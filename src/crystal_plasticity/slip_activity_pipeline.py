"""Compute and save slip activity independently of plotting or surface selection."""
from pathlib import Path
import argparse
import hashlib
import json
import numpy as np
import pandas as pd
from src.config.pipeline_paths import OUTPUTS_DIR
from src.crystal_plasticity.slip_activity import LEGACY_FCC_DIRECTIONS, z_slip_activity

SLIP_COLUMNS = [f"accumulated_shear_strain_slip{i:02d}" for i in range(1, 13)]


def read_element_frame(path, columns):
    frame = pd.read_csv(path)
    missing = {"element_id", *columns} - set(frame)
    if missing:
        raise ValueError(f"Missing columns {sorted(missing)}: {path}")
    ids = pd.to_numeric(frame.element_id, errors="raise")
    if not np.isfinite(ids).all() or (ids <= 0).any() or (ids != np.floor(ids)).any() or ids.duplicated().any():
        raise ValueError(f"Invalid or duplicate element IDs: {path}")
    frame["element_id"] = ids.astype(int)
    if frame.empty:
        raise ValueError(f"Empty element data: {path}")
    return frame.set_index("element_id")[columns].apply(pd.to_numeric, errors="raise")


def macro_interval(path, state):
    if state < 2:
        raise ValueError("state01 has no preceding interval")
    frame = pd.read_csv(path)
    frame.columns = frame.columns.str.strip().str.lower()
    if "eps_eq" not in frame:
        raise ValueError(f"Missing eps_eq: {path}")
    values = pd.to_numeric(frame.eps_eq, errors="raise").to_numpy()
    if not np.isfinite(values).all() or (values < 0).any() or state > len(values):
        raise ValueError(f"Invalid or missing macro strain for state{state:02d}: {path}")
    start, end = values[state - 2:state]
    if end <= start:
        raise ValueError("Macro equivalent strain must increase across the interval")
    return float(start), float(end)


def calculate_frame(previous_path, current_path, angles_path, *, delta_epsilon,
                    directions=LEGACY_FCC_DIRECTIONS):
    previous = read_element_frame(previous_path, SLIP_COLUMNS)
    current = read_element_frame(current_path, SLIP_COLUMNS)
    angles = read_element_frame(angles_path, ["phi1", "Phi", "phi2"])
    if set(previous.index) != set(current.index) or not set(current.index).issubset(angles.index):
        raise ValueError("State slip data and orientation element IDs do not match")
    current = current.sort_index()
    previous = previous.loc[current.index]
    angles = angles.loc[current.index]
    az, rz = z_slip_activity(previous.to_numpy(), current.to_numpy(), angles.to_numpy(),
                           delta_epsilon=delta_epsilon, directions=directions)
    result = pd.DataFrame({"element_id": current.index, "z_slip_activity": az,
                           "z_slip_fraction": rz, "delta_eps_eq": delta_epsilon})
    for column in SLIP_COLUMNS:
        result[column.replace("accumulated_shear_strain", "slip_rate")] = np.maximum(
            current[column].to_numpy() - previous[column].to_numpy(), 0) / delta_epsilon
    return result


def resolve_source(base, category, case, state):
    """Prefer normalized data; accept raw state{i}.csv inside its case directory."""
    prefix = "shear_strain" if category == "shear_strains" else "bunge_euler"
    for source in ("id_set", "rawdata"):
        candidates = []
        for path in (base / category / source).rglob("*.csv"):
            if case not in path.as_posix():
                continue
            if path.name in (f"{prefix}_{case}_state{state:02d}.csv",
                              f"{prefix}_{case}_state{state}.csv",
                              f"state{state}.csv", f"state{state:02d}.csv"):
                candidates.append(path)
        if len(candidates) == 1:
            return candidates[0]
        if len(candidates) > 1:
            raise ValueError(f"Ambiguous {category} state{state}: {candidates}")
    raise FileNotFoundError(f"Missing {category} {case} state{state:02d} under {base}")


def activity_path(record, destination=OUTPUTS_DIR):
    case = f"{record.texture}_sd{record.sd}_seed{record.seed}"
    base = Path(destination) / f"rho_{record.rho:g}" / f"rho_{record.rho:g}_seed{record.seed}"
    return base / "shear_strains" / "z_slip_activity" / case / f"z_slip_activity_{case}_state{record.state:02d}.csv"


