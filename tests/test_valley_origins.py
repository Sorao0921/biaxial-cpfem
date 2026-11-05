import numpy as np
import pandas as pd
from src.theme1.valley_origins import local_origins


def line(z):
    return pd.DataFrame([dict(segment_id=i,node_a=i,node_b=i+1,x_a=i,y_a=0,z_a=z[i],x_b=i+1,y_b=0,z_b=z[i+1],length=1.) for i in range(len(z)-1)])


def test_multiple_prominent_minima_on_one_connected_valley():
    origins,_=local_origins(line([4,0,2,1,4]),height_span=4,grain_diameter=1)
    assert set(origins.node_id)=={1,3}
    assert origins.component_id.nunique()==1
    assert len(origins)==2


def test_small_ripple_is_not_a_separate_origin_and_tilt_offset_does_not_matter():
    a,_=local_origins(line([4,0,2,1.99,4]),height_span=4,grain_diameter=1)
    assert a.node_id.tolist()==[1]
    b,_=local_origins(line(np.array([4,0,2,1.99,4])+10),height_span=4,grain_diameter=1)
    assert a.node_id.tolist()==b.node_id.tolist()


def test_flat_minimum_plateau_counts_once_and_line_end_is_not_an_origin():
    origins,members=local_origins(line([4,0,0,3,2]),height_span=4,grain_diameter=1)
    assert len(origins)==1 and origins.plateau_nodes.iloc[0]==2
    assert set(members.node_id)=={1,2}


def test_boundary_origin_captured_once_when_both_supporting_grains_are_predicted(monkeypatch):
    from src.theme1 import valley_bottom as module
    ref=dict(boundary_origins=pd.DataFrame(),grains=pd.DataFrame(dict(part_id=[1,2],surface_area=[1.,1.],reference_feature=[True,True],valley_feature=[True,True],bottom_line_length=[1.,1.])),
        origins=pd.DataFrame(dict(origin_id=[0])),origin_nodes=pd.DataFrame(),
        origin_support=pd.DataFrame(dict(origin_id=[0,0],part_id=[1,2])),
        segments=pd.DataFrame(dict(segment_id=[0],length=[1.])),support=pd.DataFrame(dict(segment_id=[0,0],part_id=[1,2])),
        metadata={'prominence_cutoff':.01})
    monkeypatch.setattr(module,'reference_bottom_lines',lambda *a,**k:ref)
    monkeypatch.setattr(module,'predicted_local_lowness',lambda *a,**k:pd.DataFrame(dict(model=['prediction','prediction'],part_id=[1,2],local_lowness=[1.,1.])))
    result=module.bottom_supported_tables({'centroids':pd.DataFrame(dict(model=['prediction'])),'metadata':{}},pd.DataFrame(dict(node_id=[1])),'.')
    primary=result['metrics'].query('threshold_factor==1').iloc[0]
    assert primary.origin_count==1 and primary.hit_origin_count==1 and primary.origin_recall==1


def test_origin_valley_only_and_unsupported_predictions_are_separate(monkeypatch):
    from src.theme1 import valley_bottom as module
    ref=dict(boundary_origins=pd.DataFrame(),grains=pd.DataFrame(dict(part_id=[1,2,3],surface_area=[1.,1.,1.],reference_feature=[True,False,False],valley_feature=[True,True,False],bottom_line_length=[1.,1.,0.])),
        origins=pd.DataFrame(dict(origin_id=[0])),origin_nodes=pd.DataFrame(),
        origin_support=pd.DataFrame(dict(origin_id=[0],part_id=[1])),
        segments=pd.DataFrame(dict(segment_id=[0],length=[1.])),support=pd.DataFrame(dict(segment_id=[0],part_id=[1])),
        metadata={'prominence_cutoff':.01})
    monkeypatch.setattr(module,'reference_bottom_lines',lambda *a,**k:ref)
    monkeypatch.setattr(module,'predicted_local_lowness',lambda *a,**k:pd.DataFrame(dict(model=['prediction']*3,part_id=[1,2,3],local_lowness=[1.,1.,1.])))
    result=module.bottom_supported_tables({'centroids':pd.DataFrame(dict(model=['prediction'])),'metadata':{}},pd.DataFrame(dict(node_id=[1])),'.')
    flags=result['flags'].query('threshold_factor==1')
    assert flags.outcome.tolist()==['TP','VALLEY','FP']
    assert flags.predicted_feature.all()
    stats=result['metrics'].query('threshold_factor==1').iloc[0]
    assert stats.origin_hit_grains==stats.valley_only_grains==stats.unsupported_fp_grains==1
    assert stats.predicted_area_fraction==1 and stats.capture_per_area==1
    assert not {"precision","recall","f1"}&set(result["metrics"])


def test_capture_efficiency_uses_area_not_grain_count(monkeypatch):
    from src.theme1 import valley_bottom as module
    ref=dict(boundary_origins=pd.DataFrame(),grains=pd.DataFrame(dict(
        part_id=[1,2,3,4],surface_area=[1.,1.,1.,9.],reference_feature=[True,False,False,False],
        valley_feature=[False,True,False,True],bottom_line_length=[0.,1.,0.,1.])),
        origins=pd.DataFrame(dict(origin_id=[0])),origin_nodes=pd.DataFrame(),
        origin_support=pd.DataFrame(dict(origin_id=[0],part_id=[1])),
        segments=pd.DataFrame(dict(segment_id=[0],length=[1.])),
        support=pd.DataFrame(dict(segment_id=[0],part_id=[2])),metadata={'prominence_cutoff':.01})
    monkeypatch.setattr(module,'reference_bottom_lines',lambda *a,**k:ref)
    monkeypatch.setattr(module,'predicted_local_lowness',lambda *a,**k:pd.DataFrame(dict(
        model=['d_q']*4,part_id=[1,2,3,4],local_lowness=[1.,1.,1.,0.])))
    result=module.bottom_supported_tables({'centroids':pd.DataFrame(dict(model=['d_q'])),'metadata':{}},pd.DataFrame(dict(node_id=[1])),'.')
    row=result['metrics'].query('threshold_factor==1').iloc[0]
    assert row.origin_recall==1 and row.predicted_area_fraction==.25
    assert row.capture_per_area==4
    from src.dashboard.dq_origins import initial_score_summary
    summary=initial_score_summary({'detection':result,'counts':pd.DataFrame(dict(state=[2],eps_eq=[.00901],total=[1],captured=[1],missed=[0]))})
    assert summary['capture_per_area']==4 and summary['initial_capture_rate']==1
    assert not {'precision','recall','f1'}&set(summary)
