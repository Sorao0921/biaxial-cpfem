import numpy as np
import pandas as pd
from src.crystal_plasticity.taylor_factor import fcc_solver, crystal_strain, components, taylor_factor
from src.theme1.initial_taylor_prediction import optimal_activity, grain_response, spearman


def test_optimal_vertices_reproduce_strain_and_taylor_minimum():
    for rho in [-.5,0,1]:
        for e in [[0,0,0],[.3,1.1,.7]]:
            r=optimal_activity(e,rho)
            gamma=r['gamma']
            b=components(crystal_strain(e,rho))
            np.testing.assert_allclose(gamma@fcc_solver()[0].T,np.broadcast_to(b,(len(gamma),5)),atol=1e-9)
            np.testing.assert_allclose(np.abs(gamma).sum(axis=1),taylor_factor(e,rho),atol=1e-9)
            assert 0<=r['az_min']<=r['az_midpoint']<=r['az_max']<=r['m_initial']+1e-9


def test_degenerate_orientation_has_multiple_solutions():
    r=optimal_activity([0,0,0],0)
    assert r['optimal_vertices']>1
    np.testing.assert_allclose(r['vertex_az'],np.abs(r['gamma'])@r['projection'])


def test_spearman_ties_and_constant():
    assert spearman([1,1,2,3],[3,3,2,1])==-1
    assert np.isnan(spearman([1,1,1],[1,2,3]))


def test_complete_top_faces_and_explicit_row_id_mapping(tmp_path):
    # Only top nodes, with local IDs overlapping unrelated global connectivity.
    top=np.array([2,10,20,30,40,50])
    geom=pd.DataFrame([{'part_id':1,'element_id':1,'area':1.,'x':.5,'y':.5,
                       'top_node_0':2,'top_node_1':10,'top_node_2':20,'top_node_3':30},
                      {'part_id':2,'element_id':2,'area':1.,'x':1.5,'y':.5,
                       'top_node_0':20,'top_node_1':30,'top_node_2':40,'top_node_3':50}])
    path=tmp_path/'height.csv'
    pd.DataFrame([[1,0,0,0],[2,1,0,0],[3,1,1,1],[4,0,1,0],[5,2,0,0]]).to_csv(path,index=False,header=False)
    grains,elements=grain_response(path,geom,top)
    assert grains.part_id.tolist()==[1]
    assert elements.element_id.tolist()==[1]
    assert grains.height_std.iloc[0]>0


def test_valley_sign_and_area_centering():
    from src.theme1.initial_taylor_prediction import add_valley_prediction
    frame=pd.DataFrame({'retained_area':[1.,2.,1.],'az_midpoint':[1.,2.,4.],
                        'height_mean':[3.,2.,0.]})
    result=add_valley_prediction(frame)
    assert result.relief_from_az_midpoint.iloc[-1]<0
    assert result.relief_from_az_midpoint.iloc[0]>0
    np.testing.assert_allclose(np.average(result.relief_from_az_midpoint,weights=frame.retained_area),0)
    np.testing.assert_allclose(spearman(result.relief_from_az_midpoint,frame.height_mean),1)
    np.testing.assert_allclose(spearman(frame.az_midpoint,frame.height_mean),-1)


def test_measured_interval_and_missing_integral(tmp_path):
    from src.dashboard.catalog import OutputRecord
    from src.crystal_plasticity.slip_activity_pipeline import activity_path
    from src.theme1.initial_taylor_prediction import measured_activity_response
    record=OutputRecord('height',0.,1,'cube',2,13,tmp_path/'height.csv','test')
    path=activity_path(record,tmp_path);path.parent.mkdir(parents=True)
    pd.DataFrame({'element_id':[2,1,3],'z_slip_activity':[4.,2.,8.],
                  'delta_eps_eq':[.1,.1,.1]}).to_csv(path,index=False)
    elements=pd.DataFrame({'element_id':[1,2,3],'part_id':[10,10,20],'area':[1.,3.,2.]})
    values,status=measured_activity_response(record,elements,tmp_path)
    assert values['measured_az_state13'].loc[10]==3.5
    assert values['measured_az_state13'].loc[20]==8.
    assert 'measured_bz_state13' not in values
    assert status['measured_bz_state13']=='missing_saved_intervals'


def test_neighbor_contrast_uses_boundary_weights_and_missing_neighbors():
    from src.theme1.initial_taylor_prediction import add_neighbor_activity
    frame=pd.DataFrame({'part_id':[1,2,3],'az_midpoint':[4.,1.,3.]})
    edges=pd.DataFrame({'part_id_i':[1,1],'part_id_j':[2,3],'weight':[1.,3.]})
    result=add_neighbor_activity(frame,edges).set_index('part_id')
    assert result.loc[1,'neighbor_az_mean']==2.5
    assert result.loc[1,'relief_from_neighbor_az']==-1.5
    assert result.loc[2,'relief_from_neighbor_az']==3.
    import pytest
    with pytest.raises(ValueError,match='neighboring grain'):
        add_neighbor_activity(frame.iloc[:2],edges)


def test_pearson_linear_and_constant():
    from src.theme1.initial_taylor_prediction import pearson
    np.testing.assert_allclose(pearson([1,2,3,4],[8,6,4,2]),-1)
    assert np.isnan(pearson([1,1,1],[1,2,3]))


def test_boundary_weights_exclude_point_contacts(tmp_path):
    from src.theme1.initial_taylor_prediction import surface_boundary_weights
    pd.DataFrame({'node_id':range(1,9),'x':[0,1,1,0,2,2,2,1],
                  'y':[0,0,1,1,0,1,2,2]}).to_csv(tmp_path/'nodes.csv',index=False)
    frame=pd.DataFrame([
        {'part_id':1,'top_node_0':1,'top_node_1':2,'top_node_2':3,'top_node_3':4},
        {'part_id':2,'top_node_0':2,'top_node_1':5,'top_node_2':6,'top_node_3':3},
        {'part_id':3,'top_node_0':3,'top_node_1':6,'top_node_2':7,'top_node_3':8}])
    edges=surface_boundary_weights(frame,tmp_path)
    assert set(zip(edges.part_id_i,edges.part_id_j))=={(1,2),(2,3)}
    np.testing.assert_allclose(edges.weight,[1.,1.])


def test_pplus_minus_reconstruct_prescribed_nd_strain():
    for rho in (-.5,0.,1.):
        d=np.array([1.,rho,-1.-rho]);d/=np.sqrt(2/3*np.dot(d,d))
        for euler in ([0.,0.,0.],[.4,.7,.9],[1.2,.1,.6]):
            result=optimal_activity(euler,rho)
            np.testing.assert_allclose(result['vertex_pplus']-result['vertex_pminus'],d[2],atol=2e-12)
            assert np.all(result['vertex_pplus']>=0)
            assert np.all(result['vertex_pminus']>=0)
            np.testing.assert_allclose(result['pplus_midpoint']-result['pminus_midpoint'],d[2],atol=2e-12)


def test_pabs_comes_from_initial_taylor_signed_slip_distribution():
    result=optimal_activity([.4,.7,.9],-.5)
    expected=np.sum(np.abs(result['gamma'])*result['projection'],axis=1)
    np.testing.assert_allclose(result['vertex_pabs'],expected)
    np.testing.assert_allclose(result['pabs_midpoint'],(expected.min()+expected.max())/2)
