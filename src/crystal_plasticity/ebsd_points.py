import numpy as np
from math import radians, sin, cos
from src.others.text_tools import ret_form_lines
from src.pre_process.mesh_node import node_set
from src.others.id_array_tools import ret_id2idx_map_array

class ebsd_points(object):
    num_points = 0
    id_array = np.empty(0)
    id_array_in_mtex = np.empty(0,dtype=int)
    x_array = np.array(0)
    y_array = np.array(0)
    z_array = np.array(0)
    phi1_array = np.empty(0)
    Phi_array = np.empty(0)
    phi2_array = np.empty(0)
    part_id_array = np.empty(0)
    id2idx_map_array = np.empty(0,dtype=int)

    def __init__(self, input_file_dir:str):
        if input_file_dir.endswith(".txt"):
            print("INFO: Reading ebsd points information from self defined file")
            self._input_from_self_defined_text(input_file_dir)
            print("INFO: Initializing the id2idx mapping array for ebsd point")
            self.id2idx_map_array = ret_id2idx_map_array(self.id_array)
        else:
            self.num_points = 0
            self.id_array = np.empty(0, dtype=int)
            self.id_array_in_mtex = np.empty(0)
            self.x_array = np.array(0)
            self.y_array = np.array(0)
            self.z_array = np.array(0)
            self.phi1_array = np.empty(0)
            self.Phi_array = np.empty(0)
            self.phi2_array = np.empty(0)
            self.part_id_array = np.empty(0)
            self.id2idx_map_array = np.empty(0, dtype=int)
            # print("INFO: Creating empty ebsd points set")

    # input functions
    def _input_from_self_defined_text(self, input_file_dir):
        """
        Initialize ebsd_points set from self defined text file
        :param input_file_dir:
        :return:
        """
        # get the information lines from text
        lines = ret_form_lines(input_file_dir,"*EBSD_POINT")[0][1:]
        # initialize number
        self.num_points = len(lines)
        # initialize the id_array
        self.id_array = np.arange(1,1+self.num_points, dtype=int)
        # initialize empty array
        self.id_array_in_mtex = np.empty(self.num_points, dtype=int)
        self.x_array = np.empty(self.num_points, dtype=float)
        self.y_array = np.empty(self.num_points, dtype=float)
        self.z_array = np.empty(self.num_points, dtype=float)
        self.part_id_array = np.empty(self.num_points, dtype=int)
        self.phi1_array = np.empty(self.num_points, dtype=float)
        self.Phi_array = np.empty(self.num_points, dtype=float)
        self.phi2_array = np.empty(self.num_points, dtype=float)
        # give the information into the container
        for i in range(len(lines)):
            info = lines[i].replace("\n", '').split(",")
            self.id_array_in_mtex[i] = info[0]
            self.x_array[i] = info[1]
            self.y_array[i] = info[2]
            self.z_array[i] = info[3]
            self.phi1_array[i] = info[4]
            self.Phi_array[i] = info[5]
            self.phi2_array[i] = info[6]
            self.part_id_array[i] = info[7]

    # edit functions for the region of ebsd set
    # including, scale, translate, rotate, crop
    # based on these, it can adjust with specimen nodes set
    def scale_points_coordinates(self, scale_factor, axis_str:str = ''):
        if axis_str == 'x':
            self.x_array = self.x_array * scale_factor
        elif axis_str == 'y':
            self.y_array = self.y_array * scale_factor
        elif axis_str == 'z':
            self.z_array = self.z_array * scale_factor
        else:
            self.x_array = self.x_array * scale_factor
            self.y_array = self.y_array * scale_factor
            self.z_array = self.z_array * scale_factor

    def translate_points_coodinates(self, distance, axis_str:str = ''):
        if axis_str == 'x':
            self.x_array = self.x_array + distance
        elif axis_str == 'y':
            self.y_array = self.y_array + distance
        elif axis_str == 'z':
            self.z_array = self.z_array + distance
        else:
            self.x_array = self.x_array + distance
            self.y_array = self.y_array + distance
            self.z_array = self.z_array + distance

    def adjust_points_region_into_specimen_size(self, specimen_nodes_set: node_set):
        """
        Scale the points coordinates to make the points set region as the same size
        of specimens nodes set region
        :param specimen_nodes_set: nodes set object of specimen mesh
        :return:
        """
        # length and width of points set region and specimen nodes region
        points_region_len = np.amax(self.x_array) - np.amin(self.x_array)
        points_region_width = np.amax(self.y_array) - np.amin(self.y_array)
        specimen_region_len = \
            np.amax(specimen_nodes_set.x_array) - np.amin(specimen_nodes_set.x_array)
        specimen_region_width = \
            np.amax(specimen_nodes_set.y_array) - np.amin(specimen_nodes_set.y_array)
        # calculate the scale factor for points set in length and width
        len_scale_factor = specimen_region_len/points_region_len
        width_scale_factor = specimen_region_width/points_region_width
        # scale the points set
        self.scale_points_coordinates(len_scale_factor,'x')
        self.scale_points_coordinates(width_scale_factor,'y')

    def adjust_points_region_into_specimen_positions(self, specimen_nodes_set: node_set):
        """
        Translate the position of points to make it the same position with specimen
        :param specimen_nodes_set: nodes set object of specimen mesh
        :return:
        """
        # center positions of points set region and specimen nodes region
        points_center_x = (np.amax(self.x_array) + np.amin(self.x_array))/2
        points_center_y = (np.amax(self.y_array) + np.amin(self.y_array)) / 2

        specimen_center_x = \
            (np.amax(specimen_nodes_set.x_array) + np.amin(specimen_nodes_set.x_array))/2
        specimen_center_y = \
            (np.amax(specimen_nodes_set.y_array) + np.amin(specimen_nodes_set.y_array)) / 2
        # translate the points set
        self.translate_points_coodinates(specimen_center_x - points_center_x, 'x')
        self.translate_points_coodinates(specimen_center_y - points_center_y, 'y')

    def adjust_points_region_with_specimen(self, specimen_nodes_set: node_set):
        """
        Adjust the points region with specimen, for size and positions
        :param specimen_nodes_set: nodes set object of specimen mesh
        :return:
        """
        # first adjust size
        self.adjust_points_region_into_specimen_size(specimen_nodes_set)
        # then adjust position
        self.adjust_points_region_into_specimen_positions(specimen_nodes_set)

    def rotate_poinst_region(self,rot_degrees):
        """
        Rotate the points region with some degrees
        :param rot_degrees: rotation angle, degrees style
        :return:
        """
        rot_radians = radians(rot_degrees)

        const_sin = sin(rot_radians)
        const_cos = cos(rot_radians)

        center_x = (np.amax(self.x_array) + np.amin(self.x_array)) / 2
        center_y = (np.amax(self.y_array) + np.amin(self.y_array)) / 2

        for i in range(self.num_points):
            x_old = self.x_array[i]
            y_old = self.y_array[i]

            x_old -= center_x
            y_old -= center_y

            x_new = const_cos * x_old - const_sin * y_old
            y_new = const_sin * x_old + const_cos * y_old

            x_new += center_x
            y_new += center_y

            self.x_array[i] = x_new
            self.y_array[i] = y_new
