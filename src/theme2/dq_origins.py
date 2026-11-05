"""Initial D+Q candidates, evaluated once per newly observed CPFEM origin."""
import numpy as np
import pandas as pd
from src.theme2.initial_mismatch import predict_indicator_models
from src.theme2.neighbor_height import evaluate_coordinates
from src.theme2.valley_evaluation import valley_tables, _surface
from src.theme2.valley_bottom import bottom_supported_tables, reference_bottom_lines
from src.theme2.delayed_valley import classify_reference

VERSION = 'dq_origin_history_v6_dual_state12'


def event_counts(origins, states):
    """Only baseline and novel origins enter counts; repeated detections never accrue."""
    rows=[]
    for state in sorted(states):
        events=origins[(origins.state==state)&origins.is_event]
        captured=int(events.captured.sum())
        rows.append(dict(state=state,captured=captured,missed=len(events)-captured,total=len(events)))
    result=pd.DataFrame(rows)
    result['cumulative_captured']=result.captured.cumsum()
    result['cumulative_total']=result.total.cumsum()
    result['cumulative_missed']=result.missed.cumsum()
    result['cumulative_capture_rate']=result.cumulative_captured/result.cumulative_total.replace(0,np.nan)
    new=result[result.state>2]
    result['new_cumulative_captured']=new.captured.cumsum().reindex(result.index,fill_value=0)
    result['new_cumulative_total']=new.total.cumsum().reindex(result.index,fill_value=0)
    result['new_cumulative_capture_rate']=result.new_cumulative_captured/result.new_cumulative_total.replace(0,np.nan)
    return result


def track_dq(prediction, heights, model_dir):
    states=sorted(heights)
    if not states or states!=list(range(2,max(states)+1)):
        raise ValueError('state02から終了stateまで連続した高さデータが必要です。')
    ids=set(heights[2].node_id)
    if any(set(h.node_id)!=ids for h in heights.values()):
        raise ValueError('state間で表面節点の評価範囲が異なります。共通範囲の確認が必要です。')
    predicted=evaluate_coordinates(prediction['coordinates'],heights[2])[0]
    legacy=valley_tables({'d_q':predicted,'cpfem':heights[2]},model_dir)
    base=bottom_supported_tables(legacy,heights[2],model_dir,prediction_floor_fraction=.5)
    flags=base['flags'].query('threshold_factor==1').copy()
    candidates=set(flags.loc[flags.predicted_feature,'item_id'].astype(int))
    top,_,_=_surface(model_dir)
    grid=min(np.diff(np.unique(top.x)).min(),np.diff(np.unique(top.y)).min())
    radius=.5*base['metadata']['reference_definition']['neighborhood_diameter']
    prior_lines=np.empty((0,2,2));prior_origins=np.empty((0,2))
    origin_frames=[];line_frames=[]
    for state in states:
        if state==2:
            ref=dict(segments=base['bottom_lines'],origins=base['origins'],origin_support=base['origin_support'])
        else:
            ref=reference_bottom_lines(heights[state],model_dir)
        lines,origins,material,xy=classify_reference(ref,top,prior_lines,prior_origins,
            line_tolerance=grid*1.01,origin_tolerance=radius)
        if state==2:
            origins['appearance']='baseline';origins['novel_origin']=False
            lines['new_disconnected_valley']=False
        hits=set(ref['origin_support'].loc[ref['origin_support'].part_id.isin(candidates),'origin_id'])
        origins['captured']=origins.origin_id.isin(hits)
        origins['is_event']=(state==2)|origins.novel_origin
        origins['state']=state;lines['state']=state
        origin_frames.append(origins);line_frames.append(lines)
        prior_lines=np.concatenate([prior_lines,material]);prior_origins=np.concatenate([prior_origins,xy])
    origins=pd.concat(origin_frames,ignore_index=True)
    return dict(detection={**legacy,**base},counts=event_counts(origins,states),origins=origins,lines=pd.concat(line_frames,ignore_index=True),
        prediction=predicted,flags=flags,metadata=dict(version=VERSION,states=states,
        prediction=prediction['metadata'],reference_definition=base['metadata']['reference_definition'],prediction_threshold_rms=.5,origin_tolerance=radius,
        cumulative_definition='captured baseline + novel origins / baseline + novel origins',
        novelty='distance from every earlier observed origin in initial material coordinates',
        caveat='detected novelty depends on fixed extraction rules and matching tolerance; not proof of physical nucleation'))


