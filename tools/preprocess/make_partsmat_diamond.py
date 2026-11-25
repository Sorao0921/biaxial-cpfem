"""Write five-grain diamond cards through the existing macro material writer."""
from __future__ import annotations

import argparse
from pathlib import Path
import sys
from tempfile import TemporaryDirectory

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.preprocess.make_partsmat import make_partsmat
from src.config.diamond_cases import SEEDS, DEGREES, ORIENTATION_DIR, PARTSMAT_DIR
from src.make_model_process.keyword_output import check_output, write_output

# Same seed/deg convention as merge_all_diamond.py. Euler CSV values are radians.
CSV_GLOB = "*.csv"
OVERWRITE_EXISTING = False


def validate_orientation(path: Path) -> None:
    """Rows 1..5 map to center, upper right, upper left, lower left, lower right."""
    try:
        orientation = np.loadtxt(path, delimiter=",", ndmin=2)
    except ValueError as exc:
        raise ValueError(f"Invalid orientation CSV: {path}: {exc}") from exc
    if orientation.shape != (5, 3) or not np.isfinite(orientation).all():
        raise ValueError(
            f"Expected five finite Bunge Euler triples (5 rows x 3 columns, radians): {path}"
        )


def render_diamond_partsmat(ori_csv: Path) -> bytes:
    """Use the unchanged macro writer to render the complete expected card."""
    validate_orientation(ori_csv)
    with TemporaryDirectory(prefix='diamond_material_') as temp:
        output=Path(temp)/'partsmat.k'
        make_partsmat(ori_csv=ori_csv,out_partsmat_k=output)
        return output.read_bytes()


def make_diamond_partsmat(ori_csv: Path, out_partsmat_k: Path,
                          overwrite: bool=False, reuse_existing: bool=False) -> Path:
    if Path(ori_csv).resolve()==Path(out_partsmat_k).resolve():
        raise ValueError('Material output must not replace its orientation CSV')
    payload=render_diamond_partsmat(ori_csv)
    write_output(out_partsmat_k,payload,overwrite,reuse_existing)
    return Path(out_partsmat_k)


def generate_materials(pairs,overwrite=False,reuse_existing=False):
    # Render and check the whole batch before publishing any file.
    prepared=[(source,output,render_diamond_partsmat(source)) for source,output in pairs]
    for _,output,payload in prepared:check_output(output,payload,overwrite,reuse_existing)
    written=reused=0
    for _,output,payload in prepared:
        if write_output(output,payload,overwrite,reuse_existing):written+=1
        else:reused+=1
    print(f'Diamond materials: {written} written, {reused} verified and reused')
    return written,reused


def plan_outputs(seeds, degrees, orientation_dir: Path,
                 partsmat_dir: Path) -> list[tuple[Path, Path]]:
    pairs = []
    missing = []
    for seed in seeds:
        for degree in degrees:
            relative = Path(f"seed_{seed}") / f"deg_{degree:g}"
            csv_files = sorted(path for path in (orientation_dir / relative).glob(CSV_GLOB)
                               if path.is_file())
            if not csv_files:
                missing.append(str(orientation_dir / relative / CSV_GLOB))
            pairs.extend((csv_path, partsmat_dir / relative / f"partsmat_{csv_path.stem}.k")
                         for csv_path in csv_files)
    if missing:
        raise FileNotFoundError("No orientation CSV files found:\n" + "\n".join(missing))
    return pairs


def main(argv=None) -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seeds", "--seed", type=int, nargs="+", default=SEEDS)
    parser.add_argument("--degs", "--degrees", "--angles", type=float, nargs="+", default=DEGREES)
    parser.add_argument("--orientation-dir", type=Path, default=ORIENTATION_DIR)
    parser.add_argument("--partsmat-dir", type=Path, default=PARTSMAT_DIR)
    parser.add_argument("--overwrite", action="store_true", default=OVERWRITE_EXISTING)
    parser.add_argument("--reuse-existing",action="store_true",help="Reuse only byte-identical existing cards")
    args = parser.parse_args(argv)
    if len(set(args.seeds)) != len(args.seeds) or min(args.seeds) < 0:
        parser.error("Seeds must be unique nonnegative integers")
    if len(set(args.degs)) != len(args.degs) or any(not 0 <= deg < float("inf") for deg in args.degs):
        parser.error("Degrees must be unique nonnegative finite numbers")
    pairs = plan_outputs(args.seeds, args.degs, args.orientation_dir, args.partsmat_dir)
    generate_materials(pairs,args.overwrite,args.reuse_existing)


if __name__ == "__main__":
    main()
