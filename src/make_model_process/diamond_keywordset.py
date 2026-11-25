"""Prepare five-grain geometry and face sets from supplied diamond inputs."""
from collections import Counter
from functools import lru_cache
from pathlib import Path
from tempfile import TemporaryDirectory

import numpy as np
from src.make_model_process.diamond_five_grain import write_diamond_model, NODE_SET_HEADER, NODE_MEMBERS_HEADER
from src.make_model_process.keyword_output import write_output


def blocks(text):
    result=[]
    for line in text.splitlines(keepends=True):
        if line.lstrip().startswith('*'):result.append([line.strip().upper(),[]])
        elif result:result[-1][1].append(line)
    return result


def data(lines):
    return [line.strip() for line in lines if line.strip() and not line.lstrip().startswith('$')]


def fragment(items):
    return ''.join(key+'\n'+''.join(lines).rstrip()+'\n' for key,lines in items)


def nodes_from_text(text):
    result={}
    for key,lines in blocks(text):
        if key=='*NODE':
            for line in data(lines):
                values=line.replace(',',' ').split()
                nid=int(values[0])
                if nid in result:raise ValueError(f'Duplicate node {nid}')
                result[nid]=np.array([float(x) for x in values[1:4]])
    if not result:raise ValueError('No nodes in diamond partset')
    return result


def save_prepared(path,text,overwrite=False):
    payload=text.encode('utf-8')
    if path.exists():
        if path.read_bytes()==payload:return False
        if not overwrite:raise FileExistsError(f'Prepared input differs; use --overwrite after review: {path}')
    write_output(path,payload,overwrite=overwrite)
    print(f'Prepared: {path}')
    return True


def prepare_partset(keywords_dir,central_diagonal=.015,overwrite=False):
    keywords_dir=Path(keywords_dir);raw=keywords_dir/'consts/initmesh_diamond.k';out=keywords_dir/'consts/partset_diamond.k'
    if not raw.is_file():
        if out.is_file():return out
        raise FileNotFoundError(raw)
    section=keywords_dir/'consts/section.k'
    if not section.is_file():raise FileNotFoundError(section)
    with TemporaryDirectory(prefix='diamond_partset_') as temp:
        full=Path(temp)/'full.k'
        write_diamond_model(raw,section,full,central_diagonal=central_diagonal)
        kept=[(k,l) for k,l in blocks(full.read_text()) if k in {'*NODE','*ELEMENT_SOLID','*SET_NODE_LIST','*SET_NODE_LIST_TITLE'}]
        text='*KEYWORD\n'+fragment(kept)+'*END\n'
    parts=[]
    for key,lines in blocks(text):
        if key=='*ELEMENT_SOLID':parts.extend(int(line.replace(',',' ').split()[1]) for line in data(lines))
    if set(parts)!={1,2,3,4,5}:raise ValueError('Prepared partset must contain five grain element groups')
    save_prepared(out,text,overwrite)
    return out


def prepare_boundary(source,partset,output,overwrite=False):
    nodes=nodes_from_text(Path(partset).read_text());ids=np.array(sorted(nodes));xyz=np.array([nodes[i] for i in ids])
    lower=xyz.min(axis=0);upper=xyz.max(axis=0)
    faces={'x0':(0,lower[0]),'x1':(0,upper[0]),'y0':(1,lower[1]),'y1':(1,upper[1]),'z0':(2,lower[2]),'z1':(2,upper[2])}
    result=[];rebuilt=[]
    for key,lines in blocks(Path(source).read_text()):
        if key in {'*KEYWORD','*END','*TITLE'}:continue
        if key=='*SET_NODE_LIST_TITLE':
            values=data(lines);name=values[0]
            raw=[line for line in lines if line.strip() and not line.lstrip().startswith('$')]
            header=raw[1].rstrip('\r\n')
            if name.lower() in faces:
                axis,bound=faces[name.lower()];members=ids[np.isclose(xyz[:,axis],bound,atol=1e-12,rtol=0)]
                new=[name+'\n',NODE_SET_HEADER,header+'\n',NODE_MEMBERS_HEADER]
                new.extend(''.join(f'{int(n):10d}' for n in members[i:i+8])+'\n' for i in range(0,len(members),8))
                result.append((key,new));rebuilt.append(f'{name}:{len(members)}')
                continue
            old=[int(x) for line in values[2:] for x in line.replace(',',' ').split() if int(x)>0]
            if not set(old)<=set(nodes):raise ValueError(f'Unknown invalid boundary set {name}; supply a geometric mapping')
        result.append((key,lines))
    save_prepared(Path(output),fragment(result),overwrite)
    return rebuilt


