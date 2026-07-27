import numpy as np
from src.pre_process.mesh import mesh
from src.pre_process.mesh_node import node_set
from copy import deepcopy
from tqdm import tqdm
from src.pre_process.keyword_format import ret_spc_node_lines, ret_prescribe_motion_node_lines,ret_curve_lines
from src.others.id_array_tools import sort_array_together_correspond_to_first_array

class rve2d(object):
    # Geometry
    #
    #      d ----- c     y
    #      |       |     |
    #      a------ b     0 ---- x
    xedge_couple = np.empty(0,dtype=int)
    yedge_couple = np.empty(0,dtype=int)
    vertex_nodes = np.empty(0,dtype=int) # a,b,c,d
    size = np.empty(0,dtype=float)

    def __init__(self, mesh_set: mesh):
        # init
        xbound = [min(mesh_set.node_set.x_array), max(mesh_set.node_set.x_array)]
        ybound = [min(mesh_set.node_set.y_array), max(mesh_set.node_set.y_array)]
        self.size = [xbound[1]-xbound[0], ybound[1]-ybound[0]]
        # init edge nodes
        thres = 10e-6 * self.size[0]
        xedge_behind_nodes = mesh_set.node_set.id_array[np.where(np.abs(mesh_set.node_set.x_array - xbound[0]) < thres)[0]]
        xedge_front_nodes = mesh_set.node_set.id_array[np.where(np.abs(mesh_set.node_set.x_array == xbound[1]) < thres)[0]]
        yedge_behind_nodes = mesh_set.node_set.id_array[np.where(np.abs(mesh_set.node_set.y_array == ybound[0]) < thres)[0]]
        yedge_front_nodes = mesh_set.node_set.id_array[np.where(np.abs(mesh_set.node_set.y_array == ybound[1]) < thres)[0]]
        # init vertex node
        self.vertex_nodes = [np.intersect1d(xedge_behind_nodes, yedge_behind_nodes)[0], np.intersect1d(xedge_front_nodes, yedge_behind_nodes)[0],
                      np.intersect1d(xedge_front_nodes, yedge_front_nodes)[0], np.intersect1d(xedge_behind_nodes, yedge_front_nodes)[0]]
        # init the inner edge node
        xedge_behind_inner_nodes = xedge_behind_nodes[~np.isin(xedge_behind_nodes, self.vertex_nodes)]
        xedge_front_inner_nodes = xedge_front_nodes[~np.isin(xedge_front_nodes, self.vertex_nodes)]
        yedge_behind_inner_nodes = yedge_behind_nodes[~np.isin(yedge_behind_nodes, self.vertex_nodes)]
        yedge_front_inner_nodes = yedge_front_nodes[~np.isin(yedge_front_nodes, self.vertex_nodes)]
        # cal the couple inner edge
        self.xedge_couple = match_2dposition(mesh_set.node_set, xedge_behind_inner_nodes, xedge_front_inner_nodes)
        self.yedge_couple = match_2dposition(mesh_set.node_set, yedge_behind_inner_nodes, yedge_front_inner_nodes)

    def write_mpc(self, file_dir, strain_arr):
        """

        :param file_dir:
        :param strain_arr: [exx,eyy,exy]
        :param dummy_nodes:
        :return:
        """
        # Geometry
        #      d ----- c      y
        #      |       |     |
        #      a------ b     0 ---- x
        # a-0 , b-1, c-2, d-3
        # check the input strain arr
        exx, eyy = strain_arr[0], strain_arr[1]
        sxx, syy = exx * self.size[0], eyy * self.size[1]
        # prepare lines
        id = 1
        lines = []
        # x inner nodes - exx for x displacement
        for i in range(self.xedge_couple.shape[0]):
            line = ret_lines_one_mpc(id, [self.xedge_couple[i,1],self.xedge_couple[i,0],self.vertex_nodes[1]],
                                     [1,1,1], [1,-1,-1])
            lines += line
            id += 1
        # x inner nodes - couple in y displacement
        for i in range(self.xedge_couple.shape[0]):
            line = ret_lines_one_mpc(id, [self.xedge_couple[i,1],self.xedge_couple[i,0]], [2,2,2], [1,-1])
            lines += line
            id += 1
        # y inner nodes - eyy for y displacement
        for i in range(self.yedge_couple.shape[0]):
            line = ret_lines_one_mpc(id, [self.yedge_couple[i, 1], self.yedge_couple[i, 0], self.vertex_nodes[3]],
                                     [2, 2, 2], [1, -1, -1])
            lines += line
            id += 1
        # x inner nodes - couple in y displacement
        for i in range(self.yedge_couple.shape[0]):
            line = ret_lines_one_mpc(id, [self.yedge_couple[i, 1], self.yedge_couple[i, 0]], [1, 1, 1], [1, -1])
            lines += line
            id += 1
        # edge redudancies
        lines += ret_lines_one_mpc(id, [self.vertex_nodes[2], self.vertex_nodes[1]], [1, 1], [1, -1])
        id += 1
        lines += ret_lines_one_mpc(id, [self.vertex_nodes[2], self.vertex_nodes[3]], [2, 2], [1, -1])
        id += 1
        # prepare spc for original node
        lines += ret_spc_node_lines(self.vertex_nodes[0], [1, 1, 0, 0, 0, 0])
        lines += ret_spc_node_lines(self.vertex_nodes[1], [0, 1, 0, 0, 0, 0])
        lines += ret_spc_node_lines(self.vertex_nodes[3], [1, 0, 0, 0, 0, 0])
        # curve
        curve_id = 1
        lines += ret_curve_lines(curve_id,[[0.0,0.0],[0.001,1.0],[1.001,1.0]])
        # prescribe motion node
        # lines += ret_prescribe_motion_node(self.vertex_nodes[1], )
        lines += ret_prescribe_motion_node_lines(self.vertex_nodes[1], 1, curve_id, sxx/1)
        lines += ret_prescribe_motion_node_lines(self.vertex_nodes[3], 2, curve_id, syy/1)
        # output
        write_io = open(file_dir,'w')
        for line in lines:
            write_io.write(line)
        write_io.close()

