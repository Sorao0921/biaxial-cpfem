"""Frozen-initial-orientation, equal-stress FCC response; no history inputs.

Common CRSS/reference-rate/stress amplitudes cancel from chi and K for the
same power law in every grain/system. beta is a STRESS ratio, not strain rho.
No compatibility or force-equilibrium boundary-value problem is solved here.
"""
from functools import lru_cache
from itertools import product
from pathlib import Path

import numpy as np
import pandas as pd

from src.crystal_plasticity.taylor_factor import bunge_sample_to_crystal


@lru_cache(maxsize=1)
def fcc_slip_geometry():
    normals=np.array([[1,1,1],[1,1,-1],[1,-1,1],[-1,1,1]],dtype=float)
    candidates=[v for v in product((-1,0,1),repeat=3)
                if sum(x*x for x in v)==2 and next(x for x in v if x)!=-1]
    pairs=[(v,n) for n in normals for v in candidates if np.dot(n,v)==0]
    return np.array([v for v,_ in pairs])/np.sqrt(2),np.array([n for _,n in pairs])/np.sqrt(3)


def initial_stress_response(euler, beta, m, volumes=None):
    """Return dimensionless chi/K and common-scaled D tensors, in input order.

    A=sum sign(tau)*abs(tau)**(1/m)*sym(s outer n), tau=Sxx+beta*Syy.
    chi=-Azz/eq(A), K=-Azz/eq(volume_mean(A)). For numerical stability,
    per-grain rate shapes and their GLOBAL relative amplitudes are separated.
    Only a common multiplier is dropped from K; no per-grain activity is lost.
    """
    euler=np.asarray(euler,dtype=float)
    if euler.ndim!=2 or euler.shape[1]!=3 or not len(euler) or not np.isfinite(euler).all():
        raise ValueError('Expected finite initial Euler triples in radians')
    if not np.isfinite([beta,m]).all() or m<=0:
        raise ValueError('Expected finite beta and positive m')
    weights=np.ones(len(euler)) if volumes is None else np.asarray(volumes,dtype=float)
    if weights.shape!=(len(euler),) or not np.isfinite(weights).all() or (weights<=0).any():
        raise ValueError('Expected one positive initial volume per grain')
    weights=weights/weights.sum()
    directions,normals=fcc_slip_geometry()
    g=bunge_sample_to_crystal(euler)
    s=np.einsum('gji,aj->gai',g,directions)
    n=np.einsum('gji,aj->gai',g,normals)
    outer=s[:,:,:,None]*n[:,:,None,:]
    schmid=.5*(outer+outer.swapaxes(-1,-2))
    tau=schmid[:,:,0,0]+beta*schmid[:,:,1,1]
    maxima=np.abs(tau).max(axis=1)
    if (maxima<=0).any():
        raise ValueError('Zero resolved deviatoric loading')
    with np.errstate(divide='ignore',under='ignore'):
        log_tau=np.log(np.abs(tau))
        local_rates=np.sign(tau)*np.exp((log_tau-np.log(maxima)[:,None])/m)
        amplitudes=np.exp((np.log(maxima)-np.log(maxima.max()))/m)
    local=np.einsum('ga,gaij->gij',local_rates,schmid)
    local_eq=np.sqrt(2./3.*np.sum(local**2,axis=(1,2)))
    if (local_eq<=0).any():
        raise ValueError('Undefined local equivalent rate')
    common=local*amplitudes[:,None,None]
    mean=np.einsum('g,gij->ij',weights,common)
    mean_eq=float(np.sqrt(2./3.*np.sum(mean**2)))
    if mean_eq<=0 or not np.isfinite(mean_eq):
        raise ValueError('Undefined macroscopic equivalent rate')
    return {'chi':-local[:,2,2]/local_eq,'k':-common[:,2,2]/mean_eq,
            'k_rd':common[:,0,0]/mean_eq,'k_td':common[:,1,1]/mean_eq,
            'A':common,'mean_A':mean,'grain_amplitude':amplitudes}


def initial_grain_volumes(model_dir):
    """Initial C3D8/LS-DYNA eight-node brick volumes, 2x2x2 Gauss integration.

    All elements/grains participate, including subsurface grains. Results must
    not depend on the displayed surface crop or on any deformed coordinates.
    """
    root=Path(model_dir)
    nodes=pd.read_csv(root/'nodes.csv').set_index('node_id')
    elements=pd.read_csv(root/'elements.csv')
    columns=[f'node_id_{i}' for i in range(1,9)]
    ids=elements[columns].to_numpy(int)
    if any(len(set(row))!=8 for row in ids):
        raise ValueError('Expected eight distinct nodes per initial brick')
    xyz=nodes.loc[ids.ravel(),['x','y','z']].to_numpy().reshape(-1,8,3)
    signs=np.array([[-1,-1,-1],[1,-1,-1],[1,1,-1],[-1,1,-1],
                    [-1,-1,1],[1,-1,1],[1,1,1],[-1,1,1]])
    volume=np.zeros(len(elements))
    for point in product((-1/np.sqrt(3),1/np.sqrt(3)),repeat=3):
        factors=1+signs*np.asarray(point)
        derivatives=np.column_stack([signs[:,i]*np.prod(factors[:,[j for j in range(3) if j!=i]],axis=1)/8 for i in range(3)])
        determinant=np.linalg.det(np.einsum('eai,aj->eij',xyz,derivatives))
        if not np.isfinite(determinant).all() or (determinant<=0).any():
            raise ValueError('Nonpositive initial brick Jacobian')
        volume+=determinant
    return pd.DataFrame({'part_id':elements.part_id,'initial_volume':volume}).groupby('part_id',as_index=False).initial_volume.sum()


def stress_ratio_for_strain_ratio(euler, rho, m, volumes=None):
    """Match volume-mean initial D_TD/D_RD to prescribed rho; no history input.

    Solve D_TD-rho*D_RD=0 rather than a ratio with possible poles.
    Only a root with positive RD extension is accepted.
    """
    if not np.isfinite(rho):
        raise ValueError('Expected finite prescribed strain ratio')

    def residual(beta):
        mean=initial_stress_response(euler,beta,m,volumes)['mean_A']
        return float((mean[1,1]-rho*mean[0,0])/np.linalg.norm(mean))

    for bound in (1.,2.,4.,8.,16.,32.,64.):
        lower,upper=residual(-bound),residual(bound)
        if lower*upper>0:
            continue
        lo,hi=-bound,bound
        for _ in range(100):
            beta=(lo+hi)/2
            value=residual(beta)
            if abs(value)<1.e-12:
                break
            if lower*value<=0:
                hi=beta
            else:
                lo=beta;lower=value
        mean=initial_stress_response(euler,beta,m,volumes)['mean_A']
        if mean[0,0]>0 and abs(mean[1,1]/mean[0,0]-rho)<1.e-7:
            return beta
    raise ValueError('Cannot match prescribed strain ratio with positive RD extension under the initial plane-stress model')
