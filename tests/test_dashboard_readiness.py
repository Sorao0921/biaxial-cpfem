from __future__ import annotations

import sqlite3
from pathlib import Path

import pandas as pd
import pytest

from src.dashboard.readiness import (
    format_readiness_booleans,
    load_readiness,
    summarize_readiness,
)


def _make_database(path: Path) -> None:
    rows = [
        (1, 1.0, 1, "cube", 1, 1, 1, 1, 1, 1, 1, 1, 1, 10),
        (2, 1.0, 1, "cube", 1, 2, 1, 1, 1, 1, 1, 1, 1, 10),
        (3, 1.0, 1, "goss", 2, 3, 1, 0, 1, 1, 0, 0, 0, 7),
        (4, 1.0, 1, "brass", 3, 4, 1, 0, 0, 1, 1, 0, 0, 5),
    ]
    with sqlite3.connect(path) as connection:
        connection.execute(
            """
            CREATE TABLE v_theme1_case_readiness (
                case_id INTEGER, rho REAL, seed INTEGER, texture TEXT,
                sd INTEGER, state INTEGER, has_surface_height INTEGER,
                has_orientation_metrics INTEGER,
                has_accumulated_shear_strain INTEGER,
                has_initial_orientation INTEGER, has_spatial_model INTEGER,
                theme1_ready INTEGER, training_ready INTEGER,
                artifact_count INTEGER
            )
            """
        )
        connection.executemany(
            "INSERT INTO v_theme1_case_readiness VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            rows,
        )
        connection.execute(
            """
            CREATE TABLE artifacts (
                rho REAL, seed INTEGER, texture TEXT, sd INTEGER, state INTEGER,
                data_kind TEXT, relative_path TEXT
            )
            """
        )
        connection.executemany(
            "INSERT INTO artifacts VALUES (?, ?, ?, ?, ?, ?, ?)",
            [
                (1.0, 1, "cube", 1, 2, "figure_or_document", "outputs/rho_1/rho_1_seed1/coords/figures/height_contours/cube/state02.png"),
                (1.0, 1, "cube", 1, 2, "figure_or_document", "outputs/rho_1/rho_1_seed1/angles/grain_orientation_plots/cube/state02/gos.png"),
                (1.0, 1, "goss", 2, 3, "figure_or_document", "outputs/rho_1/rho_1_seed1/shear_strains/figures/goss/state03/gamma.png"),
            ],
        )


def test_load_readiness_adds_human_readable_missing_items(tmp_path: Path) -> None:
    database = tmp_path / "analysis.db"
    _make_database(database)

    frame = load_readiness(database)

    assert len(frame) == 3
    assert 1 not in frame["state"].tolist()
    assert all(frame[column].dtype == bool for column in (
        "has_surface_height",
        "has_orientation_metrics",
        "has_accumulated_shear_strain",
        "has_spatial_model",
        "theme1_ready",
        "training_ready",
    ))
    by_state = frame.set_index("state")
    assert by_state.loc[2, "missing_items"] == ""
    assert by_state.loc[2, "missing_count"] == 0
    assert by_state.loc[3, "missing_items"] == "GOS・粒回転、空間モデル"
    assert by_state.loc[3, "missing_count"] == 2
    assert by_state.loc[2, "postprocess_status"] == "完了"
    assert by_state.loc[3, "postprocess_status"] == "一部不足"
    assert by_state.loc[4, "postprocess_status"] == "未実行"
    assert by_state.loc[2, "has_height_plot"]
    assert by_state.loc[2, "has_orientation_plot"]
    assert not by_state.loc[2, "has_shear_plot"]
    assert by_state.loc[3, "has_shear_plot"]


def test_summarize_readiness_returns_counts_and_rates(tmp_path: Path) -> None:
    database = tmp_path / "analysis.db"
    _make_database(database)

    summary = summarize_readiness(load_readiness(database))

    assert summary["total_cases"] == 3
    assert summary["theme1_ready_cases"] == 1
    assert summary["training_ready_cases"] == 1
    assert summary["theme1_ready_rate"] == pytest.approx(1 / 3)
    assert summary["available_counts"]["空間モデル"] == 2
    assert summary["missing_counts"]["GOS・粒回転"] == 2


def test_summarize_empty_frame() -> None:
    columns = [
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
    ]
    summary = summarize_readiness(pd.DataFrame(columns=columns))

    assert summary["total_cases"] == 0
    assert summary["theme1_ready_rate"] == 0.0
    assert summary["training_ready_rate"] == 0.0


def test_load_readiness_rejects_missing_database(tmp_path: Path) -> None:
    with pytest.raises(FileNotFoundError, match="解析データベース"):
        load_readiness(tmp_path / "missing.db")


def test_format_readiness_booleans_handles_filtered_frame() -> None:
    frame = pd.DataFrame(
        {
            "theme1_ready": pd.Series([True, False, False], dtype=bool),
            "training_ready": pd.Series([True, False, False], dtype=bool),
            "has_surface_height": pd.Series([True, True, False], dtype=bool),
        }
    )
    filtered = frame[~frame["theme1_ready"]]

    display = format_readiness_booleans(filtered)

    assert display["theme1_ready"].tolist() == ["—", "—"]
    assert display["has_surface_height"].tolist() == ["✓", "—"]
