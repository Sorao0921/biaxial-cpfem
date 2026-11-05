"""Frozen initial Sachs eigenstrain + 3D small-strain elastic equilibrium.

No simulation outputs/history enter this API. Homogeneous isotropic elasticity,
fully integrated eight-node bricks, side-normal displacement control, bottom
ND support, natural traction-free top. This is a one-way eigenstrain solve,
not an incremental crystal-plasticity constitutive model.
"""
from functools import lru_cache
from itertools import product
from pathlib import Path
import time

import numpy as np
import pandas as pd

from src.crystal_plasticity.stress_response import initial_stress_response,stress_ratio_for_strain_ratio

SIGNS=np.array([[-1,-1,-1],[1,-1,-1],[1,1,-1],[-1,1,-1],
                [-1,-1,1],[1,-1,1],[1,1,1],[-1,1,1]],float)
VOIGT=('xx','yy','zz','yz','xz','xy')


def elastic_matrix(poisson):
    if not np.isfinite(poisson) or not -1<poisson<.49:
        raise ValueError('Poisson ratio must be between -1 and 0.49')
    mu=1/(2*(1+poisson));lam=poisson/((1+poisson)*(1-2*poisson))
    matrix=np.zeros((6,6));matrix[:3,:3]=lam
    matrix[np.arange(3),np.arange(3)]+=2*mu
    matrix[np.arange(3,6),np.arange(3,6)]=mu
    return matrix


def engineering_strain(tensors):
    a=np.asarray(tensors,float)
    return np.stack([a[...,0,0],a[...,1,1],a[...,2,2],2*a[...,1,2],2*a[...,0,2],2*a[...,0,1]],axis=-1)


def relax_eigenstrain(tensors,volumes,heterogeneity):
    """Convex mean-preserving interpolation toward uniform plastic strain.

    This is a prescribed partial-constraint hypothesis, not a fitted law.
    Retain every tensor component and trace; never scale z independently.
    """
    a=np.asarray(tensors,float);weights=np.asarray(volumes,float)
    if not np.isfinite(heterogeneity) or not 0<=heterogeneity<=1:
        raise ValueError('Eigenstrain heterogeneity must be between 0 and 1')
    if a.ndim!=3 or a.shape[1:]!=(3,3) or weights.shape!=(len(a),) or not np.isfinite(a).all() or not np.isfinite(weights).all() or (weights<=0).any():
        raise ValueError('Invalid eigenstrain tensors or initial volumes')
    mean=np.einsum('g,gij->ij',weights/weights.sum(),a)
    return mean+heterogeneity*(a-mean)


def brick_operators(xyz,poisson):
    """Return K(24,24), integral B.T C(24,6), volume; C uses E=1.

    B uses engineering shears [xx,yy,zz,2yz,2xz,2xy]. Eight Gauss points
    prevent one-point hourglass modes. Coordinates may be distorted bricks.
    """
    xyz=np.asarray(xyz,float)
    if xyz.shape!=(8,3) or not np.isfinite(xyz).all():raise ValueError('Invalid brick coordinates')
    c=elastic_matrix(poisson);ke=np.zeros((24,24));load=np.zeros((24,6));volume=0.
    for point in product((-1/np.sqrt(3),1/np.sqrt(3)),repeat=3):
        factors=1+SIGNS*np.asarray(point)
        derivatives=np.column_stack([SIGNS[:,i]*np.prod(factors[:,[j for j in range(3) if j!=i]],axis=1)/8 for i in range(3)])
        jac=xyz.T@derivatives;det=float(np.linalg.det(jac))
        if not np.isfinite(det) or det<=0:raise ValueError('Nonpositive initial brick Jacobian')
        gradients=derivatives@np.linalg.inv(jac)
        b=np.zeros((6,24));dx,dy,dz=gradients.T
        b[0,0::3]=dx;b[1,1::3]=dy;b[2,2::3]=dz
        b[3,1::3]=dz;b[3,2::3]=dy
        b[4,0::3]=dz;b[4,2::3]=dx
        b[5,0::3]=dy;b[5,1::3]=dx
        load+=b.T@c*det;ke+=b.T@c@b*det;volume+=det
    return (ke+ke.T)/2,load,volume


def prescribed_boundary(xyz,rho,strain):
    if not np.isfinite([rho,strain]).all() or strain<0:raise ValueError('Invalid prescribed loading')
    low=xyz.min(axis=0);high=xyz.max(axis=0);length=high-low
    if (length<=0).any():raise ValueError('Initial mesh must have positive 3D extent')
    direction=np.array([1.,rho,-1.-rho]);direction/=np.sqrt(2/3*np.dot(direction,direction))
    fixed=np.zeros(xyz.shape,bool);u=np.zeros(xyz.shape)
    for axis in (0,1):
        lower=np.isclose(xyz[:,axis],low[axis],rtol=0,atol=length[axis]*1.e-9)
        upper=np.isclose(xyz[:,axis],high[axis],rtol=0,atol=length[axis]*1.e-9)
        fixed[lower|upper,axis]=True
        u[upper,axis]=strain*direction[axis]*length[axis]
    bottom=np.isclose(xyz[:,2],low[2],rtol=0,atol=length[2]*1.e-9)
    fixed[bottom,2]=True
    return fixed.ravel(),u.ravel(),direction


