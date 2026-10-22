import numpy as np
import pandas as pd
from src.theme1.taylor_boundary import initial_taylor_boundaries,boundary_union
from tests.test_initial_mismatch import mesh_frames


def test_initial_taylor_difference_and_origin_union_without_expanding_grains(tmp_path):
    nodes,elements=mesh_frames(6,6,1)
    nodes.to_csv(tmp_path/'nodes.csv',index=False);elements.to_csv(tmp_path/'elements.csv',index=False)
    angle=tmp_path/'orientation.csv';np.savetxt(angle,[[.2,.4,.8],[1.1,.9,.3]],delimiter=',')
    boundary=initial_taylor_boundaries(angle,tmp_path,-.5)
    assert len(boundary['segments'])>0
    assert (boundary['segments'].part_i!=boundary['segments'].part_j).all()
    np.testing.assert_allclose(boundary['segments'].delta_M,abs(boundary['segments'].M_i-boundary['segments'].M_j))
    on=int(boundary['segments'].node_a.iloc[len(boundary['segments'])//2])
    top=nodes[nodes.z.eq(nodes.z.max())].copy();top.node_id=np.arange(1,len(top)+1)
    far=int(top.loc[top.x.eq(top.x.min()),'node_id'].iloc[0])
    result=dict(node_heights=top,origins=pd.DataFrame(dict(origin_id=[0,1],node_id=[on,far])),
        origin_flags=pd.DataFrame(dict(model=['model','model'],threshold_factor=[1.,1.],origin_id=[0,1],captured=[True,False])),
        metrics=pd.DataFrame(dict(model=['model'],threshold_factor=[1.])))
    union=boundary_union(result,boundary,tmp_path,multiplier=.5)
    flags=union['union_origin_flags'].set_index('origin_id')
    assert flags.loc[0,'boundary_captured'] and flags.loc[0,'union_captured']
    assert not flags.loc[1,'boundary_captured'] and not flags.loc[1,'union_captured']
    assert union['union_metrics'].union_hit_origin_count.iloc[0]==1 # not double counted
    result['origin_flags']['captured']=False
    extra=boundary_union(result,boundary,tmp_path,multiplier=.5)
    assert extra['union_metrics'].additional_origins.iloc[0]==1
    np.testing.assert_array_equal(union['taylor_boundaries'].candidate,extra['taylor_boundaries'].candidate)
    assert 'union_precision' not in union['union_metrics']


def test_empty_reference_origins_keep_union_rows_and_undefined_recall(tmp_path):
    nodes,elements=mesh_frames(6,6,1)
    nodes.to_csv(tmp_path/'nodes.csv',index=False);elements.to_csv(tmp_path/'elements.csv',index=False)
    angle=tmp_path/'orientation.csv';np.savetxt(angle,[[.2,.4,.8],[.2,.4,.8]],delimiter=',')
    boundary=initial_taylor_boundaries(angle,tmp_path,0.)
    top=nodes[nodes.z.eq(nodes.z.max())].copy();top.node_id=np.arange(1,len(top)+1)
    result=dict(node_heights=top,origins=pd.DataFrame(columns=['origin_id','node_id']),
        origin_flags=pd.DataFrame(columns=['model','threshold_factor','origin_id','captured']),
        metrics=pd.DataFrame(dict(model=['model'],threshold_factor=[1.])))
    union=boundary_union(result,boundary,tmp_path)
    assert len(union['union_metrics'])==1
    assert union['union_metrics'].union_hit_origin_count.iloc[0]==0
    assert np.isnan(union['union_metrics'].union_origin_recall.iloc[0])
    assert union['taylor_boundary_metrics'].candidate_boundary_count.iloc[0]==0
