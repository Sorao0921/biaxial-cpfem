from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Literal

MetricKind = Literal["height", "orientation", "shear"]

_CASE_RE = re.compile(
    r"(?P<texture>brass|copper|cube|goss|s)_sd(?P<sd>\d+)_seed(?P<seed>\d+)",
    re.IGNORECASE,
)
_STATE_RE = re.compile(r"state(?P<state>\d+)", re.IGNORECASE)
_RHO_RE = re.compile(r"^rho_(?P<rho>-?\d+(?:\.\d+)?)$")


@dataclass(frozen=True)
class OutputRecord:
    kind: MetricKind
    rho: float
    seed: int
    texture: str
    sd: int
    state: int
    path: Path
    source: str

    @property
    def case_key(self) -> tuple[float, int, str, int, int]:
        return self.rho, self.seed, self.texture, self.sd, self.state


def _case_from_path(path: Path) -> tuple[float, int, str, int, int] | None:
    rho_match = next(
        (_RHO_RE.match(part) for part in path.parts if _RHO_RE.match(part)), None
    )
    case_match = _CASE_RE.search(path.as_posix())
    state_matches = list(_STATE_RE.finditer(path.name))
    if rho_match is None or case_match is None or not state_matches:
        return None
    state = int(state_matches[-1].group("state"))
    return (
        float(rho_match.group("rho")),
        int(case_match.group("seed")),
        case_match.group("texture").lower(),
        int(case_match.group("sd")),
        state,
    )


def scan_outputs(
    outputs_dir: Path | str, *, prefer_raw_height: bool = False
) -> list[OutputRecord]:
    """Build a lightweight catalog of plottable output CSV files."""
    outputs_dir = Path(outputs_dir)
    records: dict[tuple[MetricKind, float, int, str, int, int], OutputRecord] = {}

    # The comparison UI prefers the unclamped interior. Theme 1 can explicitly
    # use the complete raw surface, including the edge, for its regression.
    height_patterns = (
        (
            ("coords/rawdata/**/*.csv", "rawdata"),
            ("coords/edge_dropped/**/*.csv", "edge_dropped"),
        )
        if prefer_raw_height
        else (
            ("coords/edge_dropped/**/*.csv", "edge_dropped"),
            ("coords/rawdata/**/*.csv", "rawdata"),
        )
    )
    for pattern, source in height_patterns:
        for path in outputs_dir.glob(f"rho_*/rho_*_seed*/{pattern}"):
            case = _case_from_path(path)
            if case is None:
                continue
            key = ("height", *case)
            if key not in records:
                records[key] = OutputRecord("height", *case, path, source)

    for path in outputs_dir.glob(
        "rho_*/rho_*_seed*/angles/grain_orientation_metrics/**/*.csv"
    ):
        case = _case_from_path(path)
        if case is None:
            continue
        key = ("orientation", *case)
        records[key] = OutputRecord("orientation", *case, path, "grain_metrics")

    for path in outputs_dir.glob(
        "rho_*/rho_*_seed*/shear_strains/id_set/**/*.csv"
    ):
        case = _case_from_path(path)
        if case is None:
            continue
        key = ("shear", *case)
        records[key] = OutputRecord("shear", *case, path, "id_set")

    return sorted(
        records.values(),
        key=lambda item: (
            item.kind,
            item.rho,
            item.seed,
            item.texture,
            item.sd,
            item.state,
        ),
    )


def filter_records(
    records: Iterable[OutputRecord],
    *,
    kind: MetricKind | None = None,
    rho: float | None = None,
    seed: int | None = None,
    texture: str | None = None,
    sd: int | None = None,
    state: int | None = None,
) -> list[OutputRecord]:
    return [
        record
        for record in records
        if (kind is None or record.kind == kind)
        and (rho is None or record.rho == rho)
        and (seed is None or record.seed == seed)
        and (texture is None or record.texture == texture)
        and (sd is None or record.sd == sd)
        and (state is None or record.state == state)
    ]


def available_values(
    records: Iterable[OutputRecord], field: str
) -> list[float | int | str]:
    return sorted({getattr(record, field) for record in records})
