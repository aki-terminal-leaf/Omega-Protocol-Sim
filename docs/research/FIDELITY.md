# v0.3-preview 精確度與未完成範圍

本分支接續 v0.2 的 20 項獨立練習，加入持續狀態與原版素材管線；**不是完整所有區服／全部伺服器判定已還原的宣告**。來源、參數狀態、程式驗收與實戰校準是不同證據，不能互相替代。

## 本次實際新增

- Hello World 由真實接觸傳播紅／藍腐毒，保留原持有者；相反顏色覆蓋、Debugger、代碼氣味、潛在錯誤、到期爆炸與提前斷線均有運行狀態，不再用最後交接站位替代感染。
- Delta 成對線會在移動中斷開；Omega 可轉移的 Blaster 線跟隨實際 owner，先爆炸再結算 World，排除實際受擊者。不同類型的線不混為一種所有權規則。
- Delta 六手臂各六次判定：半徑 20 的來源、寬 8、每次轉 20°、間隔 0.6 秒；角度讀第一次實際引導，不隨後續位置重新瞄準。Sigma 為十四發寬 12 雷射，間隔 0.6 秒、每發轉 9°。
- 地火依位置、推進、下一次爆炸時間與剩餘次數持續運作。P6已接入相鄰45°、半徑24的觀測族群，每次推進8、每條七次；目前排程首次推進1.11秒、其後1.00秒，為明示名目模型，非精確server tick。完整原始RNG仍未證明；舊1.1秒參數只用於legacy fixture，見[P6地火範圍](P6_EXAFLARE_FIDELITY.md)。
- Aether／LPDU 檢知使用不同的第三檢知南側／第一檢知北側陣型，不再只換優先序名稱。Panto 的起始軸與 LPDU 兩小隊 TMR 補位分開處理。
- JSON 保存實際狀態、受擊者、所有權、事件時間、校準參數、攻略定義與重試歷史；重練恢復前置狀態和動作時長，分段起點實際模擬先前交互，而非直接指定理想線 owner。
- 本機包可載入五種原版首領網格／貼圖／骨架／resident 動作，以及既有 DSR 的七種配裝角色；詳見 [素材來源](OFFICIAL_ASSETS.md)。公開原始碼不包含遊戲素材。

## 全域界線

場地半徑 20；玩家與所有機制的 Bot 普通移動均為6，明示疾跑7.5。舊式 Party Synergy／檢知的11訓練速度已移除；受影響的338組實際 Main 案例通過，普通速度上界6.00002為浮點誤差，不改 AoE 或時間窗。大部分攻擊仍在各事件 snapshot 判定；腐毒、成對線、可轉移線與地火有移動中的狀態。數值積分步長不是量測的 server tick。

沒有完整 HP／治療／輸出、所有職業減傷／無敵、復活後繼承、完整仇恨與 LB 量表、伺服器延遲或八人連線。致死事件可記錄失敗，但尚非完整角色死亡／屍體／死後技能規則。其他攻擊不能因通過示範就稱與遊戲完全一致。

本開發分支一般練習會隱藏解法文字、建議落點與 World 建議線；以八人隊伍實際狀態判斷，僅失敗檢討或明示示範可顯示參考處理。AoE 仍有訓練示意，不等於遊戲所有無預警技能。P5 接續只保留為內部驗收 fixture，不重新放回玩家的機制選單。

## 逐項範圍

