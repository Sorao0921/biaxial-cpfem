"""Initial-only surface-height hypotheses with grain-neighbor compatibility.

This is a graph closure, not a CP equilibrium solution. No observed height,
observed strain, or in-process state is accepted by the predictor API.
"""
from functools import lru_cache
from collections.abc import Mapping
from pathlib import Path

import numpy as np
import pandas as pd

from src.crystal_plasticity.stress_response import initial_grain_volumes, initial_stress_response, stress_ratio_for_strain_ratio
from src.theme1.initial_taylor_prediction import optimal_activity, surface_geometry, surface_boundary_weights
from src.theme1.initial_height import reconstruct_nodes

FEATURES={'k':'k','chi':'chi','pminus':'pminus_midpoint','pabs':'pabs_midpoint','m':'m_initial'}
DEFAULT_BLEND={'k':.5,'pminus':.5}


@lru_cache(maxsize=8)
def _surface_inputs(model_dir,nodes_stamp,elements_stamp):
    root=Path(model_dir)
    nodes=pd.read_csv(root/'nodes.csv')
    geometry,top_ids=surface_geometry(root)
    weighted=geometry.assign(wx=geometry.area*geometry.x,wy=geometry.area*geometry.y)
    grains=weighted.groupby('part_id',as_index=False).agg(initial_area=('area','sum'),wx=('wx','sum'),wy=('wy','sum'))
    grains['center_x']=grains.wx/grains.initial_area;grains['center_y']=grains.wy/grains.initial_area
    return nodes,geometry,top_ids,grains.drop(columns=['wx','wy']),surface_boundary_weights(geometry,root),initial_grain_volumes(root)


@lru_cache(maxsize=32)
def _initial_properties(orientation_path,orientation_stamp,rho,beta,m,model_dir,nodes_stamp,elements_stamp):
    _,_,_,_,_,volumes=_surface_inputs(model_dir,nodes_stamp,elements_stamp)
    angles=np.loadtxt(orientation_path,delimiter=',',ndmin=2)
    ids=volumes.part_id.to_numpy(int)
    if (ids<1).any() or (ids>len(angles)).any():raise ValueError('Missing initial grain orientation')
    response=initial_stress_response(angles[ids-1],beta,m,volumes.initial_volume.to_numpy())
    rows=[]
    for pid,euler in zip(ids,angles[ids-1]):
        result=optimal_activity(euler,rho)
        rows.append({'part_id':pid,**{key:result[key] for key in ('m_initial','pabs_min','pabs_max','pabs_midpoint','pminus_min','pminus_max','pminus_midpoint')}})
    return volumes.merge(pd.DataFrame(rows),on='part_id',validate='one_to_one').assign(chi=response['chi'],k=response['k'],k_rd=response['k_rd'],k_td=response['k_td']),response['mean_A']


@lru_cache(maxsize=32)
def _matched_beta(orientation_path,orientation_stamp,rho,m,model_dir,nodes_stamp,elements_stamp):
    volumes=_surface_inputs(model_dir,nodes_stamp,elements_stamp)[-1]
    angles=np.loadtxt(orientation_path,delimiter=',',ndmin=2)
    ids=volumes.part_id.to_numpy(int)
    if (ids<1).any() or (ids>len(angles)).any():
        raise ValueError('Missing initial grain orientation')
    return stress_ratio_for_strain_ratio(angles[ids-1],rho,m,volumes.initial_volume.to_numpy())


