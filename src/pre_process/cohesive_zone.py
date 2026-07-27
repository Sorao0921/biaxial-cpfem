from os import error
from src.pre_process.mesh import mesh
import numpy as np
from src.pre_process.mesh_edge import edge_set
from src.others.math_tools import cal_p2p_vects, cal_vect_prod, cal_trans_by_vect_dis, normalize_vect
import os.path

# main functions
def insert_czm(model:mesh, particle_id: int, thickness: float):
    if ~np.any( model.elem_set.part_list == particle_id):
        raise error(f'Error: None of the element is assigned to this particle id {particle_id}\n')
    # init info
    print(f'INFO: Beginning inserting cohesive zone.\n')
    particle_elem_ids, matrix_elem_ids, share_nodes_ids = _ret_particle_matrix_info(model, particle_id)
    # init edges
    edges = _init_boundary_edges(model, share_nodes_ids, particle_elem_ids)
    # generate new nodes (copied of the shared nodes)
    model, new_nodes_ids = _gen_new_nodes(model, share_nodes_ids)
    # offset share nodes to outside direction
    trans = _cal_share_nodes_translation(edges, model, particle_id, thickness)
    model.node_set.offset_node_set(trans, 'xyz')
    # the inner element at the boundary inside the particle should change it nodes to new nodes
    # -> the outside element retained with the previous boundary nodes, and it would be offset, based on the last step
    model, nodes_replaced_map = _replace_nodes_inner_elem(model, particle_id, share_nodes_ids, new_nodes_ids)
    # create cohesive element
    part_id = max(model.elem_set.part_list)+1
    model, eids = _gen_cohesive_elems(edges, model, nodes_replaced_map, part_id)
    print(f'INFO: Finishing inserting cohesive zone with {len(eids)} cohesive zone elements.\n')
    return model

# init mesh information
def _ret_particle_matrix_info(model: mesh, particle_id: int):
    # obtain inside node
    particle_elem_idxs = np.where(model.elem_set.part_list == particle_id)
    particle_elem_ids = model.elem_set.id_array[particle_elem_idxs]
    particle_node_ids = model.elem_set.nodes_list[particle_elem_idxs]
    particle_node_ids_unique = np.unique([item for sublist in particle_node_ids for item in sublist])
    # obtain outside node
    matrix_elem_idx = np.where(model.elem_set.part_list != particle_id)
    matrix_elem_ids = model.elem_set.id_array[matrix_elem_idx]
    matrix_node_ids = model.elem_set.nodes_list[matrix_elem_idx]
    matrix_node_ids_unique = np.unique([item for sublist in matrix_node_ids for item in sublist])
    # obtain the share node
    share_nodes_ids = np.intersect1d(particle_node_ids_unique, matrix_node_ids_unique)
    return particle_elem_ids, matrix_elem_ids, share_nodes_ids

def _init_boundary_edges(model: mesh, share_nodes_ids:np.ndarray, particle_elem_ids: np.ndarray):
    # init the overall edges
    edges = edge_set()
    edges.init_from_elems(model.elem_set)
    # obtain the relevant edges idx
    bool_arr = np.isin(edges.nodes_arr, share_nodes_ids)
    idx_arr = np.where(np.all(bool_arr, axis=1))[0]
    edges = edges.crop_new_set(idx_arr)
    # if an edge share by two inner element it should be deleted
    bool_arr = np.isin(edges.mother_elem_arr, particle_elem_ids)
    idx_arr = np.where(~np.all(bool_arr == True, axis=1))[0]
    edges = edges.crop_new_set(idx_arr)
    # if an edge share by two outer element it should be deleted
    matrix_elem_ids = np.setdiff1d(model.elem_set.id_array, particle_elem_ids)
    bool_arr = np.isin(edges.mother_elem_arr, matrix_elem_ids)
    idx_arr = np.where(~np.all(bool_arr == True, axis=1))[0]
    edges = edges.crop_new_set(idx_arr)
    return edges

