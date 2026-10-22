# Kのみ・D/Q・3D平衡・CPFEMの4者比較

## 目的と参照した定義

初期組織のどの情報が表面応答の説明に必要かを比較する。DとQはユーザー共有会話 https://chatgpt.com/s/t_6ad1904bdf2c81919f19a30b70d66b10 の次の定義に基づく。会話の提案は検証仮説であり、確立した高さ予測式や実験的な証拠としては扱わない。

```
D_i = K_i - sum_j(w_ij*K_j)/sum_j(w_ij)
P_f = I - n_f outer n_f
Q_i = sum_(faces f adjacent to grain i) w_f * ||P_f*(eps_i-eps_j)*P_f||_F^2
```

D>0は周囲よりND収縮しようとする粒で、谷の候補。Qは非負の粒界面内ひずみ不適合の大きさであり、それだけでは山谷の符号を与えない。P jump Pは微小ひずみにおける粒界面内の整合性の候補指標で、完全な適合性・力学平衡や不安定性を判定するものではない。

## 4つの表示

- A `k_only`：Kから得るND近傍差Dのみ。QやRD/TD伸長差、低Kゲートを混ぜない。
- B `d_q`：Aと同じDに、Qに基づく追加の局所拘束を加える。3次元有限要素平衡は解かない。
- C `equilibrium`：初期Sachsの6成分を固有ひずみとして与え、初期3次元メッシュの線形弾性平衡を解く。
- CPFEM state13：比較する参照解析結果。実験実測ではない。

以前のKモデルは表面粒の正側活動超過、RD/TD配合、低Kゲート、指数板厚変換を含んでいた。今回のAは公平な比較のための**NDのみの比較用統一版**で、過去のKモデルと同一ではない。過去の出力や旧CLIは保存してある。A・B間ではQの有無だけを変更する。

## 全モデルに共通する初期情報

初期方位、初期メッシュの全粒体積、負荷rho、速度感受性mを使う。初期Sachs応答A_iの体積平均がmean(A)_yy/mean(A)_xx=rhoとなる応力比betaを逆算する。変形中の応力・方位・すべり・ひずみデータは使わない。

```
Dmacro = diag(1,rho,-1-rho) / sqrt((2/3)*(1+rho^2+(1+rho)^2))
eps_Sachs_i = strain*Dmacro_xx*A_i / volume_mean(A)_xx
eps_i = volume_mean(eps_Sachs) + eta*(eps_Sachs_i-volume_mean(eps_Sachs))
K_i = -A_i_zz / eq(volume_mean(A))
gain = Dmacro_xx*eq(volume_mean(A)) / volume_mean(A)_xx
```

既定eta=0.75を全モデル共通で使い、AのND差にも同じetaを掛ける。全成分を同率で調整し、体積平均・非圧縮性は保つ。eta=0.75は過去の結果を見て設定した近似値であり、独立した予測精度の検証と同一視しない。既定strain=0.1も事前指定であり、state13の解析ひずみから合わせたものではない。ここでの「共通」は3つの予測モデル間の条件であり、CPFEMの材料定数・m・硬化則と同定されたことや、state13の実際のひずみ量との一致を保証しない。

## 粒界と重み

初期3次元メッシュで4節点を実際に共有する面を検出する。同じ粒に属する内部面と外表面を除外し、異なる粒をつなぐ実粒界面を保持する。各面の三角形面積からarea_fと単位法線n_fを計算する。隣接する粒の初期体積重心間距離をdistance_ijとして、

```
w_f_raw = area_f / distance_ij
w_f = w_f_raw / sum_all_boundary_faces(w_raw)
```

とする。Dの近傍平均は各粒の次数sum(w)で割る。Qはリンクの定義どおり二乗差の重み付き和であり、次数で割っていない。Qのスケールは下記Qrefで無次元化する。法線を粒重心を結ぶ向きで代用せず、同じ粒界の法線が異なる面も、法線を平均せず個別に計算する。これにより段差状の粒界を保持する。

初期メッシュのアフィン8節点六面体を対象とする。粒体積と重心は初期節点から算出し、既存のGauss体積と照合。非アフィン要素や非多様体共有面は黙って近似せずエラーにする。隣接粒がない粒はD=Q=0とする。

