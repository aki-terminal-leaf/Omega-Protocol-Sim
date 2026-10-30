extends Node
const Kernel = preload("res://scripts/original_radial_kernels.gd")
var failures: Array = []
var assertions: int = 0
var texture_map: Dictionary = {}

func check(ok: bool, label: String) -> void:
    assertions += 1
    if not ok:
        failures.append(label)

func bind_input(row: Dictionary) -> Dictionary:
    var d: Dictionary = row.duplicate(true)
    for key in ["s_input", "s_merge"]:
        if d.has(key):
            d[key] = texture_map[d[key]]
    return d

func _ready() -> void:
    var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://numeric_cases.json"))
    if not load_textures(fixture):
        finish({"finished":true,"ok":false,"error":"invalid numeric fixture"})
        return
    numeric_tests(fixture["cases"])
    if DisplayServer.get_name() == "headless":
        print(JSON.stringify({"numeric_pass":failures.is_empty(),"assertions":assertions,"failures":failures,"raster_verified":false,"shader_compile_evidence":false}))
        get_tree().quit(0 if failures.is_empty() else 1)
        return
    if not OS.has_feature("web"):
        finish({"finished":true,"ok":false,"error":"only Web raster harness is enabled"})
        return
    var data = JSON.parse_string(FileAccess.get_file_as_string("res://cases.json"))
    if not load_textures(data):
        finish({"finished":true,"ok":false,"error":"invalid or oversized diagnostic cases"})
        return
    var results: Array = []
    for row in data["cases"]:
        var viewport := SubViewport.new()
        viewport.size = Vector2i(int(row["target_size"][0]), int(row["target_size"][1]))
        if viewport.size != Vector2i(int(row["target_size"][0]), int(row["target_size"][1])):
            failures.append(str(row["id"]) + ": target dimensions not representable by SubViewport")
            viewport.free()
            continue
        viewport.disable_3d = true
        viewport.transparent_bg = true
        viewport.use_hdr_2d = false
        viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
        viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
        add_child(viewport)
        var rect := ColorRect.new()
        rect.size = Vector2(viewport.size)
        rect.color = Color.WHITE
        viewport.add_child(rect)
        var binding = Kernel.new()
        if not binding.attach(rect, row["kind"], bind_input(row)):
            failures.append(str(row["id"]) + ": " + binding.last_error)
            viewport.queue_free()
            continue
        viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
        await RenderingServer.frame_post_draw
        await get_tree().process_frame
        var image: Image = viewport.get_texture().get_image()
        image.convert(Image.FORMAT_RGBA8)
        results.append({"id":row["id"],"width":image.get_width(),"height":image.get_height(),"rgba8":Array(image.get_data()),"orientation":"Image rows top-to-bottom; UV=(pixel+0.5)/target_size then uv_rect; no Y flip"})
        binding.release()
        viewport.queue_free()
    finish({"schema":1,"finished":true,"ok":failures.is_empty(),"assertions":assertions,"failures":failures,"results":results,"rendering_accepted":false,"all96_accepted":false})

func load_textures(data: Variant) -> bool:
    if not data is Dictionary or not data.get("cases") is Array or not data.get("textures") is Dictionary:
        return false
    if data["cases"].is_empty() or data["cases"].size() > 64 or data["textures"].size() > 16:
        return false
    texture_map.clear()
    for key in data["textures"]:
        var spec = data["textures"][key]
        if not spec is Dictionary or not Kernel.vector_ok(spec.get("size"),2,256.0) or not spec.get("rgba8") is Array:
            return false
        var width: int = int(spec["size"][0])
        var height: int = int(spec["size"][1])
        if width < 1 or height < 1 or width != spec["size"][0] or height != spec["size"][1] or spec["rgba8"].size() != width * height * 4:
            return false
        for value in spec["rgba8"]:
            if not (value is int or value is float) or not is_finite(float(value)) or value < 0 or value > 255 or value != floor(value):
                return false
        var img := Image.create_from_data(width,height,false,Image.FORMAT_RGBA8,PackedByteArray(spec["rgba8"]))
        texture_map[key] = ImageTexture.create_from_image(img)
    var ids: Dictionary = {}
    for row in data["cases"]:
        if not row is Dictionary or not row.get("id") is String or ids.has(row["id"]) or row.get("kind") not in ["radial","merge"]:
            return false
        ids[row["id"]] = true
        if not Kernel.vector_ok(row.get("target_size"),2,256.0):
            return false
        for dimension in row["target_size"]:
            if dimension < 2 or dimension != floor(dimension):
                return false
        if not texture_map.has(row.get("s_input")) or (row["kind"] == "merge" and not texture_map.has(row.get("s_merge"))):
            return false
    return true

func finish(result: Dictionary) -> void:
    var text: String = JSON.stringify(result)
    print(text)
    if OS.has_feature("web"):
        JavaScriptBridge.eval("window.__radial_result = " + text + "; window.__radial_finished = true;", true)
        get_tree().paused = true
    else:
        get_tree().quit(1)

