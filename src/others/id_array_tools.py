import numpy as np
from tqdm import tqdm

def ret_idx_by_id(id ,id_array) -> int:
    """
    calculate the index of the id in the id_array
    :param id:
    :param id_array:
    :return: index
    """
    return np.where(id_array == id)[0][0]

def ret_indices_of_id_array(id_array,selected_id_array):
    """
    given a selected id list, return the indices of the selected id
    from the id_array
    :param selected_id:
    :return:
    """
    num = len(selected_id_array)
    indices = np.zeros(num,dtype=int)
    for i in range(num):
        selected_id = selected_id_array[i]
        indices[i] = np.where(id_array == selected_id)[0][0]
    return indices

def ret_id2idx_map_array(id_array):
    """
    provide an array for mapping the id to the idx
    given the id, will return the idx of the given id in the id array
    :param id_array:
    :return:
    """
    renumber_flag = True
    for i in tqdm(range(len(id_array))):
        if id_array[i] != i+1:
            renumber_flag = False
            break
    if not renumber_flag:
        map_array = np.zeros(max(id_array)+1,dtype=int)
        for i in tqdm(range(len(id_array))):
            map_array[id_array[i]] = np.where(id_array == id_array[i])[0][0]
    else:
        map_array = np.arange(len(id_array))
        map_array = np.insert(map_array, 0, 0)
    return map_array

def sort_array_together_correspond_to_first_array(a,b):
    """
    sort the two array together, the array b is following array a
    :param a: The array to be sorted, and provide the reference
    :param b: THe array to be sorted based on the array a
    :return: sorted_a np.array(), sorted_b np.array()
    """
    indices = np.argsort(a)
    sorted_a = a[indices]
    sorted_b = b[indices]
    return sorted_a, sorted_b

def extend_id2idx_map_array(id2idx_map_array, new_ids):
    """
    when make some new id, extend the corresponding id2idx map array
    :param id2idx_map_array: the previous map
    :param new_ids: the new extension of id array
    :return: the updated map
    """
    # init
    id2idx_map_array_new = np.copy(id2idx_map_array)
    # obtain the previous and new max id
    prev_max_id = len(id2idx_map_array)-1
    new_max_id = max(new_ids)
    # do extension
    ext_map = np.zeros(new_max_id - prev_max_id, dtype=int)
    id2idx_map_array_new = np.append(id2idx_map_array_new, ext_map, axis=0)
    idxs = new_ids - 1
    id2idx_map_array_new[new_ids] = idxs
    return id2idx_map_array_new