A・Bの高さを結合する表面グラフは、初期上面の共有粒界長／表面粒重心間距離を全辺合計で規格化して用いる。DとQの計算には表面直下を含む3次元粒隣接を使うが、A・Bは3次元の変位・力学平衡を解いていない。

## D・Qから高さへの閉じ方（追加仮説）

共有会話には高さへの変換式が指定されていない。そこで、Qが大きいほど局所の自由変形が拘束される、という次の仮説を採用する。

```
a_i = initial_surface_area_i / sum_surface_area
Qref = volume-weighted mean Q over ALL initial grains
q_i = Q_i / Qref                   # Qref=0なら0
r_target_i = -strain*gain*eta*D_i
(diag(a_i*(1+gamma*q_i)) + lambda*L_surface) r = diag(a_i)*r_target
r = r - surface_area_mean(r)
Hmacro = H0*(1+strain*Dmacro_zz)
z_i = initial_bottom_z + Hmacro + H0*r_i
```

Aはgamma=0、Bは既定gamma=1。同じ負荷・同じ高さ変換・同じ表面結合lambda=1を使うため、**gamma=0にするとAとBは数値的に完全一致**する。Dで符号を与え、非負のQは受動的な拘束の強さにのみ作用する。Q単独を谷深さに読み替えない。Qが大きいほど凹凸が弱まるという単調性は未検証の仮説であり、逆の物理機構や帯の発生を再現できる保証はない。Qの係数をCPFEM高さへ自動的にフィットする処理はない。

高さは線形式で、Cと同じ小変形の負荷表現を採用する。値のクリップ・指数による正値化・振幅合わせは行わない。A・Bで非正の板厚があれば警告する。粒高さは初期要素面積で共有表面節点へ平均する。図のxyは全予測で指定小変形の面内アフィン座標、zは予測した値を使用する。

## 評価・表示・保存

UIメニュー「初期指標と表面高さ（state13）」は4枚表示に変更。左からA/B/C/CPFEMを横1行。共通条件は折りたたみに置き、D/Qや粒界法線はZIP内に保存する。主表示は4枚と精度表のみ。

全3予測が完了してからCPFEM座標を読む。CLIでは予測をディスクへ保存した後だけ読む。比較時に節点IDで領域を対応させ、初期予測全体は変更しない。対応節点のPearson相関、元の高さRMSE、平均高さ誤差、予測/CPFEMの高さ標準偏差比を保存する。中心化RMSEもCSVに保存するが、図・予測値を中心化しない。各マップ自身の節点高さの2〜98百分位を個別の表示色範囲に使い、CPFEMや他モデルの値で予測図の色範囲を決めない。範囲外も誤差計算には含む。色の濃さだけでモデル間の振幅を比較せず、各カラーバーと精度表の振幅比を確認する。CPFEM値は予測完了後の参照図と評価にのみ使う。

Cの反復残差、反転要素数、最大初期固有ひずみ等を記録し、収束と小変形の適用範囲を区別する。Qが効いて相関が上がったとしても、機構の因果的証明とはならない。Cとの差には内部の非局所拘束に加え、A/Bが経験的な高さ閉じ方を使う違いも含まれる。

## 一括比較

```
python -m tools.theme1.compare_initial_models --rho=-0.5 --seed 1 --sd 8
python -m tools.theme1.compare_initial_models --rho=-0.5 --seed 1 --sd 8 --q-coupling 0
```

--texture brassで1組織。条件を指定しなければ既存state13全240ケースが対象。UIでも全240ケースを選択できる。既定共通条件はm=0.05、strain=0.1、eta=0.75、lambda=1、gamma=1、nu=0.3。

出力先：database/theme1/initial_fourway_state13/<case>/<configuration_hash>/。

- indicators.csv：全粒K・D・Q・近傍平均・次数・初期体積・自由変形6成分。
- interfaces.csv：実粒界面の粒ID対・面積・重心距離・法線・重み・投影テンソル差の二乗・Qへの寄与。
- surface_edges.csv：高さ閉じ方の表面粒グラフ。
- k_only/、d_q/、equilibrium/：各モデルの全表面座標・条件。Cは全3次元変位も保存。
- cpfem_state13.csv：予測完了後に読み込んだ参照。
- 各モデルのheight_comparison.csv、evaluation.csv：対応節点値と精度。
- comparison.png：4枚を横1行に配置し、各マップで独立した2〜98百分位の色範囲を使用。

過去の先生向けKモデル集や3D比較の出力は上書きしない。
