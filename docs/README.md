# 資料の案内

現行の分類はtheme1＝メカニズム解明、theme2＝予測・評価、postprocess＝後処理・高さ分布の追加指標とする。保存済みデータの `database/theme1` 等の名前は、コード・資料の分類と独立に維持する。

## theme1：メカニズム解明

- [GOS・粒回転・せん断ひずみの寄与解析](theme1/contributions.md)
- [初期Sachs応答とND収縮指標χ・K](theme1/initial_stress_response.md)
- [初期Taylor活動と実測高さの対応](theme1/initial_taylor_state13.md)
- [実測高さ場からの谷・山の起点検出](theme1/surface_valley_origins.md)

## theme2：予測・評価

現行UIの評価から読む場合：

- [state02の5モデル比較と起点捕捉・面積率](theme2/valley_onset_state02.md)
- [D＋Qの谷・山の起点追跡（state02〜12）](theme2/dq_origin_history.md)
- [固定候補と後続起点の補助CLI](theme2/delayed_valleys_state02.md)

モデルの式・保持中のCLIを確認する場合：

- [初期Taylor活動からの高さ仮説モデル](theme2/initial_height_state13.md)
- [初期指標と隣接粒による高さ再構成](theme2/neighbor_height_prediction.md)
- [Sachs全テンソルによる3D平衡予測](theme2/sachs_equilibrium_prediction.md)
- [K・D/Q・3D平衡・CPFEMの比較](theme2/initial_fourway_comparison.md)
- [保存済み高さ場の粒重心による山・谷評価](theme2/valley_prediction_evaluation.md)

粒重心による分類評価のPrecision・Recall・F1と、現行の起点捕捉・面積率の評価は別方式である。旧state13の資料はCLIとして保持しているモデルの定義であり、現行UIの画面案内ではない。

## postprocess：後処理・追加指標

- [高さ分布のグラフ・FFT帯域指標](postprocess/height_bands.md)
- [補助形状としての谷底線](postprocess/trough_lines.md)
- [初期・state別Taylor factor計算](postprocess/taylor_factor.md)
- [UMAT履歴出力とHV番号](postprocess/umat_history_outputs.md)
- [データカタログ・準備状況](postprocess/data_catalog.md)

## 履歴と整理内容

[2026-10-08の研究計画](archive/theme1_theme2_research_plan_20261008.md)は提案時点の記録としてarchiveに保存する。FNO・IG等の提案を現行の実装済み仕様とは扱わない。重複する生成HTML・PDFは削除した。

廃止済みのΔM粒界・和集合の専用資料と空の `report01.tex` は削除した。旧谷底線・線上起点の資料は、共通検出定義・補助谷底線・現行の予測評価へ統合した。旧6モデル、旧分類指標、画面変更の追記を現行の5モデル・起点評価と混在させないよう整理した。

実行ツールは [toolsの案内](../tools/README.md)、実装は [srcの案内](../src/README.md)、検証は [testsの案内](../tests/README.md) を参照。
