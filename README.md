# Omega Protocol — Practice Lab

《FFXIV The Omega Protocol (Ultimate)／絕歐米茄》的 Godot **4.7.2-stable** 單人機制練習工具，fork 自 [WCGH/Dragonsong-Sim](https://github.com/WCGH/Dragonsong-Sim)。

**[下載 v0.3.3-preview](https://github.com/aki-terminal-leaf/Omega-Protocol-Sim/releases/tag/top-v0.3.3-preview)** · [逐機制 Buff／Debuff](docs/research/MECHANIC_STATUSES.md) · [攻略來源](docs/research/STRATEGIES.md)

先選機制，再選這個機制的攻略方式；每次獨立練習，不自動接續其他機制。預設只有遊戲場景、八人狀態及必要的 P6 LB 控制。

## 實際畫面與展示

### Program Loop：真正的數字狀態與獨立手動標記

![v0.3.3 Program Loop 實際匯出畫面](docs/images/top-v033-player.webp)

- 1～4 是原版 In Line Debuff，不是攻略文字；正確踩塔才消除自己的數字與 Looper。
- 正確處理仍會取得的 Ruin、HP Penalty、易傷、Debugger、Dynamis／Spark，依實際事件呈現，不會因「判定通過」就一律清空。
- **17種玩家目標標記**有獨立的頭頂與隊伍欄位；自己上標不改 Boss／LB 目標，也不打斷 LB 讀條。
- 八個場地標記使用原版字形及 A/1紅、B/2黃、C/3藍、D/4紫配色。可選通用、外圈、不顯示或編輯 JSON 座標；近鏡字形淡出以免遮住人物。
- 可見 death wall 與既有半徑20的死亡邊界對齊，不是阻擋人物進入的實體牆。

### P3 檢知波動砲與身位環

![v0.3.3 P3 原版素材充能與實際開炮片段](docs/images/top-v033-p3-effects.gif)

原版左／右充能網格與相關貼圖跟隨實際持有者與面向；光束及命中效果讀取真正判定事件的來源、受擊對象與位置。角色／Boss 腳下的前端箭頭、270°環及後方90°缺口與模型面向同步，不改戰鬥判定半徑。

這段是**實際匯出 WebGL 畫面的俯視、不計分示範錄影**，不是攻略動畫。當前是原版素材重建，**不是完整 AVFX 直接播放器**；attachment、材質與視覺收尾仍有重建部分。[原版來源與精度界線](docs/research/P3_EFFECTS.md)

### 八人 Buff／Debuff

![v0.3.3 P6 實際八人狀態](docs/images/top-v033-statuses.webp)

實際受擊、層數、到期、解除及 Brilliant→Spark 轉換都可在隊伍列觀察。原版封包校準與模擬流程測試分開記錄；詳細效果與未完整模擬的狀態見[逐機制狀態表](docs/research/MECHANIC_STATUSES.md)。

## 下載與開始

發布頁提供 Windows、Linux、Web、source ZIP 與 SHA256 校驗碼；含本機遊戲素材的包標記為 `local-game-models`。既有0.3.2／0.3.1／0.3.0下載保持不變。

- **Windows**：完整解壓，開啟 `TOP-Practice-Lab.exe`，`.pck` 留在旁邊。
- **Linux**：`chmod +x TOP-Practice-Lab.x86_64` 後執行。
- **Web**：在解壓資料夾執行 `python3 -m http.server 8000`，開啟 `http://localhost:8000`；不要直接開 `file://`。
- **原始碼**：以 Godot **4.7.2-stable** 開啟 **`top/project.godot`**，不是根目錄的舊 DSR 專案。公開 source ZIP 不含遊戲素材，缺少時使用訓練外觀。

執行發布包不需要遊戲安裝、帳號、ACT、Dalamud、第三方標記器或網路登入。

## 操作

| 操作 | 按鍵 |
| --- | --- |
| 相機相對移動 | WASD／方向鍵 |
| 自由環繞鏡頭 | 按住左鍵拖曳 |
| 旋轉鏡頭並同步人物方向 | 按住右鍵拖曳 |
| 向鏡頭前進 | 同時按住左右鍵，或按住中鍵 |
| 鏡頭距離 | 滾輪 |
| 轉身 | Q／E |
| 跳躍 | Space／L；不提供地面機制免疫 |
| 疾跑／防擊退／突進 | 1／2／3 |
| 暫停／同種子重來 | P／R |
| 不計分示範重播 | Shift+R |
| LB3／挑釁 | F／V |
| 標記面板／對自己上選定標記 | B／M |
| 自己下一空閒攻擊編號／清自標 | N／Backspace |
| 直接對自己上攻擊1～8 | Ctrl+1～8 |
| 練習工具／暫停設定 | Tab／Esc |

在「場地標記」設定修改配置會保留前次紀錄並重開練習；換標不旋轉機制、Boss 或攻略。目標標記會隨同種子重開清空，分段重練則恢復該段入口的實際快照。文字輸入、暫停與檢討不接受上標修改。

「示範」由八名 Bot 操作，不計玩家通關；可另外開教學提示。一般練習及普通暫停不顯示解法／建議落點。失敗後明確開啟工具才顯示參考處理，重試後隱藏。分段開始重建前置狀態，JSON標記 `checkpoint_assisted`。

## 20 項獨立機制與攻略

| 階段 | 機制 |
| --- | --- |
| P1 | Program Loop、Pantokrator、Cannons |
| P2 | Party Synergy、Limitless Synergy |
| P3 | 轉場、Hello World、Monitors |
| P4 | Blue Screen |
| P5 | Delta、Sigma、Omega、Solar Ray，各自獨立 |
| P6 | Cosmo Memory、Arrow→Dive、Exaflare→Wave、Arrow→Wave、Exaflare→Dive、Meteors、Magic Number |

目前100個可選項目包含 Elemental、Aether、LPDU、莫古力及09STOP的已核對約定與變體；**不是20×5套完整區服時間路徑**，也不把語言或社群當成全服統一打法。未實作的變體不掛名為完整解法。[各機制來源與差異](docs/research/STRATEGIES.md)

Program Loop／Limitless／Omega 透過實際移動交接線，Delta成對線在移動中斷開；Hello World有真正的接觸感染、覆蓋、Debugger、Latent與到期事件。建議落點不代替判定，Dynamis依真正受擊產生。

## 驗證與精度範圍

本輪完成100個現有選項的實際UI狀態覆蓋及300組完整Main流程回歸；另有原始封包對照、實際匯出平台與畫面驗收。[驗證紀錄](docs/VALIDATION.md)

仍未宣稱完整原版逐幀／全區服還原：完整AVFX播放、所有原始生成族群、接觸／同時事件的伺服器規則、部分精確時程、完整HP／職業減傷／復活／自然LB量表，以及部分區服路線仍有未校準項目。場地特殊shader／霧效也不是原引擎完整重現。[逐項FIDELITY](docs/research/FIDELITY.md)

手動標記基礎可使用；逐攻略的完整Bot上標規則／多模式仍是後續工作，不以靜態標記顯示冒稱已完成。[標記實作範圍](docs/development/MARKERS_PLAN.md)

## 開發

```sh
godot --headless --path top --editor --import --quit
godot --headless --path top --script tests/runtime.gd
godot --headless --path top --script tests/status_lifecycle.gd
godot --headless --path top --script tests/status_coverage.gd
godot --headless --path top --script tests/markers.gd
godot --headless --path top --script tests/facing_ring.gd
godot --headless --path top --script tests/p3_effects.gd
python3 tools/package.py --godot godot
```

建置需要完全同版的4.7.2官方export templates；非執行緒Web需 `web_nothreads_debug.zip`／`web_nothreads_release.zip`。Godot與隨附GDScript一起鎖版，不使用未驗證的nightly API。[引擎升級](docs/development/GODOT_UPGRADE_PLAN.md) · [分段提交／執行監督](docs/development/SUPERVISION.md)

## 授權與歷史

保留上游[LICENSE](LICENSE)及各檔聲明；舊README見[README.upstream.md](README.upstream.md)。上游部分程式有GPL標頭，未移除或重新授權；新增TOP程式為MIT，字型為SIL OFL。可選遊戲素材不屬於MIT程式碼授權；source ZIP排除遊戲素材，未把整個DSR PCK或攻略影片包入發布。FFXIV名稱屬各權利人；此為非官方工具。

歷史發布：[0.3.2](https://github.com/aki-terminal-leaf/Omega-Protocol-Sim/releases/tag/top-v0.3.2-preview) · [0.3.1](https://github.com/aki-terminal-leaf/Omega-Protocol-Sim/releases/tag/top-v0.3.1-preview) · [0.3.0](https://github.com/aki-terminal-leaf/Omega-Protocol-Sim/releases/tag/top-v0.3.0-preview)
