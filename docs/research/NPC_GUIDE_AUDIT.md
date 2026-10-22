# NPC 運作期與莫古力攻略核對（2026-10-23）

範圍：20項獨立機制、回報55項敘述。**結論：尚未全部符合莫古力攻略。**
這是逐程式核對，不把既有Bot全過或預算終點當作攻略認證。回報同一行可能同時包含已存在的判定和仍缺的提示；以下分開記錄。原圖1未隨文字檔提供，故不聲稱重現該圖片。未修改原傷害時間、接觸半徑、移速或一般0.5秒傷害提示政策。

## 20項覆蓋

| 階段／機制 | 核對結果與仍缺內容 |
| --- | --- |
| P1 接線踩塔 | 玩家長線NPC接取缺陷、退線內縮與提示問題；A起順時針已存在。 |
| P1 全能之主 | 內出外回存在；NPC在扇形揭示前用安全扇區走位，分攤線效果缺。 |
| P1 擴散波動炮 | CN遠程東西／補師西南東南存在；出生即答案、可見炮線不足。 |
| P2 協同PT | 圖案記憶、眼睛、真假分身／武器讀取已分段；單橫排與水晶精確站位未完整。 |
| P2 協同LB | 北誘導、實際坦克接線及扇形判定存在；引導範圍提示缺。 |
| P3 轉場 | 八波與手炮判定存在；NPC過早站安全口袋。 |
| P3 你好世界 | 四輪真實感染／塔／拉線存在；初始八方、預覽線、塔色與玩家對側補位仍不完整。 |
| P3 超取樣 | 實際半場選人與衝擊存在；3～4排優先序及玩家互動適配仍缺，圖1未重現。 |
| P4 藍色畫面 | 實際移動快照、回波及三輪分攤存在；分攤線辨識度不足。 |
| P5 德爾塔 | **CN藍綠對王側與Defense分工不符回報**；拳生成與鎖定語意須再核對。 |
| P5 西格瑪 | 圖形橫排、提早塔容量提示、手標驅動分工與World等待路徑未完整符合。 |
| P5 歐米茄 | 4×1／4×2入口正確；完整手標分工及危險側數字點契約缺漏。 |
| P5 Solar Ray（回報未提） | 兩次真實仇恨目標與V換坦可練；不是完整職業減傷／無敵／HP流程。 |
| P6 Cosmo Memory（回報未提） | 真實坦LB時機與三層資格；入口資源是明示獨立快照，不是完整HP／盾流程。 |
| P6 天箭→俯衝（回報未提） | 兩坦近／六人遠實際判定；數值天箭路線仍屬訓練構造，不套用回報的天箭→波動炮配置。 |
| P6 地火→波動炮 | 相對前兩場標間隙起點不符；八方炮判定有、線特效缺。 |
| P6 天箭→波動炮 | 已補回報指定四對並保留原已符合的A–D時鐘；完整數值天箭步伐仍是訓練構造。 |
| P6 地火→俯衝 | 同地火相對起點問題；實際近遠距離判定有。 |
| P6 流星 | 真實LB、期限、點名存在；精確晚期分支未全來源化，標記辨識度待實測。 |
| P6 Magic Number（回報未提） | 兩輪坦LB／Doom／補LB實際生命週期；不是完整傷害與最終輸出流程。 |

## 回報逐項核對

編號依原回報非標題的55個非空行順序。`已有`只表示該程式／訊號存在，不冒稱目前使用者平台的實際畫面已驗收。

