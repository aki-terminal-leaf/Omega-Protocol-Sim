extends Node3D
## Same visual module for preview and externally supplied native numeric ages.
const FX = preload("res://scripts/asset_lab_effect.gd")
const Lifetime = preload("res://scripts/asset_lab_lifetime.gd")
const SOURCE = "3719a1cfcb102a31469770f53aca9b8edd8ec84bb490c645dbc080a1c7487201"
const ASSET_PINS = {"res://raw/full_fx_7d52f33034935c9aabf2.json": "1d167245034ae6e519c8e652aff91aedb4e45765ef7cff9b5d9e44195b15c8da", "res://raw/full_tex_d00f00d4a5b35490d3a5.png": "975847812e06debb21e90db316b7502ad3e77ddf99a11ca7757c8fddc3e81512", "res://raw/full_tex_e21ed36711e1c534c71f.png": "8b65b82c9a00e0424506d3c82f4c079027730a1bba0bf232dabc0f130dde0c9d", "res://raw/full_tex_5a61e2d56e7ef42abbfb.png": "65e0058e61d91db69154d35845d0ede0c1b35628efc667d5e25ebd684594ce39", "res://raw/full_tex_26fc063c2e56ead8a43f.png": "ed298865bcdbe4b419475462efc1fe23a2253d403f8a2b35836903f1c8267a4f", "res://raw/full_tex_8f4b1f8cd36515d02ccb.png": "461390288fe018b660a1b98b88a92256c8a7f5c246f039b6c0943d480e24d313", "res://raw/full_tex_ecae0aa3f9fff7b02422.png": "10e410cb6c8baa3c0d82df5757c8cbeb8a41a6d71ba68840b78b161db6e4df08"}
var effect: Node3D
var data: Dictionary = {}
var lifetime: Dictionary = {}
var playing := false
var age := 0.0
var error := ""
var end_frame := 0.0
func release() -> void:
 playing = false
 visible = false
 age = 0.0
 data.clear()
 lifetime.clear()
 end_frame = 0.0
 if is_instance_valid(effect):
  effect.reset()
  effect.free()
 effect = null
func _fail(reason: String) -> bool:
 release()
 error = reason
 return false
func configure(path: String = "res://action-data.json") -> bool:
 release()
 error = ""
 var candidate: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
 if not candidate is Dictionary or candidate.get("action") != 31567 or candidate.get("source_sha256") != SOURCE: return _fail("Action source unavailable")
 if not candidate.get("assets") is Dictionary or candidate.assets.size() != 7: return _fail("Incomplete source assets")
 for name in candidate.assets:
  var expected: Dictionary = candidate.assets[name]
  if not ASSET_PINS.has(name) or expected.get("sha256") != ASSET_PINS[name]: return _fail("Untrusted source asset pin")
  if not str(name).begins_with("res://raw/"): return _fail("Invalid source asset path")
  # Exported PNGs are imported resources; validate an exact raw sidecar instead.
  var raw_path: String = str(name) + ".source" if str(name).ends_with(".png") and not FileAccess.file_exists(name) else str(name)
  if not FileAccess.file_exists(raw_path): return _fail("Required source asset missing")
  var bytes := FileAccess.get_file_as_bytes(raw_path)
  var hash_context := HashingContext.new()
  hash_context.start(HashingContext.HASH_SHA256)
  hash_context.update(bytes)
  if bytes.size() != int(expected.bytes) or hash_context.finish().hex_encode() != expected.sha256: return _fail("Source asset pin mismatch")
 var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(candidate.pack))
 if not document is Dictionary or document.get("source_sha256") != SOURCE: return _fail("Source graph unavailable")
 if not candidate.assets.has(candidate.pack) or not candidate.get("textures") is Dictionary: return _fail("Source dependency mismatch")
 for name in document.textures:
  if not candidate.textures.has(name) or not candidate.assets.has(candidate.textures[name]): return _fail("Texture dependency missing")
  var texture_path: String = candidate.textures[name]
  if ResourceLoader.exists(texture_path):
   var texture: Texture2D = load(texture_path) as Texture2D
   if texture == null or texture.get_width() <= 0 or texture.get_height() <= 0: return _fail("Source texture unreadable")
  else:
   var img := Image.load_from_file(texture_path)
   if img == null or img.is_empty(): return _fail("Source texture unreadable")
 var bound := float(candidate.get("inspector_end_frame", NAN))
 if not is_finite(bound) or bound <= 0 or bound > 1800: return _fail("Invalid inspection bound")
 var pending := FX.new()
 if not pending.configure(document, candidate.textures, int(candidate.seed)):
  pending.free()
  return _fail("Source graph rejected")
 effect = pending
 add_child(effect)
 effect.set_process(false)
 data = candidate.duplicate(true)
 lifetime = Lifetime.upper_bound(document)
 end_frame = bound
 var p: Array = candidate.placement.position
 effect.transform = Transform3D(Basis(Vector3.UP, float(candidate.placement.heading_radians)), Vector3(p[0], p[1], p[2]))
 visible = true
 return seek(0.0)
func seek(native_age: float) -> bool:
 if not is_finite(native_age) or native_age < 0 or native_age > 3.402823466e38: return _fail("Invalid clock")
 if not is_instance_valid(effect): return false
 # Beyond the proven supported subset envelope, sample its empty boundary; no host release is fabricated.
 age = native_age
 if not effect.seek(minf(age, end_frame)): return _fail("Source evaluation failed")
 if age >= end_frame: playing = false
 return true
func seek_seconds(seconds: float) -> bool:
 if not is_finite(seconds) or seconds < 0 or seconds > 3.402823466e38 / 30.0: return _fail("Invalid seconds clock")
 return seek(seconds * 30.0)
func play() -> bool:
 if not is_instance_valid(effect): return false
 if age >= end_frame and not seek(0.0): return false
 playing = true
 return true
func pause() -> void: playing = false
func advance(seconds: float) -> bool:
 if not is_finite(seconds) or seconds < 0: return _fail("Invalid delta")
 if not playing: return true
 return seek(minf(end_frame, age + seconds * 30.0))
func _process(delta: float) -> void:
 if playing: advance(delta)
func radial_descriptors() -> Array:
 # Host consumes detached snapshots; release/failure never leave a stale value.
 return effect.radial_effects.duplicate(true) if is_instance_valid(effect) else []
func report() -> Dictionary:
 return {"action":31567,"age":age,"playing":playing,"error":error,"source_status":"BLOCKED","rendering_accepted":false,"all96_accepted":false,"lifetime":lifetime.duplicate(true),"particle_emitter_envelope":{"frames":end_frame,"scope":"source graph subset; excludes native post-effect/host lifetime"},"inspection_end":end_frame,"clock_status":data.get("clock_status",""),"radial_effects":radial_descriptors(),"source":effect.report() if is_instance_valid(effect) else {},"graph":data.get("graph",{}).duplicate(true)}
func _exit_tree() -> void: release()
