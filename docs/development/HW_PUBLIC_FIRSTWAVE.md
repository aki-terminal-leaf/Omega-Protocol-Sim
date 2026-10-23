# Hello World 首輪公開資訊、NPC 預處理及玩家配合（v0.3.20 Web-first 限定驗收）

固定站 https://top.servicing.cc 已更新 v0.3.20。此增量只修首輪塔揭示與實際玩家選側的 NPC 行動；新包／實際Web／公開HTTPS已驗，Windows原生限定驗證及離線包也已完成；不等於全部攻略符合。

## 行為與來源界線

- 起始配置／NPC 預站位不依賴未顯示的塔方向。保留既有角色與初始減益分工；帶毒在外、連線在內。這不表示已完成玩家自己執行的初始八方觀察與全部交接教學。
- 只接受當前 Arena 真正繪出的四個紅藍塔；時間到了、pending 事件或預算終點都不能單獨解鎖首輪走位。完整塔資訊出現後，才由公開塔色／幾何及目前位置選等價同色側與外圈路徑。
- 玩家親自移動、原地合法等待、改選及回到原側都保留實際位置。NPC 不讀玩家未來意圖或按鍵目標、不修改玩家座標、不代傳毒或補成正確站位。
- 靠近另一側或站定的觀察是 NPC 訓練實現；不是攻略新增的玩家操作。站定使用固定位置錨點與模擬時間，避免高更新率把持續移動誤認為靜止；選側在真正踩塔結算前可更新，結算後保留交接分工。
- 原有 6 碼走速、塔半徑 6／中心半徑 14、24+21r 塔判定、狀態／感染／Debugger／碰撞與傷害均未放寬。14 秒顯示／24 秒首塔是既有訓練時序，不是原服逐幀來源；原始提示起算點仍 source_unknown。
- R 清除該段未來觀察；新練習清除舊輔助來源。分段重建的過去保持 synthetic/assisted，報告與畫面標為分段輔助，不得算完整玩家練習。
- 後三輪仍保留既有路線及未結清的提前分配問題；不能由首輪成功外推全部資訊隔離。接觸半徑、原服同步事件／HP／減傷精度與全社群玩家分支仍受原限制。

## 已有來源

沿用 top/data/hw_routes.json 的已讀來源與各區後續／第四輪差別，不把共同預排覆蓋所有區服：

- elemental: https://ffxiv.tuufless.com/elemental/top/03_omega_reconfigured/（Hello World setup, first/second/third iterations, fourth iteration）。
- aether: https://www.thepfstrat.com/u/top（P3 Hello World lines185–193）; https://ff14.toolboxgaming.space/?id=243183080764761（[11, 28]）。
- lpdu: https://raw.githubusercontent.com/cliaux/lpdu.github.io/main/top/top_discord_strats.md（Phase3 Hello World link）; https://ff14.toolboxgaming.space/?id=702399575985961（[1, 19]）。
- cn_moogle: https://docs.qq.com/doc/DSlBpR0JqSElVelhH（Page1 P3HW 提示+移动规则）; https://www.bilibili.com/video/av740517066/?p=3（P3 frames450-610s: all four debuff paths and fourth-round exception; 630s role cycle）。
- kr_09stop: https://docs.google.com/spreadsheets/d/1lzaCorDOUwYglSXbMnEtoOcbRQdiIpVijhMh12r8N-Q/edit#gid=1826471436（#Phase.3 rows 118–303）。

## 實際來源驗證

- 觀察／格式／錯誤資料／JSON／細時間步站定與離開：42 項，零失敗。
- 實際 Main 物理 WASD：67 條受控首輪流程、621 項，零斷言失敗；涵蓋五打法、八職責、合法改選、合法原地、四個真實錯誤後果及兩條 1/480 秒模擬步進流程。這是受控點名／角色排列，非 67 次真人自然隨機通關；也未證明所有毒色／角色／塔角度的人類組合。
- NPC 100 條四輪真實移動／600 項，零失敗：80 條五社群×首輪八方向×兩毒色（後三輪固定0），另20條混合方向／排列。每條須有16次踩塔、32次Bug／Rot爆炸、實際八人Debugger門檻；這些 headless 場景收據明示 synthetic，非普通畫面或手動來源。
- Main 的80組出生／提示前差分、五打法生成四輪、單幀跨揭示、重試及漏塔已通過；加入 HW 分段來源／成績／可見標示後共 367 項通過。既有 HW 46 項／9 流程、檢知 258 項／72 流程、P3 Main151 及共用20機制回歸通過。
- 原始失敗（經過另一側過早永久鎖定、舊位置被當新指示、細時間步逐幀靜止誤判）與修正前反例均保留；沒有改時間、幾何或判定來讓案例通過。

## 平台與後續工作

新PCK十項受影響回歸、實際Web操作／畫面、公開HTTPS十三種內容表現與全新啟動已通過；Windows原生限定實證及離線包亦已完成。全部20機制／100選項、初始八方／全玩家預處理、最佳化及完整 AVFX 仍未完成。


## Web-first 發布

Runtime/source tag: d8bd203571ba5f97dff92f4aa9d3ab6ba9c4005c. PCK SHA-256: e4a4df2e7d8af7676789c9332aa036b8aeb6a0838146b3778c4dee6fe31c0278.
實際Web經UI設定、D輸入與釋放、13秒前中立／15秒後已繪塔收據、R清除當段未來資訊；停在20秒前，並非完整手動通關。使用VPS Chromium/SwiftShader軟體WebGL2，不宣稱實體GPU。未改動的舊機制矩陣保留v19已驗基線，不假稱全部重跑。
發布與可攜驗證：https://github.com/aki-terminal-leaf/Omega-Protocol-Sim/releases/tag/top-v0.3.20-preview 。文件收尾與runtimecommit分開，不重建已驗匯出。


## Windows 離線增補

同一已驗PCK搭配官方Godot4.7.2 Windows runtime，正常相鄰PCK自動載入（非另一份Windows重匯出）。AnAn正式執行檔完成130秒Elemental HW示範：16次踩塔、32次Bug／Rot爆發、實際八人Debugger；零真實失敗。實際自有1440×900視窗以Elemental／D1／seed17391普通練習，D輸入位移約2.70碼、釋放後不自動移動、13秒前NPC中立／15秒後公開塔收據與配合、R同點名新開流程通過；43份原始報告及7張client圖片重算雜湊，父代理看過實際提示前／後／R畫面，任務視窗已關閉。

這是腳本原生操作與一個GUI族群，不是Windows全攻略真人通關。正式runtime不提供開發腳本CLI，因此Windows外部腳本Main367標為NOT_RUN，Linux同PCK367與Windows正常完整示範／實際視窗證據分開；兩次錯誤測試啟動方式與日誌保留，未改遊戲來製造通過。

[Windows x64 ZIP／Windows校驗／限定驗證](https://github.com/aki-terminal-leaf/Omega-Protocol-Sim/releases/tag/top-v0.3.20-preview)已追加；原四個Web／來源資產與校驗位元組不變。遊戲完整解壓縮後執行EXE，保留相鄰PCK；本體不需要網路，攻略連結需網路。
