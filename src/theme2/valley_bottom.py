"""Reference trough-line support vs predicted locally low surface grains.

No overlap maximization, distance matching, or reference-dependent prediction.
Reference lines are sampled on the initial regular material grid; outputs retain
current reference xyz. A line on a shared grain boundary supports both grains.
"""
import numpy as np
import pandas as pd
from scipy.ndimage import gaussian_filter,map_coordinates
from src.theme2.valley_evaluation import _surface,binary_metrics
from src.theme1.valley_origins import local_origins


def _thin(mask):
    """Zhang-Suen thinning, zero outside the visible crop."""
    a=np.pad(mask.astype(bool),1)
    for _ in range(max(mask.shape)*2):
        changed=False
        for phase in (0,1):
            p=[a[:-2,1:-1],a[:-2,2:],a[1:-1,2:],a[2:,2:],a[2:,1:-1],a[2:,:-2],a[1:-1,:-2],a[:-2,:-2]]
            count=sum(x.astype(int) for x in p)
            transitions=sum((~p[k]&p[(k+1)%8]).astype(int) for k in range(8))
            gate=(~(p[0]&p[2]&p[4])&~(p[2]&p[4]&p[6])) if phase==0 else (~(p[0]&p[2]&p[6])&~(p[0]&p[4]&p[6]))
            remove=a[1:-1,1:-1]&(count>=2)&(count<=6)&(transitions==1)&gate
            if remove.any():a[1:-1,1:-1][remove]=False;changed=True
        if not changed:break
    return a[1:-1,1:-1]


