"""Initial-only scalar D / boundary-tangential tensor mismatch Q hypotheses.

D=K-neighbor_mean(K). Q=sum_f w_f ||P_f (eps_i-eps_j) P_f||_F^2.
Q is unsigned: it modulates a stated constraint hypothesis, never valley sign.
The two reduced models use identical geometry, loading and height conversion;
Q coupling=0 exactly recovers the K-only baseline. No CPFEM data enter here.
"""
from functools import lru_cache
from pathlib import Path
import numpy as np
import pandas as pd
from src.crystal_plasticity.stress_response import initial_stress_response,stress_ratio_for_strain_ratio
from src.theme1.neighbor_height import _surface_inputs
from src.theme1.sachs_equilibrium import relax_eigenstrain

FACE_LOCAL=np.array([[0,3,2,1],[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]])
TENSOR_COMPONENTS=[(0,0,'xx'),(1,1,'yy'),(2,2,'zz'),(1,2,'yz'),(0,2,'xz'),(0,1,'xy')]


def initial_interfaces(nodes,elements,volumes):
    """True shared mesh faces, their normals and initial grain centroids.

    Boundary area/distance extends the old surface length/distance rule to 3D.
    Keep individual normals: averaging a stair-step boundary loses Q information.
    """
    nodes=nodes.sort_values('node_id');ids=nodes.node_id.to_numpy(int)
    xyz=nodes[['x','y','z']].to_numpy(float)
    raw=elements[[f'node_id_{k}' for k in range(1,9)]].to_numpy(int)
    if not np.isin(raw,ids).all():raise ValueError('Initial element contains missing node')
    conn=np.searchsorted(ids,raw);pids=elements.part_id.to_numpy(int)
    # Element centers are exact for the rectangular bricks in the initial mesh.
    centers=xyz[conn].mean(axis=1)
    ev=volumes.set_index('part_id').initial_volume
    # Volumes provided per grain; individual rectangular brick volumes below.
    ex=xyz[conn]
    determinant=np.linalg.det(np.stack([ex[:,1]-ex[:,0],ex[:,3]-ex[:,0],ex[:,4]-ex[:,0]],axis=2))
    if (determinant<=0).any():raise ValueError('Invalid initial brick')
    # This interface implementation deliberately requires affine bricks.
    expected=ex[:,0,None,:]+np.einsum('ai,eij->eaj',(np.array([[-1,-1,-1],[1,-1,-1],[1,1,-1],[-1,1,-1],[-1,-1,1],[1,-1,1],[1,1,1],[-1,1,1]])+1)/2,
        np.stack([ex[:,1]-ex[:,0],ex[:,3]-ex[:,0],ex[:,4]-ex[:,0]],axis=1))
    if not np.allclose(ex,expected,atol=1.e-10,rtol=1.e-9):raise ValueError('Mismatch geometry currently requires affine initial bricks')
    frame=pd.DataFrame({'part_id':pids,'v':determinant,'wx':centers[:,0]*determinant,'wy':centers[:,1]*determinant,'wz':centers[:,2]*determinant})
    grain=frame.groupby('part_id',sort=True).sum()
    if not np.allclose(grain.v,ev.loc[grain.index],rtol=1.e-8,atol=1.e-13):raise ValueError('Initial grain volumes do not match mesh')
    centroid=grain[['wx','wy','wz']].to_numpy()/grain.v.to_numpy()[:,None]
    lookup={int(pid):i for i,pid in enumerate(grain.index)}
    faces=conn[:,FACE_LOCAL].reshape(-1,4);owners=np.repeat(pids,6)
    canonical=np.sort(faces,axis=1)
    order=np.lexsort(canonical.T[::-1]);ordered=canonical[order]
    same=np.all(ordered[1:]==ordered[:-1],axis=1)
    if (same[1:]&same[:-1]).any():raise ValueError('Nonmanifold initial mesh face')
    shared=np.flatnonzero(same);left=order[shared];right=order[shared+1]
    different=owners[left]!=owners[right];left=left[different];right=right[different]
    if not len(left):return pd.DataFrame(columns=['part_id_i','part_id_j','area','distance','nx','ny','nz','weight'])
    qa=xyz[faces[left]]
    a=np.cross(qa[:,1]-qa[:,0],qa[:,2]-qa[:,0]);b=np.cross(qa[:,2]-qa[:,0],qa[:,3]-qa[:,0])
    normals=a+b;normals/=np.linalg.norm(normals,axis=1)[:,None]
    area=(np.linalg.norm(a,axis=1)+np.linalg.norm(b,axis=1))/2
    pairs=np.sort(np.column_stack([owners[left],owners[right]]),axis=1)
    i=np.array([lookup[int(pid)] for pid in pairs[:,0]]);j=np.array([lookup[int(pid)] for pid in pairs[:,1]])
    distance=np.linalg.norm(centroid[i]-centroid[j],axis=1)
    if (distance<=0).any() or (area<=0).any():raise ValueError('Invalid initial grain interface')
    weight=area/distance;weight/=weight.sum()
    return pd.DataFrame({'part_id_i':pairs[:,0],'part_id_j':pairs[:,1],'area':area,'distance':distance,
                         'nx':normals[:,0],'ny':normals[:,1],'nz':normals[:,2],'weight':weight})


