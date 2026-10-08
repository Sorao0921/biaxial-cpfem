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
各マップは元CSVから動的に描画されます。「表示中の全マップを1枚のPNGで保存」で、表示順と設定中の列数に合わせた白背景の200 dpi画像を保存できます。各マップのタイトル・目盛り・カラーバーを含み、スライドへそのまま貼り付けられます。パネル下部の「PNGを保存」から個別の図も保存できます。

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

座標CSVのIDは既存のEdgeDropperと同じ上面節点の1始まりの行番号です。上面節点をメッシュのnode_id昇順に対応づけます（現在の座標エクスポートの並び）。GOS・回転角の数値自体は変更しません。累積せん断ひずみも選択stateの変形後形状で表示します。

### state別 Taylor factor

「Taylor factor（state別）」を選択できます。変化させる条件を `state` にすると、
同じrho・seed・texture・sdの利用可能なstateを横並びに表示します。
「同じモデルで複数指標を比較」では、GOS等と同じstateのTaylor factorを追加表示します。
Taylor factor・累積せん断ひずみ・GOS・粒回転の描画形状は、そのstateの表面座標を使用し、同じ結晶粒界を黒線で重ねます。Taylor factorの色範囲は表示対象の最小値・最大値から自動調整します。state別とInitial Taylor factorの両方の表示値から共通範囲を決めます。パラメータ比較でも表示中の全Taylorパネルで共通範囲を使います。
初期方位の表示はUIから外しています。初期Taylor factorは複数指標比較の7枚目に表示し、state01の値・形状・粒界に固定します。6枚目のstate別Taylor factorと同じ色範囲を使います。

保存先: `outputs/rho_*/rho_*_seed*/angles/taylor_factor/{texture}_sd{sd}_seed{seed}/taylor_factor_*_stateNN.csv`。
再生成: `.venv/bin/python -m tools.postprocess.calculate_taylor`。
生成後は「データ一覧を更新」でカタログを更新できます。

定義は、GOS計算で保存した各stateの粒平均方位に対するFCC・等CRSS・等ひずみTaylor factorです。
`mean_phi1_target_deg, mean_Phi_target_deg, mean_phi2_target_deg`を使用し、
D=diag(1,rho,-1-rho)、von Mises相当塑性ひずみで正規化します。rhoは公称値です。
これは **M(粒平均方位)** であり、要素ごとのMの平均でも、実際の局所すべり量／塑性ひずみ比でもありません。
粒内方位のばらつき・局所ひずみ経路・すべり抵抗差は直接含めません。
state02〜13の保存済み粒平均方位を使用し、state01固定のデータへフォールバックしません。
各rho/seedフォルダの `manifest.csv` に集計・計算元・SHA256をまとめます。計算定義は `docs/taylor_factor.md` に記載しています。

#### UIから各stateを計算・更新

Taylor factorの条件一覧は、計算済みTaylor CSVではなく元の粒平均方位データから作ります。
未計算のstateも選べ、表示時に計算・保存します。入力方位や計算コードが変わった場合、
出力ファイルが壊れた場合も自動再計算します。入力・出力・コードのSHA256はフォルダ共通の `manifest.csv` に保存します。個別JSONは生成しません。

- 「選択中のstateを計算・更新」: 表示対象のstateを再計算。
- 「同じ条件の全stateを計算・更新」: 選択中のrho・seed・texture・sd条件に合う全stateを再計算。sd/rho比較中は表示対象の複数条件を含みます。
- 複数指標表示の「このstateのTaylor factorを計算・更新」: 選択stateのみ再計算。

コマンドからも対象を指定できます（省略した条件は全件）。

```sh
.venv/bin/python -m tools.postprocess.calculate_taylor --rho 0 --seed 1 --texture cube --sd 2 --state 2 13
```

部分再計算でも `manifest.csv` の他のstateの行を保持します。UIからの更新も同じ管理CSVに反映します。
計算コマンドはstate01も扱えます。初期表示を外す方針に従い、state別表示の対象はstate02以降です。複数指標比較の7枚目にはstate01の初期Taylor factorを表示します。

初期Taylor factorの7枚目は、選択stateの座標CSVの節点IDから同じ表示要素を選びます。
端部除去範囲を揃えたうえで座標は初期メッシュから取得するため、初期値・初期形状を維持します。

### すべり集中度（5枚目）

