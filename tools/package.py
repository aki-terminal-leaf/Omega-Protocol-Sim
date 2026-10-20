#!/usr/bin/env python3
"""Export the standalone project and assemble portable release archives."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parent.parent

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--skip-export', action='store_true')
    args = parser.parse_args()
    dist = ROOT / 'dist'
    dist.mkdir(exist_ok=True)
    revision = subprocess.run(['git','rev-parse','HEAD'],cwd=ROOT,text=True,capture_output=True,check=True).stdout.strip()
    dirty = bool(subprocess.run(['git','status','--porcelain'],cwd=ROOT,text=True,capture_output=True,check=True).stdout.strip())
    info = json.dumps({'version':'0.1.0','source_commit':revision,'working_tree_dirty':dirty,'godot':'4.4.1','fidelity':'schematic practice prototype'},indent=2)+'\n'
    for platform, preset, filename in [('windows','Windows','TOP-Practice-Lab.exe'), ('linux','Linux','TOP-Practice-Lab.x86_64'), ('web','Web','index.html')]:
        target = ROOT / 'build' / platform
        target.mkdir(parents=True, exist_ok=True)
        if not args.skip_export:
            subprocess.run([args.godot,'--headless','--path',str(ROOT/'top'),'--export-release',preset,str(target/filename)], check=True, timeout=180)
        if not (target/filename).exists():
            raise SystemExit(f'Missing export: {target/filename}')
        (target/'BUILD_INFO.json').write_text(info)
        shutil.copy2(ROOT/'LICENSE',target/'LICENSE')
        shutil.copy2(ROOT/'README.md',target/'README.md')
        shutil.copytree(ROOT/'docs',target/'docs',dirs_exist_ok=True)
        (target/'FONT-OFL.txt').write_bytes((ROOT/'top/fonts/OFL.txt').read_bytes())
        shutil.make_archive(str(dist/f'TOP-Practice-Lab-v0.1.0-{platform}-x86_64' if platform!='web' else dist/'TOP-Practice-Lab-v0.1.0-web'),'zip',target)
    with zipfile.ZipFile(dist/'TOP-Practice-Lab-v0.1.0-source.zip','w',zipfile.ZIP_DEFLATED) as archive:
        archive.writestr('BUILD_INFO.json',info)
        for base in ['top','tools','docs']:
            for path in (ROOT/base).rglob('*'):
                if path.is_file() and not any(part in ['.godot','__pycache__'] for part in path.relative_to(ROOT).parts):
                    archive.write(path,path.relative_to(ROOT))
        for name in ['README.md','README.upstream.md','LICENSE']:
            archive.write(ROOT/name,name)
    checksums = []
    for path in sorted(dist.glob('*.zip')):
        checksums.append(hashlib.sha256(path.read_bytes()).hexdigest()+'  '+path.name)
    (dist/'SHA256SUMS.txt').write_text('\n'.join(checksums)+'\n')
    print('\n'.join(checksums))

if __name__ == '__main__':
    main()