def prepare_mesh(nodes,elements,poisson=.3,*,multigrid=True):
    """Assemble mesh-dependent operator only. No orientation/history input."""
    from scipy import sparse
    required=['node_id','x','y','z']
    if set(required)-set(nodes) or nodes.node_id.duplicated().any():raise ValueError('Invalid initial nodes')
    nodes=nodes.sort_values('node_id').reset_index(drop=True).copy()
    xyz=nodes[['x','y','z']].to_numpy(float)
    if not len(nodes) or not np.isfinite(xyz).all():raise ValueError('Invalid initial coordinates')
    columns=[f'node_id_{i}' for i in range(1,9)]
    if set(columns+['part_id','element_id'])-set(elements) or elements.element_id.duplicated().any():raise ValueError('Invalid initial elements')
    ids=nodes.node_id.to_numpy();raw=elements[columns].to_numpy(int)
    if not np.isin(raw,ids).all():raise ValueError('Missing initial element node')
    conn=np.searchsorted(ids,raw)
    if any(len(set(row))!=8 for row in conn):raise ValueError('Repeated brick node')
    relative=xyz[conn]-xyz[conn[:,0],None,:]
    # Group translation-identical bricks at roundoff precision; do not coarsen.
    _,first,kind=np.unique(np.round(relative.reshape(len(conn),24),14),axis=0,return_index=True,return_inverse=True)
    operators=[brick_operators(xyz[conn[i]],poisson) for i in first]
    ke=np.array([x[0] for x in operators]);load=np.array([x[1] for x in operators]);volumes=np.array([x[2] for x in operators])[kind]
    dofs=(conn[:,:,None]*3+np.arange(3)).reshape(len(conn),24).astype(np.int32)
    ndof=3*len(nodes);levels=[]
    # Merge sparse chunks as a binary tree to bound peak memory.
    for start in range(0,len(conn),1024):
        local=dofs[start:start+1024];count=len(local)
        rr=np.repeat(local,24,axis=1).ravel();cc=np.tile(local,(1,24)).ravel()
        chunk=sparse.coo_matrix((ke[kind[start:start+count]].ravel(),(rr,cc)),shape=(ndof,ndof)).tocsr()
        level=0
        while level<len(levels) and levels[level] is not None:
            chunk=chunk+levels[level];levels[level]=None;level+=1
        if level==len(levels):levels.append(chunk)
        else:levels[level]=chunk
    stiffness=sum((x for x in levels if x is not None),sparse.csr_matrix((ndof,ndof)))
    stiffness.eliminate_zeros()
    if (stiffness.diagonal()<=0).any():raise ValueError('Unconnected mesh DOF')
    fixed,_,_=prescribed_boundary(xyz,0.,0.);free=np.flatnonzero(~fixed)
    reduced=stiffness[free][:,free].tocsr();preconditioner=None;hierarchy=None
    if multigrid:
        from pyamg import smoothed_aggregation_solver
        rigid=np.zeros((len(nodes),3,6));rigid[:,:,:3]=np.eye(3)
        centered=xyz-xyz.mean(axis=0)
        for axis in range(3):rigid[:,:,axis+3]=np.cross(np.eye(3)[axis],centered)
        hierarchy=smoothed_aggregation_solver(reduced,B=rigid.reshape(ndof,6)[free],symmetry='symmetric',max_coarse=200)
        preconditioner=hierarchy.aspreconditioner()
    return dict(nodes=nodes,xyz=xyz,conn=conn,dofs=dofs,kind=kind,loads=load,volumes=volumes,
                elements=elements.copy(),stiffness=stiffness,free=free,fixed=fixed,reduced=reduced,
                preconditioner=preconditioner,hierarchy=hierarchy,poisson=float(poisson))


