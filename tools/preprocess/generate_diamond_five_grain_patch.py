"""Simple five-columnar-grain patch matching the diamond-center sketch.

Five coplanar sites define exact planar Voronoi grain boundaries. Convex
polygons are quadrangulated and extruded into a conforming HEX8 mesh.
No voxel/material-ID approximation at grain boundaries. Unit: mm.
"""
from __future__ import annotations
import argparse
import csv
import json
from pathlib import Path
import numpy as np
if __package__:
    from .generate_five_grain_patch import validate, sets, write_keyword, read_keyword
else:
    from generate_five_grain_patch import validate, sets, write_keyword, read_keyword


def clip(poly,a,b):
    out=[]
    for start,end in zip(poly,np.roll(poly,-1,axis=0)):
        f,g=np.dot(a,start)-b,np.dot(a,end)-b
        if f<=1e-12:out.append(start)
        if (f< -1e-12 and g>1e-12) or (f>1e-12 and g< -1e-12):out.append(start+(end-start)*f/(f-g))
    result=[]
    for v in out:
        if not result or np.linalg.norm(v-result[-1])>1e-10:result.append(v)
    if len(result)>1 and np.linalg.norm(result[-1]-result[0])<1e-10:result.pop()
    return np.array(result)


def partition(width,diagonal,rotation):
    c=np.array([width/2,width/2]);angles=np.deg2rad(rotation+45+90*np.arange(4))
    seeds=np.vstack((c,c+diagonal/np.sqrt(2)*np.c_[np.cos(angles),np.sin(angles)]))
    polygons=[]
    for i,p in enumerate(seeds):
        q=np.array([[0.,0.],[width,0.],[width,width],[0.,width]])
        for j,t in enumerate(seeds):
            if i!=j:q=clip(q,2*(t-p),float(t@t-p@p))
        if len(q)<3:raise ValueError('Empty grain')
        polygons.append(q)
    # Insert all shared vertices onto all collinear polygon sides, avoiding T-junctions.
    allv=np.unique(np.round(np.vstack(polygons),12),axis=0);clean=[]
    for poly in polygons:
        out=[]
        for x,y in zip(poly,np.roll(poly,-1,axis=0)):
            edge=y-x;ts=(allv-x)@edge/(edge@edge);dist=np.linalg.norm(allv-(x+ts[:,None]*edge),axis=1)
            take=(dist<1e-10)&(ts>=-1e-9)&(ts<1-1e-9)
            out.extend(allv[take][np.argsort(ts[take])])
        clean.append(np.array(out))
    return seeds,clean


def polygon_centroid(poly):
    q=np.roll(poly,-1,axis=0);a=poly[:,0]*q[:,1]-q[:,0]*poly[:,1]
    area=a.sum()/2
    return ((poly+q)*a[:,None]).sum(axis=0)/(6*area),area


def build(width,diagonal,thickness,rotation,subdivisions,layers):
    if not 0<diagonal<width or thickness<=0 or min(subdivisions,layers)<1:raise ValueError('Invalid geometry or subdivisions')
    seeds,polygons=partition(width,diagonal,rotation)
    nodes=[];lookup={};elements=[];parts=[];coarse=[]
    def node(xyz):
        key=tuple(np.round(xyz,12))
        if key not in lookup:lookup[key]=len(nodes)+1;nodes.append(np.asarray(xyz))
        return lookup[key]
    for pid,poly in enumerate(polygons,1):
        hub,_=polygon_centroid(poly)
        for k,v in enumerate(poly):
            quad=np.array([v,(v+poly[(k+1)%len(poly)])/2,hub,(poly[k-1]+v)/2]);coarse.append((pid,quad))
            n=subdivisions;ids=np.empty((layers+1,n+1,n+1),int)
            for iz in range(layers+1):
                for iy in range(n+1):
                    y=iy/n
                    for ix in range(n+1):
                        x=ix/n;xy=(1-x)*(1-y)*quad[0]+x*(1-y)*quad[1]+x*y*quad[2]+(1-x)*y*quad[3]
                        ids[iz,iy,ix]=node([*xy,thickness*iz/layers])
            for iz in range(layers):
                for iy in range(n):
                    for ix in range(n):
                        elements.append([ids[iz,iy,ix],ids[iz,iy,ix+1],ids[iz,iy+1,ix+1],ids[iz,iy+1,ix],ids[iz+1,iy,ix],ids[iz+1,iy,ix+1],ids[iz+1,iy+1,ix+1],ids[iz+1,iy+1,ix]])
                        parts.append(pid)
    return np.array(nodes),np.array(elements),np.array(parts),seeds,polygons,coarse


