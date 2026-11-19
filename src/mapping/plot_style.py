"""Shared display ranges for comparable contour maps."""

from matplotlib.colors import LinearSegmentedColormap

HEIGHT_SCALE = 1.0e3
# Fixed absolute-height limits in scaled display units, shared across states.
HEIGHT_RANGE = (8.0, 10.0)

# Low -> high: blue, green, yellow, red.
HEIGHT_CMAP = LinearSegmentedColormap.from_list(
    "surface_height", ["#2166ac", "#22a745", "#ffdf00", "#d7191c"], N=256
)
HEIGHT_COLORBAR_TICKS = (8.0, 8.5, 9.0, 9.5, 10.0)
GOS_RANGE = (0.0, 3.0)
GRAIN_ROTATION_RANGE = (0.0, 5.0)
ACCUMULATED_SHEAR_STRAIN_RANGE = (0.0, 0.3)
HEIGHT_AXIS_TICK_INTERVAL = 0.1
