# Omega Protocol — Practice Lab

## v0.3.2-preview 候選版

- 練習預設只有遊戲場景、八人 Buff／Debuff 與必要的 LB 控制。
- **Tab** 顯示／隱藏練習工具；**Esc** 暫停並返回設定。重開／返回練習會收起工具。
- 本機遊戲素材包新增各階段原版場景模型、地板、貼圖及配置；特殊光效、霧效仍未完整復刻。
- 只使用 headless 驗收；既有 0.3.1 與 0.3.0 不會被改寫。


《FFXIV The Omega Protocol (Ultimate)／絕歐米茄》的 Godot 4 單人走位練習工具，fork 自 [WCGH/Dragonsong-Sim](https://github.com/WCGH/Dragonsong-Sim)。

## v0.3.1-preview（已發佈，後續持續開發）

- **先選機制 → 再選此機制的攻略 → 單獨練習。** 保持 P1–P6 共 20 項，結束後不連播。完整 P5 僅是內部驗收 fixture。
- Program Loop／Limitless／Omega 使用實際移動接線與當下 owner；Delta 的成對線在移動中斷開，不混成可轉移的 Boss 線。
- Hello World 加入自由感染、覆蓋、Debugger、Latent、到期爆炸與提前斷線；判定不以建議落點代替實際狀態。
- 分開 Aether／LPDU 檢知陣型；六手臂六發鎖定旋轉、十四發 Sigma 雷射與持續移動的地火。
- 本機素材包可載入 **12 種原版首領／部件網格、貼圖、骨架／動作**，以及既有 DSR 的 **7 種配裝角色**，以實際位移切換走跑。公開原始碼不包含遊戲素材，未安裝時使用訓練外觀。[來源與轉換](docs/research/OFFICIAL_ASSETS.md)
- DSR 式操作、同種子／分段重來、七名 Bot；JSON 保存實際事件、感染、受擊者、參數、攻略定義及重試歷史。

**尚未完成所有區服／全部原始判定。** 接線半徑、部分時長、所有原始克隆／地火起點、完整區服路線與 HP／減傷／死亡後行為仍有未完成項目。這是可操作的開發預覽，不把社群參數或自動測試當成實戰校準。[逐項範圍](docs/research/FIDELITY.md)

## 下載

[v0.3.1-preview 下載](https://github.com/aki-terminal-leaf/Omega-Protocol-Sim/releases/tag/top-v0.3.1-preview) 提供 Windows、Linux、Web、原始碼與 SHA256 校驗碼，固定來源 `be97a09`。本開發分支另有發佈後的增量，不會改寫既有版本。含本機遊戲素材的包標記為 `local-game-models`，不等同公開 source ZIP 內附素材。

- Windows：完整解壓後開 `TOP-Practice-Lab.exe`，`.pck` 留在旁邊。
- Linux：`chmod +x TOP-Practice-Lab.x86_64` 後執行。
- Web：在解壓資料夾執行 `python3 -m http.server 8000`，瀏覽 `http://localhost:8000`。不要直接開 `file://`。
- 從原始碼：以 Godot **4.7.2-stable** 開啟 **`top/project.godot`**，不是根目錄舊 DSR 專案。

Godot／GDScript 已升級並鎖定 **4.7.2-stable**；隔離匯入、機制回歸、原版素材與 Windows／Web 操作關卡已通過。後續開發只使用此版本文件與實際執行已證明支援的功能；不將候選語法當成已驗證能力。[升級計畫](docs/development/GODOT_UPGRADE_PLAN.md) · [分段提交與執行監督](docs/development/SUPERVISION.md)

不需要遊戲安裝、帳號、ACT、Dalamud、第三方標記器或網路登入。

## 操作（比照 DSR）

| 操作 | 按鍵 |
| --- | --- |
| 相機相對移動 | WASD／方向鍵 |
| 自由環繞鏡頭 | 按住左鍵拖曳 |
| 鏡頭旋轉並同步角色方向 | 按住右鍵拖曳 |
| 向鏡頭前方前進 | 同時按住左右鍵，或按住中鍵 |
| 相機距離 | 滾輪 |
| 跳躍 | Space／L；跳躍不提供地面機制免疫 |
| 疾跑／防擊退／突進 | 1／2／3 |
| 本工具額外訓練控制 | P 暫停、R 同種子重來、Q/E 轉身、F LB3、V 挑釁 |

先選機制及解法，再按「只練習選定機制」。點選另一個機制會要求重新選擇攻略；不沿用全域區服選項。每個機制只列出實際支援的約定，未實作的區服變體不會掛名為完整解法。

「示範」由八名 Bot 操作，不計玩家通關。分段開始會重建前置狀態，JSON 標記 `checkpoint_assisted`。

v0.3.1 已改為玩家跟隨鏡頭與全畫面練習，左側隊伍列顯示八人的實際 Buff／Debuff、層數與倒數；未知圖示保留名稱說明。一般練習不顯示解法文字或建議落點，普通暫停也不揭曉；失敗檢討才列參考處理方式，重試後再隱藏。教學提示僅供不計成績的示範使用。AoE 仍有訓練示意，不等同原作所有無預警效果。[呈現與狀態範圍](docs/development/PARTY_STATUSES.md)

v0.3.1 的 Windows／Linux 無畫面流程、headless Chrome 操作與失敗／重試提示關卡已通過，五個發布檔案的大小與雜湊均已核對。依使用者要求，本輪不進行桌面操作，也不宣稱新版原生視窗人工驗收。既有 `v0.3.0-preview` 下載保持不變。[本次驗證範圍](docs/VALIDATION.md#published-v031-preview-headless-only-2026-10-21)

## 機制

- P1：Program Loop、Pantokrator、Diffuse Wave Cannon Kyrios。
- P2：Party Synergy、Limitless Synergy。
- P3：轉場、Hello World、檢知。
- P4：Blue Screen。
- P5：Delta、Sigma、Omega、Solar Ray，各自獨立。
- P6：Cosmo Memory、Arrow→Dive、Exaflare→Wave、Arrow→Wave、Exaflare→Dive、Meteors、Magic Number。

Elemental、Aether、LPDU、莫古力與 09STOP 的**部分優先序／約定**已核對；不是完整五套區服打法。[攻略研究](docs/research/STRATEGIES.md) · [素材與操作參考](docs/research/VISUAL_REFERENCE.md)

## 開發與驗證

```sh
godot --headless --path top --editor --import --quit
godot --headless --path top --script tests/rules.gd
godot --headless --path top --script tests/interactions.gd
godot --headless --path top --script tests/stateful.gd
godot --headless --path top --script tests/review.gd
godot --headless --path top --script tests/run.gd
godot --headless --path top --script tests/runtime.gd
godot --headless --path top --script tests/runtime.gd -- --contact-stress
godot --headless --path top --script tests/models.gd -- --require-official
python3 tools/package.py --godot godot
```

建置需與引擎完全同版的官方 **4.7.2** export templates；非執行緒 Web 需 `web_nothreads_debug.zip`／`web_nothreads_release.zip`。v0.2 已在 AnAn 實際操作；v0.3 的精確驗收紀錄另列，不能沿用舊版結果冒稱新版已測。[驗證紀錄](docs/VALIDATION.md)。GitHub OAuth 缺 workflow scope，CI 僅保留 [範本](docs/ci/top.yml)，未啟用 Actions。

架構：`encounters.gd` 產生點名／段落；`interactions.gd` 處理移動中的接線；`statuses.gd` 保存感染／到期／成對線與地火狀態；`rules.gd` 從實際狀態判定；`main.gd` 控制輸入／流程；`arena.gd`／`visuals.gd` 呈現 3D。

## 授權

保留上游 [LICENSE](LICENSE) 及各檔聲明；原 README 見 [README.upstream.md](README.upstream.md)。上游部分程式有 GPL 標頭，未移除或重新授權。新增 TOP 程式為 MIT；字型為 SIL OFL。程序式 fallback 為自行製作；可選本機遊戲素材不屬於 MIT 程式碼授權。未將整個 DSR PCK 或攻略圖／影片包進發行物，source ZIP 排除遊戲素材。FFXIV 名稱屬各權利人；此為非官方工具。

### Pure practice view

Practice opens with only the game scene and eight-member Buff/Debuff list
(plus necessary P6 LB target controls). **Tab** opens/closes training tools;
**Esc** opens paused settings. Starting/retrying/resuming restores the clean view.
Reference solutions are available only after actual failure and an explicit
training-tools toggle; ordinary play/pause does not expose them.
