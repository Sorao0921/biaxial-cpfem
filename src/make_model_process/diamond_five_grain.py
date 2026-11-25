"""Generate a five-grain diamond model on an existing mesh."""

from pathlib import Path

import numpy as np

from src.pre_process.keyword_format import write_any_keyword
from src.pre_process.mesh import mesh

NODE_SET_HEADER = "$#     sid       da1       da2       da3       da4    solver       its         -\n"
NODE_MEMBERS_HEADER = "$#    nid1      nid2      nid3      nid4      nid5      nid6      nid7      nid8\n"


def write_diamond_node_set(deck, set_id, name, ids):
    """Use the same explicit 10-column card layout as the supplied macro BCs."""
    deck.write("*SET_NODE_LIST_TITLE\n" + name + "\n" + NODE_SET_HEADER)
    deck.write(f"{set_id:10d}" + f"{0.0:10.1f}" * 4 + "MECH      " + "1         " + "          " + "\n")
    deck.write(NODE_MEMBERS_HEADER)
    for start in range(0, len(ids), 8):
        deck.write("".join(f"{int(n):10d}" for n in ids[start:start+8]) + "\n")


PART_NAMES = ("CENTER", "UPPER_RIGHT", "UPPER_LEFT", "LOWER_LEFT", "LOWER_RIGHT")


def write_diamond_model(
    initmesh: Path, section_file: Path, output: Path, *, central_diagonal: float
) -> None:
    """Assign grain IDs using element centroids and write a keyword deck."""
    model = mesh(str(initmesh))
    nodes = model.node_set
    elements = model.elem_set
    axes = (nodes.x_array, nodes.y_array, nodes.z_array)
    lower = np.array([axis.min() for axis in axes])
    upper = np.array([axis.max() for axis in axes])
    if not 0 < central_diagonal < min((upper - lower)[:2]):
        raise ValueError("--central-diagonal must be positive and smaller than the XY spans")

    x, y, _ = model.ret_elem_center_pos(elements.id_array)
    x = x - (lower[0] + upper[0]) / 2
    y = y - (lower[1] + upper[1]) / 2
    # The center grain owns elements whose centroids lie on its boundary.
    inside = np.abs(x) + np.abs(y) <= central_diagonal / 2 + 1e-12
    quadrants = np.where(y >= 0, np.where(x >= 0, 2, 3), np.where(x < 0, 4, 5))
    elements.part_list = np.where(inside, 1, quadrants)
    if np.unique(elements.part_list).size != len(PART_NAMES):
        raise ValueError("the requested diamond must leave at least one element in each grain")

    section = section_file.read_text(encoding="utf-8").rstrip()
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8") as deck:
        model.write_keyword(deck)
        deck.write(section + "\n")
        for part_id, name in enumerate(PART_NAMES, start=1):
            write_any_keyword(
                deck, "*PART", f"GRAIN_{part_id}_{name}",
                [[part_id, 1, part_id, 0, 0, 0, 0, 0]],
            )
        node_sets = []
        for axis_idx, (axis_name, coords) in enumerate(zip("XYZ", axes)):
            for offset, (suffix, bound) in enumerate(
                (("MIN", lower[axis_idx]), ("MAX", upper[axis_idx]))
            ):
                ids = nodes.id_array[np.isclose(coords, bound, rtol=0, atol=1e-12)]
                node_sets.append((101 + 2 * axis_idx + offset, axis_name + suffix, ids))
        center_nodes = elements.nodes_list[inside]
        for part_id in range(2, 6):
            shared = np.intersect1d(center_nodes, elements.nodes_list[elements.part_list == part_id])
            node_sets.append((299 + part_id, f"INTERFACE_CENTER_TO_PART_{part_id}", shared))
        for set_id, name, ids in node_sets:
            write_diamond_node_set(deck, set_id, name, ids)
        deck.write("*END\n")
