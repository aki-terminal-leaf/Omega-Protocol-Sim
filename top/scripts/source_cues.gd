# SPDX-License-Identifier: MIT
extends Node3D
## Original-resource presentation only. Never writes combat state or predicts NPC choices.
## TMB/PAP/AVFX local clocks are synchronized; original engine equivalence is NOT claimed.
const Player = preload("res://scripts/source_avfx_player.gd")
const Pose = preload("res://scripts/source_animation.gd")
const Rules = preload("res://scripts/rules.gd")
const Curves = preload("res://scripts/avfx_animation.gd")
const CATALOG = "res://assets/official/source/catalog.json"
const WEAPONS = {"Efficient Bladework":31526,"Beyond Strength":31525,"Superliminal Steel":31530,"Optimized Blizzard III":31533,"Optimized Blizzard":31533}
const WEAPON_TMB={31525:"chara/action/mon_sp/m0513/mon_sp021.tmb",31526:"chara/action/mon_sp/m0513/mon_sp015.tmb",31530:"chara/action/mon_sp/m0514/mon_sp006.tmb",31533:"chara/action/mon_sp/m0514/mon_sp005.tmb"}
const NAMES = {"Storage Violation":31492,"Blaster":31498,"Omega Blaster":32373,"Ballistic Missile":31500,"Flamethrower":31501,"Guided Missile Kyrios":31502,"Condensed Wave Cannon (3)":31503,"Wave Cannon Kyrios":31505,"Tank cleave":31504,"Optimized Fire III":31535,"Optical Laser":31521,"Spotlight":31536,"Optimized Sagittarius Arrow":31539,"Beyond Defense":31528,"Pile Pitch":31529,"Optimized Meteor":31538,"Colossal Blow":31566,"Sniper Cannon":31571,"High-powered Sniper Cannon":31572,"Critical Error":31588,"Hyper Pulse":31600,"Rotating Hyper Pulse":31600,"Furthest-player Hyper Pulse":31600,"Rocket Punch":31482,"Locked fist puddle":31482,"Swivel Cannon":31637,"Rear Power Unit":31631,"Sigma Wave Cannon":31604,"Omega Diffuse Wave Cannon":31608,"Cosmo Arrow":31652,"Concurrent Cosmo Arrow":31652,"Exaflare":31661,"Cosmo Meteor initial puddle":31667,"Wave Cannon puddle":31663,"Wave Cannon spread":31659,"Wave Cannon party stack":31662,"Cosmo Dive tank":31655,"Cosmo Dive party":31656,"Solar Ray":33196}
static var catalog:Dictionary={}
static var documents:Dictionary={}
static var samples:Dictionary={}
var arena:Node3D
var state_ref:Dictionary={}
var cursor:=0
var last_time:=-1.0
var effects:Dictionary={}
var animations:Dictionary={}
var scheduled:Dictionary={}
var diagnostics:Dictionary={}
var emitted:Array=[]
var phase:=1
var beat_ref:Dictionary={}
var beat_index:=-1
var beat_start:=0.0

func setup(owner_arena:Node3D)->void:
 arena=owner_arena
 if catalog.is_empty() and FileAccess.file_exists(CATALOG):
  var loaded:Variant=JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
  if loaded is Dictionary:catalog=loaded
func clear()->void:
 for item in animations.values():Pose.clear(item.binding)
 animations.clear()
 for item in effects.values():item.player.free()
 effects.clear();scheduled.clear();diagnostics.clear();emitted.clear();cursor=0;last_time=-1.0
 state_ref={};beat_ref={};beat_index=-1;beat_start=0.0
func _exit_tree()->void:
 for item in animations.values():Pose.clear(item.binding)
func update(state:Dictionary,beat:Dictionary,actors:Array,elapsed:float)->void:
 if catalog.is_empty() or not is_instance_valid(arena):return
 var now:=float(state.get("sim_time",0.0))
 if not is_same(state_ref,state) or now<last_time-0.000001:
  clear();state_ref=state
 phase=int(str(arena.encounter_id).substr(1,1))
 if actors.size()!=8:return
 # Original M/F tells are already physically revealed by the normal renderer.
 # Only those visible sources receive a pre-impact PAP wind-up. No future entity list.
 if not is_same(beat_ref,beat):
  beat_ref=beat;beat_index+=1;beat_start=now-elapsed
 var hit_at:=beat_start+float(beat.get("duration",0))
 for shape in beat.get("shapes",[]):
  var id:=int(WEAPONS.get(str(shape.get("name","")),0))
  if id==0 or shape.get("decorative",false):continue
  var origin:=Rules.point(shape,actors)
  var source:=find_source(id,origin)
  if source==null or not source.is_visible_in_tree():continue
  var lead:float={31525:20.0/30.0,31526:13.0/30.0}.get(id,0.0)
  if now+0.000001>=hit_at-lead:
   queue_action(id,origin,float(source.rotation_degrees.y),hit_at-lead,"weapon/%d/%d/%s"%[id,beat_index,source_identity(source)],source)
 var timeline:Array=state.get("timeline",[])
 if cursor>timeline.size():clear();state_ref=state
 for event_index in range(cursor,timeline.size()):consume(timeline[event_index],actors,event_index)
 cursor=timeline.size()
 if not is_equal_approx(now,last_time):
  sample_animations(now)
  sample_effects(now)
 last_time=now
func snapshot(beat:Dictionary,actors:Array,state:Dictionary)->void:
 if catalog.is_empty():return
 var now:=float(state.get("sim_time",0.0))
 for shape in beat.get("shapes",[]):
  if shape.get("decorative",false):continue
  if WEAPONS.has(str(shape.get("name",""))):continue # queued from visible model, with source wind-up
  shape_cue(shape,actors,now,"snapshot/%s"%now)
func shape_id(shape:Dictionary)->int:
 if shape.has("ability_id"):return int(shape.ability_id)
 var name:=str(shape.get("name",""))
 if WEAPONS.has(name):return int(WEAPONS[name])
 if NAMES.has(name):return int(NAMES[name])
 if name.begins_with("Wave Repeater "):return 31567+clampi(int(name.trim_prefix("Wave Repeater "))-1,0,3)
 return 0
func shape_cue(shape:Dictionary,actors:Array,at:float,key:String)->void:
 var id:=shape_id(shape)
 if id==0:return
 var origin:=Rules.point(shape,actors)
 var direction:=Rules.aim(shape,actors) if str(shape.get("kind","")) in ["line","cone","half"] else Vector2(0,-1)
 var yaw:=-rad_to_deg(atan2(direction.x,-direction.y))
 var source:=find_source(id,origin)
 queue_action(id,origin,yaw,at,key+"/%d/%s/%s"%[id,str(origin),yaw],source)
func consume(entry:Dictionary,actors:Array,event_index:int)->void:
 var kind:=str(entry.get("kind",""));var d:Dictionary=entry.get("details",entry)
 var observed:Array=d.get("observed_positions",d.get("positions",[]))
 if observed.size()==8 and observed.all(func(p):return p is Array and p.size()==2):
  actors=actors.duplicate(true)
  for i in 8:actors[i].pos=Rules.v(observed[i])
 var at:=float(entry.get("time",0));var key:="event/%d/%s/%s"%[event_index,kind,at]
 if d.get("shape") is Dictionary and (kind.ends_with("_hazard") or kind in ["p4_wave_repeat","p4_wave_ring"]):
  var shape:Dictionary=d.shape.duplicate(true)
  if d.has("ability_id"):shape.ability_id=d.ability_id
  if kind=="p4_wave_repeat":shape.ability_id=31616
  if kind=="p4_wave_ring":shape.ability_id=31567+int(d.get("ring",0))
  shape_cue(shape,actors,at,key)
 if kind=="p3_transition_ring":
  var shape:Dictionary=d.shape.duplicate(true);shape.ability_id=31567+int(d.ring);shape_cue(shape,actors,at,key)
 elif kind=="p3_transition_arm_hit":
  var p:=Rules.v(d.get("origin",[0,0]));queue_action(31566,p,0,at,key,find_source(31566,p))
 elif kind=="p3_transition_sniper":
  for packet in d.get("packets",[]):
   var who:=int(packet.owner);var p:=Rules.v(d.positions[who]);queue_action(int(packet.ability_id),p,0,at,key+"/%d"%who)
 elif kind=="p1_missile_beam":
  for who in d.get("missiles",[]):
   var p:=Rules.v(d.observed_positions[int(who)]);queue_action(31502,p,0,at,key+"/missile/%s"%who)
  for i in d.get("aims",[]).size():
   var v:=Rules.v(d.aims[i]);queue_action(31503,Vector2.ZERO,-rad_to_deg(atan2(v.x,-v.y)),at,key+"/beam/%d"%i)
 elif kind=="p1_proteans":
  for who in d.get("targets",[]):
   var v:=Rules.v(d.observed_positions[int(who)]).normalized();queue_action(31505,Vector2.ZERO,-rad_to_deg(atan2(v.x,-v.y)),at,key+"/%s"%who)
 elif kind=="p1_cleaves":
  for i in d.get("aims",[]).size():
   var v:=Rules.v(d.aims[i]);queue_action(31504,Vector2.ZERO,-rad_to_deg(atan2(v.x,-v.y)),at,key+"/%d"%i)
 elif kind=="p6_dive":
  for who in (d.get("tanks",[]) if d.get("observed_positions",[]).size()==8 else []):queue_action(31655,Rules.v(d.get("observed_positions",[])[int(who)]),0,at,key+"/%s"%who)
 consume_resolutions(kind,d,actors,at,key)
func consume_resolutions(kind:String,d:Dictionary,actors:Array,at:float,key:String)->void:
 match kind:
  "limitless_arrow":
   var shape:Dictionary=state_ref.get("limitless",{}).get("arrow",{}).duplicate(true)
   if not shape.is_empty():shape.ability_id=31539;shape_cue(shape,actors,at,key)
  "limitless_defense","limitless_pitch","delta_defense","delta_pile_pitch":
   if d.has("target"):
    var id:=31528 if kind.ends_with("defense") else 31529
    var point:=Rules.v(actors[int(d.target)].pos);queue_action(id,point,0,at,key,find_source(id,point))
  "limitless_flares":
   for i in d.get("origins",[]).size():queue_action(31538,Rules.v(d.origins[i]),0,at,key+"/%d"%i)
  "hw_tower":queue_action(31583 if d.get("colour","")=="red" else 31584,Rules.v(d.pos),0,at,key)
  "hw_blast":
   var id:=int({"red":31578,"blue":31579,"overflow":31575,"sync":31574}.get(str(d.get("status","")),0))
   if id>0 and d.has("pos"):queue_action(id,Rules.v(d.pos),0,at,key)
  "hw_critical_error":queue_action(31588,Vector2.ZERO,0,at,key,find_source(31588,Vector2.ZERO))
  "p4_wave_protean","p4_wave_stack":
   var shapes:Array=d.get("beams",d.get("lines",[]))
   for i in shapes.size():
    var shape:Dictionary=shapes[i].duplicate(true);shape.ability_id=31614 if kind=="p4_wave_protean" else 31615;shape_cue(shape,actors,at,key+"/%d"%i)
  "p6_proteans":
   for who in d.get("targets",[]):
    var point:=Rules.v(actors[int(who)].pos);queue_action(31659,Vector2.ZERO,-rad_to_deg(atan2(point.x,-point.y)),at,key+"/%s"%who)
  "p6_charge":
   var aim:=Rules.v(d.get("aim",[0,-1]));queue_action(31662,Vector2.ZERO,-rad_to_deg(atan2(aim.x,-aim.y)),at,key)
  "p6_dive":
   if d.has("stack_target"):queue_action(31656,Rules.v(actors[int(d.stack_target)].pos),0,at,key+"/stack")
  "p6_memory","p6_magic_number":
   var id:=31649 if kind=="p6_memory" else 31670;queue_action(id,Vector2.ZERO,0,at,key,find_source(id,Vector2.ZERO))
  "p6_spread":
   for who in d.get("targets",[]):queue_action(31667,Rules.v(actors[int(who)].pos),0,at,key+"/%s"%who)
  "p6_flares":
   for who in d.get("targets",[]):queue_action(31668,Rules.v(actors[int(who)].pos),0,at,key+"/%s"%who)
  "world_pulse":
   if d.has("receiver_position"):
    var id:=(31625 if int(d.get("pulse",0))==0 else 31626) if d.get("side","")=="near" else (33040 if int(d.get("pulse",0))==0 else 33041)
    queue_action(id,Rules.v(d.receiver_position),0,at,key)
func source_identity(source:Node3D)->String:
 var index:int=arena.stage_nodes.find(source)
 return "entity%d"%index if index>=0 else "boss%d"%arena.bosses.find(source)
func action_row(id:int,form:String="")->Dictionary:
 var rows:Array=catalog.get("actions",{}).get(str(id),[])
 for row in rows:
  if row.get("observed_form","")==form and int(row.phase)==phase:return row
 for row in rows:
  if row.get("observed_form","")==form:return row
 for row in rows:
  if int(row.phase)==phase and row.get("observed_form","")=="unbound":return row
 for row in rows:
  if int(row.phase)==phase:return row
 return rows[0] if not rows.is_empty() else {}
