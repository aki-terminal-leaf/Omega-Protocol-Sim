extends SceneTree
const P=preload("res://scripts/synergy_preparation.gd")
func _init()->void:
 var beat:Dictionary={"synergy_public":P.config(),"party_statuses":[]};beat.synergy_public.merge({"phase":"cast","remote":false,"eye_angle":0.0,"north":0.0})
 var state:Dictionary={"sim_time":0.0,"synergy_presentation_required":true};P.begin(beat,state)
 beat.synergy_public.phase="remember";state.sim_time=3.2
 var glyphs:Array=[]
 for a in 8:glyphs.append({"actor":a,"symbol":["circle","cross","triangle","square"][a/2]})
 P.publish(beat,state,glyphs)
 state=JSON.parse_string(JSON.stringify(state));state.sim_time=6.1
 var initial:Dictionary=state.synergy_preparation.duplicate(true)
 P.publish(beat,state,glyphs)
 var ok:bool=not state.synergy_preparation.blocked and state.synergy_preparation==initial
 print("SYNERGY_BOUNDARY_RESULT ",JSON.stringify({"checks":1,"failures":0 if ok else 1,"blocked_at_exact_close":state.synergy_preparation.blocked,"scope":"exact JSON-restored clock API boundary; not human motion"}));quit(0 if ok else 1)
