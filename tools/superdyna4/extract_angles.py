from __future__ import annotations

import csv
import re
from pathlib import Path

"""
THIS SCRIPT HAVE TO BE RUN ON SUPERDYNA4.
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

# hv201--hv203 are the three Bunge Euler angles stored by the UMAT.
# The values are exported in radians as phi1, Phi, and phi2.
HV_TO_COMPONENT = {
    201: "phi1",
    202: "Phi",
    203: "phi2",
}


def is_float(value: str) -> bool:
    try:
        float(value.replace("D", "E").replace("d", "E"))
        return True
    except ValueError:
        return False


def to_float(value: str) -> float:
    return float(value.replace("D", "E").replace("d", "E"))


def make_angle_txt_stem(
    texture: str,
    sd: str,
    seed: str,
    state: int,
    hv: int,
) -> str:
    """
    Create the filename stem for a temporary LS-PrePost TXT file.
    """
    component = HV_TO_COMPONENT[hv]

    return f"angle_{texture}_sd{sd}_seed{seed}_state{state:02d}_hv{hv}_{component}"


def make_bunge_euler_output_stem(
    texture: str,
    sd: str,
    seed: str,
    state: int,
) -> str:
    """
    Create the final Bunge Euler output filename stem.
    """
    return f"bunge_euler_{texture}_sd{sd}_seed{seed}_state{state:02d}"


def make_angle_cfile_text(
    d3plot_path: Path,
    hv_to_txt_path: dict[int, Path],
    state: int,
) -> str:
    d3plot_str = to_cfile_path(d3plot_path)

    lines = [
        f'openc d3plot "{d3plot_str}"\n',
        "ac\n",
        f"state {state};\n",
    ]

    for hv, txt_path in hv_to_txt_path.items():
        # LS-PrePost exports history variable hvN
        # using fringe ID 1000 + N.
        #
        # hv201 -> fringe 1201
        # hv202 -> fringe 1202
        # hv203 -> fringe 1203
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


def parse_element_value_txt(
    txt_path: Path,
) -> dict[int, float]:
    """
    Parse one LS-PrePost TXT file exported from pfringe.

    Expected data columns:
        1st column: element ID
        2nd column: selected history-variable value
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

            if abs(element_id_float - element_id) > 1.0e-8:
                continue

            values[element_id] = to_float(parts[1])

    if not values:
        raise ValueError(
            f"no element-value data could be parsed from: {to_cfile_path(txt_path)}"
        )

    return values


def angle_txt_to_outputs(
    hv_to_txt_path: dict[int, Path],
    csv_path: Path,
    txt_path: Path,
) -> int:
    """
    Combine hv201--hv203 TXT files into one CSV and one TXT file.

    Output columns:
        element_id, phi1, Phi, phi2
    """
    component_to_values: dict[
        str,
        dict[int, float],
    ] = {}

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

            row.append("" if value is None else value)

        rows.append(row)

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
        output_stem = make_bunge_euler_output_stem(
            texture=texture,
            sd=sd,
            seed=seed,
            state=state,
        )

        csv_path = run_dir / f"{output_stem}.csv"
        txt_path = run_dir / f"{output_stem}.txt"

        cfile_path = run_dir / f"extract_{output_stem}.cfile"

        hv_to_txt_path = {
            hv: run_dir
            / (
                make_angle_txt_stem(
                    texture=texture,
                    sd=sd,
                    seed=seed,
                    state=state,
                    hv=hv,
                )
                + ".txt"
            )
            for hv in HV_TO_COMPONENT
        }

        if csv_path.exists():
            print(
                f"[{case_name}] state={state} skipped: "
                f"csv already exists -> "
                f"{to_cfile_path(csv_path)}"
            )
            continue

        cfile_text = make_angle_cfile_text(
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

        for hv, raw_txt_path in hv_to_txt_path.items():
            if not raw_txt_path.exists():
                raise FileNotFoundError(
                    f"txt does not exist for hv{hv}: {to_cfile_path(raw_txt_path)}"
                )

        kept = angle_txt_to_outputs(
            hv_to_txt_path=hv_to_txt_path,
            csv_path=csv_path,
            txt_path=txt_path,
        )

        if not KEEP_TXT:
            for raw_txt_path in hv_to_txt_path.values():
                raw_txt_path.unlink(missing_ok=True)

        print(
            f"[{case_name}] state={state} completed: "
            f"kept {kept} elements -> "
            f"{to_cfile_path(csv_path)}, "
            f"{to_cfile_path(txt_path)}"
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
