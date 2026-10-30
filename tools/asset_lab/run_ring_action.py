"""Trusted bounded headless runner; no GUI, exports, services or publication."""
import sys
sys.dont_write_bytecode=True
import argparse, json, pathlib, shutil, time, uuid, re
from prepare_ring_action import ROOT, EXPECTED, NEW, validate, prepare, read, sha, require

def main():
    p=argparse.ArgumentParser(); p.add_argument('--manifest',type=pathlib.Path,required=True); p.add_argument('--manifest-sha256',required=True); a=p.parse_args()
    started=time.monotonic(); out=ROOT/'top/assets/official/top-one-action-50954/outputs'/str(uuid.uuid4()); out.mkdir(parents=True,exist_ok=False)
    print(out,flush=True)
    summary={'status':'FAILED','source_status':'BLOCKED','rendering_accepted':False,'all96_accepted':False,'receipts':[]}; m=None
    try:
        m=validate(a.manifest,a.manifest_sha256)
        summary['implementation_sha256']={n:sha(ROOT/n) for n in NEW}
        # Imports only after the frozen code has been verified.
        from run_cinematic_integration import run
        def stage_resources(project, seeds):
            pending=list(seeds); copied={}
            while pending:
                name=pending.pop()
                if name in copied or name.endswith('/') or (project/name).is_file(): continue
                relative=pathlib.PurePosixPath(name)
                require(not relative.is_absolute() and '..' not in relative.parts and ':' not in name,'unsafe resource')
                source=ROOT/'top'/relative
                require(source.is_file(),'missing resource '+name)
                if str(relative) not in ['scripts/original_ring_action.gd','scripts/ring_action_preview.gd','scenes/ring_action_preview.tscn']:
                    original=pathlib.Path(m['source_root'])/'top'/relative
                    require(original.is_file() and original.read_bytes().replace(b'\r\n',b'\n')==source.read_bytes().replace(b'\r\n',b'\n'),'dependency frozen-source equality '+name)
                target=project/relative; target.parent.mkdir(parents=True,exist_ok=True)
                shutil.copyfile(source,target); copied[name]=sha(source)
                if source.suffix in ['.gd','.gdshader','.tscn','.tres']:
                    pending += re.findall(r"[\"']res://([^\"']+)[\"']", source.read_text(encoding='utf8'))
            return copied
        project=out/'project'; project.mkdir()
        data=prepare(m,project)
        summary['resource_sha256']=stage_resources(project,['scripts/original_ring_action.gd','scripts/ring_action_preview.gd','scenes/ring_action_preview.tscn'])
        summary['project']=str(project); summary['graph']=data['graph']; summary['clock_status']=data['clock_status']
        shutil.copyfile(ROOT/'tools/asset_lab/test_ring_action.gd',project/'test.gd')
        (project/'project.godot').write_text('[application]\nconfig/name="Atomic 31567 source preview"\nrun/main_scene="res://scenes/ring_action_preview.tscn"\n[display]\nwindow/size/viewport_width=1000\nwindow/size/viewport_height=720\n[debug]\nfile_logging/enable_file_logging=false\n[rendering]\nrenderer/rendering_method="gl_compatibility"\ntextures/default_filters/use_nearest_mipmap_filter=false\n',encoding='utf8')
        # Existing Web route, with private data explicitly included. No export is run here.
        (project/'export_presets.cfg').write_text('[preset.0]\nname="PrivateWeb"\nplatform="Web"\nrunnable=true\nexport_filter="all_resources"\ninclude_filter="action-data.json,raw/*.json,raw/*.png,raw/*.source"\nexclude_filter="test.gd,bad-*.json"\nexport_path="../web/index.html"\n[preset.0.options]\nvariant/extensions_support=false\nvariant/thread_support=false\nhtml/export_icon=false\nhtml/canvas_resize_policy=2\nprogressive_web_app/enabled=false\n',encoding='utf8')
        def child(label,args):
            remaining=180-(time.monotonic()-started)
            require(remaining>3,'runner total deadline'); seconds=min(90,int(remaining-2))
            receipt=run(out,label,args,seconds,project); summary['receipts'].append(receipt)
            require(receipt['ok'],label+' child failed: '+str(receipt['stop_reason']))
        child('unit',[m['runtime']['python'],'-B',str(ROOT/'tests/test_ring_action.py')])
        child('godot',[m['runtime']['godot'],'--headless','--log-file',str(out/'engine.log'),'--path',str(project),'--script',str(project/'test.gd'),'--',str(out/'numeric.json')])
        result=read(out/'numeric.json'); require(result.get('failures')==[],'engine assertions')
        require(result['nonzero_frames']>10 and len(result['samples'])==int(data['inspector_end_frame']*2)+1 and result['reverse_samples']==len(result['samples']),'sample omissions')
        require(result['samples'][-1]['count']==0 and result['simultaneous']['first'] and result['simultaneous']['second'],'tail/isolation omissions')
        summary['nonzero_frames']=result['nonzero_frames']; summary['engine_source']=result['source_report']; summary['status']='SCOPED_IMPLEMENTATION_PASS'
    except Exception as e: summary['error']=repr(e)
    finally:
        try:
            if m is not None: validate(a.manifest,a.manifest_sha256)
            for n,h in summary.get('implementation_sha256',{}).items(): require(sha(ROOT/n)==h,'implementation changed during test')
            for n,h in summary.get('resource_sha256',{}).items(): require(sha(ROOT/'top'/n)==h,'dependency changed during test')
            summary['protected77_unchanged']=m is not None
        except Exception as e: summary['status']='FAILED'; summary['pin_error']=repr(e)
        summary['seconds']=time.monotonic()-started
        if summary['seconds']>180: summary['status']='FAILED'; summary['budget_error']=True
        (out/'summary.json').write_text(json.dumps(summary,indent=2),encoding='utf8'); print(summary['status'],summary.get('error',''),flush=True)
    return 0 if summary['status']=='SCOPED_IMPLEMENTATION_PASS' else 1
if __name__=='__main__': sys.exit(main())
