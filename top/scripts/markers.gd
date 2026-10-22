# SPDX-License-Identifier: MIT
extends RefCounted
## Manual target signs and waymarks are independent of combat statuses and LB targets.
const IDS=["attack1","attack2","attack3","attack4","attack5","attack6","attack7","attack8","bind1","bind2","bind3","ignore1","ignore2","square","circle","plus","triangle"]
const ICONS=[61201,61202,61203,61204,61205,61206,61207,61208,61211,61212,61213,61221,61222,61231,61232,61233,61234]
const LABELS=["攻擊1","攻擊2","攻擊3","攻擊4","攻擊5","攻擊6","攻擊7","攻擊8","鎖鏈1","鎖鏈2","鎖鏈3","止步1","止步2","□","○","＋","△"]
const WAYMARK_IDS=["A","1","B","2","C","3","D","4"]
const COLOURS=["ff4d63","ff4d63","ffdc52","ffdc52","4bc8ff","4bc8ff","c984ff","c984ff"]
const GLYPHS=["a_base","1_base0f","b_col00f","2_base0f","c_col00f","3_base0f","d_new","4_base0f"]
static func default_layout(radius:=13.0)->Dictionary:
	var marks:Array=[]
	for i in 8:
		var angle:=deg_to_rad(i*45.0)
		marks.append({"id":WAYMARK_IDS[i],"enabled":true,"pos":[sin(angle)*radius,-cos(angle)*radius]})
	return {"schema":1,"name":"通用八標" if radius==13.0 else "外圈八標","source":"generic practice layout, not a verified regional preset","marks":marks}
static func validate_layout(raw:Variant)->Dictionary:
	if not raw is Dictionary or not raw.get("marks") is Array:return {"ok":false,"reason":"需要 schema=1 與 marks 陣列"}
	var schema:Variant=raw.get("schema")
	if not (schema is int or schema is float) or not is_finite(float(schema)) or float(schema)!=1.0:return {"ok":false,"reason":"不支援的配置版本"}
	if raw.marks.size()>8:return {"ok":false,"reason":"最多八個場地標記"}
	var ids:Array=[];var normalized:Array=[]
	for mark in raw.marks:
		if not mark is Dictionary or str(mark.get("id","")) not in WAYMARK_IDS or str(mark.id) in ids:return {"ok":false,"reason":"標記 ID 必須唯一且為 A–D／1–4"}
		if not mark.get("enabled",true) is bool:return {"ok":false,"reason":"enabled 必須為布林值"}
		var pos:Variant=mark.get("pos")
		if not pos is Array or pos.size()!=2:return {"ok":false,"reason":"pos 必須為 [X,Z]"}
		for value in pos:
			if not (value is int or value is float) or not is_finite(float(value)):return {"ok":false,"reason":"座標必須為有限數值"}
		if Vector2(float(pos[0]),float(pos[1])).length()>=20.0:return {"ok":false,"reason":"標記必須位於死亡牆內"}
		ids.append(str(mark.id));normalized.append({"id":str(mark.id),"enabled":bool(mark.get("enabled",true)),"pos":[float(pos[0]),float(pos[1])]})
	return {"ok":true,"layout":{"schema":1,"name":str(raw.get("name","自訂")).left(80),"source":str(raw.get("source","user custom")).left(240),"marks":normalized}}
static func ensure(state:Dictionary)->void:
	if not state.has("target_markers"):state.target_markers={"schema":1,"owners":["","","","","","","",""],"events":[],"sequence":0,"mode":"manual"}
static func marker_for(state:Dictionary,actor:int)->String:
	return str(state.get("target_markers",{}).get("owners",["","","","","","","",""])[actor]) if actor>=0 and actor<8 else ""
static func icon_id(marker:String)->int:
	var index:=IDS.find(marker);return ICONS[index] if index>=0 else 0
static func title(marker:String)->String:
	var index:=IDS.find(marker);return LABELS[index] if index>=0 else ""
static func assign(state:Dictionary,target:int,marker:String,actor:int,source:="player")->Dictionary:
	if target<0 or target>=8 or actor<0 or actor>=8 or (marker!="" and marker not in IDS):return {"ok":false,"reason":"無效的角色或標記"}
	ensure(state)
	var m:Dictionary=state.target_markers
	if str(m.mode)=="none":return {"ok":false,"reason":"玩家標記已關閉"}
	if marker_for(state,target)==marker:return {"ok":true,"changed":false}
	var old:=marker_for(state,target);var displaced:=-1
	if marker!="":
		for i in 8:
			if m.owners[i]==marker:displaced=i;m.owners[i]=""
	m.owners[target]=marker;m.sequence=int(m.sequence)+1
	m.events.append({"sequence":int(m.sequence),"sim_time":float(state.get("sim_time",0)),"actor":actor,"target":target,"marker":marker,"previous":old,"displaced":displaced,"source":source,"operation":"clear" if marker=="" else "assign"})
	return {"ok":true,"changed":true}
static func next_attack(state:Dictionary,actor:int)->Dictionary:
	ensure(state)
	for i in 8:
		if "attack%d"%(i+1) not in state.target_markers.owners:return assign(state,actor,"attack%d"%(i+1),actor)
	return {"ok":false,"reason":"攻擊編號已用完；沒有搶走隊友標記"}
