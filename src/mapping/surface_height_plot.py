from __future__ import annotations

import csv
from pathlib import Path

import matplotlib.pyplot as plt
import matplotlib.tri as mtri
import numpy as np
from matplotlib.ticker import MultipleLocator

from src.mapping.plot_style import (
    HEIGHT_AXIS_TICK_INTERVAL,
    HEIGHT_RANGE,
    HEIGHT_SCALE,
)


def read_surface_coordinates(path: Path | str) -> np.ndarray:
    """Read an LS-PrePost surface-coordinate CSV as an ``(n, 3)`` array."""
    path = Path(path)
    with path.open(newline="", encoding="utf-8") as source:
        first_row = next(csv.reader(source), None)
    if first_row is None:
        raise ValueError(f"Coordinate CSV is empty: {path}")

    has_header = any(not _is_float(value) for value in first_row[:3])
    coordinates = np.loadtxt(
        path, delimiter=",", skiprows=1 if has_header else 0, ndmin=2
    )
    if coordinates.shape[1] < 3:
        raise ValueError(
            f"Coordinate CSV must contain at least three columns (x, y, z): {path}"
        )
    coordinates = coordinates[:, :3]
    if len(coordinates) < 3:
        raise ValueError(f"At least three coordinate rows are required: {path}")
    if not np.isfinite(coordinates).all():
        raise ValueError(f"Coordinate CSV contains non-finite values: {path}")
    return coordinates


def _is_float(value: str) -> bool:
    try:
        float(value)
    except ValueError:
        return False
    return True


def plot_surface_height_contour(
    coordinates_csv: Path | str,
    output_path: Path | str,
    *,
    levels: int = 30,
    cmap: str = "coolwarm",
    dpi: int = 200,
    overwrite: bool = False,
    value_range: tuple[float, float] = HEIGHT_RANGE,
) -> Path:
    """Plot the deformed surface height z over its current x-y coordinates."""
    if levels < 2:
        raise ValueError("levels must be at least 2")
    output_path = Path(output_path)
    if output_path.exists() and not overwrite:
        raise FileExistsError(f"Output exists; use --overwrite: {output_path}")

    coordinates_csv = Path(coordinates_csv)
    coordinates = read_surface_coordinates(coordinates_csv)
    x, y, z = coordinates.T
    z = z * HEIGHT_SCALE
    lower, upper = value_range
    if not np.isfinite([lower, upper]).all() or lower > upper:
        raise ValueError("value_range must contain finite values in increasing order")
    if np.isclose(lower, upper):
        upper = lower + max(abs(lower), 1.0) * 1.0e-12

    triangulation = mtri.Triangulation(x, y)
    # Long, thin boundary triangles can bridge across a strongly deformed edge.
    analyzer = mtri.TriAnalyzer(triangulation)
    triangulation.set_mask(analyzer.get_flat_tri_mask(min_circle_ratio=0.01))
    boundaries = np.linspace(lower, upper, levels + 1)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    figure, axis = plt.subplots(figsize=(7.2, 7.2), constrained_layout=True)
    contour = axis.tricontourf(
        triangulation, z, levels=boundaries, cmap=cmap, extend="both"
    )
    axis.set_aspect("equal", adjustable="box")
    axis.set_xlabel("x")
    axis.set_ylabel("y")
    axis.xaxis.set_major_locator(MultipleLocator(HEIGHT_AXIS_TICK_INTERVAL))
    axis.yaxis.set_major_locator(MultipleLocator(HEIGHT_AXIS_TICK_INTERVAL))
    axis.set_title(f"Deformed surface height | {coordinates_csv.stem}")
    figure.colorbar(contour, ax=axis, label=r"$z$ ($\times 10^{-3}$)")
    figure.savefig(output_path, dpi=dpi, facecolor="white")
    plt.close(figure)
    return output_path
