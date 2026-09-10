"""Unified initial/state Taylor workflow; one manifest CSV per rho/seed.

state01 uses input Euler radians; later states use saved MTEX grain-mean
Euler degrees. Both call the same FCC solver, with nominal rho. No slip CSV
or measured equivalent plastic strain is used.
"""
import argparse
from collections import Counter
from dataclasses import replace
from functools import lru_cache
import hashlib
from pathlib import Path
import re
import numpy as np
import pandas as pd
from src.config.pipeline_paths import PROJECT_ROOT, OUTPUTS_DIR
from src.crystal_plasticity.taylor_factor import primal_check, taylor_factor

TARGET_COLUMNS = ['mean_phi1_target_deg','mean_Phi_target_deg','mean_phi2_target_deg']
RAD_COLUMNS = ['phi1_rad','Phi_rad','phi2_rad']


def output_dir(rho, seed, destination=OUTPUTS_DIR):
    return Path(destination)/f'rho_{rho:g}'/f'rho_{rho:g}_seed{seed}'/'angles'/'taylor_factor'


def output_path(record, destination=OUTPUTS_DIR):
    case=f'{record.texture}_sd{record.sd}_seed{record.seed}'
    return output_dir(record.rho,record.seed,destination)/case/f'taylor_factor_{case}_state{record.state:02d}.csv'


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


@lru_cache(maxsize=16)
def _counts(path, signature):
    counts=Counter();active=False
    for line in Path(path).read_text().splitlines():
        if line.startswith('*'):
            active=line.strip()=='*ELEMENT_SOLID'
        elif active and line.strip() and not line.startswith('$'):
            fields=line.split()
            if len(fields)!=10:raise ValueError(f'Unsupported element record: {line}')
            counts[int(fields[1])]+=1
    if not counts:raise ValueError(f'No solid elements: {path}')
    return counts


def mesh_counts(seed, root=PROJECT_ROOT):
    path=Path(root)/f'inputs/keywords/consts/partset_seed{seed}.k'
    return _counts(str(path),digest(path))


def _solve_frame(ids, counts, angles, rho, state):
    angles=np.asarray(angles,float); ids=np.asarray(ids);counts=np.asarray(counts)
    if angles.shape != (len(ids),3) or not len(ids) or not np.isfinite(angles).all():
        raise ValueError('Expected finite Euler triples')
    if (len(np.unique(ids))!=len(ids) or not np.isfinite(ids).all()
        or (ids<=0).any() or not np.equal(ids,ids.astype(int)).all()):
        raise ValueError('Invalid or duplicate grain IDs')
    if counts.shape!=ids.shape or not np.isfinite(counts).all() or (counts<0).any():
        raise ValueError('Invalid element counts')
    values=taylor_factor(angles,rho)
    np.testing.assert_allclose(values[:3],primal_check(angles[:3],rho),atol=1e-9)
    result=pd.DataFrame(angles,columns=RAD_COLUMNS)
    result.insert(0,'element_count',counts)
    result.insert(0,'part_id',ids)
    result['state']=state;result['rho_used']=rho;result['taylor_factor']=values
    return result


def calculate_initial_frame(angles, counts, rho):
    angles=np.asarray(angles,float)
    if max(counts,default=0)>len(angles):raise ValueError('Mesh part without orientation')
    ids=np.arange(1,len(angles)+1)
    return _solve_frame(ids,[counts.get(int(i),0) for i in ids],angles,rho,1)


def calculate_state_frame(frame,rho,state):
    required={'part_id','element_count','target_state',*TARGET_COLUMNS}
    if required-set(frame):raise ValueError(f'Missing grain-mean columns: {sorted(required-set(frame))}')
    if state<=1 or not frame.target_state.eq(state).all():raise ValueError('Target state mismatch')
    result=_solve_frame(frame.part_id,frame.element_count,np.deg2rad(frame[TARGET_COLUMNS]),rho,state)
    # Preserve original source columns for traceability and existing consumers.
    for column in TARGET_COLUMNS:result[column]=frame[column].to_numpy()
    return result


def input_signature(record, root=PROJECT_ROOT):
    from src.crystal_plasticity import taylor_factor as solver
    return {'source':str(record.path.resolve()),'source_sha256':digest(record.path),
            'solver_sha256':hashlib.sha256(Path(solver.__file__).read_bytes()+Path(__file__).read_bytes()).hexdigest(),
            'mesh_sha256':digest(Path(root)/f'inputs/keywords/consts/partset_seed{record.seed}.k') if record.state==1 else '',
            'rho':record.rho,'state':record.state}


