"""Pinned private diagnostic project; no extracted assets are copied or synthesized as action visuals."""
import argparse, hashlib, json, math, os, struct, uuid
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
EXPECTED = "b4e559dbf5d98e132ea25686902da487cfd6213a9c366e9e5b1bcf1ff6e0ff9d"
DEFAULT_INPUTS = Path("D:/Dev/OpenClawCodexBridge/probes/top-ring-mixed-51061/inputs.json")
PRIVATE = ROOT / "top/assets/official/top-ring-mixed-51061"
POLICY = "linear_clamp_explicit"
MIRROR_POLICY = "native_radial_0x265_mirror_lod0"
MIXED_POLICY = "native_merge_0x25_point_0x265_linear_mirror_lod0"
POLICIES = [POLICY, MIRROR_POLICY, MIXED_POLICY]
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
    if set(m["new_files"]) != set(SOURCES) or len(m["new_files"]) != 9:
        raise ValueError("nine writable paths required")
    if set(m["source_lf_sha256"]) & set(m["new_files"]):
        raise ValueError("protected/writable partition")
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

def point_sample(spec, uv):
    """Diagnostic f32 scaled coordinate then floor, integer MIRROR at LOD0.

    Exact integer boundaries are normative; general hardware fixed-point precision
    is not modeled. Bounds keep every floor/int/address operation safe.
    """
    dims=spec["size"]
    if len(dims)!=2 or any(type(n) is not int or not 1<=n<=4096 for n in dims):
        raise ValueError("point dimensions")
    if len(uv)!=2 or any(abs(f32(v))>16 for v in uv): raise ValueError("point coordinate domain")
    index=[]
    for v,n in zip(uv,dims):
        r=math.floor(mul(v,n))%(2*n)
        index.append(r if r<n else 2*n-1-r)
    offset=4*(index[1]*dims[0]+index[0])
    return [div(v,255.) for v in spec["rgba8"][offset:offset+4]]


def merge_image(row, base, other, all_linear=False):
    width,height=row["target_size"]; result=[]
    policy=row["sampler_policy"]
    if policy not in [POLICY,MIXED_POLICY]: raise ValueError("merge-only policy")
    for y in range(height):
        for x in range(width):
            uv=[add(mul(div(v+.5,n),row["uv_rect"][j]),row["uv_rect"][j+2])
                for j,(v,n) in enumerate(((x,width),(y,height)))]
            mixed=policy==MIXED_POLICY
            rgba=merge(uv,row["radii"],row["merge_param"],row["viewport"],
                lambda c: point_sample(base,c) if mixed and not all_linear else linear_sample(base,c,MIRROR_POLICY if mixed else POLICY),
                lambda c: linear_sample(other,c,MIRROR_POLICY if mixed else POLICY))
            result.extend(int(math.floor(sat(v)*255.+.5)) for v in rgba)
    return result


def linear_sample(spec, uv, policy):
    """LOD0 texel-center reference; integer MIRROR, never REPEAT.

    Explicit f32 interpolation models shader ALU, not D3D hardware filter precision.
    """
    if policy not in [POLICY,MIRROR_POLICY]: raise ValueError("explicit sampler policy required")
    width,height=spec["size"]
    p=[add(mul(uv[j],n),-.5) for j,n in enumerate((width,height))]
    lo=[math.floor(v) for v in p]; f=[add(p[j],-lo[j]) for j in range(2)]
    def address(i,n):
        if policy == POLICY: return min(n-1,max(0,i))
        r=i%(2*n)
        return r if r<n else 2*n-1-r
    def tex(x,y):
        start=4*(address(y,height)*width+address(x,width))
        return [div(v,255.) for v in spec["rgba8"][start:start+4]]
    a,b,c,d=tex(*lo),tex(lo[0]+1,lo[1]),tex(lo[0],lo[1]+1),tex(lo[0]+1,lo[1]+1)
    row0=[add(a[j],mul(add(b[j],-a[j]),f[0])) for j in range(4)]
    row1=[add(c[j],mul(add(d[j],-c[j]),f[0])) for j in range(4)]
    return [add(row0[j],mul(add(row1[j],-row0[j]),f[1])) for j in range(4)]


