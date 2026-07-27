import re
from pathlib import Path

import pandas as pd
from src.config.pipeline_paths import PostDirectories, build_post_directories
from src.extract_process.drop_edge import EdgeDropper
from src.extract_process.extract_lines import LineExtractor
from src.extract_process.roughness import SurfaceRoughnessAnalyzer

# ============================================================
# Case settings
# Change RHO and SEED to select another post-processing directory.
# ============================================================
RHO = 1
SEED = 1


# ===========================================================
# Do not change below this line unless you have to.
# ===========================================================
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


def parse_case_dir_name(case_name: str) -> tuple[str, int, int]:
    match = re.fullmatch(
        r"(.+?)_sd_?(\d+)_seed(\d+)",
        case_name,
        flags=re.IGNORECASE,
    )
    if not match:
        raise ValueError(f"Unexpected case directory name: {case_name}")

    texture, sd, seed = match.groups()
    return texture.lower(), int(sd), int(seed)


def make_edge_dropped_path(
    csv_path: Path, case_dir: Path, paths: PostDirectories
) -> Path:
    return paths.edge_dropped_dir / case_dir.name / csv_path.name


def make_case_roughness_path(case_name: str, paths: PostDirectories) -> Path:
    texture, sd, seed = parse_case_dir_name(case_name)
    return paths.roughness_dir / f"roughness_{texture}_sd{sd}_seed{seed}.csv"


def expected_line_output_paths(
    csv_path: Path, case_name: str, paths: PostDirectories
) -> list[Path]:
    extractor = LineExtractor()
    return [
        paths.lines_dir
        / case_name
        / line_label
        / extractor.make_line_output_name(csv_path, line_label)
        for line_label in ("L1", "L2", "L3")
    ]


def main() -> None:
    paths = build_post_directories(rho=RHO, seed=SEED)
    dropper = EdgeDropper(grid_size=151, keep_size=113)
    analyzer = SurfaceRoughnessAnalyzer()
    line_extractor = LineExtractor()

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

        case_result_path = make_case_roughness_path(case_name, paths)
        skip_roughness = valid_file_exists(case_result_path)

        if skip_roughness:
            print(
                "  roughness result already exists, "
                f"skip roughness calculation: {case_result_path}"
            )
            case_results = None
        else:
            case_results = []

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

            # ----------------------------------------------------------
            # Line extraction
            # ----------------------------------------------------------
            line_output_paths = expected_line_output_paths(
                csv_path=csv_path, case_name=case_name, paths=paths
            )

            if all(valid_file_exists(path) for path in line_output_paths):
                print(
                    "    all line-profile CSVs already exist, "
                    f"skip line extraction: {csv_path.name}"
                )
            else:
                line_extractor.extract_lines_from_csv(
                    csv_path=edge_dropped_path,
                    output_root_dir=paths.lines_dir / case_name,
                )

            # ----------------------------------------------------------
            # Roughness calculation
            # ----------------------------------------------------------
            if skip_roughness:
                continue

            if not valid_file_exists(edge_dropped_path):
                print(
                    "    edge-dropped CSV was not generated correctly, "
                    f"skip roughness calculation: {edge_dropped_path}"
                )
                continue

            df_dropped = pd.read_csv(edge_dropped_path)
            roughness_result = analyzer.analyze_df(df_dropped)

            result_row = {
                "case": case_name,
                "file": csv_path.name,
                "num_nodes": roughness_result["num_nodes"],
                "a": roughness_result["a"],
                "b": roughness_result["b"],
                "c": roughness_result["c"],
                "sa": roughness_result["sa"],
                "sq": roughness_result["sq"],
                "sz": roughness_result["sz"],
            }

            case_results.append(result_row)

            print(f"    Sa = {roughness_result['sa']}")
            print(f"    Sq = {roughness_result['sq']}")
            print(f"    Sz = {roughness_result['sz']}")

        if case_results:
            paths.roughness_dir.mkdir(parents=True, exist_ok=True)

            case_result_df = pd.DataFrame(case_results)
            case_result_df.to_csv(case_result_path, index=False)

            print(f"  saved case result: {case_result_path}")
        elif not skip_roughness:
            print(f"  no roughness results generated for case: {case_name}")


if __name__ == "__main__":
    main()
