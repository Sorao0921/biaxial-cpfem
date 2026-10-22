import numpy as np
import pandas as pd
from src.theme1.valley_bottom import reference_bottom_lines,predicted_local_lowness
from tests.test_initial_mismatch import mesh_frames


def mesh(tmp_path,n=20,individual=False):
    nodes,elements=mesh_frames(n,n,1)
    if individual:elements.part_id=elements.element_id
    nodes.to_csv(tmp_path/'nodes.csv',index=False);elements.to_csv(tmp_path/'elements.csv',index=False)
    top=nodes[nodes.z.eq(nodes.z.max())].copy();top.node_id=np.arange(1,len(top)+1)
    return top


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
    from src.theme1.valley_evaluation import valley_tables
    from src.theme1.valley_bottom import bottom_supported_tables
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
