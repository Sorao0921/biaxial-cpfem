# Taylor factor: 初期・state別の統合計算

計算本体は `src/crystal_plasticity/taylor_factor.py`、共通の入出力・更新判定は
`src/crystal_plasticity/taylor_pipeline.py` にあります。

```sh
# 利用可能な初期・変形後の全ケース
.venv/bin/python -m tools.postprocess.calculate_taylor
# 同じ条件の初期と指定state
.venv/bin/python -m tools.postprocess.calculate_taylor --rho 0 --seed 1 --texture cube --sd 2 --state 1 2 13
# 入力が同じでも再計算
.venv/bin/python -m tools.postprocess.calculate_taylor --state 1 --force
```

旧 `calculate_initial_taylor` / `state_taylor` は同じ実装を呼ぶ互換用入口です。
前者は省略時にstate01のみ、統合コマンドと後者は全stateが対象です。

## 出力

`outputs/rho_{rho}/rho_{rho}_seed{seed}/angles/taylor_factor/{texture}_sd{sd}_seed{seed}/` に
`taylor_factor_{texture}_sd{sd}_seed{seed}_stateNN.csv` を保存します。
初期をstate01、変形後を対応するstate番号として同じケースフォルダに置きます。
`manifest.csv`は1階層上のtaylor_factor直下に置き、ケースフォルダごとには増やしません。

各CSVはpart_id、element_count、phi1_rad/Phi_rad/phi2_rad、rho_used、state、
texture、sd、seed、taylor_factorを持ちます。state別版には元の度表記の3列も保持します。
初期CSVのelement_count=0は未使用方位なので、実在粒の集計から除外します。

1つのrho/seedにつき `manifest.csv` を1個だけ保存します。各結果の元ファイル、
入力・計算コード・出力のSHA256、粒数、平均・最小・最大を含みます。
初期についてはpartsetのSHA256も記録します。部分再計算やUI操作時にも更新し、
他のstateの行を保持します。個別JSONおよびmetadata.jsonは生成しません。

## 入力と定義

- state01: inputs/orientation/texture_seedN/*_sigma*_seedN.csv の初期Bunge角（rad）。
  行番号をpart_idに対応させ、partsetで要素数を確認します。
- state02以降: angles/grain_orientation_metrics のmean_*_target_degをradへ変換。
  粒平均方位のTaylor factorであり、要素Taylor factorの平均ではありません。

共通してFCC {111}<110> の12すべり系、全系等CRSS、全粒等ひずみを仮定。
D=diag(1,rho,-1-rho)を粒の結晶座標へ変換し、Dを再現するすべり量の絶対値総和を最小化。
M=min Σ|gamma| / sqrt((2/3)D:D)。分母を1に正規化して計算します。
公称rhoを使用し、実測のshear_strainsやeps_equivalent.csvは使用しません。

旧初期計算のrho=0.001補足結果はrho=0のフォルダ内 `boundary_check/` に保存します。
これは公称rho=0の標準結果と区別し、UIの標準マップには含めません。
旧集計の補助情報は各フォルダの `legacy_initial_summary.csv` に保持します。
UIのstate別指標は選択stateの変形後表面と粒界を使用します。複数指標比較の7枚目は初期Taylor factorで、state01の方位・変形前形状・粒界に固定し、state別Taylor factorと色範囲を共有します。

初期Taylor factorの7枚目は、選択stateの座標CSVの節点IDから同じ表示要素を選びます。
端部除去範囲を揃えたうえで座標は初期メッシュから取得するため、初期値・初期形状を維持します。
