import numpy as np

class keyword_file(object):
    file_dir = None
    file_io = None

    def __init__(self,file_dir,io_style):
        self.file_dir = file_dir
        self.file_io = open(file_dir,io_style)

    def read_lines(self):
        return self.file_io.readlines()

    def write_lines(self, lines):
        for line in lines:
            self.file_io.write(line)

    def close_file(self):
        self.file_io.close()

# functions to get lines from keyword
def ret_form_lines(lines, header_str:str):
    """
    Return a form of lists of lines, which is related to the target headers
    :param header_str: the target str, ex. *NODES
    :return: a form of lists of lines, without the comment lines
    """
    # get the beginning and end index list of one type of section
    begin_index_list, end_index_list = _ret_begin_end_index_of_section(lines, header_str)
    # cut the lists of lines from keyword, remove the comment lines,
    # and return a form of lists
    cut_lines_form = []
    for i in range(len(begin_index_list)):
        begin_index, end_index = begin_index_list[i], end_index_list[i]
        cut_lines = lines[begin_index: end_index]
        cut_lines = _remove_comment_in_lines(cut_lines)
        cut_lines_form.append(cut_lines)
    # return
    return cut_lines_form

def _ret_begin_end_index_of_section(lines, header_str:str):
    """
    Return two lists, begin index list and end index list of one type of section
    which is related to the target headers
    :param header_str: the target str, ex. *NODES
    :return: begin index list, end index list
    """
    begin_index_list = []
    end_index_list = []
    # get the beginning index of one section
    for i in range(len(lines)):
        line = lines[i]
        if line.startswith(header_str):
            begin_index_list.append(i)
    # get the end index correspond to the beginning index, for one section
    for begin_index in begin_index_list:
        for i in range(begin_index + 1, len(lines)):
            line = lines[i]
            if line.startswith("*"):
                end_index_list.append(i)
                break
            if i == (len(lines) - 1):  # go to the end line
                end_index_list.append(i + 1)
    return begin_index_list, end_index_list

def _remove_comment_in_lines(lines):
    """
    Remove the comment line in a list of lines
    :param lines: a list of lines for keyword
    :return: a list of lines without the comment line
    """
    remove_lines = []
    for line in lines:
        if line.startswith('$') or line.startswith('$$') or line.startswith('$#'):
            remove_lines.append(line)
    for remove_line in remove_lines:
        lines.remove(remove_line)
    return lines

def ret_lines_without_sections(lines, header_str: str):
    """
    Return list of lines that cutting out the certain sections,
    sections was chosen by the header keyword, ex. *NODE
    :param lines: a list of lines for keyword
    :param header_str: the target str, ex. *NODES
    :return:
    """
    # get the range of selected sections
    begin_index_list, end_index_list = \
        _ret_begin_end_index_of_section(lines,header_str)
    # create an index list for all the lines
    all_index_list = np.arange(0,len(lines)-1,dtype=int)
    # get the index list of the desired lines to be deleted
    del_index_list = []
    for i in range(len(begin_index_list)):
        begin_index = begin_index_list[i]
        end_index = end_index_list[i]
        alist = np.arange(begin_index,end_index,dtype=int).tolist()
        del_index_list.append(alist)
    del_index_list = np.array(del_index_list)
    del_index_list = np.unique(del_index_list)
    # get the lines which will be kept along
    exi_index_list = [x for x in all_index_list if x not in del_index_list]
    # get the lines after cutting
    cut_lines = [lines[i] for i in exi_index_list]
    # return
    return cut_lines

def ret_solid_set(lines):
    """
    return the id array of the solid set keyword inside the keyword lines,
    the header is *SET_SOLID_TITLE
    :param lines: a raw lines of keyword
    :return: id array of element id from solid set
    """
    solid_set_lines = ret_form_lines(lines,'*SET_SOLID_TITLE')[0]
    solid_set_lines = solid_set_lines[3:]
    elem_id_array_with_zero = np.concatenate([np.fromstring(line, sep=' ',dtype=int) for line in solid_set_lines])
    elem_id_array = elem_id_array_with_zero[elem_id_array_with_zero != 0]
    return elem_id_array

def _concatenate_lines_of_vals_to_arr(lines):
    temp =  np.concatenate([np.fromstring(line, sep=' ',dtype=int) for line in lines])
    return temp

def ret_node_list(lines):
    lines_form = ret_form_lines(lines, '*SET_NODE_LIST_TITLE')
    num = len(lines_form)
    amap = {}
    for i in range(num):
        case_lines = lines_form[i][1:]
        info_lines = _remove_comment_in_lines(case_lines)
        key = info_lines[0].replace('\n','')
        info_lines = info_lines[2:]
        vals = _concatenate_lines_of_vals_to_arr(info_lines)
        vals = vals[vals != 0]
        amap[key] = vals
    return amap