def mismatch_indicators(part_ids,k,tensors,interfaces):
    ids=np.asarray(part_ids,int);k=np.asarray(k,float);eps=np.asarray(tensors,float)
    if len(np.unique(ids))!=len(ids) or k.shape!=(len(ids),) or eps.shape!=(len(ids),3,3) or not np.isfinite(k).all() or not np.isfinite(eps).all():
        raise ValueError('Invalid initial K/tensors')
    if not np.allclose(eps,eps.transpose(0,2,1),atol=1.e-12):raise ValueError('Expected symmetric free-deformation tensors')
    lookup={int(pid):i for i,pid in enumerate(ids)}
    degree=np.zeros(len(ids));neighbor=np.zeros(len(ids));q=np.zeros(len(ids));details=interfaces.copy()
    if len(details):
        try:
            i=np.array([lookup[int(pid)] for pid in details.part_id_i]);j=np.array([lookup[int(pid)] for pid in details.part_id_j])
        except KeyError as error:raise ValueError('Missing initial neighbor grain') from error
        n=details[['nx','ny','nz']].to_numpy(float);w=details.weight.to_numpy(float)
        if not np.isfinite(n).all() or not np.isfinite(w).all() or (w<=0).any() or not np.allclose(np.linalg.norm(n,axis=1),1.,atol=1.e-8):
            raise ValueError('Invalid interface normals/weights')
        projection=np.eye(3)-n[:,:,None]*n[:,None,:]
        jump=eps[i]-eps[j]
        tangent=projection@jump@projection
        norm_squared=np.einsum('fij,fij->f',tangent,tangent)
        np.add.at(degree,i,w);np.add.at(degree,j,w)
        np.add.at(neighbor,i,w*k[j]);np.add.at(neighbor,j,w*k[i])
        np.add.at(q,i,w*norm_squared);np.add.at(q,j,w*norm_squared)
        details['k_difference']=k[i]-k[j];details['tangential_mismatch_squared']=norm_squared
        details['q_contribution']=w*norm_squared
    neighbor=np.divide(neighbor,degree,out=k.copy(),where=degree>0)
    return pd.DataFrame({'part_id':ids,'k':k,'neighbor_k_mean':neighbor,'d':k-neighbor,'q':q,'interface_degree':degree}),details


@lru_cache(maxsize=4)
def _geometry(root,node_stamp,element_stamp):
    nodes,geometry,top_ids,surface,edges,volumes=_surface_inputs(root,node_stamp,element_stamp)
    elements=pd.read_csv(Path(root)/'elements.csv')
    return nodes,geometry,top_ids,surface,edges,volumes,initial_interfaces(nodes,elements,volumes)


