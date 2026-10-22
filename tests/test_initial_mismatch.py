import numpy as np
import pandas as pd
import pytest
from src.theme1.initial_mismatch import mismatch_indicators,predict_indicator_models,initial_interfaces
from tests.test_sachs_equilibrium import mesh_frames as basic_mesh_frames

def mesh_frames(*args):
    nodes,elements=basic_mesh_frames(*args)
    lookup=nodes.set_index("node_id")[["x","y","z"]]
    conn=elements[[f"node_id_{i}" for i in range(1,9)]].to_numpy()
    centers=lookup.loc[conn.ravel()].to_numpy().reshape(-1,8,3).mean(axis=1)
    elements[["center_x","center_y","center_z"]]=centers
    return nodes,elements
from src.crystal_plasticity.stress_response import initial_grain_volumes


def face():
    return pd.DataFrame({'part_id_i':[1],'part_id_j':[2],'nx':[1.],'ny':[0.],'nz':[0.],'weight':[2.]})


def test_signed_d_and_projected_q_do_not_assign_unsigned_q_a_valley_sign():
    tensors=np.zeros((2,3,3));tensors[1,1,1]=.2
    indicators,details=mismatch_indicators([1,2],[1.,3.],tensors,face())
    np.testing.assert_allclose(indicators.d,[-2.,2.])
    np.testing.assert_allclose(indicators.q,[.08,.08])
    assert details.tangential_mismatch_squared.iloc[0]==pytest.approx(.04)
    # Normal-normal and normal-tangential jumps are removed by P jump P.
    tensors=np.zeros((2,3,3));tensors[1,0,0]=.7;tensors[1,0,1]=tensors[1,1,0]=.3
    indicators,_=mismatch_indicators([1,2],[1.,3.],tensors,face())
    np.testing.assert_allclose(indicators.q,0.)


def test_q_rotation_and_normal_sign_invariant():
    rng=np.random.default_rng(42);a=rng.normal(size=(2,3,3));a=(a+a.transpose(0,2,1))/2
    first,_=mismatch_indicators([1,2],[1.,2.],a,face())
    rotation,_=np.linalg.qr(rng.normal(size=(3,3)))
    changed=face();changed[['nx','ny','nz']]=rotation[:,0]
    rotated=rotation@a@rotation.T
    second,_=mismatch_indicators([1,2],[1.,2.],rotated,changed)
    np.testing.assert_allclose(first.q,second.q)
    changed[['nx','ny','nz']]*=-1
    third,_=mismatch_indicators([1,2],[1.,2.],rotated,changed)
    np.testing.assert_allclose(first.q,third.q)


def test_initial_faces_are_real_shared_faces_not_centroid_normals(tmp_path):
    nodes,elements=mesh_frames(2,1,1)
    nodes.to_csv(tmp_path/'nodes.csv',index=False);elements.to_csv(tmp_path/'elements.csv',index=False)
    interfaces=initial_interfaces(nodes,elements,initial_grain_volumes(tmp_path))
    assert len(interfaces)==1
    np.testing.assert_allclose(abs(interfaces[['nx','ny','nz']]),[[1.,0.,0.]])
    assert interfaces.area.iloc[0]==pytest.approx(.2)
    assert interfaces.distance.iloc[0]==pytest.approx(.5)


def test_q_zero_is_exact_k_baseline_and_predictor_accepts_initial_only(tmp_path):
    nodes,elements=mesh_frames();nodes.to_csv(tmp_path/'nodes.csv',index=False);elements.to_csv(tmp_path/'elements.csv',index=False)
    angles=tmp_path/'angles.csv';np.savetxt(angles,[[.2,.4,.8],[1.1,.9,.3]],delimiter=',')
    result=predict_indicator_models(angles,tmp_path,rho=-.5,strain=.03,q_coupling=0.)
    pd.testing.assert_frame_equal(result['predictions']['k_only']['coordinates'],result['predictions']['d_q']['coordinates'])
    assert result['predictions']['d_q']['metadata']['fit_to_simulation'] is False
    assert (result['indicators'].q>=0).all()
    homogeneous=predict_indicator_models(angles,tmp_path,rho=-.5,strain=.03,heterogeneity=0.)
    np.testing.assert_allclose(homogeneous['predictions']['d_q']['grains'].predicted_height_residual,0.,atol=1.e-14)


def test_isolated_grain_and_invalid_normal():
    result,_=mismatch_indicators([1],[.5],np.zeros((1,3,3)),face().iloc[:0])
    np.testing.assert_allclose(result[['d','q']],0.)
    wrong=face();wrong.nx=2.
    with pytest.raises(ValueError):mismatch_indicators([1,2],[1.,2.],np.zeros((2,3,3)),wrong)
