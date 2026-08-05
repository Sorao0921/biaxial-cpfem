from __future__ import annotations

import csv
import re
from pathlib import Path

"""
THIS SCRIPT HAVE TO BE RUN ON SUPERDYNA4.

Extracted history variables
---------------------------
hv115:
    Total accumulated shear strain over all slip systems.

hv103-hv114:
    Accumulated shear strain for slip systems 1-12.
"""

from extract_surface_coords import (
    CASE_DIRS,
    KEEP_TXT,
    ROOT_DIR,
    STATE_END,
    STATE_START,
    parse_case_name,
    run_lsprepost,
    to_cfile_path,
)

# ============================================================
# History-variable definitions
# ============================================================

HV_TO_COMPONENT = {
    115: "accumulated_shear_strain_total",
    103: "accumulated_shear_strain_slip01",
    104: "accumulated_shear_strain_slip02",
    105: "accumulated_shear_strain_slip03",
    106: "accumulated_shear_strain_slip04",
    107: "accumulated_shear_strain_slip05",
    108: "accumulated_shear_strain_slip06",
    109: "accumulated_shear_strain_slip07",
    110: "accumulated_shear_strain_slip08",
    111: "accumulated_shear_strain_slip09",
    112: "accumulated_shear_strain_slip10",
    113: "accumulated_shear_strain_slip11",
    114: "accumulated_shear_strain_slip12",
}


# ============================================================
# Basic utilities
# ============================================================


def is_float(value: str) -> bool:
    """
    Return True when the input string can be interpreted as a float.

    Fortran-style exponents such as 1.0D+03 are also accepted.
    """
    try:
        float(value.replace("D", "E").replace("d", "E"))
        return True
    except ValueError:
        return False


def to_float(value: str) -> float:
    """
    Convert a numeric string to float.

    Fortran-style D exponents are converted to Python-compatible E exponents.
    """
    return float(value.replace("D", "E").replace("d", "E"))


# ============================================================
# Filename utilities
# ============================================================


def make_shear_strain_txt_stem(
    texture: str,
    sd: str,
    seed: str,
    state: int,
    hv: int,
) -> str:
    """
    Create the filename stem for an intermediate LS-PrePost TXT file.

    Example
    -------
    shear_strain_brass_sd2_seed1_state01_hv182_
    accumulated_shear_strain_slip01
    """
    component = HV_TO_COMPONENT[hv]

    return (
        f"shear_strain_{texture}_sd{sd}_seed{seed}_state{state:02d}_hv{hv}_{component}"
    )


def make_shear_strain_output_stem(
    texture: str,
    sd: str,
    seed: str,
    state: int,
) -> str:
    """
    Create the filename stem for the combined output file.

    Example
    -------
    shear_strain_brass_sd2_seed1_state01
    """
    return f"shear_strain_{texture}_sd{sd}_seed{seed}_state{state:02d}"


# ============================================================
# LS-PrePost cfile generation
# ============================================================


def make_shear_strain_cfile_text(
    d3plot_path: Path,
    hv_to_txt_path: dict[int, Path],
    state: int,
) -> str:
    """
    Generate an LS-PrePost command file.

    Each history variable is displayed with pfringe and exported into
    a separate temporary TXT file.

    In LS-PrePost, history variable hvN is selected using:

        fringe 1000 + N

    Therefore:

        hv115 -> fringe 1115
        hv103 -> fringe 1103
        ...
        hv114 -> fringe 1114
    """
    d3plot_str = to_cfile_path(d3plot_path)

    lines = [
        f'openc d3plot "{d3plot_str}"\n',
        "ac\n",
        f"state {state};\n",
    ]

    for hv, txt_path in hv_to_txt_path.items():
        fringe_id = 1000 + hv
        output_txt_str = to_cfile_path(txt_path)

        lines.extend(
            [
                f"fringe {fringe_id}\n",
                "pfringe\n",
                (f'output "{output_txt_str}" {state} 1 0 1 0 0 0 0 1 0 0 0\n'),
            ]
        )

    lines.append("exit\n")

    return "".join(lines)


# ============================================================
# LS-PrePost TXT parser
# ============================================================


def parse_element_value_txt(
    txt_path: Path,
) -> dict[int, float]:
    """
    Read an LS-PrePost history-variable TXT file.

    Expected data section
    ---------------------
    First column:
        element ID

    Second column:
        selected history-variable value

    Header lines and nonnumeric lines are ignored.

    Returns
    -------
    dict[int, float]
        Mapping from element ID to history-variable value.
    """
    values: dict[int, float] = {}

    with txt_path.open(
        "r",
        encoding="utf-8",
        errors="ignore",
    ) as input_file:
        for raw_line in input_file:
            line = raw_line.strip()

            if not line:
                continue

            if line.startswith("$") or line.startswith("#") or line.startswith("*"):
                continue

            parts = [part for part in re.split(r"[,\s]+", line) if part]

            if len(parts) < 2:
                continue

            if not (is_float(parts[0]) and is_float(parts[1])):
                continue

            element_id_float = to_float(parts[0])
            element_id = int(element_id_float)

            if element_id <= 0:
                continue

            # Reject a noninteger first column.
            if abs(element_id_float - element_id) > 1.0e-8:
                continue

            values[element_id] = to_float(parts[1])

    if not values:
        raise ValueError(
            f"No element-value data could be parsed from: {to_cfile_path(txt_path)}"
        )

    return values


