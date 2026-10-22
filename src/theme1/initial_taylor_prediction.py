"""Initial Taylor out-of-plane activity versus state13 roughness.

Enumerate all optimal basic solutions of the L1 Taylor problem. A continuous
optimal face is represented by its vertices; linear |slip|-weighted activity
extrema occur at these vertices. No simulated slip/orientation is an input.
"""
from functools import lru_cache
from itertools import combinations, product
from pathlib import Path

import numpy as np
import pandas as pd

from src.crystal_plasticity.taylor_factor import (
    bunge_sample_to_crystal, components, crystal_strain, fcc_solver,
)
from src.theme1.contribution import _read_height


@lru_cache(maxsize=1)
def _geometry():
    normals = np.array([[1, 1, 1], [1, 1, -1], [1, -1, 1], [-1, 1, 1]])
    dirs = [v for v in product((-1, 0, 1), repeat=3)
            if sum(x*x for x in v) == 2 and next(x for x in v if x) != -1]
    directions = np.array([v for n in normals for v in dirs if np.dot(n, v) == 0]) / np.sqrt(2)
    a, inverses, _ = fcc_solver()
    bases = np.array(list(combinations(range(12), 5)))
    matrices = np.moveaxis(a[:, bases], 0, 1)
    bases = bases[np.abs(np.linalg.det(matrices)) > 1e-10]
    return directions, bases, inverses


def optimal_activity(euler, rho, *, tolerance=1e-9):
    """Return M, activity bounds and distinct optimal signed-slip vertices.

    Slip numbering is internal to the Taylor solver, NOT UMAT slip numbering.
    Strain is normalized to one equivalent-strain unit. No epsilon13 scaling
    is needed for within-case Spearman rankings.
    """
    euler = np.asarray(euler, float)
    if euler.shape != (3,) or not np.isfinite(euler).all():
        raise ValueError('Expected one finite initial Euler triple in radians')
    if not np.isfinite(tolerance) or tolerance <= 0:
        raise ValueError('tolerance must be positive and finite')
    directions, bases, inverses = _geometry()
    b = components(crystal_strain(euler, rho))
    basic = np.einsum('nij,j->ni', inverses, b)
    totals = np.abs(basic).sum(axis=1)
    m = float(totals.min())
    keep = np.abs(totals - m) <= tolerance * max(1., m)
    gamma = np.zeros((keep.sum(), 12))
    gamma[np.arange(len(gamma))[:, None], bases[keep]] = basic[keep]
    gamma[np.abs(gamma) < tolerance * .01] = 0
    # Degenerate bases can represent the same vertex.
    _, indices = np.unique(np.round(gamma, 10), axis=0, return_index=True)
    gamma = gamma[np.sort(indices)]
    c = np.abs(directions @ bunge_sample_to_crystal(euler)[:, 2])
    az = np.abs(gamma) @ c
    # Normals in exactly the same ordering as fcc_solver and directions.
    normals = np.repeat(np.array([[1,1,1],[1,1,-1],[1,-1,1],[-1,1,1]])/np.sqrt(3),3,axis=0)
    z_crystal = bunge_sample_to_crystal(euler)[:,2]
    contributions = gamma * ((directions @ z_crystal)*(normals @ z_crystal))
    plus = np.maximum(contributions,0).sum(axis=1)
    minus = np.maximum(-contributions,0).sum(axis=1)
    pm = {}
    for name, values in [('pplus',plus),('pminus',minus)]:
        pm.update({name+'_min':float(values.min()),name+'_max':float(values.max()),
                   name+'_midpoint':float((values.min()+values.max())/2)})
    return {**pm, 'pabs_min':float(az.min()),'pabs_max':float(az.max()),
            'pabs_midpoint':float((az.min()+az.max())/2),'vertex_pabs':az, 'vertex_pplus':plus, 'vertex_pminus':minus, 'm_initial': m, 'az_min': float(az.min()), 'az_max': float(az.max()),
            'az_midpoint': float((az.min()+az.max())/2), 'optimal_vertices': len(gamma),
            'gamma': gamma, 'vertex_az': az, 'projection': c}


