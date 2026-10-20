# v0.1.0 精確度、驗證範圍與未完成事項

本版是**可玩的示意型走位／判斷練習原型**。22 項可選不等於完整原戰鬥或完整區服戰術。以下限制同樣適用預設、示範與測試。

## 全域

- 3D 場地半徑 20 個 yard-like 單位；移動 6、疾跑 8；Bot 11。半徑、擊退、分攤／塔／連線距離是訓練參數，未由遊戲封包或逐幀錄影校準。
- 時間軸是放慢且可調速的 beat，不是原遊戲 cast timestamps。多個連續動作可能合為一個檢查點。
- 1 玩家、7 Bot；AoE 在每個 beat 結束時 snapshot。死亡牆在移動中亦記錯。不是持續的所有 AoE 碰撞模擬；可穿過暫時未結算的紅色預警。
- 判定從實際八人位置／朝向計算，不讀建議答案；示範只證明內部幾何自洽，**不證明與遊戲精確一致**。
- 沒有 HP、輸出、職業技能表、真實減傷／無敵、完整仇恨、傳染的自由接觸狀態機、復活、延遲或八人連線。LB 是角色／時窗／一次使用驗證，不是實際量表與動畫鎖模擬。
- 無提示僅隱藏建議落點和 World 建議路線；仍保留可讀 AoE／文字 cue，並非完全模擬遊戲無預警技能。

## 各練習

| 模組 | 實際可練 | 簡化／未完成 |
| --- | --- | --- |
| Program Loop | 1234 塔、3412 Blaster、正確點名、人數與重疊；有優先序差異 | 線預先配給當輪角色；沒有碰撞傳線或真實 HP penalty／Twice-come Ruin 計時；八個出塔點各出現一次、每對相隔 90°/180°；線仍是預配而非可搶取 |
| Pantokrator | 隨機 CW/CCW、飛彈前出、三人 beam、舊 puddle 與 cone | 每輪三個檢查點；非原 puddle tick、導彈／分攤所有真實 debuff timers |
| P1 Cannons | 最遠雙坦與兩輪三人 protean | 不模擬五連擊傷害、無敵 CD |
| Party Synergy | M sword/shield、F staff/legs、眼睛軸、圖形／距離、分攤 flex、實際擊退 | clone 排列是固定示意；沒有全原始 clone spawn pattern。Mid/Remote 距離為近似值 |
| Limitless | 坦克 tether 站位、分散 flare、最近兩人 Defense、受害者不入 Pitch | 非可搶線狀態機；未實作 611 中間減傷硬吃；未模擬雙王血量／擊殺次序 |
| Reconfiguration | 四紫、二白二無；三輪 Wave Repeater；手臂危險區 | 手臂位置／波時序示意化，非完整所有轉場 pattern |
| Hello World | 四組輪替、正確腐毒塔角色、defam/stack、近身交接、藍先綠後斷線 | 腐毒顏色隨點名綁定，沒有自由接觸感染／完整 Debugger/Latent 狀態；藍綠先後由獨立 beat 強制，不模擬提前斷線事件 |
| P3 Monitors | 四個半平面各恰有二人、每人恰中一次、玩家監視器左右方向 | 所有預設共用 Astoh 形狀；不是 Dylan／LPDU 真實位置切換；半平面內隨機二人的危險以「必須恰二人」驗證 |
| Blue Screen | 三輪 spread/echo/stack、TRHM 同側調整、donut 進出 | echo beam 和 ring 的時序、大小為訓練近似；沒有 DPS <20% 檢查 |
| Delta | 同類線分側、異色拳配對、拳 snapshot、inner blue break、檢知／Pitch、safe-half World | 拳色依原規則隨機產生（一組黃黃、一組藍藍、兩組混色），有內側 swap 分支；六手臂檢查最近引導，旋轉後依實際 bait 方位判定；旋轉角／大小仍是訓練參數；線斷法是分段距離檢查 |
| Sigma | 隨機六標記、雙標／單標配對、五／六塔容量、徑向擊退、旋轉雷射、World | 塔位拓撲對照原圖，實際半徑／Glitch 門檻仍是近似值；前段與擊退落塔均檢查 Glitch；14 發雷射合成 7 個檢查點；獨立模組的 Dynamis 初值是 0，跨完整 P5 可用三運接續課程 |
| Omega | 兩組 stance→安全方向／距離提示、二層 second-in-line 優先檢知、兩次 World、三層入 P6 | M/F 用結果安全扇區替代完整 clone 幾何；初始 stack 分布為洗牌後 4×2+4×1；第二組 World 的 Blaster 爆炸尚未實作；不是所有可能的 World/debuff 組合生成器 |
| Dynamis course | 四次真實最近／最遠跳躍、跳回／夾人失敗、連續計數、八人各三層 | World utility 分配使用一組合法排程，未枚舉所有可行隨機組合；不含四個 World 中間的全部 P5 機制 |
| P5 full course | Delta→Sigma→Omega 和四組換坦連續，Dynamis 不重設 | 各大機制仍採本表所述示意實作；未加入真實 Run: Dynamis raidwide／減傷、血量或 transition cast |
| Solar Ray | 兩段分開承受、第二擊 V 換坦 | 無敵／減傷職業相容計畫未模擬 |
| Cosmo Memory | 三層檢查、正確坦克 LB 角色與時窗 | 無 shield／真實傷害檢查 |
| Arrow→Dive | 十字線躲避 cadence、最近雙坦、六人最遠分攤 | 線是各檢查點的示意 lane，不是完整向外平移的幀級動畫 |
| Exaflare→Wave / Dive | 四條地火流、六次引導、1.5 marker 出發、後續散開／雙坦前排或 Dive | 追蹤方向／速度示意化，沒有所有原始四條地火起點 pattern |
| Arrow→Wave | 天箭 cadence、兩輪 beam、八人 stack | 兩個 spread snapshot 同時保留交錯箭線判定；箭線為近似 lane 幾何，尚未逐幀對照原版位移 |
| Meteors | Caster/Ranged LB 各一次、四輪四人 AoE、D3 有／無 flare 的三核爆與五人 stack | 沒有實體隕石 HP、aim line、LB 動畫鎖與實際傷害；D3 必須站北的配置是訓練約定 |
| Magic Number | 兩輪 tank LB → 6 秒內 healer LB，角色／已用 Dynamis 限制 | 無真實量表回填／傷害數值；補師 LB 只可在對應 beat 使用 |

## 推進正式版的驗收工作

1. 為每種區服／社群打法取得可讀宏、逐張圖和實戰錄影，再以來源支持的名稱發布 preset；不可僅用影片標題命名實作。
2. 以遊戲視角校準真正範圍、步速、snapshot、前後搖、判定 tick、擊退和所有 clone/exaflare pattern。
3. 以實戰錄影校準已加入的 Delta 同色拳／旋轉手臂、Sigma 落塔 Glitch、P5 全序列狀態與 Arrow+Wave 同時判定。
4. 為 P3 建立完整腐毒／Debugger、接觸感染與可提前斷線的狀態機；P1/P5 建立真正可轉移線。
5. Windows 實機、不同解析度與控制器測試；目前 Windows 僅可證明完成跨平台匯出。

不能將這份清單描述成「已完成所有區服／全部原版機制」。
