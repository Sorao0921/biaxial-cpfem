# 初期方位からの Taylor factor

225 方位ファイル（5 texture × sd 2–10 × seed 1–5）について計算。
各ファイル840方位、4負荷条件で756,000行。うち13,500行はメッシュに要素を
持たない方位エントリなので、実在粒の解析には `element_count > 0` を使う。
粒IDは元方位CSVの行番号（1始まり）、要素数は各seedのpartsetから取得。

## 結果

- `grain_taylor_factors.csv`: 粒別の値、初期Euler角（rad）、結晶粒の要素数。
- `case_summary.csv`: ケース別の実在粒の平均・範囲・標準偏差と要素数重み平均。
- `metadata.json`: 定義、前提、入力ファイルのSHA256、検証誤差。

`rho_label` は `-0.5`, `0`, `1`, `0_boundary`。
最後の条件だけ `rho_used=0.001`、他は公称rhoそのもの。
境界カードはx面に速度係数1、y面にそれぞれ-0.5, 0.001, 1を指定している。
正方形の初期形状における速度比を初期ひずみ速度比として使用する。

## 定義と前提

FCC {111}<110> の12すべり系、全系等CRSS、全粒等ひずみのTaylorモデル。
試料座標のひずみ増分を D=diag(1,rho,-1-rho) とし、塑性非圧縮・せん断成分0を仮定。
Bunge角はラジアン（生成元 `tools/preprocess/generate_angles_with_mirror.m`）。
受動回転行列 g で D_crystal = g D g^T とする。

M = min Σ|γ_α| / sqrt((2/3)D:D),
subject to Σ γ_α sym(s_α ⊗ n_α) = D_crystal.

分母はvon Mises相当塑性ひずみ。軸方向ひずみやFrobeniusノルムで正規化した
文献・ツールの値とは係数が異なる場合がある。
最小すべり問題の説明: https://mtex-toolbox.github.io/TaylorModel.html
（MTEXそのものを実行した結果ではない。）

これは初期方位と仮定した負荷モードから予測した値。
FE結果の局所塑性ひずみや累積すべり量から求めた実効比ではなく、
粒間拘束の不均一性、異なるすべり抵抗、変形後の方位変化は含まない。
state=1は初期方位を表す識別値であり、state01の0/0を計算したものではない。
要素数重み平均は体積重み平均とは区別する。

## 検証・再実行

NumPyのみで線形計画の双対頂点56個を列挙し、各方位を評価した。
全225ケース×4負荷条件の先頭3方位を、独立した主問題の基底列挙で照合。
最大絶対差5.280220705117245e-13。
無作為25方位×4負荷条件、回転行列の直交性、180度試料回転不変性、
[100]/[111]軸のFCC理論値についてテスト2件が通過。
保存後に756,000行を再読込し、未使用エントリ数・集計を確認。

リポジトリルートで実行（既存のこの出力を再生成する）:

```sh
.venv/bin/python -m tools.postprocess.calculate_initial_taylor
.venv/bin/python -m pytest tests/test_taylor_factor.py -q
```

## 保存先とUI

全結果は `database/taylor_factor_initial/` に保存する。
UI用に公称rhoごとの粒別ファイルを
`database/taylor_factor_initial/rho_*/rho_*_seed*/taylor_factor/initial/taylor_factor_{case}_state01.csv`
にも生成する。初期方位3列を同梱する。
UIではTaylor factorとEuler角マップをstate01の値・変形前形状に固定する。
GOS等の選択stateは初期指標には適用しない。
Euler角表示は度で、角度の色差は結晶方位差そのものではない。