def _atomic_csv(frame,path):
    temporary=path.with_suffix('.csv.tmp')
    frame.to_csv(temporary,index=False,float_format='%.12g')
    temporary.replace(path)


def export_record(record,destination=OUTPUTS_DIR,*,root=PROJECT_ROOT):
    if record.state==1:
        result=calculate_initial_frame(np.loadtxt(record.path,delimiter=',',ndmin=2),mesh_counts(record.seed,root),record.rho)
    else:
        result=calculate_state_frame(pd.read_csv(record.path),record.rho,record.state)
    for name in ['texture','sd','seed']:result[name]=getattr(record,name)
    out=output_path(record,destination);out.parent.mkdir(parents=True,exist_ok=True)
    _atomic_csv(result,out)
    present=result.loc[result.element_count>0,'taylor_factor']
    row={**input_signature(record,root),'file':out.relative_to(output_dir(record.rho,record.seed,destination)).as_posix(),'output_sha256':digest(out),
         'texture':record.texture,'sd':record.sd,'seed':record.seed,
         'orientation_source':'initial_input' if record.state==1 else 'target_grain_mean',
         'rows':len(result),'grains':len(present),'min':present.min(),'max':present.max(),'mean':present.mean()}
    manifest=output_dir(record.rho,record.seed,destination)/'manifest.csv'
    previous=pd.read_csv(manifest,keep_default_na=False) if manifest.exists() else pd.DataFrame()
    combined=pd.concat([previous,pd.DataFrame([row])],ignore_index=True)
    combined=combined.drop_duplicates('file',keep='last').sort_values(['texture','sd','state'])
    _atomic_csv(combined,manifest)
    return row


def ensure_record(record,destination=OUTPUTS_DIR,*,force=False,root=PROJECT_ROOT):
    """One folder-level manifest replaces per-file JSON fingerprints."""
    out=output_path(record,destination);manifest=output_dir(record.rho,record.seed,destination)/'manifest.csv'
    valid=False
    if out.exists() and manifest.exists():
        try:
            table=pd.read_csv(manifest,keep_default_na=False)
            matches=table.loc[table['file'].eq(out.relative_to(manifest.parent).as_posix())]
            if len(matches)==1:
                saved=matches.iloc[0]
                valid=all(saved[k]==v for k,v in input_signature(record,root).items()) and saved.output_sha256==digest(out)
        except (ValueError,KeyError,pd.errors.ParserError):pass
    if force or not valid:export_record(record,destination,root=root)
    return replace(record,kind='initial' if record.state==1 else 'taylor',path=out,
                   source='initial_grain_metrics' if record.state==1 else 'state_grain_mean')


def source_records(root=PROJECT_ROOT):
    from src.dashboard.catalog import OutputRecord,scan_outputs
    root=Path(root)
    records=[r for r in scan_outputs(root/'outputs') if r.kind=='orientation' and r.state>1]
    rhos=sorted(float(p.name.removeprefix('rho_')) for p in (root/'outputs').glob('rho_*') if p.is_dir())
    for path in sorted((root/'inputs/orientation').glob('texture_seed*/*.csv')):
        match=re.fullmatch(r'(\w+)_sigma(\d+)_seed(\d+)',path.stem)
        if match is None:raise ValueError(f'Unrecognized orientation filename: {path}')
        texture,sd,seed=match.groups()
        for rho in rhos:records.append(OutputRecord('initial',rho,int(seed),texture,int(sd),1,path,'initial_input'))
    return sorted(records,key=lambda r:r.case_key)


def main(argv=None,*,default_states=None):
    parser=argparse.ArgumentParser(description='Calculate initial (state01) and deformed grain-mean Taylor factors.')
    parser.add_argument('--state',type=int,nargs='+',default=default_states)
    parser.add_argument('--rho',type=float);parser.add_argument('--seed',type=int)
    parser.add_argument('--texture');parser.add_argument('--sd',type=int)
    parser.add_argument('--force',action='store_true',help='Recalculate even unchanged files')
    args=parser.parse_args(argv)
    if args.state and min(args.state)<1:parser.error('state must be >=1')
    records=[r for r in source_records() if (args.state is None or r.state in args.state)
             and all(getattr(args,k) is None or getattr(r,k)==getattr(args,k) for k in ['rho','seed','texture','sd'])]
    if not records:parser.error('No matching source orientations')
    for i,record in enumerate(records,1):
        ensure_record(record,force=args.force)
        if i%500==0:print(f'{i}/{len(records)} completed',flush=True)
    print(f'Completed {len(records)} files under outputs/rho_*/rho_*_seed*/angles/taylor_factor',flush=True)


if __name__=='__main__':main()