def preview(path,nodes,elements,parts,polygons,seeds,width,thickness):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    from matplotlib.collections import PolyCollection
    colors=np.array(['#2088b5','#e7aa55','#71b38a','#af92cb','#e17d7a'])
    top=np.all(np.isclose(nodes[elements[:,4:]-1,2],thickness,atol=1e-12,rtol=0),axis=1)
    fig,(ax,bx)=plt.subplots(1,2,figsize=(11,5.6))
    ax.add_collection(PolyCollection(polygons,facecolors=colors,edgecolors='black',linewidths=1.7))
    for pid,poly in enumerate(polygons,1):
        c,_=polygon_centroid(poly);ax.text(*c,f'{pid}',ha='center',va='center',fontsize=17)
    bx.add_collection(PolyCollection(nodes[elements[top,4:]-1,:2],facecolors=colors[parts[top]-1],edgecolors='#555555',linewidths=.16))
    bx.add_collection(PolyCollection(polygons,facecolors='none',edgecolors='black',linewidths=1.5))
    for a,title in [(ax,'Grain geometry (top view)'),(bx,'Boundary-conforming shared-node mesh')]:
        a.set(xlim=(-.03*width,1.03*width),ylim=(-.03*width,1.03*width),aspect='equal',xlabel='X / RD (mm)',ylabel='Y / TD (mm)',title=title)
    fig.suptitle(f'Five columnar grains: diamond center and four neighbors\n{width:g} x {width:g} x {thickness:g} mm; {len(elements):,} HEX8 elements',fontsize=13)
    fig.tight_layout(rect=[0,0,1,.88]);fig.savefig(path,dpi=160);plt.close(fig)


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output-dir',type=Path,required=True)
    p.add_argument('--d',type=float,default=.015);p.add_argument('--central-diagonal',type=float)
    p.add_argument('--rotation-deg',type=float,default=0.);p.add_argument('--subdivisions',type=int,default=12);p.add_argument('--layers',type=int,default=8)
    a=p.parse_args();d=a.d
    if d<=0:raise ValueError('d must be positive')
    diagonal=d if a.central_diagonal is None else a.central_diagonal;width=2*d;thickness=.5*d
    a.output_dir.mkdir(parents=True,exist_ok=True)
    n,e,parts,seeds,polygons,coarse=build(width,diagonal,thickness,a.rotation_deg,a.subdivisions,a.layers)
    report,interfaces=validate(n,e,parts,width,thickness);groups=sets(n,width,thickness,interfaces)
    path=a.output_dir/'diamond_center_5grains.k';write_keyword(path,n,e,parts,groups)
    text=path.read_text().replace('Five columnar grains: center plus four face-sharing neighbors; MESH ONLY','Diamond center + four columnar neighbors; conforming HEX8; MESH ONLY')
    text=text.replace('$ Coordinates follow the existing 0.5 x 0.5 x 0.01 model by default.','$ Unit: mm. Exact planar grain interfaces; no voxel grain-boundary staircase.')
    for old,pid in [('EAST_XPLUS',2),('NORTH_YPLUS',3),('WEST_XMINUS',4),('SOUTH_YMINUS',5)]:text=text.replace(f'GRAIN_{pid}_{old}',f'GRAIN_{pid}_VORONOI_NEIGHBOR')
    path.write_text(text)
    nn,ee,pp=read_keyword(path);r2,_=validate(nn,ee,pp,width,thickness)
    if not np.array_equal(e,ee) or not np.array_equal(parts,pp):raise ValueError('Keyword roundtrip changed topology')
    centers=nn[ee-1].mean(axis=1)
    nearest=np.argmin(np.sum((centers[:,None,:2]-seeds[None,:,:])**2,axis=2),axis=1)+1
    if not np.array_equal(nearest,parts):raise ValueError('Element parts differ from exact planar Voronoi cells')
    rows=[]
    for pid,poly in enumerate(polygons,1):
        cent,area=polygon_centroid(poly)
        exact=area*thickness
        if not np.isclose(exact,report['per_part'][str(pid)]['volume'],rtol=1e-9):raise ValueError('Exact polygon and mesh volumes differ')
        rows.append([pid,*seeds[pid-1],thickness,*cent,thickness/2,exact])
    report.update({'unit':'mm','d_mm':d,'domain_dimensions_mm':[width,width,thickness],
                   'central_diagonal_mm':diagonal,'central_side_length_mm':diagonal/np.sqrt(2),
                   'central_edge_angles_to_RD_deg':[45+a.rotation_deg,135+a.rotation_deg],
                   'rotation_deg':a.rotation_deg,'through_thickness_columnar_grains':True,
                   'coarse_quad_count':len(coarse),'subdivisions_per_coarse_quad_edge':a.subdivisions,'thickness_layers':a.layers,
                   'voronoi_sites_mm':np.c_[seeds,np.full(5,thickness)].tolist(),
                   'exact_grain_polygons_xy_mm':[v.tolist() for v in polygons],
                   'keyword_roundtrip_verified':True,'all_elements_match_planar_voronoi':True,
                   'written_minimum_scaled_jacobian':r2['minimum_scaled_jacobian'],
                   'node_sets':{str(i):{'name':name,'node_count':len(ids)} for i,(name,ids) in groups.items()}})
    (a.output_dir/'mesh_validation.json').write_text(json.dumps(report,indent=2)+'\n')
    with (a.output_dir/'grain_geometry.csv').open('w') as f:
        w=csv.writer(f);w.writerow(['part_id','site_x_mm','site_y_mm','site_z_mm','centroid_x_mm','centroid_y_mm','centroid_z_mm','volume_mm3']);w.writerows(rows)
    with (a.output_dir/'grain_interfaces.csv').open('w') as f:
        w=csv.writer(f);w.writerow(['part_a','part_b','node1','node2','node3','node4'])
        for pair,faces in sorted(interfaces.items()):
            for face in faces:w.writerow([*pair,*face])
    with (a.output_dir/'grain_interface_summary.csv').open('w') as f:
        w=csv.writer(f);w.writerow(['part_a','part_b','normal_x','normal_y','normal_z','normal_azimuth_deg','shared_area_mm2','mesh_face_count'])
        for (i,j),faces in sorted(interfaces.items()):
            delta=seeds[j-1]-seeds[i-1];normal=delta/np.linalg.norm(delta)
            q=n[np.asarray(faces)-1]
            area=float((np.linalg.norm(np.cross(q[:,1]-q[:,0],q[:,2]-q[:,0]),axis=1)+np.linalg.norm(np.cross(q[:,2]-q[:,0],q[:,3]-q[:,0]),axis=1)).sum()/2)
            w.writerow([i,j,*normal,0.,float(np.degrees(np.arctan2(normal[1],normal[0]))),area,len(faces)])
    preview(a.output_dir/'geometry_preview.png',n,e,parts,polygons,seeds,width,thickness)
    print(json.dumps({k:report[k] for k in ['node_count','element_count','minimum_scaled_jacobian','center_face_neighbors','central_diagonal_mm','all_elements_match_planar_voronoi']}))

if __name__=='__main__':main()
