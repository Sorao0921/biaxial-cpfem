"""Shared display ranges for comparable contour maps."""

HEIGHT_SCALE = 1.0e3
# Robust common ranges chosen from the available-model distributions.  The
# rounded limits follow approximately the central 95% of plotted values so
# that outliers saturate at the end colours instead of flattening contrast.
HEIGHT_RANGE = (9.0, 10.0)
GOS_RANGE = (0.0, 3.0)
GRAIN_ROTATION_RANGE = (0.0, 5.0)
ACCUMULATED_SHEAR_STRAIN_RANGE = (0.0, 0.3)
HEIGHT_AXIS_TICK_INTERVAL = 0.1
