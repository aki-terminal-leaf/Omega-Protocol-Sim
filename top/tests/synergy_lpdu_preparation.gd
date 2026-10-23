# SPDX-License-Identifier: MIT
extends SceneTree
const Main=preload("res://scenes/main.tscn")
const P=preload("res://scripts/synergy_preparation.gd")
const A=preload("res://scripts/synergy_assignment.gd")
const I=preload("res://scripts/interactions.gd")
const R=preload("res://scripts/rules.gd")
const Signs=preload("res://scripts/synergy_signs.gd")
var checks:=0
var failures:=0
var courses:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;print("SYNERGY LPDU PREPARATION FAIL ",label)
func choose(app,human:int=0,method:int=-1,seed_value:int=17391)->void:
 app.return_to_selection();app.phase_select.select(0);app.filter_catalog();app.role_select.select(human)
 for i in app.filtered.size():
  if app.filtered[i].id=="p2_synergy":
   app.choose_mechanic(i)
   if method<0:
    for n in range(1,app.strategy_select.item_count):
     var meta:Variant=app.strategy_select.get_item_metadata(n)
     if meta is Dictionary and meta.get("profile","")=="lpdu":method=n;break
   app.strategy_select.select(method);app.choose_strategy(method);break
 app.seed_edit.text=str(seed_value);app.demo=false;app.start_run(0,false);app.stop_failure.button_pressed=false
func advance(app,until:float,frame:float=.05)->void:
 var n:=0
 while app.running and float(app.state.sim_time)<until-.000001 and n<3000:
  app._process(minf(frame,until-float(app.state.sim_time)));n+=1
 check(float(app.state.sim_time)>=until-.000001,"Main reached %.3f"%until)
