from math import floor

import numpy as np


class voro_seeds(object):
    num = 0
    l_x, l_y, l_z = 0, 0, 0
    x_array = np.empty(0)
    y_array = np.empty(0)
    z_array = np.empty(0)
    id_array = np.empty(0)

    def __init__(self):
        pass

    def init_region_box(self, l_x, l_y, l_z):
        self.l_x = l_x
        self.l_y = l_y
        self.l_z = l_z

    def generate_seeds(self, grain_diameter_xyz, diviation=0.2):
        grain_diameter_x = grain_diameter_xyz[0]
        grain_diameter_y = grain_diameter_xyz[1]
        grain_diameter_z = grain_diameter_xyz[2]

        seed_dx = grain_diameter_x
        seed_dy = grain_diameter_y
        seed_dz = grain_diameter_z

        num_seed_x = floor(self.l_x / seed_dx + 0.5)
        num_seed_y = floor(self.l_y / seed_dy + 0.5)
        num_seed_z = floor(self.l_z / seed_dz + 0.5)
        self.num = num_seed_x * num_seed_y * num_seed_z

        seed_x_array_init = np.zeros(self.num, dtype=float)
        seed_y_array_init = np.zeros(self.num, dtype=float)
        seed_z_array_init = np.zeros(self.num, dtype=float)
        idx = 0
        for k in range(num_seed_z):
            for j in range(num_seed_y):
                for i in range(num_seed_x):
                    seed_x_array_init[idx] = 0.5 * seed_dx + i * seed_dx
                    seed_y_array_init[idx] = 0.5 * seed_dy + j * seed_dy
                    seed_z_array_init[idx] = 0.5 * seed_dz + k * seed_dz
                    idx = idx + 1

        seed_x_array_tmp = np.zeros(self.num, dtype=float)
        seed_y_array_tmp = np.zeros(self.num, dtype=float)
        seed_z_array_tmp = np.zeros(self.num, dtype=float)
        idx = 0
        for i in range(self.num):
            if seed_x_array_init[i] * seed_y_array_init[i] <= self.l_x * self.l_y:
                seed_x_array_tmp[idx] = seed_x_array_init[i]
                seed_y_array_tmp[idx] = seed_y_array_init[i]
                seed_z_array_tmp[idx] = seed_z_array_init[i]
                idx = idx + 1

        self.x_array = np.zeros(self.num, dtype=float)
        self.y_array = np.zeros(self.num, dtype=float)
        self.z_array = np.zeros(self.num, dtype=float)

        var_x = diviation * grain_diameter_x
        var_y = diviation * grain_diameter_y
        var_z = diviation * grain_diameter_z
        for i in range(self.num):
            r = np.random.randn()
            self.x_array[i] = seed_x_array_tmp[i] + var_x * r
            r = np.random.randn()
            self.y_array[i] = seed_y_array_tmp[i] + var_y * r
            r = np.random.randn()
            self.z_array[i] = seed_z_array_tmp[i] + var_z * r

        self.id_array = np.random.permutation(self.num)
