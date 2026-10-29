# SPDX-License-Identifier: MIT
extends Node3D
## Per-unit source orchestration. Review windows do not synthesize source stops.
const Composite=preload("res://scripts/asset_lab_composite.gd")
var composite:Node3D
var selections:Dictionary={}
var selected:Dictionary={}
var unit_id:=""
var clock:=0.0
var duration:=0.0
var error:=""
var source_root:=""
var configured:=false
var source_sampling_supported:=false
func dispose()->void:
 if is_instance_valid(composite):composite.free()
 composite=null;selections.clear();selected.clear();clock=0;duration=0;unit_id="";configured=false;source_sampling_supported=false
func _failure(reason:String,code:Error)->Error:
 dispose();error=reason;return code
func configure(root:String,camera:Camera3D,selection_path:String,attachment_path:="")->Error:
 dispose();error="";source_root=root
 var data:Variant=JSON.parse_string(FileAccess.get_file_as_string(selection_path))
 if not data is Dictionary or data.get("schema")!=1 or not data.get("units") is Dictionary:return _failure("Invalid per-unit source selections",ERR_INVALID_DATA)
 for file in data.get("source_hashes",{}):
  if file not in ["record.json","full-data.json","motion-plan.json","manifest.json","scene-data.json","weapon-data.json"]:return _failure("Rejected source hash path",ERR_INVALID_DATA)
  if FileAccess.get_sha256(root.path_join(file))!=data.source_hashes[file]:return _failure("Source selection/cache hash mismatch: "+file,ERR_INVALID_DATA)
 if data.get("source_hashes",{}).size()!=6:return _failure("Incomplete source pins",ERR_INVALID_DATA)
 if FileAccess.get_sha256("res://data/asset_lab/catalog.json")!=data.get("catalog_sha256",""):return _failure("Catalogue/source selection mismatch",ERR_INVALID_DATA)
 var attachment_file:=attachment_path if not attachment_path.is_empty() else root.path_join("attachment-data.json")
 if str(data.get("attachment_sha256","")).length()!=64 or FileAccess.get_sha256(attachment_file)!=data.attachment_sha256:return _failure("Original attachment source pin mismatch",ERR_INVALID_DATA)
 selections=data.units
 composite=Composite.new();add_child(composite)
 var result:Error=composite.configure(root,camera)
 if result!=OK:return _failure("Original composite data unavailable",result)
 var attachments:Variant=JSON.parse_string(FileAccess.get_file_as_string(attachment_file))
 if not attachments is Dictionary:return _failure("Invalid original attachments",ERR_INVALID_DATA)
 composite.eid=attachments;configured=true
 return OK
func select(id:String)->Error:
 selected={};unit_id=id;duration=0;clock=0;error="";source_sampling_supported=false
 if not configured or not is_instance_valid(composite):error="Original source configuration unavailable";return ERR_UNCONFIGURED
 if is_instance_valid(composite):composite.visible=false
 if not selections.has(id):error="No source selection for "+id;return ERR_DOES_NOT_EXIST
 var row:Dictionary=selections[id]
 if not row.has("review_window_ms"):error="Original source choreography unavailable: "+str(row.status);return ERR_UNAVAILABLE
 var window:Array=row.review_window_ms
 if window.size()!=2 or not is_finite(float(window[0])) or not is_finite(float(window[1])) or float(window[1])<=float(window[0]):error="Invalid source review window";return ERR_INVALID_DATA
 if composite.select_cues(row.cue_keys)!=OK:error="Selection references unknown original cue";return ERR_INVALID_DATA
 if composite.set_sample_window(float(window[0]),float(window[1]),row.actions,row.verified_stops)!=OK:error="Invalid original host/window data";return ERR_INVALID_DATA
 selected=row;duration=(float(window[1])-float(window[0]))/1000;composite.visible=true
 return OK
func seek(seconds:float)->bool:
 if selected.is_empty() or not is_finite(seconds) or seconds<0 or seconds>duration:return false
 clock=seconds
 var t:=minf(float(selected.review_window_ms[1])-.01,float(selected.review_window_ms[0])+seconds*1000)
 source_sampling_supported=composite.seek(t) # false also means explicit unsupported source fields, not a rejected playhead.
 return source_sampling_supported
func report()->Dictionary:
 return {"unit":unit_id,"relative_seconds":clock,"duration":duration,"error":error,"selection":selected,"source_sampling_supported":source_sampling_supported,"source":composite.report() if is_instance_valid(composite) and not selected.is_empty() else {},"all96_accepted":false}
