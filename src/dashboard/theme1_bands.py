"""Seed-faceted band comparisons; fixed controls avoid pooling unlike cases.

Chart contract: state uses equivalent-strain coordinates; other conditions use grouped bars. Both
absolute spectral energy and within-case shares retain individual seeds, with
common axes. Blue/orange/olive plus markers/hatches distinguish the three bands.
Source: graph_spectra/band_energies.csv; no reconstruction or new normalization.
"""
from __future__ import annotations

import io
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import streamlit as st

from src.config.pipeline_paths import THEME1_DIR, build_post_directories

BANDS = ("low", "mid", "high")
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
    seeds = sorted(data.seed.unique())
    levels = sorted(data[varying].unique())
    fig, axes = plt.subplots(len(seeds), 1, figsize=(9, 3.1 * len(seeds)),
                             squeeze=False, sharex=True, sharey=True, layout="constrained")
    fraction = metric == "energy_fraction"
    maximum = data[metric].max() * (100 if fraction else 1)
    for ax, seed in zip(axes[:, 0], seeds):
        subset = data.loc[data.seed.eq(seed)]
        table = subset.pivot(index=varying, columns="band", values=metric).reindex(levels)
        x = np.arange(len(levels))
        if varying == "state":
            x = subset.groupby("state").eps_eq.first().reindex(levels).to_numpy()
        for i, (band, color, marker, hatch) in enumerate(zip(BANDS, COLORS, ("o", "s", "^"), ("", "//", ".."))):
            y = table[band].to_numpy() * (100 if fraction else 1)
            if varying == "state":
                ax.plot(x, y, color=color, marker=marker, label=band, linewidth=1.5, markersize=4)
            else:
                ax.bar(x + (i - 1) * .25, y, width=.25, color=color, label=band,
                       hatch=hatch, edgecolor="#333333", linewidth=.4)
                ax.set_xticks(x, [str(v) for v in levels])
        ax.set_title(f"seed {seed} | {subset.case_id.nunique()} cases", loc="left", fontsize=11)
        ax.set_ylabel("Band share (%)" if fraction else "Spectral energy (height unit squared)")
        ax.set_ylim(0, 100 if fraction else (maximum * 1.12 or 1))
        ax.grid(axis="y", alpha=.2)
        ax.set_axisbelow(True)
        ax.spines[["top", "right"]].set_visible(False)
    axes[0, 0].legend(ncol=3, loc="upper right")
    axes[-1, 0].set_xlabel(r"Equivalent strain $\varepsilon_{eq}$ (–)" if varying == "state" else varying)
    label = "Band shares" if fraction else "Absolute band energies"
    fig.suptitle(f"Grain-mean height: {label}\n{context}", fontsize=12)
    return fig


@st.cache_data(show_spinner=False)
def _cached_data(path: str, modified: int) -> pd.DataFrame:
    return read_height_bands(Path(path))


def render_band_comparison() -> None:
    st.header("Theme1：高さの帯域比較")
    path = THEME1_DIR / "graph_spectra" / "band_energies.csv"
    try:
        data = _cached_data(str(path), path.stat().st_mtime_ns)
    except (OSError, ValueError) as exc:
        st.error(f"帯域データを読み込めません: {exc}")
        return
    st.caption(f"保存済みデータ: {data.case_id.nunique():,} ケース / {data.seed.nunique()} seed ｜ {path.name}")
    st.caption("low＝低周波、mid＝中周波、high＝高周波。比率の分母は3帯域の合計です。"
               "粒内粗さと除外された先頭固有モードは含みません。絶対値は保存済みFourier係数の二乗和で、Sq²や面積平均ではありません。")
    varying = st.selectbox("比較する条件", ["state", "texture", "rho", "sd"], key="bands-axis",
                           format_func=lambda value: "相当ひずみ（state推移）" if value == "state" else value)
    selected = data
    fixed = {}
    controls = st.columns(3)
    for column, field in zip(controls, [f for f in FIELDS if f != varying]):
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
    if varying == "state":
        try:
            selected = attach_equivalent_strain(selected)
        except (OSError, ValueError) as exc:
            st.error(f"相当ひずみを読み込めません: {exc}")
            return
        st.caption("横軸は各rho・seedのeps_equivalent.csvのeps_eq（無次元）です。CSVの1行目をstate 1として対応付けます。")
    levels = sorted(selected[varying].unique())
    expected_count = len(levels) * len(seeds)
    if selected.case_id.nunique() != expected_count:
        st.warning("seed間で比較条件が揃っていません。欠けている条件は空白で表示します。")
    zero_count = selected.groupby("case_id").energy.sum().eq(0).sum()
    if zero_count:
        st.info(f"3帯域の合計が0のケースが{zero_count}件あります。保存値に従い比率を0%で表示します。")
    context = ", ".join(f"{key}={value}" for key, value in fixed.items())
    st.caption(f"固定条件: {context} ｜ 表示: {selected.case_id.nunique()} ケース。seed間の平均化は行いません。")
    for metric, title in (("energy", "絶対エネルギー"), ("energy_fraction", "帯域比率")):
        st.subheader(title)
        figure = comparison_figure(selected, varying, metric, context)
        st.pyplot(figure, width="stretch")
        buffer = io.BytesIO()
        figure.savefig(buffer, format="png", dpi=180, bbox_inches="tight")
        plt.close(figure)
        st.download_button(f"{title}のPNGを保存", buffer.getvalue(),
                           file_name=f"theme1_{varying}_{metric}.png", mime="image/png")
    with st.expander("表示データと出典"):
        st.caption(str(path))
        st.dataframe(selected, hide_index=True)
        st.download_button("表示データをCSVで保存", selected.to_csv(index=False).encode("utf-8-sig"),
                           file_name=f"theme1_{varying}.csv", mime="text/csv")
