# state02の固定候補と後続起点：補助CLI

5モデルのstate02粒候補を固定し、利用可能な後続stateで初めて対応する起点を調べる補助解析。現行UIのD＋Q専用追跡とは別であり、UIから使うstate02〜12の谷・山対称追跡は [D＋Q追跡](dq_origin_history.md)を参照する。ΔM粒界候補・和集合は使用しない。

```bash
.venv/bin/python -m tools.theme2.validate_delayed_valleys --rho -0.5 --seed 1 --texture brass --sd 2
```

予測は初期情報から完了させ、その後でstate02以降のCPFEMを読む。候補粒と予測値は後続参照で更新しない。state02を必須とし、欠落stateは方法JSONに記録する。

## 分類と出力

同じ節点IDを初期材料座標へ戻して位置を比較する。過去の全観測起点に対して代表粒径の0.5倍、過去の線には初期格子間隔の1.01倍を許容幅に用いる。既存・再出現起点、既存／拡張谷上の新起点、新しい非連結谷の起点を区別する。既存線と接する拡張を新しい独立谷と数えない。

候補粒ごとに起点の初出、可視性、後続での対応を保存する。候補数と起点数は異なる。観測範囲の欠けはcensoredとし、最後まで未対応でも将来の形成を否定しない。初出stateは最初に観測されたstateであり、厳密な発生時刻や因果関係の証明ではない。

既定出力は `output/reports/delayed_valleys/`。`candidates.csv`、`observations.csv`、`origins.csv`、`lines.csv`、`states.csv`、`captures.csv`、`method.json` を保存する。実装は `src/theme2/delayed_valley.py`。