def reference_bottom_lines(height,model_dir,*,prominence_fraction=.01,blue_fraction=.4):
    if not np.isfinite(blue_fraction) or not 0<blue_fraction<=.5:raise ValueError('Blue cutoff must be in (0, 0.5] of the displayed color interval')
    if not np.isfinite(prominence_fraction) or prominence_fraction<0:raise ValueError('Invalid reference prominence fraction')
    top,geometry,faces=_surface(model_dir)
    ids=height.node_id.to_numpy(int)
    if len(set(ids))!=len(ids) or (ids<1).any() or (ids>len(top)).any():raise ValueError('Invalid reference IDs')
    if not np.isfinite(height[['x','y','z']].to_numpy(float)).all():raise ValueError('Nonfinite reference coordinates')
    xy=top.iloc[ids-1][['x','y']].to_numpy(float)
    xs=np.unique(xy[:,0]);ys=np.unique(xy[:,1])
    if min(len(xs),len(ys))<5 or len(xs)*len(ys)!=len(ids):raise ValueError('Trough-line detection requires a complete rectangular material grid (at least 5 by 5)')
    dx=float(np.mean(np.diff(xs)));dy=float(np.mean(np.diff(ys)))
    if not np.allclose(np.diff(xs),dx,rtol=1.e-4,atol=1.e-10) or not np.allclose(np.diff(ys),dy,rtol=1.e-4,atol=1.e-10):raise ValueError('Nonuniform material grid')
    ix=np.searchsorted(xs,xy[:,0]);iy=np.searchsorted(ys,xy[:,1])
    grid=np.empty((len(ys),len(xs)));grid[iy,ix]=height.z.to_numpy(float)
    # Match the current height map: own 2-98% robust display interval.
    # This is a fraction of the HEIGHT interval, not a selected node percentile.
    color_low,color_high=np.quantile(grid,[.02,.98])
    blue_cutoff=float(color_low+blue_fraction*(color_high-color_low))
    blue=grid<blue_cutoff
    # Subtract a plane before reflected smoothing so a uniform slope is not a valley.
    design=np.column_stack([xy,np.ones(len(xy))]);trend=design@np.linalg.lstsq(design,height.z.to_numpy(float),rcond=None)[0]
    residual=grid.copy();residual[iy,ix]-=trend
    valid=np.all(np.isin(faces,ids),axis=1)
    area=geometry.loc[valid].groupby('part_id').area.sum()
    diameter=float(np.median(2*np.sqrt(area/np.pi)))
    smooth=gaussian_filter(residual,.75,mode='reflect')
    baseline=gaussian_filter(residual,(max(1.5,diameter/(2*dy)),max(1.5,diameter/(2*dx))),mode='reflect')
    contrast=baseline-smooth
    gy,gx=np.gradient(smooth,dy,dx);hyy,hyx=np.gradient(gy,dy,dx);hxy,hxx=np.gradient(gx,dy,dx)
    hessian=np.empty((*grid.shape,2,2));hessian[...,0,0]=hxx;hessian[...,1,1]=hyy
    hessian[...,0,1]=hessian[...,1,0]=(hxy+hyx)/2
    eig,vectors=np.linalg.eigh(hessian);normal=vectors[...,1]
    yy,xx=np.indices(grid.shape,dtype=float)
    # One grid step in the transverse principal-curvature direction.
    step=min(dx,dy);ox=normal[...,0]*step/dx;oy=normal[...,1]*step/dy
    plus=map_coordinates(smooth,[yy+oy,xx+ox],order=1,mode='nearest')
    minus=map_coordinates(smooth,[yy-oy,xx-ox],order=1,mode='nearest')
    numerical=64*np.finfo(float).eps*max(1.,float(abs(grid).max()))
    cutoff=max(numerical,prominence_fraction*float(np.sqrt(np.mean(contrast**2))))
    mask=(contrast>cutoff)&(eig[...,1]>numerical/max(step*step,1.e-30))&(smooth<=plus)&(smooth<=minus)&((plus-smooth>numerical)|(minus-smooth>numerical))
    mask &= blue
    mask[[0,-1],:]=False;mask[:,[0,-1]]=False
    mask=_thin(mask)
    node_grid=np.empty(grid.shape,int);node_grid[iy,ix]=ids
    current=height.set_index('node_id')[['x','y','z']]
    # Common face membership is essential: point-only contact does not add a grain.
    face_parts={}
    for face,pid in zip(faces[valid],geometry.loc[valid].part_id):
        for a in range(4):
            for b in range(a+1,4):face_parts.setdefault(tuple(sorted((int(face[a]),int(face[b])))),set()).add(int(pid))
    segments=[];support=[]
    for y,x in np.argwhere(mask):
        for oy_,ox_ in [(0,1),(1,0),(1,1),(1,-1)]:
            y2=y+oy_;x2=x+ox_
            if not (0<=y2<len(ys) and 0<=x2<len(xs)) or not mask[y2,x2]:continue
            if oy_ and ox_ and (mask[y,x2] or mask[y2,x]):continue
            if oy_ and ox_ and not (blue[y,x2] and blue[y2,x]):continue
            n1=int(node_grid[y,x]);n2=int(node_grid[y2,x2]);parts=face_parts.get(tuple(sorted((n1,n2))),set())
            if not parts:continue
            p=current.loc[n1].to_numpy(float);q=current.loc[n2].to_numpy(float);length=float(np.linalg.norm(q[:2]-p[:2]))
            sid=len(segments)
            segments.append(dict(segment_id=sid,node_a=n1,node_b=n2,x_a=p[0],y_a=p[1],z_a=p[2],x_b=q[0],y_b=q[1],z_b=q[2],length=length,
                material_x_a=xs[x],material_y_a=ys[y],material_x_b=xs[x2],material_y_b=ys[y2]))
            for pid in parts:support.append(dict(segment_id=sid,part_id=pid,length=length))
    columns=['segment_id','node_a','node_b','x_a','y_a','z_a','x_b','y_b','z_b','length','material_x_a','material_y_a','material_x_b','material_y_b']
    segments=pd.DataFrame(segments,columns=columns);support=pd.DataFrame(support,columns=['segment_id','part_id','length'])
    grains=pd.DataFrame({'part_id':area.index,'surface_area':area.to_numpy()})
    lengths=support.groupby('part_id').length.sum() if len(support) else pd.Series(dtype=float)
    grains['bottom_line_length']=grains.part_id.map(lengths).fillna(0.)
    # Positive-length support, not a point touching a vertex.
    minimum_length=.5*min(dx,dy)
    grains['full_line_feature']=grains.bottom_line_length>=minimum_length
    # Detect origins on the full 2D height field, independently of thinned lines.
    # Use detrended, lightly smoothed heights for morphology; retain physical xyz
    # in exported origins. All eight grid neighbors participate in prominence.
    graph_edges=[]
    for oy_,ox_ in [(0,1),(1,0),(1,1),(1,-1)]:
        ya,xa=np.indices(grid.shape)
        yb,xb=ya+oy_,xa+ox_
        ok=(yb<len(ys))&(xb>=0)&(xb<len(xs))
        ya,xa,yb,xb=ya[ok],xa[ok],yb[ok],xb[ok]
        graph_edges.append(pd.DataFrame(dict(node_a=node_grid[ya,xa],node_b=node_grid[yb,xb],
            x_a=xs[xa],y_a=ys[ya],z_a=smooth[ya,xa],
            x_b=xs[xb],y_b=ys[yb],z_b=smooth[yb,xb],
            length=np.full(len(ya),np.hypot(ox_*dx,oy_*dy)))))
    # Local depression, rather than global display color, defines valley area.
    valley_cutoff=max(numerical,.5*float(np.sqrt(np.mean(contrast**2))))
    valley_mask=contrast>valley_cutoff
    candidates=set(node_grid[valley_mask])
    origins,origin_nodes=local_origins(pd.concat(graph_edges,ignore_index=True),
        height_span=float(np.ptp(smooth)),grain_diameter=diameter,
        candidate_nodes=candidates)
    boundary=set(node_grid[0])|set(node_grid[-1])|set(node_grid[:,0])|set(node_grid[:,-1])
    boundary_ids=set(origin_nodes.loc[origin_nodes.node_id.isin(boundary),'origin_id'])
    boundary_origins=origins[origins.origin_id.isin(boundary_ids)].copy()
    origins=origins[~origins.origin_id.isin(boundary_ids)].copy()
    origin_nodes=origin_nodes[origin_nodes.origin_id.isin(origins.origin_id)].copy()
    for frame in (origins,boundary_origins):
        frame[['x','y','z']]=current.loc[frame.node_id,['x','y','z']].to_numpy()
    node_parts={}
    for face,pid in zip(faces[valid],geometry.loc[valid].part_id):
        for node in face:node_parts.setdefault(int(node),set()).add(int(pid))
    origin_support=[]
    for oid,members in origin_nodes.groupby('origin_id'):
        parts=set().union(*(node_parts.get(int(n),set()) for n in members.node_id))
        origin_support.extend(dict(origin_id=oid,part_id=pid) for pid in sorted(parts))
    valley_nodes=set(node_grid[valley_mask])
    face_fraction=np.array([sum(int(n) in valley_nodes for n in face)/4 for face in faces[valid]])
    valley_area=geometry.loc[valid,['part_id','area']].copy()
    valley_area['valley_area']=valley_area.area.to_numpy()*face_fraction
    fractions=valley_area.groupby('part_id').valley_area.sum()/area
    grains['valley_area_fraction']=grains.part_id.map(fractions).fillna(0.)
    grains['valley_feature']=(grains.valley_area_fraction>=.1)|grains.full_line_feature
    origin_support=pd.DataFrame(origin_support,columns=['origin_id','part_id'])
    origin_counts=origin_support.groupby('part_id').origin_id.nunique() if len(origin_support) else pd.Series(dtype=int)
    grains['origin_count']=grains.part_id.map(origin_counts).fillna(0).astype(int)
    grains['reference_feature']=grains.origin_count>0
    return dict(boundary_origins=boundary_origins,segments=segments,support=support,grains=grains,origins=origins,origin_nodes=origin_nodes,origin_support=origin_support,metadata=dict(
        origin_rule='full 8-neighbor surface graph, detrended and smoothed; prominence >5% of smoothed height span; separation >=0.5 initial median grain diameter; boundary minima reported separately',
        valley_rule='local depression >0.5 RMS; at least 10% exposed grain area or positive trough-line support',valley_cutoff=valley_cutoff,
        origin_counting='one event per local minimum; incident surface faces at minimum plateau nodes define alternative supporting grains, never duplicate events',
        method='transverse local-minimum ridge, positive principal curvature and local depression; thinned on regular initial material grid',
        blue_color_fraction=blue_fraction,blue_height_cutoff=blue_cutoff,color_low=float(color_low),color_high=float(color_high),
        blue_rule=f'raw z below low + {blue_fraction:g}*(high-low), where low/high are own height-map 2/98 percentiles; not a node-selection percentile',
        small_smoothing_grid_sigma=.75,neighborhood_diameter=diameter,prominence_fraction=prominence_fraction,
        prominence_cutoff=cutoff,minimum_support_length=minimum_length,
        boundary_rule='a positive-length line on a shared grain boundary supports both grains; isolated points do not count',
        crop_rule='incomplete faces and outermost grid row/column excluded; no gap interpolation',
        length_counting='shared-boundary length recorded for both grains; global line coverage counts each segment once'))


