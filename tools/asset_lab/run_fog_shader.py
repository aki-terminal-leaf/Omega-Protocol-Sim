"""Serialized JobObject gates; no desktop, export, publish, or raster claims."""
import json,sys,time,uuid,shutil,msvcrt
from pathlib import Path
from prepare_fog_shader import ROOT,OUTPUT,RUNTIME,validate,save,sha,shader,INPUTS
from run_cinematic_integration import run
SOURCES=['top/materials/original_verticalfog.gdshader','top/scripts/original_verticalfog.gd','top/scripts/fog_shader_preview.gd','top/scenes/fog_shader_preview.tscn','tools/asset_lab/prepare_fog_shader.py','tools/asset_lab/run_fog_shader.py','tools/asset_lab/test_fog_shader.gd','tests/test_fog_shader.py','docs/asset-lab/FOG_SHADER.md']
def main():
 OUTPUT.mkdir(parents=True,exist_ok=True)
 lock=(OUTPUT/'runner.lock').open('a+b');lock.seek(0);lock.write(b'0');lock.flush();lock.seek(0);msvcrt.locking(lock.fileno(),msvcrt.LK_NBLCK,1)
 out=OUTPUT/('run-'+str(uuid.uuid4()));out.mkdir();print(out,flush=True)
 start=time.monotonic();report={'status':'BLOCKED','receipts':[],'raster_verified':False,'native_state_verified':False,'all96_accepted':False}
 try:
  pins=validate();report['protected_before']=pins['protected_sources'];report['input_pins']=pins['files'];paths=json.loads(RUNTIME.read_bytes())['paths'];report['implementation']={n:sha(ROOT/n) for n in SOURCES}
  if (ROOT/SOURCES[0]).read_text(encoding='utf-8-sig')!=shader():raise ValueError('shader differs from literal translation')
  def gate(label,argv,seconds,cwd):
   remaining=180-(time.monotonic()-start)
   if remaining<=0:raise RuntimeError('TOTAL_TIMEOUT')
   receipt=run(out,label,argv,min(seconds,remaining),cwd);report['receipts'].append(receipt)
   log=out/(label+'.log');text=log.read_text(errors='replace') if log.exists() else ''
   if any(x.lower() in text.lower() for x in ['SHADER ERROR','Shader compilation failed','reserved identifier','error(']):
    save(out/(label+'-shader-rejection.json'),{'rejected':True});raise RuntimeError('shader rejection '+label)
   if not receipt['ok']:raise RuntimeError(label+' failed')
  for name in ['inputs.json','shader-instruction-ir.json','verticalfog-vs-0.asm.txt','verticalfog-ps-0.asm.txt','conditional-branch-table.json']:
   shutil.copyfile(INPUTS/name,out/name)
  gate('decode',[paths['python'],'-B',str(ROOT/'tools/asset_lab/prepare_fog_shader.py'),'--output',str(out)],60,out)
  project=out/'project';project.mkdir()
  for folder in ['scripts','materials','scenes','data']:(project/folder).mkdir()
  for source in SOURCES[:4]:shutil.copyfile(ROOT/source,project/Path(source).relative_to('top'))
  shutil.copyfile(ROOT/'tools/asset_lab/test_fog_shader.gd',project/'test.gd')
  for file in out.iterdir():
   if file.name.endswith('.png.bin') or file.name=='scene.json':shutil.copyfile(file,project/'data'/file.name)
  for file in (project/'data').iterdir():
   if sha(file)!=sha(out/file.name):raise ValueError('portable payload hash join '+file.name)
  (project/'project.godot').write_text('[application]\nconfig/name="Private conditional fog inspection"\nrun/main_scene="res://scenes/fog_shader_preview.tscn"\n[debug]\nfile_logging/enable_file_logging=false\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
  (project/'export_presets.cfg').write_text('[preset.0]\nname="Web"\nplatform="Web"\nrunnable=true\nexport_filter="all_resources"\ninclude_filter="data/*.json,data/*.png.bin"\n[preset.0.options]\nvariant/extensions_support=false\nvariant/thread_support=false\n',encoding='utf-8')
  gate('python-tests',[paths['python'],'-B','-m','unittest','discover','-s','tests','-p','test_fog_shader.py'],30,ROOT)
  gate('godot',[paths['godot'],'--headless','--path',str(project),'--log-file',str(out/'engine.log'),'--script',str(project/'test.gd')],90,project)
  report['status']='HEADLESS_SOURCE_NUMERIC_PASS_RASTER_OPEN';report['project']=str(project)
 except Exception as e:report['blocker']=repr(e)
 finally:
  try:validate();report['protected55_exact']=True;report['implementation_unchanged']={n:sha(ROOT/n) for n in SOURCES}==report.get('implementation')
  except Exception as e:report['protected55_exact']=False;report['blocker']=repr(e);report['status']='BLOCKED'
  report['seconds']=time.monotonic()-start;report['output_hashes']={str(p.relative_to(out)):sha(p) for p in out.rglob('*') if p.is_file() and '.godot' not in p.parts};save(out/'summary.json',report)
  lock.seek(0);msvcrt.locking(lock.fileno(),msvcrt.LK_UNLCK,1);lock.close()
 print(report['status'],report.get('blocker',''));return int(report['status']=='BLOCKED')
if __name__=='__main__':sys.exit(main())
