from __future__ import annotations

import argparse
import sys
from pathlib import Path

# Allow ``python tools/...`` execution without an editable install.
PIPELINE_DIR = Path(__file__).resolve().parents[2]
if str(PIPELINE_DIR) not in sys.path:
    sys.path.insert(0, str(PIPELINE_DIR))

from src.mapping.surface_height_plot import plot_surface_height_contour

# Settings used when running this file with the VS Code Run button.
RHO = 1
SEED = 2


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Plot deformed-surface height contours from coords CSV files."
    )
    parser.add_argument(
        "coordinates_csv",
        type=Path,
        nargs="?",
        help="One x,y,z CSV. If omitted, all coords files for RHO/SEED are plotted.",
    )
    parser.add_argument("--rho", type=float, default=RHO)
    parser.add_argument("--seed", type=int, default=SEED)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--levels", type=int, default=30)
    parser.add_argument("--cmap", default="coolwarm")
    parser.add_argument(
        "--vmin",
        type=float,
        default=0.006,
        help="Lower z threshold shared by every plot (default: 0.006).",
    )
    parser.add_argument(
        "--vmax",
        type=float,
        default=0.01,
        help="Upper z threshold shared by every plot (default: 0.01).",
    )
    parser.add_argument("--dpi", type=int, default=200)
    parser.add_argument("--overwrite", action="store_true")
    return parser.parse_args()


def rho_dir_name(rho: float) -> str:
    return f"rho_{rho:g}"


def default_directories(rho: float, seed: int) -> tuple[Path, Path]:
    rho_name = rho_dir_name(rho)
    coords_dir = (
        PIPELINE_DIR / "outputs" / rho_name / f"{rho_name}_seed{seed}" / "coords"
    )
    return coords_dir / "rawdata", coords_dir / "figures" / "height_contours"


def main() -> None:
    args = parse_args()
    raw_dir, default_output_dir = default_directories(args.rho, args.seed)
    if args.coordinates_csv:
        csv_paths = [args.coordinates_csv]
    else:
        if not raw_dir.is_dir():
            raise FileNotFoundError(f"Raw coordinate directory not found: {raw_dir}")
        csv_paths = sorted(raw_dir.glob("*/coordinates_*.csv"))
        if not csv_paths:
            raise FileNotFoundError(f"No coordinate CSV files found in: {raw_dir}")

    if args.vmin >= args.vmax:
        raise ValueError("--vmin must be smaller than --vmax")
    value_range = (args.vmin, args.vmax)

    output_root = args.output_dir or default_output_dir
    saved = skipped = 0
    for csv_path in csv_paths:
        if not csv_path.is_file():
            raise FileNotFoundError(f"Coordinate CSV not found: {csv_path}")
        case_name = csv_path.parent.name
        output_dir = output_root if args.coordinates_csv else output_root / case_name
        output_path = output_dir / f"height_contour_{csv_path.stem}.png"
        try:
            path = plot_surface_height_contour(
                csv_path,
                output_path,
                levels=args.levels,
                cmap=args.cmap,
                dpi=args.dpi,
                overwrite=args.overwrite,
                value_range=value_range,
            )
        except FileExistsError as error:
            skipped += 1
            print(f"[skip existing] {error}")
            continue
        saved += 1
        print(f"[saved] {path}")
    print(
        f"Completed: rho={args.rho:g}, seed={args.seed}, saved={saved}, skipped={skipped}"
    )


if __name__ == "__main__":
    main()
