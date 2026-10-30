"""Bounded source-contract gate; immutable receipts in a unique ignored run."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
EXPECTED = '234f612c27cd4b68a34a7e47618af72863d5c87a06914267c7065b298b69dd96'
OWN = ['tools/asset_lab/decode_source_scene_events.py','top/scripts/source_scene_events.gd',
       'tools/asset_lab/run_source_scene_events.py','tools/asset_lab/test_source_scene_events.gd',
       'tests/test_source_scene_events.py','docs/asset-lab/SOURCE_SCENE_EVENTS.md']

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def save(p, value):
    with p.open('x',encoding='utf-8') as f: json.dump(value,f,indent=2,allow_nan=False)

def verify(path):
    if sha(path) != EXPECTED: raise ValueError('manifest hash')
    m=json.loads(path.read_bytes())
    for group,root in [('files',path.parent),('protected_sources',ROOT)]:
        for name,pin in m[group].items():
            p=root/name
            if p.stat().st_size != pin['bytes'] or sha(p) != pin['sha256']: raise ValueError('pin: '+name)
    if len(m['files'])!=9 or len(m['protected_sources'])!=64: raise ValueError('pin count')
    return m

def main():
    p=argparse.ArgumentParser(); p.add_argument('--manifest',type=Path,required=True); p.add_argument('--manifest-sha256',required=True); a=p.parse_args()
    if a.manifest_sha256 != EXPECTED: raise ValueError('expected manifest SHA')
    start=time.monotonic(); m=verify(a.manifest)
    out=ROOT/'top/assets/official/top-source-scene-events-50893/outputs'/('run-'+str(uuid.uuid4()))
    if subprocess.run(['git','check-ignore',str(out)],cwd=ROOT,capture_output=True,timeout=10).returncode: raise ValueError('output must be ignored')
    out.mkdir(parents=True,exist_ok=False); print(out,flush=True)
    summary={'status':'BLOCKED','before':m['protected_sources'],'implementation':{n:sha(ROOT/n) for n in OWN},'actual_counts':{},'receipts':[]}
    save(out/'before.json',summary)
    try:
        from run_cinematic_integration import run
        accepted=json.loads((ROOT/'docs/asset-lab/cinematic-godot-integration.json').read_bytes())
        pins=accepted['runtime_pins']
        godot=next(Path(n) for n in pins if 'Godot_v4.7.2-stable_win64.exe' in n)
        if sha(godot)!=pins[str(godot)]['sha256']: raise ValueError('engine pin')
        os.environ['SCENE_GRAPH']=str(a.manifest.parent/'decoded-graph.json')
        receipt=run(out,'python',[sys.executable,'-B',str(ROOT/'tests/test_source_scene_events.py')],min(30,120-(time.monotonic()-start)),ROOT)
        summary['receipts'].append(receipt)
        if not receipt['ok']: raise RuntimeError('Python gate failed')
        spec=importlib.util.spec_from_file_location('scene_tests',ROOT/'tests/test_source_scene_events.py'); tests=importlib.util.module_from_spec(spec); spec.loader.exec_module(tests)
        graph=json.loads((a.manifest.parent/'decoded-graph.json').read_bytes()); actual,synthetic=tests.cases(graph)
        inputs=[]
        for r in actual+synthetic:
            d=tests.decode(r); c={'record':r,'target':tests.target(r),'actual':r in actual}
            if r['source_event']['tag']=='C018': c['vector']=tests.vector_expected(d['euler'],[.3,-2,4])
            else: c['ratio']=d['ratio']
            inputs.append(c)
        save(out/'cases.json',inputs)
        project=out/'project'; project.mkdir()
        (project/'project.godot').write_text('[application]\nconfig/name="Source scene state numeric gate"\n[debug]\nfile_logging/enable_file_logging=false\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
        shutil.copyfile(ROOT/OWN[1],project/'source_scene_events.gd'); shutil.copyfile(ROOT/OWN[3],project/'test.gd')
        remaining=120-(time.monotonic()-start)
        if remaining<=0: raise RuntimeError('total budget')
        receipt=run(out,'godot',[str(godot),'--headless','--log-file',str(out/'engine.log'),'--path',str(project),'--script',str(project/'test.gd'),'--',str(out/'cases.json'),str(out/'numeric.json')],min(90,remaining),project)
        summary['receipts'].append(receipt)
        if not receipt['ok'] or not (out/'numeric.json').exists(): raise RuntimeError('Godot gate failed/missing result')
        numeric=json.loads((out/'numeric.json').read_bytes())
        if numeric['failures'] or numeric['count']!=len(inputs): raise RuntimeError('numeric assertions/count')
        summary.update(status='NUMERIC_STATE_PASS',actual_counts={'C018':41,'C196':24},synthetic_count=len(synthetic),reviewed_identities=[r['namespace'] for r in actual])
    except Exception as e:
        summary['blocker']=str(e)
    finally:
        try:
            summary['after']=verify(a.manifest)['protected_sources']
            if summary['implementation']!={n:sha(ROOT/n) for n in OWN}: raise ValueError('implementation changed during gate')
        except Exception as e: summary.update(status='BLOCKED',blocker=str(e))
        summary.update(seconds=time.monotonic()-start,scope='numeric source state only; no selected runtime, raster, native or all96 acceptance')
        summary['output_hashes']={str(p.relative_to(out)):sha(p) for p in out.rglob('*') if p.is_file() and '.godot' not in p.parts}
        save(out/'summary.json',summary)
    print(summary['status'],summary.get('blocker',''),flush=True)
    return 0 if summary['status']=='NUMERIC_STATE_PASS' else 1

if __name__=='__main__': sys.exit(main())
