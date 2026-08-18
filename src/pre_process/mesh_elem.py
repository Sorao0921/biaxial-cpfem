from src.pre_process.keyword_file import keyword_file, ret_form_lines
from src.pre_process.keyword_format import write_line_with_vars_rjust
import numpy as np
from src.others.id_array_tools import ret_id2idx_map_array, extend_id2idx_map_array
from tqdm import tqdm

class elem_set(object):
    type = ''
    id_array = np.empty(0,dtype=int)
    nodes_list = np.empty((0,8),dtype=int)
    part_list = np.empty(0,dtype=int)
    id2idx_map_array = np.empty(0,dtype=int)

    def __init__(self, input_file_dir: str):
        if input_file_dir.lower().endswith('.k'):
            print("INFO: Reading element information from keyword file")
            self._input_from_keyword(input_file_dir)
            print("INFO: Initializing the id2idx mapping array for element")
            self.id2idx_map_array = ret_id2idx_map_array(self.id_array)
        else:
            self.type = ''
            # self.num = 0
            self.id_array = np.empty(0,dtype=int)
            self.nodes_list = np.empty((0,8),dtype=int)
            self.part_list = np.empty(0,dtype=int)
            self.id2idx_map_array = np.empty(0,dtype=int)
            print("INFO: Creating empty element set")

    # properties
    @property
    def num(self):
        return len(self.id_array)

    @property
    def num_nodes(self):
        if self.type == '':
            raise ValueError(
                f'def _init_num_nodes: should define the element type before init the num nodes array.\n')
        arr = np.zeros(self.num, dtype=int)
        if self.type == 'ELEMENT_SHELL':
            condition = (self.nodes_list[:,2] == self.nodes_list[:,3])
            arr[condition] = 3
            arr[~condition] = 4
        return arr

                # Input functions
    def _input_from_keyword(self, input_file_dir):
        """
        Init the element set by reading the keyword file
        :param input_file_dir: directory of input keyword file
        :return:
        """
        # get the lines related to elements from keyword
        keyword = keyword_file(input_file_dir,'r')
        lines = keyword.read_lines()
        lines = ret_form_lines(lines,"*ELEMENT_")[0]  # now we just use one set of element
        # detect element type, begin to parse the lines
        if lines[0].startswith("*ELEMENT_SHELL"):
            self.type = "ELEMENT_SHELL"
            self._init_elem_set(lines[1:], self.type)

        elif lines[0].startswith("*ELEMENT_SOLID (ten nodes format)"):
            self.type = "ELEMENT_SOLID"
            processed_lines = self._init_elem_set_preprocess_ten_nodes_format(lines[1:])
            self._init_elem_set(processed_lines, self.type)
        elif lines[0].startswith("*ELEMENT_SOLID"):
            self.type = "ELEMENT_SOLID"
            self._init_elem_set(lines[1:], self.type)
        else:
            raise TypeError("def _input_from_keyword: Current element type is not supported.")

    # Output functions
    def write_keyword(self, write_io):
        """
        Io to Output the elem set keyword to the given directory
        :param write_io: io to keywore file
        :return:
        """
        # write header and comments
        write_io.write(f'*KEYWORD  \n')
        write_io.write(f'*{self.type}  \n')
        write_io.write(f'$#   eid     pid      n1      n2      n3      n4      n5      n6      n7      n8  \n')
        # write information
        elem_line = np.empty(10, dtype=int)
        for i in range(self.num):
            elem_line.fill(0)
            elem_line[0] = self.id_array[i]
            elem_line[1] = self.part_list[i]
            elem_line[2:2+len(self.nodes_list[i])] = self.nodes_list[i]
            write_line_with_vars_rjust(elem_line,write_io,8)

    def _init_elem_set(self, lines, elem_type):
        """
        Init the element set by the keyword lines
        :return:
        """
        # init the size of id_array, nodes_list, etc.
        num_lines = len(lines)
        self.id_array = np.empty(num_lines,dtype=int)
        self.part_list = np.empty(num_lines,dtype=int)

        num_node = 0
        if elem_type == "ELEMENT_SHELL":
            num_node = 4
        elif elem_type == "ELEMENT_SOLID":
            num_node = 8
        self.nodes_list = np.empty((self.num,num_node),dtype=int)
        # get the id_array, nodes_list, etc., from lines
        for i in tqdm(range(self.num)):
            line = lines[i]
            info = line.split()
            self.id_array[i], self.part_list[i] = info[0], info[1]
            self.nodes_list[i] = info[2:2+num_node]

    def _init_elem_set_preprocess_ten_nodes_format(self, lines):
        """
        ten nodes format lines for element
        :param lines:
        :return:
        """
        num_elem = int(len(lines)/2)
        processed_lines = [None]*num_elem
        for i in range(num_elem):
            processed_lines[i] = lines[2*i][:-1]+lines[2*i+1]
        return processed_lines

    def add_elems(self, nodes, parts):
        """
        add new elems to the set
        :param nodes: the nodes of the new elems
        :param parts: related parts of the elems
        :return: ids, the ids of the new array, 1d integer numpy array
        """
        # init
        num_elems = np.shape(nodes)[0]
        # append information
        self.part_list = np.append(self.part_list, parts, axis=0)
        self.nodes_list = np.append(self.nodes_list, nodes, axis=0)
        if np.shape(self.id_array)[0] == 0:
            ids = np.arange(1, num_elems + 1)
        else:
            ids = np.arange(max(self.id_array)+1, max(self.id_array)+num_elems+1)
        self.id_array = np.append(self.id_array, ids, axis=0)
        # update the map
        self.id2idx_map_array = extend_id2idx_map_array(self.id2idx_map_array, ids)
        return ids

    def search_ajacent_elem(self,elem_id):
        """
        Serch the adjacent element by using node lists of a specific element
        :param elem_id: id of an element
        :return: np.array, the array with the adjacent element id
        """
        idx = self.id2idx_map_array[elem_id]
        nodes_list = self.nodes_list[idx]
        elem_id_array = np.empty(0,dtype=int)
        for i in range(len(nodes_list)):
            node_id = nodes_list[i]
            temp = self.search_elem_by_node(node_id)
            elem_id_array = np.concatenate((elem_id_array,temp))
        unique_elem_id_array = np.unique(elem_id_array)
        unique_elem_id_array = unique_elem_id_array[unique_elem_id_array != elem_id]

        thres = 2
        if self.type == "ELEMENT_SHELL":
            thres = 1
        elif self.type == "ELEMENT_SOLID":
            thres = 2
        ajacent_elem_id_array = []
        for i in range(len(unique_elem_id_array)):
            cur_elem_id = unique_elem_id_array[i]
            if np.count_nonzero(elem_id_array == cur_elem_id) > thres:
                ajacent_elem_id_array.append(cur_elem_id)
        return np.array(ajacent_elem_id_array)

    def search_elem_by_node(self,node_id):
        """
        Search the elements which has such node
        :param node_id: id of a specific node
        :return: the array of the elements which have this node
        """
        idx = np.where(self.nodes_list == node_id)[0]
        return self.id_array[idx]

    def assign_elems_to_parts(self,elems_id_array,parts_id_array):
        """
        Assign the parts id to the elements with two arrays
        :param elems_id_array: np.array([elem_1_id, elem_2_id, elem_3_id, ...])
        :param parts_id_array: np.array([elem_1_grainid, elem_2_grainid, elem_3_grainid, ...])
        :return:
        """
        if np.any(elems_id_array <= 0):
            raise ValueError("def assign_elems_to_part: receive invalid element id.")
        if type(parts_id_array) == int:
            temp_arr = np.array([parts_id_array]*len(elems_id_array),dtype=int)
        else:
            temp_arr = parts_id_array
        if len(elems_id_array) == len(temp_arr):
            elems_idx_array = self.id2idx_map_array[elems_id_array]
            self.part_list[elems_idx_array] = temp_arr
        else:
            raise TypeError("def assign_elems_to_part: check the input array.")

    def modify_elems_part_id(self,init_part_id,new_part_id):
        """
        Change the part to another part for the elements
        :param init_part_id: int
        :param new_part_id: int
        :return:
        """
        indices = np.where(self.part_list == init_part_id)[0]
        if len(indices) == 0:
            raise ValueError("def modify_elems_part_id: no element is assigned to a part.")
        self.part_list[indices] = new_part_id

    def ret_part_nodes(self, part_id):
        """
        return the nodes id list for a given part id or a given parts id list
        :param part_id:
        :return: np.ndarray
        """
        elems_idx = np.where(np.isin(self.part_list, part_id))
        nodes_id = self.nodes_list[elems_idx].flatten()
        return nodes_id

    def ret_part_elems(self, part_id):
        """
        return the elem id list for a given part id or a given parts id list
        :param part_id:
        :return: np.ndarray
        """
        elems_idx = np.where(np.isin(self.part_list, part_id))
        elems_id = self.id_array[elems_idx]
        return elems_id
