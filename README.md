# LS-DYNA 二軸引張・結晶塑性解析パイプライン仕様書

## 0. English is below

The English version follows the Japanese version in [English Specification](#english-specification).

## 1. 概要

本リポジトリは、正方形平板モデルの二軸引張・結晶塑性解析について、次の処理を一連のパイプラインとして実行するためのコードを管理する。

1. 初期メッシュを結晶粒（part）へ分割する。
2. 結晶方位ごとの LS-DYNA `*PART` / `*MAT` カードを生成する。
3. 境界条件、制御条件、断面定義、材料定義を統合して解析モデルを作る。
4. LS-DYNA / SuperDyna4 で解析する。
5. LS-PrePost から表面座標、Bunge Euler 角、すべり系せん断ひずみを抽出する。
6. 要素 ID と part ID を対応付け、表面粗さと断面プロファイルを計算する。
7. 粗さ・断面形状・極点図などの可視化用データを作る。

対象ケースは主に以下の組合せで表現される。

- `rho`: モデル全体に与えるマクロなひずみ比
- `seed`: Voronoi 分割および方位データ系列を識別する乱数シード
- `texture`: 結晶方位`brass`, `copper`, `cube`, `goss`, `s`
- `sd`: 方位分布の標準偏差を表す整数（主処理では 2～10）
- `state`: 解析状態番号（主処理では 01～13）

ケース名の標準形式は `{texture}_sd{sd}_seed{seed}`（例: `cube_sd2_seed1`）である。

## 2. 全体フロー

```text
inputs/keywords/consts/initmesh.k
        |
        | tools/preprocess/partset.py
        v
partset_seedN.k（要素 → 結晶粒/part の割当）

inputs/orientation/texture_seedN/*.csv
        |
        | tools/preprocess/make_partsmat.py
        v
partsmat_*.k（方位別 *PART / *MAT）

partset + control + boundary + section + curve + partsmat
        |
        | tools/preprocess/merge_all.py
        v
models/rho_*/rho_*_seedN/merged_seedN/*.k
        |
        | LS-DYNA / SuperDyna4（リポジトリ外で解析実行）
        v
run/d3plot
        |
        | tools/superdyna4/*.py + LS-PrePost
        v
表面座標 / Euler角 / せん断ひずみ CSV
        |
        +-- tools/postprocess/post_main.py
        |       +-- 端部除去
        |       +-- L1/L2/L3 断面抽出
        |       `-- Sa/Sq/Sz 算出
        |
        `-- tools/postprocess/id_set.py
                `-- element_id / part_id を付けた正規化 CSV
```

## 3. 動作環境と依存関係

### 3.1 Python

- Python 3.10 以上（`pyproject.toml` の指定）
- NumPy
- pandas
- matplotlib
- meshio
- tqdm

`pyproject.toml` には現時点でランタイム依存関係が列挙されていないため、必要に応じて個別に導入する。

```bash
python -m pip install -e .
python -m pip install numpy pandas matplotlib meshio tqdm
```

各 Python コマンドは、`src` パッケージを解決できるようリポジトリルートで実行する。

### 3.2 外部ソフトウェア

- LS-DYNA / SuperDyna4: 解析本体
- LS-PrePost 4.9: `d3plot` から結果を抽出
- MATLAB + MTEX 5.11.1: 方位生成、極点図、misorientation 処理
- Windows PowerShell / batch: SuperDyna4 上の解析準備・実行

`tools/superdyna4/extract_surface_coords.py` は LS-PrePost を次の固定パスから起動する。

```text
C:\Program Files\LSTC\LS-PrePost 4.9\lsprepost4.9_x64.exe
```

環境が異なる場合は `LSPREPOST_EXE` を変更する。

## 4. ディレクトリ構成

```text
pipeline/
├── inputs/
│   ├── keywords/
│   │   ├── consts/                    # 共通メッシュ・制御・断面・partset
│   │   `-- keyword_rho_*/             # rho ごとの境界条件・カーブ
│   ├── orientation/texture_seedN/     # 方位 CSV（実行時に必要）
│   `-- partsmat/partsmat_seedN/        # 生成した材料カード
├── models/rho_*/rho_*_seedN/          # 生成した解析モデル（実行時に作成）
│   ├── keywordset_seedN.k
│   `-- merged_seedN/*.k
├── outputs/rho_*/rho_*_seedN/         # 後処理結果（実行時に作成）
│   ├── coords/{rawdata,edge_dropped,lines,roughness}
│   ├── angles/{rawdata,id_set}
│   `-- shear_strains/{rawdata,id_set}
├── src/                                # 再利用可能な処理本体
├── tools/preprocess/                   # モデル作成の実行スクリプト
├── tools/superdyna4/                   # 解析機上での d3plot 抽出
├── tools/postprocess/                  # ローカル後処理・描画
`-- external/                           # UMAT、SuperDyna4 実行補助、外部資産
```

パス構築は `src/config/pipeline_paths.py` に集約される。リポジトリルートは同ファイルから 2 階層上として自動判定する。

## 5. 入力データ仕様

### 5.1 共通 keyword

`inputs/keywords/consts/` に次を置く。

| ファイル | 役割 |
|---|---|
| `initmesh.k` | 元となる節点・要素メッシュ |
| `partset_seedN.k` | 要素と結晶粒 part の対応 |
| `control.k` | LS-DYNA の制御・データベース設定 |
| `section.k` | section 定義 |

`rho` ごとのディレクトリ `inputs/keywords/keyword_rho_{rho}/` には次を置く。

| ファイル | 役割 |
|---|---|
| `boundary_rho_{rho}.k` | 二軸負荷条件・拘束条件 |
| `curve_rho_{rho}.k` | 荷重または変位履歴カーブ |

### 5.2 方位 CSV

配置先は `inputs/orientation/texture_seedN/*.csv`。1 行を 1 part（結晶粒）として扱い、行順は `part_id=1, 2, ...` に対応する。

列は Bunge Euler 角の次の 3 列である。

```text
phi1,Phi,phi2
```

ヘッダー付き・ヘッダーなしの両方を `id_set.py` が受理する。`make_partsmat.py` は `numpy.loadtxt` を使うため、現実装では数値だけのヘッダーなし CSV を前提とする。

ファイル名は後段でケース名として使われる。推奨形式は次のいずれかである。

- `bunge_euler_{texture}_sd{sd}_seed{seed}.csv`
- `{texture}_sigma{sd}_seed{seed}.csv`

### 5.3 SuperDyna4 のケース配置

`tools/superdyna4/` 直下に次の形式で解析ケースを配置する。

```text
tools/superdyna4/
`-- cube_sd2_seed1/
    `-- run/
        `-- d3plot
```

`run/d3plot` が存在するディレクトリだけが自動検出される。

## 6. 前処理（モデル作成）

### 6.0 空間モデルの保存（CSV）

粒界量や方位の不連続性を後から空間マッピングできるよう、partset の節点・要素・part 情報を LS-DYNA に依存しない CSV データセットへ変換できる。

```bash
python tools/preprocess/export_spatial_model.py --seed 1
```

出力先は既定で `database/spatial_model/seed1/` となり、次のファイルを含む。

| ファイル | 内容 |
|---|---|
| `nodes.csv` | `node_id` とモデル座標 `x,y,z` |
| `elements.csv` | `element_id`, `part_id`, 要素重心、節点接続 |
| `parts.csv` | `part_id`, 要素・節点数、代表重心、bounding box |
| `metadata.json` | 形式バージョン、座標・重心の定義、件数、元ファイル |

任意の keyword と出力先も指定できる。

```bash
python tools/preprocess/export_spatial_model.py \
  --input path/to/model.k \
  --output-dir path/to/spatial_model
```

通常は一度だけ `.k` からこのデータセットを生成し、その後の粒界・方位解析では `elements.csv` の `element_id` / `part_id` / `center_*` を結合キーおよび位置として利用する。正確な形状や面共有判定が必要な場合は、`node_id_*` と `nodes.csv` を使って要素形状を復元できる。既存出力を意図的に置換するときだけ `--overwrite` を付ける。

### 6.1 partset の生成

実行:

```bash
python tools/preprocess/partset.py --seed 5
```

上書きする場合:

```bash
python tools/preprocess/partset.py --seed 5 --overwrite
```

処理内容:

1. `initmesh.k` を `mesh` クラスで読み込む。
2. NumPy の乱数シードを `--seed` に固定する。
3. メッシュの x/y/z 範囲から Voronoi 生成領域を決める。
4. 既定粒径 `(0.02, 0.015, 0.01)` で seed 点を作る。
5. 各要素中心から最寄りの seed 点を求め、要素の part ID を割り当てる。
6. `inputs/keywords/consts/partset_seedN.k` と生成条件 JSON を保存する。

既存出力がある場合は誤上書き防止のため停止する。

### 6.2 partsmat の生成

実行:

```bash
python tools/preprocess/make_partsmat.py --seed 4
```

処理内容:

1. `inputs/orientation/texture_seedN/*.csv` を列挙する。
2. CSV の各行を `part_id = 行番号 + 1` として処理する。
3. part ごとに `*PART` を生成する。
4. Bunge Euler 角を材料カード第 5 行に設定する。
5. `*MAT_USER_DEFINED_MATERIAL_MODELS_TITLE` を生成する。
6. `inputs/partsmat/partsmat_seedN/partsmat_{CSVのstem}.k` に保存する。
7. 対象ファイル一覧を `partsmat_seedN.json` に記録する。

材料カードには現状、密度 `0.027`、弾性係数 `69000`、Poisson 比 `0.3`、および硬化パラメータなどがコード内固定値として書かれる。材料モデルを変更する場合は `make_partsmat()` の `param` を変更する。

### 6.3 keywordset と最終モデルの統合

`tools/preprocess/merge_all.py` 冒頭の `RHO`, `SEED`, `OVERWRITE_EXISTING` を設定して実行する。

```bash
python tools/preprocess/merge_all.py
```

処理は 2 段階である。

1. `KeywordSetBuilder` が partset に `control`, `boundary`, `section`, `curve` を挿入し、`keywordset_seedN.k` を作る。
2. 方位 CSV と同名の `partsmat_*.k` を keywordset の末尾へ統合し、`merged_seedN/{case}.k` を作る。

挿入規則:

- `control.k`: `*KEYWORD` の直後
- `boundary.k`: control ブロックの直後
- `section.k`: 原則 `part_1` と `part_2` の間
- `curve.k`: 最初の `*ELEMENT`、なければ `*NODE` の直前
- 各断片内の `*KEYWORD` / `*END` は除去し、最終ファイル末尾に `*END` を 1 個だけ付ける

既存ファイルは `OVERWRITE_EXISTING=False` の場合スキップする。

## 7. 解析結果の抽出（SuperDyna4 / Windows）

以下のスクリプトは `tools/superdyna4/` 上で実行する。いずれも state 1～13 を処理し、出力 CSV が既に存在すればその state をスキップする。

### 7.1 表面座標

```bash
python extract_surface_coords.py
```

- LS-PrePost の cfile を state ごとに生成する。
- 節点 ID `91205`～`114005` のみを表面節点として残す。
- 出力列はヘッダーなしの `x,y,z`。
- 出力名は `coordinates_{texture}_sd{sd}_seed{seed}_state{state:02d}.csv`。
- `KEEP_TXT=True` のため中間 TXT を保持する。

### 7.2 Bunge Euler 角

```bash
python extract_angles.py
```

UMAT history variable を次のように解釈する。

| History variable | 意味 |
|---|---|
| `hv201` | `phi1` |
| `hv202` | `Phi` |
| `hv203` | `phi2` |

LS-PrePost では `hvN` を fringe ID `1000 + N` で選択する。出力列は `element_id,phi1,Phi,phi2`、ファイル名は `bunge_euler_{case}_stateNN.csv` である。

### 7.3 累積せん断ひずみ

```bash
python extract_shear_strain.py
```

- `hv115`: 全すべり系の累積せん断ひずみ
- `hv103`～`hv114`: すべり系 1～12 の累積せん断ひずみ

出力は `element_id`、合計値、12 すべり系の値を持つ `shear_strain_{case}_stateNN.csv` である。

抽出後の CSV は、用途に応じて `outputs/.../coords/rawdata`、`angles/rawdata`、`shear_strains/rawdata` の各ケースディレクトリへ配置する。

## 8. 後処理

### 8.1 表面座標、粗さ、断面線

`tools/postprocess/post_main.py` 冒頭の `RHO` と `SEED` を設定して実行する。

```bash
python tools/postprocess/post_main.py
```

入力は次の構造を前提とする。

```text
outputs/rho_X/rho_X_seedN/coords/rawdata/
`-- cube_sd2_seedN/
    `-- coordinates_cube_sd2_seedN_state01.csv
```

各座標 CSV に対し次を行う。

#### 端部除去

- 元データを `151 x 151 = 22,801` 節点の規則格子とみなす。
- CSV 行番号を 1 始まりの `node_id` とする。
- 上下左右を各 19 点除き、中央 `113 x 113 = 12,769` 点を残す。
- `coords/edge_dropped/{case}/` に保存する。

したがって、節点数や CSV の並びが前提と違う場合は `ValueError` になる。

#### 断面線抽出

中央 113 行のうち、0 始まりで次の水平行を抽出する。

| ラベル | 行 index | 抽出点数 |
|---|---:|---:|
| L1 | 29 | 113 |
| L2 | 57 | 113 |
| L3 | 85 | 113 |

出力先は `coords/lines/{case}/{L1|L2|L3}/`。

#### 表面粗さ

中央領域の座標へ最小二乗平面を当てはめる。

```text
z_plane = a*x + b*y + c
residual = z - z_plane
Sa = mean(abs(residual))
Sq = sqrt(mean(residual^2))
Sz = max(residual) - min(residual)
```

ケースごとに `coords/roughness/roughness_{texture}_sd{sd}_seed{seed}.csv` を生成する。列は `case,file,num_nodes,a,b,c,sa,sq,sz`。

### 8.2 element_id / part_id の付与

`tools/postprocess/id_set.py` 冒頭の `RHO`, `SEED` を設定して実行する。

```bash
python tools/postprocess/id_set.py
```

対象は `texture = brass/copper/cube/goss/s`、`sd = 2..10`、`state = 1..13`。

Euler 角:

- state 01 は初期方位 CSV の 1 行を 1 part として、part 内の全要素へ展開する。
- state 02～13 は LS-PrePost 出力の `element_id` に partset の対応表から `part_id` を追加する。
- 出力列は `element_id,part_id,phi1,Phi,phi2`。

せん断ひずみ:

- 全 state で LS-PrePost 出力へ `part_id` を追加する。
- 出力列は `element_id,part_id`、合計累積せん断ひずみ、すべり系 01～12。

処理中に必須列、数値変換、重複 element ID を検証し、最終結果は `element_id` 昇順に並べる。既存出力は上書きしない。

### 8.3 描画・MATLAB 後処理

| ファイル | 主な役割 |
|---|---|
| `tools/postprocess/plot_for_textile.py` | Sa/Sq/Sz と L1/L2/L3 プロファイルを方位・state 別に描画。高さは mm から µm へ 1000 倍する |
| `tools/postprocess/post_polefigure.m` | MTEX による極点図後処理 |
| `tools/postprocess/misorientation.m` | 方位差・misorientation の計算 |
| `tools/postprocess/post_main.py` | 表面粗さとライン抽出の統括 |
| `tools/postprocess/id_set.py` | 要素/part 対応付きデータの生成 |

MATLAB の `start_mtex.m` は同梱の MTEX を開始するための補助スクリプトである。

## 9. 主要 Python モジュールの責務

### `src/config`

- `pipeline_paths.py`: 入力・モデル・出力パスを `rho` と `seed` から一元生成する。

### `src/make_model_process`

- `write_keyword.py`: keyword 断片の安全なインライン挿入と `keywordset` 作成。
- `merge_partsmat.py`: keywordset と材料カードを最終解析 deck に統合。

### `src/pre_process`

- `mesh.py`: meshio/LS-DYNA keyword から節点・要素を読み、中心計算、part 抽出、領域選択などを行うモデル本体。
- `mesh_node.py`: 節点集合の読書き、移動、拡大縮小、回転。
- `mesh_elem.py`: 要素集合の読書き、隣接検索、part 割当・変更。
- `mesh_edge.py`: 要素から辺/面集合を生成し、法線・長さ・中点を計算。
- `mesh_tool.py`: shell メッシュの厚さ方向押出し。
- `mesh_rve.py`: 2D/3D RVE の周期境界・多点拘束条件生成。
- `cohesive_zone.py`: 粒子/母材界面の節点複製と cohesive 要素挿入。
- `keyword_file.py`: LS-DYNA keyword セクションの抽出・コメント除去。
- `keyword_format.py`: LS-DYNA 固定幅カードの出力補助。
- `euler_angles.py`: Euler 角テキストの読書き。
- `mesh_dict.py`: meshio と本実装の要素型名対応表。

### `src/crystal_plasticity`

- `voro_seeds.py`: 粒径と領域から Voronoi seed 点を生成。
- `voro_seeds_to_mesh.py`: 要素中心と seed の距離から part ID を割り当て。
- `ebsd.py`, `ebsd_points.py`, `ebsd_grains.py`: EBSD 点・粒情報の読込みと座標変換。
- `ebsd_to_mesh*.py`: EBSD 点群とメッシュ領域を分割し、要素へ粒 ID を写像。

### `src/extract_process`

- `drop_edge.py`: 表面格子の外周除去。
- `extract_lines.py`: L1/L2/L3 の水平プロファイル抽出。
- `roughness.py`: 最小二乗基準面と Sa/Sq/Sz の計算。
- `eid_pid_mapping.py`: partset から element↔part 対応を構築し、DataFrame の付与・展開・集約を行う。

### `src/others`

- `id_array_tools.py`: ID と配列 index の高速対応表。
- `geometry_tools.py`: 矩形領域、凸多角形、領域分割。
- `math_tools.py`: ベクトル、法線、平行移動量の計算。
- `text_tools.py`: keyword セクション・拡張子処理。
- `plot_tools.py`: EBSD 点・メッシュ要素の簡易可視化。

## 10. 外部コード

- `external/dyn_umats_from_c/`, `external/dyn_umats_from_n/`: LS-DYNA 用ユーザー材料・関連 Fortran ソース。
- `external/superdyna4_root/`: SuperDyna4 上の準備・実行用 PowerShell / batch。
- `src/mtex-5.11.1/`: MTEX 5.11.1 本体。プロジェクト独自コードではなく同梱された第三者ライブラリである。

## 11. 再実行・上書き方針

- `partset.py`, `make_partsmat.py`: 既存出力があると停止し、`--overwrite` 指定時だけ置換する。
- `merge_all.py`: `OVERWRITE_EXISTING=False` では既存 keywordset/merged model をスキップする。
- SuperDyna4 抽出: 最終 CSV が存在すれば state 単位でスキップする。
- `post_main.py`: 非空の端部除去・ライン・粗さ出力を再利用する。
- `id_set.py`: `overwrite=False` で既存 state CSV をスキップする。

途中で失敗した場合は、空ファイルまたは不完全ファイルが残っていないか確認してから再実行する。

## 12. 現実装上の注意点

1. 実行条件の多くは CLI 引数ではなく、各スクリプト冒頭の `RHO`, `SEED` などの定数で指定する。
2. 座標処理は 151×151 の行優先規則格子、および指定された表面節点 ID 範囲に強く依存する。
3. `make_partsmat.py` の材料定数とユーザー材料カード構造はコード内に固定されている。
4. `id_set.py` は texture 5 種 × sd 9 種を一括処理し、どれかの入力不足でも例外で停止する。
5. `partset.py` は生成 JSON を `partset_seedN.json` に書く一方、完了表示では `.k.json` を指すため表示名が実ファイルと一致しない。
6. `SurfaceRoughnessAnalyzer.analyze_df()` の `num_nodes` は現状 `len(df) + 1` であり、実データ行数より 1 大きい値を記録する。
7. `pyproject.toml` に NumPy 等のランタイム依存関係が未登録である。
8. 自動テストは現時点で用意されていない。条件変更後は小規模ケースで行数、ID 対応、keyword の `*END`、粗さ値を確認する。

## 13. 最短の実行順序

```bash
# 1. partset 作成
python tools/preprocess/partset.py --seed 1

# 2. 方位ごとの材料カード作成
python tools/preprocess/make_partsmat.py --seed 1

# 3. merge_all.py の RHO/SEED を編集して最終モデル作成
python tools/preprocess/merge_all.py

# 4. LS-DYNA / SuperDyna4 で解析（外部環境）

# 5. SuperDyna4 上で d3plot を CSV 化
python tools/superdyna4/extract_surface_coords.py
python tools/superdyna4/extract_angles.py
python tools/superdyna4/extract_shear_strain.py

# 6. 出力を outputs/ 以下へ配置後、RHO/SEED を編集して後処理
python tools/postprocess/post_main.py
python tools/postprocess/id_set.py
python tools/postprocess/plot_for_textile.py
```

実行前には、対象 `rho` / `seed` に対して `build_pre_directories()` と `build_post_directories()` が返すパスに必要ファイルがそろっていることを確認する。

---

# English Specification

## 1. Overview

This repository provides a pipeline for crystal-plasticity and biaxial-tension simulations of a square plate. It covers the following operations:

1. Divide the initial mesh into grains represented by LS-DYNA parts.
2. Generate orientation-dependent LS-DYNA `*PART` and `*MAT` cards.
3. Combine mesh, control, boundary, section, curve, and material definitions into analysis models.
4. Run the models with LS-DYNA/SuperDyna4.
5. Extract surface coordinates, Bunge Euler angles, and slip-system shear strains from LS-PrePost.
6. Associate element IDs with part IDs and calculate surface roughness and line profiles.
7. Prepare data for roughness plots, cross-sectional profiles, pole figures, and related visualizations.

Cases are identified by the following parameters:

- `rho`: value identifying the biaxial loading condition
- `seed`: random seed identifying the Voronoi partition and orientation dataset
- `texture`: `brass`, `copper`, `cube`, `goss`, or `s`
- `sd`: integer representing the orientation-distribution standard deviation; the main workflow uses 2 through 10
- `state`: analysis-state number; the main workflow uses 01 through 13

The standard case-name format is `{texture}_sd{sd}_seed{seed}`, for example `cube_sd2_seed1`.

## 2. Pipeline

```text
inputs/keywords/consts/initmesh.k
        |
        | tools/preprocess/partset.py
        v
partset_seedN.k (element-to-grain/part assignment)

inputs/orientation/texture_seedN/*.csv
        |
        | tools/preprocess/make_partsmat.py
        v
partsmat_*.k (orientation-dependent *PART and *MAT cards)

partset + control + boundary + section + curve + partsmat
        |
        | tools/preprocess/merge_all.py
        v
models/rho_*/rho_*_seedN/merged_seedN/*.k
        |
        | LS-DYNA / SuperDyna4 analysis outside this repository
        v
run/d3plot
        |
        | tools/superdyna4/*.py + LS-PrePost
        v
surface-coordinate / Euler-angle / shear-strain CSV files
        |
        +-- tools/postprocess/post_main.py
        |       +-- remove surface edges
        |       +-- extract L1/L2/L3 profiles
        |       `-- calculate Sa/Sq/Sz
        |
        `-- tools/postprocess/id_set.py
                `-- normalize CSV files with element_id and part_id
```

## 3. Environment and Dependencies

### 3.1 Python

- Python 3.10 or later, as specified in `pyproject.toml`
- NumPy
- pandas
- matplotlib
- meshio
- tqdm

Runtime dependencies are not currently declared in `pyproject.toml`; install them separately as required.

```bash
python -m pip install -e .
python -m pip install numpy pandas matplotlib meshio tqdm
```

Run Python commands from the repository root so that the `src` package can be resolved.

### 3.2 External Software

- LS-DYNA / SuperDyna4: simulation solver and execution environment
- LS-PrePost 4.9: result extraction from `d3plot`
- MATLAB and MTEX 5.11.1: orientation generation, pole figures, and misorientation processing
- Windows PowerShell/batch: preparation and execution on SuperDyna4

`tools/superdyna4/extract_surface_coords.py` uses the following fixed LS-PrePost path:

```text
C:\Program Files\LSTC\LS-PrePost 4.9\lsprepost4.9_x64.exe
```

Change `LSPREPOST_EXE` when LS-PrePost is installed elsewhere.

## 4. Directory Layout

```text
pipeline/
├── inputs/
│   ├── keywords/
│   │   ├── consts/                    # common mesh, control, section, and partset
│   │   `-- keyword_rho_*/             # rho-dependent boundary and curve files
│   ├── orientation/texture_seedN/     # orientation CSV inputs
│   `-- partsmat/partsmat_seedN/        # generated material cards
├── models/rho_*/rho_*_seedN/          # generated analysis models
│   ├── keywordset_seedN.k
│   `-- merged_seedN/*.k
├── outputs/rho_*/rho_*_seedN/         # post-processing results
│   ├── coords/{rawdata,edge_dropped,lines,roughness}
│   ├── angles/{rawdata,id_set}
│   `-- shear_strains/{rawdata,id_set}
├── src/                                # reusable implementation
├── tools/preprocess/                   # model-generation entry points
├── tools/superdyna4/                   # d3plot extraction on the solver host
├── tools/postprocess/                  # local post-processing and plotting
`-- external/                           # UMATs, SuperDyna4 helpers, external assets
```

Path construction is centralized in `src/config/pipeline_paths.py`. The repository root is detected as two directories above that file.

## 5. Input Specifications

### 5.1 Common Keyword Files

Place the following files in `inputs/keywords/consts/`:

| File | Purpose |
|---|---|
| `initmesh.k` | Initial node and element mesh |
| `partset_seedN.k` | Element-to-grain/part assignment |
| `control.k` | LS-DYNA control and database settings |
| `section.k` | Section definitions |

Place the following files in `inputs/keywords/keyword_rho_{rho}/`:

| File | Purpose |
|---|---|
| `boundary_rho_{rho}.k` | Biaxial loading and constraint conditions |
| `curve_rho_{rho}.k` | Load or displacement history curves |

### 5.2 Orientation CSV Files

Orientation files belong in `inputs/orientation/texture_seedN/*.csv`. Each row represents one part/grain, and row order maps to `part_id=1, 2, ...`.

The three columns are Bunge Euler angles:

```text
phi1,Phi,phi2
```

`id_set.py` accepts both headered and headerless files. Because `make_partsmat.py` uses `numpy.loadtxt`, its current implementation expects a headerless, numeric-only CSV.

Recommended filenames are:

- `bunge_euler_{texture}_sd{sd}_seed{seed}.csv`
- `{texture}_sigma{sd}_seed{seed}.csv`

### 5.3 SuperDyna4 Case Layout

Place cases directly under `tools/superdyna4/` as follows:

```text
tools/superdyna4/
`-- cube_sd2_seed1/
    `-- run/
        `-- d3plot
```

Only directories containing `run/d3plot` are detected automatically.

## 6. Pre-processing and Model Generation

### 6.1 Generate a Partset

```bash
python tools/preprocess/partset.py --seed 5
```

To intentionally overwrite existing output:

```bash
python tools/preprocess/partset.py --seed 5 --overwrite
```

The script:

1. Loads `initmesh.k` through the `mesh` class.
2. Sets the NumPy random seed from `--seed`.
3. Derives the Voronoi region from the x/y/z extent of the mesh.
4. Generates seed points using the default grain size `(0.02, 0.015, 0.01)`.
5. Assigns each element to the nearest seed using its center position.
6. Writes `inputs/keywords/consts/partset_seedN.k` and a metadata JSON file.

Generation stops if output already exists unless `--overwrite` is supplied.

### 6.2 Generate Part and Material Cards

```bash
python tools/preprocess/make_partsmat.py --seed 4
```

The script:

1. Enumerates `inputs/orientation/texture_seedN/*.csv`.
2. Maps each row to `part_id = row index + 1`.
3. Generates one `*PART` card per part.
4. Writes the Bunge Euler angles into row 5 of the material card.
5. Generates `*MAT_USER_DEFINED_MATERIAL_MODELS_TITLE` cards.
6. Saves `inputs/partsmat/partsmat_seedN/partsmat_{CSV stem}.k`.
7. Records the file list in `partsmat_seedN.json`.

Material values, including density `0.027`, Young's modulus `69000`, Poisson's ratio `0.3`, and hardening parameters, are currently hard-coded in `make_partsmat()`. Modify its `param` value to change the material model.

### 6.3 Merge the Keyword Set and Final Models

Set `RHO`, `SEED`, and `OVERWRITE_EXISTING` at the beginning of `tools/preprocess/merge_all.py`, then run:

```bash
python tools/preprocess/merge_all.py
```

The process has two stages:

1. `KeywordSetBuilder` inserts `control`, `boundary`, `section`, and `curve` into the partset and creates `keywordset_seedN.k`.
2. It appends the orientation-matched `partsmat_*.k` and creates `merged_seedN/{case}.k`.

Insertion rules:

- `control.k`: immediately after `*KEYWORD`
- `boundary.k`: immediately after the complete control block
- `section.k`: normally between `part_1` and `part_2`
- `curve.k`: before the first `*ELEMENT`, or before `*NODE` when no element keyword exists
- Embedded `*KEYWORD` and `*END` lines are removed, and exactly one final `*END` is appended

Existing files are skipped when `OVERWRITE_EXISTING=False`.

## 7. Result Extraction on SuperDyna4/Windows

Run the following scripts under `tools/superdyna4/`. Each script processes states 1 through 13 and skips a state when its final CSV already exists.

### 7.1 Surface Coordinates

```bash
python extract_surface_coords.py
```

- Generates one LS-PrePost cfile per state.
- Keeps node IDs from `91205` through `114005` as surface nodes.
- Writes headerless `x,y,z` rows.
- Uses `coordinates_{texture}_sd{sd}_seed{seed}_state{state:02d}.csv`.
- Preserves intermediate TXT files because `KEEP_TXT=True`.

### 7.2 Bunge Euler Angles

```bash
python extract_angles.py
```

UMAT history variables are interpreted as follows:

| History variable | Meaning |
|---|---|
| `hv201` | `phi1` |
| `hv202` | `Phi` |
| `hv203` | `phi2` |

LS-PrePost selects `hvN` with fringe ID `1000 + N`. Output columns are `element_id,phi1,Phi,phi2`, and filenames follow `bunge_euler_{case}_stateNN.csv`.

### 7.3 Accumulated Shear Strain

```bash
python extract_shear_strain.py
```

- `hv115`: total accumulated shear strain over all slip systems
- `hv103` through `hv114`: accumulated shear strain for slip systems 1 through 12

The resulting `shear_strain_{case}_stateNN.csv` contains `element_id`, the total, and values for all 12 slip systems.

After extraction, place CSV files in the applicable `outputs/.../coords/rawdata`, `angles/rawdata`, and `shear_strains/rawdata` case directories.

## 8. Post-processing

### 8.1 Coordinates, Roughness, and Line Profiles

Set `RHO` and `SEED` at the beginning of `tools/postprocess/post_main.py`, then run:

```bash
python tools/postprocess/post_main.py
```

The expected input layout is:

```text
outputs/rho_X/rho_X_seedN/coords/rawdata/
`-- cube_sd2_seedN/
    `-- coordinates_cube_sd2_seedN_state01.csv
```

#### Edge Removal

- Treats the original data as a row-major `151 x 151 = 22,801` regular grid.
- Assigns one-based `node_id` values from CSV row positions.
- Removes 19 points from each side and retains the central `113 x 113 = 12,769` points.
- Saves the result in `coords/edge_dropped/{case}/`.

A different node count or ordering raises `ValueError`.

#### Line Extraction

The following horizontal rows are extracted from the 113-row central region using zero-based indices:

| Label | Row index | Points |
|---|---:|---:|
| L1 | 29 | 113 |
| L2 | 57 | 113 |
| L3 | 85 | 113 |

Results are stored in `coords/lines/{case}/{L1|L2|L3}/`.

#### Surface Roughness

A least-squares reference plane is fitted to the central coordinates:

```text
z_plane = a*x + b*y + c
residual = z - z_plane
Sa = mean(abs(residual))
Sq = sqrt(mean(residual^2))
Sz = max(residual) - min(residual)
```

Each case produces `coords/roughness/roughness_{texture}_sd{sd}_seed{seed}.csv` with columns `case,file,num_nodes,a,b,c,sa,sq,sz`.

### 8.2 Add Element and Part IDs

Set `RHO` and `SEED` at the beginning of `tools/postprocess/id_set.py`, then run:

```bash
python tools/postprocess/id_set.py
```

The script processes five textures, `sd=2..10`, and `state=1..13`.

For Euler angles:

- State 01 expands each initial-orientation row to every element in the corresponding part.
- States 02 through 13 add `part_id` to LS-PrePost `element_id` output using the partset mapping.
- Output columns are `element_id,part_id,phi1,Phi,phi2`.

For shear strain:

- Every state receives a `part_id` from the partset mapping.
- Output columns include `element_id`, `part_id`, the total accumulated shear strain, and slip systems 01 through 12.

The implementation validates required columns, numeric conversion, and duplicate element IDs, then sorts by `element_id`. Existing outputs are not overwritten.

### 8.3 Plotting and MATLAB Processing

| File | Purpose |
|---|---|
| `tools/postprocess/plot_for_textile.py` | Plots Sa/Sq/Sz and L1/L2/L3 profiles by orientation and state; converts height from mm to µm by multiplying by 1000 |
| `tools/postprocess/post_polefigure.m` | Pole-figure processing with MTEX |
| `tools/postprocess/misorientation.m` | Orientation-difference and misorientation calculations |
| `tools/postprocess/post_main.py` | Coordinates, roughness, and line-extraction orchestration |
| `tools/postprocess/id_set.py` | Element/part-normalized output generation |

The MATLAB `start_mtex.m` scripts initialize the bundled MTEX installation.

## 9. Responsibilities of the Main Python Modules

### `src/config`

- `pipeline_paths.py`: derives all input, model, and output paths from `rho` and `seed`.

### `src/make_model_process`

- `write_keyword.py`: safely inserts keyword fragments and builds a keyword set.
- `merge_partsmat.py`: combines a keyword set and material cards into a final deck.

### `src/pre_process`

- `mesh.py`: main mesh abstraction for meshio/LS-DYNA keyword input, element centers, region selection, and part extraction.
- `mesh_node.py`: node-set I/O, translation, scaling, and rotation.
- `mesh_elem.py`: element-set I/O, adjacency searches, and part assignment.
- `mesh_edge.py`: edge/face generation and normal, length, and midpoint calculations.
- `mesh_tool.py`: extrusion of shell meshes through the thickness.
- `mesh_rve.py`: periodic and multipoint constraints for 2D/3D RVEs.
- `cohesive_zone.py`: node duplication and cohesive-element insertion at interfaces.
- `keyword_file.py`: keyword-section parsing and comment removal.
- `keyword_format.py`: fixed-width LS-DYNA card formatting.
- `euler_angles.py`: Euler-angle text I/O.
- `mesh_dict.py`: element-type mappings between meshio and this implementation.

### `src/crystal_plasticity`

- `voro_seeds.py`: creates Voronoi seed points from region and grain-size parameters.
- `voro_seeds_to_mesh.py`: assigns part IDs from element-center-to-seed distances.
- `ebsd.py`, `ebsd_points.py`, `ebsd_grains.py`: EBSD data loading and coordinate transformations.
- `ebsd_to_mesh*.py`: partitions EBSD point clouds and mesh regions and maps grain IDs to elements.

### `src/extract_process`

- `drop_edge.py`: removes the outer portion of a surface grid.
- `extract_lines.py`: extracts L1/L2/L3 horizontal profiles.
- `roughness.py`: calculates the least-squares plane and Sa/Sq/Sz.
- `eid_pid_mapping.py`: builds element-to-part mappings and supports DataFrame expansion, annotation, selection, and grouping.

### `src/others`

- `id_array_tools.py`: ID-to-array-index mappings.
- `geometry_tools.py`: rectangular/convex regions and spatial partitioning.
- `math_tools.py`: vector, normal, and translation calculations.
- `text_tools.py`: keyword-section and extension utilities.
- `plot_tools.py`: basic EBSD-point and mesh-element visualization.

## 10. External Code

- `external/dyn_umats_from_c/` and `external/dyn_umats_from_n/`: LS-DYNA user-material and related Fortran sources.
- `external/superdyna4_root/`: PowerShell and batch helpers for SuperDyna4.
- `src/mtex-5.11.1/`: bundled MTEX 5.11.1 third-party library, not project-specific source code.

## 11. Re-execution and Overwrite Policy

- `partset.py` and `make_partsmat.py` stop on existing output and replace it only with `--overwrite`.
- `merge_all.py` skips existing keyword sets and merged models when `OVERWRITE_EXISTING=False`.
- SuperDyna4 extraction skips individual states with existing final CSV files.
- `post_main.py` reuses nonempty edge-dropped, line-profile, and roughness output.
- `id_set.py` skips existing state CSV files when `overwrite=False`.

After a failed run, check for empty or incomplete files before restarting.

## 12. Current Implementation Notes

1. Many case parameters are constants such as `RHO` and `SEED` at the beginning of each script rather than CLI arguments.
2. Coordinate processing depends on a row-major 151-by-151 grid and a fixed surface-node ID range.
3. Material constants and the user-material card structure are hard-coded in `make_partsmat.py`.
4. `id_set.py` processes five textures by nine `sd` values as one batch and stops when any required input is missing.
5. `partset.py` writes `partset_seedN.json`, but its completion message reports a `.k.json` path.
6. `SurfaceRoughnessAnalyzer.analyze_df()` currently records `num_nodes` as `len(df) + 1`, one greater than the actual row count.
7. Runtime dependencies such as NumPy are not declared in `pyproject.toml`.
8. No automated tests are currently included. After changing assumptions, verify row counts, ID mappings, the final keyword `*END`, and roughness values with a small case.

## 13. Minimal Execution Sequence

```bash
# 1. Generate the partset
python tools/preprocess/partset.py --seed 1

# 2. Generate orientation-dependent material cards
python tools/preprocess/make_partsmat.py --seed 1

# 3. Set RHO/SEED in merge_all.py and generate final models
python tools/preprocess/merge_all.py

# 4. Run LS-DYNA/SuperDyna4 in the external solver environment

# 5. Convert d3plot results to CSV on SuperDyna4
python tools/superdyna4/extract_surface_coords.py
python tools/superdyna4/extract_angles.py
python tools/superdyna4/extract_shear_strain.py

# 6. Place results under outputs/, set RHO/SEED, and post-process
python tools/postprocess/post_main.py
python tools/postprocess/id_set.py
python tools/postprocess/plot_for_textile.py
```

Before execution, confirm that all files required by `build_pre_directories()` and `build_post_directories()` exist for the selected `rho` and `seed`.
