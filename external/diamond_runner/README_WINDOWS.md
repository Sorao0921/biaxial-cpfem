# Diamond用Windows runner（2ファイル）

`prepare.ps1` と `RUN_ALL.bat` だけをdiamond_models直下へ置く。Python・MATLABや補助ps1は不要。

1. `RUN_ALL.bat` 冒頭の `DIAMOND_SOLVER`、`DIAMOND_NCPU`、`DIAMOND_MEMORY` を設定する。
   初期値は既存マクロと同じUMAT組み込みexe `C:\LSDYNA\program\lsdyna_cp.exe`、16 CPU、memory=200000000。
2. PowerShellで `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\prepare.ps1` を実行する。
3. `RUN_ALL.bat` を実行する。

prepare.ps1は `rho_*/seed_*/deg_*/goss.k` を `rho_*/seed_*/deg_*/goss/model.k` へ**移動・改名**する。
各ケースに追加のBATは作らない。既存model.kが違う内容なら全体の処理を始める前に停止する。
同じ内容のmodel.kが既にある場合は保持する。その場合は元の.kも削除しない。
既に移動済みのケースと解析結果は再度prepareしても保持される。

RUN_ALL.batは `rho_*/seed_*/deg_*/*/model.k` を探し、1件ずつ実行する。移動前の元ファイルは不要。
解析結果は各ケースの `run/` に保存する。keywordset.kとdiamond_center_5grains.kは実行しない。
RUN_ALL.batの後半にはPowerShell処理を内蔵しているが、別のps1には依存しない。

確認だけ行う場合：

```powershell
.\prepare.ps1 -Preview
.\RUN_ALL.bat -Preview
```

prepareのみ対象を絞る場合（RUN_ALLはその時点の準備済み全ケースを実行する）：

```powershell
.\prepare.ps1 -Rhos '1' -Seeds 1 -Degrees 5 -Textures goss
```

終了コード0・正常終了メッセージ・入力SHA256で完了を記録し、完了済みはスキップする。
通常表記と文字間空白付きのNormal terminationに対応する。
既存runがあるが完了を確認できない場合は結果を削除せず停止する。
`RUN_ALL.bat -Retry` なら旧runをケース内のarchiveへ移動して再実行する。完了済みはスキップする。
`-ContinueOnError` で失敗後も次へ進む。既定では最初の失敗で停止する。
二重起動はdiamond_run.lockで防ぐ。強制終了後にlockが残った場合は、ソルバー停止を確認してからそのlockだけを削除する。
これはソルバー完走の判定で、相当塑性ひずみ10%到達や計算結果の妥当性の評価ではない。

旧7ファイル構成の補助ファイルは不要。設定はRUN_ALL.batに直接記述する。
Windowsへ更新コピーするときは、編集済みのソルバー設定を引き継ぐ。
