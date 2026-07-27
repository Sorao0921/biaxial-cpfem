import matplotlib.pyplot as plt
import numpy as np
from src.crystal_plasticity import ebsd_points
from src.pre_process.mesh_node import node_set
from src.pre_process.mesh import mesh


class visualization(object):
    fig = None
    ax = None

    def __init__(self):
        self.fig = plt.figure()
        self.ax = self.fig.add_subplot(1, 1, 1)

    def add_scatter_points(self, x_array, y_array, size = 0.05, color = 'blue'):
        self.ax.scatter(x_array,y_array,s=size,c=color)

    def add_legend(self):
        plt.legend()

    def adjust_equal_axes(self):
        self.ax.axis('equal')
        self.fig.tight_layout()

    def show_fig(self):
        plt.show()

    def save_fig(self, file_dir):
        self.ax.savefig(file_dir, dpi=600)

    # special plotting method
    def add_scatter_nodes_for_selected_elements(self, id_array_selected_elems,
                                                mesh_set: mesh, color='red'):
        """
        scatter plot all the nodes of selected elements
        :param id_array_selected_elems:
        :param mesh_set:
        :return:
        """
        selected_nodes_id_array = np.empty(0,dtype=int)
        for i in range(len(id_array_selected_elems)):
            elem_id = id_array_selected_elems[i]
            nodes_list = mesh_set.elem_set.nodes_list[elem_id-1]
            selected_nodes_id_array = np.append(selected_nodes_id_array,nodes_list)

        selected_nodes_id_array = np.unique(selected_nodes_id_array)

        selected_nodes_x_array = mesh_set.node_set.x_array[selected_nodes_id_array-1]
        selected_nodes_y_array = mesh_set.node_set.y_array[selected_nodes_id_array-1]

        print(
            f"DEBUG INFO: MESH NODES - MIN X COOR {np.amin(selected_nodes_x_array)}, MIN Y COOR {np.amin(selected_nodes_y_array)}\n")
        print(
            f"DEBUG INFO: MESH NODES - MAX X COOR {np.amax(selected_nodes_x_array)}, MAX Y COOR {np.amax(selected_nodes_y_array)}\n")

        self.add_scatter_points(selected_nodes_x_array,selected_nodes_y_array, size=5,color=color)

    def add_scatter_points_from_selected_ebsd_points(self, id_array_selected, ebsd_points_set: ebsd_points):
        selected_points_x_array = ebsd_points_set.x_array[id_array_selected-1]
        selected_points_y_array = ebsd_points_set.y_array[id_array_selected-1]
        print(f"DEBUG INFO: EBSD POINTS - MIN X COOR {np.amin(selected_points_x_array)}, MIN Y COOR {np.amin(selected_points_x_array)}\n")
        print(f"DEBUG INFO: EBSD POINTS - MAX X COOR {np.amax(selected_points_x_array)}, MAX Y COOR {np.amax(selected_points_x_array)}\n")
        selected_points_phi1_array = ebsd_points_set.phi1_array[id_array_selected-1]
        self.add_scatter_points(selected_points_x_array,selected_points_y_array, size=1,color=selected_points_phi1_array)

