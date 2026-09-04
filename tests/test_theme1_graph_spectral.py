from pathlib import Path

import numpy as np
import pandas as pd

from src.theme1.graph_spectral import (
    build_surface_grain_graph,
    reconstruct_bands,
    spectral_summary,
)


def _grid() -> tuple[pd.DataFrame, pd.DataFrame]:
    nodes = pd.DataFrame(
        [
            (1, 0.0, 0.0, 1.0),
            (2, 1.0, 0.0, 1.0),
            (3, 2.0, 0.0, 1.0),
            (4, 0.0, 1.0, 1.0),
            (5, 1.0, 1.0, 1.0),
            (6, 2.0, 1.0, 1.0),
        ],
        columns=["node_id", "x", "y", "z"],
    )
    elements = pd.DataFrame(
        [
            (1, 10, 0.5, 0.5, 1.0, 1, 2, 5, 4),
            (2, 20, 1.5, 0.5, 1.0, 2, 3, 6, 5),
        ],
        columns=[
            "element_id",
            "part_id",
            "center_x",
            "center_y",
            "center_z",
            "node_id_1",
            "node_id_2",
            "node_id_3",
            "node_id_4",
        ],
    )
    return elements, nodes


def test_surface_graph_uses_shared_edges_and_boundary_length() -> None:
    elements, nodes = _grid()
    graph = build_surface_grain_graph(elements, nodes, weight="boundary_length")
    assert graph.node_ids.tolist() == [10, 20]
    assert len(graph.edge_table) == 1
    assert np.isclose(graph.edge_table.iloc[0]["shared_boundary_length"], 1.0)
    assert np.allclose(graph.adjacency, [[0.0, 1.0], [1.0, 0.0]])


def test_graph_fourier_reconstruction_and_energy_are_exact() -> None:
    elements, nodes = _grid()
    graph = build_surface_grain_graph(elements, nodes, weight="binary")
    signal = np.array([2.0, -1.0])
    coefficients = graph.transform(signal)
    assert np.allclose(graph.inverse_transform(coefficients), signal, atol=1e-12)
    assert np.isclose(np.sum(signal**2), np.sum(coefficients**2), atol=1e-12)
    reconstructed = reconstruct_bands(graph, signal)
    assert np.allclose(sum(reconstructed.values()), signal, atol=1e-12)


def test_spectral_summary_energy_fractions_sum_to_one() -> None:
    elements, nodes = _grid()
    graph = build_surface_grain_graph(elements, nodes)
    signals = pd.DataFrame(
        {
            "part_id": [10, 20],
            "height_mean": [1.0, -1.0],
            "shear_mean": [0.2, 0.8],
            "grain_rotation": [0.1, 0.3],
            "gos": [0.05, 0.2],
        }
    )
    _, energies = spectral_summary(graph, signals)
    totals = energies.groupby("signal")["energy_fraction"].sum()
    assert np.allclose(totals, 1.0)


def test_spectral_summary_excludes_the_constant_mode_from_band_energy() -> None:
    elements, nodes = _grid()
    graph = build_surface_grain_graph(elements, nodes)
    signals = pd.DataFrame(
        {
            "part_id": [10, 20],
            "height_mean": [4.0, 4.0],
            "shear_mean": [4.0, 4.0],
            "grain_rotation": [4.0, 4.0],
            "gos": [4.0, 4.0],
        }
    )
    modes, energies = spectral_summary(graph, signals)
    assert set(modes.loc[modes["mode"] == 0, "band"]) == {"dc"}
    assert np.allclose(energies["energy"], 0.0, atol=1e-12)
