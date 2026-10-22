import numpy as np
import pandas as pd
from src.theme1.initial_height import predict_grain_height,reconstruct_nodes


def initial(az=(1.,3.),m=(2.,2.)):
    return pd.DataFrame({'part_id':[1,2],'initial_area':[1.,1.],'center_x':[0.,1.],
                         'center_y':[0.,0.],'m_initial':m,'az_midpoint':az})


def edges():
    return pd.DataFrame({'part_id_i':[1],'part_id_j':[2],'weight':[1.]})


def test_uniform_properties_flat_and_prescribed_macro_thickness():
    result,_=predict_grain_height(initial((2.,2.)),edges(),thickness=.01,strain=.1,rho=-.5)
    np.testing.assert_allclose(result.predicted_height_residual,0,atol=1e-15)
    np.testing.assert_allclose(result.predicted_height_from_bottom,.01*np.exp(-.05))


def test_high_az_valley_and_coupling_changes_full_height():
    args=dict(thickness=.01,strain=.1,rho=0,slope_scale=0)
    free,_=predict_grain_height(initial(),edges(),coupling=0,**args)
    coupled,_=predict_grain_height(initial(),edges(),coupling=1,**args)
    assert coupled.predicted_height_residual.iloc[1]<0
    assert abs(coupled.predicted_height_residual.iloc[1])<abs(free.predicted_height_residual.iloc[1])
    np.testing.assert_allclose(coupled.predicted_height_residual.mean(),0,atol=1e-15)


def test_m_contrast_enters_height_solve():
    f=initial((2.,2.),(3.,1.))
    result,edge=predict_grain_height(f,edges(),thickness=.01,strain=.1,rho=0)
    assert result.predicted_height_residual.iloc[0]>result.predicted_height_residual.iloc[1]
    assert edge.target_height_difference.iloc[0]>0


def test_zero_strain_zero_relief():
    r,_=predict_grain_height(initial(),edges(),thickness=.01,strain=0,rho=0)
    np.testing.assert_allclose(r.predicted_height_from_bottom,.01)


def test_shared_node_interpolation_has_coordinate_units():
    geometry=pd.DataFrame({'part_id':[1,2],'area':[1.,1.],
                          'top_node_0':[1,2],'top_node_1':[2,5],
                          'top_node_2':[3,6],'top_node_3':[4,3]})
    nodes=pd.DataFrame({'node_id':range(1,7),'x':[0,1,1,0,2,2],
                        'y':[0,0,1,1,0,1],'z':[.01]*6})
    grain=pd.DataFrame({'part_id':[1,2],'predicted_height_from_bottom':[.009,.011]})
    prediction=reconstruct_nodes(grain,geometry,nodes,bottom_z=0,strain=0,rho=0)
    np.testing.assert_allclose(prediction.z,[.009,.01,.01,.009,.011,.011])


def test_height_scale_comes_from_initial_thickness():
    f=initial((1.,3.),(3.,2.))
    first,_=predict_grain_height(f,edges(),thickness=.01,strain=.1,rho=0)
    scaled=f.copy();scaled[['center_x','center_y']]*=2;scaled.initial_area*=4
    scaled_edges=edges();scaled_edges.weight*=2
    second,_=predict_grain_height(scaled,scaled_edges,thickness=.02,strain=.1,rho=0)
    np.testing.assert_allclose(second.predicted_height_from_bottom,2*first.predicted_height_from_bottom)


def test_slope_is_converted_to_height_using_distance():
    f=initial((2.,2.),(3.,1.))
    _,edge=predict_grain_height(f,edges(),thickness=.01,strain=.1,rho=0)
    np.testing.assert_allclose(edge.target_slope,.1)
    np.testing.assert_allclose(edge.target_height_difference,edge.centroid_distance*edge.target_slope)


def test_normalization_removes_plane_and_amplitude(tmp_path):
    from src.theme1.initial_height import normalized_height_coordinates
    x,y=np.meshgrid(np.arange(3.),np.arange(3.))
    f=pd.DataFrame({'node_id':np.arange(1,10),'x':x.ravel(),'y':y.ravel(),'z':(x*y).ravel()})
    a=tmp_path/'a.csv';b=tmp_path/'b.csv';f.to_csv(a,index=False)
    f.z=7*f.z+2*f.x-3*f.y+10;f.to_csv(b,index=False)
    an,ar=normalized_height_coordinates(a);bn,br=normalized_height_coordinates(b)
    np.testing.assert_allclose(an.z,bn.z,atol=1e-13)
    np.testing.assert_allclose(br,7*ar)
    np.testing.assert_allclose(np.mean(an.z**2),1)
    f.z=2*f.x-3*f.y+10;f.to_csv(b,index=False)
    flat,rms=normalized_height_coordinates(b)
    assert rms==0
    np.testing.assert_array_equal(flat.z,0)


def test_pplus_and_minus_have_predeclared_opposite_signs():
    f=initial();f['pplus_midpoint']=[.1,.3];f['pminus_midpoint']=[.6,.8]
    args=dict(thickness=.01,strain=.1,rho=-.5,slope_scale=0,coupling=1)
    plus,_=predict_grain_height(f,edges(),activity='pplus',**args)
    minus,_=predict_grain_height(f,edges(),activity='pminus',**args)
    assert plus.predicted_height_residual.iloc[1]>0
    np.testing.assert_allclose(plus.predicted_height_residual,-minus.predicted_height_residual,atol=1e-14)
