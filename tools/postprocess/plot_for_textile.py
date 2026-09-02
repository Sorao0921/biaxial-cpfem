from __future__ import annotations

import re
from collections import defaultdict
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from src.config.pipeline_paths import build_post_directories

# ============================================================
# Settings
# ============================================================
RHO = 1
SEED = 2
# change the value of rho and seed for different post-processing directories

POST_PATHS = build_post_directories(RHO, SEED)
EPS_EQ_CSV = POST_PATHS.equivalent_strain_csv
ROUGHNESS_DIR = POST_PATHS.roughness_dir
LINES_DIR = POST_PATHS.lines_dir
OUTPUT_DIR = POST_PATHS.coords_figures_dir

ORIENTATIONS = ["cube", "goss", "brass", "copper", "s"]
METRICS = ["sa", "sq", "sz"]

HEIGHT_SCALE = 1000.0  # mm -> μm
LINE_YLIM = (-2.0, 2.0)


# ============================================================
# Small helpers
# ============================================================


def natural_sort_key(value: str | Path) -> list[object]:
    text = value.name if isinstance(value, Path) else str(value)
    return [
        int(part) if part.isdigit() else part.lower()
        for part in re.split(r"(\d+)", text)
    ]


def valid_file_exists(path: Path) -> bool:
    return path.is_file() and path.stat().st_size > 0


def get_sd(path: Path) -> float:
    match = re.search(
        r"sd([0-9]+(?:\.[0-9]+)?)",
        path.as_posix(),
        flags=re.IGNORECASE,
    )
    if match is None:
        raise ValueError(f"sd was not found in: {path}")

    return float(match.group(1))


def has_orientation(path: Path, orientation: str) -> bool:
    """
    Match texture/orientation name from path.

    This prevents orientation "s" from matching words such as
    "post" or "roughness".
    """
    text = path.as_posix().lower()
    name = re.escape(orientation.lower())
    pattern = rf"(^|[/_\-])(?:[0-9]+)?{name}(?=(_sd|[/_\-]|$))"

    return re.search(pattern, text) is not None


def read_eps_eq() -> pd.Series:
    df = pd.read_csv(EPS_EQ_CSV)

    lower_to_original = {str(column).strip().lower(): column for column in df.columns}

    original = lower_to_original.get("eps_eq")

    if original is None:
        raise KeyError(
            f"Column 'eps_eq' was not found in {EPS_EQ_CSV}. "
            f"Available columns: {list(df.columns)}"
        )

    return pd.to_numeric(df[original], errors="coerce").dropna().reset_index(drop=True)


def read_metric(csv_path: Path, metric: str) -> pd.Series | None:
    df = pd.read_csv(csv_path)

    lower_to_original = {str(column).strip().lower(): column for column in df.columns}

    original = lower_to_original.get(metric.lower())

    if original is None:
        return None

    return pd.to_numeric(df[original], errors="coerce").dropna().reset_index(drop=True)


def read_profile(csv_path: Path) -> tuple[np.ndarray, np.ndarray]:
    """
    Read x and z coordinates from a line-profile CSV.

    Supported examples:
        x, z
        x, y, z
        node_id, x, y, z
        X Coordinate, Y Coordinate, Z Coordinate
    """
    df = pd.read_csv(csv_path)

    normalized_columns = {str(column).strip().lower(): column for column in df.columns}

    if "x" in normalized_columns and "z" in normalized_columns:
        x = pd.to_numeric(
            df[normalized_columns["x"]],
            errors="coerce",
        )
        z = pd.to_numeric(
            df[normalized_columns["z"]],
            errors="coerce",
        )

    elif "x coordinate" in normalized_columns and "z coordinate" in normalized_columns:
        x = pd.to_numeric(
            df[normalized_columns["x coordinate"]],
            errors="coerce",
        )
        z = pd.to_numeric(
            df[normalized_columns["z coordinate"]],
            errors="coerce",
        )

    elif df.shape[1] >= 4:
        # Expected order: node_id, x, y, z
        x = pd.to_numeric(df.iloc[:, 1], errors="coerce")
        z = pd.to_numeric(df.iloc[:, 3], errors="coerce")

    elif df.shape[1] >= 3:
        # Expected order: x, y, z
        x = pd.to_numeric(df.iloc[:, 0], errors="coerce")
        z = pd.to_numeric(df.iloc[:, 2], errors="coerce")

    else:
        raise ValueError(
            f"Could not read a line profile from {csv_path}. "
            "Expected x,z; x,y,z; or node_id,x,y,z columns."
        )

    valid = x.notna() & z.notna()

    x_values = x[valid].to_numpy(dtype=float)
    z_values = z[valid].to_numpy(dtype=float)

    if len(x_values) == 0:
        raise ValueError(f"No valid x-z coordinate pairs were found in {csv_path}")

    return x_values, z_values


