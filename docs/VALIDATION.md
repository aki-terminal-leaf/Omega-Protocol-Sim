# v0.1.0 驗證紀錄

驗證環境：Linux x86_64；Godot 4.4.1.stable.official.49a5bc7b6；Compatibility / Mesa llvmpipe；桌面 Chromium / WebGL 2。

## 已通過

- `tests/rules.gd`：**190 assertions，0 failures**。含幾何邊界、空／錯／超量塔、死亡牆、錯誤檢知朝向、近遠跳回與 clipping、Dynamis、錯誤／重複 LB、同色拳、落塔 Glitch、天箭與 beam 同時存在，以及種子／指定分配。
- `tests/run.gd`：**35,580 snapshots，0 failures**。22 項課程 × 5 個約定預設 × 48 個種子，各課程所有 snapshot 以八人建議站位代入獨立判定。
- `tests/runtime.gd`：**110 complete courses，0 failures**。實際 UI 控制器、Bot 移動、時間推進、擊退、LB、狀態接續與全課程結算，不只靜態載入。
- 原生 Godot UI 實際繪圖與截圖；未出現 script/shader errors。無音效裝置的環境使用 Dummy audio driver。
- 匯出 Web 版在 Chromium 真正操作：載入 canvas、開始、WASD 移動、Space 暫停、R 同種子回復、JSON report 下載。**0 browser errors**，下載紀錄確認位置有變、暫停時採樣不增加、重來後種子和初始位置一致。

## 如何重跑

```sh
godot --headless --path top --editor --import --quit
godot --headless --path top --script tests/rules.gd
godot --headless --path top --script tests/run.gd
godot --headless --path top --script tests/runtime.gd
```

Web 黑箱測試須另外安裝 Playwright/Chromium，先在本機 serve `build/web`，再跑 `python3 tools/web_smoke.py --url http://127.0.0.1:8765`。固定 1440×1000 桌面畫布，座標由實際畫面檢查後選定，非通用 responsive UI 測試。

## 不表示已通過的事項

- 幾何自洽不證明原遊戲逐幀／所有世界戰術正確；範圍見 [FIDELITY.md](research/FIDELITY.md)。
- Windows 已設定官方 x86_64 release template 的跨平台匯出；**未在 Windows 實機執行**。
- 未聲稱 macOS、行動裝置、控制器或多人聯機已驗證。
- 目前 GitHub OAuth 不含 `workflow` scope，GitHub 拒絕上傳 `.github/workflows`；因此範本存於 `docs/ci/top.yml`，未啟用 GitHub Actions。所有上述檢查為本機驗證，沒有宣稱 CI 綠燈。
- Windows／Linux／Web 官方 release templates 均已完成匯出；匯出的 Linux binary 已獨立啟動。
