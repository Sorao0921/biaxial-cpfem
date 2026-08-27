from __future__ import annotations

import csv
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
from matplotlib.collections import LineCollection, PolyCollection
from matplotlib.colors import BoundaryNorm, Normalize

from src.mapping.spatial_model_plot import _projected_polygons, load_spatial_model


TOTAL_COLUMN = "accumulated_shear_strain_total"
SLIP_COLUMNS = tuple(
    f"accumulated_shear_strain_slip{index:02d}" for index in range(1, 13)
)
METRICS = ("gamma_total", "gamma_max", "alpha", "c_slip")


def _derive_metrics(
    gamma_total: np.ndarray,
    slips: np.ndarray,
    *,
    activity_threshold: float = 0.0,
) -> dict[str, np.ndarray]:
    gamma_total = gamma_total.astype(float, copy=True)
    gamma_max = np.max(slips, axis=1).astype(float, copy=True)
    active = gamma_total > activity_threshold
    gamma_total[~active] = np.nan
    gamma_max[~active] = np.nan
    alpha = np.full(len(gamma_total), np.nan)
    alpha[active] = np.argmax(slips[active], axis=1) + 1
    c_slip = np.full(len(gamma_total), np.nan)
    np.divide(gamma_max, gamma_total, out=c_slip, where=active)
    return {
        "gamma_total": gamma_total,
        "gamma_max": gamma_max,
        "alpha": alpha,
        "c_slip": c_slip,
    }


