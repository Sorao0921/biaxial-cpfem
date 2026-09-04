from src.config.pipeline_paths import (
    ANALYSIS_DATABASE,
    DATABASE_DIR,
    INPUTS_DIR,
    MODELS_DIR,
    OUTPUTS_DIR,
    PROJECT_ROOT,
    SPATIAL_MODELS_DIR,
    build_mapping_directories,
    build_post_directories,
    build_pre_directories,
)


def test_top_level_directories_share_project_root() -> None:
    assert INPUTS_DIR == PROJECT_ROOT / "inputs"
    assert MODELS_DIR == PROJECT_ROOT / "models"
    assert OUTPUTS_DIR == PROJECT_ROOT / "outputs"
    assert DATABASE_DIR == PROJECT_ROOT / "database"
    assert ANALYSIS_DATABASE == DATABASE_DIR / "analysis.db"
    assert SPATIAL_MODELS_DIR == DATABASE_DIR / "spatial_model"


def test_case_directories_use_canonical_rho_and_seed_names() -> None:
    pre = build_pre_directories(seed=3, rho=-0.5)
    post = build_post_directories(rho=-0.5, seed=3)
    mapping = build_mapping_directories(seed=3)

    assert pre.keywordset == (
        MODELS_DIR / "rho_-0.5" / "rho_-0.5_seed3" / "keywordset_seed3.k"
    )
    assert post.model_dir == OUTPUTS_DIR / "rho_-0.5" / "rho_-0.5_seed3"
    assert post.equivalent_strain_csv == post.model_dir / "eps_equivalent.csv"
    assert post.orientation_metrics_dir == (
        post.model_dir / "angles/grain_orientation_metrics"
    )
    assert mapping.spatial_model_dir == SPATIAL_MODELS_DIR / "seed3"
