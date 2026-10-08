from io import BytesIO
from PIL import Image
from src.dashboard.export import combine_map_pngs


def test_combined_png_preserves_order_resolution_and_white_empty_cell():
    def png(size, color):
        output = BytesIO()
        Image.new("RGBA", size, color).save(output, format="PNG")
        return output.getvalue()
    data = combine_map_pngs([png((20,10),'red'), png((10,20),'blue'),
                             png((20,20),(0,0,0,0))], 2, dpi=100)
    with Image.open(BytesIO(data)) as image:
        assert image.size == (48,48)
        assert image.getpixel((0,0)) == (255,0,0)
        assert image.getpixel((33,0)) == (0,0,255)
        assert image.getpixel((0,28)) == (255,255,255)
        assert image.getpixel((35,35)) == (255,255,255)
        assert abs(image.info['dpi'][0] - 100) < .1


def test_names_include_actual_initial_state_and_comparison_values():
    from types import SimpleNamespace
    from src.dashboard.export import map_png_name, combined_png_name
    record = SimpleNamespace(rho=.5, seed=2, texture='cube', sd=4, state=13)
    assert map_png_name('z_slip_activity', record) == 'z_slip_activity_rho0.5_seed2_cube_sd4_state13_from_state12.png'
    assert map_png_name('initial_taylor', record, initial=True).endswith('state01_view_state13.png')
    other = SimpleNamespace(rho=.5, seed=2, texture='cube', sd=4, state=2)
    assert combined_png_name('taylor_comparison', [record, other]) == 'taylor_comparison_rho0.5_seed2_texturecube_sd4_state02-13.png'
