"""Evaluation-only deep-valley detection and optional FFT scale comparison.

Reference labels/thresholds are evaluation targets, never predictor inputs.
Plane-distance feature labels include ALL spatial frequencies. FFT energy is not a
spatial valley label and is reported separately, retaining phase by IFFT.
"""
from functools import lru_cache
from pathlib import Path
import json
import numpy as np
import pandas as pd
from src.theme1.initial_taylor_prediction import surface_geometry

def fit_plane_distances(coordinates):
    """OLS z=a*x+b*y+c, followed by signed normal distance (positive upward)."""
    xyz=np.asarray(coordinates,float)
    if xyz.ndim!=2 or xyz.shape[1]!=3 or len(xyz)<3 or not np.isfinite(xyz).all():
        raise ValueError('Expected at least three finite xyz coordinates')
    center=xyz[:,:2].mean(axis=0);scale=np.ptp(xyz[:,:2],axis=0)
    if (scale==0).any():raise ValueError('Plane fit requires non-collinear xy coordinates')
    design=np.column_stack([(xyz[:,:2]-center)/scale,np.ones(len(xyz))])
    coef,_,rank,_=np.linalg.lstsq(design,xyz[:,2],rcond=None)
    if rank<3:raise ValueError('Plane fit requires non-collinear xy coordinates')
    a,b=coef[:2]/scale;c=coef[2]-np.dot([a,b],center)
    distance=(xyz[:,2]-design@coef)/np.sqrt(1+a*a+b*b)
    tolerance=64*np.finfo(float).eps*max(1.,float(np.max(abs(xyz))))
    distance[abs(distance)<=tolerance]=0.
    return distance,dict(a=float(a),b=float(b),c=float(c),sq=float(np.sqrt(np.mean(distance**2))),
        minimum_distance=float(distance.min()),maximum_distance=float(distance.max()))


def distance_mask(distance,threshold,feature):
    if not np.isfinite(threshold) or threshold<=0:raise ValueError('Distance threshold must be positive')
    if feature not in ('valley','peak'):raise ValueError('Unknown feature')
    distance=np.asarray(distance,float)
    return distance < -threshold if feature=='valley' else distance > threshold


def average_precision(truth,scores):
    """Uninterpolated AP, grouping tied scores together (no arbitrary tie luck)."""
    truth=np.asarray(truth,bool);scores=np.asarray(scores,float)
    positives=int(truth.sum())
    if not positives:return np.nan
    order=np.argsort(-scores,kind='stable');sorted_scores=scores[order];labels=truth[order]
    ends=np.r_[np.flatnonzero(np.diff(sorted_scores)),len(scores)-1]
    tp=np.cumsum(labels)[ends];count=ends+1
    recall=tp/positives;precision=tp/count
    return float(np.sum(np.diff(np.r_[0.,recall])*precision))


def binary_metrics(truth,predicted):
    truth=np.asarray(truth,bool);predicted=np.asarray(predicted,bool)
    if truth.shape!=predicted.shape or truth.ndim!=1 or not len(truth):raise ValueError('Invalid aligned masks')
    tp=int((truth&predicted).sum());fp=int((~truth&predicted).sum());fn=int((truth&~predicted).sum())
    targets=int(truth.sum());candidates=int(predicted.sum());n=len(truth)
    precision=tp/candidates if candidates else np.nan
    recall=tp/targets if targets else np.nan
    union=tp+fp+fn
    return dict(items=n,target_count=targets,predicted_count=candidates,true_positive=tp,false_positive=fp,false_negative=fn,
        precision=precision,recall=recall,f1=2*tp/(2*tp+fp+fn) if targets else np.nan,
        iou=tp/union if targets and union else np.nan,reference_coverage=targets/n,predicted_coverage=candidates/n,
        chance_recall=candidates/n,recall_lift=(recall/(candidates/n)) if targets and candidates else np.nan)


@lru_cache(maxsize=6)
def _initial_surface(root,node_stamp,element_stamp):
    nodes=pd.read_csv(Path(root)/'nodes.csv')
    top=nodes[np.isclose(nodes.z,nodes.z.max())].sort_values('node_id').reset_index(drop=True)
    geometry,top_ids=surface_geometry(root)
    lookup={int(node):i+1 for i,node in enumerate(top_ids)}
    faces=np.array([[lookup[int(getattr(row,f'top_node_{k}'))] for k in range(4)] for row in geometry.itertuples(index=False)],int)
    return top,geometry,faces


