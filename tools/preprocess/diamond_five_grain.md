# 菱形中央粒をもつ5粒モデル

`inputs/keywords_diamond/consts/initmesh_diamond.k` の構造メッシュを読み込み、節点と要素の接続を保ったまま、各要素に粒IDを割り当てる。中央粒は板厚方向に貫通し、要素重心のXY座標が菱形内にあれば粒1となる。周囲は右上から反時計回りに粒2〜5。粒界は立方体要素の面に沿う階段状の近似となる。

```bash
python -m tools.preprocess.generate_diamond_five_grain_patch
```

VS Codeでは `generate_diamond_five_grain_patch.py` を開いて▶から実行できる。標準の出力は `models/diamond_models/diamond_center_5grains.k`。変更する場合は `--output-dir` を指定する。中央粒の対角線長は `--central-diagonal` で指定でき、既定値は 0.015 mm。

境界節点集合101〜106は XMIN/XMAX、YMIN/YMAX、ZMIN/ZMAX。集合301〜304は中央粒と粒2〜5が共有する節点。SECTION 1 と PART 1〜5 を出力し、材料カード・結晶方位・境界条件・負荷は解析入力で別途設定する。
