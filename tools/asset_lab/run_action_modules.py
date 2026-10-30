"""Bounded Windows-only source checks; never exports, extracts or resamples."""
import argparse, hashlib, importlib, json, pathlib, re, shutil, sys, time, uuid
ROOT = pathlib.Path(__file__).resolve().parents[2]
EXPECTED = "92d785edb64684aae4c1a2341bcc51a4b349e4f314f31c920ec14cb962a868ca"
NEW = ["top/scripts/action_module.gd", "top/scripts/action_preview.gd", "top/scripts/action_timeline.gd", "top/scenes/action_preview.tscn", "tools/asset_lab/test_action_modules.gd", "tools/asset_lab/run_action_modules.py", "tests/test_action_modules.py"]
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p): return json.loads(p.read_text(encoding="utf8"))
def validate_result(r, m, selections):
    ids = {f"clip:{p['model']}:{c['index']}" for p in m['pairs'] for c in p['clips']}
    if r.get('failures') != []: raise ValueError('assertions failed: '+str(r.get('failures')))
    for key in ['clips','ui']:
        rows=r.get(key,[])
        if len(rows)!=len(ids) or {x['identity'] for x in rows}!=ids: raise ValueError('exact '+key+' cases missing')
    for row in r['clips']:
        if len(row.get('samples',[]))!=3: raise ValueError('sample omissions')
        for s in row['samples']:
            if s['time']<=0 or len(s['pose'])<=10 or s['pose']!=s['external_pose']: raise ValueError('pose evidence')
            for key in ['standalone','external']:
                q=s[key]
                if q['identity']!=row['identity'] or abs(q['seconds']-s['time'])>1e-5 or not q['source_sampling_supported']: raise ValueError('source evidence')
    fail = r.get('source_failure', {})
    if fail.get('visible', True) or any(fail.get(k, {}).get('ok', True) or fail[k].get('playing', True) or fail[k].get('selected', True) for k in ['seek', 'play']): raise ValueError('source failure not closed')
    validate_units(r.get('units',[]), selections)
    simultaneous=r.get('simultaneous',{})
    if not simultaneous.get('first_pose') or not simultaneous.get('second_pose') or simultaneous['first']['identity']==simultaneous['second']['identity']: raise ValueError('distinct simultaneous evidence')
    if len(r.get('unit_samples',[]))!=2: raise ValueError('unit samples missing')
    for x in r['unit_samples']:
        if x['facade']['source']!=x['direct'] or not x['pose']: raise ValueError('unit diagnostics')
def validate_units(rows, selections):
    if len(rows)!=96 or {x['identity'] for x in rows}!={'unit:'+x for x in selections['units']}: raise ValueError('exact unit registry')
    for x in rows:
        if x['selection']!=selections['units'][x['identity'][5:]]: raise ValueError('changed status')

def stage_resources(project, seeds):
    pending = list(seeds); copied = {}
    while pending:
        name = pending.pop()
        if name in copied: continue
        path = pathlib.PurePosixPath(name)
        if path.is_absolute() or ".." in path.parts or ":" in name: raise ValueError("rejected resource path " + name)
        source = ROOT / 'top' / path
        if not source.is_file(): raise ValueError("missing resource " + name)
        target = project / path; target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target); copied[name] = sha(source)
        if source.suffix in ['.gd', '.gdshader', '.tres', '.tscn']:
            pending += re.findall(r'[\"\']res://([^\"\']+)[\"\']', source.read_text(encoding='utf8'))
    return copied

