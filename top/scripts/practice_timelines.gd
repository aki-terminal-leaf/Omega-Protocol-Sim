# SPDX-License-Identifier: MIT
extends RefCounted
static var contracts:Dictionary={}
static func definition(id:String)->Dictionary:
	if contracts.is_empty():contracts=JSON.parse_string(FileAccess.get_file_as_string("res://data/practice_timelines.json")).mechanics
	return contracts.get(id,{}).duplicate(true)
