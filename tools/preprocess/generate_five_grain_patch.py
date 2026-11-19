"""Conforming five-grain columnar HEX8 patch, mesh only (LS-DYNA keyword).

One central quadrilateral, four surrounding quadrilaterals, extruded in z.
No material, orientation, loading or solver-control assumptions are added.
"""
from __future__ import annotations
import argparse
from collections import Counter, defaultdict, deque
import csv
import json
from pathlib import Path
import numpy as np

FACE_LOCAL = ((0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7))
SIGNS = np.array([[-1,-1,-1],[1,-1,-1],[1,1,-1],[-1,1,-1],[-1,-1,1],[1,-1,1],[1,1,1],[-1,1,1]],float)

def build(width=.5, center_width=.2, thickness=.01, tangential=20, radial=15,
          layers=4, geometry_seed=1, jitter=0.):
    if not 0<center_width<width or thickness<=0:
        raise ValueError('Require 0 < center_width < width and thickness > 0')
    if min(tangential, radial, layers)<1 or not 0<=jitter<=.25:
        raise ValueError('Positive subdivisions required; jitter must be in [0,0.25]')
    a,L=center_width/2,width/2
    inner=np.array([[-a,-a],[a,-a],[a,a],[-a,a]],float)
    rng=np.random.default_rng(geometry_seed)
    inner+=rng.uniform(-jitter*a,jitter*a,(4,2))
    outer=np.array([[-L,-L],[L,-L],[L,L],[-L,L]],float)
    # Each quad is counterclockwise. Shared edges have matching subdivisions.
    blocks=[(1,inner,tangential,tangential),
            (2,np.array([inner[1],outer[1],outer[2],inner[2]]),radial,tangential),
            (3,np.array([inner[3],inner[2],outer[2],outer[3]]),tangential,radial),
            (4,np.array([outer[0],inner[0],inner[3],outer[3]]),radial,tangential),
            (5,np.array([outer[0],outer[1],inner[1],inner[0]]),tangential,radial)]
    nodes=[];lookup={};elements=[];parts=[]
    def node(xyz):
        key=tuple(np.round(xyz,12))
        if key not in lookup:lookup[key]=len(nodes)+1;nodes.append(xyz)
        return lookup[key]
    for pid,q,nu,nv in blocks:
        ids=np.empty((layers+1,nv+1,nu+1),int)
        for k in range(layers+1):
            for j in range(nv+1):
                v=j/nv
                for i in range(nu+1):
                    u=i/nu
                    xy=(1-u)*(1-v)*q[0]+u*(1-v)*q[1]+u*v*q[2]+(1-u)*v*q[3]+L
                    ids[k,j,i]=node(np.array([*xy,thickness*k/layers]))
        for k in range(layers):
            for j in range(nv):
                for i in range(nu):
                    elements.append([ids[k,j,i],ids[k,j,i+1],ids[k,j+1,i+1],ids[k,j+1,i],
                                     ids[k+1,j,i],ids[k+1,j,i+1],ids[k+1,j+1,i+1],ids[k+1,j+1,i]])
                    parts.append(pid)
    return np.asarray(nodes),np.asarray(elements),np.asarray(parts),inner+L

