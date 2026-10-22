"""Generate edge-dropped surface coordinates only."""

import re
from pathlib import Path

from src.config.pipeline_paths import PostDirectories, build_post_directories
from src.extract_process.drop_edge import EdgeDropper

def natural_sort_key(path: Path) -> list:
    return [
        int(text) if text.isdigit() else text.lower()
        for text in re.split(r"(\d+)", path.name)
    ]


def valid_file_exists(file_path: Path) -> bool:
    """
    Return True when the path is an existing non-empty file.
    """
    return file_path.is_file() and file_path.stat().st_size > 0


def iter_case_dirs(raw_dir: Path):
    if not raw_dir.is_dir():
        return

    yield from sorted(
        (path for path in raw_dir.iterdir() if path.is_dir()),
        key=natural_sort_key,
    )


def iter_csv_files(case_dir: Path):
    yield from sorted(
        case_dir.glob("coordinates_*.csv"),
        key=natural_sort_key,
    )


def make_edge_dropped_path(
    csv_path: Path, case_dir: Path, paths: PostDirectories
) -> Path:
    return paths.edge_dropped_dir / case_dir.name / csv_path.name


def process_coordinates(rho: float, seed: int) -> None:
    paths = build_post_directories(rho=rho, seed=seed)
    dropper = EdgeDropper(grid_size=151, keep_size=113)

    if not paths.raw_coords_dir.is_dir():
        print(f"raw coordinate directory does not exist, skip: {paths.raw_coords_dir}")
        return

    case_dirs = list(iter_case_dirs(paths.raw_coords_dir))

    if not case_dirs:
        print(f"no coordinate case directories found: {paths.raw_coords_dir}")
        return

    for case_dir in case_dirs:
        case_name = case_dir.name
        print(f"processing case: {case_name}")

        csv_files = list(iter_csv_files(case_dir))

        if not csv_files:
            print(f"  no CSV files found, skip case: {case_dir}")
            continue

        for csv_path in csv_files:
            print(f"  processing file: {csv_path.name}")

            # ----------------------------------------------------------
            # Edge-drop processing
            # ----------------------------------------------------------
            edge_dropped_path = make_edge_dropped_path(
                csv_path=csv_path, case_dir=case_dir, paths=paths
            )
            edge_dropped_path.parent.mkdir(parents=True, exist_ok=True)

            if valid_file_exists(edge_dropped_path):
                print(
                    "    edge-dropped CSV already exists, "
                    f"skip edge drop: {edge_dropped_path}"
                )
            else:
                dropper.process_csv(
                    csv_path,
                    output_path=edge_dropped_path,
                )
