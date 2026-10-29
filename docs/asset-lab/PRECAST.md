# 施法準備特效來源接線

**起停／綁定語意仍 OPEN，非完整演出驗收；正常播放預設關閉。**

原始基礎快取包含動作結束段。`extend_precast.py` 另外讀取原始
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
34867 → ActionCastTimeline138 → VFX2208 的獨立 start 分支。
`extend_start_vfx.py` 已實作此分支的來源閉包與事件所有權追蹤；這不代表
當前私有輸入已通過閉包驗收，也不代表 native／玩家演出可用。
原始事件 43253 的 source 為 `7:0`（Pictomancer/player），路徑為
`vfx/common/eff/lbk_rpm_lv3_c0c.avfx`。原始 start timeline 11796
另存為 `original_start_timeline_id`，不是 native 啟動證明。

新分支保留玩家依賴，即使 motion-plan 沒有其姿勢；不替換成 NPC，
不修改既有 `full-data.cues`。`animation-start-proof.json` 的 `dependencies`
與 `full-data.animation_start_dependencies` 相同，每筆保留原始事件 index、
actor、Action、ActionCastTimeline、VFX、AVFX SHA256；timing、host stop、pose
均為 `UNKNOWN`。零 start-VFX 引用另列，不推論為整招沒有演出。
`all96_accepted` 與 `rendering_complete` 永遠為 false。

原始 AVFX 與原始 `.atex` 位元組、PNG hash、compiled pack 的 source hash
及安全相對路徑必須先驗證，才建立新快取。編譯 JSON 輸出另記 SHA256，
其來源 `packs.json` 亦有 source pin；此為資料完整性驗證，不是編譯語意或視覺驗收。
新資產包含原始與編譯內容，使用獨立檔案複製，不要求 Windows symlink 權限。
原始貼圖必須位於 closure 的 `bundle/raw/{texture.source}`；
只有 `textures.json.raw_sha256` 宣告不算已驗證原始貼圖。

## 執行及檢查

先由既有 `tools/full_replay/compile_resources.py` 編譯私有 `bundle/raw`，再執行：

```sh
python3 tools/asset_lab/extend_precast.py --data OLD_PRIVATE_CACHE --closure COMPILED_PRIVATE_CLOSURE --sheets ORIGINAL_SHEET_ROWS.json --catalog top/data/asset_lab/catalog.json --out NEW_PRIVATE_CACHE
```

獨立 animation-start 依賴階段（Windows 明確使用 UTF-8）：

```sh
python -X utf8 tools/asset_lab/extend_start_vfx.py --data OLD_PRIVATE_CACHE --closure COMPILED_PRIVATE_CLOSURE --sheets ORIGINAL_SHEET_ROWS.json --catalog top/data/asset_lab/catalog.json --out NEW_PRIVATE_CACHE
python -X utf8 tools/asset_lab/test_start_vfx.py -v
```

### 2026-10-29 scoped source 驗證紀錄

- PASS：10 個 synthetic Python 測試，涵蓋玩家缺姿勢仍保留來源、不合併不同事件、
  零引用、缺 actor、缺原始貼圖、原始 AVFX／貼圖／PNG／pack source hash 竄改、Windows 路徑別名。
- BLOCKED：指定唯讀父層驗收已執行，尚未通過；輸入
  `D:/Dev/OpenClawCodexBridge/probes/start-vfx-50685/bundle` 有 12 張 PNG
  及其原始 hash 宣告，但缺少 12 張原始 `.atex` 位元組。
  首個失敗紀錄（exit 1，輸出建立前）：

  ```text
  python -X utf8 D:/Dev/OpenClawCodexBridge/probes/resume-50685-start-vfx-acceptance.py
  FileNotFoundError: D:/Dev/OpenClawCodexBridge/probes/start-vfx-50685/bundle/raw/vfx/common/texture/glow607ac.atex
  ```

  尚未產生此實際輸入的成功 proof；須提供完整原始貼圖來源再驗收。
- 工具限制：`python -X utf8 tools/work_guard.py begin start-vfx-source`
  在 Windows 回報 `ModuleNotFoundError: No module named 'fcntl'`；未改寫 guard。
  Python 測試改以 subprocess 60 秒硬逾時，父層驗收為 120 秒硬逾時，均已取得 terminal status。
- NOT_RUN：Godot、native／GUI 播放、截圖、瀏覽器、匯出平台、發布或部署。
  玩家姿勢、native 啟動時序與 host stop 仍 OPEN；不宣稱 full96 或視覺保真通過。

重新對新快取執行 `compile_performances.py`，不可沿用舊來源指紋。
`asset_lab_composite.gd` 的 `provisional_precast_enabled` 預設為 false，正常介面不自動開啟。
只有隔離 source inspection 測試明確開啟；即使畫出幾何，仍會回報
`source_prepare_host_timing_unverified`，`seek()` 不得回報成功驗收。
報告保留暫定根來源、未解析的 mesh binder 數及 partial 標記。

`test_precast.gd` 用實際原始資料檢查預設關閉、明確取樣、非空幾何、倒放一致與關閉後清除。
這些是 headless 數值檢查，不是畫面比對、Windows 執行或 all-96 演出通過。
