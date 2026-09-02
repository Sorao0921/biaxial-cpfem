from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np

from src.config.pipeline_paths import build_pre_directories
from src.pre_process.keyword_format import write_any_keyword

# ============================================================
# Case settings
# Change SEED to select another post-processing directory.
# ============================================================
SEED = 4


# ===========================================================
# Do not change below this line unless you have to.
# ===========================================================
def make_partsmat(ori_csv: Path, out_partsmat_k: Path) -> Path:
    """Generate partsmat_*.k containing *PART and *MAT cards from an orientation CSV."""

    ori_csv = Path(ori_csv)
    out_partsmat_k = Path(out_partsmat_k)
    out_partsmat_k.parent.mkdir(parents=True, exist_ok=True)

    ori = np.loadtxt(str(ori_csv), delimiter=",")
    num_grains = int(np.shape(ori)[0])

    """ keyword properties:
    row4 p2 is reference strain velocity, p4 is the limit of slip rate
    row5 is the orientation in Bunge Euler angles
    row6 is work hardening parameters
    """
    with open(out_partsmat_k, "w", encoding="utf-8") as w_io:
        for i in range(num_grains):
            pid = i + 1

            # *PART
            write_any_keyword(
                w_io, "*PART", f"part_{pid}", [[pid, 1, pid, 0, 0, 0, 0, 0]]
            )

            # *MAT (orientation)
            phi1 = round(float(ori[i, 0]), 6)
            Phi = round(float(ori[i, 1]), 6)
            phi2 = round(float(ori[i, 2]), 6)

            param = [
                [pid, 0.027, 43, 32, 300, 0, 3, 4],
                [0, 0, 0, 1, 0, 0],
                [69000, 0.3, 58333.33, 26923.1, 0.0, 0.0, 0.0, 0.0],
                [0, 0.3, 0.02, 30, 0, 0, 0, 0],
                [0, phi1, Phi, phi2, 0, 0, 0, 0],
                [0, 42.0, 79.0, 240.0, 0, 1.4, 0, 0],
            ]
            write_any_keyword(
                w_io, "*MAT_USER_DEFINED_MATERIAL_MODELS_TITLE", f"mat_{pid}", param
            )

        w_io.write("*END\n")

    return out_partsmat_k


def write_metadata(
    metadata_path: Path,
    *,
    seed: int,
    orientation_csv_dir: Path,
    partsmat_dir: Path,
    csv_files: list[Path],
    output_files: list[Path],
) -> Path:
    """Save partsmat generation conditions as JSON."""

    metadata = {
        "seed": seed,
        "orientation_csv_dir": str(orientation_csv_dir.resolve()),
        "partsmat_dir": str(partsmat_dir.resolve()),
        "number_of_orientation_csv_files": len(csv_files),
        "number_of_partsmat_files": len(output_files),
        "orientation_csv_files": [path.name for path in csv_files],
        "partsmat_files": [path.name for path in output_files],
    }

    metadata_path.write_text(
        json.dumps(
            metadata,
            indent=2,
            ensure_ascii=False,
        )
        + "\n",
        encoding="utf-8",
    )

    return metadata_path


def parse_args() -> argparse.Namespace:
    """Parse command-line arguments."""

    parser = argparse.ArgumentParser(
        description=("Generate partsmat_*.k files from orientation CSV files.")
    )

    parser.add_argument(
        "--seed",
        type=int,
        default=SEED,
        help=(
            "Seed number used to select the orientation input "
            "and partsmat output directories "
            f"(default: {SEED})."
        ),
    )

    parser.add_argument(
        "--overwrite",
        action="store_true",
        help=("Allow replacement of existing partsmat keyword files."),
    )

    return parser.parse_args()


def main() -> None:
    """
    Generate partsmat keyword files using
    paths defined in pipeline_paths.py.
    """

    args = parse_args()

    pre_dirs = build_pre_directories(
        seed=args.seed,
    )

    if not pre_dirs.orientation_csv_dir.is_dir():
        raise FileNotFoundError(
            f"Orientation CSV directory was not found: {pre_dirs.orientation_csv_dir}"
        )

    csv_files = sorted(pre_dirs.orientation_csv_dir.glob("*.csv"))

    if not csv_files:
        raise FileNotFoundError(
            f"No orientation CSV files were found in: {pre_dirs.orientation_csv_dir}"
        )

    output_pairs = [
        (
            csv_path,
            pre_dirs.partsmat_dir / f"partsmat_{csv_path.stem}.k",
        )
        for csv_path in csv_files
    ]
    output_files = [out_k for _, out_k in output_pairs]
    metadata_path = pre_dirs.partsmat_dir / f"partsmat_seed{args.seed}.json"

    # Check all expected outputs before generating anything.

    existing_outputs = [
        path
        for path in [
            *output_files,
            metadata_path,
        ]
        if path.exists()
    ]

    if existing_outputs and not args.overwrite:
        existing_text = "\n".join(f"  - {path}" for path in existing_outputs)

        raise FileExistsError(
            "Existing partsmat output files were found.\n"
            "Generation was stopped to prevent accidental overwrite.\n"
            f"{existing_text}\n"
            "Use --overwrite only when replacement is intentional."
        )

    pre_dirs.partsmat_dir.mkdir(
        parents=True,
        exist_ok=True,
    )

    for csv_path, out_k in output_pairs:
        make_partsmat(
            ori_csv=csv_path,
            out_partsmat_k=out_k,
        )
        print(f"Generated: {out_k}")

    write_metadata(
        metadata_path=metadata_path,
        seed=args.seed,
        orientation_csv_dir=pre_dirs.orientation_csv_dir,
        partsmat_dir=pre_dirs.partsmat_dir,
        csv_files=csv_files,
        output_files=output_files,
    )

    print(f"Generated metadata: {metadata_path}")
    print("Partsmat generation completed.")
    print(f"  seed      : {args.seed}")
    print(f"  input dir : {pre_dirs.orientation_csv_dir}")
    print(f"  output dir: {pre_dirs.partsmat_dir}")
    print(f"  generated : {len(output_files)}")


if __name__ == "__main__":
    main()
    main()
