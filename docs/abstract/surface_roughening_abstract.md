# 背景・目的

塑性変形に伴うアルミニウム板の表面あれは、製品の外観や表面品質を損ない[1]、成形限界の低下にもつながるため[2]、その発生機構の解明と予測が重要である。先行研究では、結晶方位や近傍粒との相互作用に伴う不均一変形が、表面あれや局所的なひずみ集中に関与することが報告されている[3], [4]。そこで、本研究では表面凹凸が発達する初期段階に着目し、初期結晶方位と隣接粒間の変形応答の不均一性から、谷および山の形成起点を予測できるか検証する。

# 手法

アルミニウム板の圧延・焼鈍過程で形成される代表的な集合組織成分であるBrass、Copper、Cube、Goss、S[1]を対象に、方位分散、負荷ひずみ比および結晶組織の生成条件を変化させたモデルを用いた。各粒に共通の応力を仮定するSachs型の考え方[5]に基づき、初期結晶方位から板厚方向の変形応答指標 $K$ を算出した。さらに、本研究で定義した自粒と周囲の粒との応答差 $D$、および粒界面内の変形不整合を表す指標 $Q$ を組み合わせ、簡易予測モデルを構築した。予測入力には、初期結晶組織、粒界幾何および所定の負荷条件のみを用いた。各指標と予測式の定義はAppendixに示す。

評価には、Rossiterら[6]の結晶塑性定式化に基づく結晶塑性有限要素法（CPFEM）による変形初期の解析結果を用いた。表面高さ場から局所最深部と局所最高部をそれぞれ谷・山の起点として抽出し、予測で低い、または高いと判定された粒領域に含まれる起点数を、対応する全起点数で除した値を起点捕捉率とした。また、予測領域の広さと捕捉性能を併せて評価するため、予測面積率と、起点捕捉率を予測面積率で除した捕捉効率を補助指標とした。

# 結果

谷の起点捕捉率には集合組織による差が認められ、Cubeで比較的高く、GossおよびCopperでも多くの条件でBrass・Sを上回った。一方、Brass・Sでは相対的に捕捉率が低く、予測領域外に位置する起点が多く認められた。山の起点については谷とは異なる傾向を示し、Copperでは方位分散の増加に伴う捕捉率低下が見られるなど、集合組織と負荷条件に応じた変化が確認された。

高さマップの目視比較では、Brass・Sを除く条件で、比較的顕著な凹凸の起点を捉える事例が認められた。起点の深さ・高さおよび空間的な大きさと捕捉性能との関係については、今後、定量的に評価する。

# 考察・今後の課題

以上の結果は、初期結晶方位に由来する変形応答と隣接粒間の不整合が、表面凹凸の形成位置を説明する手掛かりとなることを示唆する。本モデルは、各粒の初期応答を代表値として扱う近似に基づく。一方、先行研究では集合組織に応じた結晶粒回転や粒内表面変形の違いが示されており[7]、結晶方位の発展が表面あれに及ぼす影響も報告されている[8]。本解析で観察されたBrass・Sの大きな粒内方位差や結晶粒回転を踏まえると、粒内の不均一変形および方位発展に伴う応答変化が、これらの集合組織における捕捉率低下に関与する可能性がある。この関係を、今後の検証仮説として位置付ける。

今後は、予測領域外の起点とGOS・結晶粒回転の空間的対応を解析し、粒内変形と粒界近傍の拘束が起点形成に及ぼす役割を切り分ける。また、予測面積率と捕捉率の関係、起点の顕著さ別の捕捉性能、および検出条件への感度を評価し、初期情報に基づく予測の適用範囲を明確化する。起点形成後の凹凸の拡大・連結および高さ分布の定量的再現は、別途進める表面応答予測の課題として位置付ける。

# Appendix：予測指標と高さ応答の定義

初期結晶方位に基づくSachs型応答から得られる粒 $i$ の塑性ひずみ速度テンソルを $\dot{\boldsymbol{\varepsilon}}_i^p$ とする。以下では、NDを板厚方向とする。

## 体積平均と面積平均

粒ごとの量 $X_i$ に対し、体積平均と面積平均をそれぞれ次式で定義する。

$$
\langle X\rangle_V
=\frac{\displaystyle\sum_{i\in\mathcal G}V_iX_i}
{\displaystyle\sum_{i\in\mathcal G}V_i},
\qquad
\langle X\rangle_A
=\frac{\displaystyle\sum_{i\in\mathcal S}A_iX_i}
{\displaystyle\sum_{i\in\mathcal S}A_i}
$$

$\mathcal G$ は初期3次元組織の全粒の集合、$V_i$ は粒 $i$ の初期体積を表す。$\mathcal S$ は予測対象表面に露出する粒の集合、$A_i$ は粒 $i$ がその表面に占める初期面積を表す。テンソル量の平均も、各成分に同じ重みを適用して求める。

したがって、本モデルで用いる塑性ひずみ速度の体積平均、$Q$ の基準値、および高さ応答の面積平均は、具体的に次のように表される。

$$
\left\langle\dot{\boldsymbol{\varepsilon}}^p\right\rangle_V
=\frac{\displaystyle\sum_{i\in\mathcal G}V_i\dot{\boldsymbol{\varepsilon}}_i^p}
{\displaystyle\sum_{i\in\mathcal G}V_i},
\qquad
Q_{\mathrm{ref}}
=\frac{\displaystyle\sum_{i\in\mathcal G}V_iQ_i}
{\displaystyle\sum_{i\in\mathcal G}V_i}
$$

