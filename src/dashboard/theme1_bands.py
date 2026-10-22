"""Seed-faceted band comparisons; fixed controls avoid pooling unlike cases.

Chart contract: rho/texture comparisons use stacked bars in all five sd panels. Both
absolute spectral energy and within-case shares retain individual seeds, with
common axes. Blue/orange/olive plus markers/hatches distinguish the three bands.
Source: graph_spectra/band_energies.csv; no reconstruction or new normalization.
"""
from __future__ import annotations

import io
from pathlib import Path

import matplotlib.pyplot as plt

from src.dashboard.style import TICK_SIZE, apply_figure_style
import numpy as np
import pandas as pd
import streamlit as st

from src.config.pipeline_paths import THEME1_DIR, build_post_directories

BANDS = ("low", "mid", "high")
SD_LEVELS = (2, 4, 6, 8, 10)
COLORS = ("#3575AB", "#CD8032", "#7B8740")
FIELDS = ("texture", "rho", "sd", "state")


def read_height_bands(path: Path) -> pd.DataFrame:
    data = pd.read_csv(path)
    required = {"case_id", "seed", "signal", "band", "energy", "energy_fraction", *FIELDS}
    if required - set(data):
        raise ValueError(f"必要な列がありません: {sorted(required - set(data))}")
    data = data.loc[data.signal.eq("height_mean")].copy()
    if data.empty:
        raise ValueError("粒平均高さの帯域データがありません。")
    if data[list(required)].isna().any().any():
        raise ValueError("高さの帯域データに欠損値があります。")
    if data.duplicated(["seed", *FIELDS, "band"]).any():
        raise ValueError("同じ条件・帯域の行が重複しています。")
    if not data.groupby("case_id").band.agg(lambda x: set(x) == set(BANDS) and len(x) == 3).all():
        raise ValueError("低・中・高の3帯域が揃っていないケースがあります。")
    values = data[["energy", "energy_fraction"]].to_numpy(float)
    if not np.isfinite(values).all() or (values < 0).any():
        raise ValueError("エネルギーまたは比率に不正な値があります。")
    totals = data.groupby("case_id").energy.transform("sum")
    expected = np.divide(data.energy, totals, out=np.zeros(len(data)), where=totals.ne(0))
    if not np.allclose(data.energy_fraction, expected, atol=1e-8, rtol=1e-6):
        raise ValueError("帯域エネルギーと保存済み比率が一致しません。")
    return data


def attach_equivalent_strain(data: pd.DataFrame) -> pd.DataFrame:
    """CSV data row 1 is initial state 1; retain rows to avoid shifted states."""
    mappings = []
    for rho, seed in data[["rho", "seed"]].drop_duplicates().itertuples(index=False, name=None):
        path = build_post_directories(float(rho), int(seed)).equivalent_strain_csv
        frame = pd.read_csv(path, encoding="utf-8-sig")
        frame.columns = frame.columns.str.strip().str.lower()
        if "eps_eq" not in frame:
            raise ValueError(f"eps_eq列がありません: {path}")
        values = pd.to_numeric(frame.eps_eq, errors="coerce")
        if not np.isfinite(values).all() or values.lt(0).any():
            raise ValueError(f"相当ひずみに欠損値または不正な値があります: {path}")
        mappings.append(pd.DataFrame({"rho": rho, "seed": seed,
                                      "state": np.arange(1, len(frame) + 1),
                                      "eps_eq": values}))
    result = data.merge(pd.concat(mappings, ignore_index=True),
                        on=["rho", "seed", "state"], how="left", validate="many_to_one")
    if result.eps_eq.isna().any():
        raise ValueError("選択したstateに対応する相当ひずみがeps_equivalent.csvにありません。")
    return result


