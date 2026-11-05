import numpy as np
from src.crystal_plasticity.taylor_factor import (
    bunge_sample_to_crystal, taylor_factor, primal_check,
)


def test_known_fcc_axes():
    # Uniaxial [100] and [111]: sqrt(6), 3 sqrt(6)/2.
    e=np.array([[0,0,0],[0,np.arccos(1/np.sqrt(3)),np.pi/4]])
    np.testing.assert_allclose(taylor_factor(e,1),[np.sqrt(6),3*np.sqrt(6)/2],atol=1e-10)
    np.testing.assert_allclose(taylor_factor([[0,0,0]],0),[3/np.sqrt(2)],atol=1e-10)


def test_rotation_and_primal_dual_agreement():
    e=np.random.default_rng(51).uniform(0,2*np.pi,(25,3))
    g=bunge_sample_to_crystal(e)
    np.testing.assert_allclose(g@np.swapaxes(g,-1,-2),np.broadcast_to(np.eye(3),g.shape),atol=1e-14)
    for rho in [-.5,0,.001,1]:
        np.testing.assert_allclose(taylor_factor(e,rho),primal_check(e,rho),atol=1e-10)
        # Rotate specimen by 180 degrees around z: diagonal strain unchanged.
        shifted=e.copy(); shifted[:,0]+=np.pi
        np.testing.assert_allclose(taylor_factor(e,rho),taylor_factor(shifted,rho),atol=1e-10)