| # | 狀態 | 核對與下一步 | 程式定位 |
| --- | --- | --- | --- |
| 01 | 本輪已修正 | NPC對玩家長線改以接取膠囊內候選點實際截線；八人33項檢查通過，未改所有權或半徑。 | `interactions.gd/raw_bot_goal` |
| 02 | 部分符合 | 退線者縮到半徑3是導航實作，確有內縮；不能視為莫古力要求的退避距離。 | `interactions.gd/raw_bot_goal` |
| 03 | 缺漏 | 現有頭頂環與線，沒有持線紅大圈／判定閃爍。 | `arena.gd/draw_signs` |
| 04 | 已有，視覺待驗 | 首扇T6.1前已有4秒起始預兆；不因主觀過短任意延後傷害。 | `p1_runtime.gd/sync` |
| 05 | 不符 | Panto coaching從T0即讀預算安全扇區；需等可見起始扇形後再分流。 | `p1_courses.gd/append_panto` |
| 06 | 缺漏 | 分攤的實際命中存在，但sync只導出hazard，未導出波動炮線特效。 | `p1_runtime.gd/resolve,sync` |
| 07 | 不符／缺漏 | 固定散開配置存在；開場直接spawn正解，波動炮僅有頭標、無相應線特效。 | `p1_courses.gd/append_cannons` |
| 08 | 部分符合 | 已有排隊，但目前是兩列小隊，不是回報要求的H1 MT ST D1 D2 D3 D4 H2單橫排。 | `p2_synergy_courses.gd/append_synergy` |
| 09 | 已有 | 場外Optical Unit已在圖形記憶階段出現；不代表已驗證其畫面辨識度。 | `p2_synergy_courses.gd/append_synergy` |
| 10 | 已有修正 | 先排隊→圖形→中立分身→武器揭示→走安區，非出生即在安區。 | `p2_synergy_courses.gd/append_synergy` |
| 11 | 已有 | hide_predictive_aoes隱藏預測答案；共用一般傷害提示上限仍依既有0.5秒要求，不改為1秒。 | `p2_synergy_courses.gd/append_synergy;late_damage_preview.gd` |
| 12 | 已有，視覺待驗 | 四種SVG頭標皆有三角、方塊；實際匯出可見性和大小不能由程式存在代替。 | `synergy_signs.gd/texture;arena.gd/_process` |
| 13 | 缺漏 | 一般場標存在，未有此機制水晶參考／兩格精確站位契約。 | `p2_synergy_courses.gd/append_synergy` |
| 14 | 部分符合 | Fire III與Spotlight已有真實搭檔距離檢查及魔法易傷；沒有完整獨立距離錯誤加傷狀態生命週期。 | `p2_synergy_courses.gd/append_synergy;rules.gd` |
| 15 | 缺漏 | 90度坦克引導扇形有真實判定，未有對應wind-up範圍提示。 | `p2_limitless_runtime.gd/resolve,sync` |
| 16 | 不符（選修） | 首段NPC目標已是手炮安全口袋；應分離中立觀察與實際讀手炮後就位。 | `p3_transition_courses.gd/append_family` |
| 17 | 部分符合 | 已有3秒Smells staging，但不是獨立八方觀察→看塔後配位流程，不能標成已符合。 | `hw_courses.gd/append_family` |
| 18 | 缺漏 | 初始只有Code Smell狀態；實際paired_tethers到T23 regression才生成。初始可見配對線須與有傷害的線分離。 | `hw_patterns.gd/events;hw_runtime.gd/begin,resolve` |
| 19 | 不符 | 塔資料有red/blue，Arena塔柱仍統一琥珀色。 | `hw_runtime.gd/sync;arena.gd/draw_signs` |
| 20 | 缺漏 | NPC用預算路徑；沒有依玩家實際選側進行合法等價對側補位。 | `hw_courses.gd/coaching_goal` |
| 21 | 部分符合 | 舊持毒者的半徑5爆炸真實存在，但缺少專屬可見衝擊。 | `hw_runtime.gd/expire` |
| 22 | 部分符合 | 目前綠線會收向±1.1,-5或末輪±1.1,3；不等於已驗證沿身位圈等待。 | `hw_courses.gd/append_family` |
| 23 | 部分符合 | 已有第四輪Local先、Remote後的inside分支；精確「分攤後→中間拉斷」仍須逐時點驗證。 | `hw_courses.gd/append_family` |
| 24 | 缺漏 | 檢知從中心出生後直接走最終位，沒有3～4直排分優先序。 | `encounters.gd/monitors` |
| 25 | 已有，視覺待驗 | Boss半場與玩家檢知載入／衝擊已存在；辨識度問題仍需可見實測。 | `encounters.gd/monitors;arena.gd/update_p3_effects` |
| 26 | 待重現 | 固定左側座標已有修正；完整Bot課程可過不能證明所有玩家移位都能處理，不能下必滅或已修好結論。 | `encounters.gd/monitors;rules.gd/monitors` |
| 27 | 本輪已修正 | 結果面板原先被Tab隱藏；現已讓結束／失敗結果在工具關閉時直接顯示。非新增判定後走位。 | `main.gd/sync_practice_hud` |
| 28 | 缺漏 | P4實際分攤線判定存在，提示主要是小圓，缺少清楚分攤線衝擊。 | `p4_wave_runtime.gd/resolve,sync` |
| 29 | 不符 | 回報要求藍找Final／綠找Beetle；目前藍西、綠東而Beetle西、Final東，確實相反。 | `p5_delta_courses.gd/goals;p5_delta_patterns.gd/events` |
| 30 | 不符／部分 | 依顛倒側別實作了手炮與Defense流程；CN目前inner_green Defense也與回報藍內圈Defense衝突，不能只鏡像終點修正。 | `p5_delta_courses.gd/arm_map,goals` |
| 31 | 來源衝突 | 回報要求拳出現後原地；runtime實際以6y/s跟隨持有者至鎖定。必須釐清生成／鎖定各時點，不當作舊問題已消失。 | `p5_delta_runtime.gd/tick` |
| 32 | 已有 | 寬16的Optical Laser在T20.120真實結算；其特效辨識度仍未由靜態審查證實。 | `p5_delta_patterns.gd/events;p5_delta_runtime.gd/resolve` |
| 33 | 已有，視覺待驗 | 六手炮鎖定及旋轉線判定存在，方向特效強化仍待處理。 | `p5_delta_runtime.gd/resolve` |
| 34 | 缺漏 | 沒有明示H1優先H2的內圈讓位契約。 | `p5_delta_courses.gd/goals` |
| 35 | 不符 | 目前同圖案左右、圖案沿南北兩列；回報要求同圖案上下、四圖案左右橫排，不能把兩者視為同一配置。 | `p5_sigma_courses.gd/append_sigma` |
| 36 | 已有，視覺待驗 | 三角方塊圖示已實作，匯出大小／辨識度另驗。 | `synergy_signs.gd/texture` |
| 37 | 已有，視覺待驗 | 六個炮標已有圖像訊號，非只有文字標籤。 | `p5_sigma_courses.gd/append_sigma;synergy_signs.gd` |
| 38 | 缺漏 | identify tower beat沒有塔shape；實際塔只在最後resolution beat加入，sync是pass，未在第一次手炮後展示容量。 | `p5_sigma_courses.gd/append_sigma;p5_sigma_runtime.gd/sync` |
| 39 | 部分符合 | 近17／遠19.5與搭檔距離、Looper及Ruin有判定；完整加傷狀態訓練仍不完整。 | `p5_sigma_courses.gd/append_sigma;p5_sigma_runtime.gd/snapshot` |
| 40 | 部分符合 | 通用手標B/M/N/Ctrl1～8存在；CN依手標選123、禁止、攻擊5替代的運作期NPC分工／檢驗缺漏。 | `markers.gd;main.gd/apply_target_marker;p5_sigma_runtime.gd/allocation` |
| 41 | 部分符合 | 模型面向、腳刀／法杖及旋轉雷射存在；清楚可辨轉向提示仍待畫面驗收。 | `p5_sigma_courses.gd/append_sigma;arena.gd/update_stage_entities` |
| 42 | 待逐時點驗證 | 有CN專用World路徑，但不能由路徑可通過推定符合貼電網等待到腳刀／十字後回場。 | `p5_sigma_runtime.gd/paths,place` |
| 43 | 部分修正 | 機制本體有14發雷射、手炮及三次World，不是就位即結束；本輪修復最後結果被隱藏。 | `p5_sigma_courses.gd/append_sigma;main.gd/sync_practice_hud` |
| 44 | 部分符合 | 獨立入口已4名一層／4名兩層；但依一麻／二麻與手標決定危險側順位的訓練仍缺。 | `encounters.gd/initial_stacks;p5_omega_runtime.gd/choose` |
| 45 | 未證實重現 | 首spawn已中心，第一組武器T0可見、第二組T4可見後才切換目標；預算goal本身不證明提前偷讀。 | `p5_omega_courses.gd/append_omega;encounters.gd/omega_dodges` |
| 46 | 部分符合 | 通用手標存在；Omega分工忽略實際attack1～4/ignore/bind，不是完整手標練習。 | `p5_omega_runtime.gd/choose,snapshot` |
| 47 | 部分符合 | 第一World有半場monitor、克隆有Diffuse扇；非完全無判定，但顯示辨識度待實測。 | `p5_omega_courses.gd/append_omega` |
| 48 | 缺漏 | 因無完整手標→角色分配契約，無法宣稱attack1／4避半場的攻略義務已符合。 | `p5_omega_runtime.gd/choose,goals` |
| 49 | 缺漏 | 未以手標ignore1／2綁定危險側數字點。 | `p5_omega_runtime.gd/choose,goals` |
| 50 | 部分修正 | CN離場方向已改為相對首預兆及旋轉方向的67.5度間隙；T0–T10仍在中心誘導首水圈，完整間隙起跑預站位仍未完成。 | `p6_patterns.gd/exa_waypoints;p6_courses.gd/append_exaflare_family` |
| 51 | 待來源確認 | 已有T26.2／28.2與T34.4判定；回報未給目標時間，不能隨意放慢。 | `p6_patterns.gd/waves` |
| 52 | 缺漏 | proteans與charge有傷害事件，但sync只導出hazard，沒有相應八方線特效。 | `p6_runtime.gd/resolve,sync` |
| 53 | 已補配對，非完整步伐認證 | 天箭→波動炮現為1=D4/ST、2=D2/H2、3=D1/H1、4=D3/MT，使用分時進出和逆時針過渡；保留原已符合的A MT/B ST/C H2/D H1時鐘（先前此處誤列不符）。不套用天箭→俯衝。 | `p6_patterns.gd/route;p6_courses.gd/arrow_goals` |
| 54 | 部分修正 | 地火→俯衝同步改為相對67.5度離場方向；初始中心誘導仍保留，未宣稱完整間隙起跑站位。雙坦近判定未放寬。 | `p6_courses.gd/append_exaflare_family` |
| 55 | 已有，視覺待驗 | 流星已有flare圖形訊號（非只有半徑1小圓）；大小、對比仍可強化。 | `synergy_signs.gd/observed_all;p6_runtime.gd/resolve` |

