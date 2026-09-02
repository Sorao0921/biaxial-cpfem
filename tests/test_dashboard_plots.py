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
    assert HEIGHT_RANGE == (5.0, 10.0)
    assert GOS_RANGE == (0.0, 10.0)
    assert GRAIN_ROTATION_RANGE == (0.0, 20.0)
    assert ACCUMULATED_SHEAR_STRAIN_RANGE == (0.0, 1.5)
