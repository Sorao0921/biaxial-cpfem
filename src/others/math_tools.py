import math
import numpy as np
from numpy.ma.core import shape


def cal_normal_vects(x1, y1, x2, y2):
    # Calculate the direction vector
    dx = x2 - x1
    dy = y2 - y1
    dyn = -dy
    # Calculate the magnitude of the normal vector
    magnitude = np.sqrt(dx ** 2 + dy ** 2)
    # Normalize the normal vector to get the unit normal vector
    unit_normal_vector = np.column_stack((dyn / magnitude,dx / magnitude))
    return unit_normal_vector

def cal_plane_normals(x1, y1, z1, x2, y2, z2, x3, y3, z3):
    # Create vectors from the points
    v1 = np.stack((x2 - x1, y2 - y1, z2 - z1), axis=1)
    v2 = np.stack((x3 - x1, y3 - y1, z3 - z1), axis=1)
    # Calculate the cross product of the two vectors
    normal_vectors = np.cross(v1, v2)
    # Normalize the normal vectors
    norms = np.linalg.norm(normal_vectors, axis=1, keepdims=True)
    normal_vectors = normal_vectors / norms
    return normal_vectors

def cal_p2p_vects(p1, p2):
    tol = 0
    dist = p2 - p1
    for i in range(np.shape(p1)[1]):
        tol += np.power(dist[0:, i], 2)
    magnitude = np.sqrt(tol)
    magnitude = magnitude.reshape(-1, 1)
    dist = dist / magnitude
    return dist

def cal_vect_prod(v1, v2):
    tol = np.zeros(np.shape(v1)[0], dtype=float)
    for i in range(np.shape(v1)[1]):
        val = v1[0:, i] * v2[0:, i]
        tol += val
    return tol

def cal_trans_by_vect_dis(vect, dis):
    """
    calculate the translation by a given unit vector for direction and a give distance
    :param vect: unit vector for trans direction, np.ndarray((n,2 or 3))
    :param dis: float constant
    :return: trans: translation in two or three x,y,z direction, np.ndarray((n,2 or 3))
    """
    dim = np.shape(vect)[1]
    trans = np.empty((np.shape(vect)[0],0), dtype=float)
    for i in range(dim):
        dl = vect[:,i] * dis
        trans = np.column_stack((trans,dl))
    return trans

def normalize_vect(vect):
    nonzero_row = np.nonzero(np.any(vect != [0, 0, 0], axis=1))[0]
    tol = np.zeros(np.shape(vect)[0], dtype=float)
    for i in range(np.shape(vect)[1]):
        tol[nonzero_row] += vect[nonzero_row, i] ** 2
    mag = np.sqrt(tol)
    mag = mag.reshape(-1, 1)
    unit_vect = np.zeros(np.shape(vect), dtype=float)
    unit_vect[nonzero_row] = vect[nonzero_row]/mag[nonzero_row]
    return unit_vect