def solve_neighbor_height(initial, edges, *, thickness, strain, rho, feature_weights,
                          coupling=1., standardize=False,mechanism='local',inplane_weight=.5,low_k_resistance=True):
    """Solve a local-vs-neighbor graph closure for log-thickness contrast.

    c = sum normalized_weight * centered(initial_feature); low M -> contraction.
    Optional standardization uses INITIAL area-weighted RMS only.
    u=-prescribed_strain*c; min_y sum a(y-u)^2 + coupling*sum w(y_i-y_j)^2.
    a=initial_area/sum(area), w=(shared_boundary_length/distance)/sum(L/d).
    Positive thickness H=Hmacro*exp(y)/area_mean(exp(y)); no amplitude fitting.
    """
    required=['part_id','initial_area','center_x','center_y']
    if set(required)-set(initial) or initial.part_id.duplicated().any() or len(initial)==0:
        raise ValueError('Expected unique initial surface grains')
    if not np.isfinite(initial[required]).all().all() or (initial.initial_area<=0).any():
        raise ValueError('Invalid initial surface geometry')
    if not np.isfinite([thickness,strain,rho,coupling]).all() or thickness<=0 or strain<0 or coupling<0:
        raise ValueError('Invalid prescribed graph parameters')
    if not isinstance(feature_weights,Mapping) or not feature_weights or set(feature_weights)-set(FEATURES):raise ValueError('Unknown or empty feature weights')
    weights={key:float(value) for key,value in feature_weights.items()}
    if not np.isfinite(list(weights.values())).all() or min(weights.values())<0 or sum(weights.values())<=0:
        raise ValueError('Feature weights must be nonnegative with positive sum')
    total=sum(weights.values());weights={key:value/total for key,value in weights.items() if value>0}
    area=initial.initial_area.to_numpy(float,copy=True);area/=area.sum()
    result=initial.copy();contraction=np.zeros(len(result));components=[]
    for key,weight in weights.items():
        raw=result[FEATURES[key]].to_numpy(float)
        if not np.isfinite(raw).all():raise ValueError('Nonfinite initial indicator')
        # Soft grains are the contraction candidates in this explicit M hypothesis.
        oriented=-raw if key=='m' else raw
        mean=float(area@oriented);centered=oriented-mean
        rms=float(np.sqrt(area@(centered**2)))
        floor=1e-12*max(1.,float(np.max(np.abs(oriented))))
        signal=centered/rms if standardize and rms>floor else (np.zeros(len(raw)) if standardize else centered)
        result[f'component_{key}']=signal
        contraction+=weight*signal
        components.append({'feature':key,'weight':weight,'oriented_mean':mean,'initial_rms':rms,'flat':rms<=floor})
    if mechanism not in ('local','neighbor_excess') or not np.isfinite(inplane_weight) or not 0<=inplane_weight<=1:
        raise ValueError('Invalid neighbor mechanism or in-plane mixture')
    preferred=-strain*contraction
    index={int(pid):i for i,pid in enumerate(result.part_id)}
    positions=result[['center_x','center_y']].to_numpy(float)
    rows=[];pairs=set()
    for edge in edges.itertuples(index=False):
        pa,pb=int(edge.part_id_i),int(edge.part_id_j)
        if pa not in index or pb not in index:raise ValueError('Missing initial neighbor grain')
        pair=tuple(sorted((pa,pb)))
        if pa==pb or pair in pairs:raise ValueError('Duplicate or self grain edge')
        pairs.add(pair);i,j=index[pa],index[pb]
        distance=float(np.linalg.norm(positions[i]-positions[j]));length=float(edge.weight)
        if not np.isfinite([distance,length]).all() or distance<=0 or length<=0:raise ValueError('Invalid initial grain edge')
        rows.append({'part_id_i':pa,'part_id_j':pb,'i':i,'j':j,'shared_boundary_length':length,
                     'centroid_distance':distance,'weight_raw':length/distance,
                     'rd_alignment':float((positions[i,0]-positions[j,0])**2/distance**2),
                     'td_alignment':float((positions[i,1]-positions[j,1])**2/distance**2)})
    susceptibility=np.ones(len(result));k_reference=0.
    if low_k_resistance and mechanism=='neighbor_excess':
        if 'k' not in result or not np.isfinite(result['k']).all():
            raise ValueError('Initial K is required for low-K resistance')
        positive_k=np.maximum(result['k'].to_numpy(float),0.)
        k_reference=float(area@positive_k)
        susceptibility=np.minimum(1.,positive_k/k_reference) if k_reference>0 else np.zeros(len(result))
    result['drag_susceptibility']=susceptibility
    result['drag_k_reference']=k_reference
    matrix=np.diag(area)
    edge_frame=pd.DataFrame(rows,columns=['part_id_i','part_id_j','i','j','shared_boundary_length','centroid_distance','weight_raw','rd_alignment','td_alignment'])
    neighbor_mean=np.zeros(len(result));degree=np.zeros(len(result))
    if len(edge_frame):
        edge_frame['weight']=edge_frame.weight_raw/edge_frame.weight_raw.sum()
        i=edge_frame.i.to_numpy(int);j=edge_frame.j.to_numpy(int);w=edge_frame.weight.to_numpy()
        denom=susceptibility[i]+susceptibility[j]
        gate=np.divide(2*susceptibility[i]*susceptibility[j],denom,out=np.zeros_like(w),where=denom>0)
        drag_weight=w*gate  # Do not renormalize: that would erase resistance.
        edge_frame['drag_gate']=gate;edge_frame['drag_weight']=drag_weight
        np.add.at(matrix,(i,i),coupling*drag_weight);np.add.at(matrix,(j,j),coupling*drag_weight)
        np.add.at(matrix,(i,j),-coupling*drag_weight);np.add.at(matrix,(j,i),-coupling*drag_weight)
        np.add.at(neighbor_mean,i,w*contraction[j]);np.add.at(neighbor_mean,j,w*contraction[i])
        np.add.at(degree,i,w);np.add.at(degree,j,w)
        edge_frame['initial_contraction_difference']=contraction[i]-contraction[j]
    else:
        edge_frame['weight']=pd.Series(dtype=float)
    neighbor_mean=np.divide(neighbor_mean,degree,out=contraction.copy(),where=degree>0)
    nd_drive=np.zeros(len(result));rd_drive=np.zeros(len(result));td_drive=np.zeros(len(result))
    if mechanism=='neighbor_excess':
        for field in ('k_rd','k_td'):
            if field not in result or not np.isfinite(result[field]).all():
                raise ValueError('Directional initial stress responses K_RD and K_TD are required')
        if len(edge_frame):
            excess=contraction[i]-contraction[j]
            np.add.at(nd_drive,i,w*np.maximum(excess,0));np.add.at(nd_drive,j,w*np.maximum(-excess,0))
            edge_frame['nd_excess_i_to_j']=np.maximum(excess,0)
            edge_frame['nd_excess_j_to_i']=np.maximum(-excess,0)
            for field,alignment,drive in [('k_rd','rd_alignment',rd_drive),('k_td','td_alignment',td_drive)]:
                values=result[field].to_numpy(float)
                delta=values[i]-values[j]
                # Count actual extension, not merely a less negative compression.
                forward=np.maximum(delta,0)*(values[i]>0)
                backward=np.maximum(-delta,0)*(values[j]>0)
                directional=w*edge_frame[alignment].to_numpy()
                np.add.at(drive,i,directional*forward);np.add.at(drive,j,directional*backward)
                edge_frame[field+'_excess_i_to_j']=forward
                edge_frame[field+'_excess_j_to_i']=backward
                edge_frame[field+'_weight']=directional
            nd_drive=np.divide(nd_drive,degree,out=np.zeros_like(nd_drive),where=degree>0)
            rd_drive=np.divide(rd_drive,degree,out=np.zeros_like(rd_drive),where=degree>0)
            td_drive=np.divide(td_drive,degree,out=np.zeros_like(td_drive),where=degree>0)
        # Convex mixture: do not add K_ND and K_RD+K_TD as independent strain.
        valley_drive=(1-inplane_weight)*nd_drive+inplane_weight*(rd_drive+td_drive)
        preferred=-strain*valley_drive
    else:
        valley_drive=contraction.copy()
    raw_response=np.linalg.solve(matrix,area*preferred)
    log_relief=raw_response-float(area@raw_response)
    if not np.isfinite(log_relief).all() or np.ptp(log_relief)>600:
        raise ValueError('Extreme graph response; review prescribed strain / input scaling')
    direction=np.array([1.,rho,-1.-rho]);direction/=np.sqrt(2/3*np.dot(direction,direction))
    macro=thickness*np.exp(direction[2]*strain)
    relative=np.exp(log_relief-log_relief.max());relative/=area@relative
    result['contraction_signal']=contraction
    result['neighbor_contraction_mean']=neighbor_mean
    result['initial_neighbor_difference']=contraction-neighbor_mean
    result['nd_neighbor_excess']=nd_drive
    result['rd_neighbor_extension_excess']=rd_drive
    result['td_neighbor_extension_excess']=td_drive
    result['valley_drive']=valley_drive
    result['preferred_log_relief']=preferred
    result['pre_reference_log_response']=raw_response
    result['drag_log_change']=raw_response-preferred
    result['compatible_log_relief']=log_relief
    result['compatibility_correction']=log_relief-preferred
    result['macro_thickness']=macro
    result['predicted_height_from_bottom']=macro*relative
    result['predicted_height_residual']=result.predicted_height_from_bottom-macro
    if len(edge_frame):
        edge_frame['predicted_height_difference']=result.predicted_height_from_bottom.to_numpy()[edge_frame.i]-result.predicted_height_from_bottom.to_numpy()[edge_frame.j]
    return result,edge_frame.drop(columns=['i','j']),pd.DataFrame(components)


