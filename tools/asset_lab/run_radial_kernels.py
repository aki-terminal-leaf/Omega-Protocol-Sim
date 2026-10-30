"""Serial bounded WindowsJobObject tests and private export. Never a rendering acceptance gate."""
import argparse, json, os, sys, time, uuid
from pathlib import Path
from prepare_radial_kernels import ROOT, PRIVATE, EXPECTED, SOURCES, POLICY, atomic, sha, validate
GODOT=Path("D:/Dev/OpenClawCodexBridge/tools/godot-4.7.2/Godot_v4.7.2-stable_win64.exe")
ENGINE_SHA="ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424"
GUARD_SHA="ca9c29ef8d28ef4bb8d764dbc1eb5a03745eb85173c6d417d5896fa824c3b87a"

def document(out,report):
    info={"schema":1,"status":"PARAMETERIZED_KERNELS_IMPLEMENTED_NATIVE_INTEGRATION_OPEN","rendering_accepted":False,"all96_accepted":False,"latest_summary":str(out/"summary.json"),"explicit_policy":POLICY,"source_evidence":{"manifest_sha256":EXPECTED,"accepted_contract":"docs/asset-lab/ring-native.json#shader_contract_audit","radial_literal_bits":"0x3eaaaaab","native_vertex_ported":False},"unsupported_native_dependencies":["resource factory installation","small-buffer upload/flush","sampler 0x265 decoding","A/B and merge texture ownership, formats and dimensions","absent IRad/defaults","native clock/lifetime"],"test_evidence":{"numeric_pass":report["numeric_pass"],"web_export_ready":report["web_export_ready"],"raster_verified":False,"headless_is_not_shader_compile_evidence":True,"status":report["status"],"blocker":report.get("blocker")},"project":report.get("project"),"web_output":report.get("web_output"),"engine_sha256":ENGINE_SHA}
    atomic(ROOT/"docs/asset-lab/radial-kernels.json",info)
    atomic(ROOT/"docs/asset-lab/RADIAL_KERNELS.md",f"""# Parameterized radial kernels ? private conditional contract

Pixel-only RadialBlur and DonutMerge implement the accepted pinned SM5 formulas.
Native action31567 / P3-02 / all96 integration and rendering acceptance remain **false**.
Source evidence: `RING_NATIVE.md` and `ring-native.json.shader_contract_audit`;
RadialBlur ShCd SHA `218b8478ba791aacd1fdc3b773ff88e2bab905e38002bf3a0479c79d40bbec2e`,
DonutMerge `e3dafd25f1422745231d06a643c0b2896ff6decb36ee94153408b5101baae117`,
VSSampling1 `59a20841f65fcd46d95949c644d5c40f2b7646945fdb25f991c8fb067882d1e9`.
No native constructors were retraced and no native capture or game execution occurred.

## Inputs and safety

Instantiate the RefCounted helper and call `attach(CanvasItem, "radial"|"merge", inputs)`.
`update(inputs)` replaces all supplied state; `release()` removes its own attachment.
Each instance owns a separate material/shader. Check `is_current()` before drawing after
external changes. Updates fail closed and release on stale texture bytes, texture sizes,
shader code, material replacement or uniform mutation; no automatic process or clock runs.
The helper cannot prevent callers from bypassing it and mutating Godot resources between checks.
The direct material is an embedding boundary, not an enforced native render graph.

All input fields are required: `viewport` float4; `uv_rect` float4; `target_size` integer2;
`s_input` ImageTexture and `s_input_size` integer2; `radial` float4 for radial;
`radii`, `merge_param` float4 plus `s_merge` and `s_merge_size` for merge;
nonempty `provenance`; `sampler_policy="linear_clamp_explicit"`;
`color_space="raw_rgba8_no_srgb"`; `target="rgba8_unorm_blend_disabled"`.
These policies are explicit conditional embedding choices, **not decoded native 0x265**.
Caller must supply an RGBA8 non-HDR target of the stated dimensions. The helper validates
the declared contract and textures; the private harness constructs the actual target.
Textures must be RGBA8 without mipmaps. No `source_color` conversion, premultiplication,
COLOR multiplication, blending or spatial tonemapping is applied by the kernels.

Conservative host domain: float4 components have magnitude <=16; radii magnitude >=1e-4;
float32 radial weight sum magnitude >=1e-4; generated UV endpoints within [-2,2];
positive integer dimensions <=4096. This bounds intermediate math for RGBA8 inputs,
rejects nonfinite values, float32 overflow and singular/near-singular divisions.
It deliberately rejects some valid native finite inputs rather than altering shader math.
The shader has no denominator guard. The weight loop uses integer i=0..3, float32
0x3eaaaaab = 0.3333333432674407958984375, and implicit `texture()` sampling.
Merge never uses viewport.zw. All four color channels participate in both kernels.
No packet mapping, viewport derivation, fixed-rate clock, defaults or native VS is implemented.
Only the first native viewport vector is consumed by these pixel shaders.

## Numeric and Web protocol

Python references explicitly round arithmetic through float32; Godot numeric weight tests
use PackedFloat32Array. These are separate from GPU results. SM5 refactoringAllowed and
cross-driver fused multiply/add differences mean no bit-exact GPU promise is made.
Headless tests inspect actual material uniforms, missing/invalid/reverse updates, isolation,
stale texture/uniform mutation, release and reattachment. Headless is **not shader raster
or shader compile evidence**. Python tests read actual SHA-pinned ShCd DXBC chunks,
reflection and disassembly, including the MUL at SHEX word75 and immediate operand at word81. Diagnostics are synthetic gradients
with varied alpha, never substitutes for original action visuals.

Prepare: `python -B tools/asset_lab/prepare_radial_kernels.py --inputs ABS_MANIFEST --input-sha256 {EXPECTED} --output NEW_ABS_OUT`.
Run: `python -B tools/asset_lab/run_radial_kernels.py --inputs ABS_MANIFEST --input-sha256 {EXPECTED} [--output NEW_ABS_OUT]`.
The runner validates all 105 protected LF sources and all readonly files before/after,
uses the pinned WindowsJobObject runner serially, 90s engine/45s other children,
240s cumulative, 1.5GiB hard memory and 8GiB free floor. POSIX work_guard uses fcntl
and is unavailable on this Windows host. Each run preserves unique logs and receipts.
No automatic retry, global installs, network publication or desktop execution.

Portable project: `{report.get('project')}`.
Web destination: `{report.get('web_output')}`.
Immutable final summary: `{out/'summary.json'}`.
Current result: **{report['status']}**. Numeric pass: `{report['numeric_pass']}`.
Web export ready: `{report['web_export_ready']}`. Blocker evidence: see summary `blocker` and the preserved per-child log paths.
Exact exported/project file hashes and child receipts are in that summary.

Parent protocol: modify the private project's `cases.json` before headless re-export.
It contains `textures` keyed by ID with integer `size` and row-major `rgba8` byte arrays,
and at most 64 `cases` (unique IDs, at most 16 textures, textures/targets <=256 per axis) with the required fields above (texture fields use those IDs),
plus unique `id` and `kind`. Existing six cases are deterministic examples.
`numeric_cases.json` is a separate fixed helper-test fixture, so parent case replacement
does not change lifecycle test assumptions. The portable
project contains no absolute original-resource paths. Export using pinned Godot's
`--headless --path PROJECT --export-release Web WEB/index.html` after import.
Serve the exported directory privately using the parent's existing Web tooling; open
index.html in headless Chromium and wait for `window.__radial_finished === true`
with a finite parent timeout (suggested 45s). Read `window.__radial_result` as JSON.
It contains `finished`, `ok`, `failures`, and per-case `id`, `width`, `height`, `rgba8`.
The finite harness renders one isolated SubViewport per case then pauses the tree.
No play UI, looping, next action, duration or accumulation is present.

Input texture bytes and readback rows are top-to-bottom. Godot Canvas UV at pixel center
is ((x+0.5)/width,(y+0.5)/height), then uv = UV*uv_rect.xy + uv_rect.zw.
This explicit Godot bridge has **no extra Y flip** and is not a VSSampling1 port.
Compare against independent linear-clamp texel-center sampling, float32 kernel arithmetic
and RGBA8 clamp/quantization. Orientation, alpha, color space and driver differences
must be adjudicated from actual readback, not screenshots or this headless pass.
The harness bypasses presentation-canvas alpha by reading the SubViewport image directly.

Native integration remains gated on resource factory identity, small CB upload/flush,
0x265 and merge sampler state, A/B+merge target ownership/formats/dimensions, absent IRad,
default values, clock and lifetime. Export readiness is not rendering/all96 acceptance.
""")