def predict_dq(orientation, model_dir, rho):
    return predict_indicator_models(orientation,model_dir,rho=rho,m=.05,strain=.00901,
        heterogeneity=.75,coupling=0.,q_coupling=1.)['predictions']['d_q']


def project_reference_to_prediction(prediction, lines, origins):
    """Map observed features by surface node ID, never nearest XY or grain centroid.

    These are reference features projected onto the prediction, not troughs
    independently extracted from the predicted height field.
    """
    if prediction.node_id.duplicated().any():
        raise ValueError('予測の節点IDが重複しています。')
    lookup=prediction.set_index('node_id')[['x','y','z']]
    mapped_lines=lines.loc[lines.state.eq(2)].copy()
    mapped_origins=origins.loc[origins.is_event].copy()
    required=set(mapped_lines.node_a)|set(mapped_lines.node_b)|set(mapped_origins.node_id)
    if required-set(lookup.index):
        raise ValueError('谷底線・起点に対応する節点が予測マップにありません。')
    for end in ('a','b'):
        coordinates=lookup.loc[mapped_lines['node_'+end]].to_numpy(float)
        for j,axis in enumerate('xyz'):mapped_lines['predicted_'+axis+'_'+end]=coordinates[:,j]
    coordinates=lookup.loc[mapped_origins.node_id].to_numpy(float)
    for j,axis in enumerate('xyz'):mapped_origins['predicted_'+axis]=coordinates[:,j]
    return mapped_lines,mapped_origins


def evaluate_peak_origins(predicted_height, reference_height, model_dir):
    """Sign-symmetric evaluation only; never changes D+Q heights or fits a model."""
    inverted={name:frame.assign(z=-frame.z) for name,frame in
              [('d_q',predicted_height),('cpfem',reference_height)]}
    legacy=valley_tables(inverted,model_dir)
    result={**legacy,**bottom_supported_tables(legacy,inverted['cpfem'],model_dir)}
    predicted_ridges=reference_bottom_lines(inverted['d_q'],model_dir)['segments'].copy()
    for name in ('origins','boundary_origins'):
        result[name]=result[name].copy();result[name]['z']=-result[name].z
    result['bottom_lines']=result['bottom_lines'].copy()
    for name in ('z_a','z_b'):
        result['bottom_lines'][name]=-result['bottom_lines'][name]
        predicted_ridges[name]=-predicted_ridges[name]
    result['predicted_ridges']=predicted_ridges
    result['metadata']['feature']='peak origins and ridges via sign-symmetric height evaluation'
    result['metadata']['ridge_caveat']='predicted ridges extracted independently from the mapped D+Q height field; not a new mechanics model'
    return result


def track_dq_peaks(prediction, heights, model_dir):
    """Run the identical history algorithm with height sign reversed, then restore xyz."""
    mirrored={**prediction,'coordinates':prediction['coordinates'].assign(z=-prediction['coordinates'].z)}
    result=track_dq(mirrored,{s:h.assign(z=-h.z) for s,h in heights.items()},model_dir)
    result['prediction']=result['prediction'].assign(z=-result['prediction'].z)
    result['origins']=result['origins'].assign(z=-result['origins'].z)
    for column in ('z_a','z_b'):result['lines'][column]=-result['lines'][column]
    for key in ('origins','boundary_origins'):
        result['detection'][key]=result['detection'][key].assign(z=-result['detection'][key].z)
    for column in ('z_a','z_b'):
        result['detection']['bottom_lines'][column]=-result['detection']['bottom_lines'][column]
    result['metadata']={**result['metadata'],'feature':'peak','evaluation':'height-sign symmetry; original D+Q prediction unchanged'}
    return result
