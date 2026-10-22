"""Valley initiation at state02 and explicit, matched physical ablations."""

import io
import json
import zipfile

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from src.config.pipeline_paths import OUTPUTS_DIR, PROJECT_ROOT, build_spatial_model_dir
from src.dashboard.catalog import filter_records, scan_outputs
from src.dashboard.initial_prediction import (
    coordinate_height_figure,
    indicator_color_limits,
)
from src.dashboard.valley_evaluation import valley_archive, valley_figures, valley_png
from src.theme1.contribution import _read_height
from src.theme1.delayed_valley import validate_delayed_candidates
from src.theme1.valley_onset import (
    LABELS,
    MODEL_NAMES,
    evaluate_onset,
    predict_onset_models,
    property_table,
    reference_followup,
)


DISPLAY_MODELS = tuple(MODEL_NAMES[i] for i in (0, 1, 3, 4, 2))


def display_properties():
    return property_table().iloc[[0, 1, 3, 4, 2]].reset_index(drop=True)


def display_order(frame):
    return frame.sort_values("model", key=lambda values: values.map({name: i for i, name in enumerate(DISPLAY_MODELS)}), kind="stable")


def onset_archive(prediction, result, followup=None):
    stream = io.BytesIO()
    with zipfile.ZipFile(stream, "w", zipfile.ZIP_DEFLATED) as z:
        with zipfile.ZipFile(io.BytesIO(valley_archive(result))) as source:
            for name in source.namelist():
                z.writestr(name, source.read(name))
        z.writestr("properties.csv", display_properties().to_csv(index=False))
        z.writestr(
            "configuration.json",
            json.dumps(prediction["configuration"], ensure_ascii=False, indent=2),
        )
        for key in ["indicators", "interfaces", "surface_edges"]:
            z.writestr(key + ".csv", prediction[key].to_csv(index=False))
        for key in ["transitions", "transition_grains", "transition_origins"]:
            z.writestr(key + ".csv", result[key].to_csv(index=False))
        for name in MODEL_NAMES:
            for key in ["coordinates", "grains", "initial_tensors"]:
                if key in prediction["models"][name]:
                    z.writestr(
                        name + "/" + key + ".csv",
                        prediction["models"][name][key].to_csv(index=False),
                    )
            z.writestr(
                name + "/model.json",
                json.dumps(
                    prediction["models"][name]["metadata"], ensure_ascii=False, indent=2
                ),
            )
        if followup is not None:
            if isinstance(followup, dict):
                for name, value in followup.items():
                    if isinstance(value, pd.DataFrame):
                        z.writestr(
                            "delayed/" + name + ".csv", value.to_csv(index=False)
                        )
                z.writestr(
                    "delayed/method.json",
                    json.dumps(followup["metadata"], ensure_ascii=False, indent=2),
                )
            else:
                z.writestr("reference_retention.csv", followup.to_csv(index=False))
    return stream.getvalue()


