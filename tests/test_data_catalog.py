from pathlib import Path

from src.data_catalog.catalog import classify, parse_case


def test_parse_complete_case() -> None:
    path = Path(
        "outputs/rho_-0.5/rho_-0.5_seed3/coords/edge_dropped/"
        "cube_sd7_seed3/coords_cube_sd7_seed3_state04.csv"
    )
    case = parse_case(path)
    assert case.rho == -0.5
    assert case.seed == 3
    assert case.texture == "cube"
    assert case.sd == 7
    assert case.state == 4
    assert case.complete


def test_classification_prefers_edge_dropped_height() -> None:
    result = classify(
        Path("outputs/rho_1/rho_1_seed1/coords/edge_dropped/cube_sd2_seed1_state01.csv")
    )
    assert result.role == "surface_height"
    assert result.representation == "edge_dropped"
    assert result.priority == 10


def test_classification_orientation_metrics() -> None:
    result = classify(
        Path(
            "outputs/rho_0/rho_0_seed2/angles/grain_orientation_metrics/"
            "cube_sd2_seed2/grain_orientation_metrics_cube_sd2_seed2_state13.csv"
        )
    )
    assert result.role == "orientation_metrics"


def test_classification_id_set_shear() -> None:
    result = classify(
        Path(
            "outputs/rho_1/rho_1_seed4/shear_strains/id_set/"
            "id_set_shear_strain_goss_sd9_seed4/shear_strain_goss_sd9_seed4_state03.csv"
        )
    )
    assert result.role == "accumulated_shear_strain"
    assert result.priority == 10


def test_parse_state_from_plot_parent_directory() -> None:
    path = Path(
        "outputs/rho_1/rho_1_seed1/angles/grain_orientation_plots/"
        "id_set_bunge_euler_cube_sd2_seed1/"
        "grain_metrics_cube_sd2_seed1_state01_to_state13/gos_surface.png"
    )
    case = parse_case(path)
    assert case.state == 13
    assert case.complete
