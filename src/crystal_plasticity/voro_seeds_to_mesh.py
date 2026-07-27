import numpy as np
from src.crystal_plasticity.voro_seeds import voro_seeds
from src.pre_process.mesh import mesh


def voro_seeds_to_mesh(seeds: voro_seeds, solid_mesh: mesh):
    grain_id_array = np.zeros(solid_mesh.elem_set.num, dtype=int)

    for i in range(solid_mesh.elem_set.num):
        elem_id = solid_mesh.elem_set.id_array[i]
        x, y, z = solid_mesh.ret_elem_center_pos(elem_id)

        distance_array = np.zeros(seeds.num, dtype=float)
        # dx = np.zeros(seeds.num, dtype=float)
        # dy = np.zeros(seeds.num, dtype=float)
        # dz = np.zeros(seeds.num, dtype=float)
        # for j in range(seeds.num):
        #     distance_array[j] = \
        #         pow(x - seeds.x_array[j], 2) + pow(y - seeds.y_array[j], 2) + pow(z - seeds.z_array[j], 2)

        # Vectorized version
        dx = np.full(seeds.num, x, dtype=float)
        dy = np.full(seeds.num, y, dtype=float)
        dz = np.full(seeds.num, z, dtype=float)

        dx = dx - seeds.x_array
        dy = dy - seeds.y_array
        dz = dz - seeds.z_array

        dx_2 = np.power(dx, 2)
        dy_2 = np.power(dy, 2)
        dz_2 = np.power(dz, 2)

        distance_array = dx_2 + dy_2 + dz_2

        idx = np.argmin(distance_array)
        grain_idx = seeds.id_array[idx]
        grain_id_array[elem_id - 1] = grain_idx + 1
        print(
            rf"INFO: Partitioning the solid mesh by voronoi tex method in progress - {i + 1}/{solid_mesh.elem_set.num}"
        )

    solid_mesh.elem_set.part_list = grain_id_array
