import numpy as np
import pandas as pd
import pytest
from src.theme1.neighbor_height import solve_neighbor_height,evaluate_coordinates


def grains():
    return pd.DataFrame({'part_id':[1,2,3],'initial_area':[1.,2.,1.],
        'center_x':[0.,1.,2.],'center_y':[0.,0.,0.],
        'k':[1.,1.,3.],'chi':[.7,.6,.5],'m_initial':[2.,3.,4.],
        'pabs_midpoint':[.7,.8,1.],'pminus_midpoint':[.51,.52,.55]})


def edges():
    return pd.DataFrame({'part_id_i':[1,2],'part_id_j':[2,3],'weight':[1.,2.]})


def solve(frame=None,edge_frame=None,**kwargs):
    params=dict(thickness=.01,strain=.1,rho=-.5,feature_weights={'k':1.},coupling=1.)
    params.update(kwargs)
    return solve_neighbor_height(grains() if frame is None else frame,edges() if edge_frame is None else edge_frame,**params)


def test_contraction_high_means_valley_and_mean_thickness_is_preserved():
    original=grains();before=original.copy(deep=True)
    result,_,_=solve(original)
    assert result.predicted_height_from_bottom.iloc[-1]<result.predicted_height_from_bottom.iloc[0]
    assert (result.predicted_height_from_bottom>0).all()
    np.testing.assert_allclose(np.average(result.predicted_height_from_bottom,weights=original.initial_area),.01*np.exp(-.05))
    pd.testing.assert_frame_equal(original,before)


def test_equal_own_property_different_neighbors_change_prediction():
    # Only grain 2 is connected to the more active grain 3.
    isolated=pd.DataFrame({'part_id_i':[2],'part_id_j':[3],'weight':[1.]})
    free,_,_=solve(edge_frame=isolated,coupling=0.)
    coupled,_,_=solve(edge_frame=isolated,coupling=1.)
    np.testing.assert_allclose(free.predicted_height_from_bottom.iloc[0],free.predicted_height_from_bottom.iloc[1])
    assert coupled.predicted_height_from_bottom.iloc[1]<coupled.predicted_height_from_bottom.iloc[0]
    assert coupled.compatibility_correction.iloc[1]!=0


def test_zero_coupling_and_initial_only_blend():
    result,_,components=solve(coupling=0.,feature_weights={'k':1.,'pminus':1.},standardize=True)
    np.testing.assert_allclose(components.weight,[.5,.5])
    np.testing.assert_allclose(result.contraction_signal,.5*result.component_k+.5*result.component_pminus)
    np.testing.assert_allclose(result.compatible_log_relief,result.preferred_log_relief)
    np.testing.assert_allclose(np.average(result.component_k**2,weights=result.initial_area),1)


def test_uniform_and_zero_strain_are_flat():
    frame=grains();frame.k=2.
    for kwargs in ({'frame':frame},{'strain':0.}):
        result,_,_=solve(**kwargs)
        np.testing.assert_allclose(result.predicted_height_residual,0,atol=1e-15)


def test_shared_boundary_length_distance_weights_and_scale_invariance():
    first,edge,_=solve()
    np.testing.assert_allclose(edge.weight,[1/3,2/3])
    changed=edges();changed.weight*=20
    second,_,_=solve(edge_frame=changed)
    np.testing.assert_allclose(first.predicted_height_from_bottom,second.predicted_height_from_bottom)
    resized=grains();resized[['center_x','center_y']]*=2;resized.initial_area*=4
    third,_,_=solve(frame=resized,edge_frame=changed,thickness=.02)
    np.testing.assert_allclose(third.predicted_height_from_bottom,2*first.predicted_height_from_bottom)


def test_prediction_independent_of_grain_and_edge_order():
    first,_,_=solve()
    reversed_edges=edges().rename(columns={'part_id_i':'part_id_j','part_id_j':'part_id_i'})
    second,_,_=solve(frame=grains().iloc[::-1],edge_frame=reversed_edges)
    np.testing.assert_allclose(first.set_index('part_id').predicted_height_from_bottom.sort_index(),second.set_index('part_id').predicted_height_from_bottom.sort_index())


def test_m_sign_and_no_reference_height_in_solver():
    result,_,_=solve(feature_weights={'m':1.},coupling=0.)
    assert result.predicted_height_from_bottom.iloc[0]<result.predicted_height_from_bottom.iloc[-1]
    assert result.predicted_height_from_bottom.min()>0


@pytest.mark.parametrize('kwargs',[{'feature_weights':{}},{'feature_weights':{'chi':-1.}},{'coupling':-1.},{'strain':-1.}])
def test_invalid_model_configuration(kwargs):
    with pytest.raises(ValueError):solve(**kwargs)


def test_evaluation_does_not_modify_full_prediction():
    prediction=pd.DataFrame({'node_id':[1,2,3,4],'x':[0,1,1,0],'y':[0,0,1,1],'z':[.009,.008,.01,.011]})
    original=prediction.copy(deep=True)
    actual=prediction.iloc[[2,0,3]].copy();actual.z*=.9
    selected,pair,metrics=evaluate_coordinates(prediction,actual)
    assert selected.node_id.tolist()==actual.node_id.tolist()
    assert metrics['nodes']==3
    pd.testing.assert_frame_equal(prediction,original)
    actual.node_id=[1,2,999]
    with pytest.raises(ValueError):evaluate_coordinates(prediction,actual)


