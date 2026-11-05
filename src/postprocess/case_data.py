from __future__ import annotations

import csv
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import numpy as np
import pandas as pd

from src.dashboard.catalog import OutputRecord, filter_records


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
    """Resolve the preferred height, orientation, and shear artifacts for every complete case."""
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


