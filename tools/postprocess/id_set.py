from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import pandas as pd
from src.config.pipeline_paths import (
    PreDirectories,
    build_post_directories,
    build_pre_directories,
)
from src.extract_process.eid_pid_mapping import ElementPartMapper

# Settings
RHO = 1
SEED = 1

EULER_COLUMNS = [
    "phi1",
    "Phi",
    "phi2",
]

OUTPUT_COLUMNS = [
    "element_id",
    "part_id",
    "phi1",
    "Phi",
    "phi2",
]


@dataclass(frozen=True)
class EulerStatePaths:
    """
    Paths required to generate element-based Euler-angle CSV files.
    """

    partset_path: Path
    input_euler_path: Path
    raw_output_dir: Path
    output_dir: Path
    raw_filename_template: str
    output_filename_template: str

    def raw_state_path(self, state: int) -> Path:
        """
        Return the raw LS-PrePost Euler-angle CSV path.

        The raw file is used only for state02 and later.
        """
        return self.raw_output_dir / self.raw_filename_template.format(state=state)

    def output_state_path(self, state: int) -> Path:
        """Return the normalized output CSV path."""
        return self.output_dir / self.output_filename_template.format(state=state)


def read_input_euler_csv(
    input_path: Path,
) -> pd.DataFrame:
    """
    Read the input Euler-angle CSV.

    The input CSV must represent one part per row, starting from part_id=1.

    Accepted formats
    ----------------
    1. CSV with the following column names:

       phi1, Phi, phi2

    2. Headerless CSV containing exactly three columns.

    The input file must not contain element_id or part_id.
    """
    input_path = Path(input_path)

    if not input_path.is_file():
        raise FileNotFoundError(f"Input Euler-angle CSV was not found: {input_path}")

    data = pd.read_csv(input_path)

    if "element_id" in data.columns:
        raise ValueError(
            "The input Euler-angle CSV must not contain an element_id column."
        )

    if "part_id" in data.columns:
        raise ValueError("The input Euler-angle CSV must not contain a part_id column.")

    if set(EULER_COLUMNS).issubset(data.columns):
        result = data.loc[:, EULER_COLUMNS].copy()
    else:
        # The first read may have interpreted the first numerical row
        # as a header. Read the file again as a headerless CSV.
        headerless_data = pd.read_csv(
            input_path,
            header=None,
        )

        if headerless_data.shape[1] != 3:
            raise ValueError(
                "The input Euler-angle CSV must contain exactly "
                "the following three columns:\n"
                "phi1, Phi, phi2\n"
                f"Detected number of columns: {headerless_data.shape[1]}\n"
                f"File: {input_path}"
            )

        headerless_data.columns = EULER_COLUMNS
        result = headerless_data

    result = _convert_euler_columns_to_numeric(
        result,
        source_path=input_path,
    )

    return result.reset_index(drop=True)


def read_raw_euler_csv(
    raw_path: Path,
) -> pd.DataFrame:
    """
    Read a state02-state13 Euler-angle CSV exported from LS-PrePost.

    Required columns:

    - element_id
    - phi1
    - Phi
    - phi2

    A part_id column is not required and should normally not be present.
    """
    raw_path = Path(raw_path)

    if not raw_path.is_file():
        raise FileNotFoundError(f"Raw Euler-angle CSV was not found: {raw_path}")

    data = pd.read_csv(raw_path)

    required_columns = {
        "element_id",
        *EULER_COLUMNS,
    }

    missing_columns = required_columns.difference(data.columns)

    if missing_columns:
        raise KeyError(
            "The raw Euler-angle CSV does not contain all required columns.\n"
            f"Missing columns: {sorted(missing_columns)}\n"
            f"Existing columns: {data.columns.tolist()}\n"
            f"File: {raw_path}"
        )

    if "part_id" in data.columns:
        raise ValueError(
            "The raw Euler-angle CSV already contains a part_id column.\n"
            f"File: {raw_path}"
        )

    result = data.loc[
        :,
        [
            "element_id",
            *EULER_COLUMNS,
        ],
    ].copy()

    result["element_id"] = pd.to_numeric(
        result["element_id"],
        errors="raise",
    ).astype(int)

    result = _convert_euler_columns_to_numeric(
        result,
        source_path=raw_path,
    )

    duplicated_mask = result["element_id"].duplicated(keep=False)

    if duplicated_mask.any():
        duplicated_ids = (
            result.loc[duplicated_mask, "element_id"].drop_duplicates().tolist()
        )

        raise ValueError(
            "Duplicated element_id values were found in the raw CSV.\n"
            f"Count: {len(duplicated_ids)}\n"
            f"First 10: {duplicated_ids[:10]}\n"
            f"File: {raw_path}"
        )

    return result.reset_index(drop=True)


