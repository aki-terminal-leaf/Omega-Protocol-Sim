# SPDX-License-Identifier: MIT
extends RefCounted
## Original geometry implementation from observed casts and public guide rules.
const Rules=preload("res://scripts/rules.gd")
static func pair_entities(m_angle: float,sword: bool,legs: bool,delay:=0.0) -> Array:
	var m:=Rules.direction(m_angle)*10.0
	return [{"form":"male","pos":m,"facing":m_angle+180,"stance":"SWORD" if sword else "SHIELD","spawn_delay":delay},
		{"form":"female","pos":-m,"facing":m_angle,"stance":"LEGS" if legs else "STAFF","spawn_delay":delay}]
static func pair_shapes(m_angle: float,sword: bool,legs: bool) -> Array:
	var m:=Rules.direction(m_angle)*10.0;var f:Vector2=-m
	var shapes:Array=[{"kind":"circle","pos":m,"radius":10.0,"name":"Efficient Bladework"} if sword else {"kind":"donut","pos":m,"inner":10.0,"radius":40.0,"name":"Beyond Strength"}]
	if legs:
		for side in [-90,90]:shapes.append({"kind":"line","pos":f,"angle":m_angle+side,"start":4.0,"length":40.0,"width":80.0,"name":"Superliminal Steel"})
	else:
		for side in [0,90]:shapes.append({"kind":"line","pos":f,"angle":m_angle+side,"start":-100.0,"length":100.0,"width":10.0,"name":"Optimized Blizzard III"})
	return shapes
