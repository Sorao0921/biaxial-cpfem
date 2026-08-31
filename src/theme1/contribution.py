from __future__ import annotations

import csv
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import numpy as np
import pandas as pd

from src.dashboard.catalog import OutputRecord, filter_records

FEATURES = ("gos", "grain_rotation", "accumulated_shear_strain")


@dataclass(frozen=True)
class CaseArtifacts:
    rho: float
    seed: int
    texture: str
    sd: int
    state: int
    height_path: Path
    orientation_path: Path
    shear_path: Path
    spatial_model_dir: Path

    @property
    def case_id(self) -> str:
        return (
            f"rho_{self.rho:g}_{self.texture}_sd{self.sd}_"
            f"seed{self.seed}_state{self.state:02d}"
        )


def complete_cases(
    records: Iterable[OutputRecord], spatial_model_root: Path | str
) -> list[CaseArtifacts]:
    """Resolve the three preferred Theme 1 artifacts for every complete case."""
    records = list(records)
    keys_by_kind = {
        kind: {item.case_key for item in records if item.kind == kind}
        for kind in ("height", "orientation", "shear")
    }
    shared = set.intersection(*keys_by_kind.values())
    spatial_model_root = Path(spatial_model_root)
    cases = []
    for rho, seed, texture, sd, state in sorted(shared):
        if state == 1:
            continue
        model_dir = spatial_model_root / f"seed{seed}"
        if not (model_dir / "elements.csv").is_file():
            continue
        filters = dict(rho=rho, seed=seed, texture=texture, sd=sd, state=state)
        cases.append(
            CaseArtifacts(
                rho,
                seed,
                texture,
                sd,
                state,
                filter_records(records, kind="height", **filters)[0].path,
                filter_records(records, kind="orientation", **filters)[0].path,
                filter_records(records, kind="shear", **filters)[0].path,
                model_dir,
            )
        )
    return cases


def _read_height(path: Path) -> pd.DataFrame:
    with path.open(newline="", encoding="utf-8-sig") as stream:
        first = next(csv.reader(stream), [])
    has_header = any(not _is_number(value) for value in first)
    frame = pd.read_csv(path, header=0 if has_header else None)
    if frame.shape[1] == 3:
        frame = frame.iloc[:, :3].copy()
        frame.columns = ["x", "y", "z"]
        frame.insert(0, "node_id", np.arange(1, len(frame) + 1))
    elif frame.shape[1] >= 4:
        frame = frame.iloc[:, :4].copy()
        frame.columns = ["node_id", "x", "y", "z"]
    else:
        raise ValueError(f"Height data must contain x, y, z: {path}")
    for column in frame.columns:
        frame[column] = pd.to_numeric(frame[column], errors="coerce")
    frame = frame.dropna()
    frame["node_id"] = frame["node_id"].astype(int)
    return frame


def _is_number(value: str) -> bool:
    try:
        float(value)
    except ValueError:
        return False
    return True


def _detrended_node_roughness(height: pd.DataFrame) -> dict[int, float]:
    design = np.column_stack(
        [height["x"].to_numpy(), height["y"].to_numpy(), np.ones(len(height))]
    )
    plane, *_ = np.linalg.lstsq(design, height["z"].to_numpy(), rcond=None)
    residual = height["z"].to_numpy() - design @ plane
    return dict(zip(height["node_id"].astype(int), np.abs(residual)))


def _restore_global_surface_node_ids(
    node_roughness: dict[int, float], spatial_model_dir: Path, surface: pd.DataFrame
) -> dict[int, float]:
    """Translate edge-dropper row IDs back to the original top-surface node IDs.

    ``EdgeDropper`` numbers the 151x151 extracted surface rows from one, while
    the spatial model retains LS-DYNA's global IDs. Direct IDs are kept when
    they already overlap the surface connectivity (also useful for other data
    producers that preserve global IDs).
    """
    node_columns = [column for column in surface.columns if column.startswith("node_id_")]
    connected = set(surface[node_columns].to_numpy().astype(int).ravel())
    if connected.intersection(node_roughness):
        return node_roughness
    nodes_path = spatial_model_dir / "nodes.csv"
    if not nodes_path.is_file():
        return node_roughness
    nodes = pd.read_csv(nodes_path)
    top = nodes[np.isclose(nodes["z"], nodes["z"].max())].sort_values("node_id")
    local_to_global = dict(enumerate(top["node_id"].astype(int), start=1))
    return {
        local_to_global[local_id]: value
        for local_id, value in node_roughness.items()
        if local_id in local_to_global
    }