def _surface(model_dir):
    root=Path(model_dir).resolve()
    return _initial_surface(str(root),(root/'nodes.csv').stat().st_mtime_ns,(root/'elements.csv').stat().st_mtime_ns)


def valley_tables(selected,model_dir,*,threshold=None,threshold_factors=(.5,1.,2.)):
    """Detect peaks/valleys by independent LS-plane signed normal distance.

    Default cutoffs are independent RMS centroid distances from each own plane.
    No alignment, fixed selected proportion, or reference-dependent prediction.
    """
    if threshold is not None and (not np.isfinite(threshold) or threshold<=0):raise ValueError('Distance threshold must be positive')
    if not threshold_factors or any(not np.isfinite(f) or f<=0 for f in threshold_factors):
        raise ValueError('Threshold factors must be positive')
    if 'cpfem' not in selected:raise ValueError('CPFEM reference is required only for evaluation')
    ids=selected['cpfem'].node_id.to_numpy(int)
    if len(np.unique(ids))!=len(ids):raise ValueError('Duplicate reference node IDs')
    values={};distances={};planes=[];coordinates={}
    for name,frame in selected.items():
        if frame.node_id.duplicated().any() or not set(ids).issubset(set(frame.node_id)):raise ValueError('Unmatched evaluation node IDs')
        xyz=frame.set_index('node_id').loc[ids,['x','y','z']].to_numpy(float)
        coordinates[name]=xyz
        distances[name],plane=fit_plane_distances(xyz)
        values[name]=xyz[:,2];planes.append(dict(model=name,**plane))
    top,geometry,faces=_surface(model_dir)
    if (ids<1).any() or (ids>len(top)).any():raise ValueError('Surface row IDs not in initial mesh')
    node_lookup={int(node):i for i,node in enumerate(ids)}
    keep=np.all(np.isin(faces,ids),axis=1)
    if not keep.any():raise ValueError('No complete retained initial surface faces')
    retained=geometry.loc[keep].reset_index(drop=True)
    positions=np.array([[node_lookup[int(node)] for node in face] for face in faces[keep]])
    def aggregate(fields):
        grain=retained[['part_id','area']].groupby('part_id',sort=True).sum().rename(columns={'area':'visible_area'})
        for name,z in fields.items():
            data=pd.DataFrame({'part_id':retained.part_id,'weighted':z[positions].mean(axis=1)*retained.area})
            grain[name]=data.groupby('part_id').weighted.sum()/grain.visible_area
        return grain.reset_index()
    def node_table(fields):
        return pd.DataFrame({'node_id':ids,'initial_x':top.iloc[ids-1].x.to_numpy(),'initial_y':top.iloc[ids-1].y.to_numpy(),**fields})
    # Surface grain centroid, computed on each field's own triangulated geometry.
    # This is the centroid of the exposed grain patch, not the buried 3D grain.
    centroids=[];grain=aggregate(distances)
    for name,xyz in coordinates.items():
        quad=xyz[positions]
        triangles=np.concatenate([quad[:,[0,1,2]],quad[:,[0,2,3]]])
        areas=np.linalg.norm(np.cross(triangles[:,1]-triangles[:,0],triangles[:,2]-triangles[:,0]),axis=1)/2
        parts=np.tile(retained.part_id.to_numpy(),2)
        centers=triangles.mean(axis=1)
        data=pd.DataFrame({'part_id':parts,'area':areas,**{axis:centers[:,k]*areas for k,axis in enumerate('xyz')}})
        grouped=data.groupby('part_id',sort=True).sum()
        if (grouped.area<=0).any():raise ValueError('Surface grain has zero current area')
        centroid=grouped[list('xyz')].div(grouped.area,axis=0)
        plane=next(p for p in planes if p['model']==name)
        d=(centroid.z-plane['a']*centroid.x-plane['b']*centroid.y-plane['c'])/np.sqrt(1+plane['a']**2+plane['b']**2)
        tol=64*np.finfo(float).eps*max(1.,float(np.max(abs(xyz))))
        d[abs(d)<=tol]=0.
        grain[name]=grain.part_id.map(d)
        centroids.append(centroid.reset_index().assign(model=name,surface_area=grouped.area.to_numpy(),distance=d.to_numpy()))
    node=node_table(distances);rows=[];flags=[];cutoffs=[]

    for level,frame,item_id in [('grain',grain,'part_id'),('node_region',node,'node_id')]:
        reference=frame.cpfem.to_numpy(float)
        bases={name:float(np.sqrt(np.mean(frame[name].to_numpy(float)**2))) for name in values}
        for name,base in bases.items():
            cutoffs.append(dict(model=name,level=level,automatic_threshold=base))
        for factor in threshold_factors:
            reference_cutoff=float((bases['cpfem'] if threshold is None else threshold)*factor)
            for feature in ('valley','peak'):
                truth=distance_mask(reference,max(reference_cutoff,np.finfo(float).tiny),feature)
                for name in values:
                    if name=='cpfem':continue
                    cutoff=float((bases[name] if threshold is None else threshold)*factor)
                    d=frame[name].to_numpy(float);predicted=distance_mask(d,max(cutoff,np.finfo(float).tiny),feature)
                    stats=binary_metrics(truth,predicted)
                    stats.update(model=name,level=level,feature=feature,threshold_factor=float(factor),distance_threshold=cutoff,reference_threshold=reference_cutoff,
                        average_precision=average_precision(truth,-d if feature=='valley' else d),ap_chance=float(truth.mean()))
                    rows.append(stats)
                    flags.append(pd.DataFrame({'level':level,'model':name,'feature':feature,'threshold_factor':float(factor),
                        'distance_threshold':cutoff,'reference_threshold':reference_cutoff,'item_id':frame[item_id],'reference_distance':reference,'predicted_distance':d,
                        'reference_feature':truth,'predicted_feature':predicted,
                        'outcome':np.select([truth&predicted,~truth&predicted,truth&~predicted],['TP','FP','FN'],default='TN')}))
    metadata={'method_version':'independent_surface_centroid_detection_v3','purpose':'evaluation only; no prediction modification or coefficient fitting',
        'plane':'independent ordinary least squares z=a*x+b*y+c using each field own matched current xyz nodes',
        'distance':'(z-a*x-b*y-c)/sqrt(1+a*a+b*b); positive upward; original coordinate length units',
        'feature_definition':'valley: distance < -threshold; peak: distance > threshold; otherwise neutral',
        'threshold':threshold,'threshold_factors':list(threshold_factors),'threshold_rule':'independent RMS signed surface-grain-centroid distances for each field and level; same multiplier, no fixed selected fraction; explicit threshold overrides for legacy calls',
        'grain_statistic':'current-area centroid of each exposed grain surface triangulated into two triangles per quad; signed distance from own nodal OLS plane; not 3D volume centroid',
        'grain_weight':'equal weight per visible grain; node-region metric reported separately',
        'cropped_grains':'partial visible grains retained; only complete retained faces contribute',
        'undefined_rule':'no reference targets makes recall/F1/IoU/AP undefined; no predicted targets makes precision undefined',
        'counts':{'nodes':len(node),'visible_grains':len(grain),'complete_faces':int(keep.sum())},
        'warning':'detection accuracy does not establish amplitude accuracy or model physical validity'}
    return {'metrics':pd.DataFrame(rows),'flags':pd.concat(flags,ignore_index=True),'grain_heights':aggregate(values),
        'node_heights':node_table(values),'grain_distances':grain,'node_distances':node,'planes':pd.DataFrame(planes),'centroids':pd.concat(centroids,ignore_index=True),'thresholds':pd.DataFrame(cutoffs),'metadata':metadata}