def scalar_height(surface,edges,*,thickness,bottom,strain,rho,k_to_strain,heterogeneity,coupling,q_coupling,q_reference):
    """Signed D drive + unsigned Q restoring constraint; no 3D FE equilibrium."""
    values=np.array([thickness,bottom,strain,rho,k_to_strain,heterogeneity,coupling,q_coupling,q_reference])
    if not np.isfinite(values).all() or thickness<=0 or strain<0 or coupling<0 or q_coupling<0 or q_reference<0 or not 0<=heterogeneity<=1:
        raise ValueError('Invalid prescribed indicator model parameters')
    result=surface.copy();area=result.initial_area.to_numpy(float,copy=True);area/=area.sum()
    d=result.d.to_numpy(float);q=result.q.to_numpy(float)
    if not np.isfinite(d).all() or not np.isfinite(q).all() or (q<0).any():raise ValueError('Invalid D/Q')
    q_scaled=q/q_reference if q_reference>0 else np.zeros(len(result))
    matrix=np.diag(area*(1+q_coupling*q_scaled))
    index={int(pid):i for i,pid in enumerate(result.part_id)}
    weights=[];positions=result[['center_x','center_y']].to_numpy(float)
    for edge in edges.itertuples(index=False):
        i,j=index[int(edge.part_id_i)],index[int(edge.part_id_j)]
        delta=positions[i]-positions[j]
        distance=float(np.linalg.norm(delta))
        if distance<=0 or edge.weight<=0:raise ValueError('Invalid surface grain edge')
        weights.append((i,j,float(edge.weight)/distance))
    total=sum(w for _,_,w in weights)
    for i,j,raw in weights:
        weight=coupling*raw/total
        matrix[i,i]+=weight;matrix[j,j]+=weight;matrix[i,j]-=weight;matrix[j,i]-=weight
    target=-strain*k_to_strain*heterogeneity*d
    relief=np.linalg.solve(matrix,area*target);relief-=area@relief
    direction=np.array([1.,rho,-1.-rho]);direction/=np.sqrt(2/3*direction@direction)
    # Same small-strain macro convention as the 3D eigenstrain solve.
    macro=thickness*(1+strain*direction[2])
    result['q_scaled']=q_scaled;result['local_constraint']=1+q_coupling*q_scaled
    result['target_nd_strain_contrast']=target;result['height_relief_strain']=relief
    result['predicted_height_from_bottom']=macro+thickness*relief
    result['predicted_height_residual']=thickness*relief
    result['macro_thickness']=macro
    result['linear_height_positive']=result.predicted_height_from_bottom>0
    return result


