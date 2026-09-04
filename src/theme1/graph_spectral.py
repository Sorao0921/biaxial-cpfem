from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Mapping

import numpy as np
import pandas as pd

from src.theme1.contribution import (
    CaseArtifacts,
    _read_height,
    _restore_global_surface_node_ids,
)


@dataclass(frozen=True)
class SurfaceGrainGraph:
    """Weighted adjacency and graph-Fourier basis for surface grains."""

    node_ids: np.ndarray
    node_table: pd.DataFrame
    edge_table: pd.DataFrame
    adjacency: np.ndarray
    laplacian: np.ndarray
    eigenvalues: np.ndarray
    eigenvectors: np.ndarray

    def transform(self, signal: np.ndarray) -> np.ndarray:
        values = np.asarray(signal, dtype=float)
        if values.shape != (len(self.node_ids),):
            raise ValueError(f"Expected {len(self.node_ids)} graph values, got {values.shape}.")
        return self.eigenvectors.T @ values

    def inverse_transform(self, coefficients: np.ndarray) -> np.ndarray:
        values = np.asarray(coefficients, dtype=float)
        if values.shape != (len(self.node_ids),):
            raise ValueError(f"Expected {len(self.node_ids)} coefficients, got {values.shape}.")
        return self.eigenvectors @ values


def _surface_elements(elements: pd.DataFrame) -> pd.DataFrame:
    required = {"element_id", "part_id", "center_x", "center_y", "center_z"}
    missing = required - set(elements.columns)
    if missing:
        raise ValueError(f"Spatial model is missing {sorted(missing)}")
    return elements[np.isclose(elements["center_z"], elements["center_z"].max())].copy()


def _top_face_edges(row: pd.Series, nodes: pd.DataFrame) -> list[tuple[int, int, float]]:
    node_columns = [column for column in row.index if column.startswith("node_id_")]
    ids = [int(row[column]) for column in node_columns if pd.notna(row[column])]
    coordinates = nodes[nodes["node_id"].isin(ids)].copy()
    if coordinates.empty:
        return []
    top = coordinates[np.isclose(coordinates["z"], coordinates["z"].max())].copy()
    if len(top) < 3:
        return []
    center = top[["x", "y"]].mean().to_numpy(float)
    delta = top[["x", "y"]].to_numpy(float) - center
    top["angle"] = np.arctan2(delta[:, 1], delta[:, 0])
    ordered = top.sort_values("angle")
    points = {
        int(item.node_id): np.array([item.x, item.y], dtype=float)
        for item in ordered.itertuples()
    }
    ordered_ids = ordered["node_id"].astype(int).tolist()
    result = []
    for first, second in zip(ordered_ids, ordered_ids[1:] + ordered_ids[:1]):
        length = float(np.linalg.norm(points[first] - points[second]))
        result.append((min(first, second), max(first, second), length))
    return result