def radial_image(row, spec):
    """Conditional host viewport diagnostic, RGBA8 output, no native graph claim."""
    width,height=row["target_size"]; result=[]
    for y in range(height):
        for x in range(width):
            uv=[add(mul(div(v+.5,n),row["uv_rect"][j]),row["uv_rect"][j+2])
                for j,(v,n) in enumerate(((x,width),(y,height)))]
            rgba=radial(uv,row["radial"],row["viewport"],lambda c:linear_sample(spec,c,row["sampler_policy"]))
            result.extend(int(math.floor(sat(v)*255.+.5)) for v in rgba)
    return result

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
    for name,width,height in [("odd",7,5),("single",1,1),("column",1,5),("row",7,1)]:
        textures[name]={"size":[width,height],"rgba8":[v for y in range(height) for x in range(width)
            for v in [(x*37+y*13+17)%256,(x*x*19+y*43+31)%256,(x*53+y*y*23+71)%256,(x*29+y*47+97)%256]]}
        for policy in [POLICY, MIRROR_POLICY]:
            for sign in [1,-1]:
                result.append(dict(common,id=f"{name}-{policy}-{sign}",kind="radial",s_input=name,
                    s_input_size=[width,height],sampler_policy=policy,radial=[.37,.62,.5,-.3],
                    viewport=[sign*4.,sign*3.,16.,16.],uv_rect=[1.5,1.5,-.25,-.25]))
    textures["pair"]={"size":[2,1],"rgba8":[13,39,71,103,239,193,157,211]}
    # Constant UV explicitly reaches sample coord after saturation * viewport.
    for i,coord in enumerate([-.5,-1.,0.,1.,2.,-.5-1/128,-.5+1/128,-1/128,1/128,1.-1/128,1.+1/128,2.-1/128,2.+1/128]):
        result.append(dict(common,id=f"mixed-boundary-{i}",kind="merge",sampler_policy=MIXED_POLICY,
            s_input="pair",s_input_size=[2,1],s_merge="odd",s_merge_size=[7,5],
            uv_rect=[0.,0.,1.,.5],viewport=[coord,1.,0.,0.],radii=[-1.,1.,-2.,2.],merge_param=[1.,.5,0.,0.]))
    for name in ["odd","single","column","row"]:
        for strength in [0.,1.,.375]:
            result.append(dict(common,id=f"mixed-{name}-{strength}",kind="merge",sampler_policy=MIXED_POLICY,
                s_input=name,s_input_size=textures[name]["size"],s_merge="b",s_merge_size=[8,6],
                viewport=[-3.,2.,0.,0.],radii=[-.21,.35,-.72,.6],merge_param=[.4,.6,1.25,strength]))
    for strength in [0.,1.,.375]:
        result.append(dict(common,id=f"mixed-exact-factor-{strength}",kind="merge",sampler_policy=MIXED_POLICY,
            s_input="odd",s_input_size=[7,5],s_merge="column",s_merge_size=[1,5],
            uv_rect=[0.,0.,1.,0.],viewport=[-1.375,1.,0.,0.],radii=[-1.,1.,-2.,2.],
            merge_param=[0.,0.,1.,strength]))
    return {"schema":1,"textures":textures,"cases":result}

def chain_cases():
    data=cases(); common=dict(data["cases"][0]); rows=[]
    for i,(src,dst,indims,outdims) in enumerate([
        ("A","B",[8,6],[7,5]),("B","A",[7,5],[6,4]),("A","B",[6,4],[5,3])]):
        rows.append(dict(common,id=f"chain-initial-{i}",kind="radial",s_input=src,output=dst,
            s_input_size=indims,target_size=outdims,sampler_policy=MIRROR_POLICY,
            radial=[.37,.62,.5,.2+i*.1],viewport=[1.,1.,1.,1.],uv_rect=[1.,1.,0.,0.]))
    rows.append(dict(common,id="chain-initial-merge",kind="merge",s_input="I",s_input_size=[7,5],
        s_merge="B",s_merge_size=[5,3],output="output",target_size=[9,7],
        sampler_policy=MIXED_POLICY,radii=[-.21,.35,-.72,.6],merge_param=[.4,.6,1.25,.75],
        viewport=[-2.,1.5,0.,0.],uv_rect=[1.,1.,0.,0.]))
    forward=json.loads(json.dumps(rows))
    for i,row in enumerate(forward):
        row["id"]=f"chain-forward-{i}"
        row["viewport"]=[-.75,1.25,1.,1.]
        if i<3: row["radial"]=[.2,.7,.75,-.2]
        else: row["merge_param"]=[.6,.3,.75,.375]
    return {"schema":1,"textures":{"I":data["textures"]["odd"],"A":data["textures"]["a"]},
        "cases":[{"id":"conditional-chain", "provenance":"CONDITIONAL_HOST_SUPPLIED_PREPASS_AND_TARGETS_NOT_NATIVE_GRAPH",
                   "initial":rows,"forward":forward}]}


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
    atomic(project/"chain_cases.json",chain_cases())
    atomic(project/"main.tscn", '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://test.gd" id="1"]\n[node name="PrivateRadialReadback" type="Node"]\nscript = ExtResource("1")\n')
    atomic(project/"project.godot", '[application]\nconfig/name="Private radial kernel readback"\nrun/main_scene="res://main.tscn"\n[display]\nwindow/size/viewport_width=32\nwindow/size/viewport_height=32\n[debug]\nfile_logging/enable_file_logging=false\n[rendering]\nrenderer/rendering_method="gl_compatibility"\nrenderer/rendering_method.mobile="gl_compatibility"\ntextures/default_filters/use_nearest_mipmap_filter=false\n')
    atomic(project/"export_presets.cfg", '[preset.0]\nname="Web"\nplatform="Web"\nrunnable=true\nexport_filter="all_resources"\nexclude_filter=""\ninclude_filter="*.json"\n[preset.0.options]\ncustom_template/release="D:/Dev/OpenClawCodexBridge/probes/top-visual-50859-render/web_nothreads_release.zip"\nvariant/extensions_support=false\nvariant/thread_support=false\nhtml/canvas_resize_policy=0\nprogressive_web_app/enabled=false\n')
    result={"project":str(project),"synthetic_diagnostics_only":True,"raster_verified":False,"policies":POLICIES,"diagnostic_sources":SOURCES,"new_files":SOURCES,"files":{str(p.relative_to(project)):sha(p) for p in project.rglob("*") if p.is_file()}}
    atomic(out/"prepared.json",result)
    return result

def main():
    p=argparse.ArgumentParser();p.add_argument("--inputs",type=Path,required=True);p.add_argument("--input-sha256",required=True);p.add_argument("--output",type=Path,required=True);a=p.parse_args()
    validate(a.inputs,a.input_sha256);print(json.dumps(prepare(a.output)));validate(a.inputs,a.input_sha256)
if __name__ == "__main__": main()
