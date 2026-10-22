# SPDX-License-Identifier: MIT
extends SceneTree
## NPC collectors must physically enter long, human-held Loop rays.
const Interactions = preload("res://scripts/interactions.gd")
const Statuses = preload("res://scripts/statuses.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("NPC HUMAN TETHER FAIL: ", label)
func actor(position: Vector2) -> Dictionary:
	return {"pos": position, "role": "dps", "face": 0.0}
func fixture(direction: Vector2, moving_endpoint: bool, human_control := true) -> Dictionary:
	var endpoint := direction.normalized() * 16.0
	var other_endpoint := direction.normalized().orthogonal() * 15.0
	var actors := [actor(endpoint), actor(-direction.normalized().orthogonal() * 8.0), actor(other_endpoint), actor(direction.normalized().orthogonal() * 8.0)]
	for i in 4: actors.append(actor(-direction.normalized() * (11.0+i) - direction.normalized().orthogonal()*12.0))
	var positions:Array=[endpoint, direction.normalized() * 17.0, other_endpoint, direction.normalized().orthogonal() * 17.0]
	for i in range(4,8):positions.append(actors[i].pos)
	var beat := {
		"duration": 8.0, "positions": positions, "shapes": [],
		"program_loop": {"round": 1, "numbers": [2, 1, 2, 1, 3, 3, 4, 4]},
		"transfers": {"group": "program_loop_regression", "initial": [0, 2], "sources": [Vector2.ZERO, Vector2.ZERO], "wanted": [1, 3], "pickup_radius": 0.65, "ownership_policy": "unverified_exclusive"}
	}
	var state := {"sim_time": 0.0, "human_actor": 0 if human_control else -1, "dynamis": [0, 0, 0, 0, 0, 0, 0, 0], "spent": [], "lb": "", "aggro": 0}
	Statuses.ensure(state)
	Interactions.begin(beat, actors, state)
	for frame in 160:
		var dt := 0.05
		var previous := actors.duplicate(true)
		if moving_endpoint:
			var angle := sin(frame * 0.04) * 0.2
			actors[0].pos = endpoint.rotated(angle)
		# Only NPCs move; ownership changes exclusively through Interactions.tick.
		for npc in [1, 3]:
			var goal: Vector2 = Interactions.bot_goal(npc, beat, actors, state)
			actors[npc].pos = (actors[npc].pos as Vector2).move_toward(goal, 6.0 * dt)
		Interactions.tick(beat, actors, previous, state, dt)
		if 1 in state.tether_holders: break
	return state
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var legacy:=fixture(Vector2.RIGHT,false,false)
	check(1 not in legacy.tether_holders,"legacy controlled-ray path cannot collect stationary long ray")
	for direction in [Vector2.RIGHT, Vector2.UP, Vector2(-0.8, 0.6), Vector2(0.6, -0.8)]:
		for moving_endpoint in [false, true]:
			var state := fixture(direction, moving_endpoint)
			check(state.get("runtime_failures",[]).is_empty(),"valid eight-person fixture has no runtime errors")
			check(1 in state.tether_holders, "collector physically picks up %s ray (moving=%s)" % [direction, moving_endpoint])
			check(state.tether_events.any(func(event): return event.from == 0 and event.to == 1), "tick records human-to-NPC transfer")
			check(not state.tether_events.any(func(event): return event.line == 0 and event.to == 3), "other-line collector does not steal human ray")
	print("NPC HUMAN TETHERS checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