def predicted_local_lowness(centroids,model_dir,node_ids):
    """Own predicted height below weighted neighboring plane, using visible faces."""
    top,geometry,faces=_surface(model_dir);keep=np.all(np.isin(faces,node_ids),axis=1)
    edges={}
    for face,pid in zip(faces[keep],geometry.loc[keep].part_id):
        for k in range(4):edges.setdefault(tuple(sorted((int(face[k]),int(face[(k+1)%4])))),set()).add(int(pid))
    pair_lengths={}
    for (a,b),parts in edges.items():
        if len(parts)!=2:continue
        pair=tuple(sorted(parts));length=float(np.linalg.norm(top.iloc[a-1][['x','y']].to_numpy(float)-top.iloc[b-1][['x','y']].to_numpy(float)))
        pair_lengths[pair]=pair_lengths.get(pair,0.)+length
    result=[]
    for model,frame in centroids.groupby('model',sort=False):
        frame=frame.set_index('part_id').sort_index();neighbors={int(pid):[] for pid in frame.index}
        for (a,b),length in pair_lengths.items():
            if a in neighbors and b in neighbors:neighbors[a].append((b,length));neighbors[b].append((a,length))
        scores=[]
        for pid,row in frame.iterrows():
            adjacent=neighbors[int(pid)]
            if not adjacent:
                scores.append(dict(model=model,part_id=pid,local_lowness=np.nan,neighbor_count=0,local_baseline='unavailable'));continue
            ids=[a for a,_ in adjacent];other=frame.loc[ids]
            delta=other[['x','y']].to_numpy(float)-row[['x','y']].to_numpy(float)
            distance=np.linalg.norm(delta,axis=1)
            weights=np.array([v for _,v in adjacent])/np.maximum(distance,np.finfo(float).tiny)
            design=np.column_stack([delta,np.ones(len(ids))]);weighted=design*np.sqrt(weights)[:,None]
            if len(ids)>=3 and np.linalg.matrix_rank(weighted)==3:
                coef=np.linalg.lstsq(weighted,(other.z.to_numpy(float)-row.z)*np.sqrt(weights),rcond=None)[0]
                score=float(coef[2]/np.sqrt(1+coef[0]**2+coef[1]**2));rule='neighbor_plane'
            else:
                score=float(np.average(other.distance,weights=weights)-row.distance);rule='neighbor_mean_detrended'
            scores.append(dict(model=model,part_id=pid,local_lowness=score,neighbor_count=len(ids),local_baseline=rule))
        result.extend(scores)
    return pd.DataFrame(result)


