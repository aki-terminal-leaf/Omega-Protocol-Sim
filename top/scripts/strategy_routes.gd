# SPDX-License-Identifier: MIT
extends RefCounted
## Per-mechanic conventions; do not mutate shared global profiles.
static var definitions: Dictionary={}
static func apply(base: Dictionary,mechanic: String,overrides: Dictionary={}) -> Dictionary:
	var result:=base.duplicate(true)
	if definitions.is_empty():definitions=JSON.parse_string(FileAccess.get_file_as_string("res://data/strategy_overrides.json"))
	if result.get("_resolved_mechanic","")!=mechanic:
		result.merge(definitions.get(mechanic,{}).get(str(base.id),{}).duplicate(true),true)
		result._resolved_mechanic=mechanic
	result.merge(overrides,true)
	return result
