# SPDX-License-Identifier: MIT
extends RefCounted
const Markers=preload("res://scripts/markers.gd")
const MAX_LAYOUTS=32
const ACTIONS=["panel","self","next","clear"]
const TITLES=["開啟標記面板","對自己上標","下一個空號","清除自己標記"]
const KEYS=[KEY_B,KEY_M,KEY_N,KEY_BACKSPACE,KEY_H,KEY_J,KEY_K,KEY_U,KEY_I,KEY_O,KEY_Y,KEY_F5,KEY_F6,KEY_F7,KEY_F8,KEY_F9,KEY_F10,KEY_F11,KEY_F12]
static func defaults()->Dictionary:return {"panel":KEY_B,"self":KEY_M,"next":KEY_N,"clear":KEY_BACKSPACE}
static func validate_keys(raw:Variant)->Dictionary:
 if not raw is Dictionary or raw.size()!=ACTIONS.size():return {"ok":false,"reason":"需要四個獨立快捷鍵"}
 var result:={};var used:Array=[]
 for action in ACTIONS:
  var key:Variant=raw.get(action)
  if not (key is int or key is float) or not is_finite(float(key)) or float(key)!=floor(float(key)) or int(key) not in KEYS:return {"ok":false,"reason":"此按鍵與移動或既有功能衝突"}
  if int(key) in used:return {"ok":false,"reason":"快捷鍵不可重複"}
  result[action]=int(key);used.append(int(key))
 return {"ok":true,"keys":result}
static func validate_library(raw:Variant)->Dictionary:
 if not raw is Dictionary or not raw.get("layouts") is Array:return {"ok":false,"reason":"需要配置庫 layouts 陣列"}
 var version:Variant=raw.get("schema")
 if not (version is int or version is float) or float(version)!=1.0:return {"ok":false,"reason":"不支援的配置庫版本"}
 if raw.layouts.size()>MAX_LAYOUTS:return {"ok":false,"reason":"配置庫最多32組"}
 var names:Array=[];var result:Array=[]
 for layout in raw.layouts:
  var checked:=Markers.validate_layout(layout)
  if not checked.ok:return checked
  var name:=str(checked.layout.name).strip_edges()
  if name.is_empty() or name in names:return {"ok":false,"reason":"配置名稱不可留空或重複"}
  checked.layout.name=name;names.append(name);result.append(checked.layout)
 return {"ok":true,"library":{"schema":1,"layouts":result}}
static func store(library:Dictionary,layout:Dictionary,name:String,copy:bool=false)->Dictionary:
 var checked:=validate_library(library)
 if not checked.ok:return checked
 var candidate:=layout.duplicate(true);candidate.name=name.strip_edges().left(80)
 var result:Dictionary=checked.library
 var index:=-1
 for i in result.layouts.size():
  if result.layouts[i].name==candidate.name:index=i;break
 if index>=0 and copy:
  var base:=str(candidate.name).left(65);var n:=2
  while n<=MAX_LAYOUTS+1:
   candidate.name=base+" (%d)"%n;var exists:=false
   for item in result.layouts:
    if item.name==candidate.name:exists=true;break
   if not exists:break
   n+=1
  index=-1
 if index>=0:result.layouts[index]=candidate
 else:result.layouts.append(candidate)
 return validate_library(result)
static func rotated(layout:Dictionary,degrees:float)->Dictionary:
 if not is_finite(degrees):return {"ok":false,"reason":"旋轉角度必須為有限值"}
 var checked:=Markers.validate_layout(layout)
 if not checked.ok:return checked
 for mark in checked.layout.marks:
  var point:=Vector2(mark.pos[0],mark.pos[1]).rotated(deg_to_rad(degrees))
  mark.pos=[point.x,point.y]
 return Markers.validate_layout(checked.layout)
