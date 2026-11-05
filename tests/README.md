# テストの分類

| ディレクトリ | 対象 |
|---|---|
| `theme1` | 物理量の寄与、初期 Taylor 活動と高さの対応、実測谷の起点 |
| `theme2` | 高さ・谷の予測、モデル比較、予測評価、その表示・箱ひげ図 |
| `postprocess` | グラフ・FFT帯域、帯域表示、再開処理、座標後処理、Taylor・すべり活動の出力処理 |
| `common` | 共通の結晶塑性計算、パス設定、データカタログ |
| `dashboard` | 共通の表示・初期マップ、表示用カタログ、データ準備状況 |

テストは対象の処理で分類します。例えば帯域の表示は `postprocess`、予測マップの表示は `theme2` に置きます。
実測谷の起点抽出は `theme1/test_valley_origins.py`、その起点を使う予測の捕捉率・面積率の評価は `theme2/test_valley_bottom.py` に分けています。

## 実行

プロジェクトルートで実行します。

```bash
.venv/bin/python -m pytest -q
.venv/bin/python -m pytest tests/theme1 -q
.venv/bin/python -m pytest tests/theme2 -q
.venv/bin/python -m pytest tests/postprocess -q
```

## 共通入力と重複の整理

`helpers.py` に合成メッシュ・初期方位・表面メッシュの生成を集約しています。テストファイル同士は import せず、共通入力はここから取得します。

M 指標単独の符号・正の板厚だけを確認していたテストは削除し、その検証を指標別のパラメータ化テストへ統合しています。異なるモデルのゼロひずみ・一様入力の検証や、各 CLI の実測読込前保存の検証は対象の実装が異なるため残しています。

今回の整理後は190件です。旧191件との差分は上記の重複1件の統合であり、FFT帯域・谷起点評価などの移動による検証の削除はありません。
