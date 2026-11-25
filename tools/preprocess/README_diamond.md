# Diamondミクロモデル：粒ごとの鏡映混在＋MTEX

通常のリポジトリは `/Users/Owner/dev/projects/si_masterthesis/pipeline`。

## 現在の設計

- 基準方位：Cube、Goss、Brass、Copper、S（マクロと同じBunge角）。
- 基準方位からの回転量：5°、15°、25°で固定。
- Seed1〜50。各基準方位・角度につき50個の5粒モデル。
- **同一モデル内の5粒に、鏡映バリアントを混在**させる。粒の配置・形状は固定。
- 既定の `balanced` は、base・flipRD・flipTD・flipRDTDを各1粒、残り1粒の種類を等確率で選び、5粒への配置をランダムに決める。中央粒もランダムなバリアントになる。
- 合計 **750枚の方位CSV、750枚のpartsmat、4rhoで最終3000ケース**。鏡映ごとに別モデルを4倍生成する方式ではない。

5粒全てについて、3次元単位球面で一様な回転軸を選び、指定角度の回転を与えてから、選んだ鏡映操作を施す。5°等は**その粒に割り当てた鏡映基準方位からのずれ**であり、中央粒と隣接粒との方位差を指定値に固定するものではない。

Cube・Gossでは理想基準方位の鏡映が結晶対称性により等価になる場合がある。したがって「鏡映コードが違う＝大きな粒間方位差」とは扱わず、実際の方位差をMTEXで計算して記録する。

## 方位生成はMATLAB／MTEX

マクロ側と同じ `src/mtex-5.11.1` の方位・結晶対称性機能を使う。結晶対称性は `m-3m`、試料対称性は **triclinic**。試料対称性をmmmにして、混在させた方位を解析上同一視する処理は行わない。

主実装は `tools/preprocess/generate_orientation_diamond.m`。MATLABから：

```matlab
addpath('tools/preprocess');
generate_orientation_diamond('Seeds',1:50,'Overwrite',true);
```

MTEXの方位・対称性に必要な機能のみを初期化する。今回の処理に不要なMEX/NFFTの再コンパイルや描画は行わず、既存の `startup_mtex.m`・マクロ用スクリプトも書き換えない。

Pythonからは同名 `.py` がMATLABを起動する：

```bash
python tools/preprocess/generate_orientation_diamond.py --overwrite
```

MATLABがPATHにない場合はmacOSの `/Applications/MATLAB*.app/bin/matlab` を検出する。明示指定も可能：

```bash
python tools/preprocess/generate_orientation_diamond.py --matlab /path/to/matlab --mtex-dir /path/to/mtex
```

`balanced` は各モデルで全4種類を比較する制約付きの乱数。5粒それぞれのタイプを完全に独立に選びたい場合：

```bash
python tools/preprocess/generate_orientation_diamond.py --variant-sampling independent --overwrite
```

この場合は4種類が全て入るとは限らない。同じSeed・sampleでは、タイプ配置と元の回転軸を基準方位・角度間で共通化する。Seedを変えると変わる。生成対象の絞り込み・順序を変えても再現できる。

## 出力と記録

```text
inputs/orientation_diamond/
  generation_manifest.mat             # バッチ全体で1ファイル
  seed_1/deg_5/goss.csv                # seed_1〜50、deg_5/15/25、5方位
inputs/partsmat_diamond/
  seed_1/deg_5/partsmat_goss.k
models/diamond_models/
  rho_-0.5/seed_1/keywordset.k
  rho_-0.5/seed_1/deg_5/goss.k          # rho→seed→deg
```

各CSVは元の材料作成関数が読める**5行×3列のBunge角、ラジアン、ヘッダなし**。行は粒ID順。

|粒ID|位置|
|---:|---|
|1|中央粒|
|2|右上|
|3|左上|
|4|左下|
|5|右下|

`generation_manifest.mat` の `records` に各ケースの次を保存する。

- Seed・角度・基準方位・sample・乱数配置モード。
- 各粒の鏡映コード（1=base、2=flipRD、3=flipTD、4=flipRDTD）。
- 鏡映前後の回転軸、各粒の初期方位行列、鏡映基準方位行列、基準からの実測角。
- 中央粒と隣接4粒の方位差角、生の回転行列、結晶対称性で最小角となる回転行列。
- 全8粒界（1–2、1–3、1–4、1–5、2–3、2–5、3–4、4–5）の同じ情報。
- 使用した24個の立方晶回転行列と操作番号（1始まり）。

方位行列Rは結晶→試料。粒aからbへの生の回転は `R_b R_a'`、最小角回転は `R_b S_k R_a'`。鏡映行列Mのproper代表 `det(M)*M` を試料側から作用させる。これは既存マクロの鏡映処理と同じ定義。

