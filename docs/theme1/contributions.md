# 物理量と表面粗面化の寄与解析

GOS・粒回転・累積せん断ひずみと表面粗面化の関連を、表面要素単位の標準化重回帰で調べる。実装は `src/theme1/contribution.py`、実行入口は `tools/theme1/estimate_contributions.py`。

```bash
uv run python -m tools.theme1.estimate_contributions
uv run python -m tools.theme1.estimate_contributions --rho -0.5 --seed 1 --texture brass --sd 2 --state 2
```

## データと推定

CLIは `coords/rawdata` を優先して高さを選び、粒方位指標・せん断ひずみ・空間モデルが揃うケースを使用する。高さCSVの読込・表面ID対応・ケース対応は `src/postprocess/case_data.py` に共通化している。

節点高さから最小二乗基準面を除去し、表面要素を構成する節点の絶対高さ残差を平均して目的変数とする。GOS・粒回転はpart ID、せん断ひずみはelement IDで結合する。

ケース内で変数を標準化し、ケース別係数と決定係数を求める。全体推定では要素数によらず各ケースの総重みが等しくなるよう重み付けする。寄与重みは標準化係数の絶対値を合計で割った値で、符号付き係数も併記する。

## 保存

既定出力は `database/theme1/contributions/`。`--outputs`・`--spatial-models`・`--output-dir` で入出力を変更できる。

| ファイル | 内容 |
|---|---|
| `contribution_weights.csv` | 標準化係数、相対寄与重みと百分率 |
| `case_coefficients.csv` | ケース別係数、決定係数、サンプル数 |
| `diagnostics.json` | ケース数、総サンプル数、全体の決定係数と解釈 |

推定値は観測上の関連であり、因果効果ではない。説明変数間の相関が強いと個々の係数が不安定になるため、全体重みだけでなくケース別係数・決定係数も確認する。
