# LS-DYNA 二軸引張・結晶塑性解析パイプライン

初期組織からの解析モデル作成、LS-DYNA結果の抽出・後処理、表面粗面化のメカニズム解明と高さ予測を扱う。

| 分類 | 目的 | 実装・実行入口 | 資料 |
|---|---|---|---|
| theme1 | 物理量の寄与、初期活動と高さの対応からメカニズムを調べる | `src/theme1`・`tools/theme1` | [theme1](docs/README.md) |
| theme2 | 初期情報から高さ・谷を予測し、CPFEMとの対応を評価する | `src/theme2`・`tools/theme2` | [theme2](docs/README.md) |
| postprocess | 結果を整備し、高さ分布の帯域などの追加指標を計算する | `src/postprocess`・`src/extract_process`・`tools/postprocess` | [postprocess](docs/README.md) |

帯域分析は高さ分布の追加指標として後処理に置き、機構解析・予測評価の双方から利用する。コードの分類変更に伴うデータ移動は行っておらず、保存先の既定値は `database/theme1` 等を維持している。

詳細の入口：[資料](docs/README.md)・[実行ツール](tools/README.md)・[実装](src/README.md)・[テスト](tests/README.md)。

## 環境構築

Python 3.10以上。依存関係は [pyproject.toml](pyproject.toml)、解決済みバージョンは `uv.lock` で管理する。以下はすべてプロジェクトルートで実行する。

```bash
uv sync --frozen
```

Pythonコマンドは `uv run python -m ...`、または `.venv/bin/python -m ...` を使う。

解析・抽出には別途LS-DYNA／SuperDyna4・LS-PrePost、方位生成・GOS・粒回転にはMATLAB＋MTEXが必要。解析機の実行ファイルパスや抽出する履歴変数は、使用環境・UMAT版に合わせる。

## ディレクトリとデータ

```text
inputs/        初期メッシュ、負荷・制御設定、方位CSV、生成材料カード
models/        生成したLS-DYNAモデル
outputs/       抽出結果と端部除去・ID付与・物理指標
database/     カタログ、空間モデル、集計・予測結果
output/        図表・PDFなどのレポート
src/           処理本体（theme1・theme2・postprocessと共通実装）
tools/         前処理・抽出・各テーマのCLIとUI
tests/         分類別のテスト
docs/          分類別の資料とarchive
external/      UMATソース、解析機の実行補助
```

パスの定義は [src/config/pipeline_paths.py](src/config/pipeline_paths.py) に集約する。

1ケースは `rho × seed × texture × sd × state` で識別する。textureは `brass`・`copper`・`cube`・`goss`・`s`、カタログの標準sdは2・4・6・8・10。ケース名は `cube_sd2_seed1` などを用い、stateはファイル名の `state01` 等で表す。

- 共通入力：`inputs/keywords/consts/` の `initmesh.k`・`control.k`・`section.k`・`partset_seedN.k`。
- 負荷条件：`inputs/keywords/keyword_rho_{rho}/` の `boundary_rho_{rho}.k`・`curve_rho_{rho}.k`。
- 初期方位：`inputs/orientation/texture_seedN/*.csv`。Bunge Euler角3列、1行1粒で行順がpart IDに対応する。材料カード生成は数値のみ・ヘッダーなしのCSVを前提とする。
- 抽出結果：`outputs/rho_{rho}/rho_{rho}_seedN/` 以下の `coords/rawdata`・`angles/rawdata`・`shear_strains/rawdata` にケース別で配置する。

`models/`・`outputs/`・`output/`・`database/` はローカルデータとしてGit管理から除外する。新規cloneには解析結果が含まれないため、必要な入力・抽出結果を配置してからカタログを構築する。元方位CSV・共通メッシュ・raw結果・解析機のd3plotは再計算の元データとして保持する。

## 前処理と解析結果の抽出

処理の流れは、初期メッシュ・方位 → 解析モデル → 外部での解析 → CSV抽出 → 後処理 → theme1／theme2での解析・評価となる。

```bash
uv run python -m tools.preprocess.partset --seed 1
uv run python -m tools.preprocess.make_partsmat --seed 1
```

続いて [tools/preprocess/merge_all.py](tools/preprocess/merge_all.py) の `RHO`・`SEED` を設定し、共通keywordと材料カードを統合する。

```bash
uv run python -m tools.preprocess.merge_all
uv run python -m tools.mapping.export_spatial_model --seed 1
```

解析モデルは `models/rho_*/rho_*_seedN/merged_seedN/`、空間モデルは `database/spatial_model/seedN/` に保存する。空間モデルの `nodes.csv`・`elements.csv` が節点・要素・粒の対応と幾何情報を保持する。

LS-DYNA／SuperDyna4で解析後、解析機上の `tools/superdyna4/` に各ケースの `run/d3plot` を配置して抽出する。

```bash
python extract_surface_coords.py
python extract_angles.py
python extract_shear_strain.py
```

