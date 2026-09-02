from __future__ import annotations

from pathlib import Path

from src.config.pipeline_paths import PreDirectories, build_pre_directories
from src.make_model_process.merge_partsmat import merge_keywordset_and_partsmat
from src.make_model_process.write_keyword import KeywordFiles, KeywordSetBuilder

# ============================================================
# Case settings
# Change RHO and SEED to select another post-processing directory.
# ============================================================
RHO = 1
SEED = 3

CSV_GLOB = "*.csv"
OVERWRITE_EXISTING = False


# ===========================================================
# Do not change below this line unless you have to.
# ===========================================================
def validate_inputs(
    paths: PreDirectories, overwrite_existing: bool = OVERWRITE_EXISTING
) -> None:
    """Raise an error before processing when required inputs are missing."""
    required_files = {
        "partset": paths.partset,
        "control": paths.control,
        "boundary": paths.boundary,
        "section": paths.section,
        "curve": paths.curve,
    }
    required_dirs = {
        "orientation_csv_dir": paths.orientation_csv_dir,
        "partsmat_dir": paths.partsmat_dir,
    }

    errors: list[str] = []

    for name, path in required_files.items():
        if not path.is_file():
            errors.append(f"missing file [{name}]: {path}")

    for name, path in required_dirs.items():
        if not path.is_dir():
            errors.append(f"missing directory [{name}]: {path}")

    if errors:
        raise FileNotFoundError("Required inputs were not found:\n" + "\n".join(errors))


def build_keywordset(
    paths: PreDirectories, overwrite_existing: bool = OVERWRITE_EXISTING
) -> None:
    """Combine the fixed and rho-dependent keyword files with the partset."""
    paths.keywordset.parent.mkdir(parents=True, exist_ok=True)

    if paths.keywordset.exists() and not overwrite_existing:
        print(f"Keywordset already exists, skip: {paths.keywordset}")
        return

    builder = KeywordSetBuilder(
        KeywordFiles(
            control_k=paths.control,
            boundary_k=paths.boundary,
            section_k=paths.section,
            curve_k=paths.curve,
        )
    )

    builder.build_keywordset(paths.partset, paths.keywordset)
    print(f"Wrote keywordset: {paths.keywordset}")


def merge_models(
    paths: PreDirectories,
    csv_glob: str = CSV_GLOB,
    overwrite_existing: bool = OVERWRITE_EXISTING,
) -> None:
    """Merge each orientation-matched partsmat file with the keyword set."""
    paths.merged_dir.mkdir(parents=True, exist_ok=True)

    csv_files = sorted(paths.orientation_csv_dir.glob(csv_glob))
    if not csv_files:
        raise FileNotFoundError(
            f"No orientation CSV matched: {paths.orientation_csv_dir / csv_glob}"
        )

    missing_partsmat: list[Path] = []

    for csv_path in csv_files:
        case_name = csv_path.stem
        partsmat_path = paths.partsmat_dir / f"partsmat_{case_name}.k"

        if not partsmat_path.is_file():
            missing_partsmat.append(partsmat_path)
            continue

        output_path = paths.merged_dir / f"{case_name}.k"

        if output_path.exists() and not overwrite_existing:
            print(f"  merged model already exists, skip: {output_path}")
            continue

        merge_keywordset_and_partsmat(
            paths.keywordset,
            partsmat_path,
            output_path,
        )
        print(f"Wrote merged model: {output_path}")

    if missing_partsmat:
        missing_text = "\n".join(str(path) for path in missing_partsmat)
        raise FileNotFoundError(
            "The following partsmat files were not found:\n" + missing_text
        )


def main() -> None:
    paths = build_pre_directories(rho=RHO, seed=SEED)

    print(f"RHO  : {RHO:g}")
    print(f"SEED : {SEED}")

    validate_inputs(paths, overwrite_existing=OVERWRITE_EXISTING)
    build_keywordset(paths, overwrite_existing=OVERWRITE_EXISTING)
    merge_models(paths, overwrite_existing=OVERWRITE_EXISTING)


if __name__ == "__main__":
    main()
