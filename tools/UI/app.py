from __future__ import annotations

import io

import matplotlib.pyplot as plt
import streamlit as st

from src.config.pipeline_paths import OUTPUTS_DIR, build_spatial_model_dir, build_pre_directories
from src.crystal_plasticity.taylor_pipeline import ensure_record
from src.crystal_plasticity.slip_activity_pipeline import ensure_activity
from src.dashboard.export import combine_map_pngs, map_png_name, combined_png_name
from src.dashboard.catalog import OutputRecord, available_values, filter_records, scan_outputs
from src.dashboard.plots import (
    height_figure,
    initial_figure,
    orientation_figure,
    shear_figure,
    slip_activity_figure,
    shared_taylor_range,
    uniform_initial_map,
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
    return [r for r in scan_outputs(OUTPUTS_DIR) if r.kind != "initial"]


def pick(label: str, values, key: str):
    if not values:
        st.error(f"{label}に利用可能な値がありません。")
        st.stop()
    return st.selectbox(label, values, key=key)


def show_figures(figures: list[tuple[str, object]], columns: int, *, filenames, combined_filename) -> None:
    downloads = []
    for start in range(0, len(figures), columns):
        row = st.columns(columns)
        for column, (label, figure) in zip(row, figures[start : start + columns]):
            with column:
                st.pyplot(figure, width="stretch")
            buffer = io.BytesIO()
            figure.savefig(buffer, format="png", dpi=200, bbox_inches="tight")
            downloads.append((label, buffer.getvalue()))
            plt.close(figure)

    if downloads:
        st.download_button(
            "表示中の全マップを1枚のPNGで保存",
            combine_map_pngs([data for _, data in downloads], columns),
            file_name=combined_filename,
            mime="image/png",
            key="download-all-maps",
            width="stretch",
        )

    with st.expander("PNGを保存"):
        for start in range(0, len(downloads), columns):
            row = st.columns(columns)
            for column, (label, data) in zip(row, downloads[start : start + columns]):
                with column:
                    st.download_button(
                        f"{label} のPNGを保存",
                        data,
                        file_name=filenames[label],
                        mime="image/png",
                        key=f"download-{label}",
                        width="stretch",
                    )


st.title("Simulation Map Comparison")
st.caption("高さ・GOS・結晶粒回転・累積せん断ひずみ・各stateのTaylor factorを比較します。")

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
    st.caption("Taylor factorの色範囲は表示値から自動調整し、state別とinitialで揃えます。")
    st.caption("Taylor factorは各stateの粒平均方位から算出。公称rho・等ひずみを仮定し、局所すべり量／塑性ひずみの実測比とは異なります。")

if mode == "パラメータを変えて同じ指標を比較":
    metric_label = st.selectbox("表示指標", ["高さ", "GOS", "結晶粒回転", "Taylor factor（state別）", "Z-directed slip activity"])
    is_slip_activity = metric_label == "Z-directed slip activity"
    kind = "taylor" if metric_label == "Taylor factor（state別）" else ("height" if metric_label == "高さ" else "orientation")
    source_kind = "height" if is_slip_activity else ("orientation" if kind == "taylor" else kind)
    candidates = [r for r in filter_records(records, kind=source_kind)
                  if (not is_slip_activity or r.state > 1)
                  and r.case_key in height_by_case
                  and (build_spatial_model_dir(r.seed)/"nodes.csv").exists()]
    if not is_slip_activity and kind != "taylor":
        initial_metric = {"高さ": "height", "GOS": "gos", "結晶粒回転": "rotation"}[metric_label]
        candidates = [r for r in candidates if r.state != 1 or not uniform_initial_map(
            r.path, build_spatial_model_dir(r.seed), height_by_case[r.case_key].path,
            metric=initial_metric)]
    varying = st.selectbox("横並びで変化させる条件", ["sd", "rho", "state"])

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
    if varying == "state":
        state = None
    else:
        state = pick("state", available_values(base, "state"), "sweep-state")
    selected = filter_records(base, state=state)

    if not selected:
        st.warning("この条件に表示可能なマップがありません。")
        st.stop()
    if kind == "taylor":
        actions = st.columns(2)
        recalculate = actions[0].button("選択中のstateを計算・更新", key="taylor-selected")
        recalculate_all = actions[1].button("同じ条件の全stateを計算・更新", key="taylor-all")
        with st.spinner("各stateの粒平均方位からTaylor factorを計算しています…"):
            if recalculate_all:
                for source in base:
                    ensure_record(source, OUTPUTS_DIR, force=True)
            selected = [ensure_record(source, OUTPUTS_DIR, force=recalculate)
                        for source in selected]
        if recalculate or recalculate_all:
            st.success("Taylor factorを計算・保存しました。")
        st.caption("未計算、または元の方位データが更新されたstateは自動計算します。")
    if is_slip_activity:
        refresh = st.button("表示中のz方向すべり活動を計算・更新", key="slip-activity-sweep")
        figures = []
        with st.spinner("z方向すべり活動の計算結果を確認しています…"):
            for record in selected:
                try:
                    path = ensure_activity(record, OUTPUTS_DIR, force=refresh)
                    figure = slip_activity_figure(
                        path, build_spatial_model_dir(record.seed),
                        coordinates_path=height_by_case[record.case_key].path,
                        title=f"Z-directed slip activity\n{varying} = {getattr(record, varying):g}")
                    figures.append((f"z_slip_activity_{varying}_{getattr(record, varying):g}", figure))
                except (ValueError, OSError, KeyError) as error:
                    st.warning(f"{varying} = {getattr(record, varying):g}: {error}")
        if not figures:
            st.warning("表示可能なz方向すべり活動の区間データがありません。")
            st.stop()
        # Use displayed element values only, including the same edge cropping.
        upper = max(float(figure.axes[0].collections[0].get_array().max())
                    for _, figure in figures)
        shared_range = (0., upper if upper > 0 else 1e-12)
        for _, figure in figures:
            figure.axes[0].collections[0].set_clim(*shared_range)
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
        metric = "taylor" if kind == "taylor" else ("gos" if metric_label == "GOS" else "rotation")
        shared_range = shared_taylor_range([
            (record.path, build_spatial_model_dir(record.seed), height_by_case[record.case_key].path)
            for record in selected
        ]) if metric == "taylor" else (GOS_RANGE if metric == "gos" else GRAIN_ROTATION_RANGE)
        figures = [
            (
                f"{metric}_{varying}_{getattr(record, varying)}",
                orientation_figure(
                    record.path,
                    build_spatial_model_dir(record.seed),
                    coordinates_path=height_by_case[record.case_key].path,
                    metric=metric,
                    title=f"{dict(gos='GOS', rotation='Grain rotation', taylor='Taylor factor')[metric]}\n{varying} = {getattr(record, varying):g}",
                    value_range=shared_range,
                ),
            )
            for record in selected
        ]
    st.caption(f"共通表示範囲: {shared_range[0]:.6g} ～ {shared_range[1]:.6g}")
    filenames = {}
    displayed_records = []
    for label, _ in figures:
        record = next(r for r in selected
                      if label.endswith(f"_{varying}_{getattr(r, varying):g}"))
        metric_name = label.rsplit(f"_{varying}_", 1)[0]
        filenames[label] = map_png_name(metric_name, record)
        displayed_records.append(record)
    show_figures(figures, grid_columns, filenames=filenames,
                 combined_filename=combined_png_name(f"{metric_name}_comparison", displayed_records))


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
                title="GOS",
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
                coordinates_path=height_record.path,
                title="Accumulated\nshear strain",
                value_range=ACCUMULATED_SHEAR_STRAIN_RANGE,
            ),
        ),
    ]
    figures.append(("slip_concentration", shear_figure(
        shear_record.path, build_spatial_model_dir(shear_record.seed),
        coordinates_path=height_record.path, metric="concentration",
        title="Slip concentration", value_range=(0., 1.), cmap="viridis")))
    st.caption("すべり集中度：表示範囲内の各粒について、すべり系別の累積ひずみを要素平均し、最大値を12系の総和で割ります。1は1系に集中、1/12は均等、未活動は0です。")
    recalculate = st.button("このstateのTaylor factorを計算・更新", key="taylor-current")
    with st.spinner("このstateのTaylor factorを確認しています…"):
        taylor_record = ensure_record(orientation_record, OUTPUTS_DIR, force=recalculate)
    initial_path = (build_pre_directories(height_record.seed).orientation_csv_dir /
                    f"{height_record.texture}_sigma{height_record.sd}_seed{height_record.seed}.csv")
    initial_source = OutputRecord("initial", height_record.rho, height_record.seed,
                                  height_record.texture, height_record.sd, 1,
                                  initial_path, "initial_input")
    with st.spinner("初期Taylor factorを確認しています…"):
        initial_record = ensure_record(initial_source, OUTPUTS_DIR)
    taylor_range = shared_taylor_range([
        (taylor_record.path, build_spatial_model_dir(height_record.seed), height_record.path),
        (initial_record.path, build_spatial_model_dir(height_record.seed), height_record.path),
    ])
    figures.append(("taylor_factor_state", orientation_figure(
        taylor_record.path, build_spatial_model_dir(height_record.seed),
        coordinates_path=height_record.path, metric="taylor",
        title="Taylor factor", value_range=taylor_range)))
    figures.append(("taylor_factor_initial_state01", initial_figure(
        initial_record.path, build_spatial_model_dir(height_record.seed), metric="taylor",
        title="Initial Taylor factor", value_range=taylor_range,
        selection_coordinates_path=height_record.path)))
    st.caption("7枚目は初期Taylor factorです。選択stateにかかわらず変形前の値・形状・粒界を表示し、6枚目と同じ要素範囲で端部を除去し、色範囲も揃えています。")
    if recalculate:
        st.success(f"state{height_record.state:02d}のTaylor factorを更新しました。")
    st.caption("8枚目：12系の累積せん断ひずみの直前stateとの差分を、eps_equivalent.csvのマクロ相当ひずみ増分で割ってz方向へ射影します。計算済みの値を表示表面のelementごとに描画します。")
    activity_upper = st.number_input("z方向活動の色範囲上限（0で自動）", min_value=0.0, value=0.0, format="%.6g")
    refresh_activity = st.button("このstateのz方向すべり活動を計算・更新", key="slip-activity-current")
    try:
        with st.spinner("z方向すべり活動の計算結果を確認しています…"):
            activity_path = ensure_activity(height_record, OUTPUTS_DIR, force=refresh_activity)
        activity_figure = slip_activity_figure(
            activity_path, build_spatial_model_dir(height_record.seed),
            coordinates_path=height_record.path,
            value_range=(0., activity_upper) if activity_upper > 0 else None,
            title="Z-directed slip activity")
    except (ValueError, OSError, KeyError) as error:
        st.warning(f"8枚目: {error}")
        activity_figure, activity_axis = plt.subplots(figsize=(5.2, 4.8))
        activity_axis.set_axis_off()
        activity_axis.set_title("Z-directed slip activity")
        activity_axis.text(.5, .5, "Required interval data unavailable", ha="center", va="center")
    figures.append(("z_slip_activity", activity_figure))
    filenames = {
        label: map_png_name("taylor_factor_initial" if label == "taylor_factor_initial_state01" else label,
                            height_record, initial=label == "taylor_factor_initial_state01")
        for label, _ in figures
    }
    show_figures(figures, grid_columns, filenames=filenames,
                 combined_filename=combined_png_name("all_maps", [height_record]))
