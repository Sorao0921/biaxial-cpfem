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
