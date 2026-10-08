"""Unsigned z-directed slip activity; Euler angles use passive Bunge radians."""

import numpy as np

from src.crystal_plasticity.taylor_factor import bunge_sample_to_crystal

# m(:,1:12) in external/dyn_umats_from_n/dyn21umats_0710.F.
# That UMAT calls the <110> slip direction m, and the {111} normal s.
LEGACY_FCC_DIRECTIONS = np.array(
    [
        [0, -1, 1],
        [1, 0, 1],
        [1, 1, 0],
        [0, -1, 1],
        [-1, 0, 1],
        [-1, 1, 0],
        [0, 1, 1],
        [1, 0, 1],
        [-1, 1, 0],
        [0, 1, 1],
        [-1, 0, 1],
        [1, 1, 0],
    ],
    dtype=float,
) / np.sqrt(2)


def z_slip_activity(
    previous, current, euler, *, delta_epsilon, directions=LEGACY_FCC_DIRECTIONS
):
    """Return Az and Rz per element, using interval-start orientation.

    delta_epsilon is the positive macro equivalent-strain increment.
    Absolute projections avoid dependence on arbitrary slip-vector signs.
    """
    previous, current, euler, directions = (
        np.asarray(x, dtype=float) for x in (previous, current, euler, directions)
    )
    if previous.ndim != 2 or previous.shape[1] != 12 or current.shape != previous.shape:
        raise ValueError("Expected matching N x 12 accumulated slip arrays")
    if euler.shape != (len(previous), 3):
        raise ValueError("Expected one interval-start Euler triple per element")
    if directions.shape != (12, 3) or not np.isfinite(directions).all():
        raise ValueError("Expected 12 finite slip direction vectors in CSV order")
    if not np.allclose(np.linalg.norm(directions, axis=1), 1):
        raise ValueError("Slip directions must be unit vectors")
    if not np.isfinite(delta_epsilon) or delta_epsilon <= 0:
        raise ValueError("delta_epsilon must be finite and positive")
    if (
        not np.isfinite(previous).all()
        or not np.isfinite(current).all()
        or (previous < 0).any()
        or (current < 0).any()
    ):
        raise ValueError("Accumulated slips must be finite and non-negative")
    increment = current - previous
    tolerance = 1e-10 * np.maximum(1, np.maximum(current, previous))
    if (increment < -tolerance).any():
        raise ValueError("Accumulated slip decreased; check states and element IDs")
    rate = np.maximum(increment, 0) / delta_epsilon
    # sample direction = g.T @ crystal direction; its z component is g[:,z].s
    g = bunge_sample_to_crystal(euler)
    projection = np.abs(g[..., :, 2] @ directions.T)
    az = np.sum(rate * projection, axis=1)
    total = np.sum(rate, axis=1)
    rz = np.divide(az, total, out=np.zeros_like(az), where=total > 0)
    return az, rz
