# ローカル比較UI

解析条件を選び、高さ・GOS・結晶粒回転・累積せん断ひずみの二次元マップを並べて比較するUIです。

## セットアップ

リポジトリのルートで次を実行します。

```bash
uv sync --frozen
```

## 起動

```bash
uv run python tools/UI/run_dashboard.py
```

ブラウザでローカルUIが開きます。初回は `outputs/` を走査するため、表示まで少し時間がかかる場合があります。
各マップは元CSVから動的に描画され、パネル下部の「PNGを保存」から必要な図だけを保存できます。

## 比較モード

- **パラメータ比較**: ほかの条件を固定し、`sd` または `rho` を変えた同一指標を共通色範囲で表示します。
- **複数指標比較**: 同じ `rho / seed / texture / sd / state` の高さ、GOS、結晶粒回転、累積せん断ひずみを表示します。

座標には `coords/edge_dropped` を優先し、存在しない場合は `coords/rawdata` を使います。GOSと結晶粒回転は `angles/grain_orientation_metrics`、累積せん断ひずみは `shear_strains/id_set` を `database/spatial_model/seedN` と結合して描画します。

## モデル充足状況

`database/analysis.db` のカタログから、Theme 1に必要な表面高さ、GOS・粒回転、累積せん断ひずみ、空間モデルなどがケースごとに揃っているか確認できます。

```bash
uv run python tools/UI/run_readiness_dashboard.py
```

データ別の充足率、texture別の横向き積み上げグラフ、ケースごとの不足データを表示します。`rho / seed` で絞り込みでき、ケース一覧ではpostprocessの未実行・一部不足・完了を色分けします。表示中の一覧はCSVで保存できます。

サイドバーの「カタログを更新」を押すと、ローカルファイルを増分スキャンして `database/analysis.db` と画面表示を更新します。充足判定に不要なファイル指紋計算は省略するため、通常の完全スキャンより短時間で更新できます。

## Theme1 帯域比較

比較方法で「Theme1 帯域比較」を選択します。既存の
`database/theme1/graph_spectra/band_energies.csv` の高さ信号を読み込み、
`state / texture / rho / sd` のいずれかを比較軸にし、残りの条件を固定します。
seed別の図を共通縦軸で表示し、絶対エネルギーと帯域比率のPNG、および表示中のCSVを保存できます。
state推移は各rho・seedの`eps_equivalent.csv`の`eps_eq`を横軸とした折れ線、それ以外は帯域別の棒グラフです。CSVの先頭データ行をstate 1として対応させ、相当ひずみは無次元で表示します。保存CSVにも`eps_eq`を含めます。対応値が不足・不正な場合はエラーを表示します。欠けた条件を補間・ゼロ埋めしません。

比率は粒平均高さのlow/mid/highの合計を分母とし、粒内粗さと先頭固有モードは含みません。
絶対エネルギーは保存済み係数の二乗和で、面積平均の粗さSq²ではありません。
全帯域エネルギーが0のケースは保存値に従い比率0%で表示します。

### 高さと結晶方位の変形表示

高さマップには、上面で異なるpartが共有する辺を結晶粒界として重ねます。GOS・Grain rotationは同一条件・stateの高さCSVの節点座標を使い、要素上面の変形後の形状で表示します。端部除去済みCSVでは全頂点が残っている要素のみを表示します。比較候補は対応する高さデータがある条件に限定します。

座標CSVのIDは既存のEdgeDropperと同じ上面節点の1始まりの行番号です。上面節点をメッシュのnode_id昇順に対応づけます（現在の座標エクスポートの並び）。GOS・回転角の数値自体は変更しません。累積せん断ひずみの表示は従来の初期形状です。

### 初期 Taylor factor・初期方位

「パラメータを変えて同じ指標を比較」で Taylor factor（初期）、初期方位 φ1・Φ・φ2
を選べます。この4指標はstate01固定で、変形前のメッシュに描画します。
「同じモデルで複数指標を比較」ではGOS等と並べて表示でき、stateを変更しても
初期指標の値と形状は変わりません。初期方位はBunge Euler角の度表示です。
Euler角は周期性を持ち、角度の色差は方位差の大きさを直接表しません。

データは `database/taylor_factor_initial/rho_*/rho_*_seed*/taylor_factor/initial/*state01.csv`。
`database/taylor_factor_initial/` には全粒データ・集計・計算条件を保存します。
再生成は `.venv/bin/python -m tools.postprocess.calculate_initial_taylor`。
UIのTaylor factorは公称rhoを使い、rho=0の実境界値0.001による結果は全集計CSVに別途保存します。
新しくデータを生成した後は、サイドバーの「データ一覧を更新」で再読み込みできます。