def main():
    p=argparse.ArgumentParser();p.add_argument("--inputs",type=Path,required=True);p.add_argument("--input-sha256",required=True);p.add_argument("--output",type=Path);a=p.parse_args()
    out=a.output or PRIVATE/("run-"+str(uuid.uuid4()))
    if not out.is_absolute() or out.exists() or not out.resolve().is_relative_to(ROOT): raise ValueError("unique absolute worktree output required")
    out.mkdir(parents=True);print(out,flush=True)
    report={"status":"BLOCKED","receipts":[],"numeric_pass":False,"web_export_ready":False,"protected105_exact":False,"raster_verified":False,"rendering_accepted":False,"all96_accepted":False,"explicit_policy":POLICY}
    start=time.monotonic()
    try:
        validate(a.inputs,a.input_sha256)
        if sha(ROOT/"tools/asset_lab/run_cinematic_integration.py",True)!=GUARD_SHA: raise ValueError("guard pin mismatch")
        from run_cinematic_integration import run
        def gate(label,argv,limit,cwd):
            remaining=240-(time.monotonic()-start)
            if remaining<=0: raise RuntimeError("cumulative 240s exhausted")
            r=run(out,label,[str(v) for v in argv],min(limit,remaining),cwd)
            r["log"]=str(out/(label+".log"))
            r["log_file"]=r["log"]
            text=Path(r["log"]).read_text(errors="replace") if Path(r["log"]).exists() else ""
            r["ok"]=r["ok"] and not any(s.lower() in text.lower() for s in ["SCRIPT ERROR","Parse Error","Compile Error","SHADER ERROR","Shader compilation failed"])
            atomic(out/(label+"-receipt.json"),r);report["receipts"].append(r)
            if not r["ok"]: raise RuntimeError(label+" failed; log="+r["log"]+"; exit="+str(r["exit"])+"; reason="+str(r["stop_reason"])+"; tail="+text[-2500:])
            return text
        if sha(GODOT)!=ENGINE_SHA: raise ValueError("pinned Godot executable mismatch")
        report["engine_sha256"]=ENGINE_SHA
        gate("prepare",[sys.executable,"-B",ROOT/"tools/asset_lab/prepare_radial_kernels.py","--inputs",a.inputs,"--input-sha256",a.input_sha256,"--output",out/"prepared"],45,ROOT)
        project=out/"prepared/project";web=out/"web";web.mkdir()
        report["project"]=str(project);report["web_output"]=str(web/"index.html")
        version=gate("version",[GODOT,"--headless","--version"],90,project)
        if "4.7.2.stable.official.ed1daf0bf" not in version: raise ValueError("engine build mismatch")
        gate("python-tests",[sys.executable,"-B","-m","unittest","discover","-s","tests","-p","test_radial_kernels.py","-v"],45,ROOT)
        gate("import",[GODOT,"--headless","--path",project,"--editor","--import","--quit"],90,project)
        text=gate("godot-numeric",[GODOT,"--headless","--path",project],90,project)
        if '"numeric_pass":true' not in text: raise RuntimeError("missing actual numeric success marker")
        report["numeric_pass"]=True
        gate("web-export",[GODOT,"--headless","--path",project,"--export-release","Web",web/"index.html"],90,project)
        for suffix in ["html","js","wasm","pck"]:
            if not (web/("index."+suffix)).is_file(): raise RuntimeError("missing exported "+suffix)
        report["web_export_ready"]=True
        report["status"]="KERNEL_NUMERIC_PASS_WEB_READY"
    except Exception as e:
        report["blocker"]=str(e)
    finally:
        try:
            m=validate(a.inputs,a.input_sha256);report["protected105_exact"]=True;report["readonly_files_exact"]=len(m["readonly_files"])
        except Exception as e:
            report["blocker"]=str(e);report["status"]="BLOCKED"
        report["seconds"]=time.monotonic()-start
        document(out,report)
        report["source_sha256"]={name:sha(ROOT/name,True) for name in SOURCES}
        report["output_sha256"]={str(p.relative_to(out)):sha(p) for p in out.rglob("*") if p.is_file() and ".godot" not in p.parts}
        atomic(out/"summary.json",report)
    print(json.dumps({"status":report["status"],"blocker":report.get("blocker")},ensure_ascii=True),flush=True)
    return int(report["status"]=="BLOCKED")
if __name__=="__main__":sys.exit(main())
