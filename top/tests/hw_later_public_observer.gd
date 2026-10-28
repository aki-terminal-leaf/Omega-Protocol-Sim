extends "res://scripts/main.gd"
## Test-only interception of the NPC observation channel. Arena, clocks,
## actors, status propagation and attack judgments remain unmodified.
var observation_mode:="normal"
var diagnostic_round:=-1
var altered_frames:=0
func publish_observed_cues()->void:
 if not current.get("hello_world",false):super.publish_observed_cues();return
 var actual:Array=arena.visible_damage_shapes.duplicate(true)
 var delivered:Array=actual.duplicate(true)
 var r:=preload("res://scripts/hw_later_observation.gd").round_of(current)
 if r==diagnostic_round:
  if observation_mode=="withheld":delivered=[]
  elif observation_mode=="contradictory" or (observation_mode=="late_conflict" and float(state.sim_time)>24.0+21.0*r-9.0):
   for shape in delivered:
    if shape.get("hw_preview",false) and shape.get("kind","")=="tower":shape.pos=load("res://scripts/rules.gd").v(shape.pos).rotated(PI/2.0)
 if actual!=delivered:altered_frames+=1
 preload("res://scripts/hw_firstwave_observation.gd").publish(current,state,delivered)
 preload("res://scripts/hw_later_observation.gd").publish(current,state,delivered)