複数指標表示の順番は、高さ、GOS、粒回転、累積せん断ひずみ、すべり集中度、
state別Taylor factor、初期Taylor factorです。
集中度は `max(mean_gamma_alpha) / sum(mean_gamma_alpha)`。
選択stateの表示表面要素をpart_idでまとめ、12系の累積ひずみを各系ごとに要素平均します。
要素ごとの集中度を平均する計算とは異なります。分母には12系の総和を用います。
全系ゼロの場合は0（未活動）、均等すべりでは1/12、1系のみでは1。
色範囲は0〜1固定。変形後座標、端部除去範囲、粒界は他のstate別指標と共通です。
Theme1と同じ比の定義ですが、集計対象はこのUIで表示する表面範囲です。

### 8枚目：z方向すべり活動（マクロ相当ひずみ増分あたり）

定義は `Az = Σα [(Γα(state i) − Γα(state i−1)) / Δeps_eq] |sα,z|`。
12系の番号を固定して差分を取り、活性系をstateごとに選び直したりTaylorモデルから推定したりしません。結晶回転による方向変化は区間開始時の要素方位で反映します。
`eps_equivalent.csv` の `eps_eq` 列の1行目をstate01に対応させ、隣接stateの差を分母に使います。区間量・実時間モード・Δτの手入力はありません。

計算とマッピングは分離しています。

- `src/crystal_plasticity/slip_activity.py`: 要素ごとの計算式。
- `src/crystal_plasticity/slip_activity_pipeline.py`: 累積値・要素方位・マクロひずみの読込、ID結合、結果CSV保存と更新判定。
- `src/dashboard/plots.py`: 保存済み要素値をelement_idで結合し、表示表面のelementごとに描画。粒内平均は行いません。生のすべりデータからの計算は行いません。

単独計算（座標・空間モデル・UIは不要）:

```sh
.venv/bin/python -m tools.postprocess.calculate_slip_activity --rho 0 --seed 1 --texture cube --sd 2 --state 2
```

入力は `shear_strains/id_set` を優先し、なければ `shear_strains/rawdata` の12系累積値を読みます。ケースフォルダ内の `state2.csv` / `state02.csv` も使用できます。総累積列やpart_idは計算に不要ですがelement_idと12系の列は必要です。
方位は `angles/id_set` または `angles/rawdata` の区間開始時の要素Bunge方位（phi1,Phi,phi2、rad）。
保存先は `shear_strains/z_slip_activity/{case}/z_slip_activity_{case}_stateNN.csv`。要素ID、Az、Rz、12系のマクロひずみあたり活動増分、区間のstateとひずみを保存します。入力・計算コード・出力ハッシュで更新を判定します。

すべり方向の既定順序は `external/dyn_umats_from_n/dyn21umats_0710.F` の `m(:,1:12)`（<110>、sは面法線）です。解析UMATで順序が違う場合は `inputs/slip_directions.csv` に `slip_id,sx,sy,sz` の12行を保存してください。試料座標へ変換する前の結晶座標方向を指定し、単位ベクトルへ正規化します。UIでのアップロードや確認操作は不要です。

state01、直前state・方位・マクロひずみの欠損、非正のひずみ増分は未計算として表示します。欠損や初期すべりをゼロで補いません。
形状・粒界・端部除去範囲は他の変形後指標と共通です。絶対値活動なので上昇・下降の符号はなく、面法線を含まないためz変位や塑性ひずみzz成分そのものではありません。

「パラメータを変えて同じ指標を比較」でもZ-directed slip activityを選択できます。sd / rho / stateを比較し、表示中のelement値の最大値から0〜共通上限を自動設定します。state02以降を対象とし、区間データの欠損は条件ごとに表示します。個別PNG・全マップをまとめたPNGの保存にも対応します。

PNGのファイル名には指標名、rho、seed、texture、sd、stateを含めます。z方向活動には区間開始state、初期Taylorには実際のstate01と表示範囲の選択stateを記録します。まとめたPNGは表示中の各条件値を列挙し、比較するstateが飛び飛びの場合も判別できます。

パラメータ比較では、表示値が均一なstate01の高さ・GOS・粒回転マップを候補から除外します（丸め誤差の許容幅1e-12）。値にばらつきがある初期マップとstate02以降は残します。まとめたPNGにも除外後のマップのみを含めます。