| 機制 | 已實作 | 仍待完成／校準 |
| --- | --- | --- |
| Program Loop | swept 接線、跨輪 owner、實際持線者受擊、塔消除實際踩塔者的 Looper、Ruin／HP Penalty；塔 3、Blaster 15 | 接線半徑與雙線政策仍待實測；Looper16/25/34/43、Ruin11s與HP Penalty9s已有四份通關紀錄的名目校準；塔／Blaster尚非完整HP／補血 |
| Pantokrator | 分組／補位、14次雙噴火、80個實際落點水圈、四輪飛彈／三人線與已核對起始軸 | 數字路徑是合法實現而非官方座標，完整HP／減傷未模擬 |
| P1 Cannons | 實際最遠雙坦選人、兩輪 protean | 五連擊傷害、無敵、職業 CD 未模擬 |
| Party Synergy | M/F 姿態、圖形、距離、同側雙分攤補位、實際擊退 | 不包含所有原始 clone 位置排列與精確預警時序；只支持明示的生成族群 |
| Limitless | 真正接線、按來源分側；Defense 讀取兩名最近候選之一，Pitch 排除實際受擊者、按當下最近目標結算 | 未完整加入 Sagittarius Arrow 所有來源／引導、流星傷害衰減、擊殺次序、Defense 易傷完整時長與 HP |
| P3 轉場 | 五套獨立來源分配；八次同時序波動、六手臂實測原點、紫單人／白雙人半徑6；正常步行與 Main 連跑驗證 | 中央地板時窗、手臂預兆／部分左右型仍有推定；HP／護盾與死亡轉標未模擬，詳 P3_TRANSITION_FIDELITY.md |
| Hello World | 自由接觸、原持有者保留、覆蓋、Debugger、Smell、Latent、實際爆炸受擊者、Local／Remote 即時斷線；最後 Local 先於 Remote | 接觸半徑、同色刷新、同時異色的伺服器次序仍未實測；初始Smell3s／Bug21s／回歸10s等已有紀錄校準，不再使用壓縮初始剩餘時間。相衝的同時感染明示為未驗證分支，不冒稱伺服器必定判死 |
| P3 Monitors | Astoh、Aether 第三檢知南側、LPDU 第一檢知北側；左右鏡像／朝向、各兩人且每人一次 | CN／KR 完整陣型尚未逐圖核對；半平面內原版隨機選兩人的風險以恰兩人站位驗證 |
| Blue Screen | 五套主來源 TRHM；三輪八向鎖定／24 舊方向回波、雙直線4+4、八次圓環與實測時序；正常步行及 Main15組通過 | 伺服器方向快照精確幀未量測；HP／減傷、壓至20%與完整 CN 原影片未驗證，詳 P4_WAVE_FIDELITY.md |
| Delta | 真正成對斷線、易傷／Ruin、拳配色與交換、六手臂鎖定後六發旋轉、檢知與 World | 線門檻與時間仍有訓練值；拳實體的出現／重複鎖定／死亡規則、完整出現族群尚未完成 |
| Sigma | 六標記、五／六塔容量、擊退落點與 Glitch、十四發旋轉雷射、實際 World 跳轉 | F 克隆所有位置／階段重疊、所有區服路線未齊全；第一發暖身時間不等於原戰鬥絕對時間 |
| Omega | 真正圓／環／十字／側邊矩形與 Diffuse cone，不再用答案形安全扇區；實際接線 Blaster、受擊後 World 排除 | 明示生成族群的姿態／旋轉測試不等於所有原始 spawn；World 初始組合未枚舉全部實戰可能 |
| Solar Ray | 兩段分開承受、換坦 | 減傷／無敵與真實傷害未模擬 |
| Cosmo Memory | 三層前置快照、實際坦 LB 請求／生效／動畫鎖，存活才取得 Brilliant | 滿量表為明示獨立前置；HP／護盾與自然量表未模擬 |
| Arrow→Dive | 交錯線條平移、最近雙坦／最遠六人 | 完整原始發生族群／所有線條重疊時程未逐幀對照 |
| Exaflare→Wave | 真正移動地火事件、實際舊引導點、散開／前排坦克分攤 | 相鄰45°／半徑24的有限觀測族群已接線並驗證16組變體；完整原始RNG／精確時序與區服路徑仍未驗證，詳P6_EXAFLARE_FIDELITY.md |
| Arrow→Wave | 交錯線與同時 beam 判定 | 不是完整所有原始起點／輪次生成器 |
| Exaflare→Dive | 移動地火後最近雙坦／最遠六人 | 同上；相鄰45°觀測族群不等於完整原始RNG或精確伺服器時序 |
| Meteors | 法系落點／遠敏目標、真實共用量表／讀條／延遲傷害／施法後鎖、6彗星＋2隕石 HP 與實際擊殺期限、56核爆分工 | 小彗星20.5s名目期限新增實際失敗紀錄支持（T20.488逾時）；遠敏全寬8已依資料解讀修正；NPC邊緣／射程寬限、核爆完整傷害／減傷、大隕石期限與部分區服路線仍未量測；觀測最大傷害不是普遍上限，詳P6_PRECISION.md |
| Magic Number | 兩輪真實坦 LB 生效、補 LB 讀完才驅散、6秒 Doom、Brilliant 消耗／退還與施法後鎖 | 起始量表為明示前置；自然量表、HP／補量、死人與復活未完整模擬 |

## 證據標籤

[參數表](../../top/data/fidelity_parameters.json) 的 `guide_documented` 表示可讀攻略有敘述，`community_geometry` 表示獨立社群事件實作有資料；兩者均不是本次遊戲伺服器實測。`unverified_training`／`unverified_branch` 明確不是已校準。

自動快照只證明幾何自洽；實際 Bot 流程證明模型中的交互可執行；負向測試證明特定錯誤會失敗。這些不證明所有區服宏、所有原始 pattern 或網路時序。要消除上述剩餘項目，仍需逐項對照可重現的實戰錄影／戰鬥紀錄與各社群原始攻略，而不是由 datamining 資料表推測伺服器邏輯。

## Engine / ordinary movement checkpoint —2026-10-21

Godot/GDScript baseline is pinned4.7.2. All ordinary bot movement now shares the
player's6-unit budget; only the explicit recorded coaching Sprint may use7.5.
`walking_fidelity.gd` exercises actual Main at≤50ms internal steps: all32
Synergy source clone families ×five offered methods ×two allocations (320),
plus six monitor methods ×three allocations (18),338 courses/0 failures.
Maximum measured ordinary speed6.0000169; only the explicitly modeled instant
Discharger knockback is excluded from walking-speed measurement. Actor goals,
attack sizes, cast/snapshot timings and legal knockback were not relaxed.
These routes remain the documented source families, not an assertion that every
original spawn or every regional temporal variant has been verified.

## Local original arena pack (2026-10-22)

`tools/export_official_arena.py` reuses Lumina/TexTools read-only parsing of
`bg/ex2/05_zon_z3/ome/z3oz/level/bg.lgb` and original BG MDL/MTRL/TEX data.
Runtime uses the original phase-layer placements centered from (100,0,100)
without changing source units or gameplay/collision geometry. TOP P6 maps to
the scene's final `p7_boss` / `p7_enkei`; the `p6` asset is a P5 transition.
Models and manifests remain local-only; source exports keep procedural fallback.
The pack has 34 original BG meshes, original diffuse/normal textures and 103
non-cutscene placements, with source and converted SHA256 provenance.

This is original geometry/texture provenance, not an exact renderer recreation:
static phase-layer selection, BG shaders, alpha/blending, lighting, fog,
transitions and multi-axis placement conventions still need visual calibration.
No original encounter timings, radii or character collision rules changed.

Pixel review rejected an opaque substitute for the original vertical-fog meshes.
Those three shader-only meshes are now intentionally omitted rather than covering
the original scene with white sheets. Original BG diffuse tint constants are
preserved in the PBR conversion; all source shader constants remain in GLB extras.
This does not implement original fog, weather or dynamic shader effects.
