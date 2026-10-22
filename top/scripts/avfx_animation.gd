# SPDX-License-Identifier: MIT
extends RefCounted
## Experimental native-unit curve evaluation. No original random-generator claim.
## Null means unsupported/malformed; callers must record it, not certify fidelity.
const LINKS=[{}, {"Y":"X","Z":"X"}, {"Y":"X"}, {"Z":"X"}, {"X":"Y","Z":"Y"}, {"X":"Y"}, {"Z":"Y"}, {"X":"Z","Y":"Z"}, {"X":"Z"}, {"Y":"Z"}]
static func value(curve:Dictionary,time:float)->Variant:
 if not is_finite(time):return null
 var keys:Array=curve.get("keys",[])
 if keys.is_empty():return null
 var rgb:=str(curve.get("kind","scalar"))=="rgb"
 for i in keys.size():
  if int(keys[i].type) not in [0,1,2]:return null
  if i>0 and float(keys[i].time)<=float(keys[i-1].time):return null
  for n in keys[i].data:
   if not is_finite(float(n)):return null
 if not curve.get("unknown_fields",[]).is_empty():return null
 var start:=float(keys[0].time);var end:=float(keys[-1].time);var t:=time;var cycles:=0.0
 if t<start or t>end:
  var behavior:Variant=curve.get("BvPr" if t<start else "BvPo")
  if behavior==null:return null
  if int(behavior)==0:t=clampf(t,start,end)
  elif int(behavior) in [1,2] and end>start:
   cycles=floor((t-start)/(end-start));t=start+fposmod(t-start,end-start)
   if int(behavior)==1:cycles=0.0
  else:return null
 var result:Variant=null
 for i in keys.size():
  if t==float(keys[i].time):result=_key(keys[i],rgb);break
  if i==0 or t>float(keys[i].time):continue
  var left:Dictionary=keys[i-1];var right:Dictionary=keys[i]
  var u:=(t-float(left.time))/(float(right.time)-float(left.time))
  if int(left.type)==2:u=0.0
  elif int(left.type)==0:
   if rgb:return null
   var half:=(float(right.time)-float(left.time))/2.0
   var x0:=float(left.time);var x3:=float(right.time)
   var x1:=x0+float(left.data[0])*half;var x2:=x3-float(left.data[1])*half
   var a:=x1-x0;var b:=x2-x1;var c:=x3-x2
   var qa:=a-2.0*b+c;var qb:=2.0*(b-a);var minimum:=minf(a,c)
   if qa>0.0:
    var critical:=-qb/(2.0*qa)
    if critical>0.0 and critical<1.0:minimum=minf(minimum,(qa*critical+qb)*critical+a)
   if minimum<0.0:return null
   var low:=0.0;var high:=1.0
   for _iteration in 48:
    var q:=(low+high)/2.0;var v:=1.0-q
    var x:=v*v*v*x0+3*v*v*q*x1+3*v*q*q*x2+q*q*q*x3
    if x<t:low=q
    else:high=q
   u=(low+high)/2.0;u=u*u*(3.0-2.0*u)
  var l:Variant=_key(left,rgb);var r:Variant=_key(right,rgb)
  result=l+(r-l)*u;break
 if result==null:return null
 if cycles!=0.0:result+=(_key(keys[-1],rgb)-_key(keys[0],rgb))*cycles
 return result
static func _key(key:Dictionary,rgb:bool)->Variant:
 return Vector3(float(key.data[0]),float(key.data[1]),float(key.data[2])) if rgb else float(key.data[2])
static func unit(seed_value:int,channel:String,tick:int=0)->float:
 # Explicit portable preview PRNG, not the game's private RNG. No global state.
 var bits:=2166136261
 for byte in (str(seed_value)+":"+channel+":"+str(tick)).to_utf8_buffer():bits=((bits^int(byte))*16777619)&0xffffffff
 bits=((bits^(bits>>16))*0x45d9f3b)&0xffffffff
 bits=((bits^(bits>>16))*0x45d9f3b)&0xffffffff
 bits=bits^(bits>>16)
 return float(bits&0xffffffff)/4294967296.0
