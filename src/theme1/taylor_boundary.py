"""Initial Taylor-factor boundary candidates and origin-wise unions."""
from functools import lru_cache
from pathlib import Path
import numpy as np
import pandas as pd
from src.crystal_plasticity.taylor_factor import taylor_factor
from src.theme1.valley_evaluation import _surface


@lru_cache(maxsize=8)
def _initial(orientation,stamp,root,node_stamp,element_stamp,rho):
    top,geometry,faces=_surface(root)
    angles=np.loadtxt(orientation,delimiter=',',ndmin=2)
    pids=np.sort(geometry.part_id.unique()).astype(int)
    if pids.min()<1 or pids.max()>len(angles):raise ValueError('Missing initial Taylor orientations')
    factors=pd.DataFrame(dict(part_id=pids,initial_M=taylor_factor(angles[pids-1],rho)))
    values=factors.set_index('part_id').initial_M
    edge_parts={}
    for face,pid in zip(faces,geometry.part_id):
        for i in range(4):edge_parts.setdefault(tuple(sorted((int(face[i]),int(face[(i+1)%4])))),set()).add(int(pid))
    rows=[]
    for (a,b),parts in sorted(edge_parts.items()):
        if len(parts)!=2:continue
        i,j=sorted(parts);p=top.iloc[a-1][['x','y']].to_numpy(float);q=top.iloc[b-1][['x','y']].to_numpy(float)
        rows.append(dict(boundary_id=f'{i}-{j}',part_i=i,part_j=j,node_a=a,node_b=b,
            x_a=p[0],y_a=p[1],x_b=q[0],y_b=q[1],length=float(np.linalg.norm(q-p)),
            M_i=values.loc[i],M_j=values.loc[j],delta_M=abs(values.loc[i]-values.loc[j])))
    columns=['boundary_id','part_i','part_j','node_a','node_b','x_a','y_a','x_b','y_b','length','M_i','M_j','delta_M']
    segments=pd.DataFrame(rows,columns=columns)
    rms=float(np.sqrt(np.average(segments.delta_M**2,weights=segments.length))) if len(segments) else 0.
    return factors,segments,rms


def initial_taylor_boundaries(orientation,model_dir,rho):
    orientation=Path(orientation).resolve();root=Path(model_dir).resolve()
    factors,segments,rms=_initial(str(orientation),orientation.stat().st_mtime_ns,str(root),
        (root/'nodes.csv').stat().st_mtime_ns,(root/'elements.csv').stat().st_mtime_ns,float(rho))
    return dict(factors=factors.copy(),segments=segments.copy(),rms=rms,
        metadata=dict(definition='abs(initial Taylor M_i - M_j), prescribed rho, equal-CRSS FCC Taylor model',
            threshold='full initial surface boundary-length-weighted RMS delta M, multiplied by a priori factor; strict greater-than',
            boundary_unit='unordered surface grain pair; all visible shared edge segments of that pair',
            fit_to_reference=False))


