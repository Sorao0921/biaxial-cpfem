"""Launch the MATLAB/MTEX five-grain, within-model mirror generator."""
import argparse
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT))
from src.config.diamond_cases import SEEDS,DEGREES,TEXTURES,SAMPLES_PER_SEED,VARIANT_SAMPLING
from src.make_model_process.diamond_orientation import plan_cases,generate_with_mtex

ORIENTATION_DIR=ROOT/'inputs/orientation_diamond'


def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--seeds','--seed',type=int,nargs='+',default=SEEDS)
    p.add_argument('--degs','--degrees','--angles',type=float,nargs='+',default=DEGREES)
    p.add_argument('--textures',nargs='+',default=TEXTURES)
    p.add_argument('--samples-per-seed',type=int,default=SAMPLES_PER_SEED)
    p.add_argument('--variant-sampling',choices=['balanced','independent'],default=VARIANT_SAMPLING)
    p.add_argument('--orientation-dir',type=Path,default=ORIENTATION_DIR)
    p.add_argument('--matlab',type=Path)
    p.add_argument('--mtex-dir',type=Path)
    p.add_argument('--overwrite',action='store_true')
    a=p.parse_args(argv);cases=plan_cases(a.seeds,a.degs,a.textures,a.samples_per_seed)
    return generate_with_mtex(cases,a.orientation_dir,a.overwrite,a.variant_sampling,a.matlab,a.mtex_dir)


if __name__=='__main__':main()
