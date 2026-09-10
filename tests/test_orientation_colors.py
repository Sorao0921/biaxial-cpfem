import numpy as np
from src.crystal_plasticity.orientation_colors import (
    relative_rotation,axis_angle_rgb,ipf_nd_rgb,cubic_rotations,
)


def test_cube_nd_twist_visible_but_ipf_invariant():
    e=np.deg2rad([[0,0,0],[2,0,0],[-2,0,0],[90,0,0]])
    axis,angle=relative_rotation(e,'cube')
    np.testing.assert_allclose(angle,[0,2,2,0],atol=1e-12)
    np.testing.assert_allclose(axis[1:3],[[0,0,1],[0,0,-1]],atol=1e-12)
    np.testing.assert_allclose(ipf_nd_rgb(e),np.tile([1,0,0],(4,1)))
    rgb=axis_angle_rgb(axis,angle)
    assert np.linalg.norm(rgb[1]-rgb[2])>.25
    np.testing.assert_allclose(rgb[[0,3]],.88,atol=1e-12)


def test_crystal_symmetry_and_shared_contrast():
    assert len(cubic_rotations())==24
    e=np.deg2rad([[10,20,30],[40,50,60]])
    equivalent=e.copy();equivalent[:,2]+=np.pi/2
    a,t=relative_rotation(e,'brass'); b,u=relative_rotation(equivalent,'brass')
    np.testing.assert_allclose(t,u,atol=1e-10)
    np.testing.assert_allclose(a,b,atol=1e-10)
    whole=axis_angle_rgb(a,t)
    np.testing.assert_allclose(whole[:1],axis_angle_rgb(a[:1],t[:1]))
    # Small angles get more contrast than a linear scale; no per-map rescaling.
    amplified=axis_angle_rgb([[1,0,0]],[2],exponent=.35)
    linear=axis_angle_rgb([[1,0,0]],[2],exponent=1)
    assert np.linalg.norm(amplified-.88)>np.linalg.norm(linear-.88)
