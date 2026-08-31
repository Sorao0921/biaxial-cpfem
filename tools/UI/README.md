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

## モデル充足状況

`database/analysis.db` のカタログから、Theme 1に必要な表面高さ、GOS・粒回転、累積せん断ひずみ、空間モデルなどがケースごとに揃っているか確認できます。

```bash
python tools/UI/run_readiness_dashboard.py
```

データ別の充足率、texture別の横向き積み上げグラフ、ケースごとの不足データを表示します。`rho / seed` で絞り込みでき、ケース一覧ではpostprocessの未実行・一部不足・完了を色分けします。表示中の一覧はCSVで保存できます。

plotについては、表面高さ、GOS・粒回転、せん断ひずみの3種類をケース単位で判定します。plotの有無は一覧とデータ別充足状況に表示しますが、Theme 1の入力データではないため解析可否には影響しません。

サイドバーの「カタログを更新」を押すと、ローカルファイルを増分スキャンして `database/analysis.db` と画面表示を更新します。充足判定に不要なファイル指紋計算は省略するため、通常の完全スキャンより短時間で更新できます。
