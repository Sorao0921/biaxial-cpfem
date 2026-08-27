from __future__ import annotations

import io
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import streamlit as st

from src.dashboard.catalog import OutputRecord, available_values, filter_records, scan_outputs
from src.dashboard.plots import (
    height_figure,
    orientation_figure,
    read_grain_metric,
    read_height,
    shear_figure,
)

ROOT = Path(__file__).resolve().parents[2]
OUTPUTS_DIR = ROOT / "outputs"
SPATIAL_MODEL_DIR = ROOT / "database" / "spatial_model"

st.set_page_config(page_title="Simulation Map Comparison", page_icon="◫", layout="wide")


@st.cache_data(show_spinner="出力データを確認しています…")
def load_catalog() -> list[OutputRecord]:
    return scan_outputs(OUTPUTS_DIR)


@st.cache_data(show_spinner=False)
def height_range(paths: tuple[str, ...]) -> tuple[float, float]:
    ranges = [read_height(path)[2] for path in paths]
    return float(min(np.nanmin(v) for v in ranges)), float(max(np.nanmax(v) for v in ranges))


@st.cache_data(show_spinner=False)
def metric_range(paths: tuple[str, ...], metric: str) -> tuple[float, float]:
    values = [value for path in paths for value in read_grain_metric(path, metric).values()]
    return float(np.nanmin(values)), float(np.nanmax(values))


def pick(label: str, values, key: str):
    if not values:
        st.error(f"{label}に利用可能な値がありません。")
        st.stop()
    return st.selectbox(label, values, key=key)


def show_figures(figures: list[tuple[str, object]], columns: int) -> None:
    for start in range(0, len(figures), columns):
        row = st.columns(columns)
        for column, (label, figure) in zip(row, figures[start : start + columns]):
            with column:
                st.pyplot(figure, width="stretch")
                buffer = io.BytesIO()
                figure.savefig(buffer, format="png", dpi=200, bbox_inches="tight")
                st.download_button(
                    "PNGを保存",
                    buffer.getvalue(),
                    file_name=f"{label}.png".replace(" ", "_"),
                    mime="image/png",
                    key=f"download-{label}",
                    width="stretch",
                )
                plt.close(figure)


records = load_catalog()
st.title("Simulation Map Comparison")
st.caption("高さ・GOS・結晶粒回転・累積せん断ひずみを、同一条件で比較します。")

if not records:
    st.error(f"表示できるデータが {OUTPUTS_DIR} に見つかりません。")
    st.stop()

mode = st.radio(
    "比較方法",
    ["パラメータを変えて同じ指標を比較", "同じモデルで複数指標を比較"],
    horizontal=True,
)

with st.sidebar:
    st.header("表示設定")
    grid_columns = st.slider("1行のパネル数", 1, 4, 3)
    st.caption(f"カタログ登録: {len(records):,} マップ")

if mode == "パラメータを変えて同じ指標を比較":
    metric_label = st.selectbox("表示指標", ["高さ", "GOS", "結晶粒回転"])
    kind = "height" if metric_label == "高さ" else "orientation"
    candidates = filter_records(records, kind=kind)
    varying = st.selectbox("横並びで変化させる条件", ["sd", "rho"])

    controls = st.columns(4)
    with controls[0]:
        rho = None if varying == "rho" else pick("rho", available_values(candidates, "rho"), "sweep-rho")
    base = filter_records(candidates, rho=rho)
    with controls[1]:
        seed = pick("seed", available_values(base, "seed"), "sweep-seed")
    base = filter_records(base, seed=seed)
    with controls[2]:
        texture = pick("texture", available_values(base, "texture"), "sweep-texture")
    base = filter_records(base, texture=texture)
    with controls[3]:
        sd = None if varying == "sd" else pick("sd", available_values(base, "sd"), "sweep-sd")
    base = filter_records(base, sd=sd)
    state = pick("state", available_values(base, "state"), "sweep-state")
    selected = filter_records(base, state=state)

    if not selected:
        st.warning("この条件に表示可能なマップがありません。")
        st.stop()
    paths = tuple(str(record.path) for record in selected)
    if kind == "height":
        shared_range = height_range(paths)
        figures = [
            (
                f"height_{varying}_{getattr(record, varying)}",
                height_figure(
                    record.path,
                    title=f"{varying} = {getattr(record, varying):g}",
                    value_range=shared_range,
                ),
            )
            for record in selected
        ]
    else:
        metric = "gos" if metric_label == "GOS" else "rotation"
        shared_range = metric_range(paths, metric)
        figures = [
            (
                f"{metric}_{varying}_{getattr(record, varying)}",
                orientation_figure(
                    record.path,
                    SPATIAL_MODEL_DIR / f"seed{record.seed}",
                    metric=metric,
                    title=f"{metric_label} | {varying} = {getattr(record, varying):g}",
                    value_range=shared_range,
                ),
            )
            for record in selected
        ]
    st.caption(f"共通表示範囲: {shared_range[0]:.6g} ～ {shared_range[1]:.6g}")
    show_figures(figures, grid_columns)

else:
    # Only cases present in every displayed dataset are selectable.
    height_keys = {record.case_key for record in records if record.kind == "height"}
    orientation_keys = {record.case_key for record in records if record.kind == "orientation"}
    shear_keys = {record.case_key for record in records if record.kind == "shear"}
    shared_keys = height_keys & orientation_keys & shear_keys
    candidates = [record for record in records if record.kind == "height" and record.case_key in shared_keys]
    if not candidates:
        st.warning("高さ・orientation metrics・せん断ひずみが揃った条件がありません。")
        st.stop()

    controls = st.columns(5)
    filters = {}
    current = candidates
    for column, field in zip(controls, ["rho", "seed", "texture", "sd", "state"]):
        with column:
            filters[field] = pick(field, available_values(current, field), f"fields-{field}")
        current = filter_records(current, **{field: filters[field]})
    height_record = current[0]
    orientation_record = filter_records(
        records, kind="orientation", **filters
    )[0]
    shear_record = filter_records(records, kind="shear", **filters)[0]

    height_values = read_height(height_record.path)[2]
    height_limits = (float(np.nanmin(height_values)), float(np.nanmax(height_values)))
    figures = [
        (
            "height",
            height_figure(height_record.path, title="Surface height", value_range=height_limits),
        ),
        (
            "gos",
            orientation_figure(
                orientation_record.path,
                SPATIAL_MODEL_DIR / f"seed{orientation_record.seed}",
                metric="gos",
                title="Grain orientation spread",
            ),
        ),
        (
            "grain_rotation",
            orientation_figure(
                orientation_record.path,
                SPATIAL_MODEL_DIR / f"seed{orientation_record.seed}",
                metric="rotation",
                title="Grain rotation",
            ),
        ),
        (
            "accumulated_shear_strain",
            shear_figure(
                shear_record.path,
                SPATIAL_MODEL_DIR / f"seed{shear_record.seed}",
                title="Accumulated shear strain",
            ),
        ),
    ]
    show_figures(figures, grid_columns)
