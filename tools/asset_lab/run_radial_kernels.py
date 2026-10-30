"""Serial bounded WindowsJobObject tests and private export. Never a rendering acceptance gate."""
import argparse, json, os, shutil, sys, time, uuid
from pathlib import Path
from prepare_radial_kernels import ROOT, PRIVATE, EXPECTED, SOURCES, POLICY, POLICIES, atomic, sha, validate
GODOT=Path("D:/Dev/OpenClawCodexBridge/tools/godot-4.7.2/Godot_v4.7.2-stable_win64.exe")
ENGINE_SHA="ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424"
GUARD_SHA="ca9c29ef8d28ef4bb8d764dbc1eb5a03745eb85173c6d417d5896fa824c3b87a"

def document(out,report):
    dependencies=["native merge/prepass sampler words 377920", "target dimensions/formats/views/aliasing", "Default prepass math", "handle factory/cache identity", "absent IRad/defaults", "default clock/lifetime", "complete dynamic native graph"]
    info={"schema":1,"status":report["status"],"rendering_accepted":False,"all96_accepted":False,
        "latest_summary":str(out/"summary.json"),"policies":POLICIES,
        "source_evidence":{"manifest_sha256":EXPECTED,"radial_literal_bits":"0x3eaaaaab","native_vertex_ported":False},
        "unsupported_native_dependencies":dependencies,"test_evidence":{k:report.get(k) for k in
            ["numeric_pass","web_export_ready","protected106_exact","raster_verified","blocker"]},
        "project":report.get("project"),"web_output":report.get("web_output"),"engine_sha256":ENGINE_SHA,
        "new_files":[s for s in SOURCES if s != SOURCES[1]],"diagnostic_sources":SOURCES}
    atomic(ROOT/"docs/asset-lab/radial-kernels.json",info)
    atomic(ROOT/"docs/asset-lab/RADIAL_KERNELS.md",f"""# Radial native mirror sampler: isolated conditional diagnostic

Schema 1. rendering_accepted=false; all96_accepted=false. Owner action31567/P3-02/all96 remains OPEN.
The parent-reviewed gpu_bridge_audit establishes radial packed 0x265: MIN_MAG_LINEAR_MIP_POINT
(filter 0x14), U/V MIRROR (2), W CLAMP (3), bias 0, LOD 0, anisotropy 1, comparison NEVER.
This increment implements its 2D LOD0 sampling semantics, not complete native rendering.
DonutMerge source is immutable; its native sampler and prepass words 377920 remain UNKNOWN.

## Explicit helper schema

Call attach(CanvasItem, "radial"|"merge", inputs), update(inputs), release(), is_current().
Required inputs: sampler_policy, color_space="raw_rgba8_no_srgb",
target="rgba8_unorm_blend_disabled", nonempty provenance; target_size integer2;
viewport and uv_rect float4; s_input ImageTexture and s_input_size integer2.
Radial requires radial float4. Merge requires radii and merge_param float4,
s_merge ImageTexture and s_merge_size integer2.
Policies: linear_clamp_explicit retains existing hardware clamp filtering;
native_radial_0x265_mirror_lod0 is radial-only, explicitly selected, never a default.
Merge rejects native radial policy. A missing/invalid policy fails closed and releases.
Updates support either radial policy in both directions. Per-instance material/shader
ownership isolates updates. is_current checks sampler boolean, all uploaded uniforms,
texture identity/dimensions/bytes and shader identity/code. External mutation fails closed.
No live lifecycle, clock, or native resource factory is introduced.

Conservative host domain: float4 magnitudes <=16, radii MAGNITUDE >=1e-4 (negative radii
remain allowed), f32 radial weight-sum magnitude >=1e-4, UV endpoints within [-2,2].
RGBA8 input textures have no mipmaps, axes 1..4096 including 1x1/1xN/Nx1.
Declared target axes are integers 2..4096. Portable harness caps axes at 256 and checks
actual SubViewport size; target 1x1 is rejected. The caller supplies a matching non-HDR target.
All four channels remain raw; no source_color, premultiplication or blending.

## Mirror proof and precision boundary

For each axis p=f32(f32(coord*N)-0.5), i=floor(p), f=p-i. Each neighbor i and i+1
is addressed with r=((i % (2*N)) + 2*N) % (2*N), index=r if r<N else 2*N-1-r.
The infinite texel-center lattice therefore duplicates both edge texels, reflecting
...1,0,0,1,...,N-1,N-1,... . At normalized seams 0,1,2 the two neighbors are the
same edge texel, so filtering is continuous across both sides. Negative periods use
positive modulo; N=1 maps every neighbor to zero. This is MIRROR, not repeat_enable/REPEAT.
Four texelFetch(...,0) loads are interpolated horizontally then vertically on all RGBA.
LOD0 is explicit; textureSize(...,0) is explicit. No extra coordinate clamp is introduced.
The original four-tap order, saturation*viewport/min, weights and raw third bits 3eaaaaab
are unchanged. Coordinates stay within [-16,16]; N<=4096 bounds p to [-65536.5,65535.5],
so floor/int/modulo are safe. Filtering differences/weights are bounded for UNORM inputs.
Python rounds each reference arithmetic operation to f32. Shader compiler FMA/refactoring
and D3D hardware subtexel/filter precision may differ from this manual f32 bilinear
implementation: exact address semantics are implemented, bit-identical hardware filtering
is NOT claimed. Actual GPU readback remains a separate parent gate.

## Evidence and portable handoff

Manifest SHA256: {EXPECTED}. All 106 protected LF sources (including merge) and all
readonly files are checked before/after. Manifest new_files is the eight writable existing
paths; diagnostic_sources lists nine kernel files including immutable merge.
Runner uses SHA-pinned Godot 4.7.2 main executable {ENGINE_SHA} and the existing custom Web
release template d3ee2f08cef0cf3cf6678a6355a92a8db48ccdd35cbd2e8bfd5f0e8a0b4032a0.
A byte-identical private copy of the main exe uses local _sc_/editor_data and explicit
log paths to isolate editor settings/user data. No default/global template install. WindowsJobObject children are serial, 90s engine/45s
others, 240s cumulative, 1.5GiB hard limit, 8GiB free floor. POSIX work_guard's fcntl is
unavailable on Windows. Unique failures/logs/receipts are preserved; publication is atomic.
Headless lifecycle/numeric tests are neither shader compilation nor raster evidence.

Latest summary: {out/'summary.json'}
Project: {report.get('project')}
Web: {report.get('web_output')}
Status: {report['status']}; numeric_pass={report['numeric_pass']}; web_export_ready={report['web_export_ready']}.
Blocker: {report.get('blocker')}.
Summary source_sha256 explicitly hashes all nine listed diagnostic sources with LF
normalization, including generated docs; summary itself is excluded. Output hashes exclude
.godot caches and summary itself. Parent independently freezes all 114 source files.

Parent may replace project cases.json, then re-export. numeric_cases.json stays separate.
Cases schema1 has textures keyed by ID with size and row-major rgba8, plus <=64 unique-ID
cases with helper fields (texture references use IDs); <=16 textures. Readback retains all
RGBA and top-to-bottom rows. UV=(pixel+0.5)/target_size transformed by uv_rect, no Y flip.
Poll window.__radial_finished; window.__radial_result contains finished/ok/failures and
per-case id/width/height/rgba8. Harness pauses after finite isolated SubViewport rendering.
Fixtures cover clamp and mirror, odd 7x5 with varied alpha, singleton axes, and positive/
negative out-of-range sampling from explicit diagnostic viewport values. These are host
choices, NOT proof of a native viewport. No optional three-pass graph was added.

Remaining native dependencies: {', '.join(dependencies)}. Initial direct C/A/B setup and
rebinding evidence remains static only. Export readiness is not actual Chromium readback,
original visual acceptance, mainWeb publication, or all96 acceptance.
""")

