#!/usr/bin/env python3
"""Black-box tests of the exported Godot canvas at the inspected 1440x900 layout."""
import argparse,json,sys
from pathlib import Path
from playwright.sync_api import sync_playwright
ap=argparse.ArgumentParser();ap.add_argument('--url',default='http://127.0.0.1:8766');ap.add_argument('--output',default='/tmp/top-web-v2');ap.add_argument('--channel',choices=['chromium','chrome'],default='chromium');args=ap.parse_args()
out=Path(args.output);out.mkdir(parents=True,exist_ok=True)
with sync_playwright() as p:
 launch={'headless':True,'args':['--use-angle=d3d11'] if sys.platform=='win32' else ['--enable-unsafe-swiftshader','--use-angle=swiftshader']}
 if args.channel=='chrome':launch['channel']='chrome'
 browser=p.chromium.launch(**launch)
 context=browser.new_context(viewport={'width':1440,'height':900},accept_downloads=True)
 page=context.new_page();errors=[]
 page.on('pageerror',lambda e:errors.append(str(e)))
 page.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
 page.goto(args.url,wait_until='networkidle');page.wait_for_timeout(6000)
 assert page.locator('canvas').is_visible();page.screenshot(path=str(out/'01-selection.png'))
 page.mouse.click(110,153);page.wait_for_timeout(400)
 page.mouse.click(150,478);page.wait_for_timeout(500);page.screenshot(path=str(out/'02-methods.png'))
 page.mouse.click(150,558);page.wait_for_timeout(500)
 page.keyboard.press('r');page.wait_for_timeout(350)
 page.keyboard.down('d');page.wait_for_timeout(600);page.keyboard.up('d');page.keyboard.press('p');page.wait_for_timeout(300)
 def download(name):
  with page.expect_download(timeout=10000) as event:page.mouse.click(1393,849)
  dest=out/name;event.value.save_as(dest);return json.loads(dest.read_text(encoding='utf-8'))
 moving=download('movement.json')
 assert moving['scenario']=='p1_loop' and moving['mode']=='practice',{'scenario':moving['scenario'],'mode':moving['mode']}
 assert len(moving['samples'])>=3,'Mechanism/strategy/start did not establish runtime'
 xs=[s['player_pos'][0] for s in moving['samples']];assert max(xs)-min(xs)>1.5,'D did not move player'
 page.wait_for_timeout(400);paused=download('paused.json')
 assert len(paused['samples'])==len(moving['samples']),'P did not pause'
 # Relative camera input and zoom are checked against exported in-app reports.
 page.mouse.move(800,400);page.mouse.down(button='right');page.mouse.move(1000,370,steps=12);page.mouse.up(button='right')
 page.mouse.move(800,400);page.mouse.wheel(0,-300)
 orbit=download('orbit.json')
 assert abs(orbit['camera']['yaw'])>0.1,'Right-drag did not rotate camera'
 assert orbit['camera']['distance']<moving['camera']['distance'],'Wheel did not zoom'
 page.keyboard.press('p');page.keyboard.press('Space');page.wait_for_timeout(160);page.keyboard.press('p')
 jumped=download('jump.json');assert jumped['controls']['jump_height']>0,'Space did not jump'
 page.keyboard.press('r');page.wait_for_timeout(650);page.keyboard.press('p')
 restarted=download('restarted.json')
 assert restarted['seed']==moving['seed'],'R changed seed'
 assert restarted['samples'][0]['player_pos']==moving['samples'][0]['player_pos'],'R did not restore spawn'
 page.screenshot(path=str(out/'03-verified.png'))
 page.mouse.click(1376,31);page.wait_for_timeout(350)
 page.mouse.click(110,219);page.wait_for_timeout(300);page.keyboard.press('r');page.wait_for_timeout(350)
 with page.expect_download(timeout=10000) as event:page.mouse.click(1291,717.5)
 event.value.save_as(str(out/'needs-strategy.json'))
 unconfigured=json.loads((out/'needs-strategy.json').read_text(encoding='utf-8'))
 assert unconfigured['scenario']=='','Changing mechanism must require choosing a strategy again'
 assert not unconfigured['samples'],'Changing mechanism must clear old practice samples'
 assert not errors,errors
 result={'pass':True,'browser':browser.version,'channel':args.channel,'errors':errors}
 (out/'acceptance.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
 print(json.dumps({'browser':browser.version+' / exported WebGL2','checks':['mechanism then strategy','start','camera-relative WASD','P pause','right-drag orbit','wheel zoom','Space jump','same-seed restart','new mechanism requires a new strategy','JSON download'],'errors':errors},ensure_ascii=False))
 context.close();browser.close()
