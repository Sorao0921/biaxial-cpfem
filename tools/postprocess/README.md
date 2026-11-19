# 後処理

Python はリポジトリルートから `python -m` で実行する。対象の rho / seed は明示する。

```bash
# 端部除去と、Euler角・せん断ひずみへのID付与
.venv/bin/python -m tools.postprocess.post_main --rho 0.5 --seed 1 --step all

# 片方だけ実行する場合
.venv/bin/python -m tools.postprocess.post_main --rho 0.5 --seed 1 --step edge
.venv/bin/python -m tools.postprocess.post_main --rho 0.5 --seed 1 --step ids
```

`--step` の既定値は `edge`。既存の非空な端部除去結果と既存のID付与CSVは再利用する。
実装は `src/extract_process/coordinates.py` と `id_enrichment.py`、引数処理は `pipeline.py` に集約。
後処理の入口は `post_main.py` に一本化した。
旧コード内の RHO / SEED 定数の編集は不要。

ID付与の後、MATLABで MTEX を初期化し、`grain_orientation_metrics.m` の `rho` / `seed` を設定して実行する。
粒方位指標が生成された後に、必要に応じて Taylor factor を計算する。

```bash
.venv/bin/python -m tools.postprocess.calculate_taylor --rho 0.5 --seed 1
# 初期方位のみ
.venv/bin/python -m tools.postprocess.calculate_taylor --rho 0.5 --seed 1 --state 1
```

`calculate_initial_taylor.py` は既存利用者のための互換入口。計算本体は `calculate_taylor` と共通。
`calculate_slip_activity.py` はせん断ひずみを使う別の指標であり、Taylor計算とは独立。

Sa/Sq/Sz と L1〜L3 の計算・評価・専用グラフ作成は廃止済み。専用コードとパス設定を削除した。
高さ座標・粒方位指標・せん断ひずみを使う Theme 1 / UI の解析は引き続き利用できる。

## 高さ分布の帯域分析

高さ分布を表す追加指標として、表面粒グラフ上の帯域分解を後処理に分類する。

```bash
.venv/bin/python -m tools.postprocess.analyze_graph_spectra --resume --skip-mode-coefficients
```

既存の結果を再利用するため、保存先の既定値は `database/theme1/graph_spectra` を維持する。
tools 全体の分類は [tools/README.md](../README.md) を参照。

## Grain Rotation / GOS の折れ線図

保存済みの粒別方位指標と `eps_equivalent.csv` から、中心方位5行×指標2列のPNGを再生成する。
横軸は相当塑性ひずみ `eps_eq`（CSVの最初のデータ行がstate01）、色はひずみ比。
線は粒別値の算術平均、帯は平均±母標準偏差（`ddof=0`）。帯が負になる場合もゼロで切り詰めず表示する。粒は等重みで、Seed・初期方位分散を混ぜない。

```bash
# pipeline ディレクトリで実行（全15枚）
.venv/bin/python -m tools.postprocess.plot_grain_orientation

# Seed・初期方位分散を限定
.venv/bin/python -m tools.postprocess.plot_grain_orientation --seeds 1 --sd 2 6 10
```

既定条件：σθ＝2・4・6・8・10°、Seed＝1〜3、ρ＝−0.5・0・0.5・1、state02〜13。
入力は `outputs/rho_*/rho_*_seed*/angles/grain_orientation_metrics/**/*.csv` と各Seedの `eps_equivalent.csv`。
必要な組み合わせの欠損・重複・不正値を出力前に確認する。
保存先は `outputs/figures/seed{seed}/grain_rotation_gos_sd{sd}_seed{seed}.png`（200 dpi、3000×2800）。
再実行時は同名PNGを上書きする。PDFや中間CSVは作成しない。
`--rho`、`--dpi`、`--input-root`、`--output-dir` も指定できる。
縦軸範囲は指定した全条件で指標ごとに統一する。条件を限定すると範囲もその条件から再計算する。
