import numpy as np
from src.crystal_plasticity.ebsd import ebsd
from src.crystal_plasticity.ebsd_points import ebsd_points
from src.others.geometry_tools import (
    is_point_in_convex_polygon,
    typical_retangle_region,
)
from src.others.plot_tools import visualization
from src.pre_process.keyword_file import keyword_file
from src.pre_process.mesh import mesh


def ebsd_to_mesh_indexing(ebsd_set: ebsd, mesh_set: mesh):

    # define the region
    print("INFO: Begin ebsd_to_mesh.")
    full_region = typical_retangle_region(
        np.amin(mesh_set.node_set.x_array),
        np.amin(mesh_set.node_set.y_array),
        np.amax(mesh_set.node_set.x_array),
        np.amax(mesh_set.node_set.y_array),
    )
    num_regions_x, num_region_y = 11, 11
    num_region = num_regions_x * num_region_y
    sub_region_array = full_region.divide_into_sub_regions(num_regions_x, num_region_y)
    print(
        rf"INFO: Partition full region into {num_regions_x} * {num_region_y} sub region for speed-up."
    )

    # partitioning the region of mesh_set
    print("INFO: Begin partitioning the region of mesh for speed-up")
    overlap_elem_id_array_list = [np.zeros(0, dtype=int)] * num_region

    for i in range(num_region):
        sub_region = sub_region_array[i]

        overlap_elem_id_array = []
        for j in range(mesh_set.elem_set.num):
            elem_id = mesh_set.elem_set.id_array[j]

            elem_node_list = mesh_set.elem_set.nodes_list[j]
            elem_num_node = len(elem_node_list)
            elem_node_x_array = np.empty(elem_num_node)
            elem_node_y_array = np.empty(elem_num_node)
            for k in range(elem_num_node):
                node_id = elem_node_list[k]
                node_x = mesh_set.node_set.x_array[node_id - 1]
                node_y = mesh_set.node_set.y_array[node_id - 1]

                elem_node_x_array[k] = node_x
                elem_node_y_array[k] = node_y

            if sub_region.overlap_elem(elem_node_x_array, elem_node_y_array) == True:
                overlap_elem_id_array.append(elem_id)

        overlap_elem_id_array = np.array(overlap_elem_id_array)
        overlap_elem_id_array_list[i] = overlap_elem_id_array
        print(
            rf"INFO: Partitioning the region of mesh for speed-up in progress - {i + 1}/{num_region}"
        )

    print("INFO: Finish partitioning the region of mesh for speed-up")

    # update the sub_region base on the element
    for i in range(num_region):
        sub_region = sub_region_array[i]
        overlap_elem_id_array = overlap_elem_id_array_list[i]

        overlap_elem_nodes_list = mesh_set.elem_set.nodes_list[
            overlap_elem_id_array - 1
        ]
        overlap_elem_nodes_list = overlap_elem_nodes_list.flatten()
        overlap_elem_nodes_list = np.unique(overlap_elem_nodes_list)

        x_array = mesh_set.node_set.x_array[overlap_elem_nodes_list - 1]
        y_array = mesh_set.node_set.y_array[overlap_elem_nodes_list - 1]

        sub_region_array[i] = typical_retangle_region(
            np.amin(x_array), np.amin(y_array), np.amax(x_array), np.amax(y_array)
        )

    # partitioning the region of ebsd_set
    print("INFO: Begin partitioning the region of ebsd points for speed-up")
    partition_points_id_array_list = partition_points_by_sub_regions_list(
        ebsd_set.points_set, sub_region_array
    )
    print("INFO: Finish partitioning the region of ebsd points for speed-up")

    # Mapping the ebsd points to the elements domain
    print("INFO: Begin mapping ebsd points into element domains of mesh")
    map_point_id_elem_id = np.zeros(ebsd_set.points_set.num_points, dtype=int)
    index_progress = 0
    for i in range(num_region):
        sub_mesh_elems_id_array = overlap_elem_id_array_list[i]
        sub_ebsd_points_id_array = partition_points_id_array_list[i]
        # mapping for the first points
        for j in range(len(sub_ebsd_points_id_array)):
            point_id = sub_ebsd_points_id_array[j]
            point_x = ebsd_set.points_set.x_array[point_id - 1]
            point_y = ebsd_set.points_set.y_array[point_id - 1]

            for k in range(len(sub_mesh_elems_id_array)):
                elem_id = sub_mesh_elems_id_array[k]
                node_list = mesh_set.elem_set.nodes_list[elem_id - 1]

                polygon_x_array = []
                polygon_y_array = []

                for node_id in node_list:
                    polygon_x_array.append(mesh_set.node_set.x_array[node_id - 1])
                    polygon_y_array.append(mesh_set.node_set.y_array[node_id - 1])

                polygon_x_array = np.array(polygon_x_array, dtype=float)
                polygon_y_array = np.array(polygon_y_array, dtype=float)

                if (
                    is_point_in_convex_polygon(
                        point_x, point_y, polygon_x_array, polygon_y_array
                    )
                    == True
                ):
                    map_point_id_elem_id[point_id - 1] = elem_id
                    index_progress += 1
                    print(
                        rf"INFO: Mapping ebsd points into element domains of mesh in progress - {index_progress}/{ebsd_set.points_set.num_points}."
                    )
                    break

    return map_point_id_elem_id
    # check
    # for i in range(len(map_point_id_elem_id)):
    #     if map_point_id_elem_id[i] == 0:
    #         print("unmap point")


