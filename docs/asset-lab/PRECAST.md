# 施法準備特效來源接線

**起停／綁定語意仍 OPEN，非完整演出驗收；正常播放預設關閉。**

目前來源快取只包含動作結束段。`extend_precast.py` 另外讀取原始
Action → ActionCastVFX → VFX，使用維護中 VFXEditor 的
[ActionRow.ToVfxPath](https://github.com/0ceal0t/Dalamud-VFXEditor/blob/master/VFXEditor/Select/Tabs/Actions/ActionRow.cs)
規則：`vfx/common/eff/{Location}.avfx`。即使檔名以 `m0513` 等開頭，也不是猜成 monster 目錄。

## 資料界線

- 原始 AVFX、編譯文件與所有引用貼圖逐檔核對 SHA-256；不以其他同名檔案替補。
- 建立全新私有快取，舊檔案僅被引用；不改寫既有快取或發布遊戲媒體。
- 每筆 cue 保留原始事件 index、actor、ability 與表格引用，不因同毫秒／同招式合併。
- `begincast` 時間是暫定取樣原點，不是已證實的 native 啟動時間；根位置也不是已驗證的 native 跟隨模式。
- 不建立假的 C012、host stop、release 或 kill，不將施法時間或檢視範圍當停止指令。
- 零 VFX 表格引用、玩家姿勢缺失、獨立 animation-start VFX 分支分開記錄；不是聲稱該招沒有其他演出。

獨立 animation-start VFX 與 ActionCastVFX 不混用。當前原始資料中另有
34867 → VFX2208 的獨立 start 分支，尚未實作。玩家 LB 仍需其原始姿勢／演出來源。

## 執行及檢查

先由既有 `tools/full_replay/compile_resources.py` 編譯私有 `bundle/raw`，再執行：

```sh
python3 tools/asset_lab/extend_precast.py --data OLD_PRIVATE_CACHE --closure COMPILED_PRIVATE_CLOSURE --sheets ORIGINAL_SHEET_ROWS.json --catalog top/data/asset_lab/catalog.json --out NEW_PRIVATE_CACHE
```

重新對新快取執行 `compile_performances.py`，不可沿用舊來源指紋。
`asset_lab_composite.gd` 的 `provisional_precast_enabled` 預設為 false，正常介面不自動開啟。
只有隔離 source inspection 測試明確開啟；即使畫出幾何，仍會回報
`source_prepare_host_timing_unverified`，`seek()` 不得回報成功驗收。
報告保留暫定根來源、未解析的 mesh binder 數及 partial 標記。

`test_precast.gd` 用實際原始資料檢查預設關閉、明確取樣、非空幾何、倒放一致與關閉後清除。
這些是 headless 數值檢查，不是畫面比對、Windows 執行或 all-96 演出通過。
