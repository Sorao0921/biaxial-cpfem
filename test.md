Let
\[
\begin{pmatrix}X_1\\X_2\end{pmatrix}
\sim N_2\left(
\begin{pmatrix}0\\0\end{pmatrix},
\begin{pmatrix}1&0.8\\0.8&1\end{pmatrix}
\right).
\]
Thus, both variables have mean \(0\) and variance \(1\), and their correlation is \(0.8\).

**1. Deriving the full conditional distributions**

The conditional distribution \(X_1\mid X_2=x_2\) describes the distribution of \(X_1\) when the value of \(X_2\) is fixed at \(x_2\).

For a bivariate normal distribution, the conditional distribution is
\[
X_1\mid X_2=x_2
\sim N\left(
\mu_1+\frac{\sigma_{12}}{\sigma_2^2}(x_2-\mu_2),
\quad
\sigma_1^2-\frac{\sigma_{12}^2}{\sigma_2^2}
\right),
\]
where the second parameter of \(N(\cdot,\cdot)\) denotes the **variance**.

In this problem,
\[
\mu_1=\mu_2=0,\qquad
\sigma_1^2=\sigma_2^2=1,\qquad
\sigma_{12}=0.8.
\]
Therefore, the conditional mean is
\[
E[X_1\mid X_2=x_2]
=0+\frac{0.8}{1}(x_2-0)
=0.8x_2,
\]
and the conditional variance is
\[
\operatorname{Var}(X_1\mid X_2=x_2)
=1-\frac{0.8^2}{1}
=0.36.
\]
Hence,
\[
\boxed{X_1\mid X_2=x_2\sim N(0.8x_2,\;0.36).}
\]

By symmetry, interchanging the roles of \(X_1\) and \(X_2\) gives
\[
\boxed{X_2\mid X_1=x_1\sim N(0.8x_1,\;0.36).}
\]

For example, if \(X_2=2\), then
\[
X_1\mid X_2=2\sim N(1.6,\;0.36).
\]
This distribution has mean \(1.6\) and standard deviation \(\sqrt{0.36}=0.6\). Knowing one variable helps predict the other, so the conditional variance is smaller than the marginal variance of \(1\).

**2. Writing one systematic-scan Gibbs update**

Gibbs sampling updates one variable at a time by drawing from its conditional distribution, holding the other variable fixed.

Suppose the current state is
\[
\left(X_1^{(t)},X_2^{(t)}\right).
\]
The superscript \((t)\) indicates the iteration number; it is not an exponent.

A systematic scan in the order \(1\to2\) means that we first update \(X_1\), then update \(X_2\) using the newly generated value of \(X_1\).

Recall that if \(Z\sim N(0,1)\), then
\[
m+sZ\sim N(m,s^2).
\]
Since the conditional variance is \(0.36\), the standard deviation used to generate each draw is \(0.6\).

First, using the current value \(X_2^{(t)}\), draw
\[
\boxed{
X_1^{(t+1)}=0.8X_2^{(t)}+0.6Z_1.
}
\]

Next, using the updated value \(X_1^{(t+1)}\), draw
\[
\boxed{
X_2^{(t+1)}=0.8X_1^{(t+1)}+0.6Z_2.
}
\]

Here, \(Z_1,Z_2\) are independent standard normal random variables, generated independently of the current state.

Thus, one complete Gibbs sweep is
\[
\boxed{
\begin{aligned}
X_1^{(t+1)}&=0.8X_2^{(t)}+0.6Z_1,\\
X_2^{(t+1)}&=0.8X_1^{(t+1)}+0.6Z_2.
\end{aligned}
}
\]

The key point is that **the second update uses the newly sampled \(X_1^{(t+1)}\)**. Each subsequent sweep uses a fresh pair of independent standard normal draws.