def validate(nodes,elements,parts,width,thickness):
    if set(parts)!=set(range(1,6)):raise ValueError('Expected exactly five grains')
    if elements.min()!=1 or elements.max()!=len(nodes):raise ValueError('Invalid node range')
    if any(len(set(e))!=8 for e in elements):raise ValueError('Degenerate connectivity')
    if len(np.unique(np.round(nodes,12),axis=0))!=len(nodes):raise ValueError('Coincident unmerged nodes')
    if len(np.unique(np.sort(elements,axis=1),axis=0))!=len(elements):raise ValueError('Duplicate elements')
    if len(np.unique(elements))!=len(nodes):raise ValueError('Unused node')
    xyz=nodes[elements-1];vol=np.zeros(len(elements));minimum=float('inf');scaled_min=1.
    for point in [*[(i,j,k) for i in [-1/np.sqrt(3),1/np.sqrt(3)] for j in [-1/np.sqrt(3),1/np.sqrt(3)] for k in [-1/np.sqrt(3),1/np.sqrt(3)]],(0.,0.,0.)]:
        factors=1+SIGNS*np.asarray(point)
        deriv=np.column_stack([SIGNS[:,i]*np.prod(factors[:,[j for j in range(3) if j!=i]],axis=1)/8 for i in range(3)])
        jac=np.einsum('eai,aj->eij',xyz,deriv);det=np.linalg.det(jac)
        minimum=min(minimum,float(det.min()))
        scaled=det/np.prod(np.linalg.norm(jac,axis=1),axis=1)
        scaled_min=min(scaled_min,float(scaled.min()))
        if not np.isfinite(det).all() or (det<=0).any():raise ValueError('Nonpositive Gauss/center Jacobian')
        if point!=(0.,0.,0.):vol+=det
    # Corner Jacobians catch warped/inverted corners missed at Gauss points.
    for point in SIGNS:
        f=1+SIGNS*point;d=np.column_stack([SIGNS[:,i]*np.prod(f[:,[j for j in range(3) if j!=i]],axis=1)/8 for i in range(3)])
        jac=np.einsum('eai,aj->eij',xyz,d);det=np.linalg.det(jac)
        if (det<=0).any():raise ValueError('Nonpositive corner Jacobian')
        minimum=min(minimum,float(det.min()));scaled_min=min(scaled_min,float((det/np.prod(np.linalg.norm(jac,axis=1),axis=1)).min()))
    if not np.isclose(vol.sum(),width*width*thickness,rtol=1e-10):raise ValueError('Domain-volume mismatch')
    faces=defaultdict(list)
    for ei,element in enumerate(elements):
        for local in FACE_LOCAL:
            face=tuple(element[list(local)]);faces[tuple(sorted(face))].append((ei,face))
    adjacency=defaultdict(set);interfaces=defaultdict(list);graph=[[] for _ in elements];external=[]
    for owners in faces.values():
        if len(owners)>2:raise ValueError('Nonmanifold face')
        if len(owners)==2:
            i,j=owners[0][0],owners[1][0];graph[i].append(j);graph[j].append(i)
            if parts[i]!=parts[j]:
                pair=tuple(sorted((int(parts[i]),int(parts[j]))));adjacency[pair[0]].add(pair[1]);adjacency[pair[1]].add(pair[0]);interfaces[pair].append(owners[0][1])
        else:
            face=owners[0][1];v=nodes[np.asarray(face)-1]
            if not any(np.allclose(v[:,axis],limit,rtol=0,atol=1e-11) for axis,limits in enumerate([(0,width),(0,width),(0,thickness)]) for limit in limits):raise ValueError('Interior hole or nonconforming face')
            external.append(face)
    seen={0};queue=deque([0])
    while queue:
        for j in graph[queue.popleft()]:
            if j not in seen:seen.add(j);queue.append(j)
    if len(seen)!=len(elements):raise ValueError('Disconnected element mesh')
    if adjacency[1]!={2,3,4,5}:raise ValueError('Center must have four face-sharing neighbors')
    edges=xyz[:,[1,2,3,0,5,6,7,4,4,5,6,7]]-xyz[:,[0,1,2,3,4,5,6,7,0,1,2,3]]
    lengths=np.linalg.norm(edges,axis=2)
    report={'node_count':len(nodes),'element_count':len(elements),'part_count':5,
            'total_volume':float(vol.sum()),'expected_volume':width**2*thickness,
            'minimum_jacobian':minimum,'minimum_scaled_jacobian':scaled_min,
            'maximum_element_edge_ratio':float((lengths.max(axis=1)/lengths.min(axis=1)).max()),
            'face_connected_components':1,'nonmanifold_faces':0,'internal_unpaired_faces':0,
            'center_face_neighbors':sorted(adjacency[1]),
            'per_part':{str(p):{'element_count':int(sum(parts==p)),'volume':float(vol[parts==p].sum())} for p in range(1,6)},
            'interface_face_counts':{f'{a}-{b}':len(fs) for (a,b),fs in sorted(interfaces.items())},
            'solver_execution_verified':False}
    return report,interfaces

def sets(nodes,width,thickness,interfaces):
    groups={}
    for sid,(axis,value,name) in enumerate([(0,0,'XMIN'),(0,width,'XMAX'),(1,0,'YMIN'),(1,width,'YMAX'),(2,0,'ZMIN'),(2,thickness,'ZMAX')],101):
        groups[sid]=(name,np.where(np.isclose(nodes[:,axis],value,rtol=0,atol=1e-11))[0]+1)
    for p in range(2,6):groups[299+p]=(f'INTERFACE_CENTER_TO_PART_{p}',np.unique(np.asarray(interfaces[(1,p)])))
    return groups

def write_keyword(path,nodes,elements,parts,node_sets):
    with path.open('w') as f:
        f.write('*KEYWORD\n*TITLE\nFive columnar grains: center plus four face-sharing neighbors; MESH ONLY\n')
        f.write('$ Coordinates follow the existing 0.5 x 0.5 x 0.01 model by default.\n')
        f.write('$ MID 1..5 reserved for crystal-plasticity materials; not defined here.\n')
        f.write('*SECTION_SOLID\n$    SECID    ELFORM\n         1         1\n')
        for p,name in [(1,'CENTER'),(2,'EAST_XPLUS'),(3,'NORTH_YPLUS'),(4,'WEST_XMINUS'),(5,'SOUTH_YMINUS')]:
            f.write(f'*PART\nGRAIN_{p}_{name}\n{p:10d}{1:10d}{p:10d}{0:10d}{0:10d}{0:10d}{0:10d}{0:10d}\n')
        f.write('*NODE\n$    NID               X               Y               Z\n')
        for i,xyz in enumerate(nodes,1):f.write(f'{i:8d}'+''.join(f'{v:16.10g}' for v in xyz)+'\n')
        f.write('*ELEMENT_SOLID\n$    EID     PID      N1      N2      N3      N4      N5      N6      N7      N8\n')
        for eid,(pid,element) in enumerate(zip(parts,elements),1):f.write(f'{eid:8d}{pid:8d}'+''.join(f'{n:8d}' for n in element)+'\n')
        for sid,(name,ids) in node_sets.items():
            f.write('*SET_NODE_LIST_TITLE\n'+name+'\n'+f'{sid:10d}\n')
            for start in range(0,len(ids),8):f.write(''.join(f'{n:10d}' for n in ids[start:start+8])+'\n')
        f.write('*END\n')

