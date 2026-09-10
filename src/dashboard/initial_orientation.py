"""Initial orientation maps with shared, explicit contrast settings."""
import csv
from pathlib import Path
import matplotlib.pyplot as plt

from src.dashboard.style import apply_figure_style
from matplotlib.collections import PolyCollection
from matplotlib.colors import PowerNorm
import numpy as np
from src.crystal_plasticity.orientation_colors import (
    REFERENCE_EULER_DEG, relative_rotation, axis_angle_rgb, ipf_nd_rgb,
)


def orientation_color_figure(path, spatial_model_dir, *, metric='axis_angle', title=None,
                             max_angle=65., exponent=.35):
    from src.dashboard.plots import surface_topology, _draw_boundaries
    with Path(path).open(newline='') as f:
        rows=list(csv.DictReader(f))
    if not rows or any(int(r['state'])!=1 for r in rows):
        raise ValueError('Initial orientation requires state01 data')
    textures={r['texture'] for r in rows}
    if len(textures)!=1:
        raise ValueError('Expected one texture per initial map')
    texture=textures.pop()
    ids=[int(r['part_id']) for r in rows]
    if len(set(ids))!=len(ids):
        raise ValueError('Duplicate initial part_id')
    e=np.array([[float(r[k]) for k in ['phi1_rad','Phi_rad','phi2_rad']] for r in rows])
    axis,theta=relative_rotation(e,texture)
    _,parts,faces,boundaries,_=surface_topology(spatial_model_dir)
    by_id={part:i for i,part in enumerate(ids)}
    if set(map(int,parts))-by_id.keys():
        raise ValueError('Missing initial surface orientations')
    index=np.array([by_id[int(p)] for p in parts])
    nodes=np.loadtxt(Path(spatial_model_dir)/'nodes.csv',delimiter=',',skiprows=1,ndmin=2)
    top=nodes[np.isclose(nodes[:,3],nodes[:,3].max())]
    top=top[np.argsort(top[:,0])]
    polygons=[top[np.asarray(face)-1,1:3] for face in faces]
    fig=plt.figure(figsize=(5.5,6.5),layout='constrained')
    grid=fig.add_gridspec(2,1,height_ratios=[5,1.5])
    ax=fig.add_subplot(grid[0]); legend=fig.add_subplot(grid[1]); legend.set_axis_off()
    if metric=='axis_angle':
        colors=axis_angle_rgb(axis,theta,max_angle=max_angle,exponent=exponent)
        coll=PolyCollection(polygons,facecolors=colors[index],edgecolors='none',antialiaseds=False)
        directions=np.vstack([np.eye(3),-np.eye(3)])
        chips=axis_angle_rgb(directions,np.full(6,max_angle),max_angle=max_angle,exponent=exponent)
        for i,(label,color) in enumerate(zip(['+x (RD)','+y (TD)','+z (ND)','-x','-y','-z'],chips)):
            x=(i%3)*.34
            y=.88-(i//3)*.25
            legend.scatter([x+.025],[y],s=110,c=[color],edgecolors='.4',linewidths=.4)
            legend.text(x+.065,y,label,va='center',fontsize=8)
        angles=np.linspace(0,max_angle,256)
        bar=axis_angle_rgb(np.tile([1,0,0],(256,1)),angles,max_angle=max_angle,exponent=exponent)
        legend.imshow(bar[None],extent=(0,1,.08,.2),aspect='auto')
        legend.text(0,-.02,'0°: neutral',fontsize=8,va='top')
        legend.text(1,-.02,f'{max_angle:g}°: full color',ha='right',va='top',fontsize=8)
        legend.text(.5,.3,'Angle strength (example: +x axis)',ha='center',fontsize=8)
        legend.set(xlim=(-.02,1.04),ylim=(-.18,1.05))
    elif metric=='angle':
        coll=PolyCollection(polygons,array=theta[index],cmap='viridis',
                            norm=PowerNorm(exponent,vmin=0,vmax=max_angle),edgecolors='none')
        fig.colorbar(coll,ax=ax,label='Reference disorientation (deg)',extend='max')
    elif metric=='ipf_nd':
        coll=PolyCollection(polygons,facecolors=ipf_nd_rgb(e)[index],edgecolors='none')
        for i,(label,color) in enumerate(zip(['[001]','[101]','[111]'],np.eye(3))):
            legend.scatter([i],[.7],c=[color],s=130)
            legend.text(i,.4,label,ha='center',fontsize=10)
        legend.text(1,.05,'ND IPF: rotation about ND is not resolved',ha='center',fontsize=8)
        legend.set(xlim=(-.6,2.6),ylim=(-.25,1.1))
    else:
        raise ValueError(f'Unknown orientation metric: {metric}')
    ax.add_collection(coll)
    _draw_boundaries(ax,[top[np.array(edge)-1,1:3] for edge in boundaries])
    ax.autoscale_view();ax.margins(0);ax.set_aspect('equal')
    names={'axis_angle':'Initial orientation: axis + angle','angle':'Initial reference angle','ipf_nd':'Initial ND IPF'}
    ax.set(xlabel='x',ylabel='y',title=title or names[metric])
    ref=','.join(map(str,REFERENCE_EULER_DEG[texture]))
    if metric!='ipf_nd':
        visible=theta[np.unique(index)]
        clipped=np.mean(visible>max_angle)*100
        detail=f'Ref: {texture} ({ref}) deg | state01\nLimit {max_angle:g}°; exponent {exponent:g}; above limit {clipped:.1f}%'
        if metric=='angle':
            legend.text(.5,.5,detail,ha='center',va='center',fontsize=9)
        else:
            fig.supxlabel(detail,fontsize=8)
    return apply_figure_style(fig)
