# 逐機制 Buff／Debuff 呈現

本表區分遊戲原始狀態、機制強制點名及玩家手動標記。狀態身份取自原版
Status 資料；成功受擊後的效果另以[四份完整紀錄的實際傷害／狀態相鄰封包](STATUS_ATTACK_OBSERVATIONS.json)
核對，不由攻略站位反推。秒數為名目模型；約1.96／4.96／10.96秒的封包
分別顯示為2／5／11秒，不代表已量得伺服器 tick。

| 獨立機制 | 初始／進行中的可見狀態 | 正確處理後仍會取得／消除的狀態 |
| --- | --- | --- |
| P1 Program Loop | First／Second／Third／Fourth in Line、Looper | 實際踩塔消除自己的數字與 Looper；塔／持線爆炸給 Twice-come Ruin11s；持線爆炸另有 HP Penalty9s，模型延後0.65s生效 |
| Pantokrator | 數字1–4、四種各自ID的 Guided Missile／Condensed Wave 倒數 | 自己的飛彈結算才移除數字；飛彈／分攤實際受擊者 Magic Vulnerability2s |
| P1 Cannons | 炮標屬於機制點名，不是假造 Debuff | Diffuse31504：Magic Vulnerability2s；Wave31505：10s，對象按實際命中 |
| Party Synergy | Mid／Remote Glitch；配對圖形是獨立強制點名 | Fire III／Spotlight受擊者 Magic Vulnerability2s；最後結算清除本次強制訊號 |
| Limitless | 流星點名者 Prey8s；可轉移線不是Buff | Bladedance實際受擊者 Physical Vulnerability2s；Beyond Defense／Pile Pitch實際受擊者 Ruin7s |
| P3 轉場 | Sniper Cannon Fodder／High-powered Sniper Cannon Fodder | 狙擊結算移除點名；實際受擊者 Magic Vulnerability2s |
| Hello World | 四種 Code Smell、Critical Bug、Latent、近／遠 Code Smell及 Regression | 成功爆炸／處理取得對應 Debugger；實際交接、塔、短易傷及 Thrice-come Ruin依運行狀態呈現，不由答案位置消除 |
| P3 Monitors | Loading Left／Right，沒有捏造倒數 | 實際開炮消除 Loading；實際受擊者 Ruin7s＋Magic Vulnerability5s |
| P4 Blue Screen | 線分攤點名與舊方向回波不是Buff | 每次實際 protean／四人分攤受擊者 Magic Vulnerability2s |
| Delta | 原版P5 Code Smell3440/3504、Regression1672/1673、近／遠世界 | 實際斷線的短 Ruin／疊層魔法易傷、Defense/Pitch/檢知效果；World實際受擊者取得 Dynamis及5s易傷 |
| Sigma | Glitch、Looper、近／遠世界；配對圖形／六炮標為強制訊號 | 正確踩塔消除 Looper並給 Ruin11s；炮／手臂與 World 按實際命中給易傷，World給 Dynamis |
| Omega | 近／遠世界、First／Second in Line，實際疾跑 | World首擊移除該組數字／世界點名；檢知給 Ruin7s＋易傷5s；Blaster給 Ruin11s＋易傷5s＋HP Penalty3s；World給 Dynamis |
| Solar Ray | 沒有專屬準備Buff | 每次實際受擊坦克 Magic Vulnerability4s；不假造減傷／無敵狀態 |
| Cosmo Memory | 三層 Quickening Dynamis與實際職業坦LB | 存活才轉成 Brilliant Dynamis；不在開炮前直接發獎勵 |
| Arrow→Dive | 明示為Memory後的 Brilliant前置快照 | Dive兩坦與六人分攤的實際受擊者 Magic Vulnerability2s |
| Exaflare→Wave | Brilliant前置快照；地火／落點為場上物件 | Wave實際散開受擊者 Magic Vulnerability2s |
| Arrow→Wave | 同上 | Wave實際散開受擊者 Magic Vulnerability2s |
| Exaflare→Dive | Brilliant前置快照 | Dive實際受擊者 Magic Vulnerability2s |
| Meteors | Brilliant前置快照、實際LB讀條／目標 | 實際流星散開受擊者易傷2s；成功使用LB後 Brilliant→Spark，Spark不因量表退還就消失 |
| Magic Number | Brilliant前置快照、各坦職業LB | Magic Number6s；補LB真正讀完才消除，使用LB者轉Spark；坦LB按實際生效窗顯示 |

八人的實際疾跑、疊層、時間與 KO 也在隊伍列呈現。手動攻擊／鎖鏈／止步／
圖形標記另存獨立欄位，不會把真正的數字狀態或機制圖形換掉。

## 範圍界線

100個已提供選項的 UI 運行覆蓋不等於原戰鬥所有狀態／時序皆完成：
Packet Filter與完整P2輸出／擊殺流程、Glitch異常時完整持續易傷政策、P6
Flash Gale自動攻擊前奏、職業減傷／完整HP／復活與全部原始生成族群仍有
未完整模擬部分。各區路線及碰撞／伺服器時序的剩餘界線見
[FIDELITY](FIDELITY.md)；P3原版素材重建與完整AVFX播放器的差異見
[P3_EFFECTS](P3_EFFECTS.md)。