def prepare_inputs(keywords_dir,rhos,central_diagonal=.015,overwrite=False):
    """Original raw mesh, boundary cards and curves remain untouched."""
    root=Path(keywords_dir)
    raw=root/'consts/initmesh_diamond.k'
    if not raw.is_file():return  # User can also supply an already prepared partset.
    sources=[]
    for rho in rhos:
        folder=root/f'keyword_rho_{rho:g}_diamond'
        source=folder/f'boundary_rho_{rho:g}.k';curve=folder/f'curve_rho_{rho:g}.k'
        for path in [source,curve]:
            if not path.is_file():raise FileNotFoundError(path)
        sources.append((source,folder/f'boundary_diamond_rho_{rho:g}.k'))
    partset=prepare_partset(root,central_diagonal,overwrite)
    for source,output in sources:
        info=prepare_boundary(source,partset,output,overwrite)
        print(f'Boundary faces ({output.parent.name}): '+', '.join(info))


@lru_cache(maxsize=8)
def validate_keywordset(text):
    """Check actual IDs referenced by geometry, node sets, BCs and curves."""
    bb=blocks(text);nodes=nodes_from_text(text);node_ids=set(nodes)
    elements={};sets={};sections=set();curves=set();referenced_sets=[];referenced_curves=[]
    for key,lines in bb:
        values=data(lines)
        if key=='*ELEMENT_SOLID':
            for line in values:
                row=[int(x) for x in line.replace(',',' ').split()]
                if len(row)!=10 or row[0] in elements:raise ValueError('Invalid/duplicate solid element')
                if not set(row[2:])<=node_ids:raise ValueError(f'Element {row[0]} references missing nodes')
                elements[row[0]]=row[1]
        elif key in {'*SET_NODE_LIST','*SET_NODE_LIST_TITLE'}:
            offset=1 if key.endswith('_TITLE') else 0
            sid=int(values[offset].replace(',',' ').split()[0])
            if sid in sets:raise ValueError(f'Duplicate node set {sid}')
            members={int(x) for line in values[offset+1:] for x in line.replace(',',' ').split() if int(x)>0}
            if not members or not members<=node_ids:raise ValueError(f'Node set {sid} references missing/empty nodes')
            sets[sid]=members
        elif key.startswith('*SECTION_SOLID'):
            offset=1 if key.endswith('_TITLE') else 0;sections.add(int(values[offset].replace(',',' ').split()[0]))
        elif key.startswith('*DEFINE_CURVE'):
            offset=1 if key.endswith('_TITLE') else 0;curves.add(int(values[offset].replace(',',' ').split()[0]))
        elif key.startswith('*BOUNDARY_SPC_SET'):
            referenced_sets.extend(int(line.replace(',',' ').split()[0]) for line in values)
        elif key.startswith('*BOUNDARY_PRESCRIBED_MOTION_SET'):
            for line in values:
                v=line.replace(',',' ').split();referenced_sets.append(int(v[0]));referenced_curves.append(int(v[3]))
    if not elements:raise ValueError('No solid elements')
    if not set(referenced_sets)<=set(sets):raise ValueError(f'Missing boundary node sets: {set(referenced_sets)-set(sets)}')
    if not set(referenced_curves)<=curves:raise ValueError('Missing loading curves')
    return {'nodes':len(nodes),'elements':len(elements),'part_counts':dict(Counter(elements.values())),
            'sections':sections,'node_sets':sets,'curve_ids':curves}


def validate_material_links(text,info):
    parts={};materials=set()
    for key,lines in blocks(text):
        values=data(lines)
        if key=='*PART':
            row=values[1].replace(',',' ').split();pid,section,mid=map(int,row[:3])
            if pid in parts:raise ValueError(f'Duplicate part {pid}')
            parts[pid]=(section,mid)
        elif key.startswith('*MAT_'):
            offset=1 if key.endswith('_TITLE') else 0
            mid=int(values[offset].replace(',',' ').split()[0])
            if mid in materials:raise ValueError(f'Duplicate material {mid}')
            materials.add(mid)
    if not set(info['part_counts'])<=set(parts):raise ValueError('Elements reference missing PART cards')
    for pid,(section,mid) in parts.items():
        if section not in info['sections']:raise ValueError(f'PART {pid} references missing section {section}')
        if mid not in materials:raise ValueError(f'PART {pid} references missing material {mid}')
    return len(parts),len(materials)
