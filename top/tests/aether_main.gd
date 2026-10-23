# SPDX-License-Identifier: MIT
extends SceneTree
# Parent actual Main integration; no native/full-guide credit.
const Main=preload("res://scenes/main.tscn")
const P=preload("res://scripts/synergy_preparation.gd")
const I=preload("res://scripts/interactions.gd")
const R=preload("res://scripts/rules.gd")
const Signs=preload("res://scripts/synergy_signs.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;print("AETHER MAIN FAIL ",label)
func choose(app,human:int=0,seed_value:int=17391):
 app.return_to_selection();app.phase_select.select(0);app.filter_catalog();app.role_select.select(human)
 var found:=false
 for n in app.filtered.size():
  if app.filtered[n].id=="p2_synergy":
   app.choose_mechanic(n)
   for k in range(1,app.strategy_select.item_count):
    var m:Variant=app.strategy_select.get_item_metadata(k)
    if m is Dictionary and str(m.get("profile",""))=="aether":app.strategy_select.select(k);app.choose_strategy(k);found=true;break
   break
 check(found,"actual Aether option exists")
 app.seed_edit.text=str(seed_value);app.demo=false;app.fresh_seed.button_pressed=false;app.start_run(0,false);app.stop_failure.button_pressed=false
func advance(app,until:float):
 var count:=0
 while app.running and float(app.state.sim_time)<until-.000001 and count<5000:
  app._process(minf(.025,until-float(app.state.sim_time)));count+=1
 check(float(app.state.sim_time)>=until-.000001,"Main reached %.3f"%until)
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900);root.gui_embed_subwindows=true
 var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false);app.arena.set_process(false)
 var default_spawn:Array=[]
 for human in 8:
  choose(app,human)
  var spawn:Array=app.actors.map(func(a):return R.v(a.pos))
  if default_spawn.is_empty():default_spawn=spawn.duplicate()
  check(spawn==default_spawn,"independent recommended spawn independent of human selection")
  check(app.state.human_actor==human and not app.demo and not app.checkpoint_assisted,"ordinary player ownership")
  check(app.arena.synergy_displayed_glyphs.is_empty() and app.state.synergy_preparation.glyphs.is_empty(),"no pre-glyph assignment")
  advance(app,2.95);var prior:Array=app.actors.map(func(a):return R.v(a.pos));app._process(.4)
  check(app.actors.map(func(a):return R.v(a.pos))==prior,"cross-beat substeps cannot consume undisplayed future glyphs")
  check(app.arena.synergy_displayed_glyphs.size()==8,"actual eight textured glyphs")
  var seen:Dictionary=app.state.synergy_preparation.duplicate(true)
  check(seen.glyphs.size()==8 and seen.basis=="displayed_textured_glyphs","only actually displayed receipt accepted")
  var actual:Array=app.actors.map(func(a):return [float(a.pos.x),float(a.pos.y)])
  check(seen.get("positions",[])==actual,"frozen poses belong to same presented Main frame")
  check(not P.memory(app.current,app.state).is_empty(),"displayed memory validates")
  advance(app,6.3)
  check(app.arena.synergy_displayed_glyphs.is_empty() and app.state.synergy_preparation.positions==seen.positions,"glyphs disappear; frozen past retained")
  check(R.v(app.actors[human].pos)==spawn[human],"legal stationary human never moved/rescued")
  check(app.all_errors.is_empty() and app.state.runtime_failures.is_empty(),"no phantom queue penalty before weapon combat")
  app.retry_beat()
  check(not app.state.synergy_preparation.glyphs.is_empty(),"beat retry retains legitimately remembered public past")
  var key:=InputEventKey.new();key.physical_keycode=KEY_R;key.pressed=true;app._unhandled_key_input(key)
  check(float(app.state.sim_time)==0 and app.index==0 and app.state.synergy_preparation.glyphs.is_empty(),"actual R clears whole mechanism memory")
  check(app.state.synergy_preparation.get("positions",null)==null,"actual R clears frozen position receipt")
 # Different actual generated pair order cannot alter independent spawn.
 for seed_value in [7,43]:
  choose(app,0,seed_value);check(app.actors.map(func(a):return R.v(a.pos))==default_spawn,"default spawn does not reveal true generated pairs")
 # Genuine missing textured publication is not repaired from hidden pair dictionaries.
 choose(app);advance(app,2.95);var textures:Dictionary=Signs.textures.duplicate()
 for shape in ["cross","square","circle","triangle"]:Signs.textures[shape]=null
 advance(app,3.4)
 check(app.arena.synergy_displayed_glyphs.is_empty() and app.state.synergy_preparation.glyphs.is_empty(),"missing actual textures cannot counterfeit eight glyph receipt")
 Signs.textures=textures;app.arena.update_state(app.actors,app.current,app.player,false,app.elapsed,app.state);app.publish_observed_cues()
 check(app.state.synergy_preparation.glyphs.size()==8,"new valid displayed source may be observed")
 choose(app);advance(app,3.4);var past:Dictionary=app.state.synergy_preparation.duplicate(true)
 advance(app,6.1)
 check(not app.state.synergy_preparation.blocked and app.state.synergy_preparation.positions==past.positions,"exact closing boundary preserves already observed receipt")
 # Actual physical movement after capture cannot rewrite observed rank/past.
 choose(app);advance(app,3.4);past=app.state.synergy_preparation.duplicate(true)
 app.reset_camera();var focused=app.get_viewport().gui_get_focus_owner()
 if focused:focused.release_focus()
 var down:=InputEventKey.new();down.physical_keycode=KEY_D;down.keycode=KEY_D;down.pressed=true;Input.parse_input_event(down);Input.flush_buffered_events()
 var before:Vector2=R.v(app.actors[app.player].pos);app._process(.2)
 var up:=InputEventKey.new();up.physical_keycode=KEY_D;up.keycode=KEY_D;up.pressed=false;Input.parse_input_event(up);Input.flush_buffered_events()
 check(before.distance_to(R.v(app.actors[app.player].pos))>1.0,"actual physical key moved human after observation")
 check(not app.state.synergy_preparation.blocked and app.state.synergy_preparation.positions==past.positions,"repeated glyph publication uses frozen past, not newly moved actors")
 # Full cache survives report JSON round-trip; future hidden routes cannot steer goals.
 advance(app,13.5)
 var goals:Array=[]
 for a in 8:goals.append(I.bot_goal(a,app.current,app.actors,app.state))
 var restored:Dictionary=JSON.parse_string(JSON.stringify(app.json_safe(app.state)))
 check(range(8).all(func(a):return I.bot_goal(a,app.current,app.actors,restored).distance_to(goals[a])<.00001),"JSON-safe cached poses preserve exact public routing")
 for a in 8:app.current.positions[a]=Vector2(18,0)
 app.encounter.assignments.reverse()
 check(range(8).all(func(a):return I.bot_goal(a,app.current,app.actors,app.state)==goals[a]),"NPC Fire routing does not consume baked truth")
 choose(app);app.start_run(4,false)
 check(app.checkpoint_assisted and app.state.synergy_preparation.basis=="assisted_checkpoint_not_observed","checkpoint synthetic receipt explicitly assisted")
 app.start_run(0,false);check(not app.checkpoint_assisted and app.state.synergy_preparation.glyphs.is_empty(),"fresh start clears synthetic credit")
 app.queue_free();await process_frame
 print("AETHER_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"actual headless Main sprites, physical post-capture key, missing textures, JSON/public past/R/assistance; not all8rank physical/fullguide/native"}))
 quit(1 if failures else 0)