def main():
    p=argparse.ArgumentParser(); p.add_argument('--manifest',type=pathlib.Path,required=True); p.add_argument('--manifest-sha256',required=True); p.add_argument('--source-root',type=pathlib.Path,required=True); a=p.parse_args()
    out=ROOT/'top/assets/official/top-action-modules-50853/outputs'/('run-'+uuid.uuid4().hex); out.mkdir(parents=True)
    summary={'status':'BLOCKED','visual_acceptance':False,'all96_accepted':False,'receipts':[]}; started=time.monotonic()
    before={}; m=None
    print(out,flush=True)
    try:
        if not a.manifest.is_absolute() or not a.source_root.is_absolute(): raise ValueError('absolute paths required')
        # Reuse the accepted playback validator, never its main or old integration validator.
        old=importlib.import_module('run_cinematic_playback')
        before={str(p.relative_to(ROOT)):sha(p) for folder in ['top/scripts','top/data','tools/asset_lab','tests','docs/asset-lab'] for p in (ROOT/folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts}
        summary['implementation_sha256']={n:sha(ROOT/n) for n in NEW}; summary['baseline_sha256']=before
        m=old.validate(a.manifest,a.manifest_sha256)
        selections=read(ROOT/'top/data/asset_lab/performances.json')
        source_pins={n:sha(a.source_root/n) for n in list(selections['source_hashes'])+['attachment-data.json']}
        for n,h in selections['source_hashes'].items():
            if source_pins[n]!=h: raise ValueError('unit source pin '+n)
        if source_pins['attachment-data.json']!=selections['attachment_sha256']: raise ValueError('attachment pin')
        summary['source_pins']=source_pins
        project=out/'project'; project.mkdir()
        (project/'project.godot').write_text('[application]\nconfig/name="Action module checks"\n[debug]\nfile_logging/enable_file_logging=false\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        summary['resource_sha256'] = stage_resources(project, ['scripts/action_module.gd','scripts/action_preview.gd','scripts/action_timeline.gd','scenes/action_preview.tscn'])
        shutil.copytree(ROOT/'top/data/asset_lab',project/'data/asset_lab', dirs_exist_ok=True)
        shutil.copyfile(ROOT/'tools/asset_lab/test_action_modules.gd',project/'test.gd')
        (out/'input.json').write_text(json.dumps({'manifest':str(a.manifest),'source_root':str(a.source_root)}))
        guard=importlib.import_module('run_cinematic_integration').run
        budget=min(90, int(120-(time.monotonic()-started)))
        if budget<=0: raise RuntimeError('runner budget exhausted')
        receipt=guard(out,'godot',[m['paths']['godot'],'--headless','--path',str(project),'--script',str(project/'test.gd'),'--',str(out/'input.json'),str(out/'numeric.json')],budget,project)
        summary['receipts'].append(receipt)
        if not receipt['ok']: raise RuntimeError('Godot failed; see preserved receipt/log')
        result=read(out/'numeric.json'); validate_result(result,m,selections)
        summary['status']='NUMERIC_PASS'
    except Exception as exc: summary['error']=repr(exc)
    finally:
        try:
            if m is not None: old.validate(a.manifest,a.manifest_sha256)
            if before and any(sha(ROOT/n)!=h for n,h in before.items()): raise ValueError('baseline changed')
            if any(sha(ROOT/'top'/n)!=h for n,h in summary.get('resource_sha256',{}).items()): raise ValueError('resource changed')
            if 'source_pins' in summary and any(sha(a.source_root/n)!=h for n,h in summary['source_pins'].items()): raise ValueError('source changed')
            summary['baseline_unchanged']=bool(before)
            summary['manifest_validated']=m is not None
            summary['pins_unchanged']=m is not None
        except Exception as exc: summary['status']='BLOCKED'; summary['pin_error']=repr(exc)
        summary['seconds']=time.monotonic()-started
        if summary['seconds']>120: summary['status']='BLOCKED'; summary['budget_error']='total budget exceeded'
        (out/'summary.json').write_text(json.dumps(summary,indent=2),encoding='utf8')
        print(summary['status'],summary.get('error',''),flush=True)
    return 0 if summary['status']=='NUMERIC_PASS' else 1
if __name__=='__main__': sys.exit(main())
