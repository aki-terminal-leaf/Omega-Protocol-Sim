"""Pinned private diagnostic project; no extracted assets are copied or synthesized as action visuals."""
import argparse, hashlib, json, math, os, struct, uuid
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
EXPECTED = "376e1c4f8f5f18890f1dba217eff7d09723fef0112aaec9a89c32d034906ec7a"
DEFAULT_INPUTS = Path("D:/Dev/OpenClawCodexBridge/probes/top-ring-kernels-51043/inputs.json")
PRIVATE = ROOT / "top/assets/official/top-ring-kernels-51043"
POLICY = "linear_clamp_explicit"
WEB_TEMPLATE = Path("D:/Dev/OpenClawCodexBridge/probes/top-visual-50859-render/web_nothreads_release.zip")
WEB_TEMPLATE_SHA = "d3ee2f08cef0cf3cf6678a6355a92a8db48ccdd35cbd2e8bfd5f0e8a0b4032a0"
SOURCES = ["top/materials/original_radial_blur.gdshader", "top/materials/original_donut_merge.gdshader", "top/scripts/original_radial_kernels.gd", "tools/asset_lab/prepare_radial_kernels.py", "tools/asset_lab/run_radial_kernels.py", "tools/asset_lab/test_radial_kernels.gd", "tests/test_radial_kernels.py", "docs/asset-lab/RADIAL_KERNELS.md", "docs/asset-lab/radial-kernels.json"]

def sha(p, lf=False):
    data = Path(p).read_bytes()
    return hashlib.sha256(data.replace(b"\r\n", b"\n") if lf else data).hexdigest()

def atomic(p, value):
    p = Path(p)
    p.parent.mkdir(parents=True, exist_ok=True)
    data = value if isinstance(value, bytes) else (value if isinstance(value, str) else json.dumps(value, indent=2, allow_nan=False) + "\n").encode("utf-8")
    tmp = p.with_name(p.name + "." + uuid.uuid4().hex + ".tmp")
    with tmp.open("xb") as f:
        f.write(data)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, p)

def validate(inputs, digest):
    inputs = Path(inputs)
    if not inputs.is_absolute() or digest != EXPECTED or sha(inputs) != digest:
        raise ValueError("frozen absolute manifest/hash required")
    m = json.loads(inputs.read_bytes())
    if len(m["source_lf_sha256"]) != 105:
        raise ValueError("protected cardinality")
    for name, pin in m["source_lf_sha256"].items():
        if sha(ROOT/name, True) != pin:
            raise ValueError("protected LF mismatch: " + name)
    for name, pin in m["readonly_files"].items():
        p = Path(name)
        if p.stat().st_size != pin["bytes"] or sha(p) != pin["sha256"]:
            raise ValueError("readonly mismatch: " + name)
    return m

def f32(x):
    try:
        v = struct.unpack("<f", struct.pack("<f", x))[0]
    except (OverflowError, struct.error):
        raise ValueError("f32 overflow") from None
    if not math.isfinite(v):
        raise ValueError("nonfinite f32")
    return v

def add(a,b): return f32(f32(a)+f32(b))
def mul(a,b): return f32(f32(a)*f32(b))
def div(a,b):
    if f32(b) == 0: raise ValueError("zero f32 denominator")
    return f32(f32(a)/f32(b))
def sat(x): return min(1., max(0., x))
THIRD = struct.unpack("<f", struct.pack("<I", 0x3eaaaaab))[0]

def radial_samples(uv, payload, viewport):
    delta = [add(payload[j], -uv[j]) for j in range(2)]
    taps=[]; total=0.
    for i in range(4):
        x=mul(mul(float(i),payload[3]),THIRD)
        w=add(1.,-mul(mul(float(i),payload[2]),.25))
        coord=[min(mul(sat(add(mul(delta[j],x),uv[j])),viewport[j]), f32(viewport[j+2])) for j in range(2)]
        taps.append((coord,w)); total=add(total,w)
    if total == 0: raise ValueError("zero weight sum")
    return taps,total

def radial(uv,payload,viewport,sample):
    taps,total=radial_samples(uv,payload,viewport); accum=[0.]*4
    for coord,w in taps:
        rgba=sample(coord)
        accum=[add(accum[j],mul(rgba[j],w)) for j in range(4)]
    return [div(x,total) for x in accum]

