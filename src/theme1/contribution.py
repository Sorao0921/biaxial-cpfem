from __future__ import annotations

from typing import Iterable

import numpy as np
import pandas as pd

from src.postprocess.case_data import (
    CaseArtifacts, _read_height, _detrended_node_roughness,
    _restore_global_surface_node_ids,
)

FEATURES = ("gos", "grain_rotation", "accumulated_shear_strain")


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
