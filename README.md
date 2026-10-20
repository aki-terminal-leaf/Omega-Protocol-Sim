# Omega Protocol — Practice Lab

《FFXIV The Omega Protocol (Ultimate)／絕歐米茄》的 Godot 4 單人走位練習工具，fork 自 [WCGH/Dragonsong-Sim](https://github.com/WCGH/Dragonsong-Sim)。

## v0.2.0

- **先選機制 → 再選該機制的攻略方式 → 單獨練習。** P1–P6 共 20 項；結束後不會播放下一個機制。移除選單中的完整 P5／四世界接續課程。
- **Program Loop 可實際接走連線**：隨機初始持線者、持有者跨輪保留、移動穿線、Blaster 跟隨當下持線者、Looper 消除／過期、Ruin 重複受擊。玩家與 Bot 共用接線碰撞規則，不以到達建議終點代替接線。
- Limitless Synergy 由坦克真正攔截連線；依接到的來源站位。P4 回波、Delta 拳與地火引導讀取真正留下的位置；部分近遠攻擊依實際距離選人。
- 人形角色、分階段 Boss 外型、機械場地、立體塔／連線標記；透視環繞鏡頭、相機相對移動與跟隨。操作參考 DSR。
- 同種子重來、指定分配、教學提示、分段重練、七名 Bot、JSON 操作／接線紀錄。

**仍非全機制完全還原。** 新版改善互動判定，但其餘項目仍有示意實作；碰撞半徑、部分 Debuff 時長與原戰鬥時序尚未逐項實測。Hello World 自由感染／Debugger、P5 線與完整克隆／地火模式仍未完成。請見 [逐項精確度](docs/research/FIDELITY.md)。

![AnAn 實際 Windows 操作畫面](docs/images/practice-lab.webp)

## 下載

[Releases](https://github.com/aki-terminal-leaf/Omega-Protocol-Sim/releases) 提供 Windows、Linux、Web 與原始碼。

- Windows：完整解壓後開 `TOP-Practice-Lab.exe`，`.pck` 留在旁邊。
- Linux：`chmod +x TOP-Practice-Lab.x86_64` 後執行。
- Web：在解壓資料夾執行 `python3 -m http.server 8000`，瀏覽 `http://localhost:8000`。不要直接開 `file://`。
- 從原始碼：以 Godot **4.4.1** 開啟 **`top/project.godot`**，不是根目錄舊 DSR 專案。

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

「示範」由八名 Bot 操作，不計玩家通關。分段開始會重建前置狀態，JSON 標記 `checkpoint_assisted`。無站位提示仍保留文字／AoE 提示，不等同遊戲全部無預警效果。

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
godot --headless --path top --script tests/run.gd
godot --headless --path top --script tests/runtime.gd
godot --headless --path top --script tests/runtime.gd -- --contact-stress
python3 tools/package.py --godot godot
```

建置需官方 4.4.1 export templates。Windows 已在 AnAn 實際操作，不再只以跨平台匯出代表實測。[驗證紀錄](docs/VALIDATION.md)。GitHub OAuth 缺 workflow scope，CI 僅保留 [範本](docs/ci/top.yml)，未啟用 Actions。

架構：`encounters.gd` 產生點名／段落；`interactions.gd` 處理移動中的接線；`rules.gd` 從實際狀態判定；`main.gd` 控制輸入／流程；`arena.gd`／`visuals.gd` 呈現 3D。

## 授權

保留上游 [LICENSE](LICENSE) 及各檔聲明；原 README 見 [README.upstream.md](README.upstream.md)。上游部分程式有 GPL 標頭，未移除或重新授權。新增 TOP 程式為 MIT；字型為 SIL OFL。模型為自行製作的低多邊形訓練表現，未將 DSR PCK 或攻略圖／影片包進發行物。FFXIV 名稱屬各權利人；此為非官方工具。
