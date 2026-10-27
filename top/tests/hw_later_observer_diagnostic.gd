extends "res://scripts/main.gd"
# Diagnostic-only observation-channel interception. The real Arena remains
# same draw path but Arena process is disabled in all controls; no event queues,
# simulation or judgments are intercepted.
var observation_mode:="normal"
var diagnostic_round:=-1
var delivered_frames:=0
var altered_frames:=0
var last_publication:Dictionary={}
func publish_observed_cues()->void:
 if not current.get("hello_world",false):
  super.publish_observed_cues();return
 for callback_key in ["synergy_public","synergy_weapon_public","p1_path","cannons_public","p3_transition_public"]:
  assert(not current.has(callback_key),"HW-only callback parity")
 var actual:Array=arena.visible_damage_shapes.duplicate(true)
 var delivered:Array=actual.duplicate(true)
 var round_index:=int(current.get("hw_tower_cooperation",{}).get("round",-1))
 var target:=round_index==diagnostic_round
 if target and observation_mode=="withheld":delivered=[]
 elif target and observation_mode=="contradictory":
  for shape in delivered:
   if shape.get("hw_preview",false) and shape.get("kind","")=="tower":
    shape.pos=load("res://scripts/rules.gd").v(shape.pos).rotated(PI/2.0)
 if target:
  delivered_frames+=1
  if actual!=delivered:altered_frames+=1
  last_publication={"at":state.get("sim_time",0.0),"round":round_index,"actual":actual,"delivered":delivered,"diagnostic_only":observation_mode!="normal"}
 # Exact sole HW callback in frozen main.gd lines668-669. This override is
 # valid ONLY for the pinned baseline, not a generic/future Main adapter.
 load("res://scripts/hw_firstwave_observation.gd").publish(current,state,delivered)
