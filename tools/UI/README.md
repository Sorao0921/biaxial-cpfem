# ローカル比較UI

解析条件を選び、高さ・GOS・結晶粒回転・累積せん断ひずみの二次元マップを並べて比較するUIです。

## セットアップ

リポジトリのルートで次を実行します。

```bash
python -m pip install -e .
```

## 起動

```bash
python tools/dashboard/run_dashboard.py
```

ブラウザでローカルUIが開きます。初回は `outputs/` を走査するため、表示まで少し時間がかかる場合があります。

## 比較モード

- **パラメータ比較**: ほかの条件を固定し、`sd` または `rho` を変えた同一指標を共通色範囲で表示します。
- **複数指標比較**: 同じ `rho / seed / texture / sd / state` の高さ、GOS、結晶粒回転、累積せん断ひずみを表示します。

座標には `coords/edge_dropped` を優先し、存在しない場合は `coords/rawdata` を使います。GOSと結晶粒回転は `angles/grain_orientation_metrics`、累積せん断ひずみは `shear_strains/id_set` を `database/spatial_model/seedN` と結合して描画します。
