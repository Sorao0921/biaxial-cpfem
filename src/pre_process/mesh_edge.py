from itertools import combinations
import numpy as np
from src.pre_process.mesh_elem import elem_set
from src.pre_process.mesh_node import node_set
from src.others.math_tools import cal_normal_vects, cal_plane_normals
from tqdm import tqdm

class edge_set(object):
    id_arr = np.empty(0, dtype=int)
    nodes_arr = np.empty((0,2), dtype=int)
    mother_elem_arr = np.empty((0,2), dtype=int)
    type_arr = np.empty(0, dtype=int) # line - 2, tri - 3, qua - 4

    def __init__(self, id = np.empty(0, dtype=int), nodes = np.empty(0, dtype=int),
                 mother_elem = np.empty(0, dtype=int)):
        if type(id) is int or len(id) > 0:
            self.id_arr = np.array(id, dtype=int)
            self.nodes_arr = np.array(nodes, dtype=int)
            self.mother_elem_arr = np.array(mother_elem, dtype=int)
        # if not, init an empty object

    def init_from_elems(self, elems_set: elem_set):
        # check the element type
        if elems_set.type == "ELEMENT_SHELL":
            # classify element
            tri_idxs = np.where(elems_set.nodes_list[:, 2] == elems_set.nodes_list[:, 3])[0]
            quad_idxs = np.where(elems_set.nodes_list[:, 2] != elems_set.nodes_list[:, 3])[0]
            #
            if len(tri_idxs) > 0:
                self._init_from_shell_elem_info(elems_set.id_array[tri_idxs], elems_set.nodes_list[tri_idxs, 0:3])
            if len(quad_idxs) > 0:
                self._init_from_shell_elem_info(elems_set.id_array[quad_idxs], elems_set.nodes_list[quad_idxs, 0:4])
        elif elems_set.type == "ELEMENT_SOLID":
            self._init_from_solid_elem_info(elems_set)
        else:
            raise Exception("@edge_set-init_from_elems: this element type is not supported.\n")

    def _init_from_solid_elem_info(self, elems_set: elem_set):
        # identify the solid element
        wedge_idxs = np.where((elems_set.nodes_list[:, 4] == elems_set.nodes_list[:, 5]) & (
                elems_set.nodes_list[:, 6] == elems_set.nodes_list[:, 7]))[0]
        hexa_idxs = np.array([len(np.unique(row)) for row in elems_set.nodes_list])
        hexa_idxs = np.where(hexa_idxs == 8)[0]
        # make edge information from different solid element
        edge_nodes = np.empty((0,4), dtype= int)
        mother_elem = np.empty(0, dtype=int)
        if len(hexa_idxs) > 0:
            a, b = self._gen_edges_info(elems_set.id_array[hexa_idxs], elems_set.nodes_list[hexa_idxs, 0:])
            edge_nodes = np.concatenate((edge_nodes, a), axis=0)
            mother_elem = np.concatenate((mother_elem, b), axis=0)
        if len(wedge_idxs) > 0:
            temp = [0, 1, 2, 3, 4, 6]
            wedge_nodes = elems_set.nodes_list[wedge_idxs, :]
            a, b = self._gen_edges_info(elems_set.id_array[wedge_idxs], wedge_nodes[:, temp])
            edge_nodes = np.concatenate((edge_nodes, a), axis= 0)
            mother_elem = np.concatenate((mother_elem, b), axis = 0)
        # deal with duplication
        duplicate_info = _chk_duplicated_row(edge_nodes)
        # construct the object and append
        edge_nodes_unique = edge_nodes[duplicate_info[0:, 1], 0:4]
        mother_elem_unique = np.column_stack((mother_elem[duplicate_info[0:, 0]], mother_elem[duplicate_info[0:, 1]]))
        ids = np.arange(1, np.shape(duplicate_info)[0] + 1)
        edges = edge_set(ids, edge_nodes_unique, mother_elem_unique)
        self.append(edges)

    def _gen_edges_info(self, id_arr: np.ndarray, nodes_list: np.ndarray):
        # init the basic properties
        num_elem, num_node = np.shape(nodes_list)[0], np.shape(nodes_list)[1]
        num_face, num_node_aface = None, None  # init
        match num_node:
            case 8:  # qudra
                num_face = 6
                idxs = np.array([[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [3, 2, 6, 7], [0, 3, 7, 4], [1, 2, 6, 5]],
                                dtype=int)
            case 6:
                num_face = 3
                # idxs = np.array([[0,1,4,4],[2,3,5,5],[0,1,2,3],[1,2,5,4],[4,5,3,0]], dtype=int)
                idxs = np.array([[0, 1, 2, 3], [1, 2, 5, 4], [4, 5, 3, 0]], dtype=int)
            # construct the edge node and part list
        edge_nodes = np.empty(shape=(num_elem * num_face, 4), dtype=int)
        for i in range(num_face):
            edge_nodes[i::num_face, 0:] = nodes_list[0:, idxs[i]]
        mother_elem = np.repeat(id_arr, num_face)
        return edge_nodes, mother_elem

    def _init_from_shell_elem_info(self, id_arr: np.ndarray, nodes_list: np.ndarray):
        # init
        num_elem = np.shape(nodes_list)[0]  # number of edges which will be made
        num_node = np.shape(nodes_list)[1]  # number for node for each shell
        edge_nodes = np.empty(shape=(num_elem*num_node,2), dtype=int)  # containors
        front_nodes = nodes_list.flatten()  # the front nodes
        seq = list(range(1, num_node))  # the sequence to reorder the front nodes to be the behind nodes
        seq.append(0)
        behind_nodes = nodes_list[:, seq]
        behind_nodes = behind_nodes.flatten()
        # ret the properties information
        edge_nodes[0:, 0] = front_nodes
        edge_nodes[0:, 1] = behind_nodes
        edge_nodes = np.sort(edge_nodes, axis=1)
        mother_elem = np.repeat(id_arr, num_node)
        # deal with the duplicated
        duplicate_info = _chk_duplicated_row(edge_nodes)
        first_idx = duplicate_info[0:, 0]
        second_idx = duplicate_info[0:, 1]
        # construct the object and append
        edge_nodes_unique = edge_nodes[first_idx, 0:2]
        mother_elem_unique = np.column_stack((mother_elem[first_idx], mother_elem[second_idx]))
        ids = np.arange(1, len(first_idx) + 1)
        edges = edge_set(ids, edge_nodes_unique, mother_elem_unique)
        self.append(edges)

    def append(self,edges):
        self.id_arr = np.append(self.id_arr, edges.id_arr)
        self.mother_elem_arr = np.append(self.mother_elem_arr, edges.mother_elem_arr, axis=0)
        if np.shape(self.nodes_arr)[0] == 0:
            self.nodes_arr = np.empty((0,np.shape(edges.nodes_arr)[1]),int)
        self.nodes_arr = np.append(self.nodes_arr, edges.nodes_arr, axis=0)

    def ret_normal_dir(self, nodes_set: node_set):
        if self.dim == 2:
            begin_nodes_coor, end_nodes_coor, _ = self._ret_endnode_coor(nodes_set)
            return cal_normal_vects(begin_nodes_coor[0:, 0], begin_nodes_coor[0:, 1], end_nodes_coor[0:, 0], end_nodes_coor[0:, 1])
        elif self.dim == 3:
            ret = self._ret_endnode_coor(nodes_set)
            return cal_plane_normals(ret[0][0:,0], ret[0][0:,1], ret[0][0:,2],
                                     ret[1][0:,0], ret[1][0:,1], ret[1][0:,2],
                                     ret[2][0:,0], ret[2][0:,1], ret[2][0:,2])

    def ret_midnode_coor(self, nodes_set: node_set):
        ret = list(self._ret_endnode_coor(nodes_set))
        x,y,z = np.zeros(self.num, dtype=float),np.zeros(self.num, dtype=float),np.zeros(self.num, dtype=float)
        num_ret = len(ret)
        for i in range(num_ret):
            x += ret[i][0:, 0]
            y += ret[i][0:, 1]
            z += ret[i][0:, 2]
        x /= num_ret
        y /= num_ret
        z /= num_ret
        return np.column_stack((x, y, z))

        # begin_nodes_coor, end_nodes_coor, temp = self._ret_endnode_coor(nodes_set)
        # x = (begin_nodes_coor[0:, 0] + end_nodes_coor[0:, 0]) / 2
        # y = (begin_nodes_coor[0:, 1] + end_nodes_coor[0:, 1]) / 2
        # return np.column_stack((x, y))

    def ret_len(self, nodes_set: node_set):
        if self.dim != 2:
            raise Exception("@edge_set-ret_len: this function is only validated in two dimension edges.\n")
        begin_nodes_coor, end_nodes_coor = self._ret_endnode_coor(nodes_set)
        dx = np.abs(begin_nodes_coor[0:, 0] - end_nodes_coor[0:, 0])
        dy = np.abs(begin_nodes_coor[0:, 1] - end_nodes_coor[0:, 1])
        return np.sqrt(dx ** 2 + dy **2)

    def _ret_endnode_coor(self, nodes_set: node_set):
        if self.dim == 2:
            begin_nodes_idx = nodes_set.id2idx_map_array[self.nodes_arr[0:, 0]]
            end_nodes_idx = nodes_set.id2idx_map_array[self.nodes_arr[0:, 1]]
            return (np.column_stack((nodes_set.x_array[begin_nodes_idx],nodes_set.y_array[begin_nodes_idx])),
                    np.column_stack((nodes_set.x_array[end_nodes_idx],nodes_set.y_array[end_nodes_idx])))
        elif self.dim == 3: # dim = 3
            indices = [nodes_set.id2idx_map_array[self.nodes_arr[:, i]] for i in range(self.num_nodes)]
            columns = [np.column_stack((nodes_set.x_array[idx], nodes_set.y_array[idx], nodes_set.z_array[idx])) for idx
                       in indices]
            return tuple(columns)

    def crop_new_set(self,idx):
        edges_nodes = self.nodes_arr[idx, 0:]
        mother_elem = self.mother_elem_arr[idx, 0:]
        ids = np.arange(1, np.shape(edges_nodes)[0] + 1)
        new_set = edge_set(ids, edges_nodes, mother_elem)
        return new_set


    @property
    def num(self):
        return len(self.id_arr)

    @property
    def dim(self):
        val = 2
        if self.num_nodes > 2:
            val = 3
        return val

    @property
    def num_nodes(self):
        return np.shape(self.nodes_arr)[1]


def _elem_nodes_to_edges(nodes):
    """
    order the continuous nodes of element to be an adjacent couple,
    e.g., [4,8,60,1] to be [[4,8],[8,60],[60,1],[1,4]]
    :param nodes:
    :return:
    """
    num = len(nodes)
    edges = np.empty(shape=(num, 2), dtype=int)
    edges[0:, 0] = nodes
    edges[0:num-1, 1] = nodes[1:num]
    edges[num-1, 1] = nodes[0]
    return edges

def _chk_duplicated_row(arr):
    """
    return the first row and the corresponding second (duplicated) rows
    :param arr: n*2 int arr
    :return:
    """
    # obtain a sorted arr
    arr_sorted = np.sort(arr, axis=1)
    # Find unique rows and their indices
    unique_rows, unique_indices = np.unique(arr_sorted, axis=0, return_index=True)
    # Create a dictionary to map rows to their first occurrence index
    row_to_index = {tuple(row): idx for idx, row in zip(unique_indices, unique_rows)}
    # Initialize lists to store duplicate information
    duplicate_info = []
    # Iterate over the array to find duplicates
    for idx, row in enumerate(arr_sorted):
        row_tuple = tuple(row)
        if row_to_index[row_tuple] != idx:
            duplicate_info.append([row_to_index[row_tuple], idx])
    return np.array(duplicate_info,dtype=int)