def read_shear_strain_data(
    path: Path | str,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Read element IDs, total strain, and the 12 slip-system strains."""
    path = Path(path)
    with path.open(newline="", encoding="utf-8") as source:
        reader = csv.DictReader(source)
        required = {"element_id", TOTAL_COLUMN, *SLIP_COLUMNS}
        missing = required.difference(reader.fieldnames or [])
        if missing:
            raise ValueError(f"Missing shear-strain columns: {sorted(missing)}")
        rows = list(reader)
    if not rows:
        raise ValueError(f"Shear-strain CSV is empty: {path}")

    element_ids = np.array([int(float(row["element_id"])) for row in rows])
    if len(np.unique(element_ids)) != len(element_ids):
        raise ValueError("Shear-strain CSV contains duplicate element_id values.")
    gamma_total = np.array([float(row[TOTAL_COLUMN]) for row in rows])
    slips = np.array(
        [[float(row[column]) for column in SLIP_COLUMNS] for row in rows]
    )
    if np.any(gamma_total < 0) or np.any(slips < 0):
        raise ValueError("Accumulated shear strains must not be negative.")

    return element_ids, gamma_total, slips


def read_shear_strain_metrics(
    path: Path | str,
    *,
    activity_threshold: float = 0.0,
) -> tuple[np.ndarray, dict[str, np.ndarray]]:
    element_ids, gamma_total, slips = read_shear_strain_data(path)
    return element_ids, _derive_metrics(
        gamma_total, slips, activity_threshold=activity_threshold
    )


def _polygon_areas(polygons: list[np.ndarray]) -> np.ndarray:
    areas = []
    for polygon in polygons:
        x, y = polygon[:, 0], polygon[:, 1]
        areas.append(0.5 * abs(np.dot(x, np.roll(y, 1)) - np.dot(y, np.roll(x, 1))))
    return np.asarray(areas)


def _grain_boundary_segments(
    polygons: list[np.ndarray], part_ids: np.ndarray
) -> list[np.ndarray]:
    edges: dict[tuple[tuple[float, float], tuple[float, float]], list[tuple[int, np.ndarray]]] = {}
    for part_id, polygon in zip(part_ids, polygons):
        for first, second in zip(polygon, np.roll(polygon, -1, axis=0)):
            key_points = sorted((tuple(np.round(first, 12)), tuple(np.round(second, 12))))
            key = (key_points[0], key_points[1])
            edges.setdefault(key, []).append((int(part_id), np.vstack((first, second))))
    return [
        entries[0][1]
        for entries in edges.values()
        if len(entries) == 1 or len({entry[0] for entry in entries}) > 1
    ]


def _grain_mapped_metrics(
    part_ids: np.ndarray,
    polygons: list[np.ndarray],
    slips: np.ndarray,
    *,
    activity_threshold: float,
) -> dict[str, np.ndarray]:
    areas = _polygon_areas(polygons)
    unique_parts, inverse = np.unique(part_ids, return_inverse=True)
    grain_slips = np.empty((len(unique_parts), slips.shape[1]))
    for grain_index in range(len(unique_parts)):
        selected = inverse == grain_index
        weights = areas[selected]
        grain_slips[grain_index] = np.average(slips[selected], axis=0, weights=weights)
    # Derive the grain total from the already aggregated slip systems.  This
    # preserves the required order: aggregate first, then calculate metrics.
    grain_total = grain_slips.sum(axis=1)
    grain_metrics = _derive_metrics(
        grain_total, grain_slips, activity_threshold=activity_threshold
    )
    return {name: values[inverse] for name, values in grain_metrics.items()}


def plot_shear_strain_layers(
    spatial_model_dir: Path | str,
    shear_strain_csv: Path | str,
    output_dir: Path | str,
    *,
    metric: str = "gamma_total",
    aggregation: str = "element",
    activity_threshold: float = 0.0,
    all_layers: bool = False,
    dpi: int = 200,
    overwrite: bool = False,
) -> list[Path]:
    """Map element-level accumulated-shear-strain metrics onto the mesh."""
    if metric not in METRICS:
        raise ValueError(f"metric must be one of: {', '.join(METRICS)}")
    if aggregation not in {"element", "grain"}:
        raise ValueError("aggregation must be one of: element, grain")
    if activity_threshold < 0:
        raise ValueError("activity_threshold must not be negative")
    spatial_ids, part_ids, centers, nodes = load_spatial_model(spatial_model_dir)
    value_ids, gamma_total, slips = read_shear_strain_data(shear_strain_csv)
    row_by_id = {element_id: index for index, element_id in enumerate(value_ids)}
    missing = sorted(set(spatial_ids).difference(row_by_id))
    if missing:
        preview = ", ".join(map(str, missing[:10]))
        raise ValueError(
            f"Shear-strain data are missing for {len(missing)} spatial element(s): {preview}."
        )
    value_rows = np.array([row_by_id[element_id] for element_id in spatial_ids])
    gamma_total = gamma_total[value_rows]
    slips = slips[value_rows]
    element_metrics = _derive_metrics(
        gamma_total, slips, activity_threshold=activity_threshold
    )

    all_z_centers = np.unique(centers[:, 2])
    z_centers = all_z_centers if all_layers else all_z_centers[-1:]
    output_dir = Path(output_dir)
    suffixes = (
        [f"layer_{index + 1:02d}_z_{z:g}" for index, z in enumerate(z_centers)]
        if all_layers
        else [f"surface_z_{z_centers[0]:g}"]
    )
    paths = [output_dir / f"{metric}_{aggregation}_{suffix}.png" for suffix in suffixes]
    existing = [path for path in paths if path.exists()]
    if existing and not overwrite:
        raise FileExistsError(f"Output exists; use --overwrite: {existing[0]}")
    output_dir.mkdir(parents=True, exist_ok=True)

    layer_values = []
    layer_polygons = []
    layer_boundaries = []
    for z in z_centers:
        selected = np.isclose(centers[:, 2], z)
        polygons = _projected_polygons(nodes[selected])
        if aggregation == "grain":
            values = _grain_mapped_metrics(
                part_ids[selected], polygons, slips[selected],
                activity_threshold=activity_threshold,
            )[metric]
        else:
            values = element_metrics[metric][selected]
        layer_values.append(values)
        layer_polygons.append(polygons)
        layer_boundaries.append(_grain_boundary_segments(polygons, part_ids[selected]))
    mapped = np.concatenate(layer_values)
    finite = mapped[np.isfinite(mapped)]

    if metric == "alpha":
        cmap = plt.get_cmap("tab20", 12).copy()
        norm = BoundaryNorm(np.arange(0.5, 13.5), cmap.N)
        colorbar_ticks = np.arange(1, 13)
    else:
        if len(finite):
            lower, upper = float(finite.min()), float(finite.max())
            if np.isclose(lower, upper):
                upper = lower + max(abs(lower), 1.0) * 1.0e-12
        else:
            # Keep an all-NaN state (typically state01) plottable.  The
            # normalization is immaterial because every polygon uses bad color.
            lower, upper = 0.0, 1.0
        cmap = plt.get_cmap("viridis").copy()
        norm = Normalize(vmin=lower, vmax=upper)
        colorbar_ticks = None
    cmap.set_bad(color="white")

    labels = {
        "gamma_total": r"$\Gamma_{total}$",
        "gamma_max": r"$\Gamma_{max}$",
        "alpha": r"$\alpha$ (slip-system number)",
        "c_slip": r"$C_{slip}$",
    }
    for path, z, values, polygons, boundaries in zip(
        paths, z_centers, layer_values, layer_polygons, layer_boundaries
    ):
        figure, axis = plt.subplots(figsize=(7.2, 7.2), constrained_layout=True)
        collection = PolyCollection(
            polygons,
            array=np.ma.masked_invalid(values),
            cmap=cmap,
            norm=norm,
            edgecolors="none",
        )
        axis.add_collection(collection)
        axis.add_collection(
            LineCollection(boundaries, colors="black", linewidths=0.25, alpha=0.65)
        )
        axis.autoscale_view()
        axis.set_aspect("equal", adjustable="box")
        axis.set_xlabel("x")
        axis.set_ylabel("y")
        axis.set_title(f"{labels[metric]} ({aggregation}) | z center = {z:g}")
        figure.colorbar(collection, ax=axis, label=labels[metric], ticks=colorbar_ticks)
        figure.savefig(path, dpi=dpi, facecolor="white")
        plt.close(figure)
    return paths