def bottom_supported_tables(legacy,cpfem,model_dir,*,prediction_floor_fraction=.5):
    if not np.isfinite(prediction_floor_fraction) or prediction_floor_fraction<=0:raise ValueError('Prediction RMS multiplier must be positive')
    ref=reference_bottom_lines(cpfem,model_dir)
    local=predicted_local_lowness(legacy['centroids'].query("model!='cpfem'"),model_dir,cpfem.node_id.to_numpy(int))
    rows=[];flags=[];thresholds=[];origin_flags=[]
    reference=ref['grains'].set_index('part_id')
    for name,frame in local.groupby('model',sort=False):
        frame=frame.set_index('part_id').reindex(reference.index)
        score=frame.local_lowness.to_numpy(float);valid=np.isfinite(score);truth=reference.reference_feature.to_numpy(bool)
        numerical=64*np.finfo(float).eps
        base=max(numerical,prediction_floor_fraction*float(np.sqrt(np.mean(score[valid]**2)))) if valid.any() else numerical
        thresholds.append(dict(model=name,level='grain',automatic_threshold=base))
        for factor in (.5,1.,2.):
            predicted=valid&(score>base*factor)
            stats=binary_metrics(truth[valid],predicted[valid]) if valid.any() else dict(precision=np.nan,recall=np.nan,f1=np.nan,iou=np.nan,items=0,target_count=0,predicted_count=0,true_positive=0,false_positive=0,false_negative=0,reference_coverage=np.nan,predicted_coverage=np.nan)
            stats={k:v for k,v in stats.items() if k not in ('chance_recall','recall_lift')}
            stats.update(model=name,level='grain',feature='valley',threshold_factor=factor,distance_threshold=base*factor,
                reference_threshold=ref['metadata']['prominence_cutoff'],excluded_no_neighbors=int((~valid).sum()))
            support=ref['support'];covered=set(reference.index[predicted])
            selected_segments=support[support.part_id.isin(covered)].segment_id.unique()
            total=ref['segments'].length.sum()
            stats['bottom_line_coverage']=float(ref['segments'].set_index('segment_id').reindex(selected_segments).length.sum()/total) if total else np.nan
            hit_origins=set(ref['origin_support'].query('part_id in @covered').origin_id) if len(ref['origin_support']) else set()
            valley=reference.valley_feature.to_numpy(bool)
            stats.update(origin_hit_grains=int((predicted&truth).sum()),valley_only_grains=int((predicted&~truth&valley).sum()),unsupported_fp_grains=int((predicted&~truth&~valley).sum()))
            stats.update(origin_count=len(ref['origins']),hit_origin_count=len(hit_origins),
                origin_recall=len(hit_origins)/len(ref['origins']) if len(ref['origins']) else np.nan)
            origin_flags.append(pd.DataFrame(dict(model=name,threshold_factor=factor,origin_id=ref['origins'].origin_id.to_numpy(),captured=ref['origins'].origin_id.isin(hit_origins).to_numpy())))
            areas=reference.surface_area.to_numpy(float)
            eligible_area=float(areas[valid].sum())
            coverage=float(areas[predicted].sum()/eligible_area) if eligible_area else np.nan
            stats.update(predicted_area_fraction=coverage,
                capture_per_area=stats['origin_recall']/coverage if coverage>0 else np.nan,
                eligible_surface_area=eligible_area,predicted_surface_area=float(areas[predicted].sum()))
            stats={k:v for k,v in stats.items() if k not in ('precision','recall','f1','iou')}
            rows.append(stats)
            flags.append(pd.DataFrame(dict(model=name,level='grain',feature='valley',threshold_factor=factor,item_id=reference.index,
                reference_feature=truth,reference_valley=valley,predicted_feature=predicted,eligible=valid,predicted_local_lowness=score,
                bottom_line_length=reference.bottom_line_length.to_numpy(),
                outcome=np.select([~valid,truth&predicted,~truth&predicted&valley,~truth&predicted,truth&~predicted],['EXCLUDED','TP','VALLEY','FP','FN'],default='TN'))))
    return dict(metrics=pd.DataFrame(rows),flags=pd.concat(flags,ignore_index=True),thresholds=pd.DataFrame(thresholds),
        boundary_origins=ref['boundary_origins'],local_lowness=local,origin_flags=pd.concat(origin_flags,ignore_index=True),origins=ref['origins'],origin_nodes=ref['origin_nodes'],origin_support=ref['origin_support'],bottom_lines=ref['segments'],bottom_line_support=ref['support'],reference_bottom_grains=ref['grains'],
        metadata={**legacy['metadata'],'method_version':'surface_valley_origins_v6_capture_area','reference_definition':ref['metadata'],
            'prediction_definition':'positive depression below neighboring weighted plane; length/distance weights; detrended neighbor mean fallback for rank-deficient neighborhoods',
            'capture_area_definition':'predicted initial surface area / eligible initial surface area; capture_per_area = origin capture fraction / area fraction; descriptive concentration, not statistical confidence or chance significance',
            'feature_definition':'reference: grains containing local deepest origin points; primary recall counts distinct origins once; grain confusion metrics are auxiliary',
            'plane':'global OLS plane retained for diagnostic outputs and detrending only, not an absolute valley cutoff',
            'grain_statistic':'current exposed surface area centroid; prediction uses neighboring-plane depression, reference uses line support',
            'prediction_floor_fraction':prediction_floor_fraction,'threshold_rule':'prediction: configured RMS local depression multiplier (default 0.5), times sensitivity .5/1/2; reference line threshold fixed across predictions',
            'false_positive_meaning':'map FP: predicted grain with neither origin nor valley support; diagnostic colors only, no classification scores'})
