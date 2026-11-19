# Background and Objective

Plastic deformation induces surface roughening in aluminum sheets, degrading their appearance and surface quality [1] and reducing their forming limits [2]. Understanding and predicting its formation mechanisms is therefore important. Previous studies have linked surface roughening and localized strain concentrations to heterogeneous deformation associated with crystallographic orientation and interactions between neighboring grains [3, 4]. This study focuses on the early development of surface topography and examines whether valley and peak initiation sites can be predicted from initial crystallographic orientations and differences in deformation response between neighboring grains.

# Methods

Models representing five characteristic texture components formed during rolling and annealing of aluminum sheets—Brass, Copper, Cube, Goss, and S [1]—were examined by varying orientation spread, imposed strain ratio, and microstructure generation conditions. Using a Sachs-type approach that assumes a common stress across grains [5], a thickness-direction response indicator, $K$, was calculated from the initial crystallographic orientations. A simplified prediction model was then constructed by combining the response contrast between each grain and its neighbors, $D$, with an indicator of deformation mismatch within grain-boundary planes, $Q$. Prediction inputs comprised only the initial microstructure, grain-boundary geometry, and prescribed loading conditions. The indicators and prediction equations are defined in the Appendix.

The predictions were evaluated against early-stage deformation results obtained using the crystal plasticity finite element method (CPFEM), based on the crystal plasticity formulation of Rossiter et al. [6]. Local minima and maxima of the surface height field were identified as valley and peak initiation sites, respectively. The initiation-site capture rate was defined as the number of reference sites located within grain regions predicted to be low or high, respectively, divided by the total number of corresponding reference sites. The predicted area fraction and capture efficiency, defined as the capture rate divided by the predicted area fraction, were also evaluated to account for the spatial extent of the predicted regions.

# Results

Valley initiation-site capture rates depended on texture. Cube exhibited relatively high capture rates, while Goss and Copper also outperformed Brass and S under many conditions. Brass and S showed relatively low capture rates, with more initiation sites located outside the predicted regions. Peak initiation sites exhibited different trends from valley initiation sites, including a decrease in capture rate with increasing orientation spread for Copper, demonstrating dependence on texture and loading conditions.

Visual comparison of the height maps identified cases in which relatively pronounced surface features were captured for textures other than Brass and S. The dependence of capture performance on feature depth, height, and spatial extent will be evaluated quantitatively in future work.

# Discussion and Future Work

These results suggest that deformation responses arising from initial crystallographic orientations and mismatch between neighboring grains provide insight into the locations of surface feature formation. The model approximates each grain using a representative initial response. Previous studies have reported texture-dependent differences in grain rotation and intragranular surface deformation [7], as well as the influence of crystallographic orientation evolution on surface roughening [8]. Considering the large intragranular orientation variations and grain rotations observed for Brass and S in the present analysis, heterogeneous intragranular deformation and changes in response associated with orientation evolution may contribute to their lower capture rates. This relationship constitutes a hypothesis for further investigation.

Future work will examine the spatial correspondence of initiation sites outside the predicted regions with grain orientation spread (GOS) and grain rotation to distinguish the roles of intragranular deformation and constraints near grain boundaries. The relationship between predicted area fraction and capture rate, performance for features of different prominence, and sensitivity to detection criteria will also be evaluated to establish the applicability of predictions based on initial information. Subsequent growth and coalescence of surface features, together with quantitative reconstruction of surface height distributions, will be addressed in a separate surface-response prediction study.

# Appendix: Definitions of Prediction Indicators and Height Response

Let $\dot{\boldsymbol{\varepsilon}}_i^p$ denote the plastic strain-rate tensor of grain $i$ obtained from the Sachs-type response based on its initial crystallographic orientation. ND denotes the sheet thickness direction.

## Volume-Weighted and Area-Weighted Averages

For a grain-wise quantity $X_i$, the volume-weighted and area-weighted averages are defined as

$$
\langle X\rangle_V
=\frac{\displaystyle\sum_{i\in\mathcal G}V_iX_i}
{\displaystyle\sum_{i\in\mathcal G}V_i},
\qquad
\langle X\rangle_A
=\frac{\displaystyle\sum_{i\in\mathcal S}A_iX_i}
{\displaystyle\sum_{i\in\mathcal S}A_i}
$$

Here, $\mathcal G$ is the set of all grains in the initial three-dimensional microstructure, and $V_i$ is the initial volume of grain $i$. The set $\mathcal S$ comprises grains exposed at the prediction surface, and $A_i$ is the initial area occupied by grain $i$ on that surface. Tensor averages are calculated by applying the same weights to each component.

Accordingly, the volume-averaged plastic strain-rate tensor, the reference value of $Q$, and the area-averaged height response are expressed explicitly as

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

## Thickness-Direction Response Indicator $K_i$

