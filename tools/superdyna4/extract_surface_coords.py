from __future__ import annotations

import csv
import re
import subprocess
from pathlib import Path

"""
THIS SCRIPT HAVE TO BE RUN ON SUPERDYNA4.
"""


# Helper to get Windows path for LS-PrePost cfile
def to_cfile_path(path: Path) -> str:
    return str(path.resolve())


# This script is intended to be placed directly under the target root folder.
ROOT_DIR = Path(__file__).resolve().parent

LSPREPOST_EXE = Path(r"C:\Program Files\LSTC\LS-PrePost 4.9\lsprepost4.9_x64.exe")

STATE_START = 1
STATE_END = 13

SURFACE_NID_MIN = 91205
SURFACE_NID_MAX = 114005

KEEP_TXT = True


# Auto-detect model directories that contain run/d3plot
CASE_DIRS = sorted(
    [
        path
        for path in ROOT_DIR.iterdir()
        if path.is_dir() and (path / "run" / "d3plot").exists()
    ]
)


def parse_case_name(case_name: str) -> tuple[str, str, str]:
    """
    Parse a model folder name.

    Expected format:
        {texture}_sd{sd}_seed{seed}

    Example:
        cube_sd2_seed1
    """
    match = re.fullmatch(
        r"(?P<texture>.+)_sd(?P<sd>\d+)_seed(?P<seed>\d+)",
        case_name,
    )

    if not match:
        raise ValueError(
            f"cannot parse case name: {case_name}. "
            f"Expected format: <texture>_sd<sd>_seed<seed>. "
            f"Example: cube_sd2_seed1"
        )

    texture = match.group("texture")
    sd = match.group("sd")
    seed = match.group("seed")

    return texture, sd, seed


def make_cfile_text(
    d3plot_path: Path,
    output_txt_path: Path,
    state: int,
) -> str:
    d3plot_str = to_cfile_path(d3plot_path)
    output_txt_str = to_cfile_path(output_txt_path)

    return f'''openc d3plot "{d3plot_str}"
ac
state {state};
output "{output_txt_str}" {state} 1 0 1 0 1 0 0 0 0 0 0 0 0 0 1.000000 0 0
exit
'''


def run_lsprepost(
    cfile_path: Path,
    workdir: Path,
) -> None:
    cmd = [
        str(LSPREPOST_EXE),
        f"c={to_cfile_path(cfile_path)}",
        "-nographics",
    ]

    result = subprocess.run(
        cmd,
        cwd=str(workdir.resolve()),
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        raise RuntimeError(
            f"failed to run LS-PrePost: {to_cfile_path(cfile_path)}\n"
            f"workdir: {to_cfile_path(workdir.resolve())}\n"
            f"STDOUT:\n{result.stdout}\n\n"
            f"STDERR:\n{result.stderr}"
        )


def is_float(value: str) -> bool:
    try:
        float(value)
        return True
    except ValueError:
        return False


def txt_to_surface_csv(
    txt_path: Path,
    csv_path: Path,
) -> int:
    """
    Extract surface nodes from an LS-PrePost TXT output and save them as CSV.

    CSV columns:
        x, y, z

    The node ID itself is not written to the CSV.
    """
    kept = 0
    in_node_block = False

    with (
        txt_path.open(
            "r",
            encoding="utf-8",
            errors="ignore",
        ) as input_file,
        csv_path.open(
            "w",
            newline="",
            encoding="utf-8",
        ) as output_file,
    ):
        writer = csv.writer(output_file)

        for raw_line in input_file:
            line = raw_line.strip()

            if not line:
                continue

            upper_line = line.upper()

            if upper_line.startswith("*NODE"):
                in_node_block = True
                continue

            if upper_line.startswith("*") and not upper_line.startswith("*NODE"):
                in_node_block = False
                continue

            if not in_node_block:
                continue

            if line.startswith("$") or line.startswith("#"):
                continue

            parts = [part for part in re.split(r"[,\s]+", line) if part]

            if len(parts) < 4:
                continue

            if not all(is_float(parts[index]) for index in range(4)):
                continue

            node_id = int(float(parts[0]))

            if not (SURFACE_NID_MIN <= node_id <= SURFACE_NID_MAX):
                continue

            x = float(parts[1])
            y = float(parts[2])
            z = float(parts[3])

            writer.writerow([x, y, z])
            kept += 1

    return kept


def process_case(case_dir: Path) -> None:
    case_name = case_dir.name
    texture, sd, seed = parse_case_name(case_name)

    run_dir = case_dir / "run"
    d3plot_path = run_dir / "d3plot"

    print(f"\n=== {case_name} ===")

    for state in range(
        STATE_START,
        STATE_END + 1,
    ):
        output_stem = f"coordinates_{texture}_sd{sd}_seed{seed}_state{state:02d}"

        txt_path = run_dir / f"{output_stem}.txt"
        csv_path = run_dir / f"{output_stem}.csv"

        cfile_path = run_dir / f"extract_{output_stem}.cfile"

        if csv_path.exists():
            print(
                f"[{case_name}] state={state} skipped: "
                f"csv already exists -> "
                f"{to_cfile_path(csv_path)}"
            )
            continue

        cfile_text = make_cfile_text(
            d3plot_path=d3plot_path,
            output_txt_path=txt_path,
            state=state,
        )

        cfile_path.write_text(
            cfile_text,
            encoding="utf-8",
        )

        print(f"[{case_name}] state={state} running...")

        run_lsprepost(
            cfile_path=cfile_path,
            workdir=run_dir,
        )

        if not txt_path.exists():
            raise FileNotFoundError(f"txt does not exist: {to_cfile_path(txt_path)}")

        kept = txt_to_surface_csv(
            txt_path=txt_path,
            csv_path=csv_path,
        )

        if not KEEP_TXT:
            txt_path.unlink(missing_ok=True)

        print(
            f"[{case_name}] state={state} completed: "
            f"kept {kept} nodes -> "
            f"{to_cfile_path(csv_path)}"
        )


def main() -> None:
    if not CASE_DIRS:
        raise RuntimeError(
            f"cannot find cases with run/d3plot under: {to_cfile_path(ROOT_DIR)}"
        )

    print(f"ROOT_DIR = {to_cfile_path(ROOT_DIR)}")
    print(f"Found {len(CASE_DIRS)} case(s)")

    for case_dir in CASE_DIRS:
        process_case(case_dir)


if __name__ == "__main__":
    main()
