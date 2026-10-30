import pathlib,subprocess,sys,json,hashlib,ctypes,time,uuid
from ctypes import wintypes
class Mem(ctypes.Structure):_fields_=[('len',wintypes.DWORD),('load',wintypes.DWORD),('total',ctypes.c_ulonglong),('available',ctypes.c_ulonglong),('page',ctypes.c_ulonglong),('apage',ctypes.c_ulonglong),('virtual',ctypes.c_ulonglong),('avirtual',ctypes.c_ulonglong),('extended',ctypes.c_ulonglong)]
class ProcMem(ctypes.Structure):_fields_=[('cb',wintypes.DWORD),('faults',wintypes.DWORD),('peak',ctypes.c_size_t),('rss',ctypes.c_size_t),('pquota',ctypes.c_size_t),('quota',ctypes.c_size_t),('npeak',ctypes.c_size_t),('nquota',ctypes.c_size_t),('page',ctypes.c_size_t),('ppeak',ctypes.c_size_t)]
getmem=ctypes.windll.psapi.GetProcessMemoryInfo;getmem.argtypes=[wintypes.HANDLE,ctypes.POINTER(ProcMem),wintypes.DWORD];getmem.restype=wintypes.BOOL
class BasicLimits(ctypes.Structure):_fields_=[('process_time',ctypes.c_longlong),('job_time',ctypes.c_longlong),('flags',wintypes.DWORD),('min_ws',ctypes.c_size_t),('max_ws',ctypes.c_size_t),('active_limit',wintypes.DWORD),('affinity',ctypes.c_size_t),('priority',wintypes.DWORD),('scheduling',wintypes.DWORD)]
class IoCounters(ctypes.Structure):_fields_=[(name,ctypes.c_ulonglong) for name in ['read_ops','write_ops','other_ops','read_bytes','write_bytes','other_bytes']]
class JobLimits(ctypes.Structure):_fields_=[('basic',BasicLimits),('io',IoCounters),('process_memory',ctypes.c_size_t),('job_memory',ctypes.c_size_t),('peak_process',ctypes.c_size_t),('peak_job',ctypes.c_size_t)]
k=ctypes.WinDLL('kernel32',use_last_error=True)
k.CreateJobObjectW.argtypes=[ctypes.c_void_p,wintypes.LPCWSTR];k.CreateJobObjectW.restype=wintypes.HANDLE
k.SetInformationJobObject.argtypes=[wintypes.HANDLE,ctypes.c_int,ctypes.c_void_p,wintypes.DWORD];k.SetInformationJobObject.restype=wintypes.BOOL
k.AssignProcessToJobObject.argtypes=[wintypes.HANDLE,wintypes.HANDLE];k.AssignProcessToJobObject.restype=wintypes.BOOL
k.QueryInformationJobObject.argtypes=[wintypes.HANDLE,ctypes.c_int,ctypes.c_void_p,wintypes.DWORD,ctypes.c_void_p];k.QueryInformationJobObject.restype=wintypes.BOOL
k.CloseHandle.argtypes=[wintypes.HANDLE];k.CloseHandle.restype=wintypes.BOOL


# Adapted from the pinned Job references. Job isolation is NOT a transitive DLL trust proof.
import argparse, os, shutil
from prepare_cinematic_godot import validate_manifest, EXPECTED, ROOT, sha

