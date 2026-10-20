#!/usr/bin/env python3
"""Black-box Chromium canvas checks, using inspected 1440x1000 desktop layout.
Run against a local exported Web build; requires Playwright + Chromium.
"""
import argparse
import json
from pathlib import Path
from playwright.sync_api import sync_playwright

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--url',default='http://127.0.0.1:8765')
parser.add_argument('--output',default='/tmp/top-web-test')
args=parser.parse_args()
out=Path(args.output);out.mkdir(parents=True,exist_ok=True)
with sync_playwright() as p:
    browser=p.chromium.launch(headless=True,args=['--enable-unsafe-swiftshader','--use-angle=swiftshader'])
    context=browser.new_context(viewport={'width':1440,'height':1000},accept_downloads=True)
    page=context.new_page();errors=[]
    page.on('pageerror',lambda e:errors.append(str(e)))
    page.on('console',lambda msg:errors.append(msg.text) if msg.type=='error' else None)
    page.goto(args.url,wait_until='networkidle')
    page.wait_for_timeout(5000)
    assert page.locator('canvas').is_visible()
    page.screenshot(path=str(out/'ready.png'))
    # Godot draws a 1440x900 game viewport centered in a 1440x1000 canvas.
    page.mouse.click(145,875)  # Start practice, inspected on ready screenshot.
    page.wait_for_timeout(500)
    page.keyboard.down('d');page.wait_for_timeout(650);page.keyboard.up('d')
    page.wait_for_timeout(200)
    def download(name):
        with page.expect_download(timeout=10000) as event:
            page.mouse.click(1275,806)  # Export practice report.
        dest=out/name;event.value.save_as(dest)
        return json.loads(dest.read_text())
    moving=download('movement.json')
    assert moving['mode']=='practice',moving
    assert len(moving['samples'])>=3,'Start click did not start sampling'
    x=[s['player_pos'][0] for s in moving['samples']]
    assert max(x)-min(x)>1.5,'Keyboard movement was not reflected in game state'
    page.keyboard.press('Space');page.wait_for_timeout(600)
    paused=download('paused.json')
    page.wait_for_timeout(600)
    paused_again=download('paused-again.json')
    assert len(paused['samples'])==len(paused_again['samples']),'Pause did not stop simulation'
    page.keyboard.press('r');page.wait_for_timeout(700)
    restarted=download('restarted.json')
    assert restarted['seed']==moving['seed'],'R did not preserve deterministic seed'
    assert restarted['samples'][0]['player_pos']==moving['samples'][0]['player_pos'],'R did not restore the original spawn'
    page.screenshot(path=str(out/'verified.png'))
    assert not errors,errors
    print(json.dumps({'browser':'Chromium / WebGL2','checks':['load','canvas','start','WASD','pause','same-seed restart','JSON download'],'errors':errors,'report':str(out/'movement.json')},ensure_ascii=False))
    context.close();browser.close()
