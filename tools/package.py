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
    manifests={}
    for name in ['manifest.json','players.json']:
        path=ROOT/'top/assets/official'/name
        if path.exists():manifests[name]=json.loads(path.read_text())
    local_models=bool(manifests)
    info=json.dumps({'version':version,'source_commit':revision,'working_tree_dirty':dirty,'godot':'4.4.1',
                     'fidelity':'See docs/research/FIDELITY.md; not all-region/all-server certification',
                     'local_game_models':local_models,'game_assets_in_source_archive':False},indent=2)+'\n'
    archives=[]
    for platform in (args.platforms or list(PLATFORMS)):
        preset,filename=PLATFORMS[platform];target=ROOT/'build'/platform;target.mkdir(parents=True,exist_ok=True)
        if not args.skip_export:
            subprocess.run([args.godot,'--headless','--path',str(ROOT/'top'),'--export-release',preset,str(target/filename)],check=True,timeout=300)
        if not (target/filename).exists():raise SystemExit('Missing export: '+filename)
        (target/'BUILD_INFO.json').write_text(info)
        for name in ['LICENSE','README.md']:shutil.copy2(ROOT/name,target/name)
        shutil.copytree(ROOT/'docs',target/'docs',dirs_exist_ok=True)
        (target/'FONT-OFL.txt').write_bytes((ROOT/'top/fonts/OFL.txt').read_bytes())
        asset_info=target/'LOCAL_GAME_ASSETS.json'
        asset_info.write_text(json.dumps(manifests,indent=2)+'\n')
        suffix=platform+('-x86_64' if platform!='web' else '')+('-local-game-models' if local_models else '')
        archive=dist/f'TOP-Practice-Lab-v{version}-{suffix}.zip'
        shutil.make_archive(str(archive.with_suffix('')),'zip',target);archives.append(archive)
    source=dist/f'TOP-Practice-Lab-v{version}-source.zip'
    with zipfile.ZipFile(source,'w',zipfile.ZIP_DEFLATED) as archive:
        archive.writestr('BUILD_INFO.json',info)
        for base in ['top','tools','docs']:
            for path in (ROOT/base).rglob('*'):
                relative=path.relative_to(ROOT)
                if not path.is_file() or any(p in ['.godot','__pycache__'] for p in relative.parts):continue
                if relative.parts[:3]==('top','assets','official'):continue
                archive.write(path,relative)
        for name in ['README.md','README.upstream.md','LICENSE']:archive.write(ROOT/name,name)
    archives.append(source)
    checksums=[hashlib.sha256(path.read_bytes()).hexdigest()+'  '+path.name for path in archives]
    (dist/f'SHA256SUMS-v{version}.txt').write_text('\n'.join(checksums)+'\n')
    print('\n'.join(checksums))
if __name__=='__main__':main()
