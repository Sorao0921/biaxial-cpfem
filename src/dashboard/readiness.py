"""Read-only access to the model readiness catalog used by the dashboard."""

from __future__ import annotations

import sqlite3
from pathlib import Path
from typing import Any
from urllib.parse import quote

import pandas as pd


READINESS_COLUMNS = (
    "has_surface_height",
    "has_orientation_metrics",
    "has_accumulated_shear_strain",
    "has_initial_orientation",
    "has_spatial_model",
    "theme1_ready",
    "training_ready",
    "has_height_plot",
    "has_orientation_plot",
    "has_shear_plot",
)

_MISSING_LABELS = {
    "has_surface_height": "表面高さ",
    "has_orientation_metrics": "GOS・粒回転",
    "has_accumulated_shear_strain": "累積せん断ひずみ",
    "has_initial_orientation": "初期方位",
    "has_spatial_model": "空間モデル",
}

_PLOT_LABELS = {
    "has_height_plot": "表面高さplot",
    "has_orientation_plot": "GOS・粒回転plot",
    "has_shear_plot": "せん断ひずみplot",
}

_QUERY = """
SELECT
    c.case_id,
    c.rho,
    c.seed,
    c.texture,
    c.sd,
    c.state,
    c.has_surface_height,
    c.has_orientation_metrics,
    c.has_accumulated_shear_strain,
    c.has_initial_orientation,
    c.has_spatial_model,
    c.theme1_ready,
    c.training_ready,
    c.artifact_count,
    EXISTS (
        SELECT 1 FROM artifacts a
        WHERE a.rho=c.rho AND a.seed=c.seed AND a.texture=c.texture
          AND a.sd=c.sd AND a.state=c.state
          AND a.data_kind='figure_or_document'
          AND a.relative_path LIKE '%/coords/figures/height_contours/%'
    ) AS has_height_plot,
    EXISTS (
        SELECT 1 FROM artifacts a
        WHERE a.rho=c.rho AND a.seed=c.seed AND a.texture=c.texture
          AND a.sd=c.sd AND a.state=c.state
          AND a.data_kind='figure_or_document'
          AND a.relative_path LIKE '%/angles/grain_orientation_plots/%'
    ) AS has_orientation_plot,
    EXISTS (
        SELECT 1 FROM artifacts a
        WHERE a.rho=c.rho AND a.seed=c.seed AND a.texture=c.texture
          AND a.sd=c.sd AND a.state=c.state
          AND a.data_kind='figure_or_document'
          AND a.relative_path LIKE '%/shear_strains/figures/%'
    ) AS has_shear_plot
FROM v_theme1_case_readiness c
WHERE c.state <> 1
ORDER BY c.rho, c.seed, c.texture, c.sd, c.state
"""

DISPLAY_BOOLEAN_COLUMNS = (
    "has_surface_height",
    "has_orientation_metrics",
    "has_accumulated_shear_strain",
    "has_spatial_model",
    "has_initial_orientation",
    "theme1_ready",
    "training_ready",
    "has_height_plot",
    "has_orientation_plot",
    "has_shear_plot",
)

POSTPROCESS_COMPLETE = "完了"
POSTPROCESS_PARTIAL = "一部不足"
POSTPROCESS_NOT_RUN = "未実行"


def _readonly_connection(database: Path) -> sqlite3.Connection:
    if not database.is_file():
        raise FileNotFoundError(f"解析データベースが見つかりません: {database}")
    uri = f"file:{quote(str(database.resolve()))}?mode=ro"
    return sqlite3.connect(uri, uri=True)


def _missing_items(row: pd.Series) -> str:
    return "、".join(
        label for column, label in _MISSING_LABELS.items() if not bool(row[column])
    )


def load_readiness(database: Path | str) -> pd.DataFrame:
    """Load per-case Theme 1 readiness from ``v_theme1_case_readiness``.

    The SQLite database is opened in read-only mode.  Availability/readiness
    columns are returned as booleans, and ``missing_items`` contains Japanese
    display labels separated by ``、``.  It is an empty string for complete
    cases.
    """

    with _readonly_connection(Path(database)) as connection:
        frame = pd.read_sql_query(_QUERY, connection)

    for column in READINESS_COLUMNS:
        frame[column] = frame[column].astype(bool)
    frame["missing_items"] = frame.apply(_missing_items, axis=1)
    frame["missing_count"] = frame["missing_items"].map(
        lambda value: 0 if not value else len(value.split("、"))
    )
    frame["postprocess_status"] = frame.apply(_postprocess_status, axis=1)
    return frame


def _postprocess_status(row: pd.Series) -> str:
    completed = (
        bool(row["has_orientation_metrics"]),
        bool(row["has_accumulated_shear_strain"]),
    )
    if all(completed):
        return POSTPROCESS_COMPLETE
    if not any(completed):
        return POSTPROCESS_NOT_RUN
    return POSTPROCESS_PARTIAL


def summarize_readiness(frame: pd.DataFrame) -> dict[str, Any]:
    """Return dashboard-friendly totals and availability counts."""

    required = set(READINESS_COLUMNS)
    missing_columns = required.difference(frame.columns)
    if missing_columns:
        names = ", ".join(sorted(missing_columns))
        raise ValueError(f"充足状況の列が不足しています: {names}")

    total = len(frame)
    theme1_ready = int(frame["theme1_ready"].astype(bool).sum())
    training_ready = int(frame["training_ready"].astype(bool).sum())
    availability_labels = {**_MISSING_LABELS, **_PLOT_LABELS}
    available_counts = {
        label: int(frame[column].astype(bool).sum())
        for column, label in availability_labels.items()
    }
    return {
        "total_cases": total,
        "theme1_ready_cases": theme1_ready,
        "theme1_not_ready_cases": total - theme1_ready,
        "theme1_ready_rate": theme1_ready / total if total else 0.0,
        "training_ready_cases": training_ready,
        "training_not_ready_cases": total - training_ready,
        "training_ready_rate": training_ready / total if total else 0.0,
        "available_counts": available_counts,
        "missing_counts": {
            label: total - count for label, count in available_counts.items()
        },
    }


def format_readiness_booleans(frame: pd.DataFrame) -> pd.DataFrame:
    """Return a display copy with availability booleans rendered as symbols.

    Columns are transformed one at a time to avoid a pandas block-manager bug
    triggered by replacing multiple filtered boolean columns in one operation.
    """
    result = frame.copy()
    for column in DISPLAY_BOOLEAN_COLUMNS:
        if column in result.columns:
            result[column] = result[column].map(lambda value: "✓" if bool(value) else "—")
    return result