$$
K_i=-\frac{\dot{\varepsilon}_{i,\mathrm{ND\,ND}}^p}
{\dot{\bar{\varepsilon}}_{\mathrm{eq}}^p},
\qquad
\dot{\bar{\varepsilon}}_{\mathrm{eq}}^p
=\sqrt{\frac23
\left\langle\dot{\boldsymbol{\varepsilon}}^p\right\rangle_V:
\left\langle\dot{\boldsymbol{\varepsilon}}^p\right\rangle_V}
$$

The operator $\langle\cdot\rangle_V$ denotes averaging weighted by initial grain volume. The indicator $K_i$ quantifies the thickness-direction contraction response relative to the equivalent plastic strain rate of the aggregate, with contraction taken as positive.

## Response Contrast with Neighboring Grains $D_i$

$$
D_i=K_i-
\frac{\displaystyle\sum_{f\in\mathcal F_i}w_fK_{j(f)}}
{\displaystyle\sum_{f\in\mathcal F_i}w_f},
\qquad
w_f=\frac{S_f/\ell_f}
{\displaystyle\sum_{g\in\mathcal F}S_g/\ell_g}
$$

Here, $\mathcal F_i$ is the set of grain-boundary faces adjoining grain $i$, $\mathcal F$ is the set of all grain-boundary faces, $j(f)$ denotes the neighboring grain across face $f$, $S_f$ is the initial shared boundary-face area, and $\ell_f$ is the initial distance between the grain centroids. A positive $D_i$ indicates a stronger thickness-direction contraction response than that of the surrounding grains.

## In-Plane Grain-Boundary Deformation Mismatch $Q_i$

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

The tensor $\boldsymbol{\varepsilon}_i^{*}$ is obtained by scaling the initial Sachs-type response to the prescribed strain level and adjusting the magnitude of intergranular response differences. The vector $\mathbf n_f$ is the unit normal to the boundary face. The indicator $Q_i$ quantifies deformation mismatch within grain-boundary planes. The model assumes that a larger $Q$ corresponds to a stronger constraint on local deformation.

## Height Response

$$
\widetilde r_i=-\frac{CD_i}{1+\gamma Q_i/Q_{\mathrm{ref}}},
\qquad
r_i=\widetilde r_i-\langle\widetilde r\rangle_A,
\qquad
h_i=h_{\mathrm{macro}}+H_0r_i
$$

The conversion coefficient $C$ is determined by the prescribed strain level, the initial response, and the coefficient controlling intergranular response differences. The parameter $\gamma$ controls the constraint associated with $Q$, and $Q_{\mathrm{ref}}=\langle Q\rangle_V$ is its reference value. The operator $\langle\cdot\rangle_A$ denotes averaging weighted by initial surface area, $H_0$ is the initial sheet thickness, and $h_{\mathrm{macro}}$ is the surface height corresponding to the macroscopic thickness change.

# References

[1] Zhou, D., Du, W., Wen, X., Qiao, J., Liang, W., and Yang, F. “Local Deformation and Texture of Cold-Rolled AA6061 Aluminum Alloy.” *Materials*, 11(10), 1866 (2018).

[2] Takakura, N., Yamaguchi, K., and Fukuda, M. “Improvement of the Forming Limit of Sheet Metals by Removal of Surface Roughening with Plastic Strain.” *JSME International Journal*, 30(270), 2034–2039 (1987).

[3] Raabe, D., Sachtleber, M., Weiland, H., Scheele, G., and Zhao, Z. “Grain-scale micromechanics of polycrystal surfaces during plastic straining.” *Acta Materialia*, 51(6), 1539–1560 (2003).

[4] Stoudt, M. R., Levine, L. E., Creuziger, A., and Hubbard, J. B. “The fundamental relationships between grain orientation, deformation-induced surface roughness and strain localization in an aluminum alloy.” *Materials Science and Engineering: A*, 530, 107–116 (2011).

[5] Sachs, G. “Plasticity problems in metals.” *Transactions of the Faraday Society*, 24, 84–92 (1928).

[6] Rossiter, J., Brahme, A., Simha, M. H., Inal, K., and Mishra, R. “A new crystal plasticity scheme for explicit time integration codes to simulate deformation in 3D microstructures: Effects of strain path, strain rate and thermal softening on localized deformation in the aluminum alloy 5754 during simple shear.” *International Journal of Plasticity*, 26(12), 1702–1725 (2010).

[7] Furushima, T., and Nakazawa, A. “Misorientation standard deviation as a microstructural factor governing surface roughening in polycrystalline sheets analyzed with crystal plasticity modeling.” *Computational Materials Science*, 262, 114327 (2026).

[8] Zeng, X., et al. “Surface Roughening Behavior and Mechanism in Aluminum Alloy Under Tensile Deformation.” *Materials*, 17(23), 5911 (2024).
