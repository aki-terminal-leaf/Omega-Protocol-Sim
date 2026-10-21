# 本機原版素材管線

2026-10-21。這裡的「原版」指從本機已安裝 FFXIV 的 SqPack 唯讀匯出網格、貼圖、骨架與 resident 動畫，**不是照圖片重畫的模型**。未修改遊戲封包、未操作遊戲程序或安裝遊戲外掛。

## 已取得的首領

| 形態 | BNpcBase | ModelChara | Monster / body / variant | 遊戲比例 | 骨架關節 | 常駐動畫 |
| --- | --- | --- | --- | --- | --- | --- |
| Omega | 15708 | 3771 | m0110 / b0001 / v0001 | 0.9 | 118 | 15 |
| Omega-M | 15712 | 3772 | m0513 / b0001 / v0001 | 3.0 | 96 | 6 |
| Omega-F | 15713 | 3773 | m0514 / b0001 / v0001 | 3.0 | 114 | 7 |
| Final Omega | 15717 | 3775 | m0515 / b0001 / v0001 | 1.4 | 170 | 19 |
| Alpha Omega | 15725 | 3524 | m0771 / b0001 / v0001 | 0.8 | 177 | 9 |

來源對應：[BNpcBase.csv](https://github.com/xivapi/ffxiv-datamining/blob/master/csv/en/BNpcBase.csv)、[ModelChara.csv](https://github.com/xivapi/ffxiv-datamining/blob/master/csv/en/ModelChara.csv)。GitHub 的 datamining repository 提供對應資料表，**並不提供完整的 3D 遊戲素材包**。

模型路徑：`chara/monster/mNNNN/obj/body/b0001/model/mNNNNb0001.mdl`；原版骨架與 resident PAP 分別位於該 monster 的 `skeleton/base/b0001/` 與 `animation/a0001/bt_common/resident/monster.pap`。

## 使用既有解析器

- [Lumina 6.7.0](https://github.com/NotAdam/Lumina)：SqPack 唯讀檔案存取與貼圖解碼。
- [xivModdingFramework / TexTools 3.1.1.7](https://github.com/TexTools/xivModdingFramework)：以 raw byte API 解析目前 v6 MDL / MTRL；不初始化遊戲快取、模組或交易。
- [SaintCoinach / Godbert](https://github.com/xivapi/SaintCoinach)：既有 `hkAnimationInterop.dll` 讀取 Havok 骨架／動作，以隔離的 32-bit Python 程序呼叫原有介面。舊 Godbert 的模型解析器不適用這次客戶端；不能因它可讀 SqPack 就宣稱模型匯出成功。
- 本專案的 glue/export 程式為原創；不將上述解析器程式碼併入 Godot 判定引擎，不隨原始碼散布其 DLL 或遊戲素材。

## 可重現操作

準備 Python / Pillow / pythonnet、.NET 8、上述工具的相容發行檔。以同一組 `--game-dir`、`--lumina-dir`、`--textools-dir` 執行：

```text
python tools/export_official_models.py <共用目錄參數> --extract-rigs-only --output <RIG_DIR>
python32 tools/sample_official_animations.py --native-lib <Godbert/hkAnimationInterop.dll> --input <RIG_DIR>
python tools/export_official_models.py <共用目錄參數> --rig-dir <RIG_DIR> --output top/assets/official
```

完整參數見兩支工具的 `--help`。解析器與 32-bit Python 只需放在工作目錄，不需變更系統設定。未提供 rig samples 時可輸出靜態 GLB，但 manifest 與 runtime metadata 會明示靜態，不冒稱原版動作。

輸出 `manifest.json` 記錄每個 GLB、原始 MDL 的 SHA256、模型來源、原始部件 attributes 與動作名稱。`top/assets/official/` 被 Git 排除；保留於本機。Godot 載入原版 pack 後選用原版 `cbbm_id0` 待機動作；未安裝 pack 時明確退回訓練模型。

## 必須區分的精確度

- 網格、來源貼圖、骨架名稱／父子關係與 resident 動作取自原版資料。Havok 動作以 30fps 取樣後輸出 glTF。原生 `getPose` 是模型空間，需轉為父骨相對空間；不可直接寫成 glTF local channels，否則骨架會爆開。已加入實際骨骼位移和形變範圍驗收。
- 材質目前是原版 diffuse / normal 貼圖加 PBR 近似，**不是完整復刻遊戲 characterlegacy shader、colorset、發光或粒子特效**。
- 匯入 resident 動作不等於逐技能 animation / TMB / VFX 全套復刻；M/F 技能姿態、武器部件切換仍須另外對照。
- 隊員可另外從使用者現有 DSR reference pack 唯讀轉出七種已配裝外觀（WAR／WHM／SCH／DRG／SAM／BRD／BLM），保留來源 hash；不是將 DSR 的 controller 或判定程式拷貝進來。這些 preset 的外觀／動畫來源是 DSR pack，不冒稱由本次 datamining 表取得或已逐一證明動畫為原版。未安裝玩家 pack 仍退回程序式隊員。競技場仍是訓練美術。
- 素材識別／骨架測試不證明戰鬥伺服器半徑、server tick、所有戰術或所有遊戲判定正確。判定進度另見 FIDELITY 與 STATEFUL_VALIDATION。

原始遊戲美術權利屬於 SQUARE ENIX，不包含在本專案程式碼授權中。

## 現有玩家外觀的可選轉換

`tools/reuse_local_players.gd` 只轉換使用者既有 DSR pack 的七種配裝 model scenes，移除 scripts，輸出 GLB 與來源 SHA256。不啟動 DSR 主遊戲、不更動原始 pack。需要可讀該 pack 格式的編輯器 binary；這次以獨立目錄的 Godot 4.7.2 完成轉換，當時 TOP 基線為 4.4.1；現已通過獨立升級關卡並鎖定 4.7.2，見升級計畫。以 `--reference-pack=<path>` 與 `--output=<path>` 指定本機來源／輸出。原始角色素材仍不併入公開程式碼。

## 玩家包相容性與驗收

DSR model-only presets 的 MeshInstance3D 保留 Skin / vertex weights，但 skeleton path 為空，由原控制器在執行時綁定。轉換器以最近的 Skeleton3D 補上本機相對路徑，加入場景樹後才匯出；不拷貝控制器。只匯出 Animation 名稱而沒有 skin 的 GLB 不通過驗收。

為保留 4.4 回退包，先前將 4.7 產生、4.4 importer 不支援的 `KHR_node_visibility` 相容化，因此 `tools/prepare_reference_glb.py` 將預設隱藏部件烘焙為不引用 mesh 的節點，同時將玩家貼圖上限降至 512，保留原始 GLB / SHA256。網格、蒙皮、骨架、動畫資料不因貼圖降採樣而重建。角色顯示另用 0.55 比例以配合訓練尺度，不改變判定或移動座標。

`tests/models.gd -- --require-official` 驗證五形態原版 rig 的實際骨骼變動與形變範圍，以及七種配裝角色的真實走跑、停止回待機、直立方向、外觀動畫不改寫遊戲 actor 原點。每次仍須看實際畫面，不把匯出 exit 0 或動畫名稱視為造型正確的證明。

二進位 local-game-models 包可包含本機素材；source ZIP 明確排除 `top/assets/official/`。打包工具不執行任何 GitHub 上傳。未安裝素材的原始碼版本會使用訓練外觀，不能以本機畫面冒稱公開 source 內含官方模型。
