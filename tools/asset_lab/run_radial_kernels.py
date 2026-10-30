"""Serial bounded WindowsJobObject tests and private export. Never a rendering acceptance gate."""
import argparse, json, os, shutil, sys, time, uuid
from pathlib import Path
from prepare_radial_kernels import ROOT, PRIVATE, EXPECTED, SOURCES, POLICY, POLICIES, atomic, sha, validate
GODOT=Path("D:/Dev/OpenClawCodexBridge/tools/godot-4.7.2/Godot_v4.7.2-stable_win64.exe")
ENGINE_SHA="ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424"
GUARD_SHA="ca9c29ef8d28ef4bb8d764dbc1eb5a03745eb85173c6d417d5896fa824c3b87a"

def document(out,report):
    limitations=["native formats/sRGB/blend/allocation/views/aliasing", "Default prepass math", "clock/IRad/lifetime/factoryCreate identity", "native input/output rebinding and complete dynamic graph", "actual compiled private WebGL allRGBA comparison against independent raw DXBC oracle pending"]
    report["limitations"]=limitations
    report["latest_summary"]=str(out/"summary.json")
    info={"schema":1,"status":report["status"],"rendering_accepted":False,"all96_accepted":False,
        "latest_summary":str(out/"summary.json"),"policies":POLICIES,"diagnostic_sources":SOURCES,
        "source_evidence":{"manifest_sha256":EXPECTED,"parent_review":"target_factory_audit full3983 normalCFG and exact leaf377920"},
        "chain_diagnostic_ready":report["chain_diagnostic_ready"],"limitations":limitations,
        "test_evidence":{k:report.get(k) for k in ["numeric_pass","web_export_ready","protected105_exact","raster_verified","blocker"]}}
    atomic(ROOT/"docs/asset-lab/radial-kernels.json",info)
    atomic(ROOT/"docs/asset-lab/RADIAL_KERNELS.md",f"""# Mixed merge sampler and conditional private chain

Schema 1; rendering_accepted=false; all96_accepted=false. Action31567/P3-02/all96 remains OPEN.
Parent target_factory_audit establishes prepass 0x265 LINEAR MIRROR, merge sInput 0x25 POINT
MIRROR and sMerge1 0x265 LINEAR MIRROR, bias zero / LOD0. I=M+68, A=M+260, B=M+268,
output=M+258; static I->A, A->B->A->B, merge(I,B)->output; rebinding can change endpoints.
This diagnostic does not implement unknown Default prepass math or native resource identity.
Independent immutable native documentation was not modified.

## Explicit policies and bounds

Exactly three policies: {', '.join(POLICIES)}.
linear_clamp_explicit remains compatible for both kernels. native_radial_0x265_mirror_lod0
is radial-only and unchanged. native_merge_0x25_point_0x265_linear_mirror_lod0 is merge-only.
Missing, invalid and cross-kind policies fail closed and release. attach/update/release/is_current
track every uniform, sampler resource, texture dimensions/format/bytes, shader identity/code.
Clamp<->mixed updates work in both directions with isolated material/shader instances.
Required provenance, raw_rgba8_no_srgb, rgba8_unorm_blend_disabled, target_size, viewport,
uv_rect, input texture/dimensions and kernel parameters remain explicit. Input axes 1..4096,
no mips, finite f32 float4 magnitudes <=16, UV endpoints [-2,2], radius magnitude >=1e-4
(negative radii allowed), radial weight-sum magnitude >=1e-4. Actual target axes 2..4096;
private portable target axes <=256. No 1x1 target support, no native default/lifecycle mapping.

POINT uses f32(coord*N), then floor, then integer MIRROR with positive modulo 2*N and
index r if r<N else 2*N-1-r. At exact integer scaled coordinates k this follows the parent's
normative exact-boundary lemma: coord=-0.5,N=2 maps texel 0. Continuous UV folding before
floor would incorrectly select texel 1. No epsilon or source rounding is added. Noninteger
coordinates use an explicit diagnostic f32 convention, not a bit-identical D3D hardware claim;
D3D fixed-point sampler precision near boundaries remains a renderer comparison concern.
Bounds |coord|<=16 and N<=4096 bound point scaled coordinates to +/-65536, safe for floor/int.
LINEAR uses maintained texel-center p=coord*N-0.5, integer-MIRROR neighbors and four LOD0
texelFetch loads, horizontal then vertical RGBA interpolation. Neighbor floor/int/modulo are
bounded within +/-65538. MIRROR is never repeat_enable/REPEAT. Raw DonutMerge pixel
arithmetic/order and all RGBA are preserved; compiler FMA/filter precision can differ.

## Portable protocol and conditional chain

cases.json is parent-overridable, separate from numeric_cases.json; schema1, <=64 unique
cases and <=16 textures, each axis <=256. All schemas and bindings validate before rendering.
window.__radial_finished and window.__radial_result report finished/ok=false on invalid packs,
including failures with no results array. Output rows are allRGBA top-to-bottom; UV is
(pixel+0.5)/target transformed by explicit uv_rect, no Y flip. Fixtures include exact negative
boundaries, seams and robust away-boundary coordinates, unequal/odd/singleton inputs, varied
alpha, signed radii and distinguishable mixed versus all-linear/clamp after saturation*viewport.

chain_cases.json schema1 contains exactly host texture IDs I and A, and 1..2 unique chain cases.
Each case requires id/provenance and initial/forward arrays of exactly four fully explicit helper
rows. First three are radial A->B, B->A, A->B with output IDs and input/target dimensions;
last is mixed merge(I,B)->output. No implicit inputs, Default copy, downsample or native allocation.
Each row declares viewport/radial or radii+merge_param/uv_rect/target_size and policy/provenance.
The harness runs initial, forward, reverse(initial), retaining bindings and updating resources
without mutating attached textures. Each intermediate is read back and quantized RGBA8 before
reattachment. chain_results records host prepass A, all three radial outputs and final merge for
every state. This is a conditional host-supplied prepass/targets diagnostic, NOT a native passgraph.
CPU chain tests and lifecycle/schema tests are separate from actual WebGL raster acceptance.

## Evidence

Manifest {EXPECTED}: 105 protected LF sources plus ALL readonly files checked before/after;
nine writable diagnostic sources pinned explicitly. Parent independently freezes 114 sources.
Pinned main Godot 4.7.2 SHA {ENGINE_SHA}, custom Web release template
 d3ee2f08cef0cf3cf6678a6355a92a8db48ccdd35cbd2e8bfd5f0e8a0b4032a0.
WindowsJobObject serial limits: 90s engine/45s others/300s cumulative, 1.5GiB hard and 8GiB free.
POSIX work_guard requires unavailable fcntl; existing pinned Windows runner is used. Private
_sc_/editor_data/cache and logs only; no default templates/global settings. Failures retained.
No native capture/binary probe, browser, desktop, commit, push or deployment was performed.
Latest summary: {out/'summary.json'}
Project: {report.get('project')}
Web: {report.get('web_output')}
Status: {report['status']}; numeric_pass={report['numeric_pass']}; web_export_ready={report['web_export_ready']};
chain_diagnostic_ready={report['chain_diagnostic_ready']}; raster_verified=false.
Blocker: {report.get('blocker')}.
Remaining limitations: {'; '.join(limitations)}. Export readiness is not GPU acceptance or all96 acceptance.
""")

