# state02：初期情報による谷形成起点の予測比較

初期方位・初期メッシュ・事前指定負荷だけで高さ場を生成し、CPFEM state02の起点位置との対応を評価する。保存state02は比較の基準であり、真の初発時刻を同定するものではない。

## 現行の5モデル

| モデル | 使用する情報・比較の意味 |
|---|---|
| `self_nd` | 自粒のND収縮傾向のみ |
| `nd_contrast` | 周囲とのND差D。表面伝達結合なし |
| `d_q` | 同じND差に粒界テンソル不適合Qの拘束を追加。表面伝達結合なし |
| `equilibrium_diagonal` | 初期Sachs応答の対角成分で3D平衡を解く |
| `equilibrium` | 同じ3Dモデルで固有せん断を含む全成分を使う |

対応比較は自粒ND→ND差、ND差→D＋Q、3D対角→3D全成分。縮約モデルと3Dの比較は複数の仕組みが異なるため単一因子の効果とは解釈しない。旧6モデルの「ND差＋表面伝達結合」は使用しない。

共通既定値はm=0.05、指定相当ひずみ0.01、ばらつき保持率0.75、Poisson比0.3。初期体積平均TD/RD比から応力比を定める。D＋QのQ拘束は1、表面伝達結合は0で固定する。指定ひずみはstate02の実測値から推定しない。D＋Q追跡ページは別途0.00901を指定する。

## 起点の定義と評価

実測起点は[高さ場からの谷・起点検出](../theme1/surface_valley_origins.md)に従う。谷底線は[補助形状指標](../postprocess/trough_lines.md)であり、実測起点の採択条件ではない。

予測は各粒の現在表面面積重心から局所低さを求める。共有辺長／重心間面内距離で隣接を重み付けし、非共線の近傍が3粒以上なら局所平面を当てる。近傍不足では全体傾斜除去後の近傍平均との差へ切り替え、孤立粒は除外する。予測自身の局所低さRMSの0.5倍を超える粒を採択し、実測との一致へ閾値を最適化しない。

- 起点捕捉率：支持粒のいずれかが採択された実測起点数／全実測起点数。粒界上でも1起点を1回だけ数える。
- 予測面積率：採択粒の初期露出面積／近傍評価可能な粒の初期露出面積。
- 面積当たり捕捉効率：起点捕捉率／予測面積率。確率や有意性ではなく領域の絞り込みの記述指標。

起点0では捕捉率、予測面積0では効率は未定義。起点支持・谷のみ・どちらでもない粒を診断として区別するが、現行の起点評価にはPrecision・Recall・F1を出さない。因子追加による新規捕捉・見逃しの起点IDを保存する。後続stateは予測へ戻さない。

## 実行と保存

```bash
.venv/bin/python -m tools.theme2.compare_valley_onset --rho -0.5 --seed 1 --texture brass --sd 2
.venv/bin/python -m tools.theme2.plot_onset_boxplots
.venv/bin/python -m tools.theme2.plot_onset_boxplots --reuse-predictions output/reports/valley_onset_state02_boxplots/case_data
```

個別CLIは `database/theme1/valley_origins_state02_five_models`、全ケース集計は `output/reports/valley_origins_state02_five_models` が既定。名称は既存データとの互換のため維持する。

予測座標・条件・properties、起点と支持粒・捕捉フラグ、境界起点、補助谷底線・線支持、局所低さ、モデル間の変化、方法JSONを保存する。箱ひげ図は起点捕捉率・予測面積率を表示し、未定義を0に置換しない。`--plots-only` は保存済み集計から図を再生成する。旧分類スコアのCSVは現行集計へ流用しない。

実装：`src/theme2/valley_onset.py`、`src/theme2/valley_bottom.py`。D＋Qのstate追跡は[別資料](dq_origin_history.md)を参照。