func find_source(id:int,origin:Vector2)->Node3D:
 var forms:Array=[]
 for row in catalog.get("actions",{}).get(str(id),[]):
  var f:=str(row.get("observed_form",""))
  if f!="unbound" and f not in forms:forms.append(f)
 if forms.is_empty():return null
 var best:Node3D=null;var distance:=INF
 for node in arena.stage_nodes+arena.bosses:
  if not is_instance_valid(node) or not node.is_visible_in_tree():continue
  var form:=str(node.get_meta("model_form",""));var normalized:=form.trim_suffix("_p5")
  if form not in forms and normalized not in forms and not (form=="optical_unit" and "optical" in forms):continue
  var gap:=Vector2(node.position.x,node.position.z).distance_squared_to(origin)
  if gap<distance:distance=gap;best=node
 return best
func queue_action(id:int,origin:Vector2,yaw:float,at:float,key:String,source:Node3D=null)->void:
 if scheduled.has(key):return
 scheduled[key]=true
 var form:=str(source.get_meta("model_form","")) if is_instance_valid(source) else "unbound"
 var row:=action_row(id,form);var tmb:=str(WEAPON_TMB.get(id,row.get("tmbs",{}).get("end","")))
 if tmb.is_empty() or not catalog.timelines.has(tmb):diagnostics["missing_action_timeline/%d"%id]=true;return
 var timeline:Dictionary=catalog.timelines[tmb]
 emitted.append({"ability":id,"at":at,"origin":[origin.x,origin.y],"tmb":tmb,"key":key,"phase":phase,"source":source_identity(source) if is_instance_valid(source) else "ground_or_target","tmb_time_origin":"source weapon windup" if key.begins_with("weapon/") else "actual resolution; local positive offsets retained"})
 if emitted.size()>256:emitted.pop_front()
 # Global source-space PAP sample, not ordinary glTF local animation.
 var animation_key:=form+"|"+tmb
 if is_instance_valid(source) and catalog.get("animations",{}).has(animation_key):
  var spec:Dictionary=catalog.animations[animation_key];var sample:=load_sample(str(spec.file))
  var owner:=str(source.get_instance_id())
  if animations.has(owner):Pose.clear(animations[owner].binding);animations.erase(owner)
  var binding:=Pose.configure(source,sample)
  if binding.get("ok",false):animations[owner]={"binding":binding,"start":at+float(spec.get("node_time",0))/30.0,"end":at+float(spec.duration_s),"source":source}
  else:diagnostics["animation/%s/%s"%[form,binding.get("error","")]]=true
 for node in timeline.get("nodes",[]):
  if node.get("tag","")!="C012":continue
  var path:=str(node.get("path",""))
  if path=="vfx/common/eff/cmma_shoot1c.avfx":continue
  if not catalog.packs.has(path):diagnostics["missing_pack/"+path]=true;continue
  var own:Dictionary=node.get("owner",{})
  if int(own.get("ability_delay",0))!=0 or int(own.get("track_time",0))!=0:
   diagnostics["unsupported_parent_timeline/"+tmb]=true;continue
  # Only root caster/target bindings are accepted here. EID bindings are per-particle below.
  var bind:Dictionary=node.get("bind_1",{})
  if int(bind.get("type",0))!=0 or int(bind.get("id",-1))!=-1:
   diagnostics["unsupported_TMB_attachment/"+path]=true;continue
  var effect_key:=key+"/%s"%node.get("id",0)
  var player:=Player.new();add_child(player)
  var doc:=load_document(path)
  if not player.configure(doc,catalog.textures,hash(effect_key)):
   player.free();diagnostics["invalid_pack/"+path]=true;continue
  # Source geometry faces +Z; arena mechanics face -Z. No arbitrary effect scale fitting.
  player.position=Vector3(origin.x,0.06,origin.y)
  player.rotation.y=deg_to_rad(yaw+180.0)
  var node_pos:Array=node.get("position",[0,0,0]);player.position+=player.basis*Vector3(node_pos[0],node_pos[1],node_pos[2])
  var rot:Array=node.get("rotation_radians",[0,0,0]);player.basis=player.basis*Basis.from_euler(Vector3(rot[0],rot[1],rot[2]))
  var scl:Array=node.get("scale",[1,1,1]);player.scale*=Vector3(scl[0],scl[1],scl[2])
  var start:=at+float(node.get("time",0))/30.0
  effects[effect_key]={"player":player,"start":start,"end":start+6.0,"source":source,"form":form,"ability":id,"path":path,"last_binders":{}}
  player.diagnostics["bounded_visual_lifetime_6s_not_original_stop"]=true