def regular_material_grid(selected,model_dir):
    top,_,_=_surface(model_dir);ids=selected['cpfem'].node_id.to_numpy(int)
    if len(np.unique(ids))!=len(ids) or (ids<1).any() or (ids>len(top)).any():raise ValueError('Invalid surface row IDs')
    xy=top.iloc[ids-1][['x','y']].to_numpy(float);x=np.unique(xy[:,0]);y=np.unique(xy[:,1])
    if len(x)<4 or len(y)<4 or len(x)*len(y)!=len(ids):raise ValueError('FFT requires a complete rectangular retained initial grid; missing nodes are not interpolated')
    dx=float(np.mean(np.diff(x)));dy=float(np.mean(np.diff(y)))
    if not np.allclose(np.diff(x),dx,rtol=1.e-4,atol=1.e-10) or not np.allclose(np.diff(y),dy,rtol=1.e-4,atol=1.e-10):
        raise ValueError('FFT requires uniformly spaced initial material coordinates')
    ix=np.searchsorted(x,xy[:,0]);iy=np.searchsorted(y,xy[:,1]);fields={}
    for name,frame in selected.items():
        z=frame.set_index('node_id').loc[ids].z.to_numpy(float)
        if not np.isfinite(z).all():raise ValueError('Nonfinite FFT field')
        grid=np.empty((len(y),len(x)));grid[iy,ix]=z;fields[name]=grid
    return fields,x,y,dx,dy


