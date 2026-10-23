# SPDX-License-Identifier: MIT
extends RefCounted
const Party=preload("res://scripts/party_statuses.gd")
static var textures:Dictionary={}
static func symbol_name(value:String) -> String:
	match value.to_lower():
		"o","circle","〇","○":return "circle"
		"x","cross","×":return "cross"
		"triangle","△","▽":return "triangle"
		"square","□":return "square"
		"stack":return "stack"
		"cannon":return "cannon"
		"flare":return "flare"
	return ""
static func texture(value:String) -> Texture2D:
	var key:=symbol_name(value)
	if key.is_empty():return null
	if textures.has(key):return textures[key]
	var colour:String={"circle":"#ff9656","cross":"#62baff","triangle":"#75e991","square":"#de8bff","stack":"#ffe4a0","cannon":"#ff7b9b","flare":"#ff9ac8"}[key]
	var path:String={"circle":"M 64,20 A 44,44 0 1,1 63.99,20","cross":"M 26,26 L 102,102 M 102,26 L 26,102","triangle":"M 16,26 L 112,26 L 64,109 Z","square":"M 23,23 L 105,23 L 105,105 L 23,105 Z","cannon":"M 64,24 A 40,40 0 1,1 63.99,24 M 64,8 L 64,40 M 64,88 L 64,120 M 8,64 L 40,64 M 88,64 L 120,64","flare":"M 64,14 L 118,107 L 10,107 Z M 64,47 L 64,81 M 64,94 L 64,96","stack":"M 20,20 L 48,48 M 108,20 L 80,48 M 20,108 L 48,80 M 108,108 L 80,80 M 34,48 L 48,48 L 48,34 M 80,34 L 80,48 L 94,48 M 34,80 L 48,80 L 48,94 M 80,94 L 80,80 L 94,80"}[key]
	var svg:='<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><path d="%s" fill="none" stroke="#101425" stroke-width="17" stroke-linecap="round" stroke-linejoin="round"/><path d="%s" fill="none" stroke="%s" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/></svg>'%[path,path,colour]
	var pixels:=Image.new();var err:=pixels.load_svg_from_string(svg,2.0)
	if err!=OK:return null
	textures[key]=ImageTexture.create_from_image(pixels)
	return textures[key]
static func same_actor(value:Variant,actor:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==float(actor)
static func observed_all(actor:int,beat:Dictionary,state:Dictionary) -> Array:
	var result:Array=[]
	if state.get("dead",[]).any(func(value):return same_actor(value,actor)):return result
	for raw in beat.get("party_statuses",[]):
		if int(raw.actor)==actor and raw.get("marker",false) and raw.has("symbol") and Party.signal_visible(raw,state,beat) and str(raw.key) not in state.get("consumed_party_signals",{}).get(str(actor),[]):result.append(str(raw.symbol))
	if actor in state.get("p4_wave",{}).get("markers",[]):result.append("stack")
	if actor in state.get("p6",{}).get("flare_targets",[]):result.append("flare")
	var limitless:Dictionary=state.get("limitless",{})
	if limitless.get("flare_marked",false) and float(state.get("sim_time",0))<float(limitless.start)+27.45 and actor in limitless.config.flare_targets:result.append("flare")
	# P1 actual Wave Cannon targets; second icons follow the first hit by3.9s.
	var p1:Dictionary=state.get("p1",{})
	for event in p1.get("pending",[]):
		if event.kind=="proteans" and event.targets.any(func(value):return same_actor(value,actor)):
			var at:=float(event.at);var now:=float(state.get("sim_time",0));var origin:=float(p1.get("coaching_origin",0))
			var show_at:=origin if at-origin<7.0 else at-5.1
			if now+0.000001>=show_at and now<at:result.append("cannon")
	return result
static func observed(actor:int,beat:Dictionary,state:Dictionary) -> String:
	var result:=observed_all(actor,beat,state)
	return str(result[0]) if not result.is_empty() else ""
