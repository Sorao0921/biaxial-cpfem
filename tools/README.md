# tools の分類

プロジェクトルートで `python -m tools.<分類>.<モジュール>` として実行します。

| ディレクトリ | 役割 | 主な処理 |
|---|---|---|
| `preprocess` | 解析前処理 | モデル・材料・方位の準備 |
| `superdyna4` | 解析結果の抽出 | 座標・方位・せん断ひずみの抽出 |
| `mapping` | 空間情報の整備 | 空間モデルのエクスポート |
| `postprocess` | 結果の後処理・追加指標 | Taylor factor、すべり活動、高さ分布の帯域分析 |
| `theme1` | メカニズム解明 | 物理量の寄与解析、初期活動と実測粗さの関係 |
| `theme2` | 予測・予測評価 | 初期情報からの高さ・谷の予測、モデル比較、精度評価、図表・PDF |
| `database` | データ管理 | カタログ構築 |
| `UI` | 結果の閲覧 | ダッシュボード |

## 分類の基準

帯域分析は高さ分布を表す追加指標なので、`postprocess/analyze_graph_spectra.py` に置きます。機構の説明や予測の評価から共通に利用できます。

`theme1/predict_initial_roughness.py` は名前に predict を含みますが、初期 Taylor 活動と実測高さの対応を調べる処理であり、学習・同定した高さ予測則を提供しないため theme1 に置きます。

初期情報から高さ・谷を生成する処理と、その予測性能を比較する処理は theme2 に置きます。予測を評価する箱ひげ図・全ケースのアトラス・PDFも同じ分類です。

## 実行例

```bash
python -m tools.postprocess.analyze_graph_spectra --resume --skip-mode-coefficients
python -m tools.theme1.estimate_contributions
python -m tools.theme1.predict_initial_roughness
python -m tools.theme2.predict_neighbor_height --rho -0.5 --seed 1 --sd 8
python -m tools.theme2.compare_valley_onset --rho -0.5 --seed 1 --texture brass --sd 2
```

旧 `tools.theme1` の予測コマンドは `tools.theme2`、帯域分析は `tools.postprocess` に変更しました。
既存データを引き続き利用できるよう、出力先の既定値（`database/theme1` 等）は維持しています。実装も `src/theme1`（機構）、`src/theme2`（予測・評価）、`src/postprocess`（共通後処理・帯域指標）に分けています。コードの分類と保存済みデータのパスは別に管理します。
モジュールごとの役割は [src/README.md](../src/README.md) を参照してください。

## テスト

```bash
python -m pytest -q
```

予測評価の箱ひげ図テストは `tests/theme2/test_prediction_boxplots.py` に集約しています。旧 onset テストの precision・recall・F1 入力を除き、現行の起点捕捉率・予測面積率を検証します。物理計算、初期入力のみで予測する制約、データ対応、機構解析のテストは継続して使用します。
