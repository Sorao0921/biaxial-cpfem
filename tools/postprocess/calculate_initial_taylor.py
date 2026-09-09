"""Run from repository root: python -m tools.postprocess.calculate_initial_taylor."""

import hashlib
import json
import re
from collections import Counter
from pathlib import Path

import numpy as np
import pandas as pd

from src.crystal_plasticity.taylor_factor import primal_check, taylor_factor

ROOT = Path(__file__).resolve().parents[2]


def mesh_counts(seed):
    counts = Counter()
    active = False
    path = ROOT / f"inputs/keywords/consts/partset_seed{seed}.k"
    for line in path.read_text().splitlines():
        if line.startswith("*"):
            active = line.strip() == "*ELEMENT_SOLID"
        elif active and line.strip() and not line.startswith("$"):
            fields = line.split()
            if len(fields) != 10:
                raise ValueError(f"Unsupported element record: {line}")
            counts[int(fields[1])] += 1
    if not counts:
        raise ValueError(f"No solid elements: {path}")
    return counts


def main():
    out = ROOT / "database/taylor_factor_initial"
    out.mkdir(exist_ok=True)
    frames = []
    summaries = []
    sources = []
    max_error = 0.0
    counts = {seed: mesh_counts(seed) for seed in range(1, 6)}
    for path in sorted((ROOT / "inputs/orientation").glob("texture_seed*/*.csv")):
        match = re.fullmatch(r"(\w+)_sigma(\d+)_seed(\d+)", path.stem)
        if match is None:
            raise ValueError(f"Unrecognized case: {path}")
        texture, sd, seed = match.groups()
        sd = int(sd)
        seed = int(seed)
        angles = np.loadtxt(path, delimiter=",", ndmin=2)
        if angles.shape[1] != 3 or not np.isfinite(angles).all():
            raise ValueError(f"Invalid orientations: {path}")
        if max(counts[seed]) > len(angles):
            raise ValueError("Mesh part without orientation")
        ids = np.arange(1, len(angles) + 1)
        weights = np.array([counts[seed][int(i)] for i in ids])
        for label, rho in [
            ("-0.5", -0.5),
            ("0", 0.0),
            ("1", 1.0),
            ("0_boundary", 0.001),
        ]:
            values = taylor_factor(angles, rho)
            err = float(np.max(np.abs(values[:3] - primal_check(angles[:3], rho))))
            max_error = max(err, max_error)
            if err > 1e-8 or not np.isfinite(values).all() or np.any(values <= 0):
                raise ValueError("Taylor solver validation failed")
            frame = pd.DataFrame(
                dict(
                    texture=texture,
                    sd=sd,
                    seed=seed,
                    state=1,
                    rho_label=label,
                    rho_used=rho,
                    part_id=ids,
                    element_count=weights,
                    phi1_rad=angles[:, 0],
                    Phi_rad=angles[:, 1],
                    phi2_rad=angles[:, 2],
                    taylor_factor=values,
                )
            )
            frames.append(frame)
            if label != '0_boundary':
                case=f'{texture}_sd{sd}_seed{seed}'
                case_dir=out/f'rho_{rho:g}/rho_{rho:g}_seed{seed}/taylor_factor/initial'
                case_dir.mkdir(parents=True,exist_ok=True)
                frame.to_csv(case_dir/f'taylor_factor_{case}_state01.csv',index=False,float_format='%.12g')
            present = values[weights > 0]
            summaries.append(
                dict(
                    texture=texture,
                    sd=sd,
                    seed=seed,
                    rho_label=label,
                    rho_used=rho,
                    orientation_count=len(values),
                    mesh_grain_count=len(present),
                    mean_grain=present.mean(),
                    mean_element_weighted=np.average(values, weights=weights),
                    min=present.min(),
                    max=present.max(),
                    std_grain=present.std(ddof=0),
                )
            )
        sources.append(
            dict(
                path=str(path.relative_to(ROOT)),
                sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
            )
        )
    df = pd.concat(frames, ignore_index=True)
    if df.duplicated(["texture", "sd", "seed", "rho_label", "part_id"]).any():
        raise ValueError("Duplicate grain keys")
    df.to_csv(out / "grain_taylor_factors.csv", index=False, float_format="%.12g")
    summary = pd.DataFrame(summaries)
    summary.to_csv(out / "case_summary.csv", index=False, float_format="%.12g")
    metadata = dict(
        definition="min sum(abs(gamma))/sqrt(2/3 D:D)",
        model="FCC {111}<110>, equal CRSS, full-constraint Taylor",
        strain="diag(1,rho,-1-rho); x primary; y transverse; z thickness",
        normalization="von Mises equivalent plastic strain",
        orientation="Bunge radians; passive sample-to-crystal matrix",
        rows=len(df),
        source_files=len(sources),
        max_primal_dual_error=max_error,
        notes=[
            "Initial orientation-based predictions, not measured FE local plastic response.",
            "rho=0_boundary uses 0.001 from boundary card; nominal rho=0 also supplied.",
            "Element-weighted mean is not asserted to be a volume-weighted mean.",
            "Rows with element_count=0 are unused orientation entries and excluded from grain means.",
        ],
        sources=sources,
    )
    for p in sorted((ROOT / "inputs/keywords").glob("**/*.k")):
        if p.name.startswith(("partset_seed", "boundary_rho_")):
            metadata.setdefault("mesh_and_boundary_sources", []).append(
                dict(
                    path=str(p.relative_to(ROOT)),
                    sha256=hashlib.sha256(p.read_bytes()).hexdigest(),
                )
            )
    (out / "metadata.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(
        json.dumps(
            {k: metadata[k] for k in ["rows", "source_files", "max_primal_dual_error"]},
            indent=2,
        )
    )
    print(df.groupby("rho_label").taylor_factor.agg(["mean", "min", "max"]).to_string())


if __name__ == "__main__":
    main()