def load_case_samples(case: CaseArtifacts) -> pd.DataFrame:
    """Join node-, element-, and grain-level fields on top-surface elements."""
    node_roughness = _detrended_node_roughness(_read_height(case.height_path))
    elements = pd.read_csv(case.spatial_model_dir / "elements.csv")
    required = {"element_id", "part_id", "center_z"}
    if not required.issubset(elements.columns):
        raise ValueError(f"Spatial model is missing {sorted(required - set(elements.columns))}")
    surface = elements[np.isclose(elements["center_z"], elements["center_z"].max())].copy()
    node_columns = [column for column in surface.columns if column.startswith("node_id_")]
    if not node_columns:
        raise ValueError("Spatial model has no element connectivity columns.")
    node_roughness = _restore_global_surface_node_ids(
        node_roughness, case.spatial_model_dir, surface
    )

    def local_roughness(row: pd.Series) -> float:
        values = [node_roughness.get(int(row[column])) for column in node_columns]
        available = [value for value in values if value is not None]
        return float(np.mean(available)) if available else np.nan

    surface["surface_roughness"] = surface.apply(local_roughness, axis=1)

    orientation = pd.read_csv(case.orientation_path)
    orientation = orientation.rename(
        columns={"gos_deg": "gos", "grain_rotation_deg": "grain_rotation"}
    )
    orientation = orientation[["part_id", "gos", "grain_rotation"]]
    shear = pd.read_csv(case.shear_path).rename(
        columns={"accumulated_shear_strain_total": "accumulated_shear_strain"}
    )
    shear = shear[["element_id", "accumulated_shear_strain"]]
    samples = surface[["element_id", "part_id", "surface_roughness"]].merge(
        orientation, on="part_id", how="inner", validate="many_to_one"
    ).merge(shear, on="element_id", how="inner", validate="one_to_one")
    samples.insert(0, "case_id", case.case_id)
    samples = samples.replace([np.inf, -np.inf], np.nan).dropna()
    if len(samples) < len(FEATURES) + 2:
        raise ValueError(f"Too few joined surface samples for {case.case_id}: {len(samples)}")
    return samples


def _standardize(frame: pd.DataFrame) -> pd.DataFrame:
    columns = [*FEATURES, "surface_roughness"]
    scale = frame[columns].std(ddof=0)
    if (scale <= 0).any():
        constant = scale.index[scale <= 0].tolist()
        raise ValueError(f"Cannot estimate contribution with constant columns: {constant}")
    result = frame.copy()
    result[columns] = (frame[columns] - frame[columns].mean()) / scale
    return result


def _fit(x: np.ndarray, y: np.ndarray, weights: np.ndarray) -> tuple[np.ndarray, float]:
    design = np.column_stack([np.ones(len(x)), x])
    root_weight = np.sqrt(weights)
    beta, *_ = np.linalg.lstsq(design * root_weight[:, None], y * root_weight, rcond=None)
    prediction = design @ beta
    mean = np.average(y, weights=weights)
    total = np.sum(weights * (y - mean) ** 2)
    residual = np.sum(weights * (y - prediction) ** 2)
    r_squared = 1.0 - residual / total if total > 0 else np.nan
    return beta[1:], float(r_squared)


def estimate_contributions(cases: Iterable[CaseArtifacts]) -> tuple[pd.DataFrame, pd.DataFrame, dict]:
    """Estimate equal-case-weighted standardized coefficients and relative weights."""
    standardized = []
    case_rows = []
    for case in cases:
        samples = _standardize(load_case_samples(case))
        x = samples[list(FEATURES)].to_numpy(float)
        y = samples["surface_roughness"].to_numpy(float)
        coefficients, r_squared = _fit(x, y, np.ones(len(samples)))
        case_rows.append(
            {
                "case_id": case.case_id,
                "rho": case.rho,
                "seed": case.seed,
                "texture": case.texture,
                "sd": case.sd,
                "state": case.state,
                "samples": len(samples),
                "r_squared": r_squared,
                **dict(zip((f"beta_{name}" for name in FEATURES), coefficients)),
            }
        )
        standardized.append(samples)
    if not standardized:
        raise ValueError("No complete Theme 1 cases were available.")
    pooled = pd.concat(standardized, ignore_index=True)
    counts = pooled.groupby("case_id")["case_id"].transform("size").to_numpy(float)
    weights = 1.0 / counts
    coefficients, r_squared = _fit(
        pooled[list(FEATURES)].to_numpy(float),
        pooled["surface_roughness"].to_numpy(float),
        weights,
    )
    absolute = np.abs(coefficients)
    relative = absolute / absolute.sum() if absolute.sum() else np.zeros_like(absolute)
    summary = pd.DataFrame(
        {
            "feature": FEATURES,
            "standardized_coefficient": coefficients,
            "relative_weight": relative,
            "relative_weight_percent": relative * 100.0,
        }
    ).sort_values("relative_weight", ascending=False, ignore_index=True)
    diagnostics = {
        "cases": len(standardized),
        "samples": len(pooled),
        "equal_case_weighted_r_squared": r_squared,
        "target": "absolute height residual from the least-squares reference plane",
        "interpretation": "association, not causal effect",
    }
    return summary, pd.DataFrame(case_rows), diagnostics