def boundary_union(result,boundary,model_dir,*,multiplier=1.):
    if not np.isfinite(multiplier) or multiplier<=0:raise ValueError('Taylor boundary multiplier must be positive')
    full=boundary['segments'];ids=result['node_heights'].node_id.to_numpy(int)
    visible=full[full.node_a.isin(ids)&full.node_b.isin(ids)].copy()
    cutoff=max(64*np.finfo(float).eps,multiplier*boundary['rms'])
    visible['candidate']=visible.delta_M>cutoff
    pairs=visible.groupby('boundary_id',sort=True).agg(part_i=('part_i','first'),part_j=('part_j','first'),
        M_i=('M_i','first'),M_j=('M_j','first'),delta_M=('delta_M','first'),length=('length','sum'),candidate=('candidate','first')).reset_index()
    top,_,_=_surface(model_dir)
    tolerance=.5*float(full.length.min()) if len(full) else 0.
    matches=[]
    for o in result['origins'].itertuples():
        point=top.iloc[int(o.node_id)-1][['x','y']].to_numpy(float)
        if not len(visible):continue
        a=visible[['x_a','y_a']].to_numpy(float);v=visible[['x_b','y_b']].to_numpy(float)-a
        t=np.clip(np.sum((point-a)*v,axis=1)/np.sum(v*v,axis=1),0,1)
        distances=np.linalg.norm(point-(a+t[:,None]*v),axis=1)
        near=visible.loc[distances<=tolerance+1.e-12,['boundary_id','candidate']].copy()
        near['distance']=distances[distances<=tolerance+1.e-12]
        near=near.groupby('boundary_id',sort=True).agg(candidate=('candidate','first'),distance=('distance','min')).reset_index()
        for r in near.itertuples():matches.append(dict(origin_id=o.origin_id,boundary_id=r.boundary_id,candidate=bool(r.candidate),distance=r.distance,junction_ambiguous=len(near)>1))
    matches=pd.DataFrame(matches,columns=['origin_id','boundary_id','candidate','distance','junction_ambiguous'])
    supported=set(matches.boundary_id)
    pairs['has_reference_origin']=pairs.boundary_id.isin(supported)
    candidates=pairs.loc[pairs.candidate.astype(bool)];candidate_hits=int(candidates.has_reference_origin.sum())
    boundary_origins=set(matches.loc[matches.candidate.astype(bool),'origin_id'])
    origins=set(result['origins'].origin_id)
    boundary_summary=dict(origin_count=len(origins),boundary_hit_origin_count=len(boundary_origins),
        boundary_origin_recall=len(boundary_origins)/len(origins) if origins else np.nan,
        candidate_boundary_count=len(candidates),candidate_boundaries_with_origin=candidate_hits,
        candidate_boundaries_without_origin=len(candidates)-candidate_hits,
        boundary_precision=candidate_hits/len(candidates) if len(candidates) else np.nan,
        candidate_boundary_length=float(candidates.length.sum()),visible_boundary_length=float(pairs.length.sum()),
        candidate_length_fraction=float(candidates.length.sum()/pairs.length.sum()) if pairs.length.sum() else np.nan,
        delta_M_threshold=cutoff,threshold_rms_multiplier=multiplier,
        boundary_origin_count=int(matches.origin_id.nunique()),junction_origin_count=int(matches.loc[matches.junction_ambiguous.astype(bool),'origin_id'].nunique()))
    rows=[];flags=[]
    for entry in result['metrics'][['model','threshold_factor']].drop_duplicates().itertuples(index=False):
        model,factor=entry.model,entry.threshold_factor
        frame=result['origin_flags'][(result['origin_flags'].model==model)&np.isclose(result['origin_flags'].threshold_factor,factor)]
        original=set(frame.loc[frame.captured,'origin_id']);union=original|boundary_origins;extra=boundary_origins-original
        rows.append(dict(model=model,threshold_factor=factor,**boundary_summary,
            original_hit_origin_count=len(original),original_origin_recall=len(original)/len(origins) if origins else np.nan,
            union_hit_origin_count=len(union),union_origin_recall=len(union)/len(origins) if origins else np.nan,
            additional_origins=len(extra),both_channels_origins=len(original&boundary_origins)))
        for oid in sorted(origins):flags.append(dict(model=model,threshold_factor=factor,origin_id=oid,
            original_captured=oid in original,boundary_captured=oid in boundary_origins,union_captured=oid in union,
            capture_source='both' if oid in original&boundary_origins else 'model_only' if oid in original else 'boundary_only' if oid in boundary_origins else 'miss'))
    return dict(taylor_factors=boundary['factors'],taylor_boundary_segments=visible,taylor_boundaries=pairs,
        taylor_origin_boundary=matches,taylor_boundary_metrics=pd.DataFrame([boundary_summary]),
        union_metrics=pd.DataFrame(rows),union_origin_flags=pd.DataFrame(flags,columns=['model','threshold_factor','origin_id','original_captured','boundary_captured','union_captured','capture_source']),
        taylor_union_method={**boundary['metadata'],'matching_tolerance':tolerance,'coordinate_system':'initial material xy matched by surface node IDs',
            'matching_rule':'origin within half one initial boundary edge length of a candidate shared edge; grain interiors are not added',
            'threshold_rms_multiplier':multiplier,'delta_M_threshold':cutoff,
            'FP_definition':'candidate unordered grain-pair boundary without a state02 reference origin; not evidence it can never form a later origin',
            'union_counting':'origin IDs OR; count once even if both grains/multiple boundaries/model channels capture it; no mixed-unit union precision/F1'})
