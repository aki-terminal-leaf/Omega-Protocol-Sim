extends SceneTree
const Main=preload("res://scenes/main.tscn")
const Signs=preload("res://scripts/synergy_signs.gd")
var checks:=0
var failures:=0
func check(ok:bool,title:String)->void:
 checks+=1
 if not ok:failures+=1;print("OBSERVED_MARKER FAIL ",title)
func choose(app,id:String)->void:
 for i in app.filtered.size():
  if app.filtered[i].id==id:
   app.choose_mechanic(i);app.strategy_select.select(1);app.choose_strategy(1);app.seed_edit.text="42";app.demo=true;app.hints.button_pressed=false;app.speed_select.select(2);app.start_run(0,false);app.stop_failure.button_pressed=false;return
func advance(app,t:float)->void:
 while app.running and float(app.state.sim_time)<t-0.000001:app._process(minf(0.1,t-float(app.state.sim_time)))
 app.arena._process(0.08)
func visible(app)->int:return app.arena.mechanic_signs.filter(func(s):return s.visible and s.texture!=null).size()
func _initialize()->void:call_deferred("run")
func run()->void:
 var app=Main.instantiate();root.add_child(app);await process_frame;app.set_process(false);app.arena.set_process(false)
 choose(app,"p1_cannons");advance(app,0.1);check(visible(app)==3,"P1 first three actual cannon targets before impact");advance(app,6.1);check(visible(app)==0,"P1 clears hit markers and does not leak second set");advance(app,10.0);check(visible(app)==3,"P1 second three markers after3.9s delay");advance(app,15.05);check(visible(app)==0,"P1 second set consumed")
 await process_frame
 choose(app,"p1_panto");advance(app,3.0);check(app.current.shapes.filter(func(s):return s.get("name","")=="Flamethrower").size()==2,"four-second initial Flame Thrower cast cue, not common two-second placeholder")
 await process_frame
 choose(app,"p2_synergy");advance(app,4.0);check(visible(app)==8,"PT eight actual PlayStation signs");advance(app,7.0);check(visible(app)==0,"PT no symbols during fake/genuine read");check(app.arena.stage_nodes.filter(func(n):return n.visible and n.name.begins_with("OpticalUnit")).size()==1,"PT one real outside eye source, not P6 scenery")
 await process_frame
 choose(app,"p2_limitless");advance(app,19.5);check(visible(app)==3,"Limitless three actual Flare heads");check(app.current.stage_entities.filter(func(e):return e.form=="optical_unit").size()==1,"Limitless eye remains for Cosmo Memory");advance(app,27.5);check(visible(app)==0,"Limitless Flare heads removed at impact")
 await process_frame
 choose(app,"p3_transition");advance(app,1.0);check(app.current.shapes.any(func(s):return s.get("name","")=="Wave Repeater"),"first ring telegraph follows five-second cast");check(app.current.shapes.filter(func(s):return str(s.get("name","")).contains("Sniper radius")).all(func(s):return s.get("instructional",false)),"unsourced sniper safe-area previews are teaching-only")
 await process_frame
 choose(app,"p4_wave");advance(app,3.0);check(visible(app)==2,"P4 actual two line-stack target heads");advance(app,9.0);check(app.current.shapes.any(func(s):return s.get("p4_wave_preview",false) and str(s.get("name","")).contains("Wave Repeater")),"P4 initial circle uses five-second cast cue")
 await process_frame
 choose(app,"p5_delta");advance(app,1.0);check(app.current.stage_entities.filter(func(e):return e.form=="optical_unit").size()==1,"Delta existing eye proxy gains visible reconstruction without duplicate")
 await process_frame
 choose(app,"p5_sigma");advance(app,1.0);check(visible(app)==8,"Sigma eight paired graphical signs");advance(app,10.3);check(visible(app)==8 and app.arena.secondary_mechanic_signs.filter(func(s):return s.visible and s.texture!=null).size()==6,"Sigma pair symbols and six cannon marks simultaneously, not mutually overwriting");advance(app,19.4);check(visible(app)==0 and app.arena.secondary_mechanic_signs.all(func(s):return not s.visible),"Sigma both sets disappear before towers")
 await process_frame
 choose(app,"p5_solar");check(is_equal_approx(float(app.encounter.beats[0].duration),5.0) and is_equal_approx(float(app.encounter.beats[1].duration),3.2),"Solar actual5s cast +3.2s second hit");check(app.encounter.beats.all(func(b):return b.shapes[0].radius==5),"Solar actual radius5, not4")
 await process_frame
 choose(app,"p6_meteors");advance(app,20.3);check(visible(app)==3,"P6 actual three Flare heads at recorded marker time");advance(app,28.4);check(visible(app)==0,"P6 Flare heads removed on actual resolution")
 for name in ["O","X","Triangle","Square","cannon","stack","flare"]:check(Signs.texture(name)!=null,"vector marker texture "+name)
 check(app.all_errors.is_empty(),"marker presentation does not change authoritative outcomes")
 app.queue_free();await process_frame;print("OBSERVED_MARKER_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
