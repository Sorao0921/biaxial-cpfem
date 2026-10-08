from __future__ import annotations

import matplotlib.pyplot as plt
import numpy as np

from src.dashboard import plots
from src.mapping.plot_style import (
    ACCUMULATED_SHEAR_STRAIN_RANGE,
    GOS_RANGE,
    GRAIN_ROTATION_RANGE,
    HEIGHT_RANGE,
)


def test_height_figure_uses_scaled_fixed_range_and_point_one_ticks(tmp_path):
    coordinates = tmp_path / "coordinates.csv"
    coordinates.write_text(
        "x,y,z\n0,0,0.005\n0.2,0,0.007\n0,0.2,0.010\n0.2,0.2,0.008\n",
        encoding="utf-8",
    )

    figure = plots.height_figure(
        coordinates, title="height", value_range=HEIGHT_RANGE
    )
    axis, colorbar_axis = figure.axes

    assert np.isclose(axis.xaxis.get_majorticklocs()[1] - axis.xaxis.get_majorticklocs()[0], 0.1)
    assert np.isclose(axis.yaxis.get_majorticklocs()[1] - axis.yaxis.get_majorticklocs()[0], 0.1)
    assert np.allclose(colorbar_axis.get_ylim(), HEIGHT_RANGE)
    assert r"$\times 10^{-3}$" in colorbar_axis.get_ylabel()
    plt.close(figure)


def test_metric_display_ranges_are_shared_constants():
    assert HEIGHT_RANGE == (9.0, 10.0)
    assert GOS_RANGE == (0.0, 3.0)
    assert GRAIN_ROTATION_RANGE == (0.0, 5.0)
    assert ACCUMULATED_SHEAR_STRAIN_RANGE == (0.0, 0.3)


def test_deformed_surface_uses_export_ids_and_only_interpart_edges(tmp_path):
    # Global IDs deliberately differ from the exported 1-based row IDs.
    (tmp_path / "nodes.csv").write_text(
        "node_id,x,y,z\n101,0,0,1\n102,1,0,1\n103,2,0,1\n"
        "104,0,1,1\n105,1,1,1\n106,2,1,1\n"
    )
    (tmp_path / "elements.csv").write_text(
        "element_id,part_id,center_x,center_y,center_z,n1,n2,n3,n4\n"
        "11,7,0.5,0.5,1,101,102,105,104\n"
        "12,8,1.5,0.5,1,102,103,106,105\n"
    )
    coords = tmp_path / "coords.csv"
    coords.write_text("node_id,x,y,z\n6,15,23,1\n5,13,23,1\n4,11,23,1\n"
                      "3,14,20,1\n2,12,20,1\n1,10,20,1\n")
    ids, parts, polygons, segments = plots.deformed_surface(tmp_path, coords)
    assert ids.tolist() == [11, 12]
    assert parts.tolist() == [7, 8]
    np.testing.assert_allclose(polygons[0], [[10,20], [12,20], [13,23], [11,23]])
    np.testing.assert_allclose(segments, [[[12,20], [13,23]]])
    metrics = tmp_path / "metrics.csv"
    metrics.write_text("part_id,gos_deg,grain_rotation_deg,taylor_factor\n7,1,2,2.5\n8,3,4,3.5\n")
    for metric in ("gos", "rotation", "taylor"):
        figure = plots.orientation_figure(metrics, tmp_path, metric=metric,
                                          title=metric, coordinates_path=coords)
        np.testing.assert_allclose(figure.axes[0].collections[0].get_paths()[0].vertices[:4], polygons[0])
        np.testing.assert_allclose(figure.axes[0].collections[-1].get_segments(), segments)
        plt.close(figure)
    shear = tmp_path / "shear.csv"
    shear.write_text(",".join(["element_id", plots.TOTAL_SHEAR_COLUMN, *plots.SLIP_COLUMNS])+"\n"
                     + "12,0.2,"+",".join(["0"]*12)+"\n"
                     + "11,0.1,"+",".join(["0"]*12)+"\n")
    figure = plots.shear_figure(shear, tmp_path, title="shear", coordinates_path=coords)
    np.testing.assert_allclose(figure.axes[0].collections[0].get_paths()[0].vertices[:4], polygons[0])
    np.testing.assert_allclose(figure.axes[0].collections[0].get_array(), [0.1, 0.2])
    np.testing.assert_allclose(figure.axes[0].collections[-1].get_segments(), segments)
    plt.close(figure)
    figure = plots.height_figure(coords, title="height", value_range=(0, 2), spatial_model_dir=tmp_path)
    np.testing.assert_allclose(figure.axes[0].collections[-1].get_segments(), segments)
    plt.close(figure)
    # Cropped exports keep original row IDs and omit incomplete elements.
    coords.write_text("2,12,20,1\n3,14,20,1\n5,13,23,1\n6,15,23,1\n")
    ids, _, polygons, _ = plots.deformed_surface(tmp_path, coords)
    assert ids.tolist() == [12]
    assert len(polygons) == 1


def test_deformed_surface_rejects_incomplete_raw_export(tmp_path, monkeypatch):
    import pytest
    monkeypatch.setattr(plots, "surface_topology", lambda _: ([], [], [], [], 6))
    coords = tmp_path / "coords.csv"
    coords.write_text("0,0,1\n1,0,1\n0,1,1\n")
    with pytest.raises(ValueError, match="Expected 6"):
        plots.deformed_surface(tmp_path, coords)


def test_slip_concentration_averages_systems_before_ratio():
    slips = np.zeros((4, 12))
    slips[0, 0] = 3
    slips[1, 1] = 1
    slips[2, :] = 2
    result = plots.grain_slip_concentration([7, 7, 8, 9], slips)
    # Both elements individually have concentration 1, but grain 7 has .75.
    np.testing.assert_allclose(result, [.75, .75, 1 / 12, 0])
    import pytest
    slips[0, 0] = np.nan
    with pytest.raises(ValueError, match="finite"):
        plots.grain_slip_concentration([7, 7, 8, 9], slips)


def test_shared_taylor_range_uses_visible_values_across_initial_and_state(tmp_path, monkeypatch):
    monkeypatch.setattr(plots, "deformed_surface", lambda *args:
                        (np.array([1,2]), np.array([7,8]), [], []))
    initial = tmp_path/'initial.csv'
    state = tmp_path/'state.csv'
    initial.write_text('part_id,taylor_factor\n7,2.8\n8,3.2\n9,99\n')
    state.write_text('part_id,taylor_factor\n7,3.1\n8,3.9\n9,0\n')
    assert plots.shared_taylor_range([(initial,tmp_path,'coords'),
                                     (state,tmp_path,'coords')]) == (2.8,3.9)
