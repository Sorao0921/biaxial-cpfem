import os.path

def ret_form_lines(input_file_dir:str, header_str: str):
    """
    Return a form of lists of lines, which is related to the target headers
    :param header_str: the target str, ex. *NODES
    :return: a form of lists of lines, without the comment lines
    """
    begin_index_list = []
    end_index_list = []
    # get the beginning index of one section
    file_io = open(input_file_dir,'r')
    lines = file_io.readlines()
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
    # cut the lists of lines from keyword, remove the comment lines,
    # and return a form of lists
    cut_lines_form = []
    for i in range(len(begin_index_list)):
        begin_index, end_index = begin_index_list[i], end_index_list[i]
        cut_lines = lines[begin_index: end_index]
        cut_lines = _remove_comment_in_lines(cut_lines)
        cut_lines_form.append(cut_lines)

    return cut_lines_form

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

def get_file_extension(file_path):
    """
    Extract the file extension from a given file path
    :param file_path: str
    :return: str, e.g., ".k", ".txt"
    """
    return os.path.splitext(file_path)[1]