"""Symmetry-aware initial orientation colors; no specimen-symmetry reduction.

Reference Euler angles match generate_angles_with_mirror.m (including rounding).
Axis-angle RGB is a custom signed-axis key, not an MTEX/IPF color key.
"""

from functools import lru_cache
from itertools import permutations, product

import numpy as np

from src.crystal_plasticity.taylor_factor import bunge_sample_to_crystal

REFERENCE_EULER_DEG = {
    "cube": (0, 0, 0),
    "goss": (0, 45, 0),
    "brass": (35, 45, 0),
    "copper": (90, 35, 45),
    "s": (59, 37, 63),
}


@lru_cache(maxsize=1)
def cubic_rotations():
    rotations = []
    for perm in permutations(range(3)):
        for signs in product((-1, 1), repeat=3):
            r = np.eye(3)[list(perm)] * np.array(signs)[:, None]
            if np.linalg.det(r) > 0:
                rotations.append(r)
    return np.array(rotations)


def relative_rotation(euler, texture):
    """Minimum crystal-symmetry rotation from reference to grain in specimen axes.

    O maps crystal to specimen. Delta = O S O_ref.T, S in cubic proper group.
    Do not identify specimen mirror variants: those can respond differently.
    Returns signed unit axis and angle in degrees. At zero angle axis is zero.
    """
    o = np.swapaxes(bunge_sample_to_crystal(np.atleast_2d(euler)), -1, -2)
    ref = bunge_sample_to_crystal(np.deg2rad(REFERENCE_EULER_DEG[texture]))
    delta = o[:, None] @ cubic_rotations()[None] @ ref
    cosine = np.clip((np.trace(delta, axis1=-2, axis2=-1) - 1) / 2, -1, 1)
    best = np.argmax(cosine, axis=1)
    d = delta[np.arange(len(o)), best]
    v = (
        np.stack(
            [d[:, 2, 1] - d[:, 1, 2], d[:, 0, 2] - d[:, 2, 0], d[:, 1, 0] - d[:, 0, 1]],
            axis=1,
        )
        / 2
    )
    sine = np.linalg.norm(v, axis=1)
    angle = np.arctan2(sine, cosine[np.arange(len(o)), best])
    angle[sine < 1e-12] = 0.0
    axis = np.divide(
        v, sine[:, None], out=np.zeros_like(v), where=sine[:, None] > 1e-12
    )
    return axis, np.rad2deg(angle)


def axis_angle_rgb(axis, angle_deg, *, max_angle=65.0, exponent=0.35):
    """Signed x/y/z map to R/G/B; opposite directions have complementary colors.

    Neutral gray at zero; magnitude blend t=(min(theta/max_angle,1))**exponent.
    exponent<1 expands small differences without per-case normalization.
    """
    if max_angle <= 0 or not 0 < exponent <= 1:
        raise ValueError("Require positive angle limit and exponent in (0,1]")
    axis = np.asarray(axis, float)
    denom = np.max(np.abs(axis), axis=-1, keepdims=True)
    unit = np.divide(axis, denom, out=np.zeros_like(axis), where=denom > 1e-12)
    direction = 0.5 + 0.5 * unit
    strength = np.clip(np.asarray(angle_deg, float) / max_angle, 0, 1) ** exponent
    return 0.88 * (1 - strength[..., None]) + direction * strength[..., None]


def ipf_nd_rgb(euler):
    """Cubic ND IPF, simple RGB barycentric key [001] red/[101] green/[111] blue.

    Standard fundamental triangle, custom interpolation (not MTEX's HSV key).
    """
    direction = np.sort(
        np.abs(bunge_sample_to_crystal(np.atleast_2d(euler))[..., 2]), axis=-1
    )
    a, b, c = direction.T
    weights = np.stack([c - b, np.sqrt(2) * (b - a), np.sqrt(3) * a], axis=-1)
    rgb = np.sqrt(np.maximum(weights, 0))
    return rgb / np.maximum(rgb.max(axis=-1, keepdims=True), 1e-15)
