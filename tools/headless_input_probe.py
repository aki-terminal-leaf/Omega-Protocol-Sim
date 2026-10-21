#!/usr/bin/env python3
"""Black-box 1440x900 P6 input probe; all state changes use real GUI input.

Run separately for --interaction none, click and drag. Screenshots and read-only
DOM diagnostics bracket each operation. Existing exports prove only that bundle.
"""
import argparse
import functools
import http.server
import json
from pathlib import Path
import sys
import threading
import time


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--bundle', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--channel', choices=['chrome', 'chromium'], default='chrome')
    ap.add_argument('--interaction', choices=['none', 'click', 'drag'], default='none')
    args = ap.parse_args()
    bundle = args.bundle.resolve()
    if not (bundle / 'index.html').is_file():
        ap.error('--bundle must contain index.html')
    out = args.output.resolve(); out.mkdir(parents=True, exist_ok=True)
    result = {'pass': False, 'bundle': str(bundle), 'interaction': args.interaction,
              'states': [], 'errors': [], 'downloads': {}}
    class Handler(http.server.SimpleHTTPRequestHandler):
        def log_message(self, *_): pass
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), functools.partial(Handler, directory=str(bundle)))
    thread = threading.Thread(target=server.serve_forever, daemon=True); thread.start()
    started = time.monotonic()
    try:
        from playwright.sync_api import sync_playwright
        with sync_playwright() as p:
            launch = {'headless': True, 'args': ['--use-angle=d3d11'] if sys.platform == 'win32' else ['--enable-unsafe-swiftshader', '--use-angle=swiftshader']}
            if args.channel == 'chrome': launch['channel'] = 'chrome'
            browser = p.chromium.launch(**launch)
            try:
                result['browser'] = browser.version
                context = browser.new_context(viewport={'width': 1440, 'height': 900}, accept_downloads=True)
                page = context.new_page(); page.set_default_timeout(8000)
                page.on('pageerror', lambda e: result['errors'].append(str(e)))
                page.on('console', lambda m: result['errors'].append(m.text) if m.type == 'error' or any(s in m.text for s in ['SCRIPT ERROR', 'Parse Error', 'Compile Error']) else None)
                def capture(label):
                    if time.monotonic() - started > 100:
                        raise TimeoutError('100s probe budget exhausted; closing owned browser/server')
                    state = page.evaluate('''() => ({pointerLock: document.pointerLockElement?.tagName || null,
                        focus: document.activeElement?.tagName, visibility: document.visibilityState,
                        canvas: [...document.querySelectorAll('canvas')].map(c => ({id:c.id, rect:c.getBoundingClientRect().toJSON()}))})''')
                    state.update(label=label, elapsed=time.monotonic()-started)
                    result['states'].append(state)
                    page.screenshot(path=str(out / (label + '.png')))
                    (out / 'diagnostics.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
                def step(label, operation, delay=150):
                    capture(label + '-before'); operation(); page.wait_for_timeout(delay); capture(label + '-after')
                def click(label, x, y): step(label, lambda: page.mouse.click(x, y))
                def download(label):
                    capture(label + '-before')
                    try:
                        with page.expect_download(timeout=3000) as event: page.mouse.click(1393, 809)
                        dest = out / (label + '.json'); event.value.save_as(str(dest))
                        data = json.loads(dest.read_text(encoding='utf-8'))
                        result['downloads'][label] = {'success': True, 'simulation_time': data.get('simulation_time'), 'camera': data.get('camera')}
                        return data
                    except Exception as e:
                        result['downloads'][label] = {'success': False, 'error': str(e)}
                        raise
                    finally: capture(label + '-after')
                def wait_report(label, predicate, attempts=16):
                    previous = None; stalled = 0
                    for attempt in range(attempts):
                        data = download(label + '-%02d' % attempt)
                        now = float(data.get('simulation_time', 0))
                        if predicate(data): return data
                        if data.get('failures'): raise AssertionError({'unexpected_failures': data['failures'], 'simulation_time': now})
                        stalled = stalled + 1 if previous is not None and now <= previous + .001 else 0
                        if stalled >= 3: raise AssertionError({'stalled_simulation': now, 'phase': label})
                        previous = now; page.wait_for_timeout(800)
                    raise AssertionError({'unmet_observed_condition': label, 'simulation_time': previous})
                page.goto('http://127.0.0.1:' + str(server.server_port), wait_until='networkidle')
                page.wait_for_timeout(6000)
                click('phase-open', 150, 113); click('phase-p6', 150, 290)
                click('meteors', 150, 270); click('method-open', 150, 495); click('elemental', 150, 558)
                click('role-open', 100, 657); click('role-d3', 100, 830)
                def scroll():
                    page.mouse.move(319,328); page.mouse.down(); page.mouse.move(319,878,steps=20); page.mouse.up()
                step('scroll', scroll)
                click('seed-focus', 150, 459)
                step('seed', lambda: (page.keyboard.press('Control+a'), page.keyboard.type('17391'), page.keyboard.press('Enter')))
                click('checkpoint-open', 150, 815); click('checkpoint-six', 100, 812)
                click('start-segment', 150, 862)
                step('pause', lambda: page.keyboard.press('p'))
                before = download('before')
                assert before['scenario'] == 'p6_meteors' and before['role'] == 'D3' and before['seed'] == 17391 and before['checkpoint_assisted'], 'Wrong GUI setup'
                assert 16.2 <= before['simulation_time'] < 19
                click('target-open', 120, 852); click('target-meteor', 100, 878)
                if args.interaction == 'click': click('world-click', 800, 400)
                elif args.interaction == 'drag':
                    step('drag-down', lambda: (page.mouse.move(800,400), page.mouse.down(button='right')))
                    step('drag-move', lambda: page.mouse.move(900,420,steps=10))
                    step('drag-up', lambda: page.mouse.up(button='right'))
                step('resume', lambda: page.keyboard.press('p'))
                ready = wait_report('gauge-ready', lambda d: d['runtime_state']['p6_lb']['gauge'] >= 30000)
                assert not any(x['kind'] == 'lb_begin' and x['actor'] == 6 for x in ready['runtime_state']['p6_lb']['history']), 'Human LB was auto-cast'
                result['gauge_ready_time'] = ready['simulation_time']
                step('lb', lambda: page.keyboard.press('f'))
                def meteors_dead(data):
                    targets = [x for x in data['runtime_state']['p6_lb']['targets'] if x.get('npc_id') == 15726]
                    return len(targets) == 2 and all(x['hp'] <= 0 for x in targets)
                wait_report('damage-resolved', meteors_dead, attempts=24)
                step('pause-after', lambda: page.keyboard.press('p'))
                try: after = download('after')
                except Exception:
                    # Diagnostic recovery only, never counted as a successful original flow.
                    step('workaround-exit-pointer-lock', lambda: page.evaluate('document.exitPointerLock()'))
                    try: download('workaround-after')
                    except Exception: pass
                    raise
                lb = after['runtime_state']['p6_lb']
                starts = [x for x in lb['history'] if x['kind'] == 'lb_begin' and x['actor'] == 6]
                finishes = [x for x in lb['history'] if x['kind'] == 'lb_finish' and x['actor'] == 6]
                assert len(starts) == len(finishes) == 1 and starts[0]['target'] == 'meteor_1', starts
                large = [x for x in lb['targets'] if x.get('npc_id') == 15726]
                assert len(large) == 2 and all(x['hp'] <= 0 for x in large), large
                assert not after['hints'] and not result['errors'], result['errors']
                result['pass'] = True
            finally: browser.close()
    except Exception as e:
        result['failure'] = repr(e)
    finally:
        server.shutdown(); server.server_close(); thread.join(timeout=5)
        (out / 'diagnostics.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k != 'states'}, ensure_ascii=True))
    return 0 if result['pass'] else 1


if __name__ == '__main__': sys.exit(main())
