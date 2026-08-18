from __future__ import annotations

import argparse
from pathlib import Path

from src.config.pipeline_paths import ROOT, build_pre_directories
from src.pre_process.spatial_model import export_spatial_model_from_keyword


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Export node, element and part positions to solver-independent CSV files."
    )
    parser.add_argument("--seed", type=int, default=1, help="Partset seed (default: 1).")
    parser.add_argument(
        "--input",
        type=Path,
        help="Input keyword containing *NODE and *ELEMENT. Defaults to partset_seedN.k.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        help="Output directory. Defaults to database/spatial_model/seedN.",
    )
    parser.add_argument("--overwrite", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    input_path = args.input or build_pre_directories(seed=args.seed).partset
    output_dir = args.output_dir or ROOT / "database" / "spatial_model" / f"seed{args.seed}"
    result = export_spatial_model_from_keyword(
        input_path, output_dir, overwrite=args.overwrite
    )
    print("Spatial-model export completed.")
    print(f"  input  : {input_path}")
    print(f"  output : {result}")


if __name__ == "__main__":
    main()
