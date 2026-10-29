# 原始掛點與隱藏目標骨架

**來源數值子集通過，不代表原片玩家姿勢或 96 項演出驗收。**

隱藏玩家目標直接使用原始人形骨架的參考姿勢與 EID，不依賴裝備角色 GLB 的縮放、缺失節點或皮膚。現有 c0101 原始骨架含 106 節點；50 個 EID 在 8 個匿名目標、40 個含倒放的取樣上，共 2000 組世界矩陣通過獨立 Python 層級／EID／戰鬥座標 oracle。保留原始微小骨架縮放，額外倍率為 1。

第一版角色 GLB 缺少 `n_hara_noanim_trans`，根節點亦不是蒙皮骨骼，造成的失敗紀錄保留。已從原始 SKLB 取回精確參考變換，改由完整原始骨架計算；一般 NPC 的未蒙皮祖先節點亦可依實際場景節點解析。

這些目標不繪製人物。每個掛點都保留來源家族、原始骨架 SHA-256、參考姿勢及戰鬥座標時刻；錄製玩家的種族、身高與當時動作未記錄，明確保留 unknown，不能冒充那名玩家的精確骨架演出。

## 私人來源合併

```sh
python3 tools/asset_lab/compile_attachments.py --eid ORIGINAL_EID_JSON --skeleton-manifest ORIGINAL_SKELETON_MANIFEST --references ORIGINAL_REFERENCE_JSON_DIRECTORY --out FRESH_CACHE/attachment-data.json
```

原始媒體／參考骨架不提交 Git。EID 與原始 SKLB 來源 SHA 必須保留；生成檔要求新路徑。

## Host 與更新語義

目前 1217 個來源 C012 cue 的 host 都是 caster/character/-1 與 target/character/-1；其他組合拒絕，不自動改成 caster。

AVFX 的 `CoUF` 是 Coordinate Update Frame，實際資料有 -1、0、1、60、400 等值；欄位標籤不足以證明原生更新行為。舊的 `CoUF == 1` 布林凍結推測已移除，非預設更新值保留未支援並拒絕，不默認為持續追蹤。延遲／環形 binder、DamageCircle、原始 binder 變形與 host 停止條件仍須各自驗證。
