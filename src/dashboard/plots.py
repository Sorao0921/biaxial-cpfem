from __future__ import annotations

import csv
from functools import lru_cache
from pathlib import Path

import matplotlib.pyplot as plt

from src.dashboard.style import apply_figure_style
import matplotlib.tri as mtri
import numpy as np
from matplotlib.collections import LineCollection, PolyCollection
from matplotlib.colors import Normalize
from matplotlib.ticker import MultipleLocator

from src.mapping.plot_style import HEIGHT_AXIS_TICK_INTERVAL, HEIGHT_SCALE
from src.mapping.spatial_model_plot import _projected_polygons, load_spatial_model

TOTAL_SHEAR_COLUMN = "accumulated_shear_strain_total"
SLIP_COLUMNS = tuple(
    f"accumulated_shear_strain_slip{index:02d}" for index in range(1, 13)
)


def read_shear_strain_data(
    path: Path | str,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Read element IDs, total strain, and the 12 slip-system strains."""
    path = Path(path)
    with path.open(newline="", encoding="utf-8") as source:
        reader = csv.DictReader(source)
        required = {"element_id", TOTAL_SHEAR_COLUMN, *SLIP_COLUMNS}
        missing = required.difference(reader.fieldnames or [])
        if missing:
            raise ValueError(f"Missing shear-strain columns: {sorted(missing)}")
        rows = list(reader)
    if not rows:
        raise ValueError(f"Shear-strain CSV is empty: {path}")

    element_ids = np.array([int(float(row["element_id"])) for row in rows])
    if len(np.unique(element_ids)) != len(element_ids):
        raise ValueError("Shear-strain CSV contains duplicate element_id values.")
    gamma_total = np.array([float(row[TOTAL_SHEAR_COLUMN]) for row in rows])
    slips = np.array(
        [[float(row[column]) for column in SLIP_COLUMNS] for row in rows]
    )
    if np.any(gamma_total < 0) or np.any(slips < 0):
        raise ValueError("Accumulated shear strains must not be negative.")
    return element_ids, gamma_total, slips


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


@lru_cache(maxsize=8)
def surface_topology(spatial_model_dir: Path | str):
    """Top-face connectivity in the coordinate export's 1-based surface order.

    EdgeDropper IDs are row numbers, not global mesh node IDs. The surface
    export follows ascending global node ID (x fastest on the plate mesh).
    """
    root = Path(spatial_model_dir)
    nodes = np.loadtxt(root / "nodes.csv", delimiter=",", skiprows=1, ndmin=2)
    elements = np.loadtxt(root / "elements.csv", delimiter=",", skiprows=1, ndmin=2)
    top = nodes[np.isclose(nodes[:, 3], nodes[:, 3].max())]
    top = top[np.argsort(top[:, 0])]
    indices = {int(row[0]): i + 1 for i, row in enumerate(top)}
    faces, ids, parts = [], [], []
    for element in elements:
        face = list(dict.fromkeys(indices[int(n)] for n in element[5:] if int(n) in indices))
        if len(face) < 3:
            continue
        xy = top[np.array(face) - 1, 1:3]
        center = xy.mean(axis=0)
        order = np.argsort(np.arctan2(xy[:, 1] - center[1], xy[:, 0] - center[0]))
        faces.append(np.array(face)[order])
        ids.append(int(element[0]))
        parts.append(int(element[1]))
    edge_parts: dict[tuple[int, int], set[int]] = {}
    for face, part in zip(faces, parts):
        for a, b in zip(face, np.roll(face, -1)):
            edge_parts.setdefault(tuple(sorted((int(a), int(b)))), set()).add(part)
    boundaries = [edge for edge, owners in edge_parts.items() if len(owners) > 1]
    return np.array(ids), np.array(parts), faces, boundaries, len(top)


def deformed_surface(spatial_model_dir: Path | str, coordinates_path: Path | str,
                     *, reference_geometry: bool = False):
    """Reconstruct visible faces and grain edges from current surface positions."""
    ids, parts, faces, boundaries, count = surface_topology(spatial_model_dir)
    path = Path(coordinates_path)
    with path.open(newline="", encoding="utf-8") as source:
        first = next(csv.reader(source))
    header = any(not _is_float(value) for value in first)
    data = np.loadtxt(path, delimiter=",", skiprows=int(header), ndmin=2)
    if data.shape[1] == 3:
        if len(data) != count:
            raise ValueError(f"Expected {count} surface coordinate rows, got {len(data)}.")
        node_ids, xyz = np.arange(1, count + 1), data
    elif data.shape[1] == 4:
        node_ids, xyz = data[:, 0], data[:, 1:4]
    else:
        raise ValueError("Expected x/y/z or surface-row-id/x/y/z coordinates.")
    if (not np.isfinite(data).all() or np.any(node_ids != node_ids.astype(int))
            or len(np.unique(node_ids)) != len(node_ids)
            or np.any(node_ids < 1) or np.any(node_ids > count)):
        raise ValueError("Invalid or duplicate surface node IDs/coordinates.")
    if reference_geometry:
        # Use only the exported node selection; coordinates stay undeformed.
        nodes = np.loadtxt(Path(spatial_model_dir)/"nodes.csv", delimiter=",", skiprows=1, ndmin=2)
        top = nodes[np.isclose(nodes[:,3], nodes[:,3].max())]
        top = top[np.argsort(top[:,0])]
        xyz = top[node_ids.astype(int)-1,1:4]
    positions = {int(n): point[:2] for n, point in zip(node_ids, xyz)}
    selected = [i for i, face in enumerate(faces) if all(int(n) in positions for n in face)]
    if not selected:
        raise ValueError("Coordinates contain no complete surface elements.")
    polygons = [np.array([positions[int(n)] for n in faces[i]]) for i in selected]
    segments = [np.array([positions[a], positions[b]]) for a, b in boundaries
                if a in positions and b in positions]
    return ids[selected], parts[selected], polygons, segments


def _draw_boundaries(axis, segments):
    axis.add_collection(LineCollection(segments, colors="black", linewidths=0.55))


def height_figure(
    path: Path | str,
    *,
    title: str,
    value_range: tuple[float, float],
    cmap: str = "coolwarm",
    spatial_model_dir: Path | str | None = None,
):
    x, y, z = read_height(path)
    z = z * HEIGHT_SCALE
    triangulation = mtri.Triangulation(x, y)
    analyzer = mtri.TriAnalyzer(triangulation)
    triangulation.set_mask(analyzer.get_flat_tri_mask(min_circle_ratio=0.01))
    lower, upper = _nonzero_range(*value_range)
    levels = np.linspace(lower, upper, 31)
    figure, axis = plt.subplots(figsize=(5.2, 4.8), constrained_layout=True)
    contour = axis.tricontourf(
        triangulation, z, levels=levels, cmap=cmap, extend="both"
    )
    if spatial_model_dir is not None:
        *_, segments = deformed_surface(spatial_model_dir, path)
        _draw_boundaries(axis, segments)
    axis.set_aspect("equal", adjustable="box")
    axis.set_xlabel("x")
    axis.set_ylabel("y")
    axis.xaxis.set_major_locator(MultipleLocator(HEIGHT_AXIS_TICK_INTERVAL))
    axis.yaxis.set_major_locator(MultipleLocator(HEIGHT_AXIS_TICK_INTERVAL))
    axis.set_title(title)
    figure.colorbar(contour, ax=axis, label=r"Surface height $z$ ($\times 10^{-3}$)")
    return apply_figure_style(figure)


def read_grain_metric(path: Path | str, metric: str) -> dict[int, float]:
    column = {"gos": "gos_deg", "rotation": "grain_rotation_deg", "taylor": "taylor_factor"}[metric]
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
    coordinates_path: Path | str | None = None,
):
    by_part = read_grain_metric(metrics_path, metric)
    segments = []
    if coordinates_path is None:
        _, parts, polygons = surface_polygons(spatial_model_dir)
    else:
        _, parts, polygons, segments = deformed_surface(spatial_model_dir, coordinates_path)
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
        antialiaseds=False,
    )
    axis.add_collection(collection)
    _draw_boundaries(axis, segments)
    axis.autoscale_view()
    axis.margins(0)
    axis.xaxis.set_major_locator(MultipleLocator(HEIGHT_AXIS_TICK_INTERVAL))
    axis.yaxis.set_major_locator(MultipleLocator(HEIGHT_AXIS_TICK_INTERVAL))
    axis.set_aspect("equal", adjustable="box")
    axis.set_xlabel("x")
    axis.set_ylabel("y")
    axis.set_title(title)
    figure.colorbar(collection, ax=axis, label="M" if metric == "taylor" else "deg")
    return apply_figure_style(figure)


def grain_slip_concentration(parts, slips):
    """Max grain-mean slip / sum of 12 grain-mean slips, on supplied elements.

    Averaging precedes the ratio. All-zero slip is assigned zero, consistent
    with the Theme 1 implementation. Returns one value per input element.
    """
    parts = np.asarray(parts)
    slips = np.asarray(slips, dtype=float)
    if slips.shape != (len(parts), 12) or not len(parts):
        raise ValueError("Expected 12 slip-system values per element")
    if not np.isfinite(slips).all() or np.any(slips < 0):
        raise ValueError("Slip values must be finite and non-negative")
    _, inverse = np.unique(parts, return_inverse=True)
    sums = np.zeros((int(inverse.max()) + 1, 12))
    np.add.at(sums, inverse, slips)
    # Element counts cancel in the ratio of grain means.
    totals = sums.sum(axis=1)
    ratios = np.divide(sums.max(axis=1), totals,
                       out=np.zeros_like(totals), where=totals > 0)
    return ratios[inverse]


def shear_figure(
    shear_path: Path | str,
    spatial_model_dir: Path | str,
    *,
    title: str,
    value_range: tuple[float, float] | None = None,
    cmap: str = "magma",
    coordinates_path: Path | str | None = None,
    metric: str = "total",
):
    value_ids, gamma_total, slips = read_shear_strain_data(shear_path)
    value_by_id = dict(zip(map(int, value_ids), gamma_total))
    segments = []
    if coordinates_path is None:
        surface_ids, parts, polygons = surface_polygons(spatial_model_dir)
    else:
        surface_ids, parts, polygons, segments = deformed_surface(spatial_model_dir, coordinates_path)
    missing = sorted(set(map(int, surface_ids)).difference(value_by_id))
    if missing:
        raise ValueError(f"Shear-strain data are missing for {len(missing)} surface element(s).")
    values = np.array([value_by_id[int(element_id)] for element_id in surface_ids])
    if metric == "concentration":
        index_by_id = {int(eid): i for i, eid in enumerate(value_ids)}
        selected_slips = slips[[index_by_id[int(eid)] for eid in surface_ids]]
        values = grain_slip_concentration(parts, selected_slips)
        value_range = (0., 1.) if value_range is None else value_range
    elif metric != "total":
        raise ValueError(f"Unknown shear metric: {metric}")
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
        antialiaseds=False,
    )
    axis.add_collection(collection)
    _draw_boundaries(axis, segments)
    axis.autoscale_view()
    axis.margins(0)
    axis.xaxis.set_major_locator(MultipleLocator(HEIGHT_AXIS_TICK_INTERVAL))
    axis.yaxis.set_major_locator(MultipleLocator(HEIGHT_AXIS_TICK_INTERVAL))
    axis.set_aspect("equal", adjustable="box")
    axis.set_xlabel("x")
    axis.set_ylabel("y")
    axis.set_title(title)
    figure.colorbar(collection, ax=axis, label="Slip concentration" if metric == "concentration" else r"$\Gamma_{total}$")
    return apply_figure_style(figure)


def _nonzero_range(lower: float, upper: float) -> tuple[float, float]:
    if np.isclose(lower, upper):
        upper = lower + max(abs(lower), 1.0) * 1.0e-12
    return lower, upper


INITIAL_METRICS = {
    "axis_angle": (None, "Initial axis + angle (state01)", "deg", (0., 65.)),
    "angle": (None, "Initial reference angle (state01)", "deg", (0., 65.)),
    "ipf_nd": (None, "Initial ND IPF (state01)", "", (0., 1.)),
    "taylor": ("taylor_factor", "Initial Taylor factor", "M", (1.5, 4.5)),
    "phi1": ("phi1_rad", "Initial orientation: phi1 (state01)", "deg", (0., 360.)),
    "Phi": ("Phi_rad", "Initial orientation: Phi (state01)", "deg", (0., 180.)),
    "phi2": ("phi2_rad", "Initial orientation: phi2 (state01)", "deg", (0., 360.)),
}


def initial_figure(metrics_path, spatial_model_dir, *, metric="taylor", title=None,
                   max_angle=65., exponent=.35, value_range=None, selection_coordinates_path=None):
    """Initial values and positions; optionally match visible node IDs of a current export."""
    if metric in {"axis_angle", "angle", "ipf_nd"}:
        from src.dashboard.initial_orientation import orientation_color_figure
        return orientation_color_figure(metrics_path, spatial_model_dir, metric=metric,
                                        title=title, max_angle=max_angle, exponent=exponent)
    column, default_title, unit, limits = INITIAL_METRICS[metric]
    limits = value_range if value_range is not None else limits
    with Path(metrics_path).open(newline="", encoding="utf-8") as source:
        rows = list(csv.DictReader(source))
    by_part = {}
    for row in rows:
        if int(row["state"]) != 1:
            raise ValueError("Initial maps require state01 data")
        part = int(row["part_id"])
        if part in by_part:
            raise ValueError("Duplicate initial part_id")
        value = float(row[column])
        if not np.isfinite(value):
            raise ValueError("Non-finite initial value")
        by_part[part] = value if metric == "taylor" else np.rad2deg(value)
    if selection_coordinates_path is not None:
        _, parts, polygons, segments = deformed_surface(
            spatial_model_dir, selection_coordinates_path, reference_geometry=True)
    else:
        _, parts, faces, boundaries, _ = surface_topology(spatial_model_dir)
        nodes = np.loadtxt(Path(spatial_model_dir)/"nodes.csv", delimiter=",", skiprows=1, ndmin=2)
        top = nodes[np.isclose(nodes[:,3], nodes[:,3].max())]
        top = top[np.argsort(top[:,0])]
        polygons = [top[np.asarray(face)-1,1:3] for face in faces]
        segments = [top[np.array(edge)-1,1:3] for edge in boundaries]
    missing = set(map(int,parts)) - by_part.keys()
    if missing:
        raise ValueError(f"Initial metrics missing for {len(missing)} surface parts")
    values = np.array([by_part[int(part)] for part in parts])
    figure, axis = plt.subplots(figsize=(5.2,4.8), constrained_layout=True)
    collection = PolyCollection(polygons, array=values, cmap="viridis",
                                norm=Normalize(*limits), edgecolors="none", antialiaseds=False)
    axis.add_collection(collection)
    _draw_boundaries(axis, segments)
    axis.autoscale_view(); axis.margins(0); axis.set_aspect("equal", adjustable="box")
    axis.set(xlabel="x", ylabel="y", title=title or default_title)
    axis.xaxis.set_major_locator(MultipleLocator(HEIGHT_AXIS_TICK_INTERVAL))
    axis.yaxis.set_major_locator(MultipleLocator(HEIGHT_AXIS_TICK_INTERVAL))
    figure.colorbar(collection, ax=axis, label=unit)
    return apply_figure_style(figure)