CSVを増やさず、後のGOS・GR・弱点方位との比較や粒間回転の方向解析に必要な初期情報を残す。部分的に再生成した場合、対象ケースの記録だけを更新し、未選択ケースの記録を保持する。

## 一連の実行

共通の設定は `src/config/diamond_cases.py`。

```python
SEEDS = list(range(1, 51))
DEGREES = [5, 15, 25]
TEXTURES = ['cube', 'goss', 'brass', 'copper', 's']
SAMPLES_PER_SEED = 1
VARIANT_SAMPLING = 'balanced'
```

全工程を実行：

```bash
python tools/preprocess/run_diamond_preprocess.py --overwrite
```

方位CSVと材料カードまで再生成する場合：

```bash
python tools/preprocess/run_diamond_preprocess.py --steps orientations materials --overwrite
```

準備済みのCSV・材料カードから結合する場合：

```bash
python tools/preprocess/run_diamond_preprocess.py --steps merge
```

材料カードは、元の `make_partsmat.py` の **`make_partsmat()` をimportして使用**。元ファイル、既存UMAT、材料定数、履歴変数数は変えない。元関数のEuler角小数6桁丸めもそのまま継承する。各段階を個別に呼ぶ場合は `make_partsmat_diamond.py`、`merge_all_diamond.py` を使用できる。

`--seeds`、`--degs`、`--textures`、`--rhos`、`--samples-per-seed` で対象を指定できる。一括スクリプトは選択した材料だけを結合する。各段階を個別に実行する材料・結合スクリプトはフォルダの全CSV／partsmatを列挙するため、別条件の古いファイルを混ぜない。

## ユーザーが用意する結合用.k

```text
inputs/keywords_diamond/
  consts/partset_diamond.k             # 節点・要素・節点集合
  consts/control.k
  consts/section.k
  keyword_rho_-0.5_diamond/boundary_rho_-0.5.k
  keyword_rho_-0.5_diamond/curve_rho_-0.5.k
  keyword_rho_0_diamond/…                      # 0.5、1も同様
```

PART・材料はpartsmat側に置き、partsetと重複させない。制御・曲線・SF・節点集合番号はユーザー入力のまま結合する。元メッシュから5粒のpartsetを派生生成し、boundaryの面節点は現在のメッシュに合わせて再構築する。名前や場所は `merge_all_diamond.py` 冒頭のテンプレートで変更可能。必要な入力を全て確認してから書き始める。

最終デッキは4rho×50Seed×3deg×5方位=3000枚、共通keywordsetは200枚。ソルバー計算はこの処理とは別。旧方式の30Seedデータを再生成する際は、置換前のCSV・材料を1つのZIPに退避してから更新する。

MTEXの定義：[方位の座標変換](https://mtex-toolbox.github.io/OrientationDefinition.html)、[結晶対称性と試料対称性](https://mtex-toolbox.github.io/SpecimenSymmetry.html)。


## 生成済みCSVからデータセットを完成させる

```bash
.venv/bin/python tools/preprocess/run_diamond_preprocess.py --steps materials merge --reuse-existing
```

既定値は5方位 × 50 Seed × 3ばらつき角（5°,15°,25°）× 4ひずみ比（−0.5,0,0.5,1）。
方位CSVは `inputs/orientation_diamond/seed_N/deg_D/`、材料カードは
`inputs/partsmat_diamond/seed_N/deg_D/`、結合済みモデルは
`models/diamond_models/rho_R/seed_N/deg_D/{texture}.k` に保存する。
材料カード750件、解析入力3000件となる。方位を再生成せず、元の `make_partsmat.py` を関数として参照する。
`--reuse-existing` は内容が完全一致する出力だけを再利用し、不一致は停止する。

結合入力は `inputs/keywords_diamond`。`consts/initmesh_diamond.k` がある場合、
5粒へのPID割り当てを行い `consts/partset_diamond.k` を派生生成する。
各 `keyword_rho_R_diamond` 内の `boundary_rho_R.k` の面名（x0/x1/y0/y1/z0）から
現在のメッシュに合う節点集合を再構築し、`boundary_diamond_rho_R.k` として保存する。
元のboundary・curve・メッシュは変更しない。SF、curveの縦軸・時間も用意済みの値を使う。
既に準備済みのpartsetとboundaryを直接使用する場合は `--no-prepare-keywords` を指定する。
結合時に要素・節点集合・境界条件・材料・断面の参照整合性を検証する。
LS-DYNA自体の解析実行はこのスクリプトには含まれない。
