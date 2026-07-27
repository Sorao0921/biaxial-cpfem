
def write_euler_angles(file_dir,phi1_list,Phi_list,phi2_list):
    """
    Write the euler angles to the text file
    :param file_dir: directory to the text file to output euler angle
    :param phi1_list: list of euler angles of the grains
    :param Phi_list: list of euler angles of the grains
    :param phi2_list: list of euler angles of the grains
    :return:
    """
    write_io = open(file_dir,'w+')
    for i in range(len(phi1_list)):
        write_io.write(f'{phi1_list[i]},{Phi_list[i]},{phi2_list[i]}\n')
    write_io.close()

def read_euler_angles(file_dir):
    """
    Write the euler angles to the text file
    :param file_dir: directory to the text file to output euler angle
    :return:
    """
    read_io = open(file_dir,'r')
    lines = read_io.readlines()
    phi1_list = []
    Phi_list = []
    phi2_list = []
    for line in lines:
        info = line.split(',')
        phi1_list.append(info[0])
        Phi_list.append(info[1])
        phi2_list.append(info[2])
    return phi1_list,Phi_list,phi2_list