def main():
    p=argparse.ArgumentParser();p.add_argument("--inputs",type=Path,required=True);p.add_argument("--input-sha256",required=True);p.add_argument("--output",type=Path);a=p.parse_args()
    out=a.output or PRIVATE/("run-"+str(uuid.uuid4()))
    if not out.is_absolute() or out.exists() or not out.resolve().is_relative_to(PRIVATE.resolve()): raise ValueError("unique absolute worktree output required")
    out.mkdir(parents=True);print(out,flush=True)
    report={"status":"BLOCKED","receipts":[],"numeric_pass":False,"web_export_ready":False,"protected106_exact":False,"raster_verified":False,"rendering_accepted":False,"all96_accepted":False,"policies":POLICIES,"new_files":[s for s in SOURCES if s != SOURCES[1]],"diagnostic_sources":SOURCES}
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
        # Godot self-contained mode: exact pinned main exe, local editor_data.
        # Never write _sc_ beside the shared executable or use global settings.
        engine=out/"engine"/GODOT.name
        atomic(engine,GODOT.read_bytes())
        if sha(engine)!=ENGINE_SHA: raise ValueError("private engine copy mismatch")
        atomic(engine.parent/"_sc_","")
        report["private_engine"]=str(engine)
        gate("prepare",[sys.executable,"-B",ROOT/"tools/asset_lab/prepare_radial_kernels.py","--inputs",a.inputs,"--input-sha256",a.input_sha256,"--output",out/"prepared"],45,ROOT)
        project=out/"prepared/project";web=out/"web";web.mkdir()
        report["project"]=str(project);report["web_output"]=str(web/"index.html")
        version=gate("version",[engine,"--headless","--log-file",out/"version-engine.log","--version"],90,project)
        if "4.7.2.stable.official.ed1daf0bf" not in version: raise ValueError("engine build mismatch")
        gate("python-tests",[sys.executable,"-B","-m","unittest","discover","-s","tests","-p","test_radial_kernels.py","-v"],45,ROOT)
        gate("import",[engine,"--headless","--log-file",out/"import-engine.log","--path",project,"--editor","--import","--quit"],90,project)
        text=gate("godot-numeric",[engine,"--headless","--log-file",out/"numeric-engine.log","--path",project],90,project)
        if '"numeric_pass":true' not in text: raise RuntimeError("missing actual numeric success marker")
        report["numeric_pass"]=True
        gate("web-export",[engine,"--headless","--log-file",out/"export-engine.log","--path",project,"--export-release","Web",web/"index.html"],90,project)
        for suffix in ["html","js","wasm","pck"]:
            if not (web/("index."+suffix)).is_file(): raise RuntimeError("missing exported "+suffix)
        report["web_export_ready"]=True
        report["status"]="KERNEL_NUMERIC_PASS_WEB_READY"
    except Exception as e:
        report["blocker"]=str(e)
    finally:
        try:
            m=validate(a.inputs,a.input_sha256);report["protected106_exact"]=True;report["readonly_files_exact"]=len(m["readonly_files"])
        except Exception as e:
            report["blocker"]=str(e);report["status"]="BLOCKED"
        report["owned_cache_cleanup"]=[]
        for cache in [out/"prepared/project/.godot",out/"engine/editor_data/cache"]:
            if cache.exists():
                if not cache.resolve().is_relative_to(out.resolve()): raise ValueError("cache outside owned output")
                try:
                    # Extended Windows path handles long Godot generated folding names.
                    shutil.rmtree("\\\\?\\" + str(cache.resolve()))
                    report["owned_cache_cleanup"].append(str(cache))
                except OSError as e:
                    report["status"]="BLOCKED"
                    report["blocker"]="owned cache cleanup: "+str(e)
        report["seconds"]=time.monotonic()-start
        document(out,report)
        report["source_hash_scope"]="All nine diagnostic_sources, LF-normalized, including docs; excludes summary itself"
        report["source_sha256"]={name:sha(ROOT/name,True) for name in SOURCES}
        report["output_sha256"]={str(p.relative_to(out)):sha(p) for p in out.rglob("*") if p.is_file() and ".godot" not in p.parts}
        atomic(out/"summary.json",report)
    print(json.dumps({"status":report["status"],"blocker":report.get("blocker")},ensure_ascii=True),flush=True)
    return int(report["status"]=="BLOCKED")
if __name__=="__main__":sys.exit(main())