def run(out,label,argv,seconds,cwd):
 assert 0<seconds<=90
 receipt={'argv':argv,'deadline_seconds':seconds,'peak_rss_bytes':0,'job_peak_private_bytes':0,'stop_reason':None,'exit':None,'job_memory_limit':1536*1024**2,'kill_owned_descendants':True}
 mem=Mem();mem.len=ctypes.sizeof(mem);job=None;child=None;start=time.monotonic()
 try:
  if not k.GlobalMemoryStatusEx(ctypes.byref(mem)): raise ctypes.WinError()
  receipt['minimum_free_bytes']=mem.available
  if mem.available<8*1024**3: raise RuntimeError('LOW_FREE_RAM_PREFLIGHT')
  job=k.CreateJobObjectW(None,None)
  if not job: raise ctypes.WinError()
  limits=JobLimits();limits.basic.flags=0x2000|0x200;limits.job_memory=1536*1024**2
  if not k.SetInformationJobObject(job,9,ctypes.byref(limits),ctypes.sizeof(limits)): raise ctypes.WinError()
  with (out/(label+'.log')).open('xb') as log:
   child=subprocess.Popen(argv,cwd=cwd,stdout=log,stderr=subprocess.STDOUT,creationflags=0x4|0x08000000,env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1',PYTHONNOUSERSITE='1'))
   if not k.AssignProcessToJobObject(job,wintypes.HANDLE(int(child._handle))): raise ctypes.WinError()
   resume=ctypes.WinDLL('ntdll').NtResumeProcess;resume.argtypes=[wintypes.HANDLE];resume.restype=ctypes.c_long
   if resume(wintypes.HANDLE(int(child._handle)))!=0: raise RuntimeError('NtResumeProcess failed')
   while child.poll() is None:
    if not k.GlobalMemoryStatusEx(ctypes.byref(mem)): raise ctypes.WinError()
    receipt['minimum_free_bytes']=min(receipt['minimum_free_bytes'],mem.available)
    pm=ProcMem();pm.cb=ctypes.sizeof(pm)
    if getmem(wintypes.HANDLE(int(child._handle)),ctypes.byref(pm),pm.cb): receipt['peak_rss_bytes']=max(receipt['peak_rss_bytes'],pm.peak)
    if mem.available<8*1024**3: raise RuntimeError('LOW_FREE_RAM')
    if time.monotonic()-start>seconds: raise RuntimeError('TIMEOUT')
    time.sleep(.05)
 except Exception as e: receipt['stop_reason']=str(e)
 finally:
  if job:
   usage=JobLimits()
   if k.QueryInformationJobObject(job,9,ctypes.byref(usage),ctypes.sizeof(usage),None): receipt['job_peak_private_bytes']=usage.peak_job
   k.CloseHandle(job)
  if child:
   if child.poll() is None: child.kill()
   child.wait(timeout=3);receipt['exit']=child.returncode
  receipt['seconds']=time.monotonic()-start
  logpath=out/(label+'.log');text=logpath.read_text(errors='replace') if logpath.exists() else ''
  receipt['no_script_errors']=not any(x in text for x in ['SCRIPT ERROR','Parse Error','Compile Error'])
  receipt['ok']=receipt['exit']==0 and receipt['stop_reason'] is None and receipt['no_script_errors']
  (out/(label+'-receipt.json')).write_text(json.dumps(receipt,indent=2))
 return receipt

def main():
 p=argparse.ArgumentParser();p.add_argument('--manifest',type=pathlib.Path,required=True);p.add_argument('--manifest-sha256',required=True);a=p.parse_args()
 a.manifest=a.manifest.resolve();m=validate_manifest(a.manifest,a.manifest_sha256)
 out=a.manifest.parent/'outputs'/('run-'+str(time.time_ns()));out.mkdir(parents=True,exist_ok=False)
 source_files=['tools/asset_lab/prepare_cinematic_godot.py','tools/asset_lab/run_cinematic_integration.py','top/scripts/cinematic_sample_adapter.gd','tools/asset_lab/test_cinematic_integration.gd','tests/test_cinematic_godot.py','top/scripts/source_animation.gd']
 source_hashes={name:sha(ROOT/name) for name in source_files}
 summary={'implementation_sha256':source_hashes,'status':'OPEN','manifest_sha256':EXPECTED,'source_pins':m['seed_pins'],'input_pins':m['inputs'],'runtime_pins':m['runtime_pins'],'receipts':[],'models':[],'all96_accepted':False,'visual_acceptance':False,'trust_scope':m['trust_scope']}
 print(str(out),flush=True)
 try:
  for pair in m['pairs']:
   label='m%04d'%pair['model'];dest=out/label
   argv=[m['paths']['python'],'-B',str(ROOT/'tools/asset_lab/prepare_cinematic_godot.py'),'--manifest',str(a.manifest),'--manifest-sha256',EXPECTED,'--model',str(pair['model']),'--output',str(dest)]
   r=run(out,label,argv,60,out);summary['receipts'].append(r)
   if not r['ok']: raise RuntimeError('export failed: '+label)
   result=json.loads((dest/'result.json').read_text())
   if sha(dest/result['file'])!=result['sha256']: raise RuntimeError('fresh GLB hash mismatch')
   summary['models'].append(result)
  project=out/'project';project.mkdir();(project/'scripts').mkdir()
  (project/'project.godot').write_text('[debug]\nfile_logging/enable_file_logging=false\n[application]\nconfig/name="Private cinematic integration"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
  for source,dest in [('top/scripts/source_animation.gd','scripts/source_animation.gd'),('top/scripts/cinematic_sample_adapter.gd','scripts/cinematic_sample_adapter.gd'),('tools/asset_lab/test_cinematic_integration.gd','test.gd')]: shutil.copyfile(ROOT/source,project/dest)
  cases=[{'glb':str(out/('m%04d'%x['model'])/('m%04d.glb'%x['model'])),'sample':str(a.manifest.parent/x['integration_samples'])} for x in m['pairs']]
  (out/'cases.json').write_text(json.dumps(cases))
  argv=[m['paths']['godot'],'--headless','--log-file',str(out/'engine.log'),'--path',str(project),'--script',str(project/'test.gd'),'--',str(out/'cases.json'),str(out/'numeric.json')]
  r=run(out,'godot',argv,90,project);summary['receipts'].append(r)
  if (out/'numeric.json').exists(): summary['numeric']=json.loads((out/'numeric.json').read_text())
  if not r['ok']: raise RuntimeError('Godot integration failed')
  summary['status']='NUMERIC_INTEGRATION_PASS'
 except Exception as e: summary['blocker']=str(e);summary['status']='BLOCKED'
 finally:
  validate_manifest(a.manifest,EXPECTED)
  summary['protected_seeds_unchanged']=True
  summary['implementation_unchanged']={name:sha(ROOT/name) for name in source_files}==source_hashes
  summary['output_hashes']={str(p.relative_to(out)):sha(p) for p in out.rglob('*') if p.is_file() and '.godot' not in p.parts}
  (out/'summary.json').write_text(json.dumps(summary,indent=2));print(summary['status'],summary.get('blocker',''),flush=True)
 return 0 if summary['status']=='NUMERIC_INTEGRATION_PASS' else 1
if __name__=='__main__':sys.exit(main())


