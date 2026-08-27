from __future__ import annotations

import csv
from functools import lru_cache
from pathlib import Path

import matplotlib.pyplot as plt
import matplotlib.tri as mtri
import numpy as np
from matplotlib.collections import PolyCollection
from matplotlib.colors import Normalize

from src.mapping.spatial_model_plot import _projected_polygons, load_spatial_model
from src.mapping.shear_strain_plot import read_shear_strain_data


def read_height(path: Path | str) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Read either raw x/y/z or edge-dropped node_id/x/y/z coordinates."""
    path = Path(path)
    with path.open(newline="", encoding="utf-8") as source:
        first = next(csv.reader(source), None)
    if not first:
        raise ValueError(f"Empty coordinate file: {path}")
    has_header = any(not _is_float(value) for value in first)
    values = np.loadtxt(path, delimiter=",", skiprows=int(has_header), ndmin=2)
    if values.shape[1] == 3:
        xyz = values
    elif values.shape[1] >= 4:
        xyz = values[:, 1:4]
    else:
        raise ValueError(f"Expected x/y/z or id/x/y/z columns: {path}")
    return xyz[:, 0], xyz[:, 1], xyz[:, 2]


def _is_float(value: str) -> bool:
    try:
        float(value)
    except ValueError:
        return False
    return True


def height_figure(
    path: Path | str,
    *,
    title: str,
    value_range: tuple[float, float],
    cmap: str = "coolwarm",
):
    x, y, z = read_height(path)
    triangulation = mtri.Triangulation(x, y)
    analyzer = mtri.TriAnalyzer(triangulation)
    triangulation.set_mask(analyzer.get_flat_tri_mask(min_circle_ratio=0.01))
    lower, upper = _nonzero_range(*value_range)
    levels = np.linspace(lower, upper, 31)
    figure, axis = plt.subplots(figsize=(5.2, 4.8), constrained_layout=True)
    contour = axis.tricontourf(
        triangulation, z, levels=levels, cmap=cmap, extend="both"
    )
    axis.set_aspect("equal", adjustable="box")
    axis.set_xlabel("x")
    axis.set_ylabel("y")
    axis.set_title(title)
    figure.colorbar(contour, ax=axis, label="Surface height z")
    return figure


def read_grain_metric(path: Path | str, metric: str) -> dict[int, float]:
    column = {"gos": "gos_deg", "rotation": "grain_rotation_deg"}[metric]
    with Path(path).open(newline="", encoding="utf-8") as source:
        reader = csv.DictReader(source)
        if not reader.fieldnames or not {"part_id", column}.issubset(reader.fieldnames):
            raise ValueError(f"Required columns part_id/{column} are missing: {path}")
        return {int(float(row["part_id"])): float(row[column]) for row in reader}


@lru_cache(maxsize=8)
def surface_polygons(
    spatial_model_dir: Path | str,
) -> tuple[np.ndarray, np.ndarray, list[np.ndarray]]:
    spatial_model_dir = Path(spatial_model_dir)
    element_ids, parts, centers, nodes = load_spatial_model(spatial_model_dir)
    selected = np.isclose(centers[:, 2], np.max(centers[:, 2]))
    return element_ids[selected], parts[selected], _projected_polygons(nodes[selected])


def orientation_figure(
    metrics_path: Path | str,
    spatial_model_dir: Path | str,
    *,
    metric: str,
    title: str,
    value_range: tuple[float, float] | None = None,
    cmap: str = "viridis",
):
    by_part = read_grain_metric(metrics_path, metric)
    _, parts, polygons = surface_polygons(spatial_model_dir)
    missing = sorted(set(map(int, parts)).difference(by_part))
    if missing:
        raise ValueError(f"Metrics are missing for {len(missing)} part(s).")
    values = np.array([by_part[int(part)] for part in parts])
    lower, upper = value_range or (float(np.nanmin(values)), float(np.nanmax(values)))
    lower, upper = _nonzero_range(lower, upper)
    norm = Normalize(vmin=lower, vmax=upper)

    figure, axis = plt.subplots(figsize=(5.2, 4.8), constrained_layout=True)
    collection = PolyCollection(
        polygons,
        array=values,
        cmap=cmap,
        norm=norm,
        edgecolors="none",
    )
    axis.add_collection(collection)
    axis.autoscale_view()
    axis.set_aspect("equal", adjustable="box")
    axis.set_xlabel("x")
    axis.set_ylabel("y")
    axis.set_title(title)
    figure.colorbar(collection, ax=axis, label="deg")
    return figure


def shear_figure(
    shear_path: Path | str,
    spatial_model_dir: Path | str,
    *,
    title: str,
    value_range: tuple[float, float] | None = None,
    cmap: str = "magma",
):
    value_ids, gamma_total, _ = read_shear_strain_data(shear_path)
    value_by_id = dict(zip(map(int, value_ids), gamma_total))
    surface_ids, _, polygons = surface_polygons(spatial_model_dir)
    missing = sorted(set(map(int, surface_ids)).difference(value_by_id))
    if missing:
        raise ValueError(f"Shear-strain data are missing for {len(missing)} surface element(s).")
    values = np.array([value_by_id[int(element_id)] for element_id in surface_ids])
    lower, upper = value_range or (float(np.nanmin(values)), float(np.nanmax(values)))
    lower, upper = _nonzero_range(lower, upper)
    norm = Normalize(vmin=lower, vmax=upper)

    figure, axis = plt.subplots(figsize=(5.2, 4.8), constrained_layout=True)
    collection = PolyCollection(
        polygons,
        array=values,
        cmap=cmap,
        norm=norm,
        edgecolors="none",
    )
    axis.add_collection(collection)
    axis.autoscale_view()
    axis.set_aspect("equal", adjustable="box")
    axis.set_xlabel("x")
    axis.set_ylabel("y")
    axis.set_title(title)
    figure.colorbar(collection, ax=axis, label=r"$\Gamma_{total}$")
    return figure


def _nonzero_range(lower: float, upper: float) -> tuple[float, float]:
    if np.isclose(lower, upper):
        upper = lower + max(abs(lower), 1.0) * 1.0e-12
    return lower, upper