def _cal_share_nodes_translation(edges: edge_set, model: mesh, particle_id: int, thickness: float):
    # obtain the corresponding inner and outside elems
    particle_elem_idxs = np.where(model.elem_set.part_list == particle_id)
    particle_elem_ids = model.elem_set.id_array[particle_elem_idxs]
    temp = np.isin(edges.mother_elem_arr, particle_elem_ids)
    inner_elem_ids = edges.mother_elem_arr[np.isin(edges.mother_elem_arr, particle_elem_ids)]
    # # check bugs
    # if len(inner_elem_ids) != edges.num:
    #     temp = np.isin(edges.mother_elem_arr, particle_elem_ids)
    #     bugs_idxs = np.all(temp == False, axis=1)
    # obtain the inner elem center position for each edge
    inner_elem_center_coor = np.column_stack(model.ret_elem_center_pos(inner_elem_ids))
    # obtain the mid point of the edge
    midpoint_coor = edges.ret_midnode_coor(model.node_set)
    # reverse the direction of the normal vector to point to outside
    judge_vects = cal_p2p_vects(midpoint_coor, inner_elem_center_coor)
    normal_vect = edges.ret_normal_dir(model.node_set)
    reverse_idx = np.where(cal_vect_prod(judge_vects, normal_vect) > 0)[0]
    # reverse_idx = np.where(cal_vect_prod(judge_vects, normal_vect) < 0)[0]
    normal_vect[reverse_idx, 0:] = -normal_vect[reverse_idx, 0:]
    # decide the vector for node translation
    vect = np.zeros(shape=(model.node_set.num, 3), dtype=float)
    for i in range(edges.num_nodes):
        nidx = model.node_set.id2idx_map_array[edges.nodes_arr[:, i]]
        np.add.at(vect, nidx, normal_vect)
    unit_vect = normalize_vect(vect)
    # calculate the translation direction by the normal vector, and the given thickness factor of czm
    trans = cal_trans_by_vect_dis(unit_vect, thickness)
    return trans

def _gen_new_nodes(model: mesh, share_nodes_ids: np.ndarray):
    share_nodes_idxs = model.node_set.id2idx_map_array[share_nodes_ids]
    x, y, z = model.node_set.x_array[share_nodes_idxs], model.node_set.y_array[share_nodes_idxs], \
    model.node_set.z_array[share_nodes_idxs]
    new_nodes_ids = model.node_set.add_points(x, y, z)
    return model, new_nodes_ids

def _replace_nodes_inner_elem(model: mesh, particle_id: int, share_nodes_ids: np.ndarray, new_nodes_ids: np.ndarray):
    # create replace map
    nodes_replaced_map = np.zeros(max(model.node_set.id_array) + 1, dtype=int)
    nodes_replaced_map[model.node_set.id_array] = model.node_set.id_array
    for i in range(len(share_nodes_ids)):
        nodes_replaced_map[share_nodes_ids[i]] = new_nodes_ids[i]
    # replace the nodes for inner element
    all_inner_elem_idxs = np.where(model.elem_set.part_list == particle_id)
    model.elem_set.nodes_list[all_inner_elem_idxs] = nodes_replaced_map[model.elem_set.nodes_list[all_inner_elem_idxs]]
    return model, nodes_replaced_map

def _gen_cohesive_elems(edges: edge_set, model: mesh, nodes_replaced_map: np.ndarray, part_id: int):
    # create new cohesive element
    match edges.dim:
        case 2:
            model, eids = _gen_cohesive_elems_2d(edges, model, nodes_replaced_map, part_id)
        case 3:
            model, eids = _gen_cohesive_elems_3d(edges, model, nodes_replaced_map, part_id)
    return model, eids

def _gen_cohesive_elems_2d(edges: edge_set, model: mesh, nodes_replaced_map: np.ndarray, part_id: int):
    """
    generate 2d cohesive zone elements
    :param edges:
    :param model:
    :param nodes_replaced_map:
    :return:
    """
    nodes = np.zeros(shape=(edges.num, 4), dtype=int)
    parts = np.full(edges.num, part_id)
    for i in range(edges.num):
        n1 = edges.nodes_arr[i]
        n2 = nodes_replaced_map[n1]
        nodes[i, 0:2] = n1
        nodes[i, 2:4] = n2
    nodes = nodes[:, [0, 1, 3, 2]]
    eids = model.elem_set.add_elems(nodes, parts)
    return model, eids

def _gen_cohesive_elems_3d(edges: edge_set, model: mesh, nodes_replaced_map: np.ndarray, part_id: int):
    # init containors
    nodes = np.zeros(shape=(edges.num, 8), dtype=int)
    parts = np.full(edges.num, part_id)
    match edges.num_nodes:
        case 3:
            for i in range(edges.num):
                n1 = edges.nodes_arr[i] # 1,2,3
                n2 = nodes_replaced_map[n1] # 4,5,6
                nodes[i, 0] = n1[0] # 1
                nodes[i, 1] = n1[1] # 2
                nodes[i, 2] = n2[1] # 3
                nodes[i, 3] = n2[0] # 4
                nodes[i, 4] = n1[2] # 5
                nodes[i, 5] = n1[2] # 6
                nodes[i, 6] = n2[2] # 7
                nodes[i, 7] = n2[2] # 8
        case 4:
            for i in range(edges.num):
                n1 = edges.nodes_arr[i]
                n2 = nodes_replaced_map[n1]
                nodes[i, 0:4] = n1
                nodes[i, 4:8] = n2
    eids = model.elem_set.add_elems(nodes, parts)
    return model, eids

