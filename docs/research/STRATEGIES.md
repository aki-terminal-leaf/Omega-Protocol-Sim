# TOP 戰術研究與目前實作範圍

2026-10-21，v0.3.0-preview 已發佈。這是目前狀態；較早的
[100格研究底稿](REGIONAL_ROUTE_AUDIT.md) 以55bbc64為基礎，不是目前選單或實作狀態。
實際可選內容以 [mechanic_strategies.json](../../top/data/mechanic_strategies.json)
為準：**20個獨立機制、100個現有選項**。內部P5連續5組不計入選單。發佈後另將已存在且驗證的P6局部分流開放為14個明示「部分來源」選項；不是補上14套完整原版區服時間路徑。已發佈0e7版本仍為86選項。
100為包含變體的選項數，**不等於20×5完整區服矩陣**：Solar Ray仍只有共用1項，Panto／Cannons／檢知則有額外變體。
測試通過表示該模型中的路線可執行，不代表全區服／所有原始出現族群已驗證。

## 已實作的區別，不再沿用舊版單一路線敘述

| 機制 | 選項數 | 目前可支持的內容／來源 |
| --- | ---: | --- |
| Program Loop | 5 | Elemental NW/CW、Aether小隊TMR補位、LPDU優先序、KR正北CW、CN正北A/CW；[P1](P1_FIDELITY.md) |
| Pantokrator | 6 | 五社群起始安全區／補位，CN內出外回與外出內回分列；[P1](P1_FIDELITY.md) |
| P1 Cannons | 7 | 固定散開、Aether動態炮標與備選、LPDU分坦備選、CN/KR遠程側分工；不含完整職業減傷 |
| Party Synergy | 5 | 圖形次序、Remote全交叉與外側交換、南／北端補位分開；只涵蓋明示clone族群 |
| Limitless | 5 | 各自誘導方向、接線分側、南北箭分支；[逐項查核](P2_LIMITLESS_FIDELITY.md) |
| P3轉場 | 5 | 各自主來源分配、八次波動、六手臂與狙擊；[來源／時序](P3_TRANSITION_FIDELITY.md) |
| Hello World | 5 | 四輪實際感染／Debugger、原毒處理與最後內外分流；[HW](HW_FIDELITY.md) |
| P3 Monitors | 6 | Astoh、Aether第三檢知南、LPDU第一檢知北、CN固定左／鏡像、KR排序；不是全部共用Astoh |
| Blue Screen | 5 | 各自主來源TRHM調整，實際方向快照／回波與三輪連續事件；[P4](P4_WAVE_FIDELITY.md) |
| Delta | 5 | 內／外換拳、Defense與World分工、實際成對線；[Delta](DELTA_FIDELITY.md) |
| Sigma | 5 | 圖形、塔宏／CN目視雙塔、旋轉雷射與World分工；[Sigma](SIGMA_FIDELITY.md) |
| Omega | 5 | 兩次克隆判定、各自World幾何與檢知選人、三層實際接線；[Omega](OMEGA_FIDELITY.md) |
| Solar Ray | 1 | 共用雙坦換仇恨，不掛名五套完整減傷方案 |
| Cosmo Memory | 5 | 實際坦LB／Brilliant與明示獨立前置；[P6 LB](P6_LB_FIDELITY.md) |
| Arrow→Dive | 5 | 已有的西南／LPDU東南與坦克分流；數值天箭路線仍為練習解 |
| Exaflare→Wave | 5 | 各自時鐘、東／南集合及已知離場角；LPDU未知角度明示採45°練習路線；CN依使用者補充改相對67.5°離場方向，初始中心誘導仍未改成間隙起跑 |
| Arrow→Wave | 5 | 各自時鐘／LPDU四象限配對、東／南集合；KR配對仍是明示推導，非完整原圖 |
| Exaflare→Dive | 5 | 已存在的離場角與最近雙坦／最遠六人；未知區服離場角仍明示為練習值 |
| Meteors | 5 | 各自初始配置、實際LB／HP與期限；[精度界線](P6_PRECISION.md) |
| Magic Number | 5 | 兩輪實際坦／補LB、Doom與動作鎖；[P6](P6_FIDELITY.md) |

## 已取得的原始來源與不能外推的部分

- Elemental：Tuufless全階段與日英宏；不推定JP所有DC相同。
- Aether：thepfstrat與其連結Toolbox；Dylan、Saus的具體分支已反映於上述模組，不是換標籤共用原版幾何。不能據此宣稱Primal／Crystal／Dynamis統一。
- LPDU：原始markdown、Toolbox、P6 raidplan；分配與部分路徑具體可支持，不推定Chaos全部團隊相同。
- CN莫古力：原版一圖流**全15個重疊區塊已讀完**，World圖示亦由本機原版效果ID核對；[逐圖紀錄](CN_POSTER_AUDIT.md)。Limitless原影片第2段14:30–22:30已查核；這不是上下兩部影片全部分支已逐幀看完的宣告。其他CN攻略組不自動套用莫古力。
- KR09STOP：公開workbook、Inven與實際選取圖例；P1/P2、部分P3/P5/P6分工有獨立來源。不把Mana-origin或一份宏當作KR／JP全服標準；尚未逐一核對每個動畫frame。

一般搜尋使用既有searxng；搜尋零結果不代表來源不存在。查核透過公開原始網站、GitHub guide source、正常公開瀏覽器與已取得圖例；未繞過403／412、登入／CAPTCHA。原圖與影片不收入公開原始碼。

## 保留的精確度缺口

完整區服時間路徑、未見過的原始spawn、接線／感染接觸門檻與同時事件政策、NPC邊緣／射程寬限、完整核爆傷害／減傷曲線及大隕石原版期限仍未全數校準。
P6遠敏LB的**全寬8／半寬4已修正並有來源解讀支持**，不是仍不知道寬度；NPC邊緣與射程寬限是另兩項未驗證問題，見 [幾何來源](P6_RANGED_GEOMETRY.md)。

目前只在有具體來源與實作時列選項；不以補滿100格或複製社群名稱冒稱完整。
完整狀態以 [FIDELITY](FIDELITY.md)、各機制專題與 [VALIDATION](../VALIDATION.md) 為準；引擎／匯出驗收與戰鬥來源不互相替代。

## v0.3.3 regression checkpoint

All100 currently offered methods were audited through actual UI status rows at
seed17391. All300 Main courses at seeds17391/7/43 pass after fixing the physical
Aether Omega43 coincident-ray handoff. This expands executed model coverage;
it does not turn the explicitly partial regional source/temporal evidence above
into exhaustive original-strategy certification. Actual attack/status packet
calibration and remaining status scope are listed in
[MECHANIC_STATUSES](MECHANIC_STATUSES.md).