def render_valley_onset():
    import streamlit as st

    st.caption(
        "主評価：初期組織からstate02の谷となる粒の位置を説明する。谷の拡大・合体やstate13の高さ振幅は予測対象外です。"
    )
    records = filter_records(scan_outputs(OUTPUTS_DIR), kind="height", state=2)
    if not records:
        st.info("state02の高さデータがありません。")
        return
    cases = pd.DataFrame(
        [
            dict(rho=r.rho, seed=r.seed, texture=r.texture, sd=r.sd, path=r.path)
            for r in records
        ]
    )
    for column, key in zip(st.columns(4), ["rho", "seed", "texture", "sd"]):
        with column:
            value = st.selectbox(key, sorted(cases[key].unique()), key=f"onset-{key}")
        cases = cases[cases[key].eq(value)]
    row = cases.iloc[0]
    model = build_spatial_model_dir(int(row.seed))
    orientation = (
        PROJECT_ROOT
        / "inputs/orientation"
        / f"texture_seed{row.seed}"
        / f"{row.texture}_sigma{row.sd}_seed{row.seed}.csv"
    )
    with st.expander("事前指定の予測条件・比較の意味"):
        prediction_threshold = st.slider(
            "予測谷の厳しさ（局所低さRMSの倍率）",
            min_value=0.1,
            max_value=1.5,
            value=0.5,
            step=0.1,
            key="onset-prediction-threshold",
        )
        boundary_threshold = st.slider(
            "初期Taylor factor差の粒界採択（RMS倍率）",
            min_value=0.5,
            max_value=2.0,
            value=1.0,
            step=0.25,
            key="onset-taylor-threshold",
        )
        st.caption(
            "ΔM=|初期M_i−初期M_j|。初期表面の粒界長で重み付けしたRMSの1倍を既定とし、候補粒界そのものを追加します。両側の粒全体は追加しません。"
        )
        st.caption(
            "倍率が大きいほど、周囲より明確に低い粒だけを残します。実測との一致が最大になる値を自動選択する処理は行いません。"
        )
        st.caption(
            "1→2：自粒Kと周囲との差Dを比較。2→3：同じDにQ拘束γ=1だけを追加。縮約3条件とも表面伝達結合λ=0。4→5：同じ3D境界・剛性・初期応答のまま固有せん断3成分だけを追加。縮約モデルと3Dの差は単一因子に帰属しません。"
        )
        st.dataframe(display_properties(), hide_index=True, width="stretch")
        st.caption(
            "③のRD・TD・せん断成分はQの計算を通じて使用。④⑤の粒界重み×は明示的な重みを使わない意味で、3D共有節点と平衡による相互作用は含みます。共通の初期方位・負荷設定と表示用の粒→節点写像は省略。"
        )
        st.caption(
            "全モデルでばらつき保持率0.75を共通化。応力比は初期体積平均のひずみ比に合わせて逆算します。保持率0.75は既存の探索的設定を継承しており、結果を見ずに確定した物性値ではありません。"
        )
    try:
        with st.spinner("初期情報のみから5条件を計算しています…"):
            prediction = predict_onset_models(
                orientation, model, rho=float(row.rho), m=0.05, strain=0.00901
            )
        # Reference is opened only after every prediction is complete.
        reference = _read_height(row.path)
        result = evaluate_onset(
            prediction,
            reference,
            model,
            prediction_threshold_rms=prediction_threshold,
            taylor_boundary_rms=boundary_threshold,
        )
    except (ValueError, KeyError, OSError) as error:
        st.error(str(error))
        return
    case = f"rho_{row.rho:g}_{row.texture}_sd{row.sd}_seed{row.seed}_state02_cfg{prediction['config_id']}_predRMS{prediction_threshold:g}_deltaMRMS{boundary_threshold:g}"
    st.caption(
        "実測：高さマップの青い低部に限定した谷底線上の局所最深部を含む粒（粒界上では両側）。予測：周辺の局所平面からの低さが、局所低さRMSの指定倍率を超える粒。最深部を含む粒を予測したときに起点を捕捉したと数えます。橙は実測の起点を含まない候補で、谷の斜面にある可能性もあります。"
    )
    metrics = result["metrics"].query(
        "level=='grain' and feature=='valley' and threshold_factor==1"
    )
    shown = metrics[
        [
            "model",
            "origin_count",
            "hit_origin_count",
            "origin_recall",
            "predicted_count",
            "precision",
            "f1",
        ]
    ].copy()
    shown = display_order(shown)
    shown.model = shown.model.map(LABELS)
    st.dataframe(
        shown.rename(
            columns={
                "model": "モデル",
                "origin_count": "実測の起点数",
                "hit_origin_count": "捕捉した起点数",
                "origin_recall": "起点捕捉率",
                "precision": "粒Precision（補助）",
                "f1": "粒F1（補助）",
                "predicted_count": "周囲より低い予測粒数",
                "reference_coverage": "参照対象粒の割合",
                "excluded_no_neighbors": "近傍不足の除外数",
                "bottom_line_coverage": "実測谷底線の被覆率",
            }
        ),
        hide_index=True,
        width="stretch",
    )
    st.caption(
        "主指標の起点捕捉率は、谷底線上の局所最深部を1点につき1回数えます。粒界上で両側の粒を予測しても二重加点しません。粒Precision・F1は補助指標で、起点の個数とは単位が異なります。"
    )
    st.caption(
        "初期Taylor factor差の粒界候補との和集合：同じ起点は一度だけ加点します。粒と粒界では予測単位が違うため、和集合のPrecision/F1は作りません。"
    )
    union = result["union_metrics"]
    chosen = union[np.isclose(union.threshold_factor, 1.0)].copy()
    chosen = display_order(chosen)
    chosen.model = chosen.model.map(LABELS)
    st.dataframe(
        chosen[
            [
                "model",
                "origin_count",
                "original_hit_origin_count",
                "boundary_hit_origin_count",
                "union_hit_origin_count",
                "additional_origins",
                "original_origin_recall",
                "union_origin_recall",
            ]
        ],
        hide_index=True,
        width="stretch",
    )
    st.dataframe(
        result["taylor_boundary_metrics"][
            [
                "candidate_boundary_count",
                "candidate_boundaries_with_origin",
                "candidate_boundaries_without_origin",
                "boundary_precision",
                "candidate_boundary_length",
                "candidate_length_fraction",
                "junction_origin_count",
            ]
        ],
        hide_index=True,
        width="stretch",
    )
    st.caption(
        "粒界側の未対応候補は「state02の実測起点を含まない粒界」です。三重点では複数の候補粒界への帰属を保存し、起点は重複計上しません。境界的中率は粒界ペア数、候補範囲は粒界長で別に表示します。"
    )
    detection = valley_figures(result, model, model_names=DISPLAY_MODELS, labels=LABELS)
    from matplotlib.collections import LineCollection

    boundary = result["taylor_boundary_segments"]
    boundary = boundary[boundary.candidate]
    material_segments = (
        boundary[["x_a", "y_a", "x_b", "y_b"]].to_numpy(float).reshape(-1, 2, 2)
    )
    for figure in detection:
        if len(material_segments):
            figure.axes[0].add_collection(
                LineCollection(
                    material_segments, colors="#c026d3", linewidths=1.3, zorder=6
                )
            )
    heights = []
    for name in (*DISPLAY_MODELS, "cpfem"):
        coordinates = result["selected"][name]
        limits = indicator_color_limits(coordinates.z.to_numpy() * 1000, robust=True)
        figure = coordinate_height_figure(
            coordinates,
            model,
            title=LABELS[name] + "\nOwn color range (2–98%)",
            value_range=limits,
        )
        figure.axes[0].title.set_fontsize(12)
        if name == "cpfem":
            from matplotlib.collections import LineCollection

            lines = result["bottom_lines"]
            if len(lines):
                import matplotlib.patheffects as pe

                figure.axes[0].add_collection(
                    LineCollection(
                        lines[["x_a", "y_a", "x_b", "y_b"]]
                        .to_numpy()
                        .reshape(-1, 2, 2),
                        colors="#62ff45",
                        linewidths=1.1,
                        path_effects=[
                            pe.Stroke(linewidth=1.8, foreground="black"),
                            pe.Normal(),
                        ],
                    )
                )
        if len(boundary):
            lookup = coordinates.set_index("node_id")[["x", "y"]]
            edges = np.stack(
                [
                    lookup.loc[boundary.node_a].to_numpy(),
                    lookup.loc[boundary.node_b].to_numpy(),
                ],
                axis=1,
            )
            figure.axes[0].add_collection(
                LineCollection(edges, colors="#c026d3", linewidths=1.3, zorder=6)
            )
        if name == "cpfem" and len(result["origins"]):
            origins = result["origins"]
            figure.axes[0].scatter(
                origins.x,
                origins.y,
                s=35,
                c="#ffef00",
                edgecolors="black",
                linewidths=0.7,
                zorder=8,
                marker="*",
            )
        heights.append(figure)
    st.caption(
        "各列の上段が谷検出、下段が高さ分布です。実測高さ図の緑線が谷底線、黄色の星が評価対象の局所起点、紫線がΔMによる候補粒界です。4モデルずつ折り返し、上下で同じモデルを揃えます。"
    )
    for start in range(0, len(detection), 4):
        for row_figures in [detection[start : start + 4], heights[start : start + 4]]:
            for column, figure in zip(st.columns(4), row_figures):
                with column:
                    st.pyplot(figure, width="stretch")
    paired = []
    for start in range(0, len(detection), 4):
        for figs in [detection[start : start + 4], heights[start : start + 4]]:
            paired.extend(figs)
            paired.extend([None] * (4 - len(figs)))
    # Pad the last model group so reference remains in the same column in both rows.
    from PIL import Image

    from src.dashboard.export import combine_map_pngs

    pngs = []
    for figure in paired:
        stream = io.BytesIO()
        if figure is None:
            Image.new("RGB", (780, 720), "white").save(stream, format="PNG")
        else:
            figure.savefig(stream, format="png", dpi=150, facecolor="white")
        pngs.append(stream.getvalue())
    st.download_button(
        "上下比較マップPNG",
        combine_map_pngs(pngs, columns=4, dpi=150),
        file_name=case + "_bottom_support.png",
        mime="image/png",
        key="onset-png",
    )
    for figure in detection + heights:
        plt.close(figure)
    st.caption(
        "因子を追加して新たに当たった粒・見逃すようになった粒を区別します。各予測の局所低さによる分類変化を含む比較であり、統計的な因果同定ではありません。"
    )
    changes = result["transitions"]
    st.dataframe(
        changes[np.isclose(changes.threshold_factor, 1.0)][
            [
                "before",
                "after",
                "change",
                "new_captured_origins",
                "lost_captured_origins",
                "delta_origin_recall",
            ]
        ],
        hide_index=True,
        width="stretch",
    )
    with st.expander("閾値感度・適用範囲・後続stateの補助確認"):
        sensitivity = display_order(result["metrics"].query("level=='grain' and feature=='valley'"))
        st.dataframe(
            sensitivity[
                [
                    "model",
                    "threshold_factor",
                    "distance_threshold",
                    "origin_count",
                    "hit_origin_count",
                    "origin_recall",
                    "precision",
                    "recall",
                    "f1",
                ]
            ],
            hide_index=True,
            width="stretch",
        )
        for name in ["equilibrium_diagonal", "equilibrium"]:
            meta = prediction["models"][name]["metadata"]
            if not meta["finite_geometry_valid"]:
                st.warning(
                    f"{LABELS[name]}：{meta['inverted_deformed_elements']}要素が反転。小変形外挿の適用範囲外です。"
                )
        st.caption(
            "青色域の基準は、表示の2–98%高さ範囲の下側40%まで。下位40%の粒や節点を選ぶ規則ではありません。白付近の浅い低部は除きます。"
        )
        st.write(
            f"青色域の高さ上限：{result['metadata']['reference_definition']['blue_height_cutoff']:.6g}（元座標単位）"
        )
        st.write(
            f"実測谷底線：{len(result['bottom_lines'])}区間、局所低さの下限：{result['metadata']['reference_definition']['prominence_cutoff']:.6g}"
        )
        st.caption(
            "微小な凹凸を物理的な起点と呼べるかは出力精度・初期形状の確認が必要です。state02は今回の操作的な起点で、最初に発生した時刻を同定したわけではありません。"
        )
        followup = None
        if st.checkbox(
            "state02の未対応候補が、後で谷・起点になるか検証", key="onset-followup"
        ):
            candidates = filter_records(
                scan_outputs(OUTPUTS_DIR),
                kind="height",
                rho=float(row.rho),
                seed=int(row.seed),
                texture=row.texture,
                sd=int(row.sd),
            )
            heights = {
                r.state: _read_height(r.path) for r in candidates if r.state >= 2
            }
            with st.spinner(
                "state02の候補を固定し、後続stateの谷底線と起点を照合しています…"
            ):
                followup = validate_delayed_candidates(result, heights, model)
            st.dataframe(followup["summary"], hide_index=True, width="stretch")
            st.caption(
                "unmatched_state02：state02で起点がなかった固定候補。later_origin：後で起点を含んだ候補（移動・再検出を含む）。later_novel_origin：過去の起点から離れた局所最深部。later_new_valley_origin：過去の谷底線にも接続しない新しい谷での起点。これらを区別し、成長だけを新規形成と数えません。"
            )
            st.dataframe(followup["states"], hide_index=True, width="stretch")
            from matplotlib.collections import LineCollection

            for index, state in enumerate(sorted(s for s in heights if s >= 3)):
                if index % 4 == 0:
                    columns = st.columns(4)
                height = heights[state]
                limits = indicator_color_limits(height.z.to_numpy() * 1000, robust=True)
                figure = coordinate_height_figure(
                    height,
                    model,
                    title=f"CPFEM state{state:02d}: later valley origins",
                    value_range=limits,
                )
                figure.axes[0].title.set_fontsize(12)
                lines = followup["lines"].query("state==@state")
                if len(lines):
                    figure.axes[0].add_collection(
                        LineCollection(
                            lines[["x_a", "y_a", "x_b", "y_b"]]
                            .to_numpy()
                            .reshape(-1, 2, 2),
                            colors="#62ff45",
                            linewidths=1,
                        )
                    )
                origins = followup["origins"].query("state==@state")
                for label, color in [
                    ("continued_or_returned_origin", "#facc15"),
                    ("new_origin_on_existing_or_expanding_valley", "#f97316"),
                    ("new_origin_in_new_valley", "#a855f7"),
                    ("baseline", "#facc15"),
                ]:
                    subset = origins[origins.appearance == label]
                    if len(subset):
                        figure.axes[0].scatter(
                            subset.x,
                            subset.y,
                            c=color,
                            s=35,
                            marker="*",
                            edgecolors="black",
                            linewidths=0.4,
                            zorder=9,
                        )
                columns[index % 4].pyplot(figure, width="stretch")
                plt.close(figure)
            st.caption(
                "星：黄＝既存・再出現、橙＝既存／拡大した谷での新しい局所最深部、紫＝新しい非接続の谷での起点。判定は初期材料座標で行い、全過去観測stateと比較します。"
            )
            with st.expander("固定候補ごとの初出stateと観測履歴"):
                st.dataframe(followup["candidates"], hide_index=True, width="stretch")
                st.dataframe(followup["observations"], hide_index=True, width="stretch")
            st.caption(
                "各stateの同じ抽出規則による検出上の出現です。出力間隔・閾値越え・位置対応の許容幅による曖昧さがあり、物理的な核生成の証明とは区別します。後続データは初期予測や閾値の調整へ戻しません。"
            )
    st.download_button(
        "和集合の起点捕捉CSV",
        union.to_csv(index=False).encode("utf-8-sig"),
        file_name=case + "_union_metrics.csv",
        mime="text/csv",
        key="onset-union-csv",
    )
    st.download_button(
        "谷検出精度CSV",
        metrics.to_csv(index=False).encode("utf-8-sig"),
        file_name=case + "_metrics.csv",
        mime="text/csv",
        key="onset-csv",
    )
    st.download_button(
        "予測・谷判定・因子別変化・条件ZIP",
        onset_archive(prediction, result, followup),
        file_name=case + "_onset.zip",
        mime="application/zip",
        key="onset-zip",
    )