def ret_lines_one_mpc(id, nodes, dirs, coeffs):
    num = len(nodes)
    lines = []
    lines.append(f'*CONSTRAINED_MULTIPLE_GLOBAL\n')
    lines.append(f'{id}'.rjust(10) + '\n')
    lines.append(f'{num}'.rjust(10) + '\n')
    for i in range(num):
        lines.append(f'{nodes[i]}'.rjust(10) + f'{dirs[i]}'.rjust(10) + f'{coeffs[i]}'.rjust(10) + '\n')
    return lines

def match_2dposition(nodes_set: node_set, nodes1_arr, nodes2_arr):
    # check num
    if len(nodes1_arr) != len(nodes2_arr):
        raise ValueError('mesh_rve match_position: the number of input for two array is not equal.\n')
    # init the information
    num = len(nodes1_arr)
    nodes1_idx_arr = nodes_set.id2idx_map_array[nodes1_arr]
    nodes2_idx_arr = nodes_set.id2idx_map_array[nodes2_arr]
    # init containor
    nodes_couple = np.zeros((num,2),dtype=int)
    temp = nodes2_idx_arr
    for i in range(num):
        # obtain the node
        node1_idx = nodes1_idx_arr[i]
        node1_id = nodes1_arr[i]
        nodes_couple[i, 0] = node1_id
        # obtain information
        x,y = nodes_set.x_array[node1_idx], nodes_set.y_array[node1_idx]
        x_arr, y_arr = nodes_set.x_array[temp], nodes_set.y_array[temp]
        dist = np.power(x_arr-x,2) + np.power(y_arr-y,2)
        # find the minimum distance
        idx = np.argmin(dist)
        node2_idx = temp[idx]
        nodes_couple[i, 1] = nodes_set.id_array[node2_idx]
        # delete the selectd value
        temp = np.delete(temp, idx)
    return nodes_couple


