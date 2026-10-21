#!/usr/bin/env python3
"""Export portable TOP builds; keep locally extracted game assets out of source ZIPs."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import zipfile

def engine_version(executable):
    result=subprocess.run([executable,'--version'],text=True,capture_output=True,check=True,timeout=15)
    raw=result.stdout.strip()
    match=re.match(r'(\d+\.\d+\.\d+)\.stable(?:\.|$)',raw)
    if not match:raise SystemExit('A stable Godot patch release is required: '+raw)
    return match.group(1),raw

def export_checked(executable,project,preset,output):
    result=subprocess.run([executable,'--headless','--path',str(project),'--export-release',preset,str(output)],text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=300)
    print(result.stdout,end='')
    if result.returncode or any(marker in result.stdout for marker in ['SCRIPT ERROR','Parse Error','Compile Error','Export failed']):
        raise SystemExit('Export gate failed for '+preset)
    if not output.is_file():raise SystemExit('Missing export: '+str(output))

ROOT=Path(__file__).resolve().parent.parent
PLATFORMS={'windows':('Windows','TOP-Practice-Lab.exe'),'linux':('Linux','TOP-Practice-Lab.x86_64'),'web':('Web','index.html')}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',default='godot')
    parser.add_argument('--skip-export',action='store_true')
    parser.add_argument('--version',help='Defaults to the project version')
    parser.add_argument('--platform',action='append',choices=list(PLATFORMS),dest='platforms')
    args=parser.parse_args()
    version=args.version or re.search(r'config/version="([^"]+)"',(ROOT/'top/project.godot').read_text()).group(1)
    if not re.fullmatch(r'[0-9A-Za-z.-]+',version):parser.error('Invalid version')
    dist=ROOT/'dist';dist.mkdir(exist_ok=True)
    revision=subprocess.run(['git','rev-parse','HEAD'],cwd=ROOT,text=True,capture_output=True,check=True).stdout.strip()
    dirty=bool(subprocess.run(['git','status','--porcelain'],cwd=ROOT,text=True,capture_output=True,check=True).stdout.strip())
    if dirty:raise SystemExit('Release packaging requires a clean working tree')
    engine,engine_raw=engine_version(args.godot)
    lock=ROOT/'top/data/engine_lock.json'
    if lock.exists() and json.loads(lock.read_text())['version']!=engine:
        raise SystemExit('Executable does not match the project engine lock')
    manifests={}
    for name in ['manifest.json','players.json','arena/manifest.json','p3/manifest.json']:
        path=ROOT/'top/assets/official'/name
        if path.exists():manifests[name]=json.loads(path.read_text())
    local_models=bool(manifests)
    info=json.dumps({'version':version,'source_commit':revision,'working_tree_dirty':dirty,'godot':engine,'godot_build':engine_raw,
                     'fidelity':'See docs/research/FIDELITY.md; not all-region/all-server certification',
                     'local_game_models':local_models,'game_assets_in_source_archive':False},indent=2)+'\n'
    archives=[]
    for platform in (args.platforms or list(PLATFORMS)):
        preset,filename=PLATFORMS[platform];target=ROOT/'build'/platform;target.mkdir(parents=True,exist_ok=True)
        if not args.skip_export:
            export_checked(args.godot,ROOT/'top',preset,target/filename)
        if not (target/filename).exists():raise SystemExit('Missing export: '+filename)
        if args.skip_export:
            old_path=target/'BUILD_INFO.json'
            if not old_path.exists():raise SystemExit('Cannot reuse export without BUILD_INFO.json')
            old=json.loads(old_path.read_text())
            expected=json.loads(info)
            if any(old.get(k)!=expected[k] for k in ['version','source_commit','working_tree_dirty','godot','local_game_models']):
                raise SystemExit('Refusing stale or mismatched --skip-export build: '+platform)
            for name,digest in old.get('export_sha256',{}).items():
                if not (target/name).is_file() or hashlib.sha256((target/name).read_bytes()).hexdigest()!=digest:
                    raise SystemExit('Reused export digest mismatch: '+name)
            if not old.get('export_sha256'):raise SystemExit('Reused export lacks binary digest evidence')
        platform_info=json.loads(info)
        outputs=[path for path in target.iterdir() if path.is_file() and (path.name==filename or (path.name.startswith(Path(filename).stem+'.') and path.suffix in ['.pck','.wasm','.js','.png']))]
        platform_info['export_sha256']={path.name:hashlib.sha256(path.read_bytes()).hexdigest() for path in outputs}
        (target/'BUILD_INFO.json').write_text(json.dumps(platform_info,indent=2)+'\n')
        for name in ['LICENSE','README.md']:shutil.copy2(ROOT/name,target/name)
        shutil.copytree(ROOT/'docs',target/'docs',dirs_exist_ok=True)
        (target/'FONT-OFL.txt').write_bytes((ROOT/'top/fonts/OFL.txt').read_bytes())
        (target/'CJK-FONT-OFL.txt').write_bytes((ROOT/'top/fonts/CJK-OFL.txt').read_bytes())
        asset_info=target/'LOCAL_GAME_ASSETS.json'
        asset_info.write_text(json.dumps(manifests,indent=2)+'\n')
        suffix=platform+('-x86_64' if platform!='web' else '')+('-local-game-models' if local_models else '')
        archive=dist/f'TOP-Practice-Lab-v{version}-{suffix}.zip'
        with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as bundle:
            roots=[path.name for path in outputs]+['BUILD_INFO.json','LICENSE','README.md','FONT-OFL.txt','CJK-FONT-OFL.txt','LOCAL_GAME_ASSETS.json']
            for name in roots:bundle.write(target/name,name)
            for path in (target/'docs').rglob('*'):
                if path.is_file():bundle.write(path,path.relative_to(target))
        archives.append(archive)
    source=dist/f'TOP-Practice-Lab-v{version}-source.zip'
    with zipfile.ZipFile(source,'w',zipfile.ZIP_DEFLATED) as archive:
        archive.writestr('BUILD_INFO.json',info)
        tracked=subprocess.run(['git','ls-files','-z','--','top','tools','docs'],cwd=ROOT,stdout=subprocess.PIPE,check=True).stdout.decode().split('\0')
        for name in filter(None,tracked):
            relative=Path(name)
            if relative.parts[:3]==('top','assets','official'):continue
            archive.write(ROOT/relative,relative)
        for name in ['README.md','README.upstream.md','LICENSE']:archive.write(ROOT/name,name)
    archives.append(source)
    checksums=[hashlib.sha256(path.read_bytes()).hexdigest()+'  '+path.name for path in archives]
    (dist/f'SHA256SUMS-v{version}.txt').write_text('\n'.join(checksums)+'\n')
    print('\n'.join(checksums))
if __name__=='__main__':main()
