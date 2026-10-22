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
	return ""
static func texture(value:String) -> Texture2D:
	var key:=symbol_name(value)
	if key.is_empty():return null
	if textures.has(key):return textures[key]
	var colour:String={"circle":"#ff9656","cross":"#62baff","triangle":"#75e991","square":"#de8bff","stack":"#ffe4a0"}[key]
	var path:String={"circle":"M 64,20 A 44,44 0 1,1 63.99,20","cross":"M 26,26 L 102,102 M 102,26 L 26,102","triangle":"M 16,26 L 112,26 L 64,109 Z","square":"M 23,23 L 105,23 L 105,105 L 23,105 Z","stack":"M 20,20 L 48,48 M 108,20 L 80,48 M 20,108 L 48,80 M 108,108 L 80,80 M 34,48 L 48,48 L 48,34 M 80,34 L 80,48 L 94,48 M 34,80 L 48,80 L 48,94 M 80,94 L 80,80 L 94,80"}[key]
	var svg:='<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><path d="%s" fill="none" stroke="#101425" stroke-width="17" stroke-linecap="round" stroke-linejoin="round"/><path d="%s" fill="none" stroke="%s" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/></svg>'%[path,path,colour]
	var pixels:=Image.new();var err:=pixels.load_svg_from_string(svg,2.0)
	if err!=OK:return null
	textures[key]=ImageTexture.create_from_image(pixels)
	return textures[key]
static func observed(actor:int,beat:Dictionary,state:Dictionary) -> String:
	if actor in state.get("dead",[]):return ""
	for raw in beat.get("party_statuses",[]):
		if int(raw.actor)==actor and raw.get("marker",false) and raw.has("symbol") and Party.signal_visible(raw,state,beat) and str(raw.key) not in state.get("consumed_party_signals",{}).get(str(actor),[]):return str(raw.symbol)
	return ""