def build_surface_grain_graph(
    elements: pd.DataFrame,
    nodes: pd.DataFrame,
    *,
    weight: str = "boundary_length_over_distance",
) -> SurfaceGrainGraph:
    """Build grain adjacency from top-surface element edges shared across parts."""
    surface = _surface_elements(elements)
    edge_owners: dict[tuple[int, int], list[tuple[int, float]]] = {}
    for row in surface.itertuples(index=False):
        series = pd.Series(row._asdict())
        for first, second, length in _top_face_edges(series, nodes):
            edge_owners.setdefault((first, second), []).append((int(series["part_id"]), length))

    boundary_lengths: dict[tuple[int, int], float] = {}
    for owners in edge_owners.values():
        parts = sorted({part for part, _ in owners})
        if len(parts) != 2:
            continue
        pair = (parts[0], parts[1])
        boundary_lengths[pair] = boundary_lengths.get(pair, 0.0) + float(
            np.mean([length for _, length in owners])
        )

    grouped = surface.groupby("part_id", sort=True)
    node_table = grouped.agg(
        center_x=("center_x", "mean"),
        center_y=("center_y", "mean"),
        surface_element_count=("element_id", "size"),
    ).reset_index()
    node_ids = node_table["part_id"].to_numpy(int)
    index = {part_id: position for position, part_id in enumerate(node_ids)}
    coordinates = node_table.set_index("part_id")[["center_x", "center_y"]]
    adjacency = np.zeros((len(node_ids), len(node_ids)), dtype=float)
    edge_rows = []
    for (first, second), boundary_length in sorted(boundary_lengths.items()):
        distance = float(
            np.linalg.norm(coordinates.loc[first].to_numpy() - coordinates.loc[second].to_numpy())
        )
        if weight == "binary":
            edge_weight = 1.0
        elif weight == "boundary_length":
            edge_weight = boundary_length
        elif weight == "boundary_length_over_distance":
            edge_weight = boundary_length / distance if distance > 0 else 0.0
        else:
            raise ValueError(f"Unknown graph weight: {weight}")
        i, j = index[first], index[second]
        adjacency[i, j] = adjacency[j, i] = edge_weight
        edge_rows.append(
            {
                "part_id_i": first,
                "part_id_j": second,
                "shared_boundary_length": boundary_length,
                "centroid_distance": distance,
                "weight": edge_weight,
            }
        )

    degree = adjacency.sum(axis=1)
    isolated = node_ids[degree <= 0]
    if len(isolated):
        raise ValueError(f"Surface graph contains isolated grains: {isolated.tolist()}")
    inverse_root = np.diag(1.0 / np.sqrt(degree))
    laplacian = np.eye(len(node_ids)) - inverse_root @ adjacency @ inverse_root
    eigenvalues, eigenvectors = np.linalg.eigh(laplacian)
    if np.count_nonzero(np.isclose(eigenvalues, 0.0, atol=1e-10)) != 1:
        raise ValueError("Surface graph must be connected for a unique constant mode.")
    node_table["weighted_degree"] = degree
    return SurfaceGrainGraph(
        node_ids=node_ids,
        node_table=node_table,
        edge_table=pd.DataFrame(edge_rows),
        adjacency=adjacency,
        laplacian=laplacian,
        eigenvalues=eigenvalues,
        eigenvectors=eigenvectors,
    )


def load_surface_graph(spatial_model_dir: Path | str, *, weight: str = "boundary_length_over_distance") -> SurfaceGrainGraph:
    model = Path(spatial_model_dir)
    return build_surface_grain_graph(
        pd.read_csv(model / "elements.csv"),
        pd.read_csv(model / "nodes.csv"),
        weight=weight,
    )


def _signed_node_height(case: CaseArtifacts, surface: pd.DataFrame) -> dict[int, float]:
    height = _read_height(case.height_path)
    design = np.column_stack(
        [height["x"].to_numpy(), height["y"].to_numpy(), np.ones(len(height))]
    )
    plane, *_ = np.linalg.lstsq(design, height["z"].to_numpy(), rcond=None)
    residual = height["z"].to_numpy() - design @ plane
    values = dict(zip(height["node_id"].astype(int), residual))
    return _restore_global_surface_node_ids(values, case.spatial_model_dir, surface)


def load_grain_signals(case: CaseArtifacts, graph: SurfaceGrainGraph) -> pd.DataFrame:
    """Aggregate signed height, orientation metrics, and slip activity by surface grain."""
    elements = pd.read_csv(case.spatial_model_dir / "elements.csv")
    surface = _surface_elements(elements)
    heights = _signed_node_height(case, surface)
    node_columns = [column for column in surface.columns if column.startswith("node_id_")]

    def element_height(row: pd.Series) -> float:
        values = [heights.get(int(row[column])) for column in node_columns]
        available = [value for value in values if value is not None]
        return float(np.mean(available)) if available else np.nan

    surface["signed_height"] = surface.apply(element_height, axis=1)
    grain_height = surface.groupby("part_id")["signed_height"].agg(
        height_mean="mean", height_std=lambda value: value.std(ddof=0), height_elements="count"
    )

    shear = pd.read_csv(case.shear_path)
    slip_columns = [column for column in shear.columns if "slip" in column.lower()]
    total_column = next(
        (
            column
            for column in shear.columns
            if column in {"accumulated_shear_strain", "accumulated_shear_strain_total"}
        ),
        None,
    )
    if total_column is None:
        raise ValueError(f"No total accumulated shear strain in {case.shear_path}")
    shear_columns = ["element_id", total_column, *slip_columns]
    surface_shear = surface[["element_id", "part_id"]].merge(
        shear[shear_columns], on="element_id", how="left", validate="one_to_one"
    )
    grain_shear = surface_shear.groupby("part_id")[total_column].agg(
        shear_mean="mean", shear_std=lambda value: value.std(ddof=0)
    )
    if slip_columns:
        slip_means = surface_shear.groupby("part_id")[slip_columns].mean().clip(lower=0)
        slip_total = slip_means.sum(axis=1)
        fractions = slip_means.div(slip_total.replace(0, np.nan), axis=0)
        grain_shear["slip_concentration"] = fractions.max(axis=1).fillna(0.0)
        grain_shear["effective_slip_systems"] = (
            1.0 / fractions.pow(2).sum(axis=1).replace(0, np.nan)
        ).fillna(0.0)

    orientation = pd.read_csv(case.orientation_path).rename(
        columns={"gos_deg": "gos", "grain_rotation_deg": "grain_rotation"}
    )
    orientation = orientation[["part_id", "gos", "grain_rotation"]].set_index("part_id")
    result = graph.node_table.set_index("part_id").join(grain_height).join(grain_shear).join(orientation)
    result = result.reindex(graph.node_ids)
    result.index.name = "part_id"
    return result.reset_index()


