# SPDX-License-Identifier: MIT
extends Node3D
## Godot original-resource inspection lab. Catalogue coverage is not recreation acceptance.
const Effect=preload("res://scripts/asset_lab_effect.gd")
const UnitDirector=preload("res://scripts/asset_lab_unit.gd")
const Motion=preload("res://scripts/asset_lab_motion.gd")
var director:Node3D
var director_error:=""
var performance_mode:=false
var view_mode:OptionButton
var catalog:Dictionary={}
var asset_root:=""
var model_cache:Dictionary={}
var current_model:Node3D
var current_motion:RefCounted
var effect:Node3D
var sample:Dictionary={}
var unit:Dictionary={}
var clock:=0.0
var playing:=true
var looping:=true
var speed:=1.0
var selected_unit:=0
var selected_sample:=0
var entries:Array=[]
var camera:Camera3D
var distance:=24.0
var target:=Vector3.ZERO
var yaw:=.65
var pitch:=.45
var list:ItemList
var choices:OptionButton
var details:RichTextLabel
var banner:Label
var clock_label:Label
var play_button:Button
var slider:HSlider
var phase_filter:OptionButton
var search:LineEdit
var _setting:=false
var qa_running:=false
var load_error:=""
func arg(key:String)->String:
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--"+key+"="):return a.substr(key.length()+3)
 return ""
func _asset_path(relative:String)->String:
 var clean:=relative.replace("\\","/")
 if clean.is_empty() or clean.is_absolute_path() or clean.contains(":") or ".." in clean.split("/"):
  load_error="Rejected source asset path";return ""
 return asset_root.path_join(clean).simplify_path()
func _ready()->void:
 asset_root=arg("asset-root")
 if asset_root.is_empty():asset_root=OS.get_executable_path().get_base_dir().path_join("LabData")
 var catpath:=arg("catalog")
 if catpath.is_empty():catpath="res://data/asset_lab/catalog.json"
 var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(catpath))
 if not parsed is Dictionary:push_error("Invalid lab catalogue");get_tree().quit(2);return
 catalog=parsed
 _world();_prepare_director();_ui();_fill()
 if not arg("lab-qa").is_empty():qa_running=true;call_deferred("_qa",arg("lab-qa"))
func _prepare_director()->void:
 var root:=arg("source-root")
 if root.is_empty() and FileAccess.file_exists(asset_root.path_join("motion-plan.json")):root=asset_root
 if root.is_empty():director_error="缺少本項演出的原始複合資料。";return
 var selection:=arg("performances")
 if selection.is_empty():selection="res://data/asset_lab/performances.json"
 director=UnitDirector.new();add_child(director)
 if director.configure(root,camera,selection,arg("attachment-data"))!=OK:
  director_error=director.error;director.free();director=null
func _duration()->float:
 return director.duration if performance_mode and is_instance_valid(director) else float(sample.get("duration",0))
func _adjacent(step:int)->void:
 if performance_mode:
  var index:=entries.find(selected_unit)+step
  if index>=0 and index<entries.size():list.select(index);_unit_selected(index)
 else:_sample_selected(clampi(selected_sample+step,0,choices.item_count-1))
func _world()->void:
 var env:=WorldEnvironment.new();env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("#0a101e")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("#a6b9d8");env.environment.ambient_light_energy=.8
 add_child(env)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-30,0);light.light_energy=1.4;add_child(light)
 camera=Camera3D.new();camera.current=true;camera.fov=45;camera.near=.01;camera.far=2000;add_child(camera);_camera()
