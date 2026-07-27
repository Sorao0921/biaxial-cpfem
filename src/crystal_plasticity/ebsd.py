from src.crystal_plasticity.ebsd_grains import ebsd_grains
from src.crystal_plasticity.ebsd_points import ebsd_points


class ebsd(object):
    points_set = ebsd_points("")
    grains_set = ebsd_grains("")

    # input functions
    def __init__(self, input_file_dir: str):
        if input_file_dir.endswith(".txt"):
            print("INFO: Reading ebsd information from self defined text")
            self.points_set = ebsd_points(input_file_dir)
            self.grains_set = ebsd_grains(input_file_dir)
        else:
            self.points_set = ebsd_points("")
            self.grains_set = ebsd_grains("")
            print("INFO: Creating empty ebsd set")
