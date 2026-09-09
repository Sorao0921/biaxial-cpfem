from __future__ import annotations

import io

import matplotlib.pyplot as plt
import streamlit as st

from src.config.pipeline_paths import OUTPUTS_DIR, build_spatial_model_dir
from src.dashboard.catalog import OutputRecord, available_values, filter_records, scan_outputs, initial_record_for
from src.dashboard.plots import (
    height_figure,
    initial_figure,
    INITIAL_METRICS,
    orientation_figure,
    shear_figure,
)
from src.mapping.plot_style import (
    ACCUMULATED_SHEAR_STRAIN_RANGE,
    GOS_RANGE,
    GRAIN_ROTATION_RANGE,
    HEIGHT_RANGE,
)

st.set_page_config(page_title="Simulation Map Comparison", page_icon="◫", layout="wide")


@st.cache_data(show_spinner="出力データを確認しています…")
def load_catalog() -> list[OutputRecord]:
    return scan_outputs(OUTPUTS_DIR)


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


st.title("Simulation Map Comparison")
st.caption("高さ・GOS・結晶粒回転・累積せん断ひずみと、変形前のTaylor factor・初期方位を比較します。")

mode = st.radio(
    "比較方法",
    ["パラメータを変えて同じ指標を比較", "同じモデルで複数指標を比較", "Theme1 帯域比較"],
    horizontal=True,
)

if mode == "Theme1 帯域比較":
    from src.dashboard.theme1_bands import render_band_comparison

    render_band_comparison()
    st.stop()

if st.sidebar.button("データ一覧を更新"):
    load_catalog.clear()
records = load_catalog()
height_by_case = {r.case_key: r for r in records if r.kind == "height"}
if not records:
    st.error(f"表示できるデータが {OUTPUTS_DIR} に見つかりません。")
    st.stop()

with st.sidebar:
    st.header("表示設定")
    grid_columns = st.slider("1行のパネル数", 1, 4, 3)
    st.caption(f"カタログ登録: {len(records):,} マップ")

initial_labels = {"Taylor factor（初期）": "taylor", "初期方位 φ1": "phi1",
                  "初期方位 Φ": "Phi", "初期方位 φ2": "phi2"}

if mode == "パラメータを変えて同じ指標を比較":
    metric_label = st.selectbox("表示指標", ["高さ", "GOS", "結晶粒回転", *initial_labels])
    is_initial = metric_label in initial_labels
    kind = "initial" if is_initial else ("height" if metric_label == "高さ" else "orientation")
    candidates = [r for r in filter_records(records, kind=kind)
                  if (is_initial or r.case_key in height_by_case)
                  and (build_spatial_model_dir(r.seed)/"nodes.csv").exists()]
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
    if is_initial:
        state = 1
        st.caption("state01固定：値と形状は変形前です。初期方位はBunge Euler角（度）で表示します。Taylor factorは公称rhoを使用します。")
    else:
        state = pick("state", available_values(base, "state"), "sweep-state")
    selected = filter_records(base, state=state)

    if not selected:
        st.warning("この条件に表示可能なマップがありません。")
        st.stop()
    if is_initial:
        metric = initial_labels[metric_label]
        shared_range = INITIAL_METRICS[metric][3]
        figures = [(f"initial_{metric}_{varying}_{getattr(record,varying)}",
                    initial_figure(record.path, build_spatial_model_dir(record.seed), metric=metric,
                                   title=f"{INITIAL_METRICS[metric][1]} | {varying}={getattr(record,varying):g}"))
                   for record in selected]
    elif kind == "height":
        shared_range = HEIGHT_RANGE
        figures = [
            (
                f"height_{varying}_{getattr(record, varying)}",
                height_figure(
                    record.path,
                    spatial_model_dir=build_spatial_model_dir(record.seed),
                    title=f"{varying} = {getattr(record, varying):g}",
                    value_range=shared_range,
                ),
            )
            for record in selected
        ]
    else:
        metric = "gos" if metric_label == "GOS" else "rotation"
        shared_range = GOS_RANGE if metric == "gos" else GRAIN_ROTATION_RANGE
        figures = [
            (
                f"{metric}_{varying}_{getattr(record, varying)}",
                orientation_figure(
                    record.path,
                    build_spatial_model_dir(record.seed),
                    coordinates_path=height_by_case[record.case_key].path,
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

    figures = [
        (
            "height",
            height_figure(height_record.path, title="Surface height", value_range=HEIGHT_RANGE,
                          spatial_model_dir=build_spatial_model_dir(height_record.seed)),
        ),
        (
            "gos",
            orientation_figure(
                orientation_record.path,
                build_spatial_model_dir(orientation_record.seed),
                coordinates_path=height_record.path,
                metric="gos",
                title="Grain orientation spread",
                value_range=GOS_RANGE,
            ),
        ),
        (
            "grain_rotation",
            orientation_figure(
                orientation_record.path,
                build_spatial_model_dir(orientation_record.seed),
                coordinates_path=height_record.path,
                metric="rotation",
                title="Grain rotation",
                value_range=GRAIN_ROTATION_RANGE,
            ),
        ),
        (
            "accumulated_shear_strain",
            shear_figure(
                shear_record.path,
                build_spatial_model_dir(shear_record.seed),
                title="Accumulated shear strain",
                value_range=ACCUMULATED_SHEAR_STRAIN_RANGE,
            ),
        ),
    ]
    initial = initial_record_for(records, height_record)
    if initial is not None:
        st.caption("Taylor factor・初期方位はstate01固定（変形前の値・形状）。他の指標は選択stateです。Taylor factorは公称rho、初期方位はBunge Euler角（度）です。")
        initial_selection = st.multiselect("一緒に表示する初期指標", list(initial_labels),
                                          default=list(initial_labels))
        for label in initial_selection:
            metric = initial_labels[label]
            figures.append((f"initial_{metric}_state01",
                            initial_figure(initial.path, build_spatial_model_dir(initial.seed), metric=metric)))
    else:
        st.info("この条件の初期Taylor factor・初期方位データは未生成です。")
    show_figures(figures, grid_columns)
