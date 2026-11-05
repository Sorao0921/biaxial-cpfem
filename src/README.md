# src の分類

| パッケージ | 役割 | モジュール |
|---|---|---|
| `theme1` | メカニズム解明 | `contribution`（物理量の寄与）、`initial_taylor_prediction`（初期活動と高さの対応）、`valley_origins`（実測谷の起点抽出） |
| `theme2` | 予測・予測評価 | `initial_height`、`neighbor_height`、`sachs_equilibrium`、`initial_mismatch`、`initial_fourway`、`valley_onset`、`valley_evaluation`、`valley_bottom`、`delayed_valley`、`dq_origins` |
| `postprocess` | 共通後処理・高さ分布の追加指標 | `case_data`（ケース対応・高さ読込・表面ID対応）、`graph_spectral`（粒グラフ上の帯域）、`height_spectral`（FFT帯域） |
| `dashboard` | 表示・UI | `height_bands`（保存済み帯域指標の表示）、各予測の表示、カタログ等 |

`initial_taylor_prediction` は初期 Taylor 活動や実測高さとの関係を扱うため theme1 に残す。theme2 はこの機構側の初期活動・表面幾何の関数を利用する。
`valley_origins` は実測谷の起点を定義する処理であり、theme2 の予測評価でも同じ定義を利用する。
`valley_bottom` は実測の谷底線と予測候補を比較する評価、`dq_origins` は初期 D/Q 予測とその後の起点追跡をまとめる処理なので theme2 に置く。

帯域の計算自体は postprocess に置き、予測と実測の帯域別比較（`valley_evaluation.fft_scale_table`）は theme2 に置く。帯域表示は UI 層の `dashboard/height_bands.py` で行う。

`crystal_plasticity` の物理計算、`extract_process` の結果抽出・ID付与、`pre_process`、`make_model_process`、`mapping`、`data_catalog`、`config` は各工程の共通実装として維持する。

コードの配置変更に伴うデータ移動は行わず、保存先の既定値（`database/theme1` 等）は既存データと共通にする。