def main():
    p=argparse.ArgumentParser();p.add_argument("--inputs",type=Path,required=True);p.add_argument("--input-sha256",required=True);p.add_argument("--output",type=Path);a=p.parse_args()
    out=a.output or PRIVATE/("run-"+str(uuid.uuid4()))
    if not out.is_absolute() or out.exists() or not out.resolve().is_relative_to(PRIVATE.resolve()): raise ValueError("unique absolute worktree output required")
    out.mkdir(parents=True);print(out,flush=True)
    report={"schema":1,"chain_diagnostic_ready":False,"status":"BLOCKED","receipts":[],"numeric_pass":False,"web_export_ready":False,"protected105_exact":False,"raster_verified":False,"rendering_accepted":False,"all96_accepted":False,"policies":POLICIES,"new_files":SOURCES,"diagnostic_sources":SOURCES}
    start=time.monotonic()
    try:
        validate(a.inputs,a.input_sha256)
        if sha(ROOT/"tools/asset_lab/run_cinematic_integration.py",True)!=GUARD_SHA: raise ValueError("guard pin mismatch")
        from run_cinematic_integration import run
        def gate(label,argv,limit,cwd,expected_exit=0):
            remaining=300-(time.monotonic()-start)
            if remaining<=0: raise RuntimeError("cumulative 300s exhausted")
            r=run(out,label,[str(v) for v in argv],min(limit,remaining),cwd)
            r["log"]=str(out/(label+".log"))
            r["log_file"]=r["log"]
            text=Path(r["log"]).read_text(errors="replace") if Path(r["log"]).exists() else ""
            r["expected_exit"]=expected_exit
            r["ok"]=r["exit"]==expected_exit and r["stop_reason"] is None and not any(s.lower() in text.lower() for s in ["SCRIPT ERROR","Parse Error","Compile Error","SHADER ERROR","Shader compilation failed"])
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
        gate("prepare",[sys.executable,"-X","utf8","-B",ROOT/"tools/asset_lab/prepare_radial_kernels.py","--inputs",a.inputs,"--input-sha256",a.input_sha256,"--output",out/"prepared"],45,ROOT)
        project=out/"prepared/project";web=out/"web";web.mkdir()
        report["project"]=str(project);report["web_output"]=str(web/"index.html")
        version=gate("version",[engine,"--headless","--log-file",out/"version-engine.log","--version"],90,project)
        if "4.7.2.stable.official.ed1daf0bf" not in version: raise ValueError("engine build mismatch")
        gate("python-tests",[sys.executable,"-X","utf8","-B","-m","unittest","discover","-s","tests","-p","test_radial_kernels.py","-v"],45,ROOT)
        gate("import",[engine,"--headless","--log-file",out/"import-engine.log","--path",project,"--editor","--import","--quit"],90,project)
        text=gate("godot-numeric",[engine,"--headless","--log-file",out/"numeric-engine.log","--path",project],90,project)
        if '"numeric_pass":true' not in text: raise RuntimeError("missing actual numeric success marker")
        report["numeric_pass"]=True
        chain_path=project/"chain_cases.json"
        original_chain=chain_path.read_bytes()
        try:
            for label,invalid in [("malformed-chain",{}),("oversized-chain",{"schema":1,"textures":{},"cases":[{}]*3})]:
                atomic(chain_path,invalid)
                rejected=gate(label,[engine,"--headless","--log-file",out/(label+"-engine.log"),"--path",project],90,project,expected_exit=1)
                if not all(marker in rejected for marker in ['"finished":true','"ok":false','invalid or oversized conditional chain']):
                    raise RuntimeError("missing terminal rejection protocol: "+label)
        finally:
            atomic(chain_path,original_chain)
        gate("web-export",[engine,"--headless","--log-file",out/"export-engine.log","--path",project,"--export-release","Web",web/"index.html"],90,project)
        for suffix in ["html","js","wasm","pck"]:
            if not (web/("index."+suffix)).is_file(): raise RuntimeError("missing exported "+suffix)
        report["web_export_ready"]=True
        report["chain_diagnostic_ready"]=True
        report["status"]="KERNEL_NUMERIC_PASS_WEB_READY"
    except Exception as e:
        report["blocker"]=str(e)
    finally:
        try:
            m=validate(a.inputs,a.input_sha256);report["protected105_exact"]=True;report["readonly_files_exact"]=len(m["readonly_files"])
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
