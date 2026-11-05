import numpy as np
import pandas as pd
from src.theme2.valley_bottom import reference_bottom_lines,predicted_local_lowness
from tests.helpers import surface_mesh as mesh


def test_tilted_trough_on_grain_boundary_supports_both_grains_and_records_coordinates(tmp_path):
    top=mesh(tmp_path)
    top.z=.01+.002*(top.x-.5)**2+.003*top.y
    result=reference_bottom_lines(top,tmp_path)
    assert len(result['segments'])>5
    assert set(result['grains'].query('full_line_feature').part_id)=={1,2}
    shared=result['support'].groupby('segment_id').part_id.nunique()
    assert (shared==2).any()
    assert np.median(abs(result['segments'].x_a-.5))<.06
    # A reference vertical offset cannot change the detected node pairs.
    shifted=top.copy();shifted.z+=2
    again=reference_bottom_lines(shifted,tmp_path)
    np.testing.assert_array_equal(result['segments'][['node_a','node_b']],again['segments'][['node_a','node_b']])


def test_uniform_tilt_does_not_create_bottom_lines(tmp_path):
    top=mesh(tmp_path);top.z=.01+.01*top.x-.003*top.y
    result=reference_bottom_lines(top,tmp_path)
    assert result['segments'].empty and not result['grains'].reference_feature.any()


def test_local_plane_excludes_uniform_slope_and_detects_a_local_depression(tmp_path):
    mesh(tmp_path,6,individual=True)
    rows=[dict(model='prediction',part_id=y*6+x+1,x=(x+.5)/6,y=(y+.5)/6,z=.01+.001*x+.002*y,distance=0.) for y in range(6) for x in range(6)]
    frame=pd.DataFrame(rows)
    ids=np.arange(1,50)
    flat=predicted_local_lowness(frame,tmp_path,ids)
    assert abs(flat.query("local_baseline=='neighbor_plane'").local_lowness).max()<1.e-12
    frame.loc[frame.part_id.eq(15),'z']-=.005
    low=predicted_local_lowness(frame,tmp_path,ids)
    assert low.set_index('part_id').loc[15,'local_lowness']>.004


def test_reference_lines_are_restricted_to_blue_height_interval(tmp_path):
    top=mesh(tmp_path)
    top.z=.01+.002*(top.x-.5)**2+.001*np.cos(4*np.pi*top.y)
    result=reference_bottom_lines(top,tmp_path)
    cutoff=result['metadata']['blue_height_cutoff']
    lo,hi=np.quantile(top.z,[.02,.98])
    assert np.isclose(cutoff,lo+.4*(hi-lo))
    assert len(result['segments'])>0
    assert (result['segments'][['z_a','z_b']].to_numpy()<cutoff).all()


def test_stricter_prediction_threshold_reduces_candidates_without_changing_reference(tmp_path):
    from src.theme2.valley_evaluation import valley_tables
    from src.theme2.valley_bottom import bottom_supported_tables
    top=mesh(tmp_path,12,individual=True)
    top.z=.01+.001*np.cos(4*np.pi*top.x)+.0002*np.cos(8*np.pi*top.y)
    selected={'cpfem':top.copy(),'prediction':top.copy()}
    legacy=valley_tables(selected,tmp_path)
    loose=bottom_supported_tables(legacy,top,tmp_path,prediction_floor_fraction=.01)
    strict=bottom_supported_tables(legacy,top,tmp_path,prediction_floor_fraction=.5)
    a=loose['flags'].query('threshold_factor==1').set_index('item_id')
    b=strict['flags'].query('threshold_factor==1').set_index('item_id').loc[a.index]
    np.testing.assert_array_equal(a.reference_feature,b.reference_feature)
    assert not (b.predicted_feature & ~a.predicted_feature).any()
    assert b.predicted_feature.sum()<a.predicted_feature.sum()
    pd.testing.assert_frame_equal(loose['bottom_lines'],strict['bottom_lines'])


def test_surface_origins_do_not_require_a_bottom_line(tmp_path,monkeypatch):
    import src.theme2.valley_bottom as module
    top=mesh(tmp_path,24,individual=True)
    top.z=.01-.002*np.exp(-((top.x-.5)**2+(top.y-.5)**2)/.02)
    # Even a completely broken/empty line extraction must not erase the basin.
    monkeypatch.setattr(module,'_thin',lambda mask:np.zeros_like(mask))
    result=module.reference_bottom_lines(top,tmp_path)
    assert result['segments'].empty
    assert len(result['origins'])==1
    origin=result['origins'].iloc[0]
    assert abs(origin.x-.5)<.05 and abs(origin.y-.5)<.05
    assert len(result['origin_support'])==4  # Shared corner, one event.
    assert result['grains'].valley_feature.sum()>result['grains'].reference_feature.sum()
    shifted=top.copy();shifted.z+=.004*shifted.x-.003*shifted.y+2
    again=module.reference_bottom_lines(shifted,tmp_path)
    assert set(again['origins'].node_id)==set(result['origins'].node_id)


def test_boundary_minimum_is_retained_separately(tmp_path):
    top=mesh(tmp_path,24,individual=True)
    top.z=.01-.002*np.exp(-(top.x**2+(top.y-.5)**2)/.01)
    result=reference_bottom_lines(top,tmp_path)
    assert len(result['boundary_origins'])>=1
    assert (result['boundary_origins'].x==0).any()
    assert not (result['origins'].x==0).any()


def test_boundary_origin_captured_once_when_both_supporting_grains_are_predicted(monkeypatch):
    from src.theme2 import valley_bottom as module
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
    from src.theme2 import valley_bottom as module
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
    from src.theme2 import valley_bottom as module
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

