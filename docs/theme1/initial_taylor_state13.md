# 初期 Taylor 面外活動による state13 粗面化の順位予測

変形後の方位・すべりを入力にせず、初期方位と公称ひずみ比 rho から FCC 等CRSS Taylor 最適解を求める。主評価は「面外活動が大きいほど谷になる」という固定仮説に基づく高低順位予測。予測指標は `relief_from_az_midpoint = -(Az_midpoint - 面積加重平均Az_midpoint)`。高さ振幅そのものは予測しない。

## 実行

```sh
.venv/bin/python -m tools.theme1.predict_initial_roughness
.venv/bin/python -m tools.theme1.predict_initial_roughness --rho 0 --seed 1 --texture cube --sd 2 --plots
```

state13 固定。既定では端部除去済みの高さを優先し、存在しない場合だけ raw を使用する。`--raw-height` は raw を優先する。`--output-dir`、`--outputs`、`--orientations`、`--spatial-models` で入出力を変更できる。

## 指標と複数解

相当ひずみ増分を1に正規化した Taylor 問題 `min Σ|gamma_alpha|` を解き、`Az = Σ|gamma_alpha| |s_alpha,z|` を求める。すべり方向は Taylor 制約行列と同じ系順序で生成する（UMATの番号とは異なる）。

全ての独立な5系の基本解を列挙し、最小総すべり量から相対許容差1e-9以内の最適基本解を保持する。同一頂点を表す退化基本解を重複除去する。最適解集合が連続の場合も、絶対値の線形計画表現における最適頂点で Az の最小・最大を評価できる。連続解そのものを無限列挙するわけではない。

`az_min`、`az_max` と、その中点 `az_midpoint` を高さを見ずに定義する。中点は中立な代表値であり最適頂点の平均ではない。Az の最小・最大は Spearman 相関の最小・最大の保証ではない。全系ゼロ等による定数場では相関は未定義として保存する。

M0、Az の上下限・中点、Rz中点を各応答と比較する。同一ケース内でマクロひずみを掛けても順位は変わらないため、state13 の実測ひずみで指標をスケーリングせず評価する。

## 高さ応答と集計

選択した高さ節点に平面 `z=ax+by+c` を最小二乗で当て、その残差 h を使用する。初期の上面四角形の全頂点が残る要素のみを採用し、底面節点を混ぜない。初期表面積で粒内集計する。

- `height_abs_mean`：上面頂点の |h| を要素内平均し、粒内面積加重平均。補助評価。
- `height_std`：面積加重した頂点二次モーメントと平均から計算する粒内標準偏差。
- `height_mean`：粒内の符号付き平均残差。山・谷の主評価。
- `surface_z_mean`：粒内の元の表面高さ z の平均。補助評価。

既存の座標CSVのIDは、初期上面の global node ID 昇順に並べた節点の1始まり行番号である。明示的に global ID に復元する。global ID を保持する別データには `--height-node-ids global` を指定する。IDの一部重複から方式を推測しない。

各ケース内で粒を1サンプルとして Spearman 相関を計算し、同順位には平均順位を使う。相関に適した粒数が不足、または数値許容幅内で定数の場合はNaNと理由を記録する。空間依存があるため独立標本を仮定したp値は出さない。seed間の頑健性はケース別結果から別途評価する。

## 出力

保存先：`database/theme1/initial_taylor_state13/`

- `spearman_by_case.csv`：ケース・指標・応答ごとの相関とサンプル数。
- `failed_cases.csv`：欠損・不整合ケース。失敗がある実行は終了コード1。
- `diagnostics.json`：解析仕様・成功数・失敗内容。
- 各ケースの `grain_predictions.csv`：初期活動指標と実際の粒応答。
- 各ケースの `optimal_vertices.csv`：最適基本解ごとの Az と符号付き12系 Taylor すべり量。
- `--plots` 時の `comparison.png`、`rank_scatter.png`：初期座標に揃えた指標・実際の粒応答マップと順位散布図。予測指標と高さは単位が異なるため色尺度も区別する。

相関があることは山・谷や高さ振幅の再現、因果関係を意味しない。M0よりAzの対応が改善するか、改善がseedや条件をまたいで安定するかを検証する。

## 山・谷仮説による評価（2026年10月11日更新）

主比較は `Spearman(relief_from_az_midpoint, height_mean)`。正で大きいほど「高活動→谷」の高低順位が一致し、負なら逆方向。`Spearman(Az_midpoint,height_mean)` はこれと符号が逆で、独立した証拠ではない。ケースごとの結果を見て符号を反転したり、最も合うTaylor解を選択したりしない。Az 最小・最大のモデルと初期 M 基準も比較する。

`valley_spearman_by_case.csv` は山・谷の主評価だけを抽出した表。`grain_predictions.csv` に `relief_from_*` を保存する。CLI の条件を限定して再実行しても、他条件の相関行は保持する。

実測 state13 Az が保存済みの場合は同じ残存上面要素で粒面積平均し、`measured_az_state13` と高さ、および `relief_from_measured_az_state13` と高さを評価する。state02〜13 の保存済み全区間が揃う場合は `Σ Az Δεeq` を `measured_bz_state13` として追加する。欠損をゼロで補わない。実測活動はシミュレーションの診断用で、初期予測とは区別する。

不足する state13 の実測活動を計算する場合：

```sh
.venv/bin/python -m tools.theme1.predict_initial_roughness --calculate-measured-az
```

このフラグは最後の区間だけを計算する。累積診断に必要な全区間は別途 `tools.postprocess.calculate_slip_activity` で用意する。

UI は左に予測高低、中央に実測粒平均高低を、青＝谷側・赤＝山側の共通順位尺度で並べる。右は他メニューと共通の節点高さ z を表示する。左右の順位マップは初期座標、右の高さマップは変形後座標であり、原点・縮尺の違いに注意する。


## 隣接活動差と最小表示への更新

初期表面で辺を共有する粒の共有粒界長を重みに、`neighbor_az_mean` を計算する。主予測 `relief_from_neighbor_az = neighbor_az_mean - az_midpoint` は周囲より活動が強い粒を谷とする符号付き活動差である。単なる接点は隣接としない。全初期表面粒の Taylor 指標を計算してから、観測領域へ絞るため、端部除去外の隣接粒も含まれる。力学的な相互作用を解いた量ではなく、粒間不一致の仮説指標である。

UI は2モデル選択、実値の予測マップ、従来形式の実測高さマップ、主評価 Pearson 相関に絞る。Spearman は補助表示とし、順位変換の操作や測定指標の追加選択は表示しない。左の色範囲は実データの最大絶対活動差から自動設定する（−1〜1 に固定しない）。

`correlations_by_case.csv` に Pearson・Spearman を保存する。従来の `spearman_by_case.csv` も同じ結果を保持して互換性を維持する。高さ振幅を予測する変換係数は学習しないため、RMSEを高さ予測誤差として計算しない。
