"""Isolated, pinned headless playback acceptance; never exports or resamples."""
import argparse, hashlib, importlib, json, pathlib, shutil, sys, time, uuid, math
ROOT = pathlib.Path(__file__).resolve().parents[2]
EXPECTED = "92d785edb64684aae4c1a2341bcc51a4b349e4f314f31c920ec14cb962a868ca"
SOURCES = ["top/scripts/source_animation.gd", "top/scripts/cinematic_player.gd", "top/scripts/cinematic_inspector.gd", "top/scripts/cinematic_sample_adapter.gd", "top/scenes/cinematic_inspector.tscn", "tools/asset_lab/test_cinematic_playback.gd", "tools/asset_lab/run_cinematic_playback.py"]
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def validate(path, expected):
    if expected != EXPECTED or sha(path) != EXPECTED: raise ValueError("manifest hash")
    m = json.loads(path.read_text(encoding="utf-8"))
    if len(m["seed_pins"]) != 22: raise ValueError("22 seeds required")
    for group, base in [("seed_pins", ROOT), ("inputs", path.parent), ("runtime_pins", ROOT)]:
        for name, pin in m[group].items():
            f = base / name
            if f.stat().st_size != pin["bytes"] or sha(f) != pin["sha256"]: raise ValueError("pin mismatch: " + str(f))
    return m

def validate_ui(result, manifest):
    def require(ok, message):
        if not ok: raise ValueError("UI evidence: " + message)
    def number(value):
        return type(value) in (int, float) and math.isfinite(value)
    def near(value, expected):
        return number(value) and abs(value-expected) < 0.00001
    expected = {f"{int(p['model'])}:{int(c['index'])}" for p in manifest['pairs'] for c in p['clips']}
    first = {int(p['model']): int(p['clips'][0]['index']) for p in manifest['pairs']}
    ui = result['ui_controls']
    require(result.get('constructed') is True and ui['buttons'] == ['Play', 'Pause'], 'exact buttons/constructed')
    require(type(ui['forbidden_controls']) is int and ui['forbidden_controls'] == 0, 'forbidden controls')
    require(len(ui['selected_case_ids']) == 9 and set(ui['selected_case_ids']) == expected, 'nine selected IDs')
    def state(st):
        require(isinstance(st, dict), 'state object')
        for key in ['model', 'clip', 'selected_clip', 'model_instance', 'time', 'duration', 'speed']:
            require(number(st[key]), 'finite numeric ' + key)
        require(type(st['playing']) is bool and st['looping'] is False and st['speed'] == 1, 'normal defaults')
        require(st['duration'] > 0 and 0 <= st['time'] <= st['duration'] and st['model_instance'] > 0, 'bounds')
        require(all(st[k] == int(st[k]) for k in ['model', 'clip', 'selected_clip', 'model_instance']), 'integer identity')
        require(st['clip'] == st['selected_clip'] and f"{int(st['model'])}:{int(st['clip'])}" in expected, 'native selection')
    initial = ui['initial']; state(initial)
    require(initial['playing'] is False and initial['time'] == 0, 'initial paused zero')
    require(len(ui['cases']) == 9 and {r['case_id'] for r in ui['cases']} == expected, 'complete nine records')
    for rec in ui['cases']:
        model, clip = map(int, rec['case_id'].split(':'))
        states = rec['states']
        keys = ['model_before','model_selected','clip_before','selected','selection_idle','progress','paused','resumed','resumed_progress','endpoint','after_end','restart','restart_progress']
        require(set(states) == set(keys), 'complete state sequence')
        for st in states.values(): state(st)
        for key in ['model_before', 'clip_before']:
            require(states[key]['playing'] is True and states[key]['time'] > 0, 'selection while playing')
        ms = states['model_selected']
        require(ms['model'] == model and ms['clip'] == first[model] and not ms['playing'] and ms['time'] == 0, 'model reset')
        selected = states['selected']; duration = selected['duration']
        require(selected['model'] == model and selected['clip'] == clip, 'requested selection')
        for key in keys[3:]:
            st = states[key]
            require(all(st[k] == selected[k] for k in ['model','clip','selected_clip','model_instance','duration']), 'stable identity ' + key)
        for key, position, playing in [('selected',0,False),('selection_idle',0,False),('progress',.1,True),('paused',.1,False),('resumed',.1,True),('resumed_progress',.2,True),('endpoint',duration,False),('after_end',duration,False),('restart',0,True),('restart_progress',.1,True)]:
            require(near(states[key]['time'], position) and states[key]['playing'] is playing, 'position/play state ' + key)
        require(states['after_end'] == states['endpoint'], 'no autoplay after endpoint')