func _initialize()->void:call_deferred("run")
func run()->void:
 root.size=Vector2i(1440,900);root.gui_embed_subwindows=true
 var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false);app.arena.set_process(false)
 for human in 8:
  choose(app,human)
  var spawn:Vector2=R.v(app.actors[human].pos)
  check(app.state.human_actor==human and app.state.synergy_presentation_required,"ordinary practice ownership/source gate")
  check(app.arena.synergy_displayed_glyphs.is_empty() and app.state.synergy_preparation.glyphs.is_empty(),"cast has no glyph memory")
  for a in 8:check(I.bot_goal(a,app.current,app.actors,app.state)==P.queue_goal(a,{},"lpdu"),"pre-reveal static LPDU THMR rolequeue")
  advance(app,2.95)
  var before:Array=app.actors.map(func(a):return R.v(a.pos))
  app._process(.4)
  check(app.actors.map(func(a):return R.v(a.pos))==before,"cross-beat substeps cannot consume unpresented glyphs")
  check(app.arena.synergy_displayed_glyphs.size()==8 and app.state.synergy_preparation.basis=="displayed_textured_glyphs","eight actual textured sprites recorded after frame")
  var seen:Dictionary=app.state.synergy_preparation.duplicate(true)
  var assignment:Dictionary=A.assign(seen.glyphs,P.config("lpdu"))
  check(not assignment.is_empty(),"displayed input forms a full assignment")
  var frozen:Dictionary=app.state.duplicate(true)
  for a in 8:check(I.bot_goal(a,app.current,app.actors,app.state)==P.queue_goal(a,assignment),"only correct lower swaps horizontally, preserving role-row")
  check(app.state==frozen,"goal is read-only")
  advance(app,6.3)
  check(app.arena.synergy_displayed_glyphs.is_empty() and app.state.synergy_preparation.glyphs==seen.glyphs,"icons disappear while remembered symbols persist")
  check(R.v(app.actors[human].pos)==spawn,"human never auto-moved or silently rescued")
  app.paused=true;frozen=app.state.duplicate(true);app._process(.4);check(app.state==frozen,"pause cannot reveal future")
  app.paused=false;app.retry_beat()
  check(app.state.synergy_preparation.glyphs==seen.glyphs and app.arena.synergy_displayed_glyphs.is_empty(),"beat retry restores already-known public past without old sprite")
  advance(app,19.85)
  check(app.journal.any(func(entry):return entry.title=="Optimized Fire III" and not entry.failures.is_empty()),"omitted human movement causes actual Fire/Glitch failure")
  check(R.v(app.actors[human].pos)==spawn,"failed human remains owned before knockback")
  var event:=InputEventKey.new();event.physical_keycode=KEY_R;event.pressed=true
  app._unhandled_key_input(event)
  check(float(app.state.sim_time)==0 and app.index==0 and app.state.synergy_preparation.glyphs.is_empty() and app.arena.synergy_displayed_glyphs.is_empty(),"actual R restarts whole mechanism fresh, no future memory")
 # A cached public past cannot be reinterpreted as a different guide's role convention.
 choose(app);advance(app,3.2)
 check(app.active_profile.id=="lpdu" and app.state.synergy_preparation.profile_id=="lpdu","actual LPDU profile and cache binding")
 var preserved_beat:Dictionary=app.current.duplicate(true)
 var foreign:Dictionary=P.config("elemental");foreign.merge({"phase":"remember","remote":app.current.synergy_public.remote,"eye_angle":app.current.synergy_public.eye_angle,"north":app.current.synergy_public.north})
 app.current.synergy_public=foreign
 check(P.memory(app.current,app.state).is_empty(),"LPDU memory cannot steer Elemental guide")
 app.current=preserved_beat
 check(not P.memory(app.current,app.state).is_empty(),"read-only foreign check does not corrupt valid LPDU past")
 # Partial current receipts cannot be completed from latent pair/pose fields.
 # Exact snapshot window close preserves a valid earlier observed public past.
 choose(app);advance(app,3.2);var remembered:Dictionary=app.state.synergy_preparation.duplicate(true)
 advance(app,6.1)
 check(not app.state.synergy_preparation.blocked and app.state.synergy_preparation.glyphs==remembered.glyphs,"Main frame ending at remember close retains observed glyphs")
 app._process(.001);check(app.arena.synergy_displayed_glyphs.is_empty(),"next beat removes final glyph sprites")
 choose(app);app.start_run(6,false)
 check(app.checkpoint_assisted and not app.state.synergy_preparation.blocked and app.state.synergy_preparation.basis=="assisted_checkpoint_not_observed","checkpoint at knock retains only synthetic valid past")
 check(app.state.runtime_failures.is_empty(),"checkpoint through Fire/Laser has no synthetic-past physical errors")
 # Genuine missing textures: absent source is not reconstructed from party dicts.
 choose(app);advance(app,2.95)
 var textures:Dictionary=Signs.textures.duplicate()
 for shape in A.SHAPES:Signs.textures[shape]=null
 advance(app,3.4)
 check(app.arena.synergy_displayed_glyphs.is_empty() and app.state.synergy_preparation.glyphs.is_empty(),"unavailable textures cannot publish hidden glyph dictionaries")
 for a in 8:check(I.bot_goal(a,app.current,app.actors,app.state)==P.queue_goal(a,{},"lpdu"),"source missing holds initial rolequeue")
 Signs.textures=textures;app.arena.update_state(app.actors,app.current,0,false,app.elapsed,app.state);app.publish_observed_cues()
 check(app.state.synergy_preparation.glyphs.size()==8,"a newly available current source can be observed")
 # Incomplete/contradictory receipts poison an epoch, never silently guess/recover.
 choose(app);advance(app,2.95);textures=Signs.textures.duplicate();Signs.textures.circle=null
 advance(app,3.4)
 check(app.arena.synergy_displayed_glyphs.size()==6 and app.state.synergy_preparation.blocked,"partial actual source fails closed")
 Signs.textures=textures;app.arena.update_state(app.actors,app.current,0,false,app.elapsed,app.state);app.publish_observed_cues()
 check(app.state.synergy_preparation.glyphs.is_empty() and app.state.synergy_preparation.blocked,"no hidden fallback repair of incomplete receipt")
 # Public-only routing: solved beat poses and true encounter pair order cannot steer remembered assignment.
 choose(app);advance(app,13.5)
 var goals:Array=[]
 for a in 8:goals.append(I.bot_goal(a,app.current,app.actors,app.state))
 var truth:Dictionary=app.current.duplicate(true)
 for a in 8:app.current.positions[a]=Vector2(18,0)
 app.encounter.assignments.reverse()
 check(range(8).all(func(a):return I.bot_goal(a,app.current,app.actors,app.state)==goals[a]),"Fire planner uses public memory, not baked route/RNG answer")
 app.current=truth
 var json_state:Dictionary=JSON.parse_string(JSON.stringify(app.json_safe(app.state)))
 check(range(8).all(func(a):return I.bot_goal(a,app.current,app.actors,json_state).distance_to(goals[a])<.00001),"restored JSON public cache works")
 # Checkpoint is explicitly synthetic, does not counterfeit displayed/manual past.
 choose(app);app.start_run(4,false)
 check(app.checkpoint_assisted and app.state.get("synergy_checkpoint_assisted",false),"checkpoint assistance explicit")
 check(app.state.synergy_preparation.basis=="assisted_checkpoint_not_observed" and app.report().checkpoint_assisted,"synthetic source remains assisted")
 check(app.state.runtime_failures.is_empty() and app.state.dead.is_empty(),"assisted past physically reconstructed without erasing errors")
 check(app.feedback.text.contains("分段輔助"),"assistance is visible")
 app.start_run(0,false)
 check(not app.state.get("synergy_checkpoint_assisted",false) and app.state.synergy_preparation.glyphs.is_empty(),"fresh restart removes synthetic past/credit")
 # Complete LPDU generated courses only; shared five-profile regression is a separate existing gate.
 for method in [-1]:
  for seed_value in [17391,7,43]:
   choose(app,0,method,seed_value);app.demo=true;app.start_run(0,false);app.stop_failure.button_pressed=false
   var total:float=0.0
   for beat in app.encounter.beats:total+=float(beat.duration)
   advance(app,total,.1)
   if app.running:app._process(.001)
   check(absf(float(app.state.sim_time)-total)<.00001,"final transition adds no extra simulation time")
   check(app.all_errors.is_empty() and app.state.runtime_failures.is_empty(),"full generated P2 method%d seed%d %s"%[method,seed_value,str(app.all_errors)])
   check(not app.running and app.journal.size()==11,"standalone course completes only its own11 snapshots running=%s pending=%s index=%d journal=%d time=%.12f total=%.12f elapsed=%.12f"%[app.running,app.pending_advance,app.index,app.journal.size(),float(app.state.sim_time),total,app.elapsed])
   if method==-1:
    check(app.state.synergy_preparation.basis=="displayed_textured_glyphs" and app.state.synergy_preparation.stacks_basis=="displayed_textured_glyphs","actual glyph and stack sprite receipts")
   courses+=1
 app.return_to_selection();check(app.arena.synergy_displayed_glyphs.is_empty(),"selection clears receipt")
 app.queue_free();await process_frame
 print("SYNERGY_LPDU_PREPARATION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"courses":courses,"scope":"actual headless Main scene sprites/cache/substeps/ownership/omission/physical Fire failure/checkpoints and generated courses; not manual/native/Web/allguide certification"}))
 quit(1 if failures else 0)