def fft_bands(field,dx,dy,grain_diameter):
    """Phase-preserving FFT bands on a symmetric reflected periodic extension.

    All spectra use the SAME geometry-derived wavelengths. A plane is removed
    for spectral analysis only; reflection avoids a height jump at the seam.
    """
    z=np.asarray(field,float);ny,nx=z.shape
    if not np.isfinite(z).all() or min(dx,dy,grain_diameter)<=0:raise ValueError('Invalid FFT geometry')
    xx,yy=np.meshgrid((np.arange(nx)-(nx-1)/2)*dx,(np.arange(ny)-(ny-1)/2)*dy)
    design=np.column_stack([np.ones(z.size),xx.ravel(),yy.ravel()])
    trend=(design@np.linalg.lstsq(design,z.ravel(),rcond=None)[0]).reshape(z.shape)
    residual=z-trend
    extended=np.pad(residual,((0,ny),(0,nx)),mode='symmetric')
    spectrum=np.fft.fft2(extended,norm='ortho')
    fx=np.fft.fftfreq(2*nx,d=dx);fy=np.fft.fftfreq(2*ny,d=dy)
    radial=np.hypot(fy[:,None],fx[None,:]);non_dc=radial>0
    low=non_dc&(radial<1/(4*grain_diameter))
    mid=(radial>=1/(4*grain_diameter))&(radial<1/grain_diameter)
    high=radial>=1/grain_diameter
    result={};energy={}
    for name,mask in [('low',low),('grain_scale',mid),('high',high)]:
        result[name]=np.fft.ifft2(spectrum*mask,norm='ortho').real[:ny,:nx]
        energy[name]=float(np.sum(abs(spectrum[mask])**2)/4)
    return {'fields':result,'energy':energy,'detrended':residual,'trend':trend}


def fft_scale_table(selected,model_dir):
    from src.theme1.initial_taylor_prediction import pearson
    fields,x,y,dx,dy=regular_material_grid(selected,model_dir)
    _,geometry,_=_surface(model_dir)
    area=geometry.groupby('part_id').area.sum().to_numpy(float)
    diameter=float(np.median(2*np.sqrt(area/np.pi)))
    transformed={name:fft_bands(z,dx,dy,diameter) for name,z in fields.items()}
    reference=transformed['cpfem'];total=sum(reference['energy'].values());rows=[]
    for name,values in transformed.items():
        if name=='cpfem':continue
        for band in ('low','grain_scale','high'):
            ref=reference['fields'][band];pred=values['fields'][band]
            rows.append({'model':name,'band':band,'reconstructed_band_pearson':pearson(pred.ravel(),ref.ravel()),
                'cpfem_energy_fraction':reference['energy'][band]/total if total else np.nan,
                'energy_ratio':values['energy'][band]/reference['energy'][band] if reference['energy'][band]>1.e-28 else np.nan})
    metadata={'purpose':'evaluation-only spatial-scale diagnostic; not a deep-valley detector',
        'grid':'initial material coordinates paired by surface node IDs; no deformed-grid interpolation',
        'dx':dx,'dy':dy,'nx':len(x),'ny':len(y),'initial_median_grain_diameter':diameter,
        'bands':{'low':'wavelength >4 initial median grain diameters','grain_scale':'1-4 initial median grain diameters','high':'wavelength <=1 initial median grain diameter'},
        'preprocessing':'independent least-squares plane removal; symmetric reflection to 2nx*2ny before FFT',
        'comparison':'identical frequency masks on all fields; inverse FFT retains phase for location-sensitive correlation',
        'boundary_assumption':'reflected continuation outside the crop; fine-scale ringing/edge effects remain possible',
        'energy_definition':'sum |FFT_ortho|^2 /4, DC excluded; not elastic/plastic energy',
        'warning':'low frequency is not low spectral energy; deep valleys may span several frequency bands'}
    return {'metrics':pd.DataFrame(rows),'metadata':metadata,'transformed':transformed}


def save_valley_evaluation(result,directory,fft=None):
    root=Path(directory);root.mkdir(parents=True,exist_ok=True)
    for name in ('metrics','flags','grain_heights','node_heights','grain_distances','node_distances','planes','centroids','thresholds'):result[name].to_csv(root/(name+'.csv'),index=False)
    (root/'method.json').write_text(json.dumps(result['metadata'],ensure_ascii=False,indent=2)+'\n')
    if fft is not None:
        fft['metrics'].to_csv(root/'fft_scales.csv',index=False)
        (root/'fft_method.json').write_text(json.dumps(fft['metadata'],ensure_ascii=False,indent=2)+'\n')