def spectral_summary(
    graph: SurfaceGrainGraph,
    signals: pd.DataFrame,
    columns: tuple[str, ...] = ("height_mean", "shear_mean", "grain_rotation", "gos"),
    *,
    cutoffs: tuple[float, float] = (1.0 / 3.0, 2.0 / 3.0),
) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Return per-mode coefficients and low/mid/high graph-frequency energies."""
    if not 0 < cutoffs[0] < cutoffs[1] < 1:
        raise ValueError("cutoffs must be increasing fractions between zero and one")
    maximum = float(graph.eigenvalues.max())
    boundaries = (maximum * cutoffs[0], maximum * cutoffs[1])
    bands = np.select(
        [graph.eigenvalues <= boundaries[0], graph.eigenvalues <= boundaries[1]],
        ["low", "mid"],
        default="high",
    )
    bands[0] = "dc"
    mode_rows = []
    energy_rows = []
    indexed = signals.set_index("part_id").reindex(graph.node_ids)
    for column in columns:
        values = indexed[column].to_numpy(float)
        if not np.isfinite(values).all():
            missing = indexed.index[~np.isfinite(values)].tolist()
            raise ValueError(f"Signal {column} is missing for surface grains {missing[:10]}")
        coefficients = graph.transform(values)
        energies = coefficients**2
        fluctuation_energy = energies.copy()
        fluctuation_energy[bands == "dc"] = 0.0
        total = float(fluctuation_energy.sum())
        for mode, (eigenvalue, coefficient, energy, band) in enumerate(
            zip(graph.eigenvalues, coefficients, energies, bands)
        ):
            mode_rows.append(
                {
                    "signal": column,
                    "mode": mode,
                    "eigenvalue": eigenvalue,
                    "band": band,
                    "coefficient": coefficient,
                    "energy": energy,
                }
            )
        for band in ("low", "mid", "high"):
            band_energy = float(fluctuation_energy[bands == band].sum())
            energy_rows.append(
                {
                    "signal": column,
                    "band": band,
                    "energy": band_energy,
                    "energy_fraction": band_energy / total if total else 0.0,
                }
            )
    return pd.DataFrame(mode_rows), pd.DataFrame(energy_rows)


def reconstruct_bands(
    graph: SurfaceGrainGraph,
    signal: np.ndarray,
    *,
    cutoffs: tuple[float, float] = (1.0 / 3.0, 2.0 / 3.0),
) -> Mapping[str, np.ndarray]:
    coefficients = graph.transform(signal)
    maximum = float(graph.eigenvalues.max())
    low = graph.eigenvalues <= maximum * cutoffs[0]
    mid = (graph.eigenvalues > maximum * cutoffs[0]) & (
        graph.eigenvalues <= maximum * cutoffs[1]
    )
    masks = {"low": low, "mid": mid, "high": ~(low | mid)}
    return {
        name: graph.inverse_transform(coefficients * mask)
        for name, mask in masks.items()
    }