static func random_value(mode:int,seed_value:int,channel:String,time:float)->Variant:
 if mode<0 or mode>5:return null
 var n:=unit(seed_value,channel,int(floor(time)) if mode>=3 else 0)
 match mode%3:
  0:return n*2.0-1.0
  1:return n
  2:return -n
 return null
static func scalar(curve:Dictionary,random_curve:Dictionary,time:float,seed_value:int,channel:String,default_value:float)->Variant:
 var result:Variant=default_value if curve.is_empty() else value(curve,time)
 if result==null:return null
 if not random_curve.is_empty():
  var amplitude:Variant=value(random_curve,time)
  if amplitude==null:return null
  if float(amplitude)!=0.0:
   var mode:Variant=curve.get("RanT",random_curve.get("RanT"))
   if mode==null:return null
   var n:Variant=random_value(int(mode),seed_value,channel,time)
   if n==null:return null
   result+=float(amplitude)*float(n)
 return result
static func axes(data:Dictionary,time:float,seed_value:int,channel:String,default_value:float)->Variant:
 var curves:Dictionary=data.get("axes",{});var raw:={};var random_axes:={}
 for axis in ["X","Y","Z"]:
  var main:Dictionary=curves.get(axis,{})
  var random_curve:Dictionary=curves.get(axis+"R",{})
  var base:Variant=default_value if main.is_empty() else value(main,time)
  var amplitude:Variant=0.0 if random_curve.is_empty() else value(random_curve,time)
  if base==null or amplitude==null:return null
  raw[axis]=base;random_axes[axis]=amplitude
 var link:Variant=data.get("ACT",0);var random_link:Variant=data.get("ACTR",0)
 if link==null or random_link==null or int(link)<0 or int(link)>=LINKS.size() or int(random_link)<0 or int(random_link)>=LINKS.size():return null
 var result:={}
 for axis in ["X","Y","Z"]:
  var main_axis:String=LINKS[int(link)].get(axis,axis)
  var random_axis:String=LINKS[int(random_link)].get(axis,axis)
  var main_curve:Dictionary=curves.get(main_axis,{})
  var mode:Variant=main_curve.get("RanT",curves.get(random_axis+"R",{}).get("RanT"))
  var offset:=0.0
  if float(random_axes[random_axis])!=0.0:
   if mode==null:return null
   var draw:Variant=random_value(int(mode),seed_value,channel+"/"+random_axis,time)
   if draw==null:return null
   offset=float(random_axes[random_axis])*float(draw)
  result[axis]=float(raw[main_axis])+offset
 return Vector3(result.X,result.Y,result.Z)
static func colour(data:Dictionary,time:float,seed_value:int,channel:String)->Variant:
 var rgb:Variant=Vector3.ONE if not data.has("RGB") else value(data.RGB,time)
 if rgb==null:return null
 var output:=Color(float(rgb.x),float(rgb.y),float(rgb.z),1.0)
 var alpha:Variant=scalar(data.get("A",{}),data.get("RanA",{}),time,seed_value,channel+"/A",1.0)
 var brightness:Variant=scalar(data.get("Bri",{}),data.get("RBri",{}),time,seed_value,channel+"/Bri",1.0)
 if alpha==null or brightness==null:return null
 for i in 4:
  var axis:String=["R","G","B","A"][i]
  var multiplier:Variant=scalar(data.get("Scl"+axis,{}),data.get("Ran"+axis,{}) if i<3 else {},time,seed_value,channel+"/"+axis,1.0)
  if multiplier==null:return null
  output[i]=(float(rgb[i])*float(brightness) if i<3 else float(alpha))*float(multiplier)
 return output
static func life(data:Dictionary,seed_value:int,channel:String)->Variant:
 if data.is_empty() or not data.get("enabled",true):return -1.0
 var base:Variant=data.get("Val");var amplitude:Variant=data.get("ValR")
 if base==null or amplitude==null:return null
 if float(amplitude)==0.0:return float(base)
 var mode:Variant=data.get("Type")
 if mode==null:return null
 var draw:Variant=random_value(int(mode),seed_value,channel,0)
 return null if draw==null else float(base)+float(amplitude)*float(draw)