def read_keyword(path):
    mode='';nodes=[];elements=[];parts=[]
    for line in path.read_text().splitlines():
        if line.startswith('*'):mode=line.strip();continue
        if not line.strip() or line.startswith('$'):continue
        if mode=='*NODE':nodes.append([float(line[8+16*i:24+16*i]) for i in range(3)])
        elif mode=='*ELEMENT_SOLID':
            values=[int(line[i:i+8]) for i in range(0,80,8)];parts.append(values[1]);elements.append(values[2:])
    return np.array(nodes),np.array(elements),np.array(parts)

def preview(path,nodes,elements,parts,inner,width,thickness):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    from matplotlib.collections import PolyCollection
    top=np.all(np.isclose(nodes[elements[:,4:]-1,2],thickness),axis=1)
    polys=nodes[elements[top,4:]-1,:2]
    colors=np.array(['#2088b5','#e7aa55','#71b38a','#af92cb','#e17d7a'])
    fig,ax=plt.subplots(figsize=(8,8));ax.add_collection(PolyCollection(polys,facecolors=colors[parts[top]-1],edgecolors='#555555',linewidths=.2))
    centers={1:inner.mean(axis=0)}
    corners=np.array([[0,0],[width,0],[width,width],[0,width]])
    for pid,quad in [(2,[inner[1],corners[1],corners[2],inner[2]]),(3,[inner[3],inner[2],corners[2],corners[3]]),(4,[corners[0],inner[0],inner[3],corners[3]]),(5,[corners[0],corners[1],inner[1],inner[0]])]:centers[pid]=np.mean(quad,axis=0)
    for pid,center in centers.items():ax.text(*center,f'Grain {pid}',ha='center',va='center',fontsize=14,bbox={'facecolor':'white','alpha':.85,'edgecolor':'none','pad':3})
    ax.set(xlim=(-width*.04,width*1.04),ylim=(-width*.04,width*1.04),xlabel='X / RD (model length unit)',ylabel='Y / TD (model length unit)',title=f'Five-grain conforming HEX8 mesh: top view\nThickness {thickness:g}; {len(elements):,} elements; interfaces share nodes')
    ax.set_aspect('equal');fig.tight_layout();fig.savefig(path,dpi=160);plt.close(fig)

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output-dir',type=Path,required=True)
    for name,value in [('width',.5),('center-width',.2),('thickness',.01),('jitter',0.)]:p.add_argument('--'+name,type=float,default=value)
    for name,value in [('tangential',20),('radial',15),('layers',4),('geometry-seed',1)]:p.add_argument('--'+name,type=int,default=value)
    a=p.parse_args();a.output_dir.mkdir(parents=True,exist_ok=True)
    nodes,elements,parts,inner=build(a.width,a.center_width,a.thickness,a.tangential,a.radial,a.layers,a.geometry_seed,a.jitter)
    report,interfaces=validate(nodes,elements,parts,a.width,a.thickness)
    groups=sets(nodes,a.width,a.thickness,interfaces);kw=a.output_dir/'five_grain_patch.k';write_keyword(kw,nodes,elements,parts,groups)
    loaded=read_keyword(kw);readback,_=validate(*loaded,a.width,a.thickness)
    if not np.array_equal(loaded[1],elements) or not np.array_equal(loaded[2],parts):raise ValueError('Keyword roundtrip changed topology')
    report['keyword_roundtrip_verified']=True;report['written_minimum_jacobian']=readback['minimum_jacobian']
    report['parameters']={k:str(v) if isinstance(v,Path) else v for k,v in vars(a).items()};report['inner_vertices_xy']=inner.tolist();report['node_sets']={str(s):{'name':n,'node_count':len(v)} for s,(n,v) in groups.items()}
    (a.output_dir/'mesh_validation.json').write_text(json.dumps(report,indent=2)+'\n')
    with (a.output_dir/'grain_interfaces.csv').open('w') as f:
        w=csv.writer(f);w.writerow(['part_a','part_b','node1','node2','node3','node4'])
        for (u,v),faces in sorted(interfaces.items()):
            for face in faces:w.writerow([u,v,*face])
    preview(a.output_dir/'mesh_top_view.png',nodes,elements,parts,inner,a.width,a.thickness)
    print(json.dumps({k:report[k] for k in ['node_count','element_count','part_count','minimum_jacobian','minimum_scaled_jacobian','center_face_neighbors','keyword_roundtrip_verified']}))

if __name__=='__main__':main()
