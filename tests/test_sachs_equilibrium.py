import numpy as np
import pandas as pd
import pytest
from src.theme1.sachs_equilibrium import (SIGNS,brick_operators,elastic_matrix,engineering_strain,
    prepare_mesh,solve_eigenstrain,predict_equilibrium_from_initial)


def mesh_frames(nx=3,ny=3,nz=2):
    xyz=np.array([[x,y,z] for z in np.linspace(0,.2,nz+1) for y in np.linspace(0,1,ny+1) for x in np.linspace(0,1,nx+1)])
    def node(x,y,z):return z*(ny+1)*(nx+1)+y*(nx+1)+x+1
    records=[]
    for z in range(nz):
        for y in range(ny):
            for x in range(nx):
                conn=[node(x+int(a),y+int(b),z+int(c)) for a,b,c in (SIGNS+1)/2]
                records.append({'element_id':len(records)+1,'part_id':1+(x>=nx//2),**dict(zip([f'node_id_{i}' for i in range(1,9)],conn))})
    nodes=pd.DataFrame(xyz,columns=['x','y','z']);nodes.insert(0,'node_id',np.arange(1,len(nodes)+1))
    return nodes,pd.DataFrame(records)


def test_brick_affine_energy_and_rigid_modes():
    xyz=(SIGNS+1)/2;xyz[:,2]*=.2
    k,load,v=brick_operators(xyz,.3)
    strain=np.array([[.02,.003,.001],[.003,-.01,.004],[.001,.004,-.01]])
    u=(xyz@strain.T).ravel();eps=engineering_strain(strain)
    np.testing.assert_allclose(u@k@u,v*eps@elastic_matrix(.3)@eps,rtol=1.e-12)
    np.testing.assert_allclose(k@u,load@eps,atol=1.e-15)
    np.testing.assert_allclose(k,k.T,atol=1.e-15)
    for axis in range(3):
        translation=np.tile(np.eye(3)[axis],(8,1)).ravel()
        rotation=np.cross(np.eye(3)[axis],xyz).ravel()
        np.testing.assert_allclose(k@translation,0.,atol=1.e-14)
        np.testing.assert_allclose(k@rotation,0.,atol=1.e-14)
    assert np.count_nonzero(np.linalg.eigvalsh(k)<1.e-10)==6


@pytest.mark.parametrize('rho',[-.5,0.,1.])
def test_uniform_eigenstrain_recovers_affine_deformation_and_free_equilibrium(rho):
    nodes,elements=mesh_frames();mesh=prepare_mesh(nodes,elements,multigrid=False)
    d=np.array([1.,rho,-1-rho]);d/=np.sqrt(2/3*d@d)
    strain=.05;eps=np.tile(np.diag(d)*strain,(len(elements),1,1))
    result=solve_eigenstrain(mesh,eps,rho=rho,strain=strain,rtol=1.e-10)
    np.testing.assert_allclose(result['displacements'][['ux','uy','uz']],nodes[['x','y','z']].to_numpy()*d*strain,atol=2.e-10)
    assert result['metadata']['relative_free_force_residual']<1.e-9
    assert result['metadata']['free_force_norm_E1']<1.e-10


def test_shear_components_change_surface_response_and_force_is_balanced():
    nodes,elements=mesh_frames();mesh=prepare_mesh(nodes,elements,multigrid=False)
    tensors=np.zeros((len(elements),3,3))
    base=solve_eigenstrain(mesh,tensors,rho=-.5,strain=.03)
    tensors[elements.part_id.eq(2),0,2]=.02;tensors[:,2,0]=tensors[:,0,2]
    shear=solve_eigenstrain(mesh,tensors,rho=-.5,strain=.03)
    assert np.ptp(shear['coordinates'].z.to_numpy()-base['coordinates'].z.to_numpy())>1.e-5
    assert shear['metadata']['relative_free_force_residual']<5.e-8
    # Explicit bottom support and natural, unconstrained top ND DOFs.
    assert np.all(shear['displacements'].loc[nodes.z.eq(0),'uz']==0)


def test_predict_initial_only_and_zero_strain(tmp_path):
    nodes,elements=mesh_frames();nodes.to_csv(tmp_path/'nodes.csv',index=False);elements.to_csv(tmp_path/'elements.csv',index=False)
    angle=tmp_path/'orientation.csv';np.savetxt(angle,[[.2,.4,.8],[1.1,.9,.3]],delimiter=',')
    before=nodes.copy(deep=True)
    result=predict_equilibrium_from_initial(angle,tmp_path,rho=-.5,strain=0.)
    np.testing.assert_allclose(result['coordinates'][['x','y','z']],nodes.loc[nodes.z.eq(.2),['x','y','z']])
    assert result['metadata']['fit_to_simulation'] is False
    assert result['metadata']['stress_redistribution_updates_slip'] is False
    assert len(result['initial_tensors'])==2
    pd.testing.assert_frame_equal(nodes,before)
    # Common modulus cannot change displacement with the same eigenstrain/BCs.
    a=predict_equilibrium_from_initial(angle,tmp_path,rho=-.5,strain=.03,young=1.)
    b=predict_equilibrium_from_initial(angle,tmp_path,rho=-.5,strain=.03,young=69000.)
    np.testing.assert_allclose(a['coordinates'],b['coordinates'])


def test_invalid_or_inverted_mesh_is_rejected():
    with pytest.raises(ValueError):brick_operators(np.zeros((8,3)),.3)
    with pytest.raises(ValueError):elastic_matrix(.5)
    nodes,elements=mesh_frames();elements.loc[0,'node_id_1']=9999
    with pytest.raises(ValueError):prepare_mesh(nodes,elements,multigrid=False)


def test_linear_validity_is_reported_separately_without_clipping():
    nodes,elements=mesh_frames(1,1,1);mesh=prepare_mesh(nodes,elements,multigrid=False)
    strain=np.tile(np.diag([5.,5.,-10.]),(len(elements),1,1))
    result=solve_eigenstrain(mesh,strain,rho=-.5,strain=0.)
    assert result['metadata']['relative_free_force_residual']<1.e-7
    assert result['metadata']['finite_geometry_valid'] is False
    assert result['metadata']['inverted_deformed_elements']>0
    assert (result['coordinates'].z<0).all()


def test_cli_finishes_both_predictions_before_opening_actual(tmp_path,monkeypatch):
    from types import SimpleNamespace
    import tools.theme1.compare_sachs_equilibrium as cli
    import matplotlib.pyplot as plt
    events=[]
    coordinates=pd.DataFrame({'node_id':[1,2,3],'x':[0.,1.,0.],'y':[0.,0.,1.],'z':[.1,.2,.3]})
    meta={'beta':0.,'finite_geometry_valid':True,'relative_free_force_residual':1.e-10,'iterations':2,
          'inverted_deformed_elements':0,'maximum_eigenstrain_norm':.03}
    def graph(*a,**kw):events.append('graph');return {'coordinates':coordinates,'metadata':{}}
    def eq(*a,**kw):events.append('equilibrium');return {'coordinates':coordinates,'metadata':meta}
    def save_graph(prediction,path):events.append('save_graph');path.mkdir(parents=True)
    def save_eq(prediction,path):events.append('save_equilibrium');path.mkdir(parents=True)
    def actual(path):
        assert events==['graph','equilibrium','save_graph','save_equilibrium']
        events.append('actual');return coordinates
    record=SimpleNamespace(rho=-.5,seed=1,texture='brass',sd=8,path=tmp_path/'unread.csv')
    monkeypatch.setattr(cli,'scan_outputs',lambda path:[])
    monkeypatch.setattr(cli,'filter_records',lambda *a,**kw:[record])
    monkeypatch.setattr(cli,'predict_from_initial',graph);monkeypatch.setattr(cli,'predict_equilibrium_from_initial',eq)
    monkeypatch.setattr(cli,'save_prediction',save_graph);monkeypatch.setattr(cli,'save_equilibrium',save_eq)
    monkeypatch.setattr(cli,'_read_height',actual)
    monkeypatch.setattr(cli,'coordinate_height_figure',lambda *a,**kw:plt.figure())
    assert cli.main(['--output-dir',str(tmp_path/'results')])==0
    assert events[-1]=='actual'


def test_distorted_brick_gradient_and_energy_patch():
    affine=np.array([[1.1,.2,.1],[.15,.9,.1],[.02,.01,.3]])
    xyz=((SIGNS+1)/2)@affine.T
    k,load,volume=brick_operators(xyz,.3)
    grad=np.array([[.01,.02,-.01],[.015,-.02,.03],[.04,-.02,.01]])
    u=(xyz@grad.T).ravel();eps=engineering_strain((grad+grad.T)/2)
    np.testing.assert_allclose(k@u,load@eps,atol=1.e-14)
    np.testing.assert_allclose(u@k@u,volume*eps@elastic_matrix(.3)@eps,rtol=1.e-12)


def test_partial_constraint_preserves_volume_mean_and_trace():
    from src.theme1.sachs_equilibrium import relax_eigenstrain
    rng=np.random.default_rng(14)
    a=rng.normal(size=(4,3,3));a=(a+a.transpose(0,2,1))/2
    a-=np.trace(a,axis1=1,axis2=2)[:,None,None]*np.eye(3)/3
    weights=np.array([1.,2.,3.,4.]);mean=np.average(a,weights=weights,axis=0)
    relaxed=relax_eigenstrain(a,weights,.75)
    np.testing.assert_allclose(np.average(relaxed,weights=weights,axis=0),mean,atol=1.e-14)
    np.testing.assert_allclose(np.trace(relaxed,axis1=1,axis2=2),0.,atol=1.e-14)
    np.testing.assert_allclose(relaxed-mean,.75*(a-mean),atol=1.e-14)
    np.testing.assert_allclose(relax_eigenstrain(a,weights,1.),a,atol=1.e-14)
    np.testing.assert_allclose(relax_eigenstrain(a,weights,0.),np.broadcast_to(mean,a.shape))
    with pytest.raises(ValueError):relax_eigenstrain(a,weights,1.1)


def test_partial_constraint_reduces_displacement_heterogeneity_with_equilibrium():
    from src.theme1.sachs_equilibrium import relax_eigenstrain
    nodes,elements=mesh_frames();mesh=prepare_mesh(nodes,elements,multigrid=False)
    a=np.zeros((len(elements),3,3));a[elements.part_id.eq(2),0,2]=.02;a[:,2,0]=a[:,0,2]
    solutions=[]
    for eta in [0.,.75,1.]:
        result=solve_eigenstrain(mesh,relax_eigenstrain(a,mesh['volumes'],eta),rho=-.5,strain=.03,rtol=1.e-10)
        solutions.append(result['displacements'][['ux','uy','uz']].to_numpy())
        assert result['metadata']['relative_free_force_residual']<1.e-9
    np.testing.assert_allclose(solutions[1],solutions[0]+.75*(solutions[2]-solutions[0]),atol=1.e-10)