def surface_geometry(directory):
    """Initial top faces and reference-area weights; reused across cases."""
    directory = Path(directory)
    nodes = pd.read_csv(directory/'nodes.csv').set_index('node_id')
    elements = pd.read_csv(directory/'elements.csv')
    elements = elements[np.isclose(elements.center_z, elements.center_z.max())]
    top = nodes[np.isclose(nodes.z, nodes.z.max())]
    top_ids = set(top.index)
    columns = [c for c in elements if c.startswith('node_id_')]
    ids = elements[columns].to_numpy(int)
    mask = np.isin(ids, top.index)
    if not (mask.sum(axis=1) == 4).all():
        raise ValueError('Expected quadrilateral top faces')
    ids = ids[mask].reshape(-1,4)
    xy = nodes.loc[ids.ravel(), ['x','y']].to_numpy().reshape(-1,4,2)
    delta = xy-xy.mean(axis=1,keepdims=True)
    order = np.argsort(np.arctan2(delta[:,:,1],delta[:,:,0]),axis=1)
    ids = np.take_along_axis(ids,order,axis=1)
    xy = np.take_along_axis(xy,order[:,:,None],axis=1)
    area = .5*np.abs((xy[:,:,0]*np.roll(xy[:,:,1],-1,axis=1)-xy[:,:,1]*np.roll(xy[:,:,0],-1,axis=1)).sum(axis=1))
    if (area <= 0).any():
        raise ValueError('Nonpositive surface area')
    frame = elements[['element_id','part_id']].reset_index(drop=True)
    frame['area']=area
    frame['x']=xy[:,:,0].mean(axis=1)
    frame['y']=xy[:,:,1].mean(axis=1)
    for i in range(4):
        frame[f'top_node_{i}']=ids[:,i]
    return frame, top.index.sort_values().to_numpy(int)


def grain_response(height_path, geometry, top_ids, *, node_ids='surface_rows'):
    """Detrend retained nodes; keep only complete top faces (no bottom nodes).

    Existing coordinate exports use 1-based rows of initial top nodes sorted
    by global ID. Mapping is explicit, never inferred from partial overlap.
    """
    h = _read_height(Path(height_path))
    if h.node_id.duplicated().any() or not np.isfinite(h[['x','y','z']]).all().all():
        raise ValueError('Invalid height nodes')
    if node_ids == 'surface_rows':
        ids = h.node_id.to_numpy(int)
        if (ids < 1).any() or (ids > len(top_ids)).any():
            raise ValueError('Height row ID outside initial top-surface range')
        h['node_id'] = top_ids[ids-1]
    elif node_ids != 'global':
        raise ValueError('Unknown height node-ID convention')
    design = np.column_stack([h.x, h.y, np.ones(len(h))])
    residual = h.z.to_numpy()-design@np.linalg.lstsq(design,h.z.to_numpy(),rcond=None)[0]
    values = dict(zip(h.node_id, residual))
    raw_z = dict(zip(h.node_id, h.z))
    frame = geometry.copy()
    corners = np.column_stack([frame[f'top_node_{i}'].map(values).to_numpy() for i in range(4)])
    valid = np.isfinite(corners).all(axis=1)
    frame = frame.loc[valid].copy()
    corners = corners[valid]
    if not len(frame):
        raise ValueError('No complete top faces in selected height region')
    raw_corners = np.column_stack([frame[f'top_node_{i}'].map(raw_z).to_numpy() for i in range(4)])
    frame['surface_z_mean'] = raw_corners.mean(axis=1)
    frame['height_mean'] = corners.mean(axis=1)
    frame['height_abs_mean'] = np.abs(corners).mean(axis=1)
    frame['height_second_moment'] = (corners**2).mean(axis=1)
    rows=[]
    for pid,g in frame.groupby('part_id'):
        w=g.area.to_numpy()
        mean=np.average(g.height_mean,weights=w)
        second=np.average(g.height_second_moment,weights=w)
        rows.append({'part_id':int(pid),'surface_elements':len(g),'retained_area':w.sum(),
                     'x':np.average(g.x,weights=w),'y':np.average(g.y,weights=w),
                     'height_mean':mean,'surface_z_mean':np.average(g.surface_z_mean,weights=w),'height_abs_mean':np.average(g.height_abs_mean,weights=w),
                     'height_std':np.sqrt(max(0.,second-mean**2))})
    return pd.DataFrame(rows), frame


def spearman(x, y):
    """Average tie ranks; constant inputs have undefined correlation."""
    x,y=np.asarray(x,float),np.asarray(y,float)
    valid=np.isfinite(x)&np.isfinite(y)
    x,y=x[valid],y[valid]
    if len(x)<3 or np.ptp(x)<=1e-12*max(1.,np.abs(x).max()) or np.ptp(y)<=1e-12*max(1.,np.abs(y).max()):
        return np.nan
    return float(np.corrcoef(pd.Series(x).rank(),pd.Series(y).rank())[0,1])


def add_valley_prediction(frame):
    """Fixed sign hypothesis: larger activity predicts lower relative height.

    Center with retained reference area. Magnitudes remain dimensionless,
    so these columns predict high/low ordering, not height amplitude.
    """
    result=frame.copy()
    weights=result.retained_area.to_numpy(float)
    if not np.isfinite(weights).all() or (weights<=0).any():
        raise ValueError('Expected positive retained grain areas')
    for column in ['az_min','az_max','az_midpoint','m_initial','measured_az_state13','measured_bz_state13']:
        if column not in result:
            continue
        values=result[column].to_numpy(float)
        if np.isfinite(values).all():
            result[f'relief_from_{column}']=-(values-np.average(values,weights=weights))
    return result


