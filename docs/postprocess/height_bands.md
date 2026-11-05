# 高さ分布の帯域指標

帯域分析は高さ分布を表す追加指標として後処理に分類する。低帯域・高帯域は空間的な変化の尺度であり、それだけで粗面化機構や因果関係を特定しない。

## 表面粒グラフ上の帯域

実装は `src/postprocess/graph_spectral.py`、実行入口は `tools/postprocess/analyze_graph_spectra.py`。

```bash
.venv/bin/python -m tools.postprocess.analyze_graph_spectra --resume --skip-mode-coefficients
.venv/bin/python -m tools.postprocess.analyze_graph_spectra --rho -0.5 --seed 1 --texture brass --sd 2 --state 2
```

表面の辺共有を隣接とし、既定重みは共有粒界長／粒重心間距離。`--weight` で二値・粒界長・粒界長／距離を選べる。グラフ基底上で符号付き粒平均高さ、せん断、粒回転、GOSを分解する。

現行の帯域境界は最大固有値の1/3・2/3であり、粒径から定めた波長境界ではない。帯域エネルギーと比率は定数モードを除外し、変動エネルギーが0なら比率0とする。モード係数と再構成は位相・符号を保持する。高さは最小二乗平面を除いた符号付き値を粒へ集計する。

保存先の既定値は `database/theme1/graph_spectra`。`--resume` は既存結果を保持し、欠損・不完全なケースを再計算する。`--skip-mode-coefficients` は大きなモード係数CSVを省略し、帯域集計・再構成は保存する。UIの「高さの帯域比較」は `src/dashboard/height_bands.py` で保存済み集計を表示する。

## FFTによる帯域

計算は `src/postprocess/height_spectral.py`。初期材料座標の規則格子へ高さを対応付け、各場の平面を除去し、対称反射で周期延長してFFTを行う。低帯域は波長が初期代表粒径の4倍超、粒径帯域は1〜4倍、高帯域は1倍以下。これらは上記のグラフ固有値による帯域とは異なる定義である。

予測とCPFEMの帯域別比較は `src/theme2/valley_evaluation.py` の `fft_scale_table`。保存済み高さ予測へ `python -m tools.theme2.evaluate_valleys --fft` で適用する。帯域別の位置対応とエネルギーを診断し、谷の検出規則には使わない。反射境界と高周波の端部影響は残る。
