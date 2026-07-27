import re
from pathlib import Path

import pandas as pd

N_PER_ROW = 113

# Line indices assuming the top of the CSV is row 0
TARGET_LINE_INDICES = {
    "L1": 29,
    "L2": 57,
    "L3": 85,
}


class LineExtractor:
    def read_edge_dropped_csv(self, csv_path: Path) -> pd.DataFrame:
        """
        Read a CSV file produced after edge_dropped.

        Assumptions:
            no header
            column 0: node_id
            column 1: x
            column 2: y
            column 3: z
        """
        df = pd.read_csv(
            csv_path,
            header=None,
            names=["node_id", "x", "y", "z"],
        )

        return df

    def extract_line_by_index(
        self,
        df: pd.DataFrame,
        line_index: int,
        n_per_row: int = N_PER_ROW,
    ) -> pd.DataFrame:
        """
        Treat the top of the CSV as row 0 and extract the horizontal line at line_index.

        Example:
            if line_index = 29,
            rows 113*29 through 113*30 - 1 are selected.
        """

        start = n_per_row * line_index
        end = n_per_row * (line_index + 1)

        return df.iloc[start:end].copy()

    def make_line_output_name(self, csv_path: Path, line_label: str) -> str:
        """Create a normalized line-profile filename.

        Example:
            node_coordinates_cube_sd_2_state_01.csv
            -> line_L1_cube_sd_2_state_01.csv
        """
        match = re.fullmatch(
            r"coordinates_(.+?)_sd(\d+)_seed(\d+)_state(\d+)",
            csv_path.stem,
            flags=re.IGNORECASE,
        )
        if not match:
            raise ValueError(
                f"Unexpected edge-dropped coordinate filename: {csv_path.name}"
            )

        texture, sd, seed, state = match.groups()
        return (
            f"line_{texture.lower()}_sd{int(sd)}_seed{int(seed)}_"
            f"state{int(state):02d}_{line_label}.csv"
        )

    def extract_lines_from_csv(
        self,
        csv_path: Path,
        output_root_dir: Path,
        target_line_indices: dict[str, int] = TARGET_LINE_INDICES,
        n_per_row: int = N_PER_ROW,
    ) -> None:
        """
        Extract and save L1, L2, and L3 lines from a single edge_dropped CSV.
        """

        df = self.read_edge_dropped_csv(csv_path)

        expected_n = n_per_row * n_per_row
        if len(df) != expected_n:
            raise ValueError(
                f"{csv_path} does not have {expected_n} rows. Current: {len(df)}"
            )

        for line_label, line_index in target_line_indices.items():
            line_df = self.extract_line_by_index(
                df=df,
                line_index=line_index,
                n_per_row=n_per_row,
            )

            output_dir = output_root_dir / line_label
            output_dir.mkdir(parents=True, exist_ok=True)

            output_name = self.make_line_output_name(csv_path, line_label)
            output_path = output_dir / output_name

            line_df.to_csv(output_path, index=False, header=False)

    def extract_lines_from_edge_dropped(
        self,
        edge_dropped_dir: Path,
        output_root_dir: Path,
        target_line_indices: dict[str, int] = TARGET_LINE_INDICES,
        n_per_row: int = N_PER_ROW,
    ) -> None:
        """
        Process all CSV files in each model folder under edge_dropped.

        Input:
            edge_dropped/
            |-0514cube_sd2/
            |  |-node_coordinates_cube_sd_2_state_01.csv
            |  |-...

        Output:
            lines/
            |-0514cube_sd2/
            |  |-L1/
            |  |  |-line_L1_cube_sd_2_state_01.csv
            |  |-L2/
            |  |-L3/
        """

        edge_dropped_dir = Path(edge_dropped_dir)
        output_root_dir = Path(output_root_dir)

        if not edge_dropped_dir.exists():
            raise FileNotFoundError(f"edge_dropped not found: {edge_dropped_dir}")

        for model_dir in sorted(edge_dropped_dir.iterdir()):
            if not model_dir.is_dir():
                continue

            csv_files = sorted(model_dir.glob("*.csv"))

            case_output_root_dir = output_root_dir / model_dir.name

            for csv_path in csv_files:
                self.extract_lines_from_csv(
                    csv_path=csv_path,
                    output_root_dir=case_output_root_dir,
                    target_line_indices=target_line_indices,
                    n_per_row=n_per_row,
                )
