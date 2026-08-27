from __future__ import annotations

import argparse
import sys
from pathlib import Path

# Allow the documented ``python tools/...`` invocation without an editable install.
PIPELINE_DIR = Path(__file__).resolve().parents[2]
if str(PIPELINE_DIR) not in sys.path:
    sys.path.insert(0, str(PIPELINE_DIR))

from src.mapping.orientation_metric_plot import plot_orientation_metric_layers

# ============================================================
# Case settings
# Change these values when running this file with VS Code's Run button.
# ============================================================
RHO = 1
SEED = 2
METRICS = ("ipf", "rotation", "gos")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Plot MTEX grain metrics on the upper spatial-model surface."
    )
    parser.add_argument(
        "metrics_csv",
        type=Path,
        nargs="?",
        help="One metrics CSV. If omitted, all CSVs for RHO/SEED are plotted.",
    )
    parser.add_argument("--rho", type=float, default=RHO)
    parser.add_argument("--seed", type=int, default=SEED)
    parser.add_argument("--spatial-model-dir", type=Path)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument(
        "--metric",
        choices=METRICS,
        help="Plot one metric. If omitted, IPF, rotation, and GOS are plotted.",
    )
    parser.add_argument(
        "--all-layers",
        action="store_true",
        help="Plot every z layer instead of only the upper surface.",
    )
    parser.add_argument("--dpi", type=int, default=200)
    parser.add_argument("--overwrite", action="store_true")
    return parser.parse_args()


def rho_dir_name(rho: float) -> str:
    return f"rho_{rho:g}"


def default_directories(rho: float, seed: int) -> tuple[Path, Path, Path]:
    rho_name = rho_dir_name(rho)
    angle_dir = (
        PIPELINE_DIR / "outputs" / rho_name / f"{rho_name}_seed{seed}" / "angles"
    )
    metrics_root = angle_dir / "grain_orientation_metrics"
    plots_root = angle_dir / "grain_orientation_plots"
    spatial_model_dir = PIPELINE_DIR / "database" / "spatial_model" / f"seed{seed}"
    return metrics_root, plots_root, spatial_model_dir


def find_metric_csvs(metrics_root: Path) -> list[Path]:
    if not metrics_root.is_dir():
        raise FileNotFoundError(f"Grain-metrics directory not found: {metrics_root}")
    csv_paths = sorted(metrics_root.glob("*/grain_metrics_*.csv"))
    if not csv_paths:
        raise FileNotFoundError(f"No grain-metrics CSV files found in: {metrics_root}")
    return csv_paths


def main() -> None:
    args = parse_args()
    metrics_root, default_plots_root, default_spatial_dir = default_directories(
        args.rho, args.seed
    )
    spatial_model_dir = args.spatial_model_dir or default_spatial_dir
    required_spatial_files = (
        spatial_model_dir / "nodes.csv",
        spatial_model_dir / "elements.csv",
    )
    missing_spatial_files = [
        path for path in required_spatial_files if not path.is_file()
    ]
    if missing_spatial_files:
        details = "\n".join(f"  {path}" for path in missing_spatial_files)
        raise FileNotFoundError(
            "Spatial model is incomplete. Run export_spatial_model.py for "
            f"seed {args.seed} first. Missing:\n{details}"
        )
    metrics_csvs = (
        [args.metrics_csv] if args.metrics_csv else find_metric_csvs(metrics_root)
    )
    selected_metrics = (args.metric,) if args.metric else METRICS

    saved_count = 0
    skipped_count = 0
    for metrics_csv in metrics_csvs:
        if not metrics_csv.is_file():
            raise FileNotFoundError(f"Grain-metrics CSV not found: {metrics_csv}")

        if args.output_dir:
            # A single CSV can write directly to the requested directory. In
            # batch mode, retain case/state subdirectories to prevent clashes.
            if args.metrics_csv:
                csv_output_dir = args.output_dir
            else:
                csv_output_dir = (
                    args.output_dir / metrics_csv.parent.name / metrics_csv.stem
                )
        else:
            csv_output_dir = (
                default_plots_root / metrics_csv.parent.name / metrics_csv.stem
            )

        for metric in selected_metrics:
            try:
                paths = plot_orientation_metric_layers(
                    spatial_model_dir,
                    metrics_csv,
                    csv_output_dir,
                    metric=metric,
                    all_layers=args.all_layers,
                    dpi=args.dpi,
                    overwrite=args.overwrite,
                )
            except FileExistsError as error:
                skipped_count += 1
                print(f"[skip existing] {metrics_csv.name} / {metric}: {error}")
                continue

            saved_count += len(paths)
            for path in paths:
                print(f"[saved] {path}")

    print(
        f"Completed: rho={args.rho:g}, seed={args.seed}, "
        f"saved={saved_count}, skipped={skipped_count}"
    )


if __name__ == "__main__":
    main()
