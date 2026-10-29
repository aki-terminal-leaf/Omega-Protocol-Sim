#!/usr/bin/env python3
"""Fresh standalone source-lifetime numerical gate; rejects zero-exit script errors."""
import argparse,json,subprocess,sys
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--godot',type=Path,required=True);p.add_argument('--data',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
repo=Path(__file__).resolve().parents[2]
if a.out.exists():raise SystemExit('Fresh evidence directory required')
a.out.mkdir(parents=True)
subprocess.run([sys.executable,str(repo/'tools/asset_lab/stage.py'),'--out',str(a.out/'project')],check=True)
subprocess.run([sys.executable,str(repo/'tools/asset_lab/lifetime_vectors.py'),str(a.out/'independent-vectors.json')],check=True)
cmd=[str(a.godot),'--headless','--path',str(a.out/'project'),'--quit-after','2','--script',str(repo/'tools/asset_lab/test_lifetime.gd'),'--',str(a.data),str(a.out/'result.json'),str(a.out/'independent-vectors.json')]
r=subprocess.run(cmd,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=100)
(a.out/'runtime.log').write_text(r.stdout)
print(r.stdout)
assert r.returncode==0 and not any(x in r.stdout for x in ['SCRIPT ERROR','Parse Error','Compile Error']), 'Godot runtime failed; preserve log'
assert (a.out/'result.json').exists(), 'No completed proof'
result=json.loads((a.out/'result.json').read_text());assert result['status']=='PASS',result['failures']