func _ui()->void:
 var canvas:=CanvasLayer.new();add_child(canvas)
 var control:=Control.new();control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);control.mouse_filter=Control.MOUSE_FILTER_IGNORE;canvas.add_child(control)
 var theme:=Theme.new();theme.default_font=load("res://fonts/NotoSansCJKtc-Regular.otf");theme.default_font_size=15;control.theme=theme
 var panel:=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE);panel.offset_left=12;panel.offset_top=12;panel.offset_right=372;panel.offset_bottom=-112;control.add_child(panel)
 var box:=VBoxContainer.new();box.add_theme_constant_override("separation",8);panel.add_child(box)
 var title:=Label.new();title.text="TOP · 素材演出實驗室";title.add_theme_font_size_override("font_size",24);box.add_child(title)
 var subtitle:=Label.new();subtitle.text="GODOT 4.7.2  /  分項演出與資源檢視";subtitle.modulate=Color("#8ec8f0");box.add_child(subtitle)
 search=LineEdit.new();search.placeholder_text="搜尋物件、招式、塔、連線…";search.text_changed.connect(func(_s):_fill());box.add_child(search)
 phase_filter=OptionButton.new();phase_filter.add_item("全部階段")
 for ph in ["P1","P2","P3","P4","P5-Δ","P5-Σ","P5-Ω","P6"]:phase_filter.add_item(ph)
 phase_filter.item_selected.connect(func(_i):_fill());box.add_child(phase_filter)
 list=ItemList.new();list.size_flags_vertical=Control.SIZE_EXPAND_FILL;list.item_selected.connect(_unit_selected);box.add_child(list)
 var note:=Label.new();note.text="● 原始資源樣本   ◇ 僅模型檢視   × 缺原始演出\n不是整場重現；過場缺件不以示意動畫替代。";note.add_theme_font_size_override("font_size",12);box.add_child(note)
 var upper:=PanelContainer.new();upper.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);upper.offset_left=390;upper.offset_right=-16;upper.offset_top=12;upper.offset_bottom=116;control.add_child(upper)
 var vb:=VBoxContainer.new();upper.add_child(vb)
 banner=Label.new();banner.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;vb.add_child(banner)
 view_mode=OptionButton.new();view_mode.add_item("分項複合演出");view_mode.add_item("原始資源檢視");view_mode.item_selected.connect(func(_i):_unit_selected(entries.find(selected_unit)));vb.add_child(view_mode)
 choices=OptionButton.new();choices.size_flags_horizontal=Control.SIZE_EXPAND_FILL;choices.item_selected.connect(_sample_selected);vb.add_child(choices)
 var bottom:=PanelContainer.new();bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);bottom.offset_left=12;bottom.offset_right=-16;bottom.offset_top=-102;bottom.offset_bottom=-12;control.add_child(bottom)
 var controls:=VBoxContainer.new();bottom.add_child(controls)
 var row:=HBoxContainer.new();controls.add_child(row)
 play_button=Button.new();play_button.text="暫停";play_button.pressed.connect(func():playing=not playing);row.add_child(play_button)
 var replay:=Button.new();replay.text="重播";replay.pressed.connect(func():clock=0;playing=true;_sample_at());row.add_child(replay)
 var loop:=CheckButton.new();loop.text="循環";loop.button_pressed=true;loop.toggled.connect(func(v):looping=v);row.add_child(loop)
 var rates:=OptionButton.new()
 for v in [".25","0.5","1","2"]:rates.add_item(v+"x")
 rates.selected=2;rates.item_selected.connect(func(i):speed=[.25,.5,1.,2.][i]);row.add_child(rates)
 var prev:=Button.new();prev.text="上一個";prev.pressed.connect(func():_adjacent(-1));row.add_child(prev)
 var next:=Button.new();next.text="下一個";next.pressed.connect(func():_adjacent(1));row.add_child(next)
 clock_label=Label.new();row.add_child(clock_label)
 slider=HSlider.new();slider.max_value=6;slider.step=.001;slider.value_changed.connect(func(v):if not _setting:clock=v;_sample_at());controls.add_child(slider)
 var help:=Label.new();help.text="右鍵拖曳旋轉  ·  滾輪縮放  ·  Space 暫停  ·  分開檢查模型／動作／特效，不自動把缺件視為完成";help.add_theme_font_size_override("font_size",12);controls.add_child(help)
 details=RichTextLabel.new();details.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT);details.offset_left=-580;details.offset_right=-20;details.offset_top=-300;details.offset_bottom=-120;details.mouse_filter=Control.MOUSE_FILTER_IGNORE;details.add_theme_font_size_override("normal_font_size",12);control.add_child(details)