def predict_from_initial(orientation_path,model_dir,*,rho,beta,m,strain=.1,
                         feature_weights=None,coupling=1.,standardize=False,mechanism='neighbor_excess',inplane_weight=.5,low_k_resistance=True):
    """Read initial inputs only. Return full prediction before evaluation crop."""
    root=Path(model_dir);orientation=Path(orientation_path)
    ns=(root/'nodes.csv').stat().st_mtime_ns;es=(root/'elements.csv').stat().st_mtime_ns
    nodes,geometry,top_ids,surface,edges,_=_surface_inputs(str(root),ns,es)
    automatic_beta=beta is None
    if automatic_beta:
        beta=_matched_beta(str(orientation),orientation.stat().st_mtime_ns,float(rho),float(m),str(root),ns,es)
    properties,mean=_initial_properties(str(orientation),orientation.stat().st_mtime_ns,float(rho),float(beta),float(m),str(root),ns,es)
    initial=surface.merge(properties,on='part_id',validate='one_to_one')
    if len(initial)!=len(surface):raise ValueError('Missing surface properties')
    height,edge_result,components=solve_neighbor_height(initial,edges,thickness=float(nodes.z.max()-nodes.z.min()),
        strain=strain,rho=rho,feature_weights={'k':1.} if feature_weights is None else feature_weights,coupling=coupling,standardize=standardize,mechanism=mechanism,inplane_weight=inplane_weight,low_k_resistance=low_k_resistance)
    top=nodes.set_index('node_id').loc[top_ids].reset_index()
    predicted=reconstruct_nodes(height,geometry,top,bottom_z=float(nodes.z.min()),strain=strain,rho=rho)
    model_rho=float(mean[1,1]/mean[0,0]) if abs(mean[0,0])>1e-14 else None
    metadata={'model':'Initial-only graph log-thickness closure v2; not force equilibrium',
              'stress_ratio_mode':'initial_volume_mean_strain_match' if automatic_beta else 'manual',
              'rho':float(rho),'beta':float(beta),'m':float(m),'prescribed_strain':float(strain),
              'coupling':float(coupling),'standardize_initial_inputs':bool(standardize),
              'mechanism':mechanism,'inplane_weight':float(inplane_weight),
              'low_k_resistance':bool(low_k_resistance),
              'drag_rule':'s=min(1,max(K,0)/area_mean(max(K,0))); harmonic pair gate; no gated-weight renormalization',
              'directional_convention':'K_ND=-Azz/eq(mean A); K_RD=Axx/eq(mean A); K_TD=Ayy/eq(mean A)',
              'incompressibility':'K_RD+K_TD=K_ND; directional-neighbor mixture, not additive independent strain',
              'feature_weights':dict(zip(components.feature,components.weight)),
              'stress_model_mean_strain_ratio':model_rho,
              'orientation_source':str(orientation.resolve()),'initial_model_source':str(root.resolve()),
              'initial_input_versions':{'orientation_mtime_ns':orientation.stat().st_mtime_ns,'nodes_mtime_ns':ns,'elements_mtime_ns':es},
              'fit_to_simulation':False,'sign_convention':'higher K/chi/P -> thinner; lower M -> thinner',
              'weight_rule':'shared initial surface grain-boundary length / initial centroid distance',
              'scope':'surface-grain graph; subsurface compatibility is not solved',
              'height_conversion':'Hmacro=H0*exp(Dzz(rho)*strain); positive exp(log relief), area-mean thickness preserved'}
    return {'grains':height,'edges':edge_result,'components':components,'coordinates':predicted,
            'initial_properties':properties,'metadata':metadata}


