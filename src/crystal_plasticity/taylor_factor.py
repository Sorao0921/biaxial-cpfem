"""Equal-CRSS FCC Taylor factor, normalized by von Mises plastic strain.

Solve min ||gamma||_1 subject to sum gamma*sym(s outer n) = D.
The finite dual vertex set makes evaluating many orientations inexpensive.
"""

from functools import lru_cache
from itertools import combinations, product

import numpy as np


def bunge_sample_to_crystal(euler):
    """Passive Bunge matrix; angles in radians, last dimension phi1,Phi,phi2."""
    e = np.asarray(euler, dtype=float)
    if e.shape[-1] != 3 or not np.isfinite(e).all():
        raise ValueError("Expected finite Bunge Euler triples in radians")
    c1, c, c2 = np.moveaxis(np.cos(e), -1, 0)
    s1, s, s2 = np.moveaxis(np.sin(e), -1, 0)
    return np.stack(
        [
            c1 * c2 - s1 * s2 * c,
            s1 * c2 + c1 * s2 * c,
            s2 * s,
            -c1 * s2 - s1 * c2 * c,
            -s1 * s2 + c1 * c2 * c,
            c2 * s,
            s1 * s,
            -c1 * s,
            c,
        ],
        axis=-1,
    ).reshape(e.shape[:-1] + (3, 3))


def components(d):
    return d[..., (0, 1, 1, 0, 0), (0, 1, 2, 2, 1)]


@lru_cache(maxsize=1)
def fcc_solver():
    normals = np.array([[1, 1, 1], [1, 1, -1], [1, -1, 1], [-1, 1, 1]])
    dirs = [
        v
        for v in product((-1, 0, 1), repeat=3)
        if sum(x * x for x in v) == 2 and next(x for x in v if x) != -1
    ]
    tensors = []
    for n in normals:
        for v in dirs:
            if np.dot(n, v) == 0:
                outer = np.outer(v, n) / np.sqrt(6)
                tensors.append((outer + outer.T) / 2)
    a = components(np.array(tensors)).T
    assert a.shape == (5, 12)
    bases = np.array(list(combinations(range(12), 5)))
    matrices = np.moveaxis(a[:, bases], 0, 1)
    good = np.abs(np.linalg.det(matrices)) > 1e-10
    matrices = matrices[good]
    inverses = np.linalg.inv(matrices)
    signs = np.array(list(product((-1.0, 1.0), repeat=5)))
    vertices = np.einsum("nji,sj->nsi", inverses, signs).reshape(-1, 5)
    vertices = vertices[(np.abs(vertices @ a) <= 1 + 1e-9).all(axis=1)]
    vertices = np.unique(np.round(vertices, 12), axis=0)
    return a, inverses, vertices


def crystal_strain(euler, rho):
    if not np.isfinite(rho):
        raise ValueError("rho must be finite")
    d = np.diag([1.0, rho, -1.0 - rho])
    d /= np.sqrt(2 / 3 * np.sum(d * d))
    g = bunge_sample_to_crystal(euler)
    return g @ d @ np.swapaxes(g, -1, -2)


def taylor_factor(euler, rho):
    """rho = Dyy/Dxx; Dzz=-(Dxx+Dyy), zero imposed shear."""
    b = components(crystal_strain(euler, rho))
    return np.max(b @ fcc_solver()[2].T, axis=-1)


def primal_check(euler, rho):
    """Independent primal basis enumeration for validation of small samples."""
    b = components(crystal_strain(euler, rho))
    gamma = np.einsum("nij,...j->...ni", fcc_solver()[1], b)
    return np.min(np.sum(np.abs(gamma), axis=-1), axis=-1)