def measured_activity_response(record, elements, outputs, *, calculate=False):
    """Join saved interval activity and, if complete, its strain integral.

    Missing intervals remain unavailable; never replace with zero. All joins
    use element IDs on the same fully retained faces as the height response.
    """
    from dataclasses import replace
    from src.crystal_plasticity.slip_activity_pipeline import activity_path, ensure_activity
    result={}
    diagnostics={}
    def read(interval):
        path=activity_path(replace(record,state=interval),outputs)
        if not path.exists():
            return None
        f=pd.read_csv(path,usecols=['element_id','z_slip_activity','delta_eps_eq'])
        if f.element_id.duplicated().any() or not np.isfinite(f.to_numpy()).all() or (f.delta_eps_eq<=0).any():
            raise ValueError(f'Invalid measured activity: {path}')
        selected=elements[['element_id','part_id','area']].merge(f,on='element_id',how='left',validate='one_to_one')
        if selected.z_slip_activity.isna().any():
            raise ValueError(f'Missing retained element activity: {path}')
        return selected
    if calculate:
        ensure_activity(record,outputs)
    last=read(13)
    diagnostics['measured_az_state13']='available' if last is not None else 'missing_saved_state13_activity'
    if last is not None:
        result['measured_az_state13']=(last.assign(weighted=last.z_slip_activity*last.area).groupby('part_id').weighted.sum()/last.groupby('part_id').area.sum())
    intervals=[read(k) for k in range(2,14)]
    diagnostics['measured_bz_state13']='available' if all(f is not None for f in intervals) else 'missing_saved_intervals'
    if all(f is not None for f in intervals):
        for f in intervals:
            contribution=(f.assign(weighted=f.z_slip_activity*f.delta_eps_eq*f.area).groupby('part_id').weighted.sum()/f.groupby('part_id').area.sum())
            result['measured_bz_state13']=result.get('measured_bz_state13',0)+contribution
    return result,diagnostics


def surface_boundary_weights(geometry, spatial_model_dir):
    """Shared top-face boundary lengths, excluding point-only contact."""
    nodes=pd.read_csv(Path(spatial_model_dir)/'nodes.csv').set_index('node_id')
    xy=nodes[['x','y']]
    owners={}
    for row in geometry.itertuples(index=False):
        ids=[getattr(row,f'top_node_{i}') for i in range(4)]
        for a,b in zip(ids,ids[1:]+ids[:1]):
            edge=tuple(sorted((a,b)))
            owners.setdefault(edge,set()).add(int(row.part_id))
    lengths={}
    for (a,b),parts in owners.items():
        if len(parts)!=2:
            continue
        pair=tuple(sorted(parts))
        length=float(np.linalg.norm(xy.loc[a].to_numpy()-xy.loc[b].to_numpy()))
        lengths[pair]=lengths.get(pair,0.)+length
    return pd.DataFrame([{'part_id_i':a,'part_id_j':b,'weight':w} for (a,b),w in sorted(lengths.items())],
                        columns=['part_id_i','part_id_j','weight'])


def add_neighbor_activity(predictions, edges):
    """Fixed valley hypothesis using signed difference from adjacent activity.

    Uses all exposed grains, including neighbors outside the observation crop.
    Geometric boundary lengths are weights, not fitted influence coefficients.
    """
    result=predictions.copy()
    if result.part_id.duplicated().any():
        raise ValueError('Duplicate predicted grain IDs')
    values=result.set_index('part_id').az_midpoint
    if not np.isfinite(values).all() or (edges.weight<=0).any():
        raise ValueError('Invalid activities or boundary weights')
    totals={int(p):0. for p in values.index}
    weights=totals.copy();counts={int(p):0 for p in values.index}
    for edge in edges.itertuples(index=False):
        a,b=int(edge.part_id_i),int(edge.part_id_j)
        if a not in values.index or b not in values.index:
            raise ValueError('Missing initial prediction for a neighboring grain')
        totals[a]+=edge.weight*values.loc[b];weights[a]+=edge.weight;counts[a]+=1
        totals[b]+=edge.weight*values.loc[a];weights[b]+=edge.weight;counts[b]+=1
    means={p:totals[p]/weights[p] if weights[p]>0 else np.nan for p in totals}
    result['neighbor_az_mean']=result.part_id.map(means)
    result['neighbor_count']=result.part_id.map(counts)
    result['az_neighbor_difference']=result.az_midpoint-result.neighbor_az_mean
    result['relief_from_neighbor_az']=-result.az_neighbor_difference
    return result


def pearson(x,y):
    """Linear correspondence; constant fields have undefined correlation."""
    x,y=np.asarray(x,float),np.asarray(y,float)
    valid=np.isfinite(x)&np.isfinite(y)
    x,y=x[valid],y[valid]
    if len(x)<3 or np.ptp(x)<=1e-12*max(1.,np.abs(x).max()) or np.ptp(y)<=1e-12*max(1.,np.abs(y).max()):
        return np.nan
    return float(np.corrcoef(x,y)[0,1])