## 優先次序

1. 玩家互動與攻略錯誤：長線接取、Delta側別＋Defense整組分工、HW對側補位、檢知排優先序與選人、Sigma/Omega實際手標契約、P6明示配對與地火相對起點。
2. 觀察訓練：不要在提示前偷跑；塔色／容量、線特效、轉向、判定衝擊。揭示預覽與會傷害的線必須分開，不能為了畫出提示提早觸發判定。
3. **低幀數優化排後**：先量測同場景CPU／實際frame time，保留所有角色、訊號與判定，分清CPU改進和使用者平台實際FPS。

這份審查不將尚未完成的攻略修正列為通過，也不因通用手標已存在就把Sigma/Omega攻略手標視為完成。

## 本輪驗證（與尚未符合的攻略項目分開）

- 玩家長線接取：四方向×靜止／合法移動端點、雙線預留、真實接取事件，以及舊受控線路徑對長線失敗的對照，33項檢查通過。
- 結束／失敗回饋：實際Main檢知Bot完成與玩家站死亡牆失敗，10項檢查通過；普通練習不提前顯示解法。
- 初版接線測試誤用四人fixture觸發八人索引錯誤，已保留失敗紀錄並改成完整八人；不採用該次exit0作為通過。
- 20項×3固定種子共60個實際移動Main課程、522個判定快照，0失敗；這仍只驗證目前模型可運作，不將表內攻略缺漏認證為正確。
- 這些修正尚未發佈至固定測試站；本表其他缺漏不因這兩項通過而變成攻略認證。

[後續低優先度HUD CPU量測與優化](../development/HUD_FRAME_COST.md)已完成首輪；局部CPU改善不等於使用者FPS驗收，亦不取代本表剩餘攻略修正。


## 2026-10-23 多模型增量：P6配對與離場方向

- 新增配對與實際傷害幾何檢查240項；完整P6回歸1614項、操作20項、精度55項、Main選項93項均零失敗。
- 新跑20機制×3種子60條Main實際移動課程，522次判定快照，零失敗；仍不是其餘攻略缺口認證。
- 初版靜態半徑配對實際回歸6項失敗，修正為分時進出後才通過；保留失敗紀錄，沒有放寬原傷害時間、範圍或移速。
- 相對67.5度只修正地火離場方向，初始中心誘導尚未改成間隙起跑；玩家平台畫面、新匯出與發佈未由這些檢查驗收。
