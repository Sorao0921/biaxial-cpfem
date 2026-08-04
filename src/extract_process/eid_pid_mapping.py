from __future__ import annotations

from pathlib import Path

import pandas as pd


class ElementPartMapper:
    """
    Load the mapping between element_id and part_id from an LS-DYNA partset.

    The mapper supports:

    - element_id -> part_id
    - part_id -> element_id list
    - adding part_id to element-based data
    - expanding part-based data into element-based data
    """

    def __init__(self, partset_path: Path) -> None:
        self.partset_path = Path(partset_path)

        self._element_to_part = self._load_mapping()
        self._part_to_elements = self._build_reverse_mapping()

    @property
    def element_to_part(self) -> dict[int, int]:
        """
        Return the mapping of element_id -> part_id.

        Return a copy so external code cannot directly modify
        the internal dictionary.
        """
        return self._element_to_part.copy()

    @property
    def part_to_elements(self) -> dict[int, tuple[int, ...]]:
        """
        Return the mapping of part_id -> element_id tuple.

        Tuples are used so callers cannot modify the internal
        element collections.
        """
        return {
            part_id: tuple(element_ids)
            for part_id, element_ids in self._part_to_elements.items()
        }

    @property
    def number_of_elements(self) -> int:
        """Return the number of registered elements."""
        return len(self._element_to_part)

    @property
    def number_of_parts(self) -> int:
        """Return the number of registered parts."""
        return len(self._part_to_elements)

    def get_part_id(self, element_id: int) -> int:
        """
        Return the part_id associated with the specified element_id.
        """
        try:
            return self._element_to_part[element_id]

        except KeyError as error:
            raise KeyError(
                f"element_id={element_id} does not exist in {self.partset_path}."
            ) from error

    def get_element_ids(self, part_id: int) -> tuple[int, ...]:
        """
        Return all element_id values belonging to the specified part_id.
        """
        try:
            return tuple(self._part_to_elements[part_id])

        except KeyError as error:
            raise KeyError(
                f"part_id={part_id} does not exist in {self.partset_path}."
            ) from error

    def add_part_id(
        self,
        data: pd.DataFrame,
    ) -> pd.DataFrame:
        """
        Add a part_id column to a DataFrame that contains
        an element_id column.
        """
        if "element_id" not in data.columns:
            raise KeyError("The input DataFrame does not contain an element_id column.")

        result = data.copy()

        if "part_id" in result.columns:
            raise ValueError("The input DataFrame already contains a part_id column.")

        insert_position = result.columns.get_loc("element_id") + 1

        result.insert(
            loc=insert_position,
            column="part_id",
            value=result["element_id"].map(self._element_to_part),
        )

        missing_mask = result["part_id"].isna()

        if missing_mask.any():
            missing_ids = (
                result.loc[missing_mask, "element_id"].drop_duplicates().tolist()
            )

            raise ValueError(
                "There are element_id values that do not exist "
                "in the partset.\n"
                f"Count: {len(missing_ids)}\n"
                f"First 10: {missing_ids[:10]}"
            )

        result["part_id"] = result["part_id"].astype(int)

        return result

    def expand_part_data_to_elements(
        self,
        data: pd.DataFrame,
        *,
        first_part_id: int = 1,
    ) -> pd.DataFrame:
        """
        Expand row-ordered part data into element-based data.

        Returns
        -------
        pd.DataFrame
            Element-based data containing element_id and part_id columns.
        """
        if first_part_id < 1:
            raise ValueError("first_part_id must be 1 or greater.")

        if "part_id" in data.columns:
            raise ValueError("The input DataFrame already contains a part_id column.")

        if "element_id" in data.columns:
            raise ValueError(
                "The input DataFrame already contains an element_id column."
            )

        part_data = data.copy().reset_index(drop=True)

        part_data.insert(
            loc=0,
            column="part_id",
            value=range(
                first_part_id,
                first_part_id + len(part_data),
            ),
        )

        registered_part_ids = set(self._part_to_elements)

        part_data = part_data.loc[part_data["part_id"].isin(registered_part_ids)].copy()

        if part_data.empty:
            output_columns = [
                "element_id",
                "part_id",
                *data.columns.tolist(),
            ]

            return pd.DataFrame(columns=output_columns)

        element_rows = pd.DataFrame(
            (
                (element_id, part_id)
                for part_id, element_ids in self._part_to_elements.items()
                for element_id in element_ids
            ),
            columns=[
                "element_id",
                "part_id",
            ],
        )

        result = element_rows.merge(
            part_data,
            on="part_id",
            how="inner",
            validate="many_to_one",
        )

        ordered_columns = [
            "element_id",
            "part_id",
            *data.columns.tolist(),
        ]

        return (
            result.loc[:, ordered_columns]
            .sort_values("element_id")
            .reset_index(drop=True)
        )

    def select_part(
        self,
        data: pd.DataFrame,
        part_id: int,
    ) -> pd.DataFrame:
        """
        Return only the elements belonging to the specified part_id.
        """
        data_with_part = self._ensure_part_id(data)

        return (
            data_with_part.loc[data_with_part["part_id"] == part_id]
            .copy()
            .reset_index(drop=True)
        )

    def group_by_part(
        self,
        data: pd.DataFrame,
    ):
        """
        Return a groupby object keyed by part_id.
        """
        data_with_part = self._ensure_part_id(data)

        return data_with_part.groupby("part_id")

    def _ensure_part_id(
        self,
        data: pd.DataFrame,
    ) -> pd.DataFrame:
        """
        Add a part_id column if it is missing.

        If the DataFrame already contains part_id, return it as is.
        """
        if "part_id" in data.columns:
            return data

        return self.add_part_id(data)

    def _build_reverse_mapping(
        self,
    ) -> dict[int, list[int]]:
        """
        Build a part_id -> element_id list mapping.
        """
        part_to_elements: dict[int, list[int]] = {}

        for element_id, part_id in self._element_to_part.items():
            part_to_elements.setdefault(
                part_id,
                [],
            ).append(element_id)

        for element_ids in part_to_elements.values():
            element_ids.sort()

        return part_to_elements

    def _load_mapping(self) -> dict[int, int]:
        """
        Read the *ELEMENT_SOLID section and build an
        element_id -> part_id dictionary.
        """
        if not self.partset_path.is_file():
            raise FileNotFoundError(f"partset not found: {self.partset_path}")

        element_to_part: dict[int, int] = {}
        in_element_solid = False

        with self.partset_path.open(
            "r",
            encoding="utf-8",
            errors="replace",
        ) as file:
            for line_number, raw_line in enumerate(
                file,
                start=1,
            ):
                line = raw_line.strip()

                if not line or line.startswith("$"):
                    continue

                if line.startswith("*"):
                    keyword = line.upper()

                    if keyword.startswith("*ELEMENT_SOLID"):
                        in_element_solid = True
                        continue

                    if in_element_solid:
                        break

                    continue

                if not in_element_solid:
                    continue

                fields = line.replace(",", " ").split()

                if len(fields) < 2:
                    raise ValueError(
                        f"{self.partset_path}:"
                        f"{line_number}: "
                        "Unable to parse an ELEMENT_SOLID line.\n"
                        f"line={raw_line.rstrip()}"
                    )

                try:
                    element_id = int(fields[0])
                    part_id = int(fields[1])

                except ValueError as error:
                    raise ValueError(
                        f"{self.partset_path}:"
                        f"{line_number}: "
                        "element_id or part_id is not an integer.\n"
                        f"line={raw_line.rstrip()}"
                    ) from error

                if element_id in element_to_part:
                    raise ValueError(
                        f"{self.partset_path}:"
                        f"{line_number}: "
                        f"element_id={element_id} "
                        "is duplicated."
                    )

                element_to_part[element_id] = part_id

        if not element_to_part:
            raise ValueError(
                f"Could not obtain *ELEMENT_SOLID data from {self.partset_path}."
            )

        return element_to_part
