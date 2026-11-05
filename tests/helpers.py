"""Shared synthetic inputs; contains no collected tests."""

import numpy as np
import pandas as pd

from src.theme2.sachs_equilibrium import SIGNS


def mesh_frames(nx=3, ny=3, nz=2):
    xyz = np.array(
        [
            [x, y, z]
            for z in np.linspace(0, 0.2, nz + 1)
            for y in np.linspace(0, 1, ny + 1)
            for x in np.linspace(0, 1, nx + 1)
        ]
    )

    def node(x, y, z):
        return z * (ny + 1) * (nx + 1) + y * (nx + 1) + x + 1

    records = []
    for z in range(nz):
        for y in range(ny):
            for x in range(nx):
                conn = [
                    node(x + int(a), y + int(b), z + int(c))
                    for a, b, c in (SIGNS + 1) / 2
                ]
                records.append(
                    {
                        "element_id": len(records) + 1,
                        "part_id": 1 + (x >= nx // 2),
                        **dict(zip([f"node_id_{i}" for i in range(1, 9)], conn)),
                    }
                )
    nodes = pd.DataFrame(xyz, columns=["x", "y", "z"])
    nodes.insert(0, "node_id", np.arange(1, len(nodes) + 1))
    elements = pd.DataFrame(records)
    lookup = nodes.set_index("node_id")[["x", "y", "z"]]
    conn = elements[[f"node_id_{i}" for i in range(1, 9)]].to_numpy()
    centers = lookup.loc[conn.ravel()].to_numpy().reshape(-1, 8, 3).mean(axis=1)
    elements[["center_x", "center_y", "center_z"]] = centers
    return nodes, elements


def onset_inputs(tmp_path):
    nodes, elements = mesh_frames(6, 6, 2)
    nodes.to_csv(tmp_path / "nodes.csv", index=False)
    elements.to_csv(tmp_path / "elements.csv", index=False)
    angle = tmp_path / "orientation.csv"
    np.savetxt(angle, [[0.2, 0.4, 0.8], [1.1, 0.9, 0.3]], delimiter=",")
    return angle


def surface_mesh(tmp_path, n=20, individual=False):
    nodes, elements = mesh_frames(n, n, 1)
    if individual:
        elements.part_id = elements.element_id
    nodes.to_csv(tmp_path / "nodes.csv", index=False)
    elements.to_csv(tmp_path / "elements.csv", index=False)
    top = nodes[nodes.z.eq(nodes.z.max())].copy()
    top.node_id = np.arange(1, len(top) + 1)
    return top
