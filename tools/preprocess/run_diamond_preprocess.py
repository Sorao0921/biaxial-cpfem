"""Run orientation CSV -> existing material writer -> supplied-keyword merge."""
from pathlib import Path
from collections import defaultdict
import argparse
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT))
from src.config.diamond_cases import SEEDS,DEGREES,TEXTURES,SAMPLES_PER_SEED,VARIANT_SAMPLING,ORIENTATION_DIR,PARTSMAT_DIR,KEYWORDS_DIR,OUTPUT_DIR
from src.make_model_process.diamond_orientation import plan_cases,generate_with_mtex,validate_generated
from tools.preprocess.make_partsmat_diamond import generate_materials,validate_orientation
from tools.preprocess import merge_all_diamond as merge


def run_pipeline(cases,rhos,orientation_dir,partsmat_dir,keywords_dir,output_dir,
                 steps=('orientations','materials','merge'),overwrite=False,
                 variant_sampling=VARIANT_SAMPLING,matlab=None,mtex_dir=None,
                 reuse_existing=False,prepare_keywords=True):
    cases=list(cases);steps=set(steps);rhos=list(rhos)
    if not steps or not steps<={'orientations','materials','merge'}:
        raise ValueError('Unknown or empty steps')
    if not rhos or len(set(rhos))!=len(rhos) or any(not float('-inf')<r<float('inf') for r in rhos):
        raise ValueError('Rhos must be unique finite numbers')
    if 'merge' in steps and prepare_keywords:
        merge.prepare_inputs(keywords_dir,rhos,overwrite=overwrite)
    by_group=defaultdict(list)
    for c in cases:by_group[c.seed,c.degree].append(c.material_path(partsmat_dir))
    jobs=[merge.build_paths(rho,seed,deg,Path(keywords_dir),Path(partsmat_dir),Path(output_dir))
          for rho in rhos for seed,deg in by_group]
    missing=set();existing=[]
    if 'merge' in steps:
        for job in jobs:
            for name in ['partset','control','section','boundary','curve']:
                p=getattr(job,name)
                if not p.is_file():missing.add(str(p))
        if 'materials' not in steps:
            missing.update(str(c.material_path(partsmat_dir)) for c in cases if not c.material_path(partsmat_dir).is_file())
    if 'materials' in steps and 'orientations' not in steps:
        missing.update(str(c.csv_path(orientation_dir)) for c in cases if not c.csv_path(orientation_dir).is_file())
    if missing:raise FileNotFoundError('Provide the following input files before running these steps:\n'+'\n'.join(sorted(missing)))
    for c in cases:
        for step,path in [('orientations',c.csv_path(orientation_dir)),('materials',c.material_path(partsmat_dir))]:
            if step in steps and path.exists() and not (step=='materials' and reuse_existing):existing.append(path)
    if existing and not overwrite:
        raise FileExistsError(f'{len(existing)} planned CSV/material outputs exist; use --overwrite. First: {existing[0]}')
    if 'materials' in steps and 'orientations' not in steps:
        validate_generated(cases,orientation_dir,variant_sampling)
        for c in cases:validate_orientation(c.csv_path(orientation_dir))
    # All required input/existing-output checks above happen before any write.
    if 'orientations' in steps:
        generate_with_mtex(cases,orientation_dir,overwrite,variant_sampling,matlab,mtex_dir)
    if 'materials' in steps:
        generate_materials([(c.csv_path(orientation_dir),c.material_path(partsmat_dir)) for c in cases],overwrite,reuse_existing)
    written=skipped=0;built=set()
    if 'merge' in steps:
        for job in jobs:
            if job.keywordset not in built:
                merge.build_keywordset(job,overwrite,reuse_existing);built.add(job.keywordset)
            new,old=merge.merge_models(job,by_group[job.seed,job.degree],overwrite,reuse_existing)
            written+=new;skipped+=old
    counts={'orientation_csv':len(cases) if 'orientations' in steps else 0,
            'partsmat':len(cases) if 'materials' in steps else 0,
            'merged':written,'skipped':skipped}
    print('Completed: '+', '.join(f'{k}={v}' for k,v in counts.items()))
    return counts


def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--seeds','--seed',type=int,nargs='+',default=SEEDS)
    p.add_argument('--degs','--degrees','--angles',type=float,nargs='+',default=DEGREES)
    p.add_argument('--textures',nargs='+',default=TEXTURES)
    p.add_argument('--samples-per-seed',type=int,default=SAMPLES_PER_SEED)
    p.add_argument('--variant-sampling',choices=['balanced','independent'],default=VARIANT_SAMPLING)
    p.add_argument('--matlab',type=Path)
    p.add_argument('--mtex-dir',type=Path)
    p.add_argument('--rhos','--rho',type=float,nargs='+',default=merge.RHOS)
    p.add_argument('--orientation-dir',type=Path,default=ORIENTATION_DIR)
    p.add_argument('--partsmat-dir',type=Path,default=PARTSMAT_DIR)
    p.add_argument('--keywords-dir',type=Path,default=KEYWORDS_DIR)
    p.add_argument('--output-dir',type=Path,default=OUTPUT_DIR)
    p.add_argument('--steps',nargs='+',choices=['orientations','materials','merge'],default=['orientations','materials','merge'])
    p.add_argument('--overwrite',action='store_true')
    p.add_argument('--reuse-existing',action='store_true',help='Reuse only byte-identical outputs')
    p.add_argument('--prepare-keywords',action=argparse.BooleanOptionalAction,default=True)
    a=p.parse_args(argv)
    cases=plan_cases(a.seeds,a.degs,a.textures,a.samples_per_seed)
    return run_pipeline(cases,a.rhos,a.orientation_dir,a.partsmat_dir,a.keywords_dir,a.output_dir,a.steps,a.overwrite,a.variant_sampling,a.matlab,a.mtex_dir,a.reuse_existing,a.prepare_keywords)


if __name__=='__main__':main()