def solve_eigenstrain(mesh,eigenstrain,*,rho,strain,rtol=1.e-8,maxiter=2000):
    """Solve K u = integral B.T C eps_p with prescribed side displacements."""
    from scipy.sparse.linalg import cg,LinearOperator
    tensors=np.asarray(eigenstrain,float)
    if tensors.shape!=(len(mesh['conn']),3,3) or not np.isfinite(tensors).all():raise ValueError('Invalid element eigenstrain')
    if not np.allclose(tensors,tensors.transpose(0,2,1),atol=1.e-12):raise ValueError('Eigenstrain must be symmetric')
    if not np.isfinite(rtol) or not 0<rtol<1 or maxiter<1:raise ValueError('Invalid solve tolerance')
    local=np.einsum('eij,ej->ei',mesh['loads'][mesh['kind']],engineering_strain(tensors))
    force=np.bincount(mesh['dofs'].ravel(),weights=local.ravel(),minlength=len(mesh['xyz'])*3)
    fixed,u,direction=prescribed_boundary(mesh['xyz'],rho,strain);free=mesh['free']
    if not np.array_equal(fixed,mesh['fixed']):raise ValueError('Boundary topology changed')
    rhs=(force-mesh['stiffness']@u)[free];iterations=0
    def step(_):
        nonlocal iterations
        iterations+=1
    pre=mesh['preconditioner']
    if pre is None:
        diagonal=mesh['reduced'].diagonal();pre=LinearOperator(mesh['reduced'].shape,matvec=lambda x:x/diagonal)
    if np.linalg.norm(rhs)>0:
        solution,info=cg(mesh['reduced'],rhs,M=pre,rtol=rtol,atol=0.,maxiter=maxiter,callback=step)
        residual=float(np.linalg.norm(mesh['reduced']@solution-rhs)/np.linalg.norm(rhs))
        if info!=0 or residual>max(5*rtol,1.e-10):raise ValueError(f'Equilibrium did not converge: info={info}, relative residual={residual:g}')
        u[free]=solution
    else:residual=0.
    deformed=mesh['xyz']+u.reshape(-1,3)
    if not np.isfinite(deformed).all():raise ValueError('Nonfinite equilibrium displacement')
    # A linear solve can converge even when extrapolation to finite geometry
    # is invalid. Keep the unmodified linear field and report this separately.
    inverted=np.zeros(len(mesh['conn']),bool);minimum_jacobian_ratio=float('inf')
    for start in range(0,len(mesh['conn']),4096):
        block=deformed[mesh['conn'][start:start+4096]]
        original=mesh['xyz'][mesh['conn'][start:start+4096]]
        for point in product((-1/np.sqrt(3),1/np.sqrt(3)),repeat=3):
            factors=1+SIGNS*np.asarray(point)
            derivatives=np.column_stack([SIGNS[:,i]*np.prod(factors[:,[j for j in range(3) if j!=i]],axis=1)/8 for i in range(3)])
            ratios=np.linalg.det(np.einsum('eai,aj->eij',block,derivatives))/np.linalg.det(np.einsum('eai,aj->eij',original,derivatives))
            inverted[start:start+len(block)]|=ratios<=0
            minimum_jacobian_ratio=min(minimum_jacobian_ratio,float(ratios.min()))
    frame=mesh['nodes'].copy()
    frame[['ux','uy','uz']]=u.reshape(-1,3);frame[['x_deformed','y_deformed','z_deformed']]=deformed
    top=np.isclose(mesh['xyz'][:,2],mesh['xyz'][:,2].max(),rtol=0,atol=np.ptp(mesh['xyz'][:,2])*1.e-9)
    display=deformed[top].copy()
    low=mesh['xyz'].min(axis=0)
    display[:,:2]=low[:2]+(mesh['xyz'][top,:2]-low[:2])*(1+strain*direction[:2])
    coordinates=pd.DataFrame(display,columns=['x','y','z']);coordinates.insert(0,'node_id',np.arange(1,top.sum()+1))
    balance=mesh['stiffness']@u-force
    return dict(coordinates=coordinates,displacements=frame,
                metadata={'solver':'C3D8, 2x2x2 Gauss integration, CG + algebraic multigrid',
                'iterations':iterations,'relative_free_force_residual':residual,'free_dofs':len(free),
                'fixed_dofs':int(fixed.sum()),'inverted_deformed_elements':int(inverted.sum()),
                'minimum_deformed_jacobian_ratio':minimum_jacobian_ratio,
                'finite_geometry_valid':bool(not inverted.any()),
                'maximum_eigenstrain_norm':float(np.linalg.norm(tensors,axis=(1,2)).max()),
                'surface_display_projection':'xy: prescribed affine small strain; z: solved initial z + uz; full deformed xyz in displacements',
                'free_force_norm_E1':float(np.linalg.norm(balance[free])),
                'prescribed_strain_direction':direction.tolist(),'converged':True})


@lru_cache(maxsize=1)
def _cached_mesh(root,node_stamp,element_stamp,poisson):
    path=Path(root)
    return prepare_mesh(pd.read_csv(path/'nodes.csv'),pd.read_csv(path/'elements.csv'),poisson)