# ============================================================
# Combined CSV/TXT output
# ============================================================


def shear_strain_txt_to_outputs(
    hv_to_txt_path: dict[int, Path],
    csv_path: Path,
    txt_path: Path,
) -> int:
    """
    Combine hv115 and hv103-hv114 into one table.

    Output columns
    --------------
    element_id

    accumulated_shear_strain_total

    accumulated_shear_strain_slip01
    accumulated_shear_strain_slip02
    ...
    accumulated_shear_strain_slip12

    Returns
    -------
    int
        Number of element IDs written to the output.
    """
    component_to_values: dict[str, dict[int, float]] = {}
    all_element_ids: set[int] = set()

    for hv, raw_txt_path in hv_to_txt_path.items():
        component = HV_TO_COMPONENT[hv]
        values = parse_element_value_txt(raw_txt_path)

        component_to_values[component] = values
        all_element_ids.update(values.keys())

    header = [
        "element_id",
        *HV_TO_COMPONENT.values(),
    ]

    rows: list[list[object]] = []

    for element_id in sorted(all_element_ids):
        row: list[object] = [element_id]

        for component in HV_TO_COMPONENT.values():
            value = component_to_values[component].get(element_id)

            if value is None:
                row.append("")
            else:
                row.append(value)

        rows.append(row)

    csv_path.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    with csv_path.open(
        "w",
        newline="",
        encoding="utf-8",
    ) as output_file:
        writer = csv.writer(output_file)
        writer.writerow(header)
        writer.writerows(rows)

    with txt_path.open(
        "w",
        newline="",
        encoding="utf-8",
    ) as output_file:
        writer = csv.writer(output_file)
        writer.writerow(header)
        writer.writerows(rows)

    return len(all_element_ids)


# ============================================================
# Case processing
# ============================================================


def process_case(case_dir: Path) -> None:
    """
    Extract shear-strain history variables for every state in one case.
    """
    case_name = case_dir.name
    texture, sd, seed = parse_case_name(case_name)

    run_dir = case_dir / "run"
    d3plot_path = run_dir / "d3plot"

    if not d3plot_path.exists():
        raise FileNotFoundError(f"d3plot does not exist: {to_cfile_path(d3plot_path)}")

    print()
    print(f"=== {case_name} ===")

    for state in range(
        STATE_START,
        STATE_END + 1,
    ):
        output_stem = make_shear_strain_output_stem(
            texture=texture,
            sd=sd,
            seed=seed,
            state=state,
        )

        csv_path = run_dir / f"{output_stem}.csv"
        txt_path = run_dir / f"{output_stem}.txt"

        cfile_path = run_dir / f"extract_{output_stem}.cfile"

        hv_to_txt_path = {
            hv: (
                run_dir
                / (
                    make_shear_strain_txt_stem(
                        texture=texture,
                        sd=sd,
                        seed=seed,
                        state=state,
                        hv=hv,
                    )
                    + ".txt"
                )
            )
            for hv in HV_TO_COMPONENT
        }

        # Existing CSV means this state has already been processed.
        if csv_path.exists():
            print(
                f"[{case_name}] state={state} skipped: "
                "CSV already exists -> "
                f"{to_cfile_path(csv_path)}"
            )
            continue

        cfile_text = make_shear_strain_cfile_text(
            d3plot_path=d3plot_path,
            hv_to_txt_path=hv_to_txt_path,
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

        # Confirm that all history-variable TXT files were generated.
        for hv, raw_txt_path in hv_to_txt_path.items():
            if not raw_txt_path.exists():
                raise FileNotFoundError(
                    f"TXT does not exist for hv{hv}: {to_cfile_path(raw_txt_path)}"
                )

        kept = shear_strain_txt_to_outputs(
            hv_to_txt_path=hv_to_txt_path,
            csv_path=csv_path,
            txt_path=txt_path,
        )

        # Delete only the temporary per-HV files.
        # The combined TXT file is preserved.
        if not KEEP_TXT:
            for raw_txt_path in hv_to_txt_path.values():
                raw_txt_path.unlink(missing_ok=True)

        print(
            f"[{case_name}] state={state} completed: "
            f"kept {kept} elements -> "
            f"{to_cfile_path(csv_path)}, "
            f"{to_cfile_path(txt_path)}"
        )


# ============================================================
# Main
# ============================================================


def main() -> None:
    if not CASE_DIRS:
        raise RuntimeError(
            f"Cannot find cases containing run/d3plot under: {to_cfile_path(ROOT_DIR)}"
        )

    print(f"ROOT_DIR = {to_cfile_path(ROOT_DIR)}")
    print(f"Found {len(CASE_DIRS)} case(s)")

    for case_dir in CASE_DIRS:
        process_case(case_dir)


if __name__ == "__main__":
    main()
