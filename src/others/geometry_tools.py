import numpy as np
import math

class typical_retangle_region(object):
    l_point_x = 0
    l_point_y = 0
    r_point_x = 0
    r_point_y = 0

    def __init__(self, l_point_x, l_point_y, r_point_x, r_point_y):
        self.l_point_x = l_point_x
        self.l_point_y = l_point_y
        self.r_point_x = r_point_x
        self.r_point_y = r_point_y

    # Check whether in a domain
    def in_region(self, x, y) -> bool:
        """
        Judge whether a point is inside the region and its boundary
        :param x: x coordinate of the point
        :param y: y coordinate of the point
        :return: True - it is inside
        """
        if x > self.l_point_x and\
                x < self.r_point_x and\
                y > self.l_point_y and\
                y< self.r_point_y:
            return True
        else:
            return False
    def in_region_and_boundary(self, x, y) -> bool:
        """
        Judge whether a point is inside the region and its boundary
        :param x: x coordinate of the point
        :param y: y coordinate of the point
        :return: True - it is inside
        """
        if x >= self.l_point_x and\
                x <= self.r_point_x and\
                y >= self.l_point_y and\
                y<= self.r_point_y:
            return True
        else:
            return False

    def overlap_elem(self, x_array, y_array) -> bool:
        """
        Check whether an element has overlap with this region
        :param x_array: x coordinates array of the nodes of element
        :param y_array: y coordinates array of the nodes of element
        :return: True - it is inside
        """
        for i in range(len(x_array)):
            if self.in_region(x_array[i], y_array[i]):
                return True
        # no node inside ->  no overlap
        return False


    # Divide retangle regions
    def divide_into_sub_regions(self, num_in_x, num_in_y):
        """
        divide the current region in x,y directions, then return a list of
        sub_regions
        :param num_in_x: number of sub_region in x direction
        :param num_in_y: number of sub_region in y direction
        :return: a list of retangle regions class
        """
        num_regions = num_in_x * num_in_y
        region_array = [None]*num_regions

        step_x = (self.r_point_x - self.l_point_x)/num_in_x
        step_y = (self.r_point_y - self.l_point_y)/num_in_y

        x_array = np.arange(start=self.l_point_x, stop=self.r_point_x + step_x, step=step_x)
        y_array = np.arange(start=self.l_point_y, stop=self.r_point_y + step_y, step=step_y)

        for i in range(num_in_x):
            for j in range(num_in_y):
                region_array[i+j*num_in_x] = typical_retangle_region(x_array[i], y_array[j], x_array[i + 1], y_array[j + 1])

        return region_array

def is_point_in_convex_polygon(point_x,point_y, polygon_x_array, polygon_y_array) -> bool:
    """
    Determine whether a point is inside a convex polygon
    :param point_x: x coordinate of checking points
    :param point_y: y coordinate of checking points
    :param polygon_x_array: x coordinates array of convex polygon
    :param polygon_y_array: y coordinates array of convex polygon
    :return: whether a point is inside a convex polygon
    """

    polygon_x_array_extended = np.append(polygon_x_array, polygon_x_array[0])
    polygon_y_array_extended = np.append(polygon_y_array, polygon_y_array[0])

    last_ret = 0

    for i in range(len(polygon_x_array)):

        cur_node_x = polygon_x_array_extended[i]
        cur_node_y = polygon_y_array_extended[i]

        next_node_x = polygon_x_array_extended[i+1]
        next_node_y = polygon_y_array_extended[i+1]

        vec_1 = np.array([next_node_x-cur_node_x,next_node_y-cur_node_y])
        vec_2 = np.array([point_x-cur_node_x, point_y-cur_node_y])

        cur_ret = np.cross(vec_1,vec_2)

        if i>0:
            prod = cur_ret * last_ret
            if prod <= 0:
                return False

        last_ret = cur_ret

    return True