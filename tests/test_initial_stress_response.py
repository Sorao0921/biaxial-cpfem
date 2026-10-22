import numpy as np
import pandas as pd
import pytest

from src.crystal_plasticity.stress_response import (
    initial_stress_response,initial_grain_volumes,fcc_slip_geometry)
from src.crystal_plasticity.taylor_factor import bunge_sample_to_crystal


def test_matches_unscaled_power_law_and_volume_average():
    angles=np.array([[.2,.4,.8],[1.1,.9,.3],[.7,.6,1.2]])
    beta=.3;m=.2;weights=np.array([1.,2.,4.])
    s,n=fcc_slip_geometry();g=bunge_sample_to_crystal(angles)
    s=np.einsum('gji,aj->gai',g,s);n=np.einsum('gji,aj->gai',g,n)
    schmid=(s[:,:,:,None]*n[:,:,None,:]+n[:,:,:,None]*s[:,:,None,:])/2
    tau=schmid[:,:,0,0]+beta*schmid[:,:,1,1]
    direct=np.einsum('ga,gaij->gij',np.sign(tau)*np.abs(tau)**(1/m),schmid)
    local_eq=np.sqrt(2/3*np.sum(direct**2,axis=(1,2)))
    mean=np.average(direct,axis=0,weights=weights)
    mean_eq=np.sqrt(2/3*np.sum(mean**2))
    result=initial_stress_response(angles,beta,m,weights)
    np.testing.assert_allclose(result['chi'],-direct[:,2,2]/local_eq)
    np.testing.assert_allclose(result['k'],-direct[:,2,2]/mean_eq)
    # Any COMMON positive CRSS/stress/reference-rate multiplier cancels.
    scaled=direct*1.e23
    scaled_mean=np.average(scaled,axis=0,weights=weights)
    np.testing.assert_allclose(result['k'],-scaled[:,2,2]/np.sqrt(2/3*np.sum(scaled_mean**2)))
    np.testing.assert_allclose(np.trace(result['A'],axis1=1,axis2=2),0,atol=1e-14)


def test_cube_uniaxial_and_equibiaxial_symmetry():
    for m in (.005,.05,.2,1.):
        for beta,chi in [(0.,.5),(1.,1.)]:
            result=initial_stress_response(np.zeros((1,3)),beta,m)
            np.testing.assert_allclose(result['chi'],chi,atol=1e-12)
            np.testing.assert_allclose(result['k'],chi,atol=1e-12)


def test_extreme_rate_sensitivity_remains_finite_and_preserves_relative_amplitude():
    angles=np.array([[.2,.4,.8],[1.1,.9,.3],[.7,.6,1.2]])
    result=initial_stress_response(angles,-.5,.001)
    assert np.isfinite(result['chi']).all() and np.isfinite(result['k']).all()
    assert np.ptp(result['grain_amplitude'])>0
    assert np.ptp(result['k'])>0
    assert np.all(np.abs(result['chi'])<=1+1e-12)


def test_m_beta_and_volume_changes_are_distinct():
    angles=np.array([[.2,.4,.8],[1.1,.9,.3],[.7,.6,1.2]])
    first=initial_stress_response(angles,.2,.05)
    weighted=initial_stress_response(angles,.2,.05,[1,10,1])
    np.testing.assert_allclose(first['chi'],weighted['chi'])
    assert not np.allclose(first['k'],weighted['k'])
    assert not np.allclose(first['chi'],initial_stress_response(angles,.8,.05)['chi'])
    assert not np.allclose(first['chi'],initial_stress_response(angles,.2,.2)['chi'])


@pytest.mark.parametrize('kwargs',[{'m':0},{'m':np.nan},{'beta':np.inf},{'volumes':[0]}])
def test_invalid_physical_parameters(kwargs):
    params=dict(beta=0.,m=.05);params.update(kwargs)
    with pytest.raises(ValueError):initial_stress_response(np.zeros((1,3)),**params)


def test_initial_brick_volumes(tmp_path):
    cube=np.array([[0,0,0],[1,0,0],[1,1,0],[0,1,0],[0,0,1],[1,0,1],[1,1,1],[0,1,1]],float)
    xyz=np.vstack([cube,cube*np.array([2,1,1])+[2,0,0]])
    pd.DataFrame({'node_id':np.arange(1,17),'x':xyz[:,0],'y':xyz[:,1],'z':xyz[:,2]}).to_csv(tmp_path/'nodes.csv',index=False)
    elements=pd.DataFrame({'element_id':[1,2],'part_id':[4,9],**{f'node_id_{i}':[i,i+8] for i in range(1,9)}})
    elements.to_csv(tmp_path/'elements.csv',index=False)
    volume=initial_grain_volumes(tmp_path)
    assert volume.part_id.tolist()==[4,9]
    np.testing.assert_allclose(volume.initial_volume,[1,2])


@pytest.mark.parametrize('beta',[-.5,0.,.5,1.])
def test_directional_responses_preserve_incompressibility(beta):
    response=initial_stress_response(np.array([[.2,.4,.8],[1.1,.9,.3]]),beta,.05)
    np.testing.assert_allclose(response['k_rd']+response['k_td'],response['k'],atol=1.e-12)


@pytest.mark.parametrize('rho',[-.5,0.,.5,1.])
@pytest.mark.parametrize('m',[.005,.05,.2])
def test_automatic_stress_ratio_matches_initial_mean_strain(rho,m):
    from src.crystal_plasticity.stress_response import stress_ratio_for_strain_ratio
    angles=np.array([[.2,.4,.8],[1.1,.9,.3],[.7,.6,1.2]])
    volumes=[1.,2.,4.]
    beta=stress_ratio_for_strain_ratio(angles,rho,m,volumes)
    mean=initial_stress_response(angles,beta,m,volumes)['mean_A']
    assert mean[0,0]>0
    np.testing.assert_allclose(mean[1,1]/mean[0,0],rho,atol=1.e-7)
