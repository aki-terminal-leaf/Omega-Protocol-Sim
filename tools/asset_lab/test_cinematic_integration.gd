extends SceneTree
const Adapter = preload("res://scripts/cinematic_sample_adapter.gd")
const Source = preload("res://scripts/source_animation.gd")
const TOLERANCE = 0.0002
var report: Dictionary = {"status":"OPEN","tolerance_absolute":TOLERANCE,"models":[],"all96_accepted":false,"gpu_deformation_proved":false}
var destination: String
func _initialize() -> void:
	call_deferred("run")
func fail(message: String) -> void:
	report.status="BLOCKED"
	report["blocker"]=message
	FileAccess.open(destination,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	printerr(message)
	quit(1)
func trs(row: Array) -> Transform3D:
	return Transform3D(Basis(Quaternion(row[8],row[9],row[10],row[11]).normalized()) * Basis.from_scale(Vector3(row[4],row[5],row[6])),Vector3(row[0],row[1],row[2]))
func error_matrix(a: Transform3D,b: Transform3D) -> float:
	var error: float = 0.0
	for v in [a.origin-b.origin,a.basis.x-b.basis.x,a.basis.y-b.basis.y,a.basis.z-b.basis.z]:
		error=maxf(error,maxf(absf(v.x),maxf(absf(v.y),absf(v.z))))
	return error
func collect(node: Node, skeletons: Array, meshes: Array, players: Array) -> void:
	if node is Skeleton3D: skeletons.append(node)
	if node is MeshInstance3D: meshes.append(node)
	if node is AnimationPlayer: players.append(node)
	for child in node.get_children(): collect(child,skeletons,meshes,players)
func run() -> void:
	var args=OS.get_cmdline_user_args()
	destination=args[1]
	var cases=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	for entry in cases:
		var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(entry.sample))
		var state=GLTFState.new()
		var document=GLTFDocument.new()
		var code=document.append_from_file(entry.glb,state)
		if code!=OK: fail("GLTF import error %s: %s"%[code,entry.glb]); return
		var scene=document.generate_scene(state)
		if scene==null: fail("GLTF generate_scene failed"); return
		var holder=Node3D.new()
		root.add_child(holder)
		holder.transform=Transform3D(Basis.from_euler(Vector3(.2,.4,.1))*Basis.from_scale(Vector3(1.2,.8,1.4)),Vector3(8,3,-4))
		holder.add_child(scene)
		scene.transform=Transform3D(Basis.from_euler(Vector3(0,.7,0))*Basis.from_scale(Vector3(.7,1.3,1.1)),Vector3(2,1,3))
		var skeletons: Array=[]
		var meshes: Array=[]
		var players: Array=[]
		collect(scene,skeletons,meshes,players)
		var result: Dictionary={"model":raw.model,"meshes":meshes.size(),"skeletons":skeletons.size(),"resident_players":players.size(),"clips":[],"max_rest_error":0.0,"surfaces":0,"skin_bindings":0,"vertices":0,"material_surfaces":0,"textured_surfaces":0,"weight_values":0}
		report.models.append(result)
		if skeletons.size()!=1 or meshes.is_empty(): fail("missing/ambiguous imported skeleton/mesh"); return
		var skel: Skeleton3D=skeletons[0]
		if skel.get_bone_count()!=raw.names.size(): fail("bone count mismatch %s != %s"%[skel.get_bone_count(),raw.names.size()]); return
		for mesh in meshes:
			if mesh.mesh==null or mesh.skin==null or mesh.get_node_or_null(mesh.skeleton)!=skel: fail("mesh lacks actual bound Skin/Skeleton3D"); return
			result.surfaces+=mesh.mesh.get_surface_count()
			result.skin_bindings+=mesh.skin.get_bind_count()
			for surface in mesh.mesh.get_surface_count():
				var arrays: Array=mesh.mesh.surface_get_arrays(surface)
				result.vertices+=arrays[Mesh.ARRAY_VERTEX].size()
				result.weight_values+=arrays[Mesh.ARRAY_WEIGHTS].size()
				var material=mesh.mesh.surface_get_material(surface)
				if material!=null: result.material_surfaces+=1
				if material is BaseMaterial3D and (material.albedo_texture!=null or material.normal_texture!=null): result.textured_surfaces+=1
		if result.surfaces==0 or result.skin_bindings==0 or result.vertices==0 or result.weight_values==0 or result.textured_surfaces==0: fail("empty imported resources"); return
		for i in raw.names.size():
			var id: int=skel.find_bone(raw.names[i])
			if id<0:
				var actual: Array=[]
				for j in skel.get_bone_count(): actual.append(skel.get_bone_name(j))
				result["imported_names"]=actual
				fail("import renamed/missing exact source bone: "+raw.names[i]); return
			var p: int=skel.get_bone_parent(id)
			var expected: String=raw.names[int(raw.parents[i])] if raw.parents[i]>=0 else ""
			var actual: String=skel.get_bone_name(p) if p>=0 else ""
			if expected!=actual: fail("hierarchy mismatch for %s: %s != %s"%[raw.names[i],actual,expected]); return
			result.max_rest_error=maxf(result.max_rest_error,error_matrix(skel.get_bone_rest(id),trs(raw.reference_local[i])))
		if result.max_rest_error>TOLERANCE: fail("LOCAL rest matrix mismatch: %s"%result.max_rest_error); return
		# Independently derive model-to-skeleton transform; exclude both transformed roots.
		var relative: Transform3D=Transform3D.IDENTITY
		var cursor: Node3D=skel
		while cursor!=scene:
			relative=cursor.transform*relative
			cursor=cursor.get_parent() as Node3D
		var to_skeleton: Transform3D=relative.affine_inverse()
		for clip in raw.clips:
			var adapted=Adapter.convert(raw,int(clip.index))
			if adapted.has("error"): fail(str(adapted)); return
			var binding=Source.configure(holder,adapted)
			if not binding.ok: fail(binding.error); return
			var cr: Dictionary={"index":clip.index,"frames":clip.times.size(),"seeks":0,"max_matrix_error":0.0,"max_motion":0.0}
			result.clips.append(cr)
			var initial: Array=[]
			var order: Array=[]
			for i in clip.times.size(): order.append(i)
			for i in range(clip.times.size()-1,-1,-1): order.append(i)
			order.append(0)
			for fi in order:
				if not Source.seek(binding,clip.times[fi]): fail(binding.error); return
				for bi in raw.names.size():
					var actual: Transform3D=skel.get_bone_global_pose(skel.find_bone(raw.names[bi]))
					var expected: Transform3D=to_skeleton*trs(clip.frames[fi][bi])
					cr.max_matrix_error=maxf(cr.max_matrix_error,error_matrix(actual,expected))
					if cr.seeks==0: initial.append(actual)
					else: cr.max_motion=maxf(cr.max_motion,error_matrix(actual,initial[bi]))
				cr.seeks+=1
				if cr.max_matrix_error>TOLERANCE: fail("actual posed matrix mismatch: "+str(cr)); return
			Source.clear(binding)
			if skel.has_meta(Source.OWNER_META): fail("clear ownership failed"); return
			skel.force_update_all_bone_transforms()
			var clear_error: float=0.0
			for bi in skel.get_bone_count(): clear_error=maxf(clear_error,error_matrix(skel.get_bone_global_pose(bi),skel.get_bone_global_rest(bi)))
			cr["clear_rest_error"] = clear_error
			if clear_error>TOLERANCE: fail("clear did not restore rest"); return
			var rebound=Source.configure(holder,adapted)
			if not rebound.ok or not Source.seek(rebound,clip.times[-1]): fail("rebind failed"); return
			Source.clear(rebound)
			cr["clear_rebind"]=true
			cr["resident_restore"]="NOT_EXERCISED: unanimated bind rig has no resident player" if players.is_empty() else "OPEN"
		holder.free()
	report.status="NUMERIC_INTEGRATION_PASS"
	FileAccess.open(destination,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit(0)

