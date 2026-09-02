from __future__ import annotations

import argparse
import sys
from pathlib import Path

PIPELINE_DIR = Path(__file__).resolve().parents[2]
if str(PIPELINE_DIR) not in sys.path:
    sys.path.insert(0, str(PIPELINE_DIR))

from src.mapping.plot_workflow import (
    ORIENTATION_METRICS,
    PLOT_TYPES,
    SHEAR_METRICS,
    plot_all_mapping_results,
)

# VS Code の Run ボタンから実行するときは、ここだけ変更する。
RHO = -0.5
SEED = 2


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create all mapping plots with one command."
    )
    parser.add_argument("--rho", type=float, default=RHO)
    parser.add_argument("--seed", type=int, default=SEED)
    parser.add_argument(
        "--plot",
        choices=PLOT_TYPES,
        action="append",
        dest="plots",
        help="Plot type to create. Repeat to select multiple; default: all.",
    )
    parser.add_argument(
        "--orientation-metric", choices=ORIENTATION_METRICS, action="append"
    )
    parser.add_argument("--shear-metric", choices=SHEAR_METRICS, action="append")
    parser.add_argument(
        "--aggregation", choices=("element", "grain", "both"), default="both"
    )
    parser.add_argument("--activity-threshold", type=float, default=0.0)
    parser.add_argument("--all-layers", action="store_true")
    parser.add_argument("--height-levels", type=int, default=30)
    parser.add_argument("--height-cmap", default="coolwarm")
    parser.add_argument("--height-vmin", type=float, default=0.006)
    parser.add_argument("--height-vmax", type=float, default=0.01)
    parser.add_argument("--dpi", type=int, default=200)
    parser.add_argument("--overwrite", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.height_vmin >= args.height_vmax:
        raise ValueError("--height-vmin must be smaller than --height-vmax")
    summaries = plot_all_mapping_results(
        args.rho,
        args.seed,
        plot_types=tuple(args.plots or PLOT_TYPES),
        orientation_metrics=tuple(args.orientation_metric or ORIENTATION_METRICS),
        shear_metrics=tuple(args.shear_metric or SHEAR_METRICS),
        aggregation=args.aggregation,
        activity_threshold=args.activity_threshold,
        height_levels=args.height_levels,
        height_cmap=args.height_cmap,
        height_value_range=(args.height_vmin, args.height_vmax),
        all_layers=args.all_layers,
        dpi=args.dpi,
        overwrite=args.overwrite,
        on_message=print,
    )
    details = ", ".join(
        f"{name}: saved={summary.saved}, skipped={summary.skipped}"
        for name, summary in summaries.items()
    )
    print(f"Completed: rho={args.rho:g}, seed={args.seed} ({details})")


if __name__ == "__main__":
    main()
