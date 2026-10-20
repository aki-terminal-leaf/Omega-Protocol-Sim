# TOP 戰術研究與來源邊界

查核日期：2026-10-21（Asia/Taipei）。原始來源、具體可支持的結論和讀取限制見 [sources.json](sources.json)。

## 方法

先確認既有方案：XIVsim 已有 TOP 部分階段練習；Aether 攻略直接列出 P2/P3/P5/P6 與單人 Bot。使用者明確要求 fork Dragonsong-Sim，所以採用獨立 Godot 離線專案，沒有拷貝 XIVsim 程式或美術。

搜尋使用既有 searxng，英文／中日文多次零結果。**零結果不代表沒有攻略**；後續直接閱讀攻略網站、GitHub guide source、Inven，以及 Bilibili 的公開來源索引。遇到 403／412 不繞過驗證、不使用登入憑證。QQ 宏的文字抽取失敗，但正常公開瀏覽器可畫出內容；Google Sheets 則使用公開 CSV view 核對文字。

## 已核對差異

| 約定 | NA Aether | EU LPDU | JP Elemental |
| --- | --- | --- | --- |
| P1 Loop | light parties；TMR flex；G1 NW/CCW、G2 N/CW | CW M1 M2 MT OT R1 R2 H1 H2 | NW 起 CW H1 MT ST D1 D2 D3 D4 H2 |
| P1 Panto | 飛彈前出；三人後方分攤 | north/south，TMRH | NW/SE，HTDH，飛彈前出 |
| P2 圖形 | BPOG；Remote 右側 GPOB | BPOG full cross | O X triangle square；Remote 只對調 O/square |
| P2 同側雙分攤 | north-most shape + partner 調整 | 已核對 full-cross，完整調整版本依團隊確認 | furthest-from-eye + partner 調整 |
| P3 檢知 | Dylan / conga | RMTHHTMR | Astoh / H1 H2 MT ST D1 D2 D3 D4 |
| P4 | TRHM；最低分攤與對側 melee 調整 | TRHM / melee adjust | TRHM / melee adjust |
| P5 Delta | Saus / blues to beetle | source links separate toolbox | Kinda Awk；另有 GMT 變體 |
| P5 Sigma | 頁面未完整覆蓋 | waymark tower macros | waymark-based towers；HTDH 選 utility |
| P6 | 原頁 WIP，不能據此推定統一配置 | 有 WC1/WC2/meteor raidplan 與南集合 | clock spread、east stack |

**本原型實作的是表格中的部分約定 + 共用示意幾何。** 例如所有 P3 檢知練習目前都採 Astoh 形狀，不是完整 Dylan／LPDU 陣型；P5 不是三套社群戰術切換器。

## 區服／社群覆蓋

伺服器（world）、資料中心（DC）、PF 社群與攻略語言並不是同一個分類。無法從某一個 DC 的公開攻略推論每個 world／固定團都用同一套。

| 區域／社群 | 查核結果 | 可用狀態 |
| --- | --- | --- |
| NA Aether PF | 直接讀取 thepfstrat TOP | 部分約定預設 |
| NA Primal / Crystal / Dynamis | 沒有足以證明統一慣例的直接來源 | 未核對；自訂設定 |
| EU Light / LPDU | 直接讀取 LPDU guide source | 部分約定預設 |
| EU Chaos / 其他社群 | 不能單靠 LPDU 推論全部 PF | 未核對；自訂設定 |
| JP Elemental | Tuufless 全階段與日英宏 | 部分約定預設 |
| JP Mana | Inven 的 09STOP／kiwi 明確說明 Mana-origin；有 Nukemaru clip reference | 來源確認，不等於 Mana 全服標準 |
| JP Gaia / Meteor | 未取得完整可核對區域宏 | 未核對 |
| OCE Materia | 未取得完整可核對區域宏 | 未核對 |
| CN 莫古力攻略組 | Bilibili 上下篇及正常瀏覽器的三頁公開宏；全程 HTDH 優先序、P4 近戰調整、P5 選人可讀 | 優先序預設；完整陣型未實作 |
| CN 莫靈喵 | 明確標示獨立 Delta 打法 | 來源層；未觀看／轉錄全文 |
| CN MM+W／鈺子燒 | 明確標示完整攻略系列 | 來源層；全文未核對 |
| KR 09STOP／Rominny | Inven + 公開 workbook CSV 的 P1/P2/P3/Omega、手動標記／Sigma 宏；P1 H1 T1 T2 D1 D2 D3 D4 H2、P3 HH TT DPS | 優先序預設；不冒稱完整戰術 |
| KR 手動 Omega 標記 | 公開文字給出二層與世界順序選人規則 | 規則已用於 Omega monitor allocator |
| TW／繁體中文社群 | Elemental 官方作者有繁體 quick-reference 連結 | 語言資源；不推定獨立台服慣例 |

## 高滅團風險優先項目

- P1：塔踏錯次序、Blaster 重疊、飛彈炸隊友、三人分攤缺人、坦克未取最遠。
- P2：M/F 姿態判斷、Glitch 長度、同側雙分攤沒調整、擊退進 clone；Beyond Defense 吃到 Pile Pitch。
- P3：紫／白轉場分配；四輪塔／腐毒交接、藍綠同時斷線；檢知朝向與重複命中。
- P4：未離開回波、雙分攤同側、近戰未調整、Wave Repeater 進出時機。
- P5：同色拳、過早斷綠線、檢知與 Pile Pitch；Sigma 六標記分組和擊退塔；Omega 兩組安全點；近遠跳回原主；Dynamis 未湊三層。
- P6：Tank LB 漏按、交叉天箭、地火與六次引導；坦克不在最近／前排；遠敏 LB 動不了時三核爆調整；Magic Number 未在六秒內補 LB。

## 仍需補核對

CN 一圖流／莫靈喵／MM+W 的完整陣型、KR 每一張站位圖、更多 NA/EU/JP/OCE 的團隊約定，以及各變體與遊戲實測尺寸／時序的逐項對照。這些不是「已支援」功能；原型有自訂約定入口，但入口本身不代表已實作所有戰術。

## 新增 CN/KR 優先序預設的邊界

莫古力與 09STOP 的可讀文字均支持 HTDH 優先序，但這不表示其 P2 圖形、P5 全陣型、P6 集合方向與 Elemental 相同。設定中的 `verified_fields` / `training_only_fields` 分開列出，介面選擇時亦顯示「其他欄位為訓練預設」。KR 的 Loop 依原文從北開始順時針；P3 依原文 HH TT DPS 排序。
