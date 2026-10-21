# P3 波動砲與身位環 — 原版素材重建

## 已實作

- Status3452 → StatusLoopVFX534 → VFX1591 → `m0771stlp3c0c.avfx`；
  Status3453 → StatusLoopVFX535 → VFX1592 → `m0771stlp4c0c.avfx`。
  左／右充能使用各自原版模型，不假設兩者只是同一檔鏡像。
- Action31595/31596 的怪物技能時間軸連到 m0515 sp008/sp009；
  命中31597 的 ActionTimeline6738 是 `z3of_boss_gimmick06`，
  連到 `vfx/monster/gimmick2/eff/z3of_b0_g06c0c.avfx`。
- 本機原版 AVFX 內嵌網格與貼圖已取出並保留來源／輸出 SHA256。
  遊戲素材不收入公開原始碼；可攜包中的選定媒體附本機來源 manifest。
- 充能裝置跟隨實際持有者、左右側及角色面向，不讀建議站位。
  開炮／命中只讀實際判定事件記錄的來源與受擊位置；重試不殘留／重播舊爆炸。
- 一般練習不再把完整半場地面判定當成遊戲特效顯示；教學模式仍可開示意。
- 角色與 Boss 的方向指示改為前端箭頭、270°環與後方90°缺口，
  與模型朝向同步。這是遊戲式可讀性設計，不改人物／Boss 的判定半徑。

## 沒有宣稱完成的項目

這是**原版素材的重建顯示，不是完整 AVFX 直接播放器**。目前驗證的
Godot4.7.2 Windows／Web 管線沒有可直接使用的完整 AVFX runtime。
Physis 是資料讀寫庫；VFXEditor 的播放器依賴遊戲內環境，不能直接拿來
當獨立 Web/Godot 播放器。本次沒有嵌入這些工具的插件或另改專案授權。

當前 attachment、藍色加色材質、UV 調整、光束連接及0.85秒視覺收尾
是明示的重建；不是原版 scheduler、完整粒子／隨機分佈、曲線／shader、
精確 blend/UV 或逐幀驗證的時間。原版圖示、原版貼圖、原版網格與
完整原版特效播放是不同證據。後續可替換已驗證的 AVFX 播放層，
不必變動戰鬥判定及實際受擊事件。

來源：原版 Status/Action/ActionTimeline/StatusLoopVFX/VFX 資料，
[既有 AVFX 管線](VFX_PIPELINE.md)、[逐攻擊狀態紀錄](STATUS_ATTACK_OBSERVATIONS.json)。
