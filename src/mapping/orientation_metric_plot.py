from __future__ import annotations

import csv
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
from matplotlib.collections import PolyCollection
from matplotlib.colors import Normalize

from src.mapping.plot_style import GOS_RANGE, GRAIN_ROTATION_RANGE
from src.mapping.spatial_model_plot import _projected_polygons, load_spatial_model


def _read_grain_metrics(path: Path) -> tuple[np.ndarray, dict[str, np.ndarray]]:
    with path.open(newline="", encoding="utf-8") as source:
        reader = csv.DictReader(source)
        required = {"part_id", "grain_rotation_deg", "gos_deg", "ipf_nd_r", "ipf_nd_g", "ipf_nd_b"}
        missing = required.difference(reader.fieldnames or [])
        if missing:
            raise ValueError(f"Missing grain-metric columns: {sorted(missing)}")
        rows = list(reader)
    if not rows:
        raise ValueError(f"Grain metric CSV is empty: {path}")
    part_ids = np.array([int(float(row["part_id"])) for row in rows])
    if len(np.unique(part_ids)) != len(part_ids):
        raise ValueError("Grain metric CSV contains duplicate part_id values.")
    values = {
        "rotation": np.array([float(row["grain_rotation_deg"]) for row in rows]),
        "gos": np.array([float(row["gos_deg"]) for row in rows]),
        "ipf": np.array([[float(row[f"ipf_nd_{c}"]) for c in "rgb"] for row in rows]),
    }
    return part_ids, values


def plot_orientation_metric_layers(
    spatial_model_dir: Path | str,
    metrics_csv: Path | str,
    output_dir: Path | str,
    *,
    metric: str = "ipf",
    all_layers: bool = False,
    dpi: int = 200,
    overwrite: bool = False,
) -> list[Path]:
    """Map grain-level MTEX results onto surface (or all) element polygons."""
    if metric not in {"ipf", "rotation", "gos"}:
        raise ValueError("metric must be one of: ipf, rotation, gos")
    _, element_parts, centers, nodes = load_spatial_model(spatial_model_dir)
    grain_parts, values = _read_grain_metrics(Path(metrics_csv))
    row_by_part = {part_id: index for index, part_id in enumerate(grain_parts)}
    missing = sorted(set(element_parts).difference(row_by_part))
    if missing:
        preview = ", ".join(map(str, missing[:10]))
        raise ValueError(
            f"Metrics are missing for {len(missing)} spatial part(s): {preview}. "
            "The orientation extraction and spatial model must describe the same elements."
        )
    metric_rows = np.array([row_by_part[part_id] for part_id in element_parts])
    mapped = values[metric][metric_rows]

    all_z_centers = np.unique(centers[:, 2])
    # The upper free surface is represented by elements in the highest
    # center-z layer.  Keeping this as the default avoids rendering buried
    # elements that cannot appear in the final contour map.
    z_centers = all_z_centers if all_layers else all_z_centers[-1:]
    output_dir = Path(output_dir)
    if all_layers:
        paths = [
            output_dir / f"{metric}_layer_{i + 1:02d}_z_{z:g}.png"
            for i, z in enumerate(z_centers)
        ]
    else:
        paths = [output_dir / f"{metric}_surface_z_{z_centers[0]:g}.png"]
    existing = [path for path in paths if path.exists()]
    if existing and not overwrite:
        raise FileExistsError(f"Output exists; use --overwrite: {existing[0]}")
    output_dir.mkdir(parents=True, exist_ok=True)

    norm = None
    if metric != "ipf":
        finite = mapped[np.isfinite(mapped)]
        if not len(finite):
            raise ValueError(f"No finite {metric} values to plot.")
        fixed_ranges = {"gos": GOS_RANGE, "rotation": GRAIN_ROTATION_RANGE}
        lower, upper = fixed_ranges[metric]
        if np.isclose(lower, upper):
            upper = lower + max(abs(lower), 1.0) * 1.0e-12
        norm = Normalize(vmin=lower, vmax=upper)

    for path, z in zip(paths, z_centers):
        selected = np.isclose(centers[:, 2], z)
        colors = mapped[selected] if metric == "ipf" else plt.get_cmap("viridis")(norm(mapped[selected]))
        figure, axis = plt.subplots(figsize=(7.2, 7.2), constrained_layout=True)
        collection = PolyCollection(_projected_polygons(nodes[selected]), facecolors=colors, edgecolors="none")
        axis.add_collection(collection)
        axis.autoscale_view()
        axis.set_aspect("equal", adjustable="box")
        axis.set_xlabel("x")
        axis.set_ylabel("y")
        title = "IPF-ND grain orientation" if metric == "ipf" else f"Grain {metric} (deg)"
        axis.set_title(f"{title} | z center = {z:g}")
        if metric != "ipf":
            figure.colorbar(plt.cm.ScalarMappable(norm=norm, cmap="viridis"), ax=axis, label="deg")
        figure.savefig(path, dpi=dpi, facecolor="white")
        plt.close(figure)
    return paths