func numeric_tests(rows: Array) -> void:
    var a := ColorRect.new()
    var b := ColorRect.new()
    add_child(a)
    add_child(b)
    var ka = Kernel.new()
    var kb = Kernel.new()
    var input: Dictionary = bind_input(rows[0])
    check(ka.attach(a,"radial",input),"attach A")
    check(kb.attach(b,"radial",input),"attach B")
    check(a.material != b.material,"separate material instances")
    check(a.material.shader != b.material.shader,"separate shader resources")
    check(a.material.get_shader_parameter("radial") == Vector4(.37,.62,1.,.7),"actual uniform upload")
    var changed: Dictionary = input.duplicate()
    changed["radial"] = [.1,.2,.5,-.3]
    check(ka.update(changed),"forward update")
    check(b.material.get_shader_parameter("radial") == Vector4(.37,.62,1.,.7),"B isolated from A")
    check(ka.update(input),"reverse update")
    changed["sampler_policy"] = Kernel.MIRROR_POLICY
    check(ka.update(changed),"explicit clamp to mirror update")
    check(a.material.get_shader_parameter("native_radial_mirror_lod0") == true,"mirror uniform actual upload")
    check(b.material.get_shader_parameter("native_radial_mirror_lod0") == false,"sampler B isolated")
    check(ka.is_current(),"mirror current")
    check(ka.update(input),"explicit mirror to clamp reverse update")
    check(a.material.get_shader_parameter("native_radial_mirror_lod0") == false,"reverse sampler upload")
    a.material.set_shader_parameter("native_radial_mirror_lod0",true)
    check(not ka.is_current(),"sampler uniform mutation detected")
    check(not ka.update(input) and a.material == null,"sampler mutation releases")
    check(ka.attach(a,"radial",changed),"reattach mirror")
    a.material.set_shader_parameter("s_input",texture_map["b"])
    check(not ka.is_current(),"sampler resource mutation detected")
    check(not ka.update(changed) and a.material == null,"sampler resource mutation releases")
    check(ka.attach(a,"radial",changed),"mirror reattach after resource mutation")
    ka.release()
    check(a.material == null and not ka.is_current(),"mirror release")
    check(ka.attach(a,"radial",input),"clamp reattach after mirror release")
    var original_image: Image = texture_map["a"].get_image()
    var alternate_format := Image.create_from_data(original_image.get_width(),original_image.get_height(),false,Image.FORMAT_RF,original_image.get_data())
    texture_map["a"].set_image(alternate_format)
    check(not ka.is_current(),"same bytes and dimensions with changed format rejected")
    check(not ka.update(input),"changed format releases")
    texture_map["a"].set_image(original_image)
    check(ka.attach(a,"radial",input),"reattach restored RGBA8")
    var tiny: Dictionary = input.duplicate()
    tiny["target_size"] = [1,1]
    check(not ka.update(tiny),"target singleton rejected")
    check(Kernel.weights(1.) == [1.,.75,.5,.25],"four radial weights")
    check(Kernel.f32(0.3333333432674407958984375) != Kernel.f32(0.333333),"exact raw third literal")
    for bad in [[],[1.,2.,3.],[1.,2.,3.,INF],[1.,2.,3.,NAN],[1.,2.,3.,1e39],[1.,2.,3.,1e30],[0.,0.,2.6666666666666665,1.]]:
        check(ka.attach(a,"radial",input),"reattach before invalid")
        var invalid: Dictionary = input.duplicate()
        invalid["radial"] = bad
        check(not ka.update(invalid),"reject invalid/singular f32")
        check(a.material == null,"invalid update detaches")
    for key in ["viewport","target_size","s_input","s_input_size","provenance","sampler_policy","color_space","target","uv_rect"]:
        check(ka.attach(a,"radial",input),"reattach missing field")
        var invalid: Dictionary = input.duplicate()
        invalid.erase(key)
        check(not ka.update(invalid),"missing field rejected: " + key)
    check(ka.attach(a,"radial",input),"reattach stale material")
    a.material.set_shader_parameter("radial",Vector4.ZERO)
    check(not ka.update(input) and a.material == null,"external uniform tamper releases")
    check(ka.attach(a,"radial",input),"reattach stale texture")
    var img: Image = texture_map["a"].get_image()
    var old: Color = img.get_pixel(0,0)
    img.set_pixel(0,0,Color(1,0,1,1))
    texture_map["a"].update(img)
    check(not ka.update(input) and a.material == null,"stale texture releases")
    img.set_pixel(0,0,old)
    texture_map["a"].update(img)
    check(ka.attach(a,"radial",input),"reattach after stale texture")
    ka.release()
    check(a.material == null and not ka.update(input),"release prevents update")
    kb.release()
    for row in rows:
        check(ka.attach(a,row["kind"],bind_input(row)),"case binds " + row["id"])
        ka.release()
    for policy in ["native_0x265", "nearest_clamp", ""]:
        check(ka.attach(a,"radial",input),"attach wrong policy")
        var invalid: Dictionary = input.duplicate()
        invalid["sampler_policy"] = policy
        check(not ka.update(invalid),"wrong policy rejected")
    check(ka.attach(a,"radial",input),"attach shader identity")
    a.material.shader = a.material.shader.duplicate()
    check(not ka.update(input) and a.material == null,"stale shader identity rejected")
    var merge_input: Dictionary = bind_input(rows[3])
    check(ka.attach(a,"merge",merge_input),"merge attach")
    merge_input["sampler_policy"] = Kernel.MIRROR_POLICY
    check(not ka.update(merge_input) and a.material == null,"merge rejects native radial sampler")
    merge_input["sampler_policy"] = Kernel.POLICY
    merge_input["radii"] = [-.21,-.35,-.72,-.6]
    check(ka.attach(a,"merge",merge_input),"negative radius magnitudes supported")
    merge_input["radii"] = [0.,.2,.3,.4]
    check(not ka.update(merge_input),"zero radius rejected")
    a.queue_free()
    b.queue_free()
