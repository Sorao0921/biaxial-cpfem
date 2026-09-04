from __future__ import annotations

import pandas as pd
import streamlit as st

from src.config.pipeline_paths import ANALYSIS_DATABASE, PROJECT_ROOT
from src.data_catalog.catalog import scan
from src.dashboard.readiness import (
    format_readiness_booleans,
    load_readiness,
    summarize_readiness,
)

ROOT = PROJECT_ROOT
DATABASE = ANALYSIS_DATABASE

st.set_page_config(
    page_title="モデル充足状況",
    page_icon=":material/database:",
    layout="wide",
)


@st.cache_data(show_spinner="データベースを読み込んでいます…")
def cached_readiness(database: str, modified_ns: int) -> pd.DataFrame:
    del modified_ns  # The mtime is part of the cache key.
    return load_readiness(database)


st.title("モデル充足状況")
st.caption(
    "Theme 1に必要な解析結果が、どのモデルに揃っているかをdatabase/analysis.dbから確認します。"
)

refresh_message = st.session_state.pop("catalog_refresh_message", None)
if refresh_message:
    st.toast(refresh_message, icon=":material/check_circle:")

if not DATABASE.is_file():
    st.error(f"解析データベースが見つかりません: {DATABASE}", icon=":material/error:")
    st.stop()

catalog = cached_readiness(str(DATABASE), DATABASE.stat().st_mtime_ns)

with st.sidebar:
    if st.button(
        "カタログを更新",
        icon=":material/refresh:",
        type="primary",
        width="stretch",
        help="ローカルファイルを増分スキャンし、analysis.dbへ反映します。",
    ):
        try:
            with st.status("ローカルファイルを確認しています…", expanded=True) as status:
                result = scan(ROOT, DATABASE, fingerprint=False, progress_every=500)
                status.write(
                    f"{result['files_seen']:,}ファイルを確認し、"
                    f"{result['files_updated']:,}ファイルを更新しました。"
                )
                if result["errors"]:
                    status.update(
                        label=f"カタログ更新完了（エラー {result['errors']}件）",
                        state="error",
                    )
                else:
                    status.update(label="カタログ更新完了", state="complete")
            cached_readiness.clear()
            st.session_state["catalog_refresh_message"] = (
                f"カタログを更新しました（{result['elapsed_seconds']:.1f}秒）"
            )
            st.rerun()
        except Exception as error:
            st.error(f"カタログを更新できませんでした: {error}", icon=":material/error:")
    st.header("絞り込み")
    selected_rho = st.multiselect("rho", sorted(catalog["rho"].unique()))
    selected_seed = st.multiselect("seed", sorted(catalog["seed"].unique()))
    st.caption(
        f"DB更新日時: {pd.Timestamp(DATABASE.stat().st_mtime, unit='s'):%Y-%m-%d %H:%M:%S}"
    )

filtered = catalog.copy()
for column, values in (
    ("rho", selected_rho),
    ("seed", selected_seed),
):
    if values:
        filtered = filtered[filtered[column].isin(values)]

summary = summarize_readiness(filtered)

if filtered.empty:
    st.warning(
        "選択条件に一致するケースがありません。", icon=":material/filter_alt_off:"
    )
    st.stop()

availability = pd.DataFrame(
    {
        "データ": list(summary["available_counts"]),
        "あり": list(summary["available_counts"].values()),
        "不足": list(summary["missing_counts"].values()),
    }
)
availability["充足率"] = availability["あり"] / summary["total_cases"]

with st.container(border=True):
    st.subheader("データ別の充足状況")
    st.dataframe(
        availability,
        hide_index=True,
        column_config={
            "充足率": st.column_config.ProgressColumn(
                "充足率", min_value=0.0, max_value=1.0, format="percent"
            )
        },
    )

with st.container(border=True):
    st.subheader("texture別のモデル構成")
    st.caption("各横棒はrho・seedの組合せです。色は5種類のtextureを表します。")
    textures = ["brass", "copper", "cube", "goss", "s"]
    texture_colors = ["#4C78A8", "#F58518", "#54A24B", "#E45756", "#B279A2"]
    texture_counts = (
        filtered.assign(
            条件=lambda frame: frame.apply(
                lambda row: f"rho {row['rho']:g} / seed {int(row['seed'])}", axis=1
            )
        )
        .groupby(["条件", "texture"])
        .size()
        .unstack(fill_value=0)
        .reindex(columns=textures, fill_value=0)
        .reset_index()
    )
    st.bar_chart(
        texture_counts,
        x="条件",
        y=textures,
        color=texture_colors,
        horizontal=True,
        stack=True,
        x_label="ケース数",
        y_label="rho / seed",
    )

st.subheader("ケース一覧")
display = filtered[
    [
        "postprocess_status",
        "rho",
        "seed",
        "texture",
        "sd",
        "state",
        "has_surface_height",
        "has_orientation_metrics",
        "has_accumulated_shear_strain",
        "has_spatial_model",
        "has_initial_orientation",
        "theme1_ready",
        "training_ready",
        "missing_items",
    ]
].copy()
display = format_readiness_booleans(display)
display = display.rename(
    columns={
        "postprocess_status": "postprocess",
        "has_surface_height": "表面高さ",
        "has_orientation_metrics": "GOS・粒回転",
        "has_accumulated_shear_strain": "累積せん断ひずみ",
        "has_spatial_model": "空間モデル",
        "has_initial_orientation": "初期方位",
        "theme1_ready": "Theme 1",
        "training_ready": "学習可能",
        "missing_items": "不足データ",
    }
)


def highlight_postprocess(value: object) -> str:
    return {
        "未実行": "background-color: #FDE2E1; color: #8C1D18; font-weight: 600",
        "一部不足": "background-color: #FFF1CC; color: #7A4D00; font-weight: 600",
        "完了": "background-color: #DDF3E4; color: #175C2C; font-weight: 600",
    }.get(str(value), "")


styled_display = display.style.map(highlight_postprocess, subset=["postprocess"])
st.dataframe(styled_display, hide_index=True, height=520)
st.download_button(
    "表示中の一覧をCSV保存",
    filtered.to_csv(index=False).encode("utf-8-sig"),
    file_name="model_readiness.csv",
    mime="text/csv",
    icon=":material/download:",
)

st.caption(
    "表示内容はデータベースの最終スキャン時点です。最新ファイルを反映するには、先にデータカタログを再スキャンしてください。"
)
