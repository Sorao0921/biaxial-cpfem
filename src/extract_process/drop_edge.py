from pathlib import Path

import numpy as np
import pandas as pd


class EdgeDropper:
    """
    Process to keep only the central 113 x 113 nodes from the coordinate CSV of 151 x 151 = 22801 nodes.

    node_id is assigned starting from 1 corresponding to the CSV row number.
    Assume a grid where node_id=1 is at the bottom-left, and id increases to the right.
    """

    def __init__(self, grid_size: int = 151, keep_size: int = 113):
        if keep_size > grid_size:
            raise ValueError("keep_size must be smaller than or equal to grid_size.")

        margin = (grid_size - keep_size) // 2
        if (grid_size - keep_size) % 2 != 0:
            raise ValueError("grid_size - keep_size must be an even number.")

        self.grid_size = grid_size
        self.keep_size = keep_size
        self.margin = margin

        # For 1-based row and column numbers, imagine keeping 20 to 132
        self.keep_min = margin + 1
        self.keep_max = grid_size - margin

    def make_keep_mask(self, num_nodes: int) -> np.ndarray:
        """Determine which nodes to keep based on the quotient and remainder of node_id divided by grid_size."""
        expected_nodes = self.grid_size * self.grid_size
        if num_nodes != expected_nodes:
            raise ValueError(
                f"Expected {expected_nodes} rows, but got {num_nodes} rows."
            )

        node_ids = np.arange(1, num_nodes + 1)

        # 0-based quotient and remainder
        quotient = (node_ids - 1) // self.grid_size
        remainder = (node_ids - 1) % self.grid_size

        # Convert to 1-based row and column numbers
        row_id = quotient + 1
        col_id = remainder + 1

        keep_mask = (
            (self.keep_min <= row_id)
            & (row_id <= self.keep_max)
            & (self.keep_min <= col_id)
            & (col_id <= self.keep_max)
        )

        return keep_mask

    def add_node_id_column(self, df: pd.DataFrame) -> pd.DataFrame:
        """Add original 1-based node_id as the first column."""
        df_with_node_id = df.copy()
        df_with_node_id.insert(0, "node_id", np.arange(1, len(df_with_node_id) + 1))
        return df_with_node_id

    def drop_edge_nodes(self, df: pd.DataFrame) -> pd.DataFrame:
        """Exclude peripheral nodes and return a DataFrame with only the central part."""
        keep_mask = self.make_keep_mask(len(df))
        return df.loc[keep_mask].reset_index(drop=True)

    def process_csv(self, csv_path: Path, output_path: Path) -> pd.DataFrame:
        """Read one CSV, add original node_id, drop the edges, save it, and return the result."""
        df = pd.read_csv(csv_path, header=None)
        df_with_node_id = self.add_node_id_column(df)
        df_dropped = self.drop_edge_nodes(df_with_node_id)

        output_path.parent.mkdir(parents=True, exist_ok=True)
        df_dropped.to_csv(output_path, index=False, header=False)

        print(f"saved: {output_path} ({len(df)} rows -> {len(df_dropped)} rows)")

        return df_dropped

    def process_case_dir(self, case_dir: Path, output_case_dir: Path) -> None:
        """Process all CSVs in one case folder, such as brass_sd2."""
        csv_paths = sorted(case_dir.glob("*.csv"))
        if not csv_paths:
            print(f"skip: {case_dir} has no csv files")
            return

        for csv_path in csv_paths:
            output_path = output_case_dir / csv_path.name
            self.process_csv(csv_path, output_path)

    def process_post_dir(self, post_dir: Path, output_root: Path) -> None:
        """Process each case folder under post in order."""
        case_dirs = sorted([path for path in post_dir.iterdir() if path.is_dir()])
        if not case_dirs:
            raise FileNotFoundError(f"No case directories found in {post_dir}")

        for case_dir in case_dirs:
            output_case_dir = output_root / case_dir.name
            print(f"processing case: {case_dir.name}")
            self.process_case_dir(case_dir, output_case_dir)
