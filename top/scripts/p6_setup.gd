# SPDX-License-Identifier: MIT
extends RefCounted
## Explicit standalone-practice entry snapshot, never a reward for following goals.
const LB=preload("res://scripts/p6_lb.gd")
const JOBS=["DRK","PLD","AST","SCH","MNK","NIN","BRD","PCT"]
static func initialize(state:Dictionary,actors:Array,scenario:String,human:int,job:String="",loadout_actor:int=-1) -> void:
	if scenario not in ["p6_memory","p6_meteors","p6_magic"]:return
	# Control ownership changes on checkpoint entry; cast/gauge history does not.
	state.human_actor=human
	if state.has("p6_lb"):return
	var jobs:Array=JOBS.duplicate()
	var selected:int=loadout_actor if loadout_actor>=0 else human
	if selected>=0 and not job.is_empty():jobs[selected]=job
	var calibration:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/p6_lb_calibration.json"))
	var animation:Dictionary={}
	for identity in LB.ACTIONS:animation[identity]=float(calibration.post_cast_seconds_by_kind[LB.ACTIONS[identity].kind])
	LB.begin(state,actors,{"jobs":jobs,"gauge":30000,"brilliant":[] if scenario=="p6_memory" else range(8),"animation_seconds":animation,"targets":[{"id":"alpha_omega","npc_id":0,"pos":[0,0],"hp":1000000000.0,"targetable":true}]})
	state.p6_lb.memory_entry=scenario=="p6_memory"
	state.p6_lb.calibration.animation=calibration.source
	state.p6_lb.calibration.animation_confidence=calibration.confidence
	state.p6_auto_lb=true;state.human_actor=human
	state.p6_training_entry={"scenario":scenario,"jobs":jobs.duplicate(),"gauge":30000,"brilliant":"earned only by surviving Memory" if scenario=="p6_memory" else "explicit standalone pre-course snapshot","dynamis":"three-stack prerequisite snapshot; not earned by this standalone drill"}