def test_cli_saves_prediction_before_opening_observed_height(tmp_path,monkeypatch):
    from tools.theme1 import predict_neighbor_height as cli
    from src.dashboard.catalog import OutputRecord
    record=OutputRecord('height',-.5,1,'cube',8,13,tmp_path/'observed.csv','test')
    monkeypatch.setattr(cli,'scan_outputs',lambda *a:[record])
    coordinates=pd.DataFrame({'node_id':[1,2,3],'x':[0,1,0],'y':[0,0,1],'z':[.009,.01,.011]})
    prediction={name:pd.DataFrame({'value':[1]}) for name in ('grains','edges','components','initial_properties')}
    prediction.update(coordinates=coordinates,metadata={'fit_to_simulation':False,'feature_weights':{'k':1.}})
    monkeypatch.setattr(cli,'predict_from_initial',lambda *a,**kw:prediction)
    def read_observed(path):
        assert list(tmp_path.glob('saved/**/coordinates.csv'))
        assert list(tmp_path.glob('saved/**/model.json'))
        actual=coordinates.copy();actual.z=.02
        return actual
    monkeypatch.setattr(cli,'_read_height',read_observed)
    assert cli.main(['--output-dir',str(tmp_path/'saved')])==0
    saved=pd.read_csv(next(tmp_path.glob('saved/**/coordinates.csv')))
    np.testing.assert_allclose(saved.z,coordinates.z)


@pytest.mark.parametrize('feature',['k','chi','pminus','pabs','m'])
def test_each_indicator_is_a_valid_independent_hypothesis(feature):
    result,_,_=solve(feature_weights={feature:1.})
    assert np.isfinite(result.predicted_height_from_bottom).all()
    assert 'component_'+feature in result
    expected=grains()[{'k':'k','chi':'chi','pminus':'pminus_midpoint','pabs':'pabs_midpoint','m':'m_initial'}[feature]].to_numpy()
    if feature=='m':expected=-expected
    expected=expected-np.average(expected,weights=grains().initial_area)
    np.testing.assert_allclose(result.contraction_signal,expected)


def directional_grains(k):
    frame=grains();frame['k']=k
    frame['k_rd']=frame.k*.7;frame['k_td']=frame.k*.3
    return frame


def test_low_k_resistance_blocks_drag_without_changing_valley_source():
    frame=directional_grains([1.e-7,1.,3.])
    enabled,edge,_=solve(frame,mechanism='neighbor_excess',inplane_weight=0.,low_k_resistance=True)
    disabled,_,_=solve(frame,mechanism='neighbor_excess',inplane_weight=0.,low_k_resistance=False)
    np.testing.assert_allclose(enabled.valley_drive,disabled.valley_drive)
    assert abs(enabled.pre_reference_log_response.iloc[0])<abs(disabled.pre_reference_log_response.iloc[0])*.001
    assert edge.drag_gate.iloc[0]<1.e-5
    assert edge.drag_weight.sum()<edge.weight.sum()
    assert (enabled.pre_reference_log_response<=1.e-14).all()


def test_zero_k_grain_has_no_drag_and_uniform_positive_gate_is_one():
    result,edge,_=solve(directional_grains([0.,1.,3.]),mechanism='neighbor_excess')
    assert result.drag_susceptibility.iloc[0]==0
    assert result.pre_reference_log_response.iloc[0]==0
    assert edge.drag_weight.iloc[0]==0
    uniform,edge,_=solve(directional_grains([2.,2.,2.]),mechanism='neighbor_excess')
    np.testing.assert_allclose(edge.drag_gate,1.)
    np.testing.assert_allclose(uniform.valley_drive,0.)
    np.testing.assert_allclose(uniform.predicted_height_residual,0.,atol=1.e-15)


def test_directional_excess_uses_neighbor_direction_and_convex_mixture():
    frame=directional_grains([1.,1.,3.])
    nd,_,_=solve(frame,mechanism='neighbor_excess',inplane_weight=0.)
    rd,_,_=solve(frame,mechanism='neighbor_excess',inplane_weight=1.)
    mixed,_,_=solve(frame,mechanism='neighbor_excess',inplane_weight=.3)
    np.testing.assert_allclose(mixed.valley_drive,.7*nd.valley_drive+.3*rd.valley_drive)
    rotated=frame.copy();rotated['center_y']=frame.center_x;rotated['center_x']=0.
    td,_,_=solve(rotated,mechanism='neighbor_excess',inplane_weight=1.)
    np.testing.assert_allclose(rd.valley_drive*.3,td.valley_drive*.7)


def test_low_k_gate_is_reciprocal_and_local_mode_unchanged():
    frame=directional_grains([.01,1.,3.])
    forward,edge,_=solve(frame,mechanism='neighbor_excess')
    reversed_edges=edges().rename(columns={'part_id_i':'part_id_j','part_id_j':'part_id_i'})
    backward,other,_=solve(frame,reversed_edges,mechanism='neighbor_excess')
    np.testing.assert_allclose(forward.predicted_height_from_bottom,backward.predicted_height_from_bottom)
    np.testing.assert_allclose(edge.drag_weight,other.drag_weight)
    old,_,_=solve(frame,low_k_resistance=False)
    default,_,_=solve(frame)
    np.testing.assert_allclose(old.predicted_height_from_bottom,default.predicted_height_from_bottom)
