from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


@dataclass(frozen=True)
class PreDirectories:
    """Files and directories used when creating analysis models."""

    initmesh: Path
    partset: Path
    control: Path
    section: Path
    boundary: Path | None
    curve: Path | None

    orientation_csv_dir: Path
    partsmat_dir: Path

    keywordset: Path
    merged_dir: Path


@dataclass(frozen=True)
class PostDirectories:
    """Directories used when processing analysis results."""

    raw_coords_dir: Path
    edge_dropped_dir: Path
    lines_dir: Path
    roughness_dir: Path

    raw_angle_dir: Path
    id_set_angle_dir: Path

    raw_shear_strain_dir: Path
    id_set_shear_strain_dir: Path


@dataclass(frozen=True)
class MappingDirectories:
    """Input and output paths used for spatial-model mapping."""

    input_keyword: Path
    spatial_model_dir: Path
    plots_dir: Path


def rho_dir_name(rho: float | None) -> str:
    """Convert rho into the common directory name."""

    if rho is None:
        return "rho_none"
    return f"rho_{rho:g}"


def build_pre_directories(
    seed: int,
    rho: float | None = None,
) -> PreDirectories:
    """Build files and directories used to create one model."""

    rho_name = rho_dir_name(rho)

    inputs_dir = ROOT / "inputs"
    models_dir = ROOT / "models"

    keyword_dir = inputs_dir / "keywords"
    orientation_dir = inputs_dir / "orientation"
    partsmat_root_dir = inputs_dir / "partsmat"

    consts_dir = keyword_dir / "consts"
    rho_keyword_dir = keyword_dir / f"keyword_{rho_name}"

    partset = consts_dir / f"partset_seed{seed}.k"
    initmesh = consts_dir / "initmesh.k"
    control = consts_dir / "control.k"
    section = consts_dir / "section.k"

    if rho is None:
        boundary = None
        curve = None
    else:
        boundary = rho_keyword_dir / f"boundary_{rho_name}.k"
        curve = rho_keyword_dir / f"curve_{rho_name}.k"

    orientation_csv_dir = orientation_dir / f"texture_seed{seed}"
    partsmat_dir = partsmat_root_dir / f"partsmat_seed{seed}"

    pre_model_dir = models_dir / rho_name / f"{rho_name}_seed{seed}"

    keywordset = pre_model_dir / f"keywordset_seed{seed}.k"
    merged_dir = pre_model_dir / f"merged_seed{seed}"

    return PreDirectories(
        initmesh=initmesh,
        partset=partset,
        control=control,
        boundary=boundary,
        section=section,
        curve=curve,
        orientation_csv_dir=orientation_csv_dir,
        partsmat_dir=partsmat_dir,
        keywordset=keywordset,
        merged_dir=merged_dir,
    )


def build_post_directories(
    rho: float,
    seed: int,
) -> PostDirectories:
    """Build directories used to process one analysis result."""

    rho_name = rho_dir_name(rho)

    outputs_dir = ROOT / "outputs"
    # Contents of outputs_dir:
    post_model_dir = outputs_dir / rho_name / f"{rho_name}_seed{seed}"
    coords_dir = post_model_dir / "coords"
    angle_dir = post_model_dir / "angles"
    shear_strain_dir = post_model_dir / "shear_strains"
    # Contents of coords_dir:
    raw_coords_dir = coords_dir / "rawdata"
    edge_dropped_dir = coords_dir / "edge_dropped"
    lines_dir = coords_dir / "lines"
    roughness_dir = coords_dir / "roughness"
    # Contents of angle_dir:
    raw_angle_dir = angle_dir / "rawdata"
    id_set_angle_dir = angle_dir / "id_set"
    # Contents of shear_strain_dir:
    raw_shear_strain_dir = shear_strain_dir / "rawdata"
    id_set_shear_strain_dir = shear_strain_dir / "id_set"

    return PostDirectories(
        raw_coords_dir=raw_coords_dir,
        edge_dropped_dir=edge_dropped_dir,
        lines_dir=lines_dir,
        roughness_dir=roughness_dir,
        raw_angle_dir=raw_angle_dir,
        id_set_angle_dir=id_set_angle_dir,
        raw_shear_strain_dir=raw_shear_strain_dir,
        id_set_shear_strain_dir=id_set_shear_strain_dir,
    )


def build_mapping_directories(seed: int) -> MappingDirectories:
    """Build paths for the solver-independent spatial model and its plots."""
    input_keyword = ROOT / "inputs" / "keywords" / "consts" / f"partset_seed{seed}.k"
    spatial_model_dir = ROOT / "database" / "spatial_model" / f"seed{seed}"

    return MappingDirectories(
        input_keyword=input_keyword,
        spatial_model_dir=spatial_model_dir,
        plots_dir=spatial_model_dir / "plots",
    )
