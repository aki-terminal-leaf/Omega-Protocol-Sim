"""Pinned, read-only cinematic extraction. Run only under the private Windows job guard."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
from types import SimpleNamespace

MANIFEST_SHA = '40ec9bd72ff51ebda0b9111500038838cca65f319c4b63b177378bfc2858d6f8'
BASE = '6e11e44c4009f095148e0c15520d25a8b8aeccd2'
MODELS = {110:1,424:2,8277:1,771:1}
CAP = 32*1024**2

def pin(path):
    data=path.read_bytes();return {'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data)}

def confined(root, name):
    p=(root/name).resolve()
    if not p.is_relative_to(root.resolve()):raise ValueError('path escapes trusted root')
    return p

def verify(root, repo):
    manifest=root/'inputs.json'
    manifest_bytes=manifest.read_bytes()
    if hashlib.sha256(manifest_bytes).hexdigest() != MANIFEST_SHA:raise ValueError('untrusted manifest')
    m=json.loads(manifest_bytes)
    if not m.get('seed_pins') or len(m.get('inputs',{}))!=29 or 'references/official_export_helpers.py' not in m['inputs'] or 'references/rig/sources.json' not in m['inputs']:raise ValueError('required manifest keys')
    if m['source_base'] != BASE:raise ValueError('source base')
    for group,base in [('seed_pins',repo),('inputs',root)]:
        for name,expected in m[group].items():
            if pin(confined(base,name)) != expected:raise ValueError('pin mismatch: '+name)
    native=json.loads((root/'references/rig/sources.json').read_text())['native_tools']
    if set(native)!={r'D:\Dev\OpenClawCodexBridge\tools\python32-top\python.exe',r'C:\Users\a9501\Downloads\Godbert\hkAnimationInterop.dll'}:raise ValueError('expected absolute native paths')
    for name,expected in native.items():
        if pin(Path(name))['sha256'] != expected['sha256']:raise ValueError('native pin mismatch')
    return m

def paths(model):
    base=MODELS[model]
    return {'mdl':f'chara/monster/m{model:04d}/obj/body/b{base:04d}/model/m{model:04d}b{base:04d}.mdl',
            'sklb':f'chara/monster/m{model:04d}/skeleton/base/b0001/skl_m{model:04d}b0001.sklb'}

def extract(root, output, config):
    if struct.calcsize('P')!=8:raise ValueError('64-bit extraction required')
    verify(root,Path(__file__).resolve().parents[2])
    required=('game_dir','lumina_dir','textools_dir','pythonnet_dir')
    if not config or any(k not in config for k in required):
        raise ValueError('OPEN: missing exact existing READ API configuration: '+','.join(required))
    helper=root/'references/official_export_helpers.py'
    spec=importlib.util.spec_from_file_location('pinned_official_helpers',helper)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    args=SimpleNamespace(**{k:Path(config[k]) if config[k] else None for k in required},output=output)
    realm=None;rows=[];total=0
    try:
        realm=module.initialize(args)
        from Lumina.Data import FileResource
        from xivModdingFramework.Models.FileTypes import Mdl
        for model in MODELS:
            row={'model':model,'base':MODELS[model],'candidate':'SOURCE_SUPPORTED_CANDIDATE','native_exact_mapping':'UNKNOWN','files':{}}
            for kind,source in paths(model).items():
                raw=realm.GetFile[FileResource](source)
                if raw is None:row['files'][kind]={'source':source,'status':'MISSING_AT_EXACT_PATH'};continue
                size=int(raw.Data.Length)
                if total+size>CAP:raise ValueError('OPEN resource cap before copying asset')
                total+=size;p=output/f'm{model:04d}.{kind}';p.write_bytes(bytes(raw.Data))
                row['files'][kind]={'source':source,**pin(p)}
                if kind=='mdl':
                    mdl=Mdl.GetTTModel(raw.Data,source).GetAwaiter().GetResult()
                    row['mdl_bones']=sorted({str(b) for g in mdl.MeshGroups for b in g.Bones})
            rows.append(row)
    finally:
        if realm is not None:realm.Dispose()
    return rows

def main():
    p=argparse.ArgumentParser();p.add_argument('--root',type=Path,required=True);p.add_argument('--config',type=Path);p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();confined(a.root,str(a.output.resolve()));a.output.mkdir(exist_ok=False)
    manifest=verify(a.root,Path(__file__).resolve().parents[2])
    config=None
    if a.config:
        relative=str(a.config.resolve().relative_to(a.root.resolve())).replace('\\','/')
        if relative not in manifest['inputs']:raise ValueError('untrusted extraction configuration')
        config=json.loads(confined(a.root,relative).read_text())
    try:result={'status':'EXTRACTED_CANDIDATES','pairs':extract(a.root,a.output,config)}
    except Exception as e:result={'status':'OPEN','reason':str(e)}
    (a.output/'result.json').write_text(json.dumps(result,separators=(',',':')))
    print(json.dumps(result))
if __name__=='__main__':main()