@lru_cache(maxsize=8)
def _predict(orientation,orientation_stamp,root,node_stamp,element_stamp,rho,m,strain,poisson,young,heterogeneity,components):
    started=time.perf_counter();mesh=_cached_mesh(root,node_stamp,element_stamp,poisson)
    elements=mesh['elements'];pids=elements.part_id.to_numpy(int)
    volume=pd.DataFrame({'part_id':pids,'volume':mesh['volumes']}).groupby('part_id',sort=True).volume.sum()
    angles=np.loadtxt(orientation,delimiter=',',ndmin=2);ids=volume.index.to_numpy(int)
    if (ids<1).any() or (ids>len(angles)).any():raise ValueError('Missing initial orientation')
    beta=stress_ratio_for_strain_ratio(angles[ids-1],rho,m,volume.to_numpy())
    response=initial_stress_response(angles[ids-1],beta,m,volume.to_numpy())
    direction=np.array([1.,rho,-1.-rho]);direction/=np.sqrt(2/3*np.dot(direction,direction))
    scale=strain*direction[0]/response['mean_A'][0,0]
    unrelaxed=response['A']*scale
    grain_strain=relax_eigenstrain(unrelaxed,volume.to_numpy(),heterogeneity)
    if components=='diagonal':
        grain_strain=grain_strain*np.eye(3)[None,:,:]
    element_strain=grain_strain[np.searchsorted(ids,pids)]
    result=solve_eigenstrain(mesh,element_strain,rho=rho,strain=strain)
    tensors=pd.DataFrame({'part_id':ids,'initial_volume':volume.to_numpy(),'k':response['k']})
    for a,b,name in [(0,0,'xx'),(1,1,'yy'),(2,2,'zz'),(1,2,'yz'),(0,2,'xz'),(0,1,'xy')]:
        tensors['plastic_strain_'+name]=grain_strain[:,a,b]
        tensors['unrelaxed_plastic_strain_'+name]=unrelaxed[:,a,b]
    result['initial_tensors']=tensors
    result['metadata'].update(model=('Frozen initial Sachs diagonal tensor' if components=='diagonal' else 'Frozen initial Sachs full tensor')+' + 3D linear elastic eigenstrain equilibrium v2',
        rho=rho,beta=beta,m=m,prescribed_strain=strain,poisson=poisson,young_modulus=young,
        tensor_components=components,component_ablation='off-diagonal eigenstrains zeroed after identical initial response/relaxation' if components=='diagonal' else 'none',
        eigenstrain_heterogeneity=heterogeneity,
        heterogeneity_rule="mean + eta*(initial Sachs eigenstrain - mean); all tensor components; prescribed, not fitted",
        elasticity='homogeneous isotropic; common E cancels from displacement under displacement loading',
        boundary='ux=0/xmax prescribed on xmin/xmax; uy=0/ymax prescribed on ymin/ymax; uz=0 on bottom; top traction-free',
        kinematics='one-step small strain: x_new=x+u; no exponential mean-height reset or amplitude fitting',
        eigenstrain_scale='eps_p_i = prescribed_RD_strain * A_i / volume_mean(A)_xx; full symmetric tensor retained',
        plastic_mean_strain=(np.einsum('g,gij->ij',volume.to_numpy()/volume.sum(),grain_strain)).tolist(),
        stress_model_mean_strain_ratio=float(response['mean_A'][1,1]/response['mean_A'][0,0]),
        initial_nodes=len(mesh['nodes']),initial_elements=len(elements),fit_to_simulation=False,
        frozen_initial_orientation=True,stress_redistribution_updates_slip=False,
        orientation_source=str(Path(orientation).resolve()),initial_model_source=str(Path(root).resolve()),
        input_versions={'orientation':orientation_stamp,'nodes':node_stamp,'elements':element_stamp},
        elapsed_seconds=time.perf_counter()-started)
    return result


def predict_equilibrium_from_initial(orientation_path,model_dir,*,rho,m=.05,strain=.1,poisson=.3,young=69000.,heterogeneity=.75,components='full'):
    """Initial inputs + prescribed constants only; no actual-state argument."""
    if not np.isfinite([rho,m,strain,poisson,young,heterogeneity]).all() or m<=0 or strain<0 or young<=0 or not 0<=heterogeneity<=1:
        raise ValueError('Invalid prescribed equilibrium parameters')
    if components not in ('full','diagonal'):raise ValueError('Unknown eigenstrain component selection')
    elastic_matrix(poisson)
    orientation=Path(orientation_path).resolve();root=Path(model_dir).resolve()
    return _predict(str(orientation),orientation.stat().st_mtime_ns,str(root),
        (root/'nodes.csv').stat().st_mtime_ns,(root/'elements.csv').stat().st_mtime_ns,
        float(rho),float(m),float(strain),float(poisson),float(young),float(heterogeneity),components)
