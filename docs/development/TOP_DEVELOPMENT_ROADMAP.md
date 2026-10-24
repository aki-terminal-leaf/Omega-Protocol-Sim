# TOP 全攻略互動、最佳化與完整 AVFX 開發路線圖

日期：2026-10-23。範圍：本次使用者要求的**開發整理與規劃**；本文不表示以下功能已實作。
開發基準與檔案SHA見[結構化矩陣](../research/STRATEGY_CONFORMANCE_MATRIX.json)。

## 1. 優先順序與「完成」的定義

1. **全部攻略的機制正確性與玩家練習價值**：不是只修莫古力回報，也不是只查Bot能否走到合法終點。
   - **2026-10-24 新增優先項：玩家結果判定**。玩家不必與 NPC 一樣踩攻略指定座標；只依實際攻擊、正確 Buff／Debuff 與死亡判定通過。合法異位或等價分工不額外失敗；攻略符合度與 NPC 路徑另外驗證。缺少教學分配與未校準傷害的未知不得憑空算玩家受傷／死亡；也不把未知宣稱為實服已證安全。
2. **最佳化**：先建立實際CPU／GPU／幀時間基準，再保留原判定與可讀訊號改善。
3. **完成AVFX**：補足原始輸入、完整播放語義、實際整合、原遊戲對照與Windows／Web匯出，不以shader小實驗宣告完成。

可並行資料盤點、來源閱讀與獨立review；功能整合／驗收按上述順序。每次只結清一個可審核段落，未完成工作保留在矩陣，不以局部PASS替代整體完成。
本路線圖初版為規劃，不表示全項實作。其後 v0.3.11／v0.3.12／v0.3.13 已逐階段驗收並部署；目前固定站為 v0.3.29，限定範圍見 [部署紀錄](STAGE_DEPLOYMENTS.md)。下列尚未結清的分支繼續保留，開發 push 不等於 release。

v0.3.14–v0.3.17 的累積來源改善已隨 Web-first v0.3.18 更新固定站；各舊候選的原生 GUI 證據仍未完成，不能混算通過。[P3 公開觀察增量](P3_PUBLIC_OBSERVATION.md)有 4,200 條全分組走位及 40 正向／3 負向 Main 鍵盤流程通過；新 PCK 的 23 組回歸、無桌面 Chromium／SwiftShader WebGL2 操作、固定 HTTPS 位元組及全新啟動已通過。玩家正向尚未涵蓋全部手臂／減益組合。依使用者要求先更新 Web，不等待原生；原生待驗；該歷史階段曾開放 AnAn 桌面；依2026-10-24最新指示，桌面目前停用，後續原生仍待驗。完整攻略、最佳化及完整 AVFX 其餘工作繼續保留。

[P3 提示狀態診斷 v0.3.19 Web-first](P3_OBSERVATION_DIAGNOSTICS.md)已發布：來源／七項新包受影響檢查、實際 Web 狀態／操作、固定 HTTPS 及全新啟動通過。此項不更改走位、判定或未知原始時序；未改動的舊機制保留 v0.3.18 基線，原生仍待驗；該歷史階段曾開放AnAn，依2026-10-24最新指示目前桌面停用。全部玩家義務、最佳化及完整 AVFX 仍未結清。

[LPDU P2 初始準備 v0.3.22](P2_LPDU_PREPARATION.md)已驗收並更新固定站：THMR／南位重複換側、公開圖形記憶、十一組新PCK、實際Web及固定HTTPS通過；原生待驗，後段分攤歧義、武器／新北與全部P2未結清；Aether自由換序其後的限定驗收見下節。

[Aether P2 橫排準備 v0.3.23](P2_AETHER_PREPARATION.md)已更新固定站：來源141條實際輸入、十三組精確PCK、實際Web十項操作、固定HTTPS與全新啟動通過；原生獨立待驗。未覆蓋全部初始排列／幾何、武器／新北／後段與完整P2，全20／100、最佳化與完整AVFX仍繼續。

[公開身體辨認新北 v0.3.25](P2_PUBLIC_NORTH.md)已驗收並更新固定站：限定Elemental／Aether／LPDU既有分工，來源20Main274／生命週期84、17組同PCK、實際Web9項及固定HTTPS通過；Web較早圖形明示分段輔助、當前North仍須實際顯示。CN／KR、LPDU武器側軸、原遊戲精確幾何、全角色×攻略及全部P2仍未認證；原生25待驗。全20／100正確性、量測最佳化與完整AVFX繼續。

