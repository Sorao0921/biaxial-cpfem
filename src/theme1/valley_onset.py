"""Initial-only, matched ablations for valley initiation at CPFEM state02.

Reference height, later growth and random-choice scores never enter prediction.
"""
import copy
import hashlib
import json
from pathlib import Path
import numpy as np
import pandas as pd
from src.theme1.initial_fourway import predict_three_models
from src.theme1.initial_mismatch import _geometry,scalar_height
from src.theme1.sachs_equilibrium import predict_equilibrium_from_initial
from src.theme1.neighbor_height import evaluate_coordinates
from src.theme1.valley_evaluation import valley_tables
from src.theme1.taylor_boundary import initial_taylor_boundaries,boundary_union
from src.theme1.valley_bottom import bottom_supported_tables,reference_bottom_lines

MODEL_NAMES=('self_nd','nd_contrast','d_q','equilibrium_diagonal','equilibrium')
LABELS={'self_nd':'1: Own ND only','nd_contrast':'2: Neighbor ND contrast',
    'd_q':'3: D + Q (no surface coupling)',
    'equilibrium_diagonal':'4: 3D diagonal only','equilibrium':'5: 3D full tensor',
    'cpfem':'Reference: CPFEM state02'}
PAIRS=(('self_nd','nd_contrast','周囲との差（表面伝達結合なし）'),
    ('nd_contrast','d_q','同一ND差・表面伝達結合なしでQ拘束を追加'),
    ('equilibrium_diagonal','equilibrium','同一3Dモデルでの固有せん断成分'))



def property_table():
    """Properties entering the height model, excluding common load setup/mapping."""
    columns=['自粒ND応答','近傍ND差D','RD・TD伸縮成分','せん断3成分','粒界幾何の相互作用重み','Q拘束','3D力学平衡']
    values=((1,0,0,0,0,0,0),(1,1,0,0,1,0,0),(1,1,1,1,1,1,0),
        (1,0,1,0,0,0,1),(1,0,1,1,0,0,1))
    names=['① 自粒NDのみ','② 周囲とのND差','③ 周囲とのND差＋Q','④ 3D対角のみ','⑤ 3D全成分']
    return pd.DataFrame([dict(条件=name,**{k:'○' if v else '×' for k,v in zip(columns,row)}) for name,row in zip(names,values)])


def _map_grains(grains,nodes,geometry,top_ids,rho,strain):
    top=nodes.set_index('node_id').loc[top_ids].reset_index().sort_values('node_id')
    low=nodes[['x','y','z']].min().to_numpy(float)
    height=grains.set_index('part_id').predicted_height_from_bottom
    mass={int(n):0. for n in top.node_id};zsum=mass.copy()
    for face in geometry.itertuples(index=False):
        for k in range(4):
            node=int(getattr(face,f'top_node_{k}'));mass[node]+=face.area
            zsum[node]+=face.area*(height.loc[face.part_id]+low[2])
    coordinates=top[['node_id','x','y','z']].copy()
    coordinates.z=[zsum[int(n)]/mass[int(n)] for n in coordinates.node_id]
    direction=np.array([1.,rho,-1-rho]);direction/=np.sqrt(2/3*direction@direction)
    for a,axis in enumerate('xy'):coordinates[axis]=low[a]+(coordinates[axis]-low[a])*(1+strain*direction[a])
    coordinates.node_id=np.arange(1,len(coordinates)+1)
    return coordinates


def predict_onset_models(orientation_path,model_dir,*,rho,m=.05,strain=.01,heterogeneity=.75,coupling=0.,q_coupling=1.,poisson=.3):
    """No current-state argument. strain is prescribed, not inferred from state02."""
    if strain<=0:raise ValueError('Onset response requires a positive prescribed strain')
    if coupling!=0:raise ValueError('Five-condition onset design fixes surface transmission coupling to zero')
    base=predict_three_models(orientation_path,model_dir,rho=rho,m=m,strain=strain,
        heterogeneity=heterogeneity,coupling=coupling,q_coupling=q_coupling,poisson=poisson)
    models=dict(base['models'])
    root=Path(model_dir).resolve()
    nodes,geometry,top_ids,surface,edges,volumes,_=_geometry(str(root),
        (root/'nodes.csv').stat().st_mtime_ns,(root/'elements.csv').stat().st_mtime_ns)
    initial=surface.merge(base['indicators'],on='part_id',validate='one_to_one')
    meta=copy.deepcopy(models['k_only']['metadata'])
    for name,own in [('self_nd',True),('nd_contrast',False)]:
        data=initial.copy()
        if own:
            # A common offset cancels in scalar_height's area-mean removal.
            data['d']=data.k
        grains=scalar_height(data,edges,thickness=float(np.ptp(nodes.z)),bottom=float(nodes.z.min()),
            strain=strain,rho=rho,k_to_strain=meta['k_to_strain_gain'],heterogeneity=heterogeneity,
            coupling=0.,q_coupling=0.,q_reference=meta['q_reference'])
        metadata={**meta,'model':name,'surface_coupling':0.,'q_coupling':0.,
            'drive_definition':'own K; remove common surface mean' if own else 'K_i - weighted neighboring K',
            'd_definition':'own K (common surface mean removed after solve)' if own else 'K_i - weighted neighboring K',
            'ablation_scope':'same nodal mapping, plane removal and threshold; no graph transmission'}
        models[name]={'coordinates':_map_grains(grains,nodes,geometry,top_ids,rho,strain),'grains':grains,'metadata':metadata}
    models['equilibrium_diagonal']=predict_equilibrium_from_initial(orientation_path,model_dir,rho=rho,m=m,
        strain=strain,heterogeneity=heterogeneity,poisson=poisson,components='diagonal')
    models={name:models[name] for name in MODEL_NAMES}
    configuration={**base['configuration'],'version':'valley_onset_v2_five_conditions','evaluation_state':2,
        'scope':'valley initiation locations, not subsequent expansion/merging',
        'strain_source':'a priori response scale; not obtained from CPFEM state02',
        'monotonicity_assumed':False,'random_baseline':False}
    taylor=initial_taylor_boundaries(orientation_path,model_dir,rho)
    return {**base,'models':models,'configuration':configuration,'taylor_boundary':taylor,
        'config_id':hashlib.sha256(json.dumps(configuration,sort_keys=True).encode()).hexdigest()[:12]}