def comparison_figure(data: pd.DataFrame, varying: str, metric: str, context: str):
    """Stack all three bands for every even sd, retaining separate seed panels."""
    if varying not in ("rho", "texture"):
        raise ValueError("比較条件はrhoまたはtextureです。")
    data = data.loc[data.sd.isin(SD_LEVELS)]
    seeds = sorted(data.seed.unique())
    levels = sorted(data[varying].unique())
    fraction = metric == "energy_fraction"
    scale = 100 if fraction else 1
    maximum = data.groupby("case_id")[metric].sum().max() * scale
    fig, axes = plt.subplots(len(seeds), len(SD_LEVELS),
                             figsize=(21, 3.8 * len(seeds) + 1.5), squeeze=False,
                             sharex=True, sharey=True, layout="constrained")
    for row, seed in enumerate(seeds):
        for column, sd in enumerate(SD_LEVELS):
            ax = axes[row, column]
            subset = data.loc[data.seed.eq(seed) & data.sd.eq(sd)]
            table = subset.pivot(index=varying, columns="band", values=metric).reindex(index=levels, columns=BANDS)
            x = np.arange(len(levels))
            bottom = np.zeros(len(levels))
            for band, color, hatch in zip(BANDS, COLORS, ("", "//", "..")):
                y = table[band].to_numpy() * scale
                ax.bar(x, y, bottom=bottom, width=.7, color=color, label=band,
                       hatch=hatch, edgecolor="#333333", linewidth=.4)
                bottom += y
            ax.set_xticks(x, [str(v) for v in levels], rotation=30 if varying == "texture" else 0)
            ax.set_title(f"seed {seed} | sd={sd}", fontsize=11)
            if column == 0:
                ax.set_ylabel("Band share (%)" if fraction else "Spectral energy")
            if row == len(seeds)-1:
                ax.set_xlabel(varying)
            ax.set_ylim(0, 100 if fraction else (maximum * 1.12 or 1))
            ax.grid(axis="y", alpha=.2)
            ax.set_axisbelow(True)
            ax.spines[["top", "right"]].set_visible(False)
    handles, labels = axes[0, 0].get_legend_handles_labels()
    fig.legend(handles, labels, ncol=3, loc="outside lower center", fontsize=TICK_SIZE, frameon=False)
    label = "Band shares" if fraction else "Absolute band energies"
    fig.suptitle(f"Grain-mean height: {label}\n{context}", fontsize=12)
    return apply_figure_style(fig)


@st.cache_data(show_spinner=False)
def _cached_data(path: str, modified: int) -> pd.DataFrame:
    return read_height_bands(Path(path))


def render_band_comparison() -> None:
    st.header("高さの帯域比較")
    path = THEME1_DIR / "graph_spectra" / "band_energies.csv"
    try:
        data = _cached_data(str(path), path.stat().st_mtime_ns)
    except (OSError, ValueError) as exc:
        st.error(f"帯域データを読み込めません: {exc}")
        return
    st.caption(f"保存済みデータ: {data.case_id.nunique():,} ケース / {data.seed.nunique()} seed ｜ {path.name}")
    st.caption("low＝低周波、mid＝中周波、high＝高周波。比率の分母は3帯域の合計です。"
               "粒内粗さと除外された先頭固有モードは含みません。絶対値は保存済みFourier係数の二乗和で、Sq²や面積平均ではありません。")
    varying = st.selectbox("比較する条件", ["rho", "texture"], key="bands-axis")
    selected = data.loc[data.sd.isin(SD_LEVELS)].copy()
    if selected.empty:
        st.info("sd=2・4・6・8・10の帯域データがありません。")
        return
    fixed = {}
    controls = st.columns(2)
    for column, field in zip(controls, [f for f in FIELDS if f not in (varying, "sd")]):
        with column:
            values = sorted(selected[field].unique())
            fixed[field] = st.selectbox(field, values, key=f"bands-{varying}-{field}")
            selected = selected.loc[selected[field].eq(fixed[field])]
    seeds = st.multiselect("表示するseed", sorted(selected.seed.unique()),
                           default=sorted(selected.seed.unique()), key=f"bands-seeds-{varying}")
    selected = selected.loc[selected.seed.isin(seeds)].copy()
    if selected.empty:
        st.info("表示するseedを選択してください。")
        return
    levels = sorted(selected[varying].unique())
    expected_count = len(levels) * len(seeds) * len(SD_LEVELS)
    if selected.case_id.nunique() != expected_count:
        st.warning("seed・sd間で比較条件が揃っていません。欠けている条件は空白で表示します。")
    zero_count = selected.groupby("case_id").energy.sum().eq(0).sum()
    if zero_count:
        st.info(f"3帯域の合計が0のケースが{zero_count}件あります。保存値に従い比率を0%で表示します。")
    context = ", ".join(f"{key}={value}" for key, value in fixed.items())
    st.caption(f"固定条件: {context} ｜ 表示: {selected.case_id.nunique()} ケース。sd=2・4・6・8・10をすべて表示し、seed間の平均化は行いません。")
    downloads = []
    for metric, title in (("energy", "絶対エネルギー"), ("energy_fraction", "帯域比率")):
        st.subheader(title)
        figure = comparison_figure(selected, varying, metric, context)
        st.pyplot(figure, width="stretch")
        buffer = io.BytesIO()
        figure.savefig(buffer, format="png", dpi=180, bbox_inches="tight")
        plt.close(figure)
        downloads.append((title, metric, buffer.getvalue()))
    with st.expander("PNGを保存"):
        for title, metric, data in downloads:
            st.download_button(f"{title}のPNGを保存", data,
                               file_name=f"height_bands_{varying}_{metric}.png", mime="image/png")
    with st.expander("表示データと出典"):
        st.caption(str(path))
        st.dataframe(selected, hide_index=True)
        st.download_button("表示データをCSVで保存", selected.to_csv(index=False).encode("utf-8-sig"),
                           file_name=f"height_bands_{varying}.csv", mime="text/csv")