$$
\langle\widetilde r\rangle_A
=\frac{\displaystyle\sum_{i\in\mathcal S}A_i\widetilde r_i}
{\displaystyle\sum_{i\in\mathcal S}A_i}
$$

## 板厚方向応答指標 $K_i$

$$
K_i=-\frac{\dot{\varepsilon}_{i,\mathrm{ND\,ND}}^p}
{\dot{\bar{\varepsilon}}_{\mathrm{eq}}^p},
\qquad
\dot{\bar{\varepsilon}}_{\mathrm{eq}}^p
=\sqrt{\frac23
\left\langle\dot{\boldsymbol{\varepsilon}}^p\right\rangle_V:
\left\langle\dot{\boldsymbol{\varepsilon}}^p\right\rangle_V}
$$

$\langle\cdot\rangle_V$ は初期粒体積による重み付き平均を表す。$K_i$ は、組織全体の相当塑性ひずみ速度を基準とした板厚方向収縮応答の強さを表し、収縮を正とする。

## 隣接粒との応答差 $D_i$

$$
D_i=K_i-
\frac{\displaystyle\sum_{f\in\mathcal F_i}w_fK_{j(f)}}
{\displaystyle\sum_{f\in\mathcal F_i}w_f},
\qquad
w_f=\frac{S_f/\ell_f}
{\displaystyle\sum_{g\in\mathcal F}S_g/\ell_g}
$$

$\mathcal F_i$ は粒 $i$ に接する粒界面の集合、$\mathcal F$ は全粒界面の集合、$j(f)$ は隣接粒、$S_f$ は初期共有粒界面積、$\ell_f$ は初期粒重心間距離である。$D_i>0$ は、周囲より板厚方向の収縮応答が強いことを示す。

## 粒界面内の変形不整合 $Q_i$

$$
Q_i=\sum_{f\in\mathcal F_i}w_f
\left\|
\mathbf P_f
\left(\boldsymbol{\varepsilon}_i^{*}-
\boldsymbol{\varepsilon}_{j(f)}^{*}\right)
\mathbf P_f
\right\|_{\mathrm F}^{2},
\qquad
\mathbf P_f=\mathbf I-\mathbf n_f\otimes\mathbf n_f
$$

$\boldsymbol{\varepsilon}_i^{*}$ は初期Sachs型応答を所定のひずみ量に換算し、粒間の応答差を調整したひずみテンソル、$\mathbf n_f$ は粒界面の単位法線である。$Q_i$ は粒界面内の変形不整合の大きさを表す。本モデルでは、$Q$ が大きいほど局所変形への拘束が強まると仮定する。

## 高さ応答

$$
\widetilde r_i=-\frac{CD_i}{1+\gamma Q_i/Q_{\mathrm{ref}}},
\qquad
r_i=\widetilde r_i-\langle\widetilde r\rangle_A,
\qquad
h_i=h_{\mathrm{macro}}+H_0r_i
$$

$C$ は所定のひずみ量と初期応答、および粒間応答差の調整係数から定まる変換係数、$\gamma$ は $Q$ による拘束の強さ、$Q_{\mathrm{ref}}=\langle Q\rangle_V$ は $Q$ の基準値である。$\langle\cdot\rangle_A$ は初期表面積による重み付き平均、$H_0$ は初期板厚、$h_{\mathrm{macro}}$ は巨視的な板厚変化に対応する表面高さを表す。

# 参考文献

[1]Zhou, D., Du, W., Wen, X., Qiao, J., Liang, W., and Yang, F. “Local Deformation and Texture of Cold-Rolled AA6061 Aluminum Alloy.” *Materials*, 11(10), 1866 (2018).

[2]Takakura, N., Yamaguchi, K., and Fukuda, M. “Improvement of the Forming Limit of Sheet Metals by Removal of Surface Roughening with Plastic Strain.” *JSME International Journal*, 30(270), 2034–2039 (1987).

[3]Raabe, D., Sachtleber, M., Weiland, H., Scheele, G., and Zhao, Z. “Grain-scale micromechanics of polycrystal surfaces during plastic straining.” *Acta Materialia*, 51(6), 1539–1560 (2003).

[4]Stoudt, M. R., Levine, L. E., Creuziger, A., and Hubbard, J. B. “The fundamental relationships between grain orientation, deformation-induced surface roughness and strain localization in an aluminum alloy.” *Materials Science and Engineering: A*, 530, 107–116 (2011).

[5]Sachs, G. “Plasticity problems in metals.” *Transactions of the Faraday Society*, 24, 84–92 (1928).

[6]Rossiter, J., Brahme, A., Simha, M. H., Inal, K., and Mishra, R. “A new crystal plasticity scheme for explicit time integration codes to simulate deformation in 3D microstructures: Effects of strain path, strain rate and thermal softening on localized deformation in the aluminum alloy 5754 during simple shear.” *International Journal of Plasticity*, 26(12), 1702–1725 (2010).

[7]Furushima, T., and Nakazawa, A. “Misorientation standard deviation as a microstructural factor governing surface roughening in polycrystalline sheets analyzed with crystal plasticity modeling.” *Computational Materials Science*, 262, 114327 (2026).

[8]Zeng, X., et al. “Surface Roughening Behavior and Mechanism in Aluminum Alloy Under Tensile Deformation.” *Materials*, 17(23), 5911 (2024).