def evaluate_coordinates(predicted,actual):
    """Evaluation-only node selection. Never feeds back into prediction."""
    from src.theme1.initial_taylor_prediction import pearson
    for frame in (predicted,actual):
        if set(['node_id','x','y','z'])-set(frame) or frame.node_id.duplicated().any() or len(frame)==0:
            raise ValueError('Expected unique nonempty surface node coordinates')
        if not np.isfinite(frame[['node_id','x','y','z']]).all().all():raise ValueError('Nonfinite surface coordinates')
    pred=predicted.set_index('node_id')
    if not set(actual.node_id).issubset(pred.index):raise ValueError('Actual surface node IDs not in initial prediction')
    selected=pred.loc[actual.node_id].reset_index()
    pair=selected[['node_id','z']].merge(actual[['node_id','z']],on='node_id',suffixes=('_predicted','_actual'),validate='one_to_one')
    error=pair.z_predicted-pair.z_actual
    metrics={'nodes':len(pair),'nodal_pearson':pearson(pair.z_predicted,pair.z_actual),
             'raw_height_rmse':float(np.sqrt(np.mean(error**2))),
             'predicted_height_std':float(np.std(pair.z_predicted)),
             'actual_height_std':float(np.std(pair.z_actual))}
    return selected,pair,metrics
