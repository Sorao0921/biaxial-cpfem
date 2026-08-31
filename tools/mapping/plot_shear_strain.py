from __future__ import annotations

import argparse
import sys
from pathlib import Path

PIPELINE_DIR = Path(__file__).resolve().parents[2]
if str(PIPELINE_DIR) not in sys.path:
    sys.path.insert(0, str(PIPELINE_DIR))

from src.config.pipeline_paths import build_mapping_directories, build_post_directories
from src.mapping.shear_strain_plot import METRICS, plot_shear_strain_layers

RHO = 1
SEED = 2


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Plot accumulated-shear-strain metrics on the spatial model."
    )
    parser.add_argument("shear_strain_csv", type=Path, nargs="?")
    parser.add_argument("--rho", type=float, default=RHO)
    parser.add_argument("--seed", type=int, default=SEED)
    parser.add_argument("--spatial-model-dir", type=Path)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--metric", choices=METRICS)
    parser.add_argument(
        "--aggregation",
        choices=("element", "grain", "both"),
        default="both",
        help="Plot element values, grain-aggregated values, or both (default).",
    )
    parser.add_argument(
        "--activity-threshold",
        type=float,
        default=0.0,
        help="Mask alpha and all strain metrics at or below this total strain.",
    )
    parser.add_argument("--all-layers", action="store_true")
    parser.add_argument("--dpi", type=int, default=200)
    parser.add_argument("--overwrite", action="store_true")
    return parser.parse_args()


def default_directories(rho: float, seed: int) -> tuple[Path, Path, Path]:
    post_paths = build_post_directories(rho, seed)
    mapping_paths = build_mapping_directories(seed)
    return (
        post_paths.id_set_shear_strain_dir,
        post_paths.shear_strain_contours_dir,
        mapping_paths.spatial_model_dir,
    )


def main() -> None:
    args = parse_args()
    input_root, output_root, default_spatial = default_directories(args.rho, args.seed)
    spatial_dir = args.spatial_model_dir or default_spatial
    csvs = (
        [args.shear_strain_csv]
        if args.shear_strain_csv
        else sorted(input_root.glob("*/*.csv"))
    )
    if not csvs:
        raise FileNotFoundError(f"No shear-strain CSV files found in: {input_root}")
    selected_metrics = (args.metric,) if args.metric else METRICS
    aggregations = (
        ("element", "grain") if args.aggregation == "both" else (args.aggregation,)
    )

    saved = skipped = 0
    for csv_path in csvs:
        if not csv_path.is_file():
            raise FileNotFoundError(f"Shear-strain CSV not found: {csv_path}")
        if args.output_dir and args.shear_strain_csv:
            csv_output = args.output_dir
        else:
            base = args.output_dir or output_root
            csv_output = base / csv_path.parent.name / csv_path.stem
        for metric in selected_metrics:
            for aggregation in aggregations:
                try:
                    paths = plot_shear_strain_layers(
                        spatial_dir,
                        csv_path,
                        csv_output,
                        metric=metric,
                        aggregation=aggregation,
                        activity_threshold=args.activity_threshold,
                        all_layers=args.all_layers,
                        dpi=args.dpi,
                        overwrite=args.overwrite,
                    )
                except FileExistsError as error:
                    skipped += 1
                    print(
                        f"[skip existing] {csv_path.name} / {metric} / "
                        f"{aggregation}: {error}"
                    )
                    continue
                saved += len(paths)
                for path in paths:
                    print(f"[saved] {path}")
    print(
        f"Completed: rho={args.rho:g}, seed={args.seed}, saved={saved}, skipped={skipped}"
    )


if __name__ == "__main__":
    main()