def build_state01_data(
    mapper: ElementPartMapper,
    input_euler_path: Path,
) -> pd.DataFrame:
    """
    Generate state01 data from the input Euler angles.

    Each input row is associated with a part in the following order:

    - row 1 -> part_id=1
    - row 2 -> part_id=2
    - ...

    Parts that do not exist in the loaded partset are ignored.

    Each retained part row is expanded to all elements belonging to
    that part.
    """
    part_euler_data = read_input_euler_csv(input_euler_path)

    element_euler_data = mapper.expand_part_data_to_elements(
        part_euler_data,
        first_part_id=1,
    )

    return _finalize_output_data(element_euler_data)


def build_lspost_state_data(
    mapper: ElementPartMapper,
    raw_path: Path,
) -> pd.DataFrame:
    """
    Generate state02-state13 data from LS-PrePost output.

    The raw output already contains element_id. The corresponding
    part_id is added using the element-part mapping.
    """
    raw_data = read_raw_euler_csv(raw_path)

    element_euler_data = mapper.add_part_id(raw_data)

    return _finalize_output_data(element_euler_data)


def generate_euler_state_csvs(
    paths: EulerStatePaths,
    *,
    first_state: int = 1,
    last_state: int = 13,
    overwrite: bool = False,
) -> None:
    """
    Generate normalized Euler-angle CSV files for all requested states.

    Processing rule
    ---------------
    state01:
        Use the input Euler-angle CSV because LS-PrePost records
        zero Euler angles at the initial state.

    state02-state13:
        Use the LS-PrePost raw Euler-angle CSV and add part_id from
        the partset.

    Output columns
    --------------
    element_id, part_id, phi1, Phi, phi2
    """
    if first_state < 1:
        raise ValueError("first_state must be 1 or greater.")

    if last_state < first_state:
        raise ValueError("last_state must be greater than or equal to first_state.")

    paths.output_dir.mkdir(
        parents=True,
        exist_ok=True,
    )

    mapper = ElementPartMapper(paths.partset_path)

    print(f"Partset: {paths.partset_path}")
    print(f"Registered parts: {mapper.number_of_parts}")
    print(f"Registered elements: {mapper.number_of_elements}")

    for state in range(
        first_state,
        last_state + 1,
    ):
        output_path = paths.output_state_path(state)

        if output_path.exists() and not overwrite:
            print(f"state{state:02d}: output already exists, skip: {output_path}")
            continue

        if state == 1:
            output_data = build_state01_data(
                mapper=mapper,
                input_euler_path=paths.input_euler_path,
            )

            source_description = paths.input_euler_path

        else:
            raw_path = paths.raw_state_path(state)

            output_data = build_lspost_state_data(
                mapper=mapper,
                raw_path=raw_path,
            )

            source_description = raw_path

        output_data.to_csv(
            output_path,
            index=False,
        )

        print(
            f"state{state:02d}: generated "
            f"{len(output_data)} rows\n"
            f"  source: {source_description}\n"
            f"  output: {output_path}"
        )


