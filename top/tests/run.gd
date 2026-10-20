extends SceneTree
const Encounter = preload("res://scripts/encounters.gd")
const Interactions = preload("res://scripts/interactions.gd")
const Rules = preload("res://scripts/rules.gd")
func _initialize() -> void:
	var profiles = JSON.parse_string(FileAccess.get_file_as_string("res://data/strategies.json"))
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	var failures = 0; var snapshots = 0; var examples = {}
	for strategy in profiles:
		for item in catalog:
			for seed_value in range(1, 49):
				var encounter = Encounter.new().build(item.id, seed_value, strategy)
				var state = {"dynamis": encounter.initial_dynamis.duplicate(), "spent": [], "lb": "", "lb_actor": -1, "aggro": 0}
				for raw in encounter.beats:
					var b: Dictionary = raw.duplicate(true)
					state.sim_time = float(state.get("sim_time", 0)) + float(b.duration)
					# This suite validates ideal snapshot geometry only. Runtime tests must physically collect the lines.
					if b.has("transfers"):
						Interactions.begin(b, [], state); state.tether_holders = b.transfers.wanted.duplicate(); Interactions.sync(b, state)
					var actors: Array = []
					for i in 8:
						var p: Vector2 = b.positions[i]
						if b.has("knockback"): p += p.normalized() * float(b.knockback)
						actors.append({"role": Encounter.ROLES[i], "pos": p, "face": b.facing.get(i, 0)})
					for check in b.checks:
						if check.kind == "lb": state.lb = check.type; state.lb_actor = check.eligible[0]
						if check.kind == "aggro": state.aggro = check.actor
					var errors = Rules.evaluate(b, actors, state)
					snapshots += 1
					if not errors.is_empty():
						failures += 1
						var key: String = item.id + " / " + b.title
						if not examples.has(key): examples[key] = errors
	for key in examples: print("FAIL ",key, " : ", examples[key])
	print("SNAPSHOTS ", snapshots, " FAILURES ", failures)
	quit(1 if failures else 0)
