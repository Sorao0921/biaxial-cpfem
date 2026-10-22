"""Teacher-free graph closure from initial Taylor properties to surface height.

This is an explicit hypothesis model, not a solution of crystal-plasticity
force equilibrium. All coefficients and signs are prescribed before seeing
simulation heights. Coordinate units are retained in prediction; normalization is evaluation-only.
"""
import numpy as np
import pandas as pd


def predict_grain_height(initial, edges, *, thickness, strain, rho,
                         az_scale=1., slope_scale=1., coupling=1., activity='az'):
    """Minimize local-activity and weighted grain-boundary slope mismatch.

    E = sum a_g[(h_g-u_g)/H]^2 + coupling*sum w_ij[(h_i-h_j)/distance-s_ij]^2
    a_g normalized initial surface area; w_ij normalized boundary length/distance.
    u_g = sign*H*strain*az_scale*(activity_g-area_mean(activity))
    sign: Az/Pminus -> -1, Pplus -> +1 (fixed hypotheses)
    s_ij = strain*slope_scale*(M_i-M_j)/area_mean(M)
    d_ij = distance*s_ij

    M contrast supplies preferred boundary slopes; geometric weights couple
    them to local Az relief. No simulated values enter this solve.
    """
    required=['part_id','initial_area','center_x','center_y','m_initial','az_midpoint']
    if set(required)-set(initial):
        raise ValueError('Missing initial grain properties')
    if initial.part_id.duplicated().any() or not np.isfinite(initial[required]).all().all():
        raise ValueError('Invalid initial grain properties')
    if not np.isfinite([thickness,strain,rho,az_scale,slope_scale,coupling]).all() or thickness<=0 or strain<0 or coupling<0:
        raise ValueError('Invalid prescribed model parameters')
    area=initial.initial_area.to_numpy(float)
    if (area<=0).any():
        raise ValueError('Nonpositive initial surface area')
    area=area/area.sum()
    if activity not in ('az','pplus','pminus'):
        raise ValueError('Unknown activity')
    az=initial[activity+'_midpoint'].to_numpy(float)
    if not np.isfinite(az).all():
        raise ValueError('Nonfinite activity')
    m=initial.m_initial.to_numpy(float)
    if (m<=0).any():
        raise ValueError('Nonpositive Taylor factor')
    u=(1. if activity=='pplus' else -1.)*thickness*strain*az_scale*(az-np.dot(area,az))
    matrix=np.diag(area)
    rhs=area*u
    idx={int(p):i for i,p in enumerate(initial.part_id)}
    coordinates=initial[['center_x','center_y']].to_numpy(float)
    connections=[]
    for edge in edges.itertuples(index=False):
        i,j=idx[int(edge.part_id_i)],idx[int(edge.part_id_j)]
        distance=np.linalg.norm(coordinates[i]-coordinates[j])
        if distance<=0 or edge.weight<=0:
            raise ValueError('Invalid grain-boundary geometry')
        connections.append((i,j,float(edge.weight/distance),float(distance)))
    total=sum(w for _,_,w,_ in connections)
    edge_rows=[]
    for i,j,w,distance in connections:
        weight=w/total
        slope=strain*slope_scale*(m[i]-m[j])/np.dot(area,m)
        target=distance*slope
        # Multiply dimensionless objective by H^2 for this linear system.
        effective=coupling*weight*thickness**2/distance**2
        matrix[i,i]+=effective;matrix[j,j]+=effective
        matrix[i,j]-=effective;matrix[j,i]-=effective
        rhs[i]+=effective*target;rhs[j]-=effective*target
        edge_rows.append({'part_id_i':int(initial.part_id.iloc[i]),'part_id_j':int(initial.part_id.iloc[j]),
                          'weight':weight,'centroid_distance':distance,'target_slope':slope,'target_height_difference':target})
    relief=np.linalg.solve(matrix,rhs)
    result=initial.copy()
    if activity=='az':
        result['local_az_relief']=u  # Backward-compatible Az output only.
    result['local_activity_relief']=u
    result['activity_model']=activity
    result['predicted_height_residual']=relief
    # Prescribed equivalent logarithmic strain, incompressible diagonal path.
    d=np.array([1.,rho,-1.-rho]);d/=np.sqrt(2./3.*np.dot(d,d))
    result['macro_thickness']=thickness*np.exp(d[2]*strain)
    result['predicted_height_from_bottom']=result.macro_thickness+relief
    return result,pd.DataFrame(edge_rows,columns=['part_id_i','part_id_j','weight','centroid_distance','target_slope','target_height_difference'])


def reconstruct_nodes(grains,geometry,top_nodes,*,bottom_z,strain,rho):
    """Area-average grain heights at shared nodes, yielding continuous faces.

    Affine in-plane coordinates use only the prescribed logarithmic strain.
    Neither measured coordinates nor measured heights enter reconstruction.
    """
    values=grains.set_index('part_id').predicted_height_from_bottom
    weighted={int(n):0. for n in top_nodes.node_id}
    mass=weighted.copy()
    for row in geometry.itertuples(index=False):
        z=values.loc[row.part_id]+bottom_z
        for k in range(4):
            node=int(getattr(row,f'top_node_{k}'))
            weighted[node]+=row.area*z;mass[node]+=row.area
    result=top_nodes.sort_values('node_id').copy()
    if any(mass[int(n)]<=0 for n in result.node_id):
        raise ValueError('Initial top node has no contributing face')
    result['z']=[weighted[int(n)]/mass[int(n)] for n in result.node_id]
    d=np.array([1.,rho,-1.-rho]);d/=np.sqrt(2./3.*np.dot(d,d))
    result['x']*=np.exp(d[0]*strain);result['y']*=np.exp(d[1]*strain)
    # Existing surface exporters use sorted 1-based row IDs.
    result['node_id']=np.arange(1,len(result)+1)
    return result[['node_id','x','y','z']]


def normalized_height_coordinates(path):
    """Remove plane, center and divide by each field's own nodal RMS.

    Applied after prediction for shape comparison only. No observed values
    or observed scale are used to change predicted heights.
    """
    from pathlib import Path
    from src.theme1.contribution import _read_height
    coordinates=_read_height(Path(path))
    if coordinates.node_id.duplicated().any() or not len(coordinates):
        raise ValueError('Invalid height node IDs')
    design=np.column_stack([coordinates.x,coordinates.y,np.ones(len(coordinates))])
    z=coordinates.z.to_numpy(float)
    residual=z-design@np.linalg.lstsq(design,z,rcond=None)[0]
    residual-=residual.mean()
    rms=float(np.sqrt(np.mean(residual**2)))
    floor=1e-12*max(1.,np.max(np.abs(z)))
    result=coordinates.copy()
    result['z']=residual/rms if rms>floor else np.zeros(len(residual))
    return result,rms if rms>floor else 0.