def partition_points_by_sub_regions_list(points_set: ebsd_points, sub_region_array):
    num_sub_region = len(sub_region_array)
    partition_points_id_array_list = [np.zeros(0, dtype=int)] * num_sub_region

    dynamic_id_array = points_set.id_array

    for i in range(num_sub_region):
        sub_region = sub_region_array[i]

        partition_points_id_array = []
        partition_points_idx_array_in_dynamic_array = []
        for j in range(len(dynamic_id_array)):
            point_id = dynamic_id_array[j]
            point_idx = point_id - 1

            x = points_set.x_array[point_idx]
            y = points_set.y_array[point_idx]

            if sub_region.in_region_and_boundary(x, y) == True:
                partition_points_id_array.append(point_id)
                partition_points_idx_array_in_dynamic_array.append(j)

        partition_points_id_array_list[i] = np.array(
            partition_points_id_array, dtype=int
        )
        dynamic_id_array = np.delete(
            dynamic_id_array, partition_points_idx_array_in_dynamic_array
        )
        print(
            rf"INFO: Partitioning the region of ebsd points for in progress - {i + 1}/{num_sub_region}"
        )

    return partition_points_id_array_list


def ebsd_to_mesh_partitioning(
    map_elem_id_array, ebsd_set: ebsd, mesh_set: mesh, output_mesh_dir: str
):

    # elem_id_array, points_id_array_list = read_media_file(media_file_dir)
    points_id_array_list = [[] for _ in range(mesh_set.elem_set.num)]
    for i in range(len(map_elem_id_array)):
        elem_id = map_elem_id_array[i]
        point_id = i + 1
        points_id_array_list[elem_id - 1].append(point_id)

    # detect which has points id, which does not have point
    free_elem_id_list = []
    fix_elem_id_list = []

    for i in range(mesh_set.elem_set.num):
        elem_id = i + 1
        if len(points_id_array_list[i]) == 0:
            free_elem_id_list.append(elem_id)
        else:
            fix_elem_id_list.append(elem_id)

    # give the grain id to the element which has points
    new_part_id_array = np.zeros(mesh_set.elem_set.num, dtype=int)
    new_part_id_array.fill(10000)
    for i in range(len(fix_elem_id_list)):
        elem_id = fix_elem_id_list[i]
        elem_inx = elem_id - 1
        inside_points_list = points_id_array_list[elem_inx]
        grain_id = index_element_grain_id_by_point_list(
            inside_points_list, ebsd_set.points_set.part_id_array
        )
        new_part_id_array[elem_inx] = grain_id
        print(
            rf"INFO: Partitioning the shell mesh (with point) in progress - {i + 1}/{len(fix_elem_id_list)}"
        )

    # give the grain id to the free elements which doesn't have node
    num_free_elem = len(free_elem_id_list)
    progress = 0
    while len(free_elem_id_list) > 0:
        for elem_id in free_elem_id_list:
            ajacent_elem_array = mesh_set.elem_set.search_ajacent_elem(elem_id)

            # append all the points to a list
            point_list = []
            for k in range(len(ajacent_elem_array)):
                adjacent_elem_id = ajacent_elem_array[k]
                point_list.extend(points_id_array_list[adjacent_elem_id - 1])

            if len(point_list) == 0:
                continue
            else:
                points_id_array_list[elem_id - 1] = point_list
                grain_id = index_element_grain_id_by_point_list(
                    point_list, ebsd_set.points_set.part_id_array
                )
                new_part_id_array[elem_id - 1] = grain_id
                free_elem_id_list.remove(elem_id)
                progress += 1
                print(
                    rf"INFO: Partitioning the shell mesh (without points) in progress - {progress}/{num_free_elem}"
                )

    mesh_set.elem_set.part_list = new_part_id_array

    output_mesh_io = keyword_file(output_mesh_dir, "w").file_io
    mesh_set.write_keyword(output_mesh_io)


def read_media_file(media_file_dir: str):
    file_io = open(media_file_dir, "r")
    lines = file_io.readlines()

    num_elem = len(lines)
    elem_id_array = np.empty(len(lines), dtype=int)

    points_id_array_list = [None] * num_elem

    for i in range(num_elem):
        line = lines[i]
        info = line.split(",")[:-1]

        elem_id_array[i] = info[0]

        point_info = info[1:]
        num_points = len(point_info)
        points_array = np.empty(num_points, dtype=int)
        for j in range(num_points):
            points_array[j] = point_info[j]
        points_id_array_list[i] = points_array

    return elem_id_array, points_id_array_list


def index_element_grain_id_by_point_list(
    points_id_array, points_set_grain_id_array
) -> int:
    num_points = len(points_id_array)

    belong_grain_id_array = []

    for i in range(num_points):
        points_id = points_id_array[i]
        point_idx = points_id - 1
        belong_grain_id = points_set_grain_id_array[point_idx]
        belong_grain_id_array.append(belong_grain_id)

    belong_grain_id_array = np.array(belong_grain_id_array, dtype=int)

    result_grain_id = ret_most_frequent_values(belong_grain_id_array)

    return result_grain_id


def ret_most_frequent_values(array):
    freq = np.bincount(array)
    return np.argmax(freq)