# ============================================================
# Roughness data collection
# ============================================================


def collect_metric_data(
    csvs: list[Path],
    eps_eq: pd.Series,
    orientation: str,
    metric: str,
) -> pd.DataFrame:
    rows: list[pd.DataFrame] = []

    for csv_path in csvs:
        if not has_orientation(csv_path, orientation):
            continue

        values = read_metric(csv_path, metric)

        if values is None:
            continue

        n = min(len(eps_eq), len(values))

        if n == 0:
            continue

        rows.append(
            pd.DataFrame(
                {
                    "eps_eq": eps_eq.iloc[:n].reset_index(drop=True),
                    "sd": get_sd(csv_path),
                    metric: values.iloc[:n].reset_index(drop=True),
                }
            )
        )

    if not rows:
        return pd.DataFrame()

    return pd.concat(rows, ignore_index=True)


# ============================================================
# Roughness plot
# ============================================================


def plot_metric(
    df: pd.DataFrame,
    orientation: str,
    metric: str,
) -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    output_png = OUTPUT_DIR / f"rho_{RHO}_seed_{SEED}_{orientation}_{metric}.png"

    if valid_file_exists(output_png):
        print(f"Skipped existing figure: {output_png}")
        return

    fig, ax = plt.subplots(figsize=(8, 6))

    for sd, group in sorted(
        df.groupby("sd"),
        key=lambda item: item[0],
    ):
        group = group.sort_values("eps_eq")

        ax.plot(
            group["eps_eq"],
            group[metric] * 1000.0,
            marker="o",
            markersize=3,
            linewidth=1.5,
            label=f"sd={sd:g}",
        )

    ax.set_xlabel("")
    ax.set_ylabel("")
    ax.text(0.02, 0.98, "[$\mu$m]", transform=ax.transAxes, ha="left", va="top")
    ax.text(0.98, 0.02, "[-]", transform=ax.transAxes, ha="right", va="bottom")
    ax.grid(True, alpha=0.3)
    ax.legend(title="sd", loc="best")

    fig.tight_layout()
    fig.savefig(
        output_png,
        dpi=300,
        bbox_inches="tight",
    )
    plt.close(fig)

    print(f"Saved: {output_png}")


# ============================================================
# Line-profile discovery
# ============================================================


def line_identifier(csv_path: Path) -> str:
    """
    Convert filenames such as the following into L1, L2, or L3:

        L1.csv
        line1.csv
        line_1.csv
        profile_L1.csv
    """
    stem = csv_path.stem

    match = re.search(
        r"(?:^|[_\-])(l(?:ine)?[_\-]?[123])(?:$|[_\-])",
        stem,
        flags=re.IGNORECASE,
    )

    if match:
        token = (
            match.group(1)
            .lower()
            .replace("line", "l")
            .replace("_", "")
            .replace("-", "")
        )
        return token.upper()

    match = re.search(
        r"(?:line|l)[_\-]?([123])",
        stem,
        flags=re.IGNORECASE,
    )

    if match:
        return f"L{match.group(1)}"

    return stem


def collect_current_layout_profiles(
    case_dir: Path,
) -> dict[str, list[Path]]:
    """
    Current directory layout:

        coords/lines/{case}/{state}/{line}.csv
    """
    grouped: dict[str, list[Path]] = defaultdict(list)

    state_dirs = sorted(
        (path for path in case_dir.iterdir() if path.is_dir()),
        key=natural_sort_key,
    )

    for state_dir in state_dirs:
        csv_paths = sorted(
            state_dir.glob("*.csv"),
            key=natural_sort_key,
        )

        for csv_path in csv_paths:
            grouped[line_identifier(csv_path)].append(csv_path)

    return dict(grouped)


def collect_legacy_layout_profiles(
    case_dir: Path,
) -> dict[str, list[Path]]:
    """
    Legacy GitHub directory layout:

        coords/lines/{case}/{line}/{state}.csv
    """
    grouped: dict[str, list[Path]] = {}

    line_dirs = sorted(
        (path for path in case_dir.iterdir() if path.is_dir()),
        key=natural_sort_key,
    )

    for line_dir in line_dirs:
        csv_paths = sorted(
            line_dir.glob("*.csv"),
            key=natural_sort_key,
        )

        if csv_paths:
            grouped[line_identifier(line_dir)] = csv_paths

    return grouped


def discover_line_profiles(
    case_dir: Path,
) -> dict[str, list[Path]]:
    """
    Detect and support both the current and legacy layouts.
    """
    child_dirs = [path for path in case_dir.iterdir() if path.is_dir()]

    if not child_dirs:
        return {}

    looks_legacy = any(
        re.fullmatch(
            r"(?:l|line)[_\-]?[123]",
            path.name,
            flags=re.IGNORECASE,
        )
        for path in child_dirs
    )

    if looks_legacy:
        return collect_legacy_layout_profiles(case_dir)

    return collect_current_layout_profiles(case_dir)


