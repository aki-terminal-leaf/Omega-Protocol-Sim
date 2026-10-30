"""Serial bounded Windows decoder/import gate, private outputs only."""
import argparse,json,sys,time,uuid,shutil
from pathlib import Path
from preserve_original_visual_inputs import ROOT,OUTPUT,EXPECTED,validate,write_json,sha,verify_identities

def main():
 p=argparse.ArgumentParser();p.add_argument('--manifest',type=Path,required=True);p.add_argument('--manifest-sha256',required=True);a=p.parse_args()
 out=OUTPUT/('run-'+str(uuid.uuid4()));out.mkdir(parents=True,exist_ok=False);print(out,flush=True)
 summary=dict(status='BLOCKED',models=[],receipts=[],all96_accepted=False,visual_acceptance=False,shader_status='OPEN');start=time.monotonic()
 try:
  m=validate(a.manifest,a.manifest_sha256);summary['seed_comparison']=m['seed_comparison']
  implementation={str(p):sha(p) for p in [ROOT/'tools/asset_lab/preserve_original_visual_inputs.py',Path(__file__).resolve(),ROOT/'tools/asset_lab/test_original_visual_inputs.gd',ROOT/'tools/asset_lab/audit_cinematic_mesh_fidelity.py',ROOT/'tools/asset_lab/run_cinematic_integration.py']}
  summary['implementation']=implementation
  from run_cinematic_integration import run
  for pair in m['pairs']:
   remaining=180-(time.monotonic()-start)
   if remaining<=0:raise RuntimeError('TOTAL_DEADLINE')
   label=f'm{pair["model"]:04d}';dest=out/label
   argv=[m['paths']['python'],'-B',str(ROOT/'tools/asset_lab/preserve_original_visual_inputs.py'),'--manifest',str(a.manifest),'--manifest-sha256',EXPECTED,'--model',str(pair['model']),'--output',str(dest)]
   r=run(out,label,argv,min(60,remaining),out);summary['receipts'].append(r)
   result=json.loads((dest/'result.json').read_text(encoding='utf-8')) if (dest/'result.json').exists() else {'status':'BLOCKED','blocker':'missing result'}
   summary['models'].append(result)
   if not r['ok'] or result.get('status')!='PRESERVED_SHADER_OPEN':raise RuntimeError('decoder blocked '+label+': '+result.get('blocker','guard failure'))
   validate(a.manifest,EXPECTED)
  verify_identities(summary['models'],json.loads((ROOT/'docs/asset-lab/cinematic-mesh-fidelity.json').read_text(encoding='utf-8'))['models'])
  identities=[(x['model'],x['base']) for x in summary['models']]
  if identities!=[(110,1),(424,2),(8277,1),(771,1)]:raise ValueError('model identity closure')
  mats=[v for x in summary['models'] for v in x['materials']]
  if len(mats)!=9 or len({v['path'] for v in mats})!=9 or sum(len(x['textures']) for x in mats)!=36:raise ValueError('material/binding closure')
  project=out/'project';project.mkdir();(project/'project.godot').write_text('[application]\nconfig/name="Original input gate"\n[debug]\nfile_logging/enable_file_logging=false\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8');shutil.copyfile(ROOT/'tools/asset_lab/test_original_visual_inputs.gd',project/'test.gd')
  if sha(project/'test.gd')!=sha(ROOT/'tools/asset_lab/test_original_visual_inputs.gd'):raise ValueError('staged Godot gate source changed')
  write_json(out/'cases.json',[dict(result=str(out/f'm{x["model"]:04d}'/'result.json')) for x in summary['models']])
  remaining=180-(time.monotonic()-start)
  if remaining<=0:raise RuntimeError('TOTAL_DEADLINE')
  r=run(out,'godot',[m['paths']['godot'],'--headless','--log-file',str(out/'engine.log'),'--path',str(project),'--script',str(project/'test.gd'),'--',str(out/'cases.json'),str(out/'engine-result.json')],min(90,remaining),project);summary['receipts'].append(r)
  if (out/'engine-result.json').exists():summary['engine']=json.loads((out/'engine-result.json').read_text(encoding='utf-8'))
  if not r['ok'] or summary.get('engine',{}).get('status')!='PASS':raise RuntimeError('actual Godot import gate blocked')
  for model,engine in zip(summary['models'],summary['engine']['models'],strict=True):
   if model['model']!=engine['model'] or [p['name'] for p in model['parts']]!=engine['parts']:raise ValueError('engine part identities')
   expected=[[mat['path'],t['path'],t['sampler_id']] for mat in model['materials'] for t in mat['textures']]
   if expected!=engine['bindings']:raise ValueError('engine binding identities')
  summary['status']='PRESERVATION_IMPORT_PASS_SHADER_OPEN'
 except Exception as e:summary['blocker']=str(e)
 finally:
  try:validate(a.manifest,a.manifest_sha256);summary['protected_raws_unchanged']=True
  except Exception as e:summary.update(status='BLOCKED',end_pin_error=str(e))
  if 'implementation' in locals():
   summary['implementation_unchanged']=all(sha(Path(p))==h for p,h in implementation.items())
   if not summary['implementation_unchanged']:summary.update(status='BLOCKED',blocker='implementation changed during run')
  summary['seconds']=time.monotonic()-start;summary['output_hashes']={str(f.relative_to(out)):sha(f) for f in out.rglob('*') if f.is_file() and '.godot' not in f.parts}
  write_json(out/'summary.json',summary);print(summary['status'],summary.get('blocker',''),flush=True)
 return int(summary['status']!='PRESERVATION_IMPORT_PASS_SHADER_OPEN')
if __name__=='__main__':sys.exit(main())