class rve3d(object):
    # properties
    size = np.empty(3, dtype=float)
    bound = np.empty((3,2), dtype=float)
    # face, edge, vertex
    face = [[np.ndarray, np.ndarray], [np.ndarray, np.ndarray], [np.ndarray, np.ndarray]] # a,b,c +,-
    edge = [[np.ndarray, np.ndarray, np.ndarray, np.ndarray], # AE, BF, DH, CG
            [np.ndarray, np.ndarray, np.ndarray, np.ndarray], # AD, EH, BC, FG
            [np.ndarray, np.ndarray, np.ndarray, np.ndarray]] # AB, DC, EF, HG
    vertex = np.empty(8, int) # A,B,C,D,E,F,G,H

    def __init__(self, model: mesh):
        # init nodes
        self._init_nodes(model)
        # order nodes
        self._order_pair(model)

    def _init_nodes(self, model: mesh):
        # obtain the coordinates of the nodes
        nodes_coor = model.node_set.coordinate
        # init the size and bound of the model
        for i in range(3):
            self.bound[i, 0] = min(nodes_coor[0:, i])
            self.bound[i, 1] = max(nodes_coor[0:, i])
            self.size[i] = self.bound[i, 1] - self.bound[i, 0]
        # init the threshold to judge position
        thres = 10e-6 * self.size[0]
        # init faces with edges and vertex
        for i in range(3):
            # behind face
            self.face[i][0] = model.node_set.id_array[np.where(np.abs(nodes_coor[0:, i] - self.bound[i, 0]) < thres)]
            # front face
            self.face[i][1] = model.node_set.id_array[np.where(np.abs(nodes_coor[0:, i] - self.bound[i, 1]) < thres)]
        # init edges with vertex
        cut_face = [1, 2, 0]  # normal axis
        for i in range(3):
            self.edge[i][0] = np.intersect1d(self.face[i][0], self.face[cut_face[i]][0])
            self.edge[i][1] = np.intersect1d(self.face[i][0], self.face[cut_face[i]][1])
            self.edge[i][2] = np.intersect1d(self.face[i][1], self.face[cut_face[i]][0])
            self.edge[i][3] = np.intersect1d(self.face[i][1], self.face[cut_face[i]][1])
        # init vertex
        self.vertex[0] = np.intersect1d(self.face[2][0], self.edge[0][0])
        self.vertex[1] = np.intersect1d(self.face[2][0], self.edge[0][1])
        self.vertex[2] = np.intersect1d(self.face[2][0], self.edge[0][3])
        self.vertex[3] = np.intersect1d(self.face[2][0], self.edge[0][2])
        self.vertex[4] = np.intersect1d(self.face[2][1], self.edge[0][0])
        self.vertex[5] = np.intersect1d(self.face[2][1], self.edge[0][1])
        self.vertex[6] = np.intersect1d(self.face[2][1], self.edge[0][3])
        self.vertex[7] = np.intersect1d(self.face[2][1], self.edge[0][2])
        # delete vertex and edges in edges and faces
        for i in range(3):
            for j in range(4):
                self.edge[i][j] = np.setdiff1d(self.edge[i][j], self.vertex)
        # delete edges and vertex in faces
        all_edges = np.reshape(self.edge, -1)
        all_edges = np.concatenate((all_edges, self.vertex))
        for i in range(3):
            self.face[i][0] = np.setdiff1d(self.face[i][0], all_edges)
            self.face[i][1] = np.setdiff1d(self.face[i][1], all_edges)

    def _order_pair(self, model: mesh):
        coor = model.node_set.coordinate
        self.face[0][1] = _order_face_pairs(self.face[0][0], self.face[0][1], coor[0:, [1, 2]],
                                            model.node_set.id2idx_map_array)
        self.face[1][1] = _order_face_pairs(self.face[1][0], self.face[1][1], coor[0:, [0, 2]],
                                            model.node_set.id2idx_map_array)
        self.face[2][1] = _order_face_pairs(self.face[2][0], self.face[2][1], coor[0:, [0, 1]],
                                            model.node_set.id2idx_map_array)
        self.edge[0] = _order_edges_pair(self.edge[0], coor[0:, 2], model.node_set.id2idx_map_array)
        self.edge[1] = _order_edges_pair(self.edge[1], coor[0:, 0], model.node_set.id2idx_map_array)
        self.edge[2] = _order_edges_pair(self.edge[2], coor[0:, 1], model.node_set.id2idx_map_array)

    def fix_position(self, model:mesh):
        # fix position
        model.node_set.y_array[model.node_set.id2idx_map_array[self.face[0][1]]] = model.node_set.y_array[model.node_set.id2idx_map_array[self.face[0][0]]]
        model.node_set.z_array[model.node_set.id2idx_map_array[self.face[0][1]]] = model.node_set.z_array[model.node_set.id2idx_map_array[self.face[0][0]]]
        model.node_set.x_array[model.node_set.id2idx_map_array[self.face[1][1]]] = model.node_set.x_array[model.node_set.id2idx_map_array[self.face[1][0]]]
        model.node_set.z_array[model.node_set.id2idx_map_array[self.face[1][1]]] = model.node_set.z_array[model.node_set.id2idx_map_array[self.face[1][0]]]
        model.node_set.x_array[model.node_set.id2idx_map_array[self.face[2][1]]] = model.node_set.x_array[model.node_set.id2idx_map_array[self.face[2][0]]]
        model.node_set.y_array[model.node_set.id2idx_map_array[self.face[2][1]]] = model.node_set.y_array[model.node_set.id2idx_map_array[self.face[2][0]]]
        for i in range(1, 4):
            model.node_set.z_array[model.node_set.id2idx_map_array[self.edge[0][i]]] = model.node_set.z_array[model.node_set.id2idx_map_array[self.edge[0][0]]]
            model.node_set.x_array[model.node_set.id2idx_map_array[self.edge[1][i]]] = model.node_set.x_array[model.node_set.id2idx_map_array[self.edge[1][0]]]
            model.node_set.y_array[model.node_set.id2idx_map_array[self.edge[2][i]]] = model.node_set.y_array[model.node_set.id2idx_map_array[self.edge[2][0]]]
        return model

    def write_mpc(self, file_dir, strain_arr, dummy_nodes):
        # calculate the dummy node displacement
        exx, eyy, ezz, exy, exz, eyz = strain_arr[0], strain_arr[1], strain_arr[2], strain_arr[3], strain_arr[4], \
        strain_arr[5]
        sxx, syy, szz, sxy, sxz, syz = exx * self.size[0], eyy * self.size[1], ezz * self.size[2], exy * self.size[
            1], exz * self.size[2], eyz * self.size[2]
        # init lines
        lines = []
        id = 1
        # node motion
        curve_id = 1
        lines += ret_curve_lines(curve_id, [[0.0, 0.0], [0.001, 1.0], [1.001, 1.0]])
        lines += ret_prescribe_motion_node_lines(dummy_nodes[0], 1, curve_id, sxx / 1)
        lines += ret_prescribe_motion_node_lines(dummy_nodes[0], 2, curve_id, syy / 1)
        lines += ret_prescribe_motion_node_lines(dummy_nodes[0], 3, curve_id, szz / 1)
        lines += ret_prescribe_motion_node_lines(dummy_nodes[1], 2, curve_id, sxy / 1)
        lines += ret_prescribe_motion_node_lines(dummy_nodes[1], 3, curve_id, sxz / 1)
        lines += ret_prescribe_motion_node_lines(dummy_nodes[1], 3, curve_id, syz / 1)
        # prepare dummy node map
        dummy_nodes_map = [[dummy_nodes[0], dummy_nodes[1], dummy_nodes[1]],
                           [dummy_nodes[1], dummy_nodes[0], dummy_nodes[1]],
                           [dummy_nodes[1], dummy_nodes[1], dummy_nodes[0]]]
        # faces
        for i in range(3):
            num = len(self.face[i][0])
            for j in range(1,4):
                for k in range(num):
                    lines += ret_lines_one_mpc(id, [self.face[i][0][k], self.face[i][1][k], dummy_nodes_map[j-1][i]],
                                               [j, j, j], [1, -1, -1])
                    id += 1
        # edge
        edge_couples = [[[0,3],[0,0]],
                        [[0,2],[0,1]],
                        [[2,3],[2,0]],
                        [[2,1],[2,2]],
                        [[1,3],[1,0]],
                        [[1,2],[1,1]]]
        coeff_couple = [[-1,-1],[-1,1],[-1,-1],[-1,1],[-1,-1],[-1,1]]
        dir_couple = [[1,2],[1,2],[1,3],[1,3],[2,3],[2,3]]
        for i in range(6):
            first, second = edge_couples[i][0], edge_couples[i][1]
            first_edge, second_edge = self.edge[first[0]][first[1]], self.edge[second[0]][second[1]]
            num = len(first_edge)
            for j in range(1,4):
                first_dir, second_dir = dir_couple[i][0], dir_couple[i][1]
                first_coeff, second_coeff = coeff_couple[i][0], coeff_couple[i][1]
                for k in range(num):
                    lines += ret_lines_one_mpc(id, [first_edge[k], second_edge[k], dummy_nodes_map[j-1][first_dir-1], dummy_nodes_map[j-1][second_dir-1]],
                                               [j, j, first_dir, second_dir], [1, -1, first_coeff, second_coeff])
                    id += 1
        # edges
        # edge = [[None, None, None, None],  # AE, BF, DH, CG
        #         [None, None, None, None],  # AD, EH, BC, FG
        #         [None, None, None, None]]  # AB, DC, EF, HG
        # vertex
        # vertex = np.empty(8, int)  # A,B,C,D,E,F,G,H
        vertex_couple = [[6,0],[2,4],[5,3],[7,1]]
        coeff_couple = [[-1,-1,-1],[-1,1,1],[-1,-1,-1],[-1,1,-1]]
        for i in range(4):
            for j in range(1, 4):
                lines += ret_lines_one_mpc(id, [self.vertex[vertex_couple[i][0]], self.vertex[vertex_couple[i][1]], dummy_nodes_map[j-1][0], dummy_nodes_map[j-1][1], dummy_nodes_map[j-1][2]],
                                           [j, j, 1, 2, 3], [1,-1, coeff_couple[i][0], coeff_couple[i][1], coeff_couple[i][2]])
                id += 1
        # output
        write_io = open(file_dir, 'w')
        for line in lines:
            write_io.write(line)
        write_io.close()

    def write_mpc__(self, file_dir, strain_arr):
        # # face, edge, vertex
        # face = [[None, None], [None, None], [None, None]]  # a,b,c +,-
        # edge = [[None, None, None, None],  # AE, BF, DH, CG
        #         [None, None, None, None],  # AD, EH, BC, FG
        #         [None, None, None, None]]  # AB, DC, EF, HG
        # vertex = np.empty(8, float)  # A,B,C,D,E,F,G,H
        exx, eyy, ezz, exy, exz, eyz = strain_arr[0], strain_arr[1], strain_arr[2], strain_arr[3], strain_arr[4], strain_arr[5]
        sxx, syy, szz, sxy, sxz, syz = exx * self.size[0], eyy * self.size[1], ezz * self.size[2], exy * self.size[1], exz * self.size[2], eyz * self.size[2]
        # prepare lines
        id = int(1)
        lines = []
        # face +- x




        # face mpc
        # x,y,z face , x,y,z direction
        vertex_id = [self.vertex[3], self.vertex[1], self.vertex[1]]
        for k in range(3):
            for i in range(len(self.face[k][0])):
                nbf, nff = self.face[k][0], self.face[k][1]
                for j in range(1,4):
                    lines += ret_lines_one_mpc(id, [nff[i], nbf[i], vertex_id[k]], [j,j,j], [1,-1,-1])
                    id += 1
        # edge mpc
        # x parallel edges, fg-ad, bc-eh,
        # fg-ad, y,z
        # for i in range()


        # vertex mpc

        # spc
        lines += ret_spc_node_lines(self.vertex[0], [1, 1, 1, 0, 0, 0])  # A
        lines += ret_spc_node_lines(self.vertex[3], [0, 1, 1, 0, 0, 0])  # D
        lines += ret_spc_node_lines(self.vertex[1], [1, 0, 1, 0, 0, 0])  # B
        lines += ret_spc_node_lines(self.vertex[4], [1, 1, 0, 0, 0, 0])  # E
        # node motion
        curve_id = 1
        lines += ret_curve_lines(curve_id, [[0.0, 0.0], [0.001, 1.0], [1.001, 1.0]])
        lines += ret_prescribe_motion_node_lines(self.vertex[3], 1, curve_id, sxx / 1)  # D
        lines += ret_prescribe_motion_node_lines(self.vertex[1], 2, curve_id, syy / 1)  # B
        lines += ret_prescribe_motion_node_lines(self.vertex[4], 3, curve_id, szz / 1)  # E
        # output
        write_io = open(file_dir, 'w')
        for line in lines:
            write_io.write(line)
        write_io.close()