抽出スクリプトはstate01〜13、指定された表面節点範囲・LS-PrePostパスを前提とする。メッシュや解析環境を変える場合は [extract_surface_coords.py](tools/superdyna4/extract_surface_coords.py) の設定を確認する。HV番号とUMAT版の対応は [履歴出力の定義](docs/postprocess/umat_history_outputs.md) を参照。

## postprocess：後処理・追加指標

抽出CSVを `outputs/` に配置したら、対象rho・seedを明示して端部除去とID付与を行う。

```bash
uv run python -m tools.postprocess.post_main --rho -0.5 --seed 1 --step all
```

`--step edge` は座標の端部除去、`--step ids` は方位・せん断ひずみへのID付与。座標処理は151×151の行順規則格子を前提とし、中央113×113を残す。CSVの行番号から付ける表面IDと元メッシュのglobal node IDを区別する。

GOS・粒回転には、MTEXを初期化したMATLABで `tools/postprocess/grain_orientation_metrics.m` のrho・seedを設定して実行する。Taylor factorやすべり活動は必要に応じて別途計算する。

```bash
uv run python -m tools.postprocess.calculate_taylor --rho -0.5 --seed 1
uv run python -m tools.postprocess.calculate_slip_activity --help
uv run python -m tools.postprocess.analyze_graph_spectra --resume --skip-mode-coefficients
```

帯域分析は符号付き高さなどを低・中・高グラフ周波数へ分解する。FFT帯域は別の定義なので混同しない。`--resume` は既存結果を保持して未完了ケースを補う。詳細は [帯域指標](docs/postprocess/height_bands.md)、[Taylor factor](docs/postprocess/taylor_factor.md)、[後処理の実行案内](tools/postprocess/README.md) を参照。

データを追加・更新した後はカタログを更新する。

```bash
uv run python -m tools.database.build_catalog --database database/analysis.db scan --root .
uv run python -m tools.database.build_catalog --database database/analysis.db report
```

カタログは元データをコピーせず、ファイル情報・ケース対応・準備状況を管理する。[データカタログ](docs/postprocess/data_catalog.md) に定義と操作をまとめている。

## theme1：メカニズム解明

GOS・粒回転・累積せん断ひずみの寄与を調べる処理と、初期Taylor活動・近傍差が実測高さにどう対応するかを調べる処理を置く。

```bash
uv run python -m tools.theme1.estimate_contributions
uv run python -m tools.theme1.predict_initial_roughness --rho 0 --seed 1 --texture cube --sd 2 --plots
```

`predict_initial_roughness` は初期活動と実測高さの対応を調べるCLIで、theme1に分類する。寄与係数・相関は観測上の関連であり、因果効果を直接示すものではない。

定義は [寄与解析](docs/theme1/contributions.md)、[初期Taylor活動と高さ](docs/theme1/initial_taylor_state13.md)、[χ・Kの初期応答](docs/theme1/initial_stress_response.md)、[谷・山の起点検出](docs/theme1/surface_valley_origins.md) を参照。

## theme2：予測・評価

初期方位・初期メッシュ・指定負荷から高さ場を生成し、その後にCPFEMを読んで評価する。現行UIの主な比較はstate02の5モデルと、D＋Qによるstate02〜12の谷・山の起点追跡。

```bash
uv run python -m tools.theme2.compare_valley_onset --rho -0.5 --seed 1 --texture brass --sd 2
uv run python -m tools.theme2.plot_onset_boxplots
```

state02では自粒ND、周囲とのND差、ND差＋Q、3D対角、3D全成分を比較する。主指標は起点捕捉率・予測面積率・面積当たり捕捉効率。既存の粒重心による山・谷分類評価は別方式として扱う。

詳細は [state02の予測比較](docs/theme2/valley_onset_state02.md) と [D＋Q起点追跡](docs/theme2/dq_origin_history.md) を参照。初期高さ仮説、近傍モデル、Sachs平衡、state13比較など保持中のCLIは [theme2資料一覧](docs/README.md) から確認できる。

## UI

```bash
uv run python -m tools.UI.run_dashboard
```

高さ・方位・すべり指標の比較、高さの帯域比較、谷形成起点の因子比較、D＋Qの起点追跡を表示する。データの準備状況は別UIで確認できる。

```bash
uv run python -m tools.UI.run_readiness_dashboard
```

操作や表示の詳細は [UIの案内](tools/UI/README.md) を参照。

## 再実行と検証

partset・材料カード・空間モデルの置換には `--overwrite` を明示する。モデル統合は `merge_all.py` の `OVERWRITE_EXISTING` で制御する。CSV抽出と座標・ID後処理は既存結果を再利用するため、元入力を変更した場合は対象出力・キャッシュの整合性を確認する。

```bash
uv run python -m pytest -q
uv run python -m pytest tests/theme1 tests/theme2 tests/postprocess -q
```

共通計算・UIのテストも全体実行に含まれる。分類と共通入力の扱いは [tests/README.md](tests/README.md) を参照。