def merge_factor(uv,radii,payload):
    r=[div(add(uv[j%2],-payload[j%2]),radii[j]) for j in range(4)]
    inner=add(mul(r[0],r[0]),mul(r[1],r[1]))
    outer=add(mul(r[2],r[2]),mul(r[3],r[3]))
    return mul(sat(min(add(mul(add(inner,-1.),payload[2]),1.),add(mul(add(1.,-outer),payload[2]),.5))),payload[3])

def merge(uv,radii,payload,viewport,base,other):
    f=merge_factor(uv,radii,payload)
    coord=[mul(sat(uv[j]),viewport[j]) for j in range(2)]
    a,b=base(coord),other(coord)
    return [add(a[j],mul(f,add(b[j],-a[j]))) for j in range(4)]

def cases():
    textures={}
    for name,seed in [("a",3),("b",29)]:
        textures[name]={"size":[8,6], "rgba8":[v for y in range(6) for x in range(8) for v in [(x*31+y*7+seed)%256,(x*x*13+y*37+seed)%256,(x*19+y*y*11+seed)%256,(x*23+y*41+seed)%256]]}
    common={"sampler_policy":POLICY,"color_space":"raw_rgba8_no_srgb","target":"rgba8_unorm_blend_disabled","provenance":"SYNTHETIC_DIAGNOSTIC_NOT_ORIGINAL_VISUAL","target_size":[9,7],"s_input":"a","s_input_size":[8,6],"viewport":[.75,.8,.375,.5],"uv_rect":[1.25,1.5,-.125,-.25]}
    result=[]
    for i,p in enumerate([[.37,.62,1.,.7],[.2,.8,0.,0.],[.7,.3,.5,-.3]]):
        result.append(dict(common,id="radial-"+str(i),kind="radial",radial=p))
    for i,strength in enumerate([0.,.75,1.]):
        result.append(dict(common,id="merge-"+str(i),kind="merge",radii=[.21,.35,.72,.6],merge_param=[.4,.6,1.25,strength],s_merge="b",s_merge_size=[8,6]))
    return {"schema":1,"textures":textures,"cases":result}

def prepare(out):
    if sha(WEB_TEMPLATE) != WEB_TEMPLATE_SHA: raise ValueError("pinned private Web template mismatch")
    out=Path(out)
    if not out.is_absolute() or out.exists(): raise ValueError("new absolute output required")
    out.mkdir(parents=True)
    project=out/"project"
    for source in SOURCES[:3]:
        atomic(project/Path(source).relative_to("top"),(ROOT/source).read_bytes())
    atomic(project/"test.gd",(ROOT/"tools/asset_lab/test_radial_kernels.gd").read_bytes())
    atomic(project/"cases.json",cases())
    atomic(project/"numeric_cases.json",cases())
    atomic(project/"main.tscn", '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://test.gd" id="1"]\n[node name="PrivateRadialReadback" type="Node"]\nscript = ExtResource("1")\n')
    atomic(project/"project.godot", '[application]\nconfig/name="Private radial kernel readback"\nrun/main_scene="res://main.tscn"\n[display]\nwindow/size/viewport_width=32\nwindow/size/viewport_height=32\n[debug]\nfile_logging/enable_file_logging=false\n[rendering]\nrenderer/rendering_method="gl_compatibility"\nrenderer/rendering_method.mobile="gl_compatibility"\ntextures/default_filters/use_nearest_mipmap_filter=false\n')
    atomic(project/"export_presets.cfg", '[preset.0]\nname="Web"\nplatform="Web"\nrunnable=true\nexport_filter="all_resources"\nexclude_filter=""\ninclude_filter="*.json"\n[preset.0.options]\ncustom_template/release="D:/Dev/OpenClawCodexBridge/probes/top-visual-50859-render/web_nothreads_release.zip"\nvariant/extensions_support=false\nvariant/thread_support=false\nhtml/canvas_resize_policy=0\nprogressive_web_app/enabled=false\n')
    result={"project":str(project),"synthetic_diagnostics_only":True,"raster_verified":False,"files":{str(p.relative_to(project)):sha(p) for p in project.rglob("*") if p.is_file()}}
    atomic(out/"prepared.json",result)
    return result

def main():
    p=argparse.ArgumentParser();p.add_argument("--inputs",type=Path,required=True);p.add_argument("--input-sha256",required=True);p.add_argument("--output",type=Path,required=True);a=p.parse_args()
    validate(a.inputs,a.input_sha256);print(json.dumps(prepare(a.output)));validate(a.inputs,a.input_sha256)
if __name__ == "__main__": main()
