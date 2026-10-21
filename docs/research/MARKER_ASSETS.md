# 標記原版素材蒐集與外觀對照

2026-10-22；需求：Telegram48716。**僅蒐集與對照，沒有實作標記功能、替換執行中素材或發布新版。**
機器可讀索引：[MARKER_ASSETS.json](MARKER_ASSETS.json)。功能範圍另見 [標記規劃](../development/MARKERS_PLAN.md)。

## 已實際取得

- **17 種目標標記的原版 UI 圖示**：攻擊 1–8、鎖鏈 1–3、止步／Ignore 1–2、正方形、圓形、加號／Plus、三角形。
- **八個場地標記 A–D、1–4**：選單 UI 與地圖用圖示；另有「清除場地標記」圖示。
- 上述共 34 個圖示，各有原尺寸與 `_hr1` 高解析版本，**共 68 張 PNG**；保留每張原始 TEX。
- **八組原版場地 AVFX**，以及它們引用的 **15 張不重複 ATEX 貼圖**：八個字形、圓環／方框、光暈、遮罩、扭曲等。
  原始 AVFX、ATEX 與解碼 PNG 都保留；特效圖不是網頁截圖重畫。
- 八組 AVFX、68 組圖示來源／PNG、15 組貼圖來源／PNG，共 91 個素材項目已核對 SHA256；所有 PNG 實際解碼、尺寸吻合，缺失 0。
- 原版 UI 總覽與場地紋理總覽已產出並檢視。這是來源素材檢視，**不是遊戲內實拍或 Godot 最終渲染驗收**。

## 現有 TOP／DSR 與原版的差距

| 層級 | 目前 TOP／DSR 狀況 | 原版素材與後續取用 |
| --- | --- | --- |
| 場地字形 | TOP 是平放 Label3D；非原版字形。 | 用 `a_base`、`b_col00f`、`c_col00f`、`d_new`、`1_base0f` 至 `4_base0f`，不再拿普通字型替代。 |
| 場地顏色 | TOP 的字色配對與原版不一致；圓環全為同一訓練色。 | 原版字形為 A／1 紅、B／2 黃、C／3 藍、D／4 紫；實際光柱色彩與混色仍要看 AVFX，不以字色代替。 |
| 地面底座／光柱 | TOP 現為統一圓環；DSR 的程序式柱體也不能視為原版粒子。 | 保存來源中的圓環、方框、光暈、遮罩與八組 AVFX；後續分層重建形狀、發光、透明與動態。 |
| 目標標記全集 | DSR 資源為 12 種，缺攻擊 5–8、鎖鏈 3。TOP 尚無可操作的玩家標記。 | 索引已補齊現行資料表的 17 種，按 Icon ID 取原版圖；不從 Status ID 推算圖示 ID。 |
| 四圖形 | 玩家目標標記不是機制強制的 PlayStation 點名。 | Marker 表的第四組為 Square／Circle／**Plus**／Triangle；不要把 Plus 默畫成機制的 ×。`cross` 巨集別名／操作語義另行驗證。 |
| UI 與頭頂 | 選單圖示不等於世界空間頭頂特效。 | 已取得的是 17 種 UI 原圖；目標標記頭頂的獨立原版特效來源**仍未定位**，不能宣稱已完整取得或用縮放 UI 冒充。 |
| Buff／Debuff | 既有隊伍狀態已用本機原版 PNG，維持與玩家標記分離。 | 本輪不重畫、不改變狀態時機；未知來源／未映射項目仍需按實際 Status 表逐項核對。 |

## 場地特效來源對照

| 標記 | FieldMarker row | UI icon | Map icon | VFX row | 原版 AVFX basename |
| --- | ---: | ---: | ---: | ---: | --- |
| A | 1 | 61241 | 60474 | 302 | `fld_mark_a0f.avfx` |
| B | 2 | 61242 | 60475 | 303 | `fld_mark_b0f.avfx` |
| C | 3 | 61243 | 60476 | 304 | `fld_mark_c0f.avfx` |
| D | 4 | 61247 | 60936 | 519 | `fld_mark_d0f.avfx` |
| 1 | 5 | 61244 | 60931 | 489 | `fld_mark_10f.avfx` |
| 2 | 6 | 61245 | 60932 | 490 | `fld_mark_20f.avfx` |
| 3 | 7 | 61246 | 60933 | 491 | `fld_mark_30f.avfx` |
| 4 | 8 | 61248 | 63904 | 861 | `fld_mark_40f.avfx` |

全部位於 `vfx/common/eff/`。紋理依 AVFX 內的實際引用讀取，而不是猜測名字。
圖示原路徑為 `ui/icon/NNN000/NNNNNN.tex`；高解析檔加 `_hr1`。
完整原路徑、原始檔與匯出檔雜湊、PNG 尺寸均在 JSON 索引。

## 來源與重現範圍

- 素材直接唯讀匯出自已安裝的 FFXIV SqPack；客戶端版本 **2026.10.16.0000.0000**。
- 沿用已有的 [Lumina](https://github.com/NotAdam/Lumina)／本機原版素材管線及 Pillow 解碼，未安裝新插件、啟動遊戲、操作桌面或改寫遊戲檔。
- 名稱／Icon ID／FieldMarker → VFX 對應採用固定版本 [ffxiv-datamining `44948e4cda58`](https://github.com/xivapi/ffxiv-datamining/tree/44948e4cda5846eab0baa9872122a888fcc4f1b1/csv/en)：[Marker.csv](https://raw.githubusercontent.com/xivapi/ffxiv-datamining/44948e4cda5846eab0baa9872122a888fcc4f1b1/csv/en/Marker.csv)、[FieldMarker.csv](https://raw.githubusercontent.com/xivapi/ffxiv-datamining/44948e4cda5846eab0baa9872122a888fcc4f1b1/csv/en/FieldMarker.csv)、[VFX.csv](https://raw.githubusercontent.com/xivapi/ffxiv-datamining/44948e4cda5846eab0baa9872122a888fcc4f1b1/csv/en/VFX.csv)。
  公開資料表的版本與本機客戶端分別記錄，不宣稱逐列讀取並比對了本機 EXD。
- 原始遊戲素材、預覽 PNG、匯出／候選查找腳本與完整證據放在本機蒐集資料夾；公開 Git 只同步研究文件與文字索引。素材權利屬於 SQUARE ENIX，不併入本專案程式碼授權。
- 本輪封存的主要素材 ZIP 約 **1.28 MiB**；沒有下載整套遊戲包或重建三平台套件。

## 尚待查證，不能當作已完成

1. 角色頭頂玩家標記的獨立原版圖／AVFX。目前依 DSR 名稱查找 common／lockon ATEX、TEX、AVFX 的候選未命中；這只排除了所查候選，不代表遊戲沒有相應資源。
   額外讀到的 `NamePlate.tex` 不是已確認的目標標記，不納入選用素材包。
2. 場地光柱、底座、發光、透明混色、字形浮動等 AVFX 最終重建，以及近／遠鏡頭下的高度、尺寸與遮擋對照。
3. 素材接入後的功能、玩家自行上標、狀態共存及 Windows／Web headless 畫面驗收；**本輪均未進行**。

下一個實作階段可直接使用上述原版場地字形與 UI 素材，不需要先重畫；先補足頭頂來源或明示近似，再進行獨立驗收。