func load_document(path:String)->Dictionary:
 if not documents.has(path):documents[path]=JSON.parse_string(FileAccess.get_file_as_string(catalog.packs[path].file))
 return documents[path]
func load_sample(path:String)->Dictionary:
 if not samples.has(path):
  var bytes:=FileAccess.get_file_as_bytes(path)
  var decoded:=bytes.decompress_dynamic(32*1024*1024,FileAccess.COMPRESSION_GZIP)
  var value:Variant=JSON.parse_string(decoded.get_string_from_utf8())
  samples[path]=value if value is Dictionary else {}
 return samples[path]
func sample_animations(now:float)->void:
 for key in animations.keys():
  var item:Dictionary=animations[key]
  if not is_instance_valid(item.source) or now>float(item.end):Pose.clear(item.binding);animations.erase(key);continue
  if now>=float(item.start) and not Pose.seek(item.binding,now-float(item.start)):diagnostics["pose_seek/"+str(item.binding.get("error",""))]=true
func sample_effects(now:float)->void:
 for key in effects.keys():
  var item:Dictionary=effects[key];var player:Node3D=item.player
  if now>=float(item.end):player.free();effects.erase(key);continue
  player.visible=now>=float(item.start)
  if not player.visible:continue
  var age:=(now-float(item.start))*30.0
  if not player.seek(age):player.visible=false;diagnostics["effect_budget/"+item.path]=true;continue
  for spec in player.last_particles:
   var index:=int(spec.get("binder",-1))
   if index<0:continue
   var draw:MeshInstance3D=player.draws.get(spec.key)
   if draw==null:continue
   var pose:Variant=binder_transform(item,index,age)
   draw.visible=pose!=null
   if pose!=null:draw.transform=pose*spec.transform
func binder_transform(item:Dictionary,index:int,age:float)->Variant:
 var doc:Dictionary=item.player.document;var binds:Array=doc.get("groups",{}).get("Bind",[])
 if index>=binds.size():return null
 var prop:Dictionary=binds[index].get("properties",{}).get("PrpS",{})
 if prop.is_empty():return Transform3D.IDENTITY
 var pose:=Transform3D.IDENTITY;var typ:=int(prop.get("BPTP",0))
 if typ==3:
  var family:="m0514" if str(item.form).begins_with("female") else ("m0513" if str(item.form).begins_with("male") else "")
  var eid:Dictionary={}
  for row in catalog.get("eid",{}).get(family,{}).get("rows",[]):
   if int(row.id)==int(prop.get("BPID",-1)):eid=row;break
  var source:Node3D=item.source if is_instance_valid(item.source) else null
  var skel:Skeleton3D=find_skeleton(source) if source!=null else null
  var bone:=skel.find_bone(str(eid.get("bone",""))) if skel!=null else -1
  if bone<0:
   if item.last_binders.has(index):return item.last_binders[index]
   diagnostics["unresolved_EID/%s/%s"%[item.form,prop.get("BPID",-1)]]=true;return null
  var p:Array=eid.position;var r:Array=eid.rotation_radians
  var xf:=skel.global_transform*skel.get_bone_global_pose(bone)*Transform3D(Basis.from_euler(Vector3(r[0],r[1],r[2])),Vector3(p[0],p[1],p[2]))
  xf.basis=xf.basis.orthonormalized()
  pose=item.player.global_transform.affine_inverse()*xf
 elif typ not in [0,1]:diagnostics["unsupported_binder/%d"%typ]=true;return null
 var offset:Variant=Curves.axes(prop.get("Pos",{}),age,1,"binder%d"%index,0.0)
 if offset==null:return null
 pose=pose*Transform3D(Basis.IDENTITY,offset);item.last_binders[index]=pose
 return pose
static func find_skeleton(node:Node)->Skeleton3D:
 if node is Skeleton3D:return node
 for child in node.get_children():
  var found:=find_skeleton(child)
  if found!=null:return found
 return null
func report()->Dictionary:
 var active:Array=[]
 for item in effects.values():active.append({"ability":item.ability,"path":item.path,"start":item.start,"particles":item.player.last_particles.size(),"diagnostics":item.player.diagnostics.keys()})
 return {"source_resources":not catalog.is_empty(),"active":active,"animations":animations.size(),"emitted":emitted.duplicate(true),"diagnostics":diagnostics.keys(),"clock":"simulation seconds / source local 30Hz","rendering_complete":false,"optical_lid":"source default static pose; original dynamic timeline pending"}
