import _io
import io

import numpy as np
from src.pre_process.mesh_elem import elem_set
from src.pre_process.mesh_node import node_set
from src.others.id_array_tools import ret_indices_of_id_array, ret_id2idx_map_array
from src.others.text_tools import get_file_extension
from copy import deepcopy
import meshio
from src.pre_process.mesh_dict import DICT_MESH2MESHIO_ELEM,DICT_MESHIO2MESH_ELEM


class mesh(object):
    elem_set = elem_set('')
    node_set = node_set('')
    # properties for specific functions
    # elem_center_pos = np.zeros(shape=(3, elem_set.num), dtype=float)
    # elem_center_pos_periodic = np.zeros(shape=(26, 3, elem_set.num), dtype=float)

    # init functions
    def __init__(self, input_file_dir: str):
        """
        Init function for the base object
        :param input_file_dir: directory to the keyword file.
        """
        file_ext = get_file_extension(input_file_dir)
        if file_ext == '':
            print("INFO: Creating empty mesh set.")
            self.elem_set = elem_set('')
            self.node_set = node_set('')
        else:
            self._init_from_file(input_file_dir, file_ext)
            print("INFO: Reading mesh information from file.")
            self.elem_set = elem_set(input_file_dir)
            self.node_set = node_set(input_file_dir)

    def _init_from_file(self, input_file_dir: str, file_ext: str):
        """
        Read the mesh information from file
        :param input_file_dir:
        :param file_ext: '.k','.inp',...
        :return:
        """
        if file_ext == '.k' or '.K':
            print("INFO: Reading mesh information from LS-DYNA keyword file.")
            self.elem_set = elem_set(input_file_dir)
            self.node_set = node_set(input_file_dir)
        else:
            print("INFO: Reading mesh information from other input file.")
            mesh_mio = meshio.read(input_file_dir)
            # self.elem_set, self.node_set = meshio_to_mesh(mesh_mio)

    # Output mesh
    # def write_keyword(self, write_dest, file_format: str = ".k"):
    def write_keyword(self, write_dest):
        """
        Io to Output the mesh set keyword to the given directory
        :param write_io: io to keywore file, string of the diretory to the keyword file
        :return:
        """
        if type(write_dest) is _io.TextIOWrapper:
            self.elem_set.write_keyword(write_dest)
            self.node_set.write_keyword(write_dest)
        elif type(write_dest) is str:
            write_io = open(write_dest, 'w')
            self.elem_set.write_keyword(write_io)
            self.node_set.write_keyword(write_io)
            write_io.close()
        else:
            raise Exception("def write_keyword: check the input dest.")

    def identify_boundary_elem(self, elem_id):
        """
        check whether is an element at grain boundary,
        return the flag, and the part id list
        :param elem_id: id of a given element
        :return: flag,
                part id list (if boundary elem, return all the part id and its own, if not, return its own id)
        """
        flag = False
        adjacent_elem_id_list = self.elem_set.search_ajacent_elem(elem_id)
        adjacent_elem_idx_list = self.elem_set.id2idx_map_array[adjacent_elem_id_list]
        part_id_list = self.elem_set.part_list[adjacent_elem_idx_list]
        part_id_list = np.unique(part_id_list)

        if len(part_id_list) > 1:
            flag = True
        return flag, part_id_list

    def ret_elem_center_pos(self, elem_id):
        """
        return the center position of elems
        :param elem_id:
        :return:
        """
        idx = self.elem_set.id2idx_map_array[elem_id]
        node_id_list = self.elem_set.nodes_list[idx]
        node_idx_list = self.node_set.id2idx_map_array[node_id_list]
        x_array = self.node_set.x_array[node_idx_list]
        y_array = self.node_set.y_array[node_idx_list]
        z_array = self.node_set.z_array[node_idx_list]
        return np.mean(x_array, axis=1), np.mean(y_array, axis=1), np.mean(z_array, axis=1)

    def init_all_elem_certer_post(self):
        """
        return all the centeral position of the element
        :return: np,array()*3
        """
        center_x_array = np.zeros(self.elem_set.num, dtype=float)
        center_y_array = np.zeros(self.elem_set.num, dtype=float)
        center_z_array = np.zeros(self.elem_set.num, dtype=float)
        for i in range(self.elem_set.num):
            node_id_list = self.elem_set.nodes_list[i]
            node_idx_list = self.node_set.id2idx_map_array[node_id_list]
            x_array = self.node_set.x_array[node_idx_list]
            y_array = self.node_set.y_array[node_idx_list]
            z_array = self.node_set.z_array[node_idx_list]
            center_x_array[i] = np.mean(x_array)
            center_y_array[i] = np.mean(y_array)
            center_z_array[i] = np.mean(z_array)
        center_array = np.vstack([center_x_array, center_y_array, center_z_array])
        self.elem_center_pos = center_array
        return center_array

    def init_periodic_elem_center_post(self):
        """
        initialize the center position for periodic elements
        (+x,-x,+y,-y,+z,-z)
        :return:
        """
        if len(self.elem_center_pos[0]) == 0:
            self.init_all_elem_certer_post()
        center_x_array, center_y_array, center_z_array = (
            self.elem_center_pos[0], self.elem_center_pos[1], self.elem_center_pos[2])
        len_cube = [self.node_set.x_array.max() - self.node_set.x_array.min(),
                    self.node_set.y_array.max() - self.node_set.y_array.min(),
                    self.node_set.z_array.max() - self.node_set.z_array.min()]
        temp = np.zeros(shape=(26, 3, self.elem_set.num), dtype=float)
        pos = [-1,0,1]
        pos_list = [[pos[i], pos[j], pos[k]] for i in range(3) for j in range(3) for k in range(3)]
        for i in range(len(temp)):
            temp[i] = np.vstack([center_x_array + len_cube[0]*pos_list[i][0],
                                 center_y_array + len_cube[1]*pos_list[i][1],
                                 center_z_array + len_cube[2]*pos_list[i][2]])
        self.elem_center_pos_periodic = temp
        return temp

    def combine_all_parts_into_one(self):
        """
        Assign all the element to part 1
        :return:
        """
        new_part_list = np.full(self.elem_set.num, 1, dtype=int)
        self.elem_set.part_list = new_part_list

    def extract_mesh_by_part_list(self, selected_part_id_list):
        """
        Extract a submesh from the mesh by referring to the part_list
        :param selected_part_id_list: the part list of the submesh
        :return: object mesh
        """
        # init a mew mesh object
        print("INFO: Extracting a submesh from the input mesh")
        submesh = mesh('')
        # element information
        submesh.elem_set.type = self.elem_set.type
        elem_id_array = np.empty(0, dtype=int)
        part_id_array = np.empty(0, dtype=int)
        nodes_list_array = np.empty((0, self.elem_set.nodes_list.shape[1]), dtype=int)
        for part_id in selected_part_id_list:
            indices = np.where(self.elem_set.part_list == part_id)
            elem_id_array = np.hstack((elem_id_array, self.elem_set.id_array[indices]))
            part_id_array = np.hstack((part_id_array, self.elem_set.part_list[indices]))
            nodes_list_array = np.vstack((nodes_list_array, self.elem_set.nodes_list[indices]))
        submesh.elem_set.id_array = elem_id_array
        submesh.elem_set.num = len(submesh.elem_set.id_array)
        submesh.elem_set.nodes_list = nodes_list_array
        submesh.elem_set.part_list = part_id_array
        submesh.elem_set.id2idx_map_array = ret_id2idx_map_array(submesh.elem_set.id_array)
        # node information
        node_id_array = submesh.elem_set.nodes_list.flatten()
        node_id_array = np.unique(node_id_array)
        submesh.node_set.num = len(node_id_array)
        indices = ret_indices_of_id_array(self.node_set.id_array, node_id_array)
        submesh.node_set.x_array = self.node_set.x_array[indices]
        submesh.node_set.y_array = self.node_set.y_array[indices]
        submesh.node_set.z_array = self.node_set.z_array[indices]
        submesh.node_set.id_array = self.node_set.id_array[indices]
        submesh.node_set.id2idx_map_array = ret_id2idx_map_array(submesh.node_set.id_array)
        return submesh

    def delete_useless_nodes(self):
        """
        clean up the nodes which is not belong to any elements
        :return:
        """
        link_nodes_id = np.unique(self.elem_set.nodes_list.flatten())
        all_nodes_id = self.node_set.id_array
        free_nodes_id = np.setdiff1d(all_nodes_id, link_nodes_id)
        free_nodes_idx = self.node_set.id2idx_map_array[free_nodes_id]
        # begin to clean
        print(f"Info: cleaning the free nodes in the mesh {len(free_nodes_id)} in {self.node_set.num}.")
        self.node_set.id_array = np.delete(self.node_set.id_array, free_nodes_idx)
        self.node_set.x_array = np.delete(self.node_set.x_array, free_nodes_idx)
        self.node_set.y_array = np.delete(self.node_set.y_array, free_nodes_idx)
        self.node_set.z_array = np.delete(self.node_set.z_array, free_nodes_idx)
        self.node_set.num = len(self.node_set.id_array)
        self.node_set.id2idx_map_array[free_nodes_id] = 0

    def select_elem_by_box_region(self, pos_min, pos_max, periodic=False):
        """
        select the element by a box
        also support periodic selection
        :param pos_min: [x_min, y_min, z_min]
        :param pos_max: [x_max, y_max, z_max]
        :return: id array of the select element, np.array()
        """
        if periodic:
            if len(self.elem_center_pos_periodic[0][0]) == 0:
                self.init_periodic_elem_center_post()
            indices = np.empty(shape=0, dtype=int)
            for i in range(len(self.elem_center_pos_periodic)):
                center_pos = self.elem_center_pos_periodic[i]
                one_indices = np.where((center_pos[0] > pos_min[0]) & (center_pos[0] < pos_max[0]) &
                                       (center_pos[1] > pos_min[1]) & (center_pos[1] < pos_max[1]) &
                                       (center_pos[2] > pos_min[2]) & (center_pos[2] < pos_max[2]))[0]
                indices = np.concatenate([indices, one_indices])
            indices = np.unique(indices)
        else:
            if len(self.elem_center_pos[0]) == 0:
                self.init_all_elem_certer_post()
            indices = np.where((self.elem_center_pos[0] > pos_min[0]) & (self.elem_center_pos[0] < pos_max[0]) &
                               (self.elem_center_pos[1] > pos_min[1]) & (self.elem_center_pos[1] < pos_max[1]) &
                               (self.elem_center_pos[2] > pos_min[2]) & (self.elem_center_pos[2] < pos_max[2]))[0]
        return self.elem_set.id_array[indices]

    def copy(self):
        """
        copy a new mesh
        :return: mesh
        """
        return deepcopy(self)