def _order_face_pairs(set1, set2, coors, id2idx_arr):
    num_nodes = np.shape(set1)[0]
    coor1_bn = coors[id2idx_arr[set1], 0]
    coor1_bn_mat = np.tile(coor1_bn.reshape(-1, 1), (1, num_nodes))
    coor2_bn = coors[id2idx_arr[set1], 1]
    coor2_bn_mat = np.tile(coor2_bn.reshape(-1, 1), (1, num_nodes))
    coor1_fn = coors[id2idx_arr[set2], 0]
    coor1_fn_mat = np.tile(coor1_fn, (num_nodes, 1))
    coor2_fn = coors[id2idx_arr[set2], 1]
    coor2_fn_mat = np.tile(coor2_fn, (num_nodes, 1))
    dist = np.sqrt(np.power(coor1_fn_mat - coor1_bn_mat, 2) + np.power(coor2_fn_mat - coor2_bn_mat, 2))
    min_col_indices = np.argmin(dist, axis=1)
    return set2[min_col_indices]

def _order_edges_pair(sets, coor, id2idx_arr):
    num_nodes = np.shape(sets[0])[0]
    coor_bn = coor[id2idx_arr[sets[0]]]
    coor_bn_mat = np.tile(coor_bn.reshape(-1, 1), (1, num_nodes))
    for i in range(1,4):
        coor_fn = coor[id2idx_arr[sets[i]]]
        coor_fn_mat = np.tile(coor_fn, (num_nodes, 1))
        dist = np.abs(coor_fn_mat-coor_bn_mat)
        min_col_indices = np.argmin(dist, axis=1)
        sets[i] = sets[i][min_col_indices]
    return sets