# ============================================================
# Line-profile plot
# ============================================================


def plot_profile_progress(
    profile_paths: list[Path],
    eps_eq: pd.Series,
    output_path: Path,
) -> None:
    if valid_file_exists(output_path):
        print(f"Skipped existing figure: {output_path}")
        return

    n = min(len(profile_paths), len(eps_eq))

    if n == 0:
        print(f"Skipped empty profile group: {output_path}")
        return

    if len(profile_paths) != len(eps_eq):
        print(
            "Warning: profile/eps_eq length mismatch; "
            f"using the first {n} entries for {output_path.name} "
            f"(profiles={len(profile_paths)}, eps_eq={len(eps_eq)})"
        )

    fig, ax = plt.subplots(figsize=(8, 6))

    plotted_count = 0

    for index, csv_path in enumerate(profile_paths[:n]):
        try:
            x, z = read_profile(csv_path)
        except (OSError, ValueError, pd.errors.ParserError) as error:
            print(f"Warning: skipped invalid profile: {csv_path}")
            print(f"         {error}")
            continue

        x_min = np.min(x)
        x_max = np.max(x)

        if np.isclose(x_max, x_min):
            print(f"Warning: zero x-range, skipped profile: {csv_path}")
            continue

        x_normalized = (x - x_min) / (x_max - x_min)

        # Remove the mean height of each line and convert mm to μm.
        height = (z - np.mean(z)) * HEIGHT_SCALE

        ax.plot(
            x_normalized,
            height,
            linewidth=1.2,
            label=rf"$\varepsilon_{{eq}}={eps_eq.iloc[index]:.3f}$",
        )

        plotted_count += 1

    if plotted_count == 0:
        plt.close(fig)
        print(f"Skipped: no valid line data for {output_path}")
        return

    # ax.set_xlabel(r"Normalized position $x/L$")
    # ax.set_ylabel(r"Height $[\mu\mathrm{m}]$")
    ax.set_ylim(*LINE_YLIM)
    ax.grid(True, alpha=0.3)

    ax.legend(
        loc="center left",
        bbox_to_anchor=(1.02, 0.5),
        borderaxespad=0,
    )

    fig.tight_layout()

    output_path.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    fig.savefig(
        output_path,
        dpi=300,
        bbox_inches="tight",
    )
    plt.close(fig)

    print(f"Saved: {output_path}")


def plot_all_line_profiles(
    eps_eq: pd.Series,
) -> None:
    if not LINES_DIR.is_dir():
        print(f"Line directory does not exist, skipped: {LINES_DIR}")
        return

    case_dirs = sorted(
        (path for path in LINES_DIR.iterdir() if path.is_dir()),
        key=natural_sort_key,
    )

    for case_dir in case_dirs:
        grouped_profiles = discover_line_profiles(case_dir)

        if not grouped_profiles:
            print(f"No line profiles found, skipped: {case_dir}")
            continue

        case_output_dir = OUTPUT_DIR / "lines" / case_dir.name

        for line_name, profile_paths in sorted(
            grouped_profiles.items(),
            key=lambda item: natural_sort_key(item[0]),
        ):
            profile_paths = sorted(
                profile_paths,
                key=natural_sort_key,
            )

            safe_line_name = re.sub(
                r"[^A-Za-z0-9_.-]+",
                "_",
                line_name,
            )

            output_png = (
                case_output_dir / f"{case_dir.name}_{safe_line_name}_profile.png"
            )

            plot_profile_progress(
                profile_paths=profile_paths,
                eps_eq=eps_eq,
                output_path=output_png,
            )


# ============================================================
# Main
# ============================================================


def main() -> None:
    eps_eq = read_eps_eq()
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    if ROUGHNESS_DIR.is_dir():
        roughness_csvs = sorted(
            ROUGHNESS_DIR.rglob("*.csv"),
            key=natural_sort_key,
        )

        for orientation in ORIENTATIONS:
            for metric in METRICS:
                df = collect_metric_data(
                    csvs=roughness_csvs,
                    eps_eq=eps_eq,
                    orientation=orientation,
                    metric=metric,
                )

                if df.empty:
                    print(f"Skipped: {orientation} / {metric}")
                    continue

                plot_metric(
                    df=df,
                    orientation=orientation,
                    metric=metric,
                )

    else:
        print(f"Roughness directory does not exist, skipped: {ROUGHNESS_DIR}")

    plot_all_line_profiles(eps_eq)


if __name__ == "__main__":
    main()