def ensure_activity(record, destination=OUTPUTS_DIR, *, force=False):
    out = activity_path(record, destination)
    base = out.parents[3]
    case = f"{record.texture}_sd{record.sd}_seed{record.seed}"
    if record.state < 2:
        raise ValueError("state01 has no preceding interval")
    previous = resolve_source(base, "shear_strains", case, record.state - 1)
    current = resolve_source(base, "shear_strains", case, record.state)
    angles = resolve_source(base, "angles", case, record.state - 1)
    macro = base / "eps_equivalent.csv"
    start, end = macro_interval(macro, record.state)
    # Optional persistent model-specific ordering; no per-plot upload/confirmation.
    direction_path = Path(destination).parent / "inputs" / "slip_directions.csv"
    directions = LEGACY_FCC_DIRECTIONS
    sources = [previous, current, angles, macro, Path(__file__), Path(__file__).with_name("slip_activity.py"),
               Path(__file__).with_name("taylor_factor.py")]
    if direction_path.exists():
        table = pd.read_csv(direction_path).sort_values("slip_id")
        if table.slip_id.tolist() != list(range(1, 13)):
            raise ValueError("slip_directions.csv must contain slip_id 1..12 exactly once")
        directions = table[["sx", "sy", "sz"]].to_numpy(dtype=float)
        lengths = np.linalg.norm(directions, axis=1)
        if not np.isfinite(directions).all() or (lengths <= 0).any():
            raise ValueError("Slip directions must be finite and nonzero")
        directions = directions / lengths[:, None]
        sources.append(direction_path)
    signature = {"sources": {str(p.resolve()): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},
                 "direction_order": "inputs/slip_directions.csv" if direction_path.exists() else "dyn21umats_0710.F m(:,1:12)",
                 "orientation_state": record.state - 1}
    metadata = out.with_suffix(".json")
    if not force and out.exists() and metadata.exists():
        try:
            saved = json.loads(metadata.read_text())
            if saved.get("signature") == signature and saved.get("output_sha256") == hashlib.sha256(out.read_bytes()).hexdigest():
                return out
        except (ValueError, OSError):
            pass
    result = calculate_frame(previous, current, angles, delta_epsilon=end-start, directions=directions)
    result["previous_state"] = record.state - 1
    result["state"] = record.state
    result["eps_eq_previous"] = start
    result["eps_eq"] = end
    out.parent.mkdir(parents=True, exist_ok=True)
    temp = out.with_suffix(".csv.tmp")
    result.to_csv(temp, index=False, float_format="%.12g")
    temp.replace(out)
    metadata.write_text(json.dumps({"signature": signature,
        "output_sha256": hashlib.sha256(out.read_bytes()).hexdigest()}, indent=2))
    return out


def main(argv=None):
    from src.dashboard.catalog import OutputRecord, _case_from_path
    parser = argparse.ArgumentParser(description="Save z-directed slip activity per macro equivalent-strain increment")
    for field, kind in (("rho", float), ("seed", int), ("texture", str), ("sd", int), ("state", int)):
        parser.add_argument(f"--{field}", type=kind)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args(argv)
    discovered = {}
    for path in OUTPUTS_DIR.glob("rho_*/rho_*_seed*/shear_strains/**/state*.csv"):
        import re
        case = re.search(r"(brass|copper|cube|goss|s)_sd(\d+)_seed(\d+)", path.as_posix())
        state = re.fullmatch(r"state(\d+)\.csv", path.name)
        if case and state:
            rho = next(float(p.removeprefix("rho_")) for p in path.parts if re.fullmatch(r"rho_-?\d+(?:\.\d+)?", p))
            key = (rho, int(case[3]), case[1], int(case[2]), int(state[1]))
            discovered[key] = OutputRecord("shear", *key, path, "source")
    for source in ("rawdata", "id_set"):
        for path in OUTPUTS_DIR.glob(f"rho_*/rho_*_seed*/shear_strains/{source}/**/*.csv"):
            key = _case_from_path(path)
            if key:
                discovered[key] = OutputRecord("shear", *key, path, source)
    records = [r for r in discovered.values() if r.state > 1
        and all(getattr(args, f) is None or getattr(args, f) == getattr(r, f)
                for f in ("rho", "seed", "texture", "sd", "state"))]
    if not records:
        parser.error("No matching states")
    for record in records:
        print(ensure_activity(record, force=args.force))


if __name__ == "__main__":
    main()