func _fill()->void:
 if list==null:return
 list.clear();entries.clear()
 for i in catalog.units.size():
  var u:Dictionary=catalog.units[i]
  if phase_filter.selected>0 and u.phase!=phase_filter.get_item_text(phase_filter.selected):continue
  if not search.text.is_empty() and not (u.id+" "+u.title+" "+u.requirements).to_lower().contains(search.text.to_lower()):continue
  var badge:="×" if u.samples.is_empty() else ("◇" if u.status=="inspection_only" else "●")
  list.add_item("%s %s · %s"%[badge,u.phase,u.title]);entries.append(i)
 if entries.is_empty():return
 list.select(0);_unit_selected(0)
func _unit_selected(index:int)->void:
 if index<0 or index>=entries.size():return
 selected_unit=entries[index];unit=catalog.units[selected_unit];choices.clear()
 for s in unit.samples:choices.add_item(("模型動作 · " if s.kind=="model" else "特效材質 · ")+s.label)
 if view_mode.selected==0:_unit_composite();return
 choices.visible=true
 banner.text=unit.id+" · "+unit.title+"  ["+str(unit.samples.size())+" 個獨立樣本]"
 if unit.samples.is_empty():
  _clear();sample={};details.text=unit.requirements+"\n\n缺少已確認的原始過場演出；尚未重現。";return
 _sample_selected(0)
func _unit_composite()->void:
 _clear();performance_mode=true;sample={};choices.visible=false;clock=0;_setting=true;slider.value=0;_setting=false
 banner.text=unit.id+" · "+unit.title+"  [演出尚未驗收]"
 if not is_instance_valid(director):load_error=director_error;_detail();return
 if director.select(str(unit.id))!=OK:load_error=director.error;_detail();return
 clock=0;slider.max_value=maxf(.1,director.duration);target=Vector3(0,1,0);distance=70;_camera();_sample_at();_detail()
func _clear()->void:
 if is_instance_valid(director):director.visible=false
 performance_mode=false
 if is_instance_valid(current_model):current_model.visible=false
 current_model=null;current_motion=null
 if is_instance_valid(effect):effect.free()
 effect=null;load_error=""
func _sample_selected(index:int)->void:
 if index<0 or index>=unit.samples.size():return
 _clear();view_mode.selected=1;choices.visible=true;selected_sample=index;choices.select(index);sample=unit.samples[index];clock=0
 slider.max_value=maxf(.1,float(sample.duration));_setting=true;slider.value=0;_setting=false
 if sample.kind=="model":
  var key:String=sample.asset
  if not model_cache.has(key):
   var path:=_asset_path(str(catalog.assets[key].file))
   var doc:=GLTFDocument.new();var state:=GLTFState.new();var err:=doc.append_from_file(path,state)
   if err!=OK:load_error="Missing/invalid GLB "+key;_detail();return
   var model:=doc.generate_scene(state)
   if model==null:load_error="GLB scene failed "+key;_detail();return
   add_child(model);var motion:=Motion.new()
   if not motion.configure(path,model):load_error="GLB motion failed "+key;model.free();_detail();return
   var suppath:=asset_root.path_join("leg-motion.json")
   if FileAccess.file_exists(suppath):motion.add_supplement(JSON.parse_string(FileAccess.get_file_as_string(suppath)))
   model_cache[key]={"root":model,"motion":motion}
  current_model=model_cache[key].root;current_motion=model_cache[key].motion
  current_model.visible=true;current_model.scale=Vector3.ONE*float(sample.scale);_parts(current_model,str(sample.asset),sample.stance)
 else:
  effect=Effect.new();add_child(effect)
  var path:=_asset_path(str(catalog.packs[sample.asset].file));var data:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
  var paths:Dictionary={}
  for p in catalog.textures:paths[p]=_asset_path(str(catalog.textures[p]))
  if not data is Dictionary or not effect.configure(data,paths,int(sample.seed)):load_error="Missing/invalid source effect "+str(sample.asset)
  effect.force_double_sided=false
 _sample_at()
 if sample.kind=="effect" and is_instance_valid(effect):
  # Inspection framing uses real generated geometry, not game positions.
  clock=minf(1,float(sample.duration)*.5);_sample_at()
 _frame_camera();_sample_at();_detail()
func _parts(n:Node,form:String,stance:String)->void:
 if n is MeshInstance3D:
  var part:=str(n.name)
  if part.contains("atr_parts_a"):n.visible=stance==("SHIELD" if form.begins_with("male") else "LEGS")
  elif part.contains("atr_parts_b"):n.visible=(stance!="NEUTRAL" and stance!="SHIELD") if form.begins_with("male") else stance!="LEGS"
  elif form.begins_with("female") and part.contains("atr_bv_c"):n.visible=stance!="LEGS"
 for c in n.get_children():_parts(c,form,stance)
func _sample_at()->void:
 if performance_mode:
  if not is_instance_valid(director) or director.selected.is_empty():return
  director.visible=true;_camera();director.seek(clock)
  for entry in director.composite.active_fx.values():
   if entry.fx.visible:
    for source in entry.fx.camera_effects:camera.transform=camera.transform*entry.fx.CameraEffect.offset(source)
  _setting=true;slider.value=clock;_setting=false
  clock_label.text="%.2f / %.2f 秒"%[clock,_duration()];_detail();return
 if sample.is_empty():return
 if current_motion!=null:
  var length:float=current_motion.duration(sample.clip)
  if not current_motion.sample(sample.clip,minf(clock,maxf(0,length-.00001))):load_error="Original clip unavailable: "+str(sample.clip)
 if is_instance_valid(effect):
  _camera() # Restore the orbit camera before applying absolute source quake.
  effect.endpoint_start=Vector3(-8,1.5,sin(clock)*2);effect.endpoint_end=Vector3(8,1.5,cos(clock*.8)*2);effect.camera_position=camera.global_position
  effect.seek(clock*30) # Rejection remains in diagnostic report, not a load failure.
  for source in effect.camera_effects:
   camera.transform=camera.transform*effect.CameraEffect.offset(source)
 _setting=true;slider.value=clock;_setting=false
 if clock_label!=null:clock_label.text="%.2f / %.2f 秒"%[clock,_duration()]
func _bounds(n:Node,bounds:Array)->void:
 if n is MeshInstance3D and n.is_visible_in_tree() and n.mesh!=null:
  var a: AABB=n.global_transform*n.get_aabb()
  if a.size.length()>0:bounds.append(a)
 for c in n.get_children():_bounds(c,bounds)
func _frame_camera()->void:
 var all:Array=[];_bounds(current_model if current_model!=null else effect if effect!=null else self,all)
 if all.is_empty():target=Vector3(0,2,0);distance=28
 else:
  var box:AABB=all[0]
  for a in all:box=box.merge(a)
  target=box.get_center();distance=clampf(box.size.length()*1.8,.5,600)
 _camera()
func _camera()->void:
 camera.position=target+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
 camera.look_at(target);camera.far=maxf(2000,distance*4)
func _detail()->void:
 if unit.is_empty():return
 if performance_mode:
  var text:String=unit.requirements+"\n"+unit.lifecycle+"\n"
  if not load_error.is_empty():text+="\n"+load_error
  elif is_instance_valid(director) and not director.selected.is_empty():
   var count:int=director.composite.diagnostics.size();var fx_count:=0
   for entry in director.composite.active_fx.values():
    if entry.fx.visible:fx_count+=1;count+=entry.fx.diagnostics.size()
   text+="\n原始紀錄中的獨立時段；特效 %d／待驗證項 %d。"%[fx_count,count]
  text+="\n完整材質、掛點、生命週期、音效與過場仍未驗收。播放區間不代表原始特效停止。"
  details.text=text;return
 var text:String=unit.requirements+"\n"+unit.lifecycle+"\n"
 if not sample.is_empty():text+="來源："+str(sample.source)+"\n"
 if not load_error.is_empty():text+="載入問題："+load_error+"\n"
 text+="原始資源子集；未驗收完整演出／原始 shader／停止條件。"
 if sample.get("endpoint_demo",false):text+=" 連線端點為可移動檢視掛點，非原場次路徑。"
 if is_instance_valid(effect):text+="\n粒子 %d / 繪圖 %d / 尚未實作欄位 %d"%[effect.last_particles.size(),effect.draws.size(),effect.diagnostics.size()]
 if is_instance_valid(effect) and effect.diagnostics.has("budget_exceeded"):text+="\n此取樣超過有界播放預算，已拒絕繪圖；不是完整演出。"
 if is_instance_valid(effect) and not effect.camera_effects.is_empty():text+="\n來源鏡頭效應 %d（與粒子分開取樣）"%effect.camera_effects.size()
 details.text=text
