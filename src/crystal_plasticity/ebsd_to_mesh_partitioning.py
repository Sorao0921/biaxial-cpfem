import numpy as np
from src.crystal_plasticity.ebsd import ebsd
from src.crystal_plasticity.ebsd_points import ebsd_points
from src.others.geometry_tools import (
    is_point_in_convex_polygon,
    typical_retangle_region,
)
from src.pre_process.keyword_file import keyword_file
from src.pre_process.mesh import mesh
from src.pre_process.mesh_elem import elem_set


def ebsd_to_mesh_partitioning(map_elem_id_array, ebsd_set: ebsd, mesh_set: mesh):

    # ================================================================= #
    #           processing the map array for element belonging          #
    # ================================================================= #
    print(rf"INFO: Begin processing map array")
    points_id_array_list = [[] for _ in range(mesh_set.elem_set.num)]
    points_id_array_list = process_map_array_to_elem_belonging(
        map_elem_id_array,
        mesh_set.elem_set.num,
        mesh_set.elem_set.id2idx_map_array,
        ebsd_set.points_set.id_array,
    )
    print(rf"INFO: FInish processing map array")

    # ================================================================= #
    #           clasify the element, with points inside, without        #
    # ================================================================= #
    print(rf"INFO: Begin classifying element which haves points or not")
    free_elem_id_list = []
    fix_elem_id_list = []
    free_elem_id_list, fix_elem_id_list = classfied_elem_no_points(
        points_id_array_list, mesh_set.elem_set.id_array
    )
    print(rf"INFO: Finish classifying element which haves points or not")

    # ================================================================= #
    #           partition mesh for element                              #
    # ================================================================= #
    print(rf"INFO: Begin partition mesh")
    new_part_id_array = np.zeros(mesh_set.elem_set.num, dtype=int)
    new_part_id_array = partition_mesh(
        points_id_array_list, fix_elem_id_list, free_elem_id_list, mesh_set, ebsd_set
    )
    mesh_set.elem_set.part_list = new_part_id_array
    print(rf"INFO: Finish partition mesh")

    return new_part_id_array


def partition_mesh(
    points_id_array_list,
    fix_elem_id_list,
    free_elem_id_list,
    mesh_set: mesh,
    ebsd_set: ebsd,
):
    new_part_id_array = np.zeros(mesh_set.elem_set.num, dtype=int)

    # ================================================================= #
    #           partition mesh for element  with points                 #
    # ================================================================= #
    print(rf"INFO: Begin partition mesh with points")
    new_part_id_array = partition_mesh_with_points(
        new_part_id_array,
        fix_elem_id_list,
        points_id_array_list,
        ebsd_set.points_set.part_id_array,
        mesh_set.elem_set.id2idx_map_array,
        ebsd_set.points_set.id2idx_map_array,
    )
    print(rf"INFO: Begin partition mesh without points")

    # ================================================================= #
    #           partition mesh for element without points               #
    # ================================================================= #
    print(rf"INFO: Begin partition mesh without points")
    new_part_id_array = partition_mesh_without_points(
        new_part_id_array,
        free_elem_id_list,
        points_id_array_list,
        mesh_set.elem_set,
        ebsd_set.points_set.part_id_array,
        ebsd_set.points_set.id2idx_map_array,
    )
    print(rf"INFO: Begin partition mesh without points")

    return new_part_id_array


def partition_mesh_with_points(
    new_part_id_array,
    fix_elem_id_list: list,
    points_id_array_list: list,
    ebsd_grain_id_array,
    elem_id2idx_array,
    points_id2idx_array,
):
    for i in range(len(fix_elem_id_list)):
        elem_id = fix_elem_id_list[i]
        elem_idx = elem_id2idx_array[elem_id]
        inside_points_list = points_id_array_list[elem_idx]
        grain_id = index_element_grain_id_by_point_list(
            inside_points_list, ebsd_grain_id_array, points_id2idx_array
        )
        new_part_id_array[elem_idx] = grain_id
        print(
            rf"INFO: Partitioning the shell mesh (with point) in progress - {i + 1}/{len(fix_elem_id_list)}"
        )
    return new_part_id_array


def partition_mesh_without_points(
    new_part_id_array,
    free_elem_id_list: list,
    points_id_array_list: list,
    elem_set: elem_set,
    ebsd_grain_id_array,
    points_id2idx_array,
):
    num_free_elem = len(free_elem_id_list)
    progress = 0
    while len(free_elem_id_list) > 0:
        for elem_id in free_elem_id_list:
            ajacent_elem_array = elem_set.search_ajacent_elem(elem_id)
            elem_idx = elem_set.id2idx_map_array[elem_id]

            # append all the points to a list
            point_list = []
            for k in range(len(ajacent_elem_array)):
                adjacent_elem_id = ajacent_elem_array[k]
                adjacent_elem_idx = elem_set.id2idx_map_array[adjacent_elem_id]
                point_list.extend(points_id_array_list[adjacent_elem_idx])

            if len(point_list) == 0:
                continue
            else:
                points_id_array_list[elem_idx] = point_list
                grain_id = index_element_grain_id_by_point_list(
                    point_list, ebsd_grain_id_array, points_id2idx_array
                )
                new_part_id_array[elem_idx] = grain_id
                free_elem_id_list.remove(elem_id)
                progress += 1
                print(
                    rf"INFO: Partitioning the shell mesh (without points) in progress - {progress}/{num_free_elem}"
                )
    return new_part_id_array


def process_map_array_to_elem_belonging(
    map_elem_id_array, num_elem, elem_id2idx_map_array, point_id_array
):
    points_id_array_list = [[] for _ in range(num_elem)]
    fix_point_indices = np.where(map_elem_id_array > 0)[
        0
    ]  # Points out of the mesh is useless
    for fix_point_idx in fix_point_indices:
        elem_id = map_elem_id_array[fix_point_idx]
        elem_idx = elem_id2idx_map_array[elem_id]
        fix_point_id = point_id_array[fix_point_idx]
        points_id_array_list[elem_idx].append(fix_point_id)
    return points_id_array_list

    # for i in range(len(map_elem_id_array)):
    #     elem_id = map_elem_id_array[i]
    #     elem_idx = elem_id2idx_map_array[elem_id]
    #     point_id = point_id_array[i]
    #     points_id_array_list[elem_idx].append(point_id)
    # return points_id_array_list


def classfied_elem_no_points(points_id_array_list, elem_id_array):
    num_elem = len(points_id_array_list)
    free_elem_id_list = []
    fix_elem_id_list = []
    for i in range(num_elem):
        elem_id = elem_id_array[i]
        if len(points_id_array_list[i]) == 0:
            free_elem_id_list.append(elem_id)
        else:
            fix_elem_id_list.append(elem_id)
    return free_elem_id_list, fix_elem_id_list


def index_element_grain_id_by_point_list(
    points_id_array, points_set_grain_id_array, points_id2idx_array
) -> int:
    num_points = len(points_id_array)

    belong_grain_id_array = []

    for i in range(num_points):
        points_id = points_id_array[i]
        point_idx = points_id2idx_array[points_id]
        belong_grain_id = points_set_grain_id_array[point_idx]
        belong_grain_id_array.append(belong_grain_id)

    belong_grain_id_array = np.array(belong_grain_id_array, dtype=int)

    result_grain_id = ret_most_frequent_values(belong_grain_id_array)

    return result_grain_id


def ret_most_frequent_values(array):
    freq = np.bincount(array)
    return np.argmax(freq)
