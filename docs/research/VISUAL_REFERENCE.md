# 素材、操作與實測參考（v0.2.0）

## 已實際查看

- AnAn 使用者提供的 `dsr-sim-1.1.0`：啟動後查看 P3 Limit Cut 畫面；參考透視場地、角色／Boss、塔與隊伍介面。未將它的 PCK 複製到 TOP 發行物。
- DSR 上游 `player_movement_controller.gd`、`action_bar.gd`：參考相機相對 WASD、左右鍵環繞、雙鍵／中鍵前進、Space 跳躍及 1/2/3 動作；TOP 自行實作，不複製 GPL 控制器為 MIT。
- [Program Loop 塔與接線圖](https://ffxiv.tuufless.com/images/ultimates/top/01/program_loop_02.jpg)、[Party Synergy 姿態圖](https://ffxiv.tuufless.com/images/ultimates/top/02/party_synergy_03d.jpg)、[P6 場地／天箭圖](https://ffxiv.tuufless.com/images/ultimates/top/06/alpha_omega_1_01a.jpg)：已下載並實際查看像素。
- [Pantokrator 動畫](https://ffxiv.tuufless.com/images/ultimates/top/01/pantokrator.gif)：已查看全部六張動畫影格（10.5 秒），作為轉向／飛彈分攤的動態參考。
- 攻略內連結的 YouTube 影片抓取遇到登入／反機器人頁，沒有繞過，也沒有將未看過的影片當成已逐幀核對。

## 素材

`visuals.gd` 提供原創低多邊形機械場地、帶肢體擺動的人形角色、六足 Omega、M/F 裝備姿態、Final Omega、Alpha Omega 翼形輪廓。P6 使用金銅場地配色。沒有官方貼圖、骨架、音樂、付費依賴或攻略圖片／影片再散布。

這些是可讀性優先的訓練表現，不等於 DSR 的高精細匯入模型或 FFXIV 官方模型。P5 克隆仍是提示用途，不代表所有原始出現位置；完整原版素材外觀與動作尚未完成。

## 操作／API

`arena.gd` 保留 `update_state`、`screen_to_world`、`update_camera`、`zoom`，新增 `orbit`、`movement_vector`、`reset_camera`、`set_follow`、`set_encounter`。相機 yaw 是弧度；拖曳靈敏度預設 0.002 弧度／像素，比照 DSR。人物移動與突進讀相機方向，跳躍不會避開地面判定。

塔以垂直外框呈現；連線與頭頂持線標記讀實際 owner。清除選擇時亦清除舊角色、線與 AoE。角色使用實際位移驅動擺動，Bot 也會動。

## AnAn 開發與驗收

AnAn 作業 `top-visuals-controls-20261021`，隔離分支 `openclaw/top-visuals-controls-20261021`（同名 worktree）。三個變更檔及新檔已由父層下載逐一審閱，再整合輸入與接線；原 checkout 保持未修改。原作業參考圖下載失敗，父層已透過另一個可正常取得圖片的環境完成上述圖／動畫查看。

Godot 4.4.1 Windows import／規則測試、原生 OpenGL 畫面、相機 API 均有實測。整合後再於 AnAn 桌面以真正的相對滑鼠／掃描碼鍵盤事件操作，不以 SetCursorPos 當成遊戲的 raw mouse 動作。完整結果見 [驗證紀錄](../VALIDATION.md)。

## v0.3-preview 本機原版素材

本次已從 AnAn 的已安裝遊戲唯讀取得五種首領網格、貼圖、骨架與 56 段 resident 動作；另由使用者現有 DSR 1.1.0 轉出七種配裝角色、保留蒙皮與動作，沒有拷貝 DSR controller。具體來源、hash、相容性與未完整復刻的 shader / VFX 見 [OFFICIAL_ASSETS](OFFICIAL_ASSETS.md)。上面的「沒有官方素材」是 v0.2 的歷史描述，不再代表 v0.3 本機包；公開 source 仍不內附遊戲素材。