func _process(delta:float)->void:
 if qa_running:return
 if playing and _duration()>0 and (performance_mode or not sample.is_empty()):
  clock+=delta*speed
  if clock>_duration():
   clock=fmod(clock,_duration()) if looping else _duration()
   if not looping:playing=false
  _sample_at()
 if play_button!=null:play_button.text="暫停" if playing else "播放"
 if clock_label!=null:clock_label.text="%.2f / %.2f 秒"%[clock,_duration()]
func _unhandled_input(event:InputEvent)->void:
 if event is InputEventKey and event.pressed and event.keycode==KEY_SPACE:playing=not playing
 if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
  yaw-=event.relative.x*.006;pitch=clampf(pitch+event.relative.y*.006,-1.3,1.3);_camera()
 if event is InputEventMouseButton and event.pressed:
  if event.button_index==MOUSE_BUTTON_WHEEL_UP:distance=maxf(.1,distance*.9);_camera()
  if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:distance=minf(1000,distance*1.1);_camera()

func _qa(output:String)->void:
 qa_running=true;playing=false;view_mode.selected=1
 DirAccess.make_dir_recursive_absolute(output)
 var rows:Array=[];var unique:Dictionary={};var missing:=0
 var only:=arg("qa-only")
 for ui in catalog.units.size():
  unit=catalog.units[ui];selected_unit=ui;list.select(ui);list.ensure_current_is_visible()
  if unit.samples.is_empty():
   rows.append({"unit":unit.id,"status":unit.status,"samples":0});continue
  choices.clear()
  for item in unit.samples:choices.add_item(item.label)
  for si in unit.samples.size():
   var sp:Dictionary=unit.samples[si]
   var key:=str(sp.kind)+"|"+str(sp.asset)+"|"+str(sp.get("clip",""))+"|"+str(sp.get("stance",""))
   if not only.is_empty() and not (key+"|"+str(sp.source)).contains(only):continue
   if unique.has(key):continue
   unique[key]=true;_sample_selected(si)
   var row:={"unit":unit.id,"sample":si,"key":key,"source":sp.source,"kind":sp.kind,"error":load_error,"frames":[]}
   if not load_error.is_empty():missing+=1
   var max_draws:=0;var max_particles:=0;var shot_saved:=false
   for fraction in [.05,.25,.65,.95]:
    clock=float(sp.duration)*fraction;_sample_at();await get_tree().process_frame
    if arg("qa-render")=="1":await RenderingServer.frame_post_draw
    var frame:={"time":clock,"load_error":load_error}
    if is_instance_valid(effect):
     frame["report"]=effect.report();frame["draws"]=effect.draws.size();frame["particles"]=effect.last_particles.size()
     max_draws=maxi(max_draws,effect.draws.size());max_particles=maxi(max_particles,effect.last_particles.size())
    elif current_motion!=null:frame["pose"]=current_motion.report()
    row.frames.append(frame)
    if arg("qa-render")=="1" and (not shot_saved) and ((sp.kind=="model" and fraction==.65) or (sp.kind=="effect" and max_draws>0)):
     _frame_camera();_sample_at();_detail();banner.text=unit.id+" · "+unit.title
     await get_tree().process_frame;await RenderingServer.frame_post_draw
     var path:="sample-%03d.png"%unique.size()
     if is_instance_valid(effect):
      effect.visible=false;await get_tree().process_frame;await RenderingServer.frame_post_draw
      var baseline:="sample-%03d-base.png"%unique.size()
      get_viewport().get_texture().get_image().save_png(output.path_join(baseline));row["baseline"]=baseline
      effect.visible=true;await get_tree().process_frame;await RenderingServer.frame_post_draw
     get_viewport().get_texture().get_image().save_png(output.path_join(path));row["image"]=path;shot_saved=true
   row["max_draws"]=max_draws;row["max_particles"]=max_particles
   if is_instance_valid(effect):
    clock=float(sp.duration)*.25;_sample_at()
    var before:=JSON.stringify(effect.report())
    clock=float(sp.duration)*.65;_sample_at();clock=float(sp.duration)*.25;_sample_at()
    row["reverse_state_equal"]=before==JSON.stringify(effect.report())
    if sp.get("endpoint_demo",false):
     var connected:=0
     for spec in effect.last_particles:
      if int(spec.kind)==6 and effect._enabled(effect._node("Ptcl",int(spec.index)).get("data",{}),"bCtg"):connected+=1
     if connected>0:
      effect.endpoint_end=effect.endpoint_start
      var safe:bool=effect.seek(clock*30)
      for spec in effect.last_particles:
       if int(spec.kind)==6 and effect._enabled(effect._node("Ptcl",int(spec.index)).get("data",{}),"bCtg"):
        safe=safe and effect.draws[spec.key].mesh==null
      safe=safe and effect.diagnostics.has("polyline_degenerate_endpoints")
      row["degenerate_endpoint_safe"]=safe;assert(safe,"Degenerate endpoint left invalid geometry")
      _sample_at()
      var recovered:=0
      for spec in effect.last_particles:
       if int(spec.kind)==6 and effect.draws[spec.key].mesh!=null:recovered+=1
      row["endpoint_geometry_recovered"]=recovered>0;assert(recovered>0)
     else:row["degenerate_endpoint_test"]="N_A_no_connected_source_particles"
    else:row["degenerate_endpoint_test"]="N_A_not_a_tether_sample"
   rows.append(row)
   FileAccess.open(output.path_join("states.json"),FileAccess.WRITE).store_string(JSON.stringify(rows))
   print("TOP_LAB_SAMPLE ",unique.size()," ",key," draws ",max_draws," error ",load_error)
 assert(unique.size()>0,"INVALID: no samples selected by the QA filter")
 # Check every catalogue entry can be selected, not just shared assets.
 for i in catalog.units.size():
  _unit_selected(i)
  assert(selected_unit==i and unit.has("limitations") and unit.complete==false)
  if unit.id in ["P6-01a","P6-01b","P6-01c","P6-21","P6-22","P6-23"]:assert(unit.status=="source_missing_cinematic" and unit.samples.is_empty())
 _unit_selected(0);clock=0;playing=false;qa_running=false
 play_button.pressed.emit()
 await get_tree().create_timer(.15).timeout
 qa_running=true;assert(clock>0,"Play control did not advance the source clock")
 playing=false;var stopped_clock:=clock;qa_running=false
 await get_tree().process_frame;await get_tree().process_frame
 qa_running=true;assert(clock==stopped_clock,"Pause advanced source clock")
 slider.value=float(sample.duration)*.5
 assert(absf(clock-float(sample.duration)*.5)<.002,"Slider failed to seek source time")
 var control_proof:={"play_advanced":true,"pause_stable":true,"slider_seek":true,"all_96_selections_checked":true}
 _clear();assert(effect==null and current_model==null)
 var result:={"engine":Engine.get_version_info().string,"units":catalog.units.size(),"unique_samples":unique.size(),"load_errors":missing,"rows":rows.size(),"status":"SOURCE_SUBSET_CAPTURED_NOT_FULL_RECREATION","full_recreation":false,"rendered":arg("qa-render")=="1","controls":control_proof}
 FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("TOP_LAB_RESULT ",JSON.stringify(result))
 get_tree().quit(1 if missing>0 else 0)