def _convert_euler_columns_to_numeric(
    data: pd.DataFrame,
    *,
    source_path: Path,
) -> pd.DataFrame:
    """
    Convert phi1, Phi and phi2 to numeric values.
    """
    result = data.copy()

    for column in EULER_COLUMNS:
        try:
            result[column] = pd.to_numeric(
                result[column],
                errors="raise",
            )

        except (TypeError, ValueError) as error:
            raise ValueError(
                f"The {column} column contains a non-numeric value.\n"
                f"File: {source_path}"
            ) from error

    return result


def _finalize_output_data(
    data: pd.DataFrame,
) -> pd.DataFrame:
    """
    Validate and arrange the final output columns.
    """
    missing_columns = set(OUTPUT_COLUMNS).difference(data.columns)

    if missing_columns:
        raise KeyError(
            "Required output columns are missing.\n"
            f"Missing columns: {sorted(missing_columns)}"
        )

    result = data.loc[
        :,
        OUTPUT_COLUMNS,
    ].copy()

    result["element_id"] = result["element_id"].astype(int)
    result["part_id"] = result["part_id"].astype(int)

    result = result.sort_values("element_id").reset_index(drop=True)

    if result["element_id"].duplicated().any():
        duplicated_ids = (
            result.loc[
                result["element_id"].duplicated(keep=False),
                "element_id",
            ]
            .drop_duplicates()
            .tolist()
        )

        raise ValueError(
            "Duplicated element_id values exist in the final output.\n"
            f"First 10: {duplicated_ids[:10]}"
        )

    return result


def _resolve_input_euler_path(
    texture: str,
    sd_value: int,
    seed: int,
    pre_dirs: PreDirectories,
) -> Path:
    """Resolve the initial Euler-angle CSV using the pipeline directory layout."""
    candidate_paths = [
        pre_dirs.orientation_csv_dir
        / f"bunge_euler_{texture}_sd{sd_value}_seed{seed}.csv",
        pre_dirs.orientation_csv_dir / f"{texture}_sigma{sd_value}.csv",
    ]

    for candidate_path in candidate_paths:
        if candidate_path.is_file():
            return candidate_path

    raise FileNotFoundError(
        "Input Euler-angle CSV was not found. Tried the following paths:\n"
        + "\n".join(str(path) for path in candidate_paths)
    )


def main() -> None:
    texture_list = ["brass", "copper", "cube", "goss", "s"]
    sd_values = list(range(2, 11))
    seed = SEED
    rho_value = RHO

    for texture in texture_list:
        for sd_value in sd_values:
            pre_dirs = build_pre_directories(
                seed=seed,
                rho=rho_value,
            )
            post_dirs = build_post_directories(
                rho=rho_value,
                seed=seed,
            )
            input_euler_path = _resolve_input_euler_path(
                texture=texture,
                sd_value=sd_value,
                seed=seed,
                pre_dirs=pre_dirs,
            )

            paths = EulerStatePaths(
                partset_path=pre_dirs.partset,
                # One row corresponds to one part.
                # The first row is part_id=1.
                input_euler_path=input_euler_path,
                # Raw LS-PrePost output for state02-state13.
                raw_output_dir=post_dirs.raw_angle_dir
                / f"bunge_euler_{texture}_sd{sd_value}_seed{seed}",
                # Normalized output destination.
                output_dir=post_dirs.id_set_angle_dir
                / f"id_set_bunge_euler_{texture}_sd{sd_value}_seed{seed}",
                raw_filename_template=(
                    f"bunge_euler_{texture}_sd{sd_value}_seed{seed}_state{{state:02d}}.csv"
                ),
                output_filename_template=(
                    f"bunge_euler_{texture}_sd{sd_value}_seed{seed}_state{{state:02d}}.csv"
                ),
            )

            generate_euler_state_csvs(
                paths,
                first_state=1,
                last_state=13,
                overwrite=False,
            )


if __name__ == "__main__":
    main()
