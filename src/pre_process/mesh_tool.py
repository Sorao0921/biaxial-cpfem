from src.pre_process.mesh import mesh
import numpy as np
from src.pre_process.mesh_node import node_set
from enum import Enum
from copy import deepcopy
from tqdm import tqdm

def drag_shell_to_solid(shell_mesh: mesh, num_layer: int, tol_thick):
    """
    Drag the shell mesh to be solid mesh,
    This functions should be used in the mesh set which has been reordered.
    :param num_layers:
    :param thicknesss:
    :return:
    """
    thick = tol_thick / num_layer
    solid_mesh = mesh('')
    nodes_form = np.empty(shape=(shell_mesh.node_set.num, num_layer + 1), dtype=int)
    # begin to copy for the first layer
    solid_mesh.node_set.add_points(shell_mesh.node_set.x_array, shell_mesh.node_set.y_array,
                                   shell_mesh.node_set.z_array)
    curr_nodes_id_array = solid_mesh.node_set.id_array
    nodes_form[:, 0] = curr_nodes_id_array
    # offset for multiple layers
    temp_nodes = deepcopy(shell_mesh.node_set)
    for i in range(num_layer):
        temp_nodes.offset_node_set(thick, 'z')
        solid_mesh.node_set.add_points(temp_nodes.x_array, temp_nodes.y_array, temp_nodes.z_array)
        curr_nodes_id_array = curr_nodes_id_array + shell_mesh.node_set.num
        nodes_form[:, i + 1] = curr_nodes_id_array
    # create solid
    solid_nodes_network = nodes_form[shell_mesh.node_set.id2idx_map_array[shell_mesh.elem_set.nodes_list], :]
    # nodes_form[shell_mesh.node_set.id2idx_map_array[shell_mesh.elem_set.nodes_list] ,:]
    # drag different nodes
    num_nodes_arr = shell_mesh.elem_set.num_nodes
    tri_elem_idx = np.where(num_nodes_arr == 3)[0]
    quad_elem_idx = np.where(num_nodes_arr == 4)[0]
    # drag tri-shell
    # if len(quad_elem_idx) != 0:
    for i in range(num_layer):
        nodes = np.empty(shape=(shell_mesh.elem_set.num, 8), dtype=int)
        if len(quad_elem_idx) != 0:
            n1 = solid_nodes_network[quad_elem_idx, 0:4, i]
            n2 = solid_nodes_network[quad_elem_idx, 0:4, i + 1]
            nodes[quad_elem_idx, 0] = n1[:, 0]
            nodes[quad_elem_idx, 1] = n1[:, 1]
            nodes[quad_elem_idx, 2] = n1[:, 2]
            nodes[quad_elem_idx, 3] = n1[:, 3]
            nodes[quad_elem_idx, 4] = n2[:, 0]
            nodes[quad_elem_idx, 5] = n2[:, 1]
            nodes[quad_elem_idx, 6] = n2[:, 2]
            nodes[quad_elem_idx, 7] = n2[:, 3]
        if len(tri_elem_idx) != 0:
            n1 = solid_nodes_network[tri_elem_idx, 0:3, i]
            n2 = solid_nodes_network[tri_elem_idx, 0:3, i + 1]
            nodes[tri_elem_idx, 0] = n1[:, 0]
            nodes[tri_elem_idx, 1] = n1[:, 1]
            nodes[tri_elem_idx, 2] = n2[:, 1]
            nodes[tri_elem_idx, 3] = n2[:, 0]
            nodes[tri_elem_idx, 4] = n1[:, 2]
            nodes[tri_elem_idx, 5] = n1[:, 2]
            nodes[tri_elem_idx, 6] = n2[:, 2]
            nodes[tri_elem_idx, 7] = n2[:, 2]
        solid_mesh.elem_set.add_elems(nodes, shell_mesh.elem_set.part_list)
    # drag quad_shell
    # if len(tri_elem_idx) != 0:
    #     for i in range(num_layer):
    #         n1 = solid_nodes_network[tri_elem_idx, 0:3, i]
    #         n2 = solid_nodes_network[tri_elem_idx, 0:3, i + 1]
    #         nodes = np.empty(shape=(shell_mesh.elem_set.num, 8), dtype=int)
    #         nodes[tri_elem_idx, 0] = n1[:, 0]
    #         nodes[tri_elem_idx, 1] = n1[:, 1]
    #         nodes[tri_elem_idx, 2] = n2[:, 1]
    #         nodes[tri_elem_idx, 3] = n2[:, 0]
    #         nodes[tri_elem_idx, 4] = n1[:, 2]
    #         nodes[tri_elem_idx, 5] = n1[:, 2]
    #         nodes[tri_elem_idx, 6] = n2[:, 2]
    #         nodes[tri_elem_idx, 7] = n2[:, 2]
    #         solid_mesh.elem_set.add_elems(nodes, shell_mesh.elem_set.part_list)
    solid_mesh.elem_set.type = "ELEMENT_SOLID"
    return solid_mesh

def _drag_node(original_x, original_y, original_z, distance_list):
    """
    Drag one original node in z direction with a list of distance
    :param original_node_coordinates: coordinate of the original node [x,y,z]
    :param distance_list: list of distance between a sequence nodes
    :return: coordinates_list: list of coordinates of the drag nodes
    """
    # given the original coordinate
    x_coordinate = original_x
    y_coordinate = original_y
    z_coordinate = original_z
    # initialize the drag x,y,z array
    num_drag_nodes = len(distance_list) + 1
    drag_x_array = np.empty(num_drag_nodes, dtype=float)
    drag_y_array = np.empty(num_drag_nodes, dtype=float)
    drag_z_array = np.empty(num_drag_nodes, dtype=float)
    # original node
    drag_x_array[0] = original_x
    drag_y_array[0] = original_y
    drag_z_array[0] = original_z
    # calculate the coordinates of drag nodes
    drag_x_array.fill(original_x)
    drag_y_array.fill(original_y)
    for i in range(len(distance_list)):
        distance = distance_list[i]
        z_coordinate += distance
        drag_z_array[i + 1] = z_coordinate
    # return the node coordinates list
    return drag_x_array, drag_y_array, drag_z_array

