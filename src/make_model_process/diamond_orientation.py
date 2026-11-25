"""Case planning and MATLAB/MTEX bridge for within-model mirror mixtures."""
from dataclasses import dataclass
from pathlib import Path
import shutil
import subprocess
import sys

import numpy as np
from scipy.io import loadmat
from src.crystal_plasticity.orientation_colors import REFERENCE_EULER_DEG

ROOT=Path(__file__).resolve().parents[2]
MTEX_DIR=ROOT/'src/mtex-5.11.1'


@dataclass(frozen=True)
class OrientationCase:
    seed: int
    degree: float
    texture: str
    sample: int
    numbered: bool=False

    @property
    def stem(self):
        return f'{self.texture}_case{self.sample:02d}' if self.numbered else self.texture

    def csv_path(self,root):
        return Path(root)/f'seed_{self.seed}'/f'deg_{self.degree:g}'/f'{self.stem}.csv'

    def material_path(self,root):
        return Path(root)/f'seed_{self.seed}'/f'deg_{self.degree:g}'/f'partsmat_{self.stem}.k'


def plan_cases(seeds,degrees,textures,samples_per_seed=1):
    seeds=list(seeds);degrees=list(degrees);textures=list(textures)
    if not seeds or len(set(seeds))!=len(seeds) or any(not isinstance(s,(int,np.integer)) or s<0 for s in seeds):
        raise ValueError('Seeds must be unique nonnegative integers')
    if not degrees or len(set(degrees))!=len(degrees) or any(not np.isfinite(d) or not 0<=d<45 for d in degrees):
        raise ValueError('Degrees must be unique and in [0,45)')
    if not textures or len(set(textures))!=len(textures) or any(t not in REFERENCE_EULER_DEG for t in textures):
        raise ValueError(f'Textures must be unique names from {list(REFERENCE_EULER_DEG)}')
    if not isinstance(samples_per_seed,int) or samples_per_seed<1:
        raise ValueError('samples_per_seed must be a positive integer')
    return [OrientationCase(int(s),float(d),t,i,samples_per_seed>1)
            for s in seeds for d in degrees for t in textures for i in range(1,samples_per_seed+1)]


def find_matlab(explicit=None):
    if explicit:
        located=shutil.which(str(explicit))
        if located:return located
        if Path(explicit).is_file():return str(Path(explicit).resolve())
        raise FileNotFoundError(f'MATLAB executable not found: {explicit}')
    found=shutil.which('matlab')
    if found:return found
    apps=sorted(Path('/Applications').glob('MATLAB*.app/bin/matlab'),reverse=True)
    if apps:return str(apps[0])
    raise FileNotFoundError('MATLAB not found. Supply --matlab with the executable path.')


def matlab_string(value):
    return "'"+str(value).replace("'","''")+"'"


def read_manifest(root):
    path=Path(root)/'generation_manifest.mat'
    if not path.is_file():raise FileNotFoundError(f'MTEX generation record missing: {path}')
    manifest=loadmat(path,simplify_cells=True)
    if manifest.get('schema')!='diamond_mtex_mixed_mirror_v1':raise ValueError('Unexpected MTEX generation schema')
    records=manifest['records']
    if isinstance(records,dict):records=[records]
    records=list(records)
    manifest['records']=records
    return manifest


def validate_generated(cases,root,variant_sampling='balanced'):
    manifest=read_manifest(root)
    lookup={(int(r['seed']),float(r['degree']),str(r['texture']),int(r['sample'])):r for r in manifest['records']}
    for c in cases:
        key=(c.seed,c.degree,c.texture,c.sample)
        if key not in lookup:raise ValueError(f'Missing MTEX generation record: {key}')
        r=lookup[key]
        if str(r['variant_sampling'])!=variant_sampling:raise ValueError(f'Wrong mirror mode: {key}')
        variants=np.asarray(r['variant_ids'],int).reshape(-1)
        if variants.shape!=(5,) or not np.isin(variants,[1,2,3,4]).all():raise ValueError(f'Invalid mirror variants: {key}')
        if variant_sampling=='balanced' and set(variants)!={1,2,3,4}:raise ValueError(f'Incomplete mirror mixture: {key}')
        e=np.loadtxt(c.csv_path(root),delimiter=',',ndmin=2)
        if e.shape!=(5,3) or not np.isfinite(e).all():raise ValueError(f'Invalid MTEX CSV: {key}')
        if not np.allclose(e,r['euler_rad'],atol=1e-12,rtol=0):raise ValueError(f'CSV differs from MTEX record: {key}')
        if not np.allclose(r['reference_offset_deg'],c.degree,atol=1e-6,rtol=0):raise ValueError(f'Wrong reference offset: {key}')
    return manifest


def generate_with_mtex(cases,root,overwrite=False,variant_sampling='balanced',matlab=None,mtex_dir=None):
    cases=list(cases);root=Path(root).resolve()
    if not cases:raise ValueError('No cases')
    if variant_sampling not in ('balanced','independent'):raise ValueError('Unknown mirror sampling mode')
    existing=[c.csv_path(root) for c in cases if c.csv_path(root).exists()]
    if existing and not overwrite:raise FileExistsError(f'Orientation CSVs exist; use --overwrite. First: {existing[0]}')
    seeds=list(dict.fromkeys(c.seed for c in cases));degrees=list(dict.fromkeys(c.degree for c in cases));textures=list(dict.fromkeys(c.texture for c in cases));samples=max(c.sample for c in cases)
    if len(cases)!=len(seeds)*len(degrees)*len(textures)*samples:raise ValueError('MTEX batch must be a full selected Cartesian product')
    mtex_dir=Path(mtex_dir or MTEX_DIR).resolve()
    if not mtex_dir.is_dir():raise FileNotFoundError(f'MTEX folder missing: {mtex_dir}')
    script_dir=ROOT/'tools/preprocess'
    vec=lambda values:'['+' '.join(format(v,'.15g') for v in values)+']'
    command='addpath('+matlab_string(script_dir)+');generate_orientation_diamond('+','.join([
        "'Seeds'",vec(seeds),"'Degrees'",vec(degrees),"'Textures'",'{'+','.join(matlab_string(t) for t in textures)+'}',
        "'SamplesPerSeed'",str(samples),"'VariantSampling'",matlab_string(variant_sampling),
        "'OutputDir'",matlab_string(root),"'MTEXDir'",matlab_string(mtex_dir),"'Overwrite'",str(bool(overwrite)).lower()])+');'
    executable=find_matlab(matlab)
    flags=['-nojvm'] if sys.platform=='darwin' else []
    result=subprocess.run([executable,*flags,'-batch',command,'-sd',str(ROOT)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
    if result.returncode:
        raise RuntimeError(f'MATLAB/MTEX generation failed ({result.returncode}):\n{result.stdout[-10000:]}')
    manifest=validate_generated(cases,root,variant_sampling)
    print(f'MTEX generated and validated {len(cases)} CSVs; record: {root / "generation_manifest.mat"}')
    return manifest
