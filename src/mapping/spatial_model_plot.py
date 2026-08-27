from __future__ import annotations

import csv
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
from matplotlib.collections import PolyCollection
from matplotlib.colors import hsv_to_rgb


def _read_numeric_csv(path: Path) -> tuple[list[str], np.ndarray]:
    with path.open(newline="", encoding="utf-8") as source:
        reader = csv.reader(source)
        header = next(reader)
    data = np.loadtxt(path, delimiter=",", skiprows=1, ndmin=2)
    return header, data


def load_spatial_model(
    spatial_model_dir: Path | str,
) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    """Load node positions and element geometry from a spatial-model directory."""
    spatial_model_dir = Path(spatial_model_dir)
    node_header, node_data = _read_numeric_csv(spatial_model_dir / "nodes.csv")
    element_header, element_data = _read_numeric_csv(
        spatial_model_dir / "elements.csv"
    )

    required_node_columns = ["node_id", "x", "y", "z"]
    required_element_columns = [
        "element_id", "part_id", "center_x", "center_y", "center_z"
    ]
    if node_header[:4] != required_node_columns:
        raise ValueError(f"Unexpected nodes.csv columns: {node_header}")
    if element_header[:5] != required_element_columns:
        raise ValueError(f"Unexpected elements.csv columns: {element_header}")

    node_ids = node_data[:, 0].astype(int)
    node_coordinates = node_data[:, 1:4]
    element_ids = element_data[:, 0].astype(int)
    part_ids = element_data[:, 1].astype(int)
    element_centers = element_data[:, 2:5]
    connectivity = element_data[:, 5:].astype(int)

    node_index = {int(node_id): index for index, node_id in enumerate(node_ids)}
    try:
        element_node_indices = np.array(
            [[node_index[int(node_id)] for node_id in row] for row in connectivity],
            dtype=int,
        )
    except KeyError as error:
        raise ValueError(
            f"elements.csv refers to missing node ID {error.args[0]}."
        ) from error

    return element_ids, part_ids, element_centers, node_coordinates[element_node_indices]


def _projected_polygons(element_nodes: np.ndarray) -> list[np.ndarray]:
    polygons: list[np.ndarray] = []
    for nodes in element_nodes:
        points = np.unique(nodes[:, :2], axis=0)
        center = points.mean(axis=0)
        angles = np.arctan2(points[:, 1] - center[1], points[:, 0] - center[0])
        polygons.append(points[np.argsort(angles)])
    return polygons


def _part_colors(part_ids: np.ndarray) -> np.ndarray:
    """Return stable categorical colors without implying a numeric part scale."""
    hue = np.mod(part_ids.astype(float) * 0.618033988749895, 1.0)
    saturation = np.full(len(part_ids), 0.62)
    value = 0.72 + 0.18 * np.mod(part_ids, 3) / 2
    return hsv_to_rgb(np.column_stack((hue, saturation, value)))


def _draw_layer(
    axis,
    element_nodes: np.ndarray,
    part_ids: np.ndarray,
    *,
    z_center: float,
    element_count: int,
) -> None:
    collection = PolyCollection(
        _projected_polygons(element_nodes),
        facecolors=_part_colors(part_ids),
        edgecolors="none",
        linewidths=0,
        antialiaseds=False,
    )
    axis.add_collection(collection)
    axis.autoscale_view()
    axis.set_aspect("equal", adjustable="box")
    axis.set_title(f"z center = {z_center:g}  |  {element_count:,} elements", fontsize=10)
    axis.set_xlabel("x")
    axis.set_ylabel("y")
    axis.tick_params(labelsize=8)


def plot_spatial_model_layers(
    spatial_model_dir: Path | str,
    output_dir: Path | str,
    *,
    dpi: int = 200,
    overwrite: bool = False,
    all_layers: bool = False,
) -> list[Path]:
    """Render the upper-surface part map, optionally including every layer."""
    _, part_ids, element_centers, element_nodes = load_spatial_model(
        spatial_model_dir
    )
    all_z_centers = np.unique(element_centers[:, 2])
    z_centers = all_z_centers if all_layers else all_z_centers[-1:]
    output_dir = Path(output_dir)
    if all_layers:
        layer_paths = [
            output_dir / f"layer_{index + 1:02d}_z_{z_center:g}.png"
            for index, z_center in enumerate(z_centers)
        ]
        overview_path = output_dir / "layers_overview.png"
        all_paths = [*layer_paths, overview_path]
    else:
        layer_paths = [output_dir / f"surface_z_{z_centers[0]:g}.png"]
        overview_path = None
        all_paths = layer_paths

    existing = [path for path in all_paths if path.exists()]
    if existing and not overwrite:
        details = "\n".join(f" - {path}" for path in existing)
        raise FileExistsError(
            "Layer-map output already exists. Use overwrite=True only when "
            f"replacement is intentional.\n{details}"
        )
    output_dir.mkdir(parents=True, exist_ok=True)

    selections = [np.isclose(element_centers[:, 2], z) for z in z_centers]
    for z_center, selected, path in zip(z_centers, selections, layer_paths):
        figure, axis = plt.subplots(figsize=(7.2, 7.2), constrained_layout=True)
        _draw_layer(
            axis,
            element_nodes[selected],
            part_ids[selected],
            z_center=float(z_center),
            element_count=int(selected.sum()),
        )
        figure.suptitle("Part map by element geometry", fontsize=13)
        figure.savefig(path, dpi=dpi, facecolor="white")
        plt.close(figure)

    if all_layers:
        columns = 2
        rows = int(np.ceil(len(z_centers) / columns))
        figure, axes = plt.subplots(
            rows,
            columns,
            figsize=(12, 5.8 * rows),
            constrained_layout=True,
            squeeze=False,
        )
        for axis, z_center, selected in zip(axes.flat, z_centers, selections):
            _draw_layer(
                axis,
                element_nodes[selected],
                part_ids[selected],
                z_center=float(z_center),
                element_count=int(selected.sum()),
            )
        for axis in axes.flat[len(z_centers) :]:
            axis.set_visible(False)
        figure.suptitle(
            "Square plate reconstructed by z layer — color identifies part",
            fontsize=14,
        )
        figure.savefig(overview_path, dpi=dpi, facecolor="white")
        plt.close(figure)
    return all_paths
