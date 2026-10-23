# Hello World 首輪公開資訊、NPC 預處理及玩家配合（v0.3.20 來源候選）

固定站目前仍為 v0.3.19。此增量只修首輪塔揭示與實際玩家選側的 NPC 行動；新包／Web／原生驗收待完成，不等於全部攻略符合。

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

## 待完成

新 PCK 的受影響回歸、實際 Web 操作／畫面、公開 HTTPS 與新啟動、Windows 原生及離線包另行驗收。全部20機制／100選項、初始八方／全玩家預處理、最佳化及完整 AVFX 仍未完成。
