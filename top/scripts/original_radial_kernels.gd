extends RefCounted
## Explicit bounded embedding contract. No native lifecycle/default/packet mapping.
const POLICY = "linear_clamp_explicit"
const MIRROR_POLICY = "native_radial_0x265_mirror_lod0"
const MIXED_POLICY = "native_merge_0x25_point_0x265_linear_mirror_lod0"
const SPACE = "raw_rgba8_no_srgb"
const TARGET = "rgba8_unorm_blend_disabled"
const RADIAL = preload("res://materials/original_radial_blur.gdshader")
const MERGE = preload("res://materials/original_donut_merge.gdshader")
var _owner: WeakRef
var _material: ShaderMaterial
var _expected: Dictionary = {}
var _textures: Dictionary = {}
var _shader_code: String = ""
var _shader: Shader
var _kind: String = ""
var last_error: String = ""

static func f32(x: float) -> float:
    return PackedFloat32Array([x])[0]

static func weights(z: float) -> Array:
    var result: Array = []
    for i in range(4):
        result.append(f32(1.0 - f32(f32(float(i) * f32(z)) * 0.25)))
    return result

static func vector_ok(value: Variant, width: int, bound: float = 16.0) -> bool:
    if not value is Array or value.size() != width:
        return false
    for x in value:
        if not (x is float or x is int) or not is_finite(float(x)):
            return false
        var rounded: float = f32(float(x))
        if not is_finite(rounded) or abs(rounded) > bound:
            return false
    return true

static func _v4(a: Array) -> Vector4:
    return Vector4(f32(a[0]), f32(a[1]), f32(a[2]), f32(a[3]))

func _fail(message: String) -> bool:
    release()
    last_error = message
    return false

func release() -> void:
    if _owner != null and is_instance_valid(_owner.get_ref()):
        var item = _owner.get_ref()
        if item.material == _material:
            item.material = null
    _owner = null
    _material = null
    _expected.clear()
    _textures.clear()
    _shader_code = ""
    _shader = null
    _kind = ""

func is_current() -> bool:
    if _owner == null or not is_instance_valid(_owner.get_ref()) or _material == null:
        return false
    if _owner.get_ref().material != _material or _material.shader == null or _material.shader != _shader or _material.shader.code != _shader_code:
        return false
    for key in _expected:
        if _material.get_shader_parameter(key) != _expected[key]:
            return false
    for key in _textures:
        var t: Texture2D = _textures[key][0]
        if not is_instance_valid(t) or t.get_width() != _textures[key][1] or t.get_height() != _textures[key][2] or t.get_format() != Image.FORMAT_RGBA8:
            return false
        var current_image: Image = t.get_image()
        if current_image == null or current_image.get_format() != Image.FORMAT_RGBA8 or current_image.has_mipmaps():
            return false
        if current_image.get_data() != _textures[key][3]:
            return false
    return true

func attach(item: CanvasItem, kind: String, inputs: Dictionary) -> bool:
    release()
    if not is_instance_valid(item) or item.material != null or kind not in ["radial", "merge"]:
        return _fail("attachment must be empty and kind explicit")
    _owner = weakref(item)
    _kind = kind
    _material = ShaderMaterial.new()
    _material.shader = (RADIAL if kind == "radial" else MERGE).duplicate()
    _shader = _material.shader
    _shader_code = _material.shader.code
    item.material = _material
    return update(inputs)

func update(inputs: Dictionary) -> bool:
    if not is_current():
        return _fail("stale attachment/material/texture")
    var policy = inputs.get("sampler_policy")
    if policy != POLICY and not (_kind == "radial" and policy == MIRROR_POLICY) and not (_kind == "merge" and policy == MIXED_POLICY):
        return _fail("explicit supported sampler_policy required; cross-kind policies are rejected")
    for pair in [["color_space", SPACE], ["target", TARGET]]:
        if inputs.get(pair[0]) != pair[1]:
            return _fail("explicit policy required: " + pair[0])
    if not inputs.get("provenance") is String or inputs["provenance"].strip_edges().is_empty():
        return _fail("provenance required")
    if not vector_ok(inputs.get("target_size"), 2, 4096.0):
        return _fail("target dimensions required")
    for x in inputs["target_size"]:
        if x < 2 or x != floor(x):
            return _fail("integer target dimensions at least 2 required")
    var names: Array = ["viewport", "uv_rect", "radial"] if _kind == "radial" else ["viewport", "uv_rect", "radii", "merge_param"]
    for key in names:
        if not vector_ok(inputs.get(key), 4):
            return _fail("bounded finite f32 float4 required: " + key)
    # Conservative finite intermediate domain, a host policy, not native behavior.
    for axis in range(2):
        var lo: float = inputs["uv_rect"][axis + 2]
        var hi: float = lo + inputs["uv_rect"][axis]
        if min(lo, hi) < -2.0 or max(lo, hi) > 2.0:
            return _fail("UV domain outside [-2,2]")
    if _kind == "radial":
        var total: float = 0.0
        for w in weights(inputs["radial"][2]):
            total = f32(total + w)
        if not is_finite(total) or abs(total) < 0.0001:
            return _fail("singular or near-singular f32 weight sum")
    else:
        for radius in inputs["radii"]:
            if abs(f32(radius)) < 0.0001:
                return _fail("singular or near-singular radius")
    var tex_names: Array = ["s_input"] if _kind == "radial" else ["s_input", "s_merge"]
    var next_textures: Dictionary = {}
    for key in tex_names:
        var tex = inputs.get(key)
        var dims = inputs.get(key + "_size")
        if not tex is ImageTexture or not vector_ok(dims, 2, 4096.0):
            return _fail("explicit ImageTexture and dimensions required")
        if tex.get_width() != dims[0] or tex.get_height() != dims[1] or dims[0] < 1 or dims[1] < 1:
            return _fail("texture dimension mismatch")
        var img: Image = tex.get_image()
        if img == null or tex.get_format() != Image.FORMAT_RGBA8 or img.get_format() != Image.FORMAT_RGBA8 or img.has_mipmaps():
            return _fail("raw RGBA8 without mipmaps required")
        next_textures[key] = [tex, tex.get_width(), tex.get_height(), img.get_data()]
    _expected.clear()
    if _kind == "radial":
        _expected["native_radial_mirror_lod0"] = policy == MIRROR_POLICY
    else:
        _expected["native_merge_mixed_lod0"] = policy == MIXED_POLICY
    for key in names:
        _expected[key] = _v4(inputs[key])
    for key in tex_names:
        _expected[key] = inputs[key]
    for key in _expected:
        _material.set_shader_parameter(key, _expected[key])
    _textures = next_textures
    last_error = ""
    return true
