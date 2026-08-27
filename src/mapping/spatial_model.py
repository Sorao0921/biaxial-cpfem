from __future__ import annotations

import csv
import json
from pathlib import Path

import numpy as np

from src.pre_process.mesh import mesh

SPATIAL_MODEL_VERSION = 1


def _write_csv(path: Path, header: list[str], rows) -> None:
    with path.open("w", newline="", encoding="utf-8") as output:
        writer = csv.writer(output)
        writer.writerow(header)
        writer.writerows(rows)


def export_spatial_model(
    model: mesh,
    output_dir: Path | str,
    *,
    source: Path | str | None = None,
    overwrite: bool = False,
) -> Path:
    """Export mesh geometry and part membership as CSV files.

    The output is solver-independent and keeps the original node, element and
    part IDs.  Element positions are node-coordinate centroids.  Part
    positions are the mean of their element centroids; bounding boxes are also
    included so spatial filtering does not depend on that representative point.
    """
    output_dir = Path(output_dir)
    paths = {
        "nodes": output_dir / "nodes.csv",
        "elements": output_dir / "elements.csv",
        "parts": output_dir / "parts.csv",
        "metadata": output_dir / "metadata.json",
    }

    existing = [path for path in paths.values() if path.exists()]
    if existing and not overwrite:
        details = "\n".join(f" - {path}" for path in existing)
        raise FileExistsError(
            "Spatial-model output already exists. Use overwrite=True only "
            f"when replacement is intentional.\n{details}"
        )

    node_ids = np.asarray(model.node_set.id_array, dtype=int)
    coordinates = np.asarray(model.node_set.coordinate, dtype=float)
    element_ids = np.asarray(model.elem_set.id_array, dtype=int)
    part_ids = np.asarray(model.elem_set.part_list, dtype=int)
    connectivity = np.asarray(model.elem_set.nodes_list, dtype=int)

    if len(node_ids) == 0 or len(element_ids) == 0:
        raise ValueError("The model must contain at least one node and one element.")
    if len(element_ids) != len(part_ids) or len(element_ids) != len(connectivity):
        raise ValueError(
            "Element IDs, part IDs and connectivity have different lengths."
        )
    if len(np.unique(node_ids)) != len(node_ids):
        raise ValueError("Duplicate node IDs are not supported.")
    if len(np.unique(element_ids)) != len(element_ids):
        raise ValueError("Duplicate element IDs are not supported.")

    node_index = {int(node_id): index for index, node_id in enumerate(node_ids)}
    try:
        connectivity_indices = np.array(
            [[node_index[int(node_id)] for node_id in row] for row in connectivity],
            dtype=int,
        )
    except KeyError as error:
        raise ValueError(
            f"Element connectivity refers to missing node ID {error.args[0]}."
        ) from error

    element_centroids = coordinates[connectivity_indices].mean(axis=1)
    output_dir.mkdir(parents=True, exist_ok=True)

    _write_csv(
        paths["nodes"],
        ["node_id", "x", "y", "z"],
        (
            (int(node_id), *position.tolist())
            for node_id, position in zip(node_ids, coordinates)
        ),
    )

    node_columns = [f"node_id_{index + 1}" for index in range(connectivity.shape[1])]
    _write_csv(
        paths["elements"],
        ["element_id", "part_id", "center_x", "center_y", "center_z", *node_columns],
        (
            (int(element_id), int(part_id), *center.tolist(), *nodes.tolist())
            for element_id, part_id, center, nodes in zip(
                element_ids, part_ids, element_centroids, connectivity
            )
        ),
    )

    part_rows = []
    for part_id in np.unique(part_ids):
        selected_elements = part_ids == part_id
        selected_node_ids = np.unique(connectivity[selected_elements])
        selected_coordinates = coordinates[
            [node_index[int(node_id)] for node_id in selected_node_ids]
        ]
        centroid = element_centroids[selected_elements].mean(axis=0)
        lower = selected_coordinates.min(axis=0)
        upper = selected_coordinates.max(axis=0)
        part_rows.append(
            (
                int(part_id),
                int(selected_elements.sum()),
                int(len(selected_node_ids)),
                *centroid.tolist(),
                *lower.tolist(),
                *upper.tolist(),
            )
        )

    _write_csv(
        paths["parts"],
        [
            "part_id",
            "element_count",
            "node_count",
            "center_x",
            "center_y",
            "center_z",
            "min_x",
            "min_y",
            "min_z",
            "max_x",
            "max_y",
            "max_z",
        ],
        part_rows,
    )

    metadata = {
        "format": "si-spatial-model",
        "version": SPATIAL_MODEL_VERSION,
        "source": str(Path(source).resolve()) if source is not None else None,
        "element_type": model.elem_set.type,
        "coordinate_system": "model/global Cartesian coordinates",
        "element_position_definition": "arithmetic mean of element node coordinates",
        "part_position_definition": "arithmetic mean of member element centroids",
        "counts": {
            "nodes": int(len(node_ids)),
            "elements": int(len(element_ids)),
            "parts": int(len(part_rows)),
        },
        "files": {key: path.name for key, path in paths.items() if key != "metadata"},
    }
    paths["metadata"].write_text(
        json.dumps(metadata, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    return output_dir


def export_spatial_model_from_keyword(
    input_keyword: Path | str,
    output_dir: Path | str,
    *,
    overwrite: bool = False,
) -> Path:
    """Read an LS-DYNA keyword once and export a solver-independent dataset."""
    input_keyword = Path(input_keyword)
    if not input_keyword.is_file():
        raise FileNotFoundError(f"Input keyword not found: {input_keyword}")
    model = mesh(str(input_keyword))
    return export_spatial_model(
        model, output_dir, source=input_keyword, overwrite=overwrite
    )