def evaluate_onset(prediction,cpfem,model_dir,*,prediction_threshold_rms=.5,taylor_boundary_rms=1.):
    selected={name:evaluate_coordinates(model['coordinates'],cpfem)[0] for name,model in prediction['models'].items()}
    selected['cpfem']=cpfem.copy()
    result=valley_tables(selected,model_dir)
    result.update(bottom_supported_tables(result,cpfem,model_dir,prediction_floor_fraction=prediction_threshold_rms))
    result['metrics']=result['metrics'].drop(columns=['chance_recall','recall_lift','ap_chance'],errors='ignore')
    result['metadata'].update(evaluation_state=2,scope='valley initiation only',random_baseline=False,
        prediction_configuration=prediction['configuration'],
        ablation_interpretation='only listed within-family pairs isolate stated changes; reduced vs 3D is a formulation comparison')
    transitions=[];details=[];origin_details=[]
    for factor in sorted(result['metrics'].threshold_factor.unique()):
        flags=result['flags'].query("level=='grain' and feature=='valley'")
        flags=flags[np.isclose(flags.threshold_factor,factor)]
        for before,after,label in PAIRS:
            a=flags[flags.model==before].set_index('item_id');b=flags[flags.model==after].set_index('item_id').loc[a.index]
            truth=a.reference_feature.to_numpy(bool);old=a.predicted_feature.to_numpy(bool);new=b.predicted_feature.to_numpy(bool)
            outcome=np.select([truth&~old&new,truth&old&~new,~truth&~old&new,~truth&old&~new],
                ['new_hit','lost_hit','new_false_alarm','removed_false_alarm'],default='unchanged')
            details.append(pd.DataFrame(dict(part_id=a.index,before=before,after=after,change=label,threshold_factor=factor,
                reference_valley=truth,before_valley=old,after_valley=new,transition=outcome)))
            row=dict(before=before,after=after,change=label,threshold_factor=factor)
            row.update({kind:int((outcome==kind).sum()) for kind in ['new_hit','lost_hit','new_false_alarm','removed_false_alarm']})
            metrics=result['metrics'].query("level=='grain' and feature=='valley'")
            metrics=metrics[np.isclose(metrics.threshold_factor,factor)].set_index('model')
            row.update({f'delta_{metric}':metrics.loc[after,metric]-metrics.loc[before,metric] for metric in ['precision','recall','f1']})
            origin_flags=result['origin_flags']
            origin_flags=origin_flags[np.isclose(origin_flags.threshold_factor,factor)]
            oa=origin_flags[origin_flags.model==before].set_index('origin_id').captured
            ob=origin_flags[origin_flags.model==after].set_index('origin_id').captured.reindex(oa.index)
            gained=(~oa&ob);lost=(oa&~ob)
            row.update(new_captured_origins=int(gained.sum()),lost_captured_origins=int(lost.sum()),
                delta_origin_recall=float(ob.mean()-oa.mean()) if len(oa) else np.nan)
            origin_details.append(pd.DataFrame(dict(origin_id=oa.index,before=before,after=after,threshold_factor=factor,
                before_captured=oa.to_numpy(),after_captured=ob.to_numpy(),
                transition=np.select([gained,lost],['new_hit','lost_hit'],default='unchanged'))))
            transitions.append(row)
    result.update(selected=selected,transitions=pd.DataFrame(transitions),transition_grains=pd.concat(details,ignore_index=True),transition_origins=pd.concat(origin_details,ignore_index=True))
    boundary=prediction.get('taylor_boundary')
    if boundary is None:
        cfg=prediction['configuration'];boundary=initial_taylor_boundaries(cfg['orientation'],model_dir,cfg['rho'])
    result.update(boundary_union(result,boundary,model_dir,multiplier=taylor_boundary_rms))
    result['metadata']['taylor_union']=result['taylor_union_method']
    return result


def reference_followup(onset_result,heights,model_dir):
    """Evaluation-only retention of state02 valley IDs; no growth prediction."""
    source=onset_result['flags'].query("level=='grain' and feature=='valley' and threshold_factor==1")
    source=source[source.model==MODEL_NAMES[0]].set_index('item_id').reference_feature
    rows=[]
    for state,height in sorted(heights.items()):
        detected=reference_bottom_lines(height,model_dir)
        flags=detected['grains'].set_index('part_id')
        ids=source.index.intersection(flags.index);start=source.loc[ids].to_numpy(bool);later=flags.loc[ids].reference_feature.to_numpy(bool)
        rows.append(dict(state=state,common_grains=len(ids),onset_valleys=int(start.sum()),later_valleys=int(later.sum()),
            retained_onset_valleys=int((start&later).sum()),onset_retention=float((start&later).sum()/start.sum()) if start.any() else np.nan))
    return pd.DataFrame(rows)
