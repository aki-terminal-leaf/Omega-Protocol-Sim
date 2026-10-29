# TOP Asset Lab — Godot

逐項拆解 TOP 的模型、材質、原始骨架動作與 AVFX 子集。介面有「分項複合演出」與「原始資源檢視」，支援播放、暫停、重播、時間滑桿、0.25–2x、旋轉及縮放。**來源接線與檢視工具不是所有項目已完整還原的聲明。**

依照 2026-10-28 新指示，後續開發只使用 **Godot 4.7.2**，不再使用 Unity。Unity 歷史成果保留，不啟動、不續跑；既有 Godot 練習版及 Web 站點未被此實驗室取代。

- [96 項逐項狀態與樣本來源](CATALOG.md)
- [原始盤點快照](INVENTORY.md)
- [機器可讀目錄](../../top/data/asset_lab/catalog.json)
- [驗證與限制](VALIDATION.md)
- [分項複合播放與來源界線](COMPOSITE.md)

## 執行與建置

需 Godot 4.7.2 與 Python 3。原始遊戲媒體及戰鬥資料不存入 Git。供應具有 `manifest.json`、`record.json`、`motion-plan.json`、`full-data.json`、`weapon-data.json` 與 `assets/` 的既有 GLB/PNG/AVFX 私人來源快取；這是資料格式，不依賴 Unity 或任何 Unity 程式。

```sh
python3 tools/asset_lab/build_catalog.py --data PRIVATE_SOURCE_CACHE --out NEW_LAB_DATA
python3 tools/asset_lab/stage.py --out NEW_STANDALONE_PROJECT
godot --headless --path NEW_STANDALONE_PROJECT --editor --import --quit
python3 tools/asset_lab/compile_performances.py --data PRIVATE_SOURCE_CACHE --attachments ORIGINAL_ATTACHMENTS.json --out NEW_PERFORMANCES.json
godot --path NEW_STANDALONE_PROJECT -- --asset-root=NEW_LAB_DATA --source-root=PRIVATE_SOURCE_CACHE --performances=NEW_PERFORMANCES.json --attachment-data=ORIGINAL_ATTACHMENTS.json
```

此工具使用 Godot 官方 GLTFDocument 載入模型、現有專案的 AVFX 解析器和來源曲線子集。獨立 staging 不修改練習版 main scene。Windows 可使用官方匯出範本跨平台匯出：

```sh
godot --headless --path NEW_STANDALONE_PROJECT --export-release Windows OUTPUT/TOPAssetLab.exe
```

將私人 `NEW_LAB_DATA` 放在執行檔旁並命名 `LabData`，或用 `-- --asset-root=PATH` 指定；複合播放另外需要完整 `--source-root`、相符的 `--performances` 及原始 `--attachment-data`。只有樣本快取時，可選「原始資源檢視」。缺少資料會顯示載入問題，不會偷偷改用假模型。

## 驗證

```sh
python3 tools/asset_lab/compile_performances.py --data PRIVATE_SOURCE_CACHE --attachments ORIGINAL_ATTACHMENTS.json --out NEW_PERFORMANCES.json
godot --path NEW_STANDALONE_PROJECT -- --asset-root=NEW_LAB_DATA --source-root=PRIVATE_SOURCE_CACHE --performances=NEW_PERFORMANCES.json --attachment-data=ORIGINAL_ATTACHMENTS.json --lab-qa=NEW_EVIDENCE --qa-render=1
python3 tools/asset_lab/verify_motion.py --data NEW_LAB_DATA --states NEW_EVIDENCE/states.json --out NEW_MOTION_PROOF.json
```

骨架 oracle 另需 NumPy／SciPy。QA 不自動證明原版視覺等價性。不得因為項目存在、成功解析、有粒子或有截圖，就宣稱完整還原。來源 shader、host stop、場景交互、音訊、頭標／玩家 LB 及過場缺件逐項保留；原片與事件紀錄非同一場。