def main():
    p = argparse.ArgumentParser(); p.add_argument("--manifest", type=pathlib.Path, required=True); p.add_argument("--manifest-sha256", required=True); a = p.parse_args()
    path = a.manifest.resolve(); out = path.parent / "outputs" / ("playback-" + uuid.uuid4().hex); out.mkdir(parents=True)
    started = time.monotonic()
    summary = {"status":"BLOCKED", "receipts":[], "all96_accepted":False,"shader_accepted":False,"raster_accepted":False,"export_accepted":False}
    print(out, flush=True)
    try:
        m = validate(path,a.manifest_sha256)
        summary.update(manifest_sha256=EXPECTED, seed_pins=m["seed_pins"], input_pins=m["inputs"], runtime_pins=m["runtime_pins"], source_hashes={s:sha(ROOT/s) for s in SOURCES})
        # Import only after pin validation. Never invoke old main or validator.
        guard = importlib.import_module("run_cinematic_integration")
        project = out / "project"; (project/"scripts").mkdir(parents=True); (project/"scenes").mkdir()
        (project/"project.godot").write_text('[application]\nconfig/name="Private playback QA"\n[debug]\nfile_logging/enable_file_logging=false\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        for s in SOURCES:
            if s.startswith("top/"): shutil.copyfile(ROOT/s,project/s[4:])
        shutil.copyfile(ROOT/"tools/asset_lab/test_cinematic_playback.gd",project/"test.gd")
        for mode in ["numeric","ui"]:
            seconds = min(90, int(115-(time.monotonic()-started)))
            if seconds <= 0: raise RuntimeError("total deadline")
            argv = [m["paths"]["godot"],"--headless","--log-file",str(out/(mode+"-engine.log")),"--path",str(project),"--script",str(project/"test.gd"),"--",str(path),str(out/(mode+".json")),mode,"--manifest="+str(path)]
            receipt = guard.run(out,mode,argv,seconds,project); summary["receipts"].append(receipt)
            result_path=out/(mode+".json")
            result=json.loads(result_path.read_text(encoding="utf-8")) if result_path.exists() else {"status":"BLOCKED","blocker":"child produced no structured result"}
            if not result_path.exists(): result_path.write_text(json.dumps(result))
            summary[mode]=result
            if not receipt["ok"] or result.get("status")!="PASS": raise RuntimeError(mode+" failed")
            if mode=="numeric":
                expected={f"{int(pair['model'])}:{int(c['index'])}" for pair in m['pairs'] for c in pair['clips']}
                if set(result.get("case_ids",[]))!=expected or len(result.get("seeks",[]))!=9 : raise RuntimeError("missing exact cases/evidence")
                resident_expected={(int(pair['model']),mode) for pair in m['pairs'] for mode in ["playing","paused","stopped","disabled","reverse","zero_scale","newer"]}
                resident=result.get("resident",[])
                if len(resident)!=28 or {(int(x.get('model',-1)),x.get('mode')) for x in resident}!=resident_expected: raise RuntimeError("missing exact model/mode resident evidence")
            else:
                validate_ui(result, m)
        summary["status"]="PASS"
    except Exception as e: summary["blocker"]=str(e)
    finally:
        try:
            validate(path,a.manifest_sha256); summary["end_pins_unchanged"]=True
            if "source_hashes" in summary and summary["source_hashes"]!={s:sha(ROOT/s) for s in SOURCES}: raise ValueError("source changed during run")
        except Exception as e: summary.update(status="BLOCKED",end_pin_error=str(e))
        summary["seconds"]=time.monotonic()-started
        (out/"summary.json").write_text(json.dumps(summary,indent=2),encoding="utf-8")
        print(summary["status"],summary.get("blocker",""),flush=True)
    return 0 if summary["status"]=="PASS" else 1
if __name__=="__main__": sys.exit(main())
