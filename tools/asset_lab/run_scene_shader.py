"""Serial bounded source decode and headless numerical gate. Never a raster claim."""
import json,sys,time,uuid,shutil
from pathlib import Path
from prepare_scene_shader import ROOT,OUTPUT,RUNTIME,validate,save,sha
from run_cinematic_integration import run

def main():
 out=OUTPUT/('run-'+str(uuid.uuid4()));out.mkdir(parents=True);print(out,flush=True)
 start=time.monotonic();report={'status':'BLOCKED','receipts':[],'raster_verified':False,'native_state_verified':False}
 try:
  validate();paths=json.loads(RUNTIME.read_bytes())['paths']
  sources=['top/scripts/original_lightshaft.gd','top/materials/original_lightshaft.gdshader','top/scripts/scene_shader_preview.gd','top/scenes/scene_shader_preview.tscn','tools/asset_lab/prepare_scene_shader.py','tools/asset_lab/run_scene_shader.py','tools/asset_lab/test_scene_shader.gd','tests/test_scene_shader.py']
  report['implementation']={n:sha(ROOT/n) for n in sources}
  def gate(label,argv,seconds,cwd):
   remaining=180-(time.monotonic()-start)
   if remaining<=0:raise RuntimeError('TOTAL_TIMEOUT')
   receipt=run(out,label,argv,min(seconds,remaining),cwd);report['receipts'].append(receipt)
   text=(out/(label+'.log')).read_text(errors='replace')
   if any(marker in text for marker in ['SHADER ERROR','Shader compilation failed']):
    receipt['ok']=False;receipt['shader_errors']=True
    save(out/(label+'-shader-rejection.json'),receipt)
   if not receipt['ok']:raise RuntimeError(label+' failed; inspect receipt/log')
  gate('decode',[paths['python'],'-B',str(ROOT/'tools/asset_lab/prepare_scene_shader.py'),'--output',str(out)],60,out)
  project=out/'project';project.mkdir()
  for folder in ['scripts','materials','scenes','data']:(project/folder).mkdir()
  for source in sources[:4]:shutil.copyfile(ROOT/source,project/Path(source).relative_to('top'))
  shutil.copyfile(ROOT/'tools/asset_lab/test_scene_shader.gd',project/'test.gd')
  for file in out.iterdir():
   if file.suffix in ['.png','.rgba'] or file.name=='scene.json':shutil.copyfile(file,project/'data'/file.name)
  (project/'project.godot').write_text('[application]\nconfig/name="Source shaft inspection"\nrun/main_scene="res://scenes/scene_shader_preview.tscn"\n[debug]\nfile_logging/enable_file_logging=false\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
  gate('python-tests',[paths['python'],'-B','-m','unittest','discover','-s','tests','-p','test_scene_shader.py'],30,ROOT)
  gate('godot',[paths['godot'],'--headless','--path',str(project),'--log-file',str(out/'engine.log'),'--script',str(project/'test.gd')],90,project)
  report['status']='HEADLESS_DATA_NUMERIC_PASS_RASTER_OPEN'
 except Exception as e:report['blocker']=repr(e)
 finally:
  try:validate();report['protected46_exact']=True
  except Exception as e:report['protected46_exact']=False;report['blocker']=repr(e);report['status']='BLOCKED'
  report['seconds']=time.monotonic()-start;save(out/'summary.json',report)
 print(report['status']);return int(report['status']=='BLOCKED')
if __name__=='__main__':sys.exit(main())