@lru_cache(maxsize=12)
def _predict(orientation,orientation_stamp,root,node_stamp,element_stamp,rho,m,strain,heterogeneity,coupling,q_coupling):
    nodes,geometry,top_ids,surface,edges,volumes,interfaces=_geometry(root,node_stamp,element_stamp)
    angles=np.loadtxt(orientation,delimiter=',',ndmin=2);ids=volumes.part_id.to_numpy(int)
    if (ids<1).any() or (ids>len(angles)).any():raise ValueError('Missing initial orientation')
    v=volumes.initial_volume.to_numpy()
    beta=stress_ratio_for_strain_ratio(angles[ids-1],rho,m,v)
    response=initial_stress_response(angles[ids-1],beta,m,v)
    direction=np.array([1.,rho,-1.-rho]);direction/=np.sqrt(2/3*direction@direction)
    mean_eq=np.sqrt(2/3*np.sum(response['mean_A']**2))
    gain=direction[0]*mean_eq/response['mean_A'][0,0]
    free=strain*direction[0]*response['A']/response['mean_A'][0,0]
    tensors=relax_eigenstrain(free,v,heterogeneity)
    indicators,face_details=mismatch_indicators(ids,response['k'],tensors,interfaces)
    indicators=indicators.merge(volumes,on='part_id',validate='one_to_one')
    q_reference=float(np.average(indicators.q,weights=indicators.initial_volume))
    for a,b,name in TENSOR_COMPONENTS:indicators['free_strain_'+name]=tensors[:,a,b]
    initial=surface.merge(indicators,on='part_id',validate='one_to_one')
    predictions={}
    top=nodes.set_index('node_id').loc[top_ids].reset_index().sort_values('node_id')
    low=nodes[['x','y','z']].min().to_numpy()
    for name,gamma in [('k_only',0.),('d_q',q_coupling)]:
        grains=scalar_height(initial,edges,thickness=float(np.ptp(nodes.z)),bottom=float(low[2]),strain=strain,rho=rho,
            k_to_strain=float(gain),heterogeneity=heterogeneity,coupling=coupling,q_coupling=gamma,q_reference=q_reference)
        height=grains.set_index('part_id').predicted_height_from_bottom
        mass={int(pid):0. for pid in top.node_id};zsum=mass.copy()
        for face in geometry.itertuples(index=False):
            for k in range(4):
                node=int(getattr(face,f'top_node_{k}'));mass[node]+=face.area;zsum[node]+=face.area*(height.loc[face.part_id]+low[2])
        coordinates=top[['node_id','x','y','z']].copy()
        coordinates['z']=[zsum[int(node)]/mass[int(node)] for node in coordinates.node_id]
        coordinates['x']=low[0]+(coordinates.x-low[0])*(1+strain*direction[0])
        coordinates['y']=low[1]+(coordinates.y-low[1])*(1+strain*direction[1])
        coordinates['node_id']=np.arange(1,len(coordinates)+1)
        metadata={'model':name,'model_version':1,'rho':rho,'beta':beta,'m':m,'prescribed_strain':strain,
            'heterogeneity':heterogeneity,'surface_coupling':coupling,'q_coupling':gamma,'q_reference':q_reference,
            'q_reference_rule':'initial full-grain volume-weighted mean Q; no CPFEM input',
            'd_definition':'K_i - sum(w_ij K_j)/sum(w_ij)',
            'q_definition':'sum_faces w_f ||(I-n_f n_f^T)(eps_i-eps_j)(I-n_f n_f^T)||_F^2',
            'interface_weight':'initial shared 3D face area / initial grain centroid distance; normalized over interfaces',
            'height_closure':'(diag(a*(1+gamma*Q/Qref))+lambda*L)r = -a*strain*gain*eta*D; subtract area mean r',
            'q_assumption':'larger unsigned mismatch gives stronger local restoring constraint; prescribed hypothesis, not established monotonic law',
            'height_conversion':'Hmacro=H0*(1+strain*Dzz); z=bottom+Hmacro+H0*r; no clipping, no amplitude fitting',
            'k_to_strain_gain':float(gain),'fit_to_simulation':False,
            'orientation_source':orientation,'initial_model_source':root,
            'input_versions':{'orientation':orientation_stamp,'nodes':node_stamp,'elements':element_stamp}}
        predictions[name]={'coordinates':coordinates,'grains':grains,'metadata':metadata}
    return {'predictions':predictions,'indicators':indicators,'interfaces':face_details,'surface_edges':edges}


def predict_indicator_models(orientation_path,model_dir,*,rho,m=.05,strain=.1,heterogeneity=.75,coupling=1.,q_coupling=1.):
    if not np.isfinite([rho,m,strain,heterogeneity,coupling,q_coupling]).all() or m<=0 or strain<0 or not 0<=heterogeneity<=1 or coupling<0 or q_coupling<0:
        raise ValueError('Invalid prescribed indicator parameters')
    root=Path(model_dir).resolve();orientation=Path(orientation_path).resolve()
    return _predict(str(orientation),orientation.stat().st_mtime_ns,str(root),(root/'nodes.csv').stat().st_mtime_ns,
        (root/'elements.csv').stat().st_mtime_ns,float(rho),float(m),float(strain),float(heterogeneity),float(coupling),float(q_coupling))