[玩家結果判定＋CN開場 v0.3.26](PLAYER_OUTCOME_VERDICT.md)已更新固定站（[發布](https://github.com/aki-terminal-leaf/Omega-Protocol-Sim/releases/tag/top-v0.3.26-preview)、[top.servicing.cc](https://top.servicing.cc)）。下一步順序不變：全20／100正確性 → 量測效能 → AVFX啟用；AnAn桌面保持停用，原生26待驗。

[Astoh 檢知 M2玩家／N3應變 v0.3.27來源增量](P3_MONITOR_ADAPTIVE.md)已限定驗收：19實際輸入／641項、20回歸／372項、純39項及必要既有檢查通過，七檔獨立審查完成。此來源檢查點當時新PCK／實際Web／發布待驗；其後v0.3.27已完成限定Web驗收與發布，見下方「v0.3.27 Web-first 限定驗收」。只改N3目標，不把玩家攻略座標當失敗條件；其他角色／打法、全部攻略、量測最佳化與AVFX仍繼續。原生待驗、AnAn桌面停用。

### 全範圍而非抽樣

- 20個產品機制、102個可選選項（原100＋09STOP固定DPS兩個明確變體）、5個社群；Panto/Cannons/Monitors的額外變體分列，Solar Ray只有1個共用選項。
- 不是20×5完整區服矩陣。內部`p5_full`五組只作狀態連續性驗證，不算額外產品選項。
- [全20機制與100選項清冊](../research/STRATEGY_CONFORMANCE_MATRIX.md)、[JSON](../research/STRATEGY_CONFORMANCE_MATRIX.json)、[CSV](../research/STRATEGY_CONFORMANCE_MATRIX.csv)已逐項列入範圍；**列入不等於符合**。
- 原回報55項仍由[NPC_GUIDE_AUDIT](../research/NPC_GUIDE_AUDIT.md)保留追溯；它是CN專項，不足以認證其他攻略。
- 已登錄但未完整研究的莫靈喵、MM+W／鈺子燒、KR Kiwi，以及後續找到的具體新分支也要納入來源盤點；不先掛名為可用打法，不宣稱網路所有攻略已搜盡。

## 2. 每個選項要核對的八層

| 層 | 必須回答的問題 | 必留證據 |
| --- | --- | --- |
| 原機制 | 生成在哪、限定族群／聯動、玩家誘導還是隨機、真實選人與失敗條件？ | 原紀錄／攻略衝突對照、時間與方向，不能以壓測推回遊戲RNG |
| 原攻略 | 這個具體方法／版本如何分工，圖文、宏、Toolbox、影片有沒有不同分支？ | 公開URL、版本或取證日期、段落／頁／slide／step／timecode；文字與圖像分開 |
| 玩家預處理 | 預先要排隊、排序、分隊、記對、標記、選位、換位或分配LB嗎？ | 是開場設定還是機制內步驟；誰做、何時做、可見依據與完成條件 |
| 可見情報 | 當下能知道什麼？塔色／容量、眼睛、真假武器、線色、層數何時揭示？ | 揭示前／當下／之後的畫面與事件時間；不透露未來答案 |
| 玩家操作 | 玩家是否真正需要執行？漏做／錯做／晚做會怎樣？ | 實際輸入、目標、位置／面向／標記事件，不用NPC解答路徑代替 |
| NPC協作 | 依哪個公開訊號及實際玩家選擇做出什麼回應？ | 合法等價選擇、讓位／補位與衝突政策；不可使用隱藏未來資訊 |
| 真實判定 | 線轉移、感染、選人、塔人數、朝向、傷害、狀態及LB是否按實際行動結算？ | 運作期事件、碰撞與狀態生命週期，含負向案例 |
| 實際體驗 | 圖示／效果能辨識、結果能理解、匯出版同樣能操作？ | Windows原生與Web實際畫面／輸入／結果；工程測試不能替代 |

狀態須拆為`source_unknown`（來源未證）、`missing`（未實作）、`mismatch`（已證不符）、`partial`（部分）、`verified_scoped`（限定條件通過）、`render_unverified`，不可只剩「Bot全過」。
矩陣本版採保守`not_certified`／待逐選項重核；不是說既有所有功能都壞掉，也不抹除已驗增量。

## 3. 來源補證與現有資料整理（S0）

**開工第一批；逐選項伴隨修復，不必等所有來源查完才修明確錯誤。**

| 社群／來源 | 目前可沿用的證據 | 仍須補的全內容對照 |
| --- | --- | --- |
| Elemental / Tuufless | 全階段文字、日英宏與既有專題 | 每機制圖／動畫／PoV所有合法分支、隊列與人類交接；不能外推整個JP |
| Aether / thepfstrat、Dylan、Saus | 既有Toolbox、P5／P6獨立來源與已實作分流 | 早期P1–P4連結圖、P5／P6完整角色路徑與預處理；D1/D2對應按原圖職業核對；P6非「完全無來源」 |
| LPDU | 原markdown、**P1 raidplan全八張已逐張讀過**、P5 Toolbox、P6三張raidplan與post-7.0差別 | P1八張已讀圖以外的未核影片分支、P2–P4尚未讀完的Toolbox／raidplan步驟、完整影片／減傷與坦組合、自由分支與預先分工 |
| CN莫古力 | 一圖流15區塊、宏、Limitless第2段14:30–22:30與原55項回報 | 上下部影片其餘內容與所有分支；拳生成／追蹤／鎖定、預站／手標／相對角度的精確語義 |
| KR09STOP | 全階段workbook文字、部分圖例／動畫與宏 | 尚未讀完的動畫frame、分支／宏／減傷頁、P3與Sigma完整分配、P6原配對與動作，不把推導當原圖 |
| 其他已知來源 | 莫靈喵、MM+W／鈺子燒、Kiwi入口 | 先辨識是否真正不同解法、適用機制與可取得的內容；來源不全先研究，不自動克隆成選項 |

- 每段原文要求拆成可追溯requirement，引用到具體選項／分支與runtime函式；原圖、影片及遊戲素材不放公開Git。
- **已確認的文案漂移，列首批修正**：CN Delta選單仍寫「綠側Defense」，但實際已改藍內Defense；CN兩種Exa描述仍寫45°，實際離場已改相對67.5°。修正選單／說明與當前runtime一致，仍明示初始間隙預站未完成；不要再把過時文字當新物理bug。
- 既有`REGIONAL_ROUTE_AUDIT.md`／`regional_route_spec.json`是歷史研究，不是最新runtime真相。
- `strategies.json`／`sources.json`部分早期scope與metadata落後於專題：例如CN全圖已讀、Aether已取得P6資料。要在有更晚證據時合併更新，而不是按舊metadata判無來源或按新測試判全符合。
- 跨攻略相同機制的物理規則不應因區服改變。扇形90°／120°、Dive選人、彗星5／6等衝突先比原紀錄；彗星六配置已有後續證據，不重新把已關閉問題列成未知。
- 候選角度、精確座標、自由選人tie-break要標「合法實作慣例」或「訓練值」；無來源不能自動回退另一社群。
- 驗收：100選項皆有來源定位、明示缺頁／缺分支、預處理責任與差異表；尚未補證者不能升級成完全符合。

## 4. 玩家預處理與NPC合作的共用契約（S1）

優先重用現有`markers.gd`／`marker_settings.gd`、`interactions.gd`、各runtime/course、`party_statuses`及原DSR controller模式；不另造平行標記／狀態引擎。
既有[MARKERS_PLAN](MARKERS_PLAN.md)的手動／輔助／不用玩家標記是設計與分段功能目標，**全部模式與NPC反應尚未實作完畢**。

### 每個方法的預處理規格

`requirement_id + mechanic/option/branch + source_locator + actor/responsible_role + visible_inputs + reveal_time + action_window + valid_choices + player_action + npc_response + deadline + invalid_action_policy + clear/restore_rule`。
這是待落地資料契約，不要求玩家閱讀工程欄位。機制選單仍維持「先機制、再打法、單項練習」。

- **設定前置**：職責、攻略、允許的場標配置、固定／新種子；不自動填入本次亂數答案。
- **機制內預處理**：排隊／排序、看塔選側、記圖形、找搭檔、手動上標、換位／讓位、先站間隙；不能因尚未傷害就跳過。
- **玩家必做**：來源要求自己判讀／上標／接線／施法時，Bot不得代做。不同職責的義務不同；不是所有八人都要做同一件事。
- **合法等價選擇**：來源允許玩家選A或B時，NPC依實際選擇補另一側；不強逼唯一預算終點。
- **非法操作**：錯標／漏標／晚標或走錯側要保留真實協作後果；NPC不暗改線所有權、Debuff、層數、生成、判定時間或碰撞大小救場。未上標本身不憑空造成傷害，實際站位／接線照常判定。
- **手動／輔助分帳**：示範可顯示分配，但必須標示輔助，不算手動通過。機制強制點名、手動標記及Buff三者分離；不用玩家標記不會隱藏機制情報。
- **回復生命週期**：R同種子重練清除本次殘留；檢查點只還原已發生的可見事件、標記與狀態，不注入未來答案。暫停／設定／失敗檢討不修改通過紀錄。
- **結果拆開**：戰鬥判定成功、攻略流程符合、手動／輔助及來源精度分開顯示／記錄；結果在判定後可見，不提前洩解。

## 5. 正確性開發批次與驗收（S2–S6）

| 順位／批次 | 要開發或補證的內容 | 最低驗收條件 |
| --- | --- | --- |
| S2-A HW | 八方觀察→Smell與無傷配對預覽→真紅藍塔→玩家選側／NPC對側；原毒等待與第四輪依五來源分開 | 八職責各至少一實際玩家流程；合法左右選擇NPC皆可補位；漏交接、錯塔、提前／延後斷線真實失敗；預覽不觸發傷害 |
| S2-B 檢知 | 六選項的3／4列優先序、實際點名後排位、Boss半場／個人左右朝向、玩家合法移位適配 | 有／無檢知、左右Boss與左右玩家檢知分支；正確人數／每人一次；錯面向不自救；CN圖1缺失不冒稱圖像重現 |
| S3-A Sigma | 五攻略各自圖形隊列、塔識別時機／容量與宏／目視策略；手標到真實World分工與等待回場 | CN橫排同圖上下；炮後早塔可讀不提前結算；所有手標角色正確／漏／錯／晚與attack5替代；西方宏／KR分配不能套CN |
| S3-B Omega | 實際層數／I、II→來源手標→檢知與World/接線；危險側數字點、attack1/4與ignore1/2契約 | 正確優先與非法標記衝突；兩輪來源北；自由Far合法側；玩家需要時自己Sprint；實際三層接線，不預發層數 |
| S4-A 觀察與預排 | Panto／Cannons／P3轉場的偷跑／出生答案；P1退線距離；PT各攻略隊列、水晶參考及距離異常；LB誘導wind-up | 所有相關選項，揭示前保持中立、揭示後可正常走到；人類真誘導／接線；時序和幾何不放寬 |
| S4-B Delta收尾 | H1>H2讓位、綠外精確數字標；原資料驗拳出生→跟隨→鎖定；五攻略換拳與World分工 | 使用合法來源位置；玩家人選互換不靠固定Bot答案；保留已修藍Final／綠Beetle與藍內Defense；原7碼濺射及斷線窗不變 |
| S4-C P6預處理 | CN地火67.5°相對離場以外的初始間隙預站／首水圈誘導；各攻略八方／配對、LB與換位、所有未知路線補證 | 間隙預站與首水圈兩要求能同時成立；不照搬CN到其他區；天箭→Wave四對不套Dive；LB由玩家真操作，未知角度保留來源標籤 |
| S5 可讀性與狀態 | P1/P4/P6炮線與衝擊、Loop持線紅圈、HW爆毒與塔色、圖形/flare大小、Delta手炮轉向、全部狀態 | 實際匯出前中後幀可辨；可見預兆不提早產生碰撞；一般傷害最後0.5秒政策與起始預兆例外同時成立；維持隊伍Buff與底部操作說明 |
| S6 全攻略收斂 | 補齊所有未回報機制、Solar/Memory/Meteors/Magic來源精度與玩家義務；其餘社群所有分支 | 100選項逐行結清，不能只跑一社群20項；未證／部分功能保留明示狀態；涉及新打法時先取得完整規格再掛選項 |

S2/S3可由不同檔案owner並行；父代理整合共用`main.gd/arena.gd/markers.gd`，避免同檔競爭。
同一機制的來源／預處理／NPC／判定／提示應形成完整小增量，不只改終點後留人類流程斷開。

### 已結清、不可倒退當新待辦的項目

- 玩家長Loop線由NPC**真實截取**；結果面板在結束／失敗可見。
- CN Delta側別、藍內Defense與六手炮分工、外綠先斷／內綠延至World易傷後斷、盾擊者避7碼濺射已修。
- CN Arrow→Wave四對已修；A MT/B ST/C H2/D H1時鐘原本就正確，不能重新當錯誤。
- CN地火**離場方向**已改相對67.5°；尚缺的是初始間隙預站，不是這個角度完全未改。
- HUD首輪CPU優化、四UV傳輸、color stage實驗播放器整合與原始paired shader限定證據均保留，不重跑關閉批次來冒充新進度。

## 6. 全攻略驗證方法

1. 先列100選項×八職責的**待覆蓋索引**（800個基礎職責入口，不是宣稱800已跑）；按機制差異做合法等價分組，記錄來源branch與實際覆蓋。不用全維度巨大笛卡兒積拖死主機。
2. 每個互動合約至少驗：正確流程、合法另一選擇、漏做、錯做、過早、晚做，以及NPC不可代作。負向案例核對真實後果，不只斷言失敗flag。
3. 揭示邊界前／當下／後、狀態取得／消除、接觸距離與同時事件；未知伺服器規則另列，不能用實作自證。
4. deterministic runtime回歸驗實際玩家座標／輸入與碰撞；全Bot通關只作回歸層。native手動與可回放輸入證據分開，不能把重播稱真人操作。
5. Windows原生與Web各做真實操作／畫面驗收，包含八人Buff、提示、字體／縮放、鏡頭、重試／檢查點、標記、LB；HTTPS／PCK hash不是遊玩驗收。
6. 每份結果固定commit、引擎鎖、選項/override、角色、種子、分支、模式、輸入、事件、截圖／影片hash；更改runtime後只重驗受影響族群及必要共用回歸，保留失敗。

不新增只鏡像程式的測試；優先真碰撞、真標記分配、資訊隔離、生命週期及跨平台操作測試。

## 7. 最佳化（P0–P3，正確性之後）

既有[HUD_FRAME_COST](HUD_FRAME_COST.md)只證明局部HUD CPU均值下降約15%～49%，不是實際FPS已修。

| 批次 | 內容 | 驗收 |
| --- | --- | --- |
| P0基準 | Windows原生／Web實際使用環境，Monitors/HW/Omega及P6效果密集場，同commit/seed/視角/解析度/角色/提示模式 | CPU main/physics、GPU（API可得時）、frame time p50/p95/p99、draw calls、VRAM/常駐記憶體、首次／暖機、載入與卡頓；GPU不可得就明記未知 |
| P1 CPU | 量測後依熱點處理HUD/狀態投影、重複觀察、字串布局、每幀配置與事件更新 | 同一完整流程before/after，不用單函式microbench替代；冷啟／重試結果一致 |
| P2 GPU／資源 | 依profile處理材質/shader/mesh重用、批次、透明overdraw、紋理／模型載入與必要LOD | 所有角色／武器/預兆/頭標/判定保留；遠近可讀、視覺對照不退化，不縮碰撞或刪提示換FPS |
| P3生命週期 | 反覆開始/暫停/同點名重練/切機制/seek，驗shader/mesh/texture釋放與峰值回落 | 同一暖機基準後不持續增長；無孤兒Godot/browser/Xvfb／子程序；量測報告附真實平台 |

Linux llvmpipe只作相容性／正確性參考，不能代表玩家實體GPU效能；CPU microbench另列，與原生實體GPU／WebGL2真實幀時間分帳。所有比較要固定暖機／冷啟條件，檢查出生、穩態、消失與重試尖峰。

效能目標需在P0量測後鎖定；以60Hz為候選時，p95≤16.7ms、p99≤33.3ms只是待校準目標，不是本次已達成承諾。依實際平台限制決定品質層級，不能任意降低訓練情報。
用既有Godot profiler／平台工具，不先購買服務或建立自製監控平台。AVFX完整整合後再跑受影響的效能回歸，舊renderer數據不能代替。

## 8. 完整AVFX工作包（V0–V7）

### 可沿用基線，不再當作未開始

- 已有AVFX資源／graph／曲線／mesh工具、四原UV通道、限定原始shader D3D對照、DXBC→SPIR-V→GLSLES工具鏈與explicit ABI。
- 實驗播放器已opt-in接入reviewed color sections，使用actual mesh、一次compile後apply、不重複tint、保留支援render states、錯誤fail closed與釋放。
- 該actual-player新路徑已有Linux 363合約、135 fixtures/2461 checks及64 state/framebuffer限定檢查；**沒有因此取得新Windows／Web整合驗收**。
- 原始VS+PS限定12例與局部pixel對照不等於全部材質、host、場景渲染或完整AVFX。P3既有重建仍是fallback，不能將實驗自動換上當完整原版。

### 優先重用既有方案

沿用已釘版本的MIT VFXEditor格式（05f6eb0cce19a6a91ae275bce609299d573914b3）、Lumina／既有資源工具、Penumbra.GameData來源，以及已驗的vkd3d/SPIRV-Cross/validators；使用現有`avfx_*`、`shpk_inspect`、`shader_pair_abi`、`apricot_*`工具。先檢查可重用能力，必要時才補缺層，不重寫整套shader translator或嵌入in-game plugin冒充獨立runtime。

| 批次 | 內容 | 依賴與完成證據 |
| --- | --- | --- |
| V0支援清冊 | 由全部保留AVFX/particle/material/binder/clip產生支援矩陣，並盤點20機制是否缺effect資源 | 18個現存effect是樣本，不是整副本資源齊全；unsupported不得悄悄當預設成功 |
| V1原始選擇與host ABI | 每個ShPk本地key schema、真正pass/permutation、vertex packing、CalculateColor/Alpha/common factor、UV矩陣、TC控制與Fresnel建構 | 不是只在候選shader中猜最近；Unknown枚舉維持unknown，caller明示context不等於原host來源已證 |
| V2材質與資源 | 原texture decode／sampler／四UV路由、TC2–4、normal/reflection/distortion/palette、lighting、完整blend/depth/cull/priority與Disc/soft particles | 原始實際輸入／非中性案例對照；擴展到尚未支援的族群而非無限重跑同一9個shader |
| V3時間／粒子／綁定 | 循環、stop/unlock/fade/reset/trigger；fractional spawn、原random distribution／volume／velocity／inheritance；billboard/polyline/decal/simple anim；骨架socket與binder transform | 多時間點及seek/stop/reset；人物移動旋轉時附件跟對位置；不只靜態截圖或只有shape/powder/model |
| V4 render graph | MRT/HDR、screen-copy／distortion、DOF/tone／Fresnel與實際排序／合成 | 原始多pass及非中性場景對照；color-section測試不能代替整個framebuffer graph |
| V5正式接線 | 由練習機制事件驅動正確effect instance、空間／actor binding及結束清理；保持正式判定單一來源 | 玩家技能/敵人預兆/命中/消失皆正確；未支援有明確diagnostic與可辨fallback，不雙播不改判定 |
| V6原遊戲對照 | 同一可重現場景的多時點、動作、停止／消失、透明／深度與畫面比較 | 確定的遊戲實例與scene/capture route；先被動來源／既存合法紀錄，確需host追蹤時不可任選正在玩的程序附加；未有對照就不宣告完整 |
| V7平台／資源／發佈 | 同commit新版Windows/Web/Linux必要匯出、實際播放、效能與釋放、README真實畫面／影片、完整hash與rollback | 新路徑平台回歸通過才升級完成狀態；完成驗證後沿用既有授權直接發版，不重問例行確認 |

依賴主線：`V0 → V1 → V2 → V4 → V5 → V6 → V7`；`V3`可在來源已證部分與V1/V2分檔並行，但V5須同時滿足V3。V6能先整理既有對照片，不必等整合才開始蒐證。
原host取證仍有「具體遊戲實例／可重現場景」缺口，先在V1/V6標條件依賴；離線格式／player可繼續，不偽造host預設、不任選live game、不把此缺口誇大成所有工作停擺。

整合前後須比較相同事件／狀態、transform、四UV與材質生命週期，另做alpha/MRT/depth及原版多時點差異圖review；非空畫面不是等價。不得因新粒子/LOD/batch/cache方案改變關鍵預兆。

**完整AVFX的收尾門檻**：目標20機制所需effect及所有實際用到的功能均有正確來源／runtime、正式機制整合、原遊戲時間/畫面對照與新Windows/Web驗收。剩餘unsupported若仍被目標機制用到，就只能報部分，不以parser保留欄位或shader編譯通過替代。

## 9. 開發節奏、責任與收尾

- 最先落地：S0選項證據／預處理契約整理，接S1共用事件與手動責任，S2 HW／檢知及S3 Sigma／Omega；其餘全部機制與攻略持續在S4–S6收斂。
- 每段≤25分鐘，單指令≤10分鐘、至少15分鐘內有新的可檢查實質證據；卡住保留失敗與seed、具體改法後同stage恢復，禁止換ID重試逃過上限。
- 有界跨模型子代理按獨立檔案所有權工作；父代理整合／驗收、另一owner獨立review。不等待早已結清的舊completion通知，也不把交付標籤問題當開發重跑理由。
- 每一已review增量只stage本次來源／文件，commit後直接push既有開發分支；不等全部100選項才累積提交。
- 工作結束清除只屬本次的runtime/process group／cache／userdata／暫存，保留原始來源、失敗與必要證據，不碰其他服務或原有快取。
- 引擎保持已驗Godot4.7.2-stable鎖；不混用`.godot`與未驗nightly API。完整HP/職業減傷、自然LB量表、復活與最終輸出屬現有精度缺口，需來源／範圍明示，不讓NPC正確性或AVFX完成聲明掩蓋。

## 10. 本次交付與後續追蹤

本次完成：全範圍清冊、逐機制人類／NPC契約、開發優先與依賴、驗收／資源收尾計畫。**沒有宣稱100攻略已逐圖逐幀完全核實、機制已修完、FPS已改善或AVFX已完成。**
後續每個功能增量更新對應矩陣行／requirement與實際證據；不因一個案例通過就批量把全社群／全機制改為完成。


## 2026-10-23 開發增量

首批已進入實作，參見[玩家／NPC 預處理增量](PLAYER_NPC_PREPARATION_INCREMENT.md)。S0三項已知文案漂移已修；HW同色塔配合、可讀塔色與檢知排序僅按該文所列範圍驗證。原S2–S6其餘項目、全攻略來源、最佳化及完整AVFX門檻不因此結清。


## v0.3.15 Sigma 來源整合（歷史）

[手標協作、責任及驗收界線](SIGMA_MANUAL_PREPARATION.md)的來源整合有 18 個實際移動重播／1,534 項檢查、Main 170 項及必要共用回歸通過；累積改善現已隨 v0.3.18 Web-first 發布。早期 v0.3.14／v0.3.15 的原生 GUI 仍未驗收，桌面停用，不會自動等閒置後恢復。S0–S6、全部來源分支、最佳化與完整 AVFX 不因此結清。

## v0.3.17 Cannons 有限觀察來源候選

[Cannons 契約與證據](CANNONS_OBSERVATION.md)區分既有炮標、真實已顯示三人／合法互補推知、公開固定職責／坦位及明示合成分段輔助；不改6碼移速、五cleave／兩protean與15.1秒終點。MF1及JSON呈現局部修復已獨立覆核關閉，且140個有限物理流程／613項、Main81／468、實際場景299、必要共用及修復後P1事件1266項皆通過；獨立來源／輸入及測試fixture覆核完成。原提示起算點及KR90°／120°仍未知，現120°不變；非空部分收據永久封鎖只是有限政策，不是攻略命令。候選未匯出／平台測試，100行仍 NOT_CERTIFIED。Panto Main166只示範UI1..5（不含KR6）；82物理流程含所有profile，不外推為Main五社群全部已驗。


## v0.3.20 HW 首輪 Web-first 限定驗收

[首輪公開資訊與玩家配合](HW_PUBLIC_FIRSTWAVE.md)已發布限定修正：67條實際Main操作／621項、100條NPC四輪／600項及42項觀察檢查通過。分段補充Main367及必要共用回歸亦通過；新PCK十項／實際Web／公開HTTPS與新啟動已通過，依使用者要求先發布Web v0.3.20；Windows原生限定操作及離線包亦已追加，完整示範與真人／全攻略範圍分開。此項只修首輪塔方向偷跑及實際選側回應，不結清S2-A八方玩家預處理、後三輪情報隔離或全20／100攻略。

## v0.3.21 P2 Elemental Web-first 限定驗收

Elemental初始HTMR列隊／下位重複換邊改由實際可見八人圖形驅動，保留機制亂數、玩家所有權、原判定與移速。來源／八組精確PCK／實際Web操作與提示／公開HTTPS及新啟動已驗；原生21待驗，不混用Windows20證據。其他四打法的實際排序、完整P2／新北／武器、其餘玩家義務、最佳化及完整AVFX繼續，詳見[P2限定範圍](P2_ELEMENTAL_PREPARATION.md)。

[公開實體武器提示 v0.3.24](P2_PUBLIC_WEAPONS.md)已更新固定站：五種P2選項197純檢查／十五原版模型Main課程187項、240完整生成差分及必要回歸通過；十五組新PCK、實際Web八項、固定HTTPS十三種表示與全新啟動通過。原生獨立待驗；LPDU分組側、其他攻略／全20與100、最佳化和完整AVFX仍繼續。

[公開身體新北 v0.3.25](P2_PUBLIC_NORTH.md)已更新固定站：來源1345純檢查、20原版Main274項、84生命週期、十二回歸與240完整生成差分，以及17同PCK／9Web／13HTTPS與全新啟動通過；較早圖形明示分段輔助、當前North來自實際顯示身體。原生25另待驗，CN／KR、LPDU武器側與原遊戲確切幾何仍未知，全20／100、最佳化與完整AVFX繼續。


## v0.3.27 Web-first 限定驗收

Astoh M2玩家／N3增量已更新固定站並[發布](https://github.com/aki-terminal-leaf/Omega-Protocol-Sim/releases/tag/top-v0.3.27-preview)；21精確PCK、實際Web八項、獨立最終畫面、HTTPS13表示與全新啟動通過。不是全部檢知攻略或全20／100；原生27待驗、桌面停用。依既定順序繼續其餘正確性，再量測最佳化與完整AVFX。


## v0.3.28 LPDU N4 來源限定修正（歷史來源檢查點）

[LPDU N4來源與界線](P3_LPDU_N4.md)：原版seed1微小轉向造成錯誤隨機候選已由實際Main輸入重現，只調N4訓練位置，其他判定／玩家所有權／亂數不變。純3873項、72NPC／258項、20Main輸入／372項與4800生成差分限定通過。舊全機制靜態快照719失敗在原版一致重現，仍記FAIL，不作全攻略證書。此來源檢查點當時新版PCK／實際Web待驗；其後已通過並部署v0.3.28，見下方「v0.3.28 Web-first 限定驗收」。原生仍待驗、桌面停用。全20／100攻略→量測最佳化→完整AVFX仍ACTIVE。


## v0.3.28 Web-first 限定驗收

LPDU N4內側工程間距已更新固定站並[發布](https://github.com/aki-terminal-leaf/Omega-Protocol-Sim/releases/tag/top-v0.3.28-preview)；11精確PCK、單次完整Web八項、獨立最終畫面、HTTPS13表示與全新啟動通過。不是全部檢知或全20／100攻略；原生28待驗、桌面停用。先續其餘攻略正確性，再量測最佳化與完整AVFX。


## v0.3.29 固定DPS來源檢查點（新平台待驗）

[P3 09STOP固定DPS](P3_MONITOR_FIXED_DPS.md)：兩個明確新選項、當前公開提示NPC分配與人類no-op；純1792／32726、56實際Main／995、舊20Main／372及72NPC／258通過，384舊完整生成／RNG／排序相同。44正向與8真實負向／4明示提示撤回分帳，不等於全部角色／種子。H/T全組合與東側鏡像為來源推導、既有KR精確幾何未校準。清冊現102行；原100規劃基準與未認證項保留。現有固定站仍v0.3.28，新PCK／Web／發布待驗；桌面停用、原生29待驗；全攻略→量測效能→完整AVFX持續。


## v0.3.29 Web-first 限定驗收

09STOP兩固定DPS選項已[發布](https://github.com/aki-terminal-leaf/Omega-Protocol-Sim/releases/tag/top-v0.3.29-preview)並更新固定站；13精確PCK、單次完整Web八項、獨立最終畫面、HTTPS13表示與全新啟動通過。非全20／102攻略；原生29待驗／桌面停用。仍先續NPC攻略正確性，再量測最佳化與完整AVFX。


## v0.3.30 後續輪次選塔來源檢查點（新平台待驗）

[HW 後續輪次選擇](HW_LATER_CHOICE.md)：只修 NPC 判塔前責任更新與外圈側切換，玩家／速度／攻擊／狀態規則不變。生命週期108／實際Main3流程48項及相依回歸通過，兩個正向與一個真實太晚失敗分帳。只限受控 Elemental 第二輪角色6實際案例，合成前段不等於普通手動；逐輪完整公開憑據未完成。新 PCK／Web／原生待驗，既有固定站29不變；全20／102正確性→量測效能→完整AVFX仍進行。
