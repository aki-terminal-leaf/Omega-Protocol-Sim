#!/usr/bin/env python3
"""Collect public TOP fight evidence through a legitimate existing browser session.

Uses the site's normal replaysegment and casts-events requests. Does not read
cookies or credentials, solve challenges, access archives, or publish raw logs.
Requires playwright and an already running CDP browser; output is local evidence.
"""
from __future__ import annotations
import argparse
from collections import Counter
import gzip
import hashlib
import json
from pathlib import Path
import re
from datetime import datetime, timezone


def write_json(path: Path, data):
    raw=json.dumps(data,ensure_ascii=False,separators=(',',':')).encode()
    with gzip.open(path,'wb') as f: f.write(raw)
    return {'file':path.name,'sha256':hashlib.sha256(raw).hexdigest(),'uncompressed_bytes':len(raw)}


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--cdp',required=True)
    ap.add_argument('--report',required=True)
    ap.add_argument('--fight',required=True,type=int)
    ap.add_argument('--output',required=True,type=Path)
    args=ap.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9]{16}',args.report):ap.error('Invalid report code')
    from playwright.sync_api import sync_playwright
    out=args.output/args.report/str(args.fight);out.mkdir(parents=True,exist_ok=True)
    manifest={'report':args.report,'fight':args.fight,'retrieved_utc':datetime.now(timezone.utc).isoformat(),
              'source_url':f'https://www.fflogs.com/reports/{args.report}?fight={args.fight}',
              'method':'normal public browser UI requests; replay segments inclusive, casts nextPageTimestamp',
              'files':[],'complete':False}
    with sync_playwright() as p:
        browser=p.chromium.connect_over_cdp(args.cdp,timeout=15000)
        context=browser.contexts[0]
        name=f'top-evidence-{args.report}-{args.fight}'
        page=None
        for candidate in context.pages:
            if args.report not in candidate.url:continue
            try:
                if candidate.evaluate('window.name')==name:page=candidate;break
            except Exception:pass
        if page is None:page=context.new_page()
        page.goto(manifest['source_url']+'&type=casts&view=events&hostility=1',wait_until='domcontentloaded',timeout=45000)
        page.evaluate('(name)=>window.name=name',name)
        page.wait_for_function("typeof reportsCache!=='undefined' && reportsCache[0]?.tableURL?.includes('casts-events')",timeout=30000)
        text=page.locator('body').inner_text()
        if 'This log has been archived' in text or 'You must be logged in' in text:raise RuntimeError('Report is not publicly accessible in this session')
        meta=page.evaluate('''()=>({fights:reportsCache[0].fights,players:reportsCache[0].players,enemies:reportsCache[0].enemies,lang:reportsCache[0].lang,logVersion:reportsCache[0].logVersion,castsURL:reportsCache[0].tableURL})''')
        fight=next(f for f in meta['fights'] if f['id']==args.fight)
        if fight.get('boss') not in (1068,1077) or fight.get('zoneID')!=1122:raise RuntimeError('Selected fight is not TOP')
        meta['fights']=[fight]
        manifest['fight_metadata']=fight
        manifest['files'].append(write_json(out/'metadata.json.gz',meta))
        def fetch(url):
            result=page.evaluate('''async u=>{const r=await fetch(u,{signal:AbortSignal.timeout(45000)});if(!r.ok)throw Error('HTTP '+r.status+' '+u);return await r.json()}''',url)
            if not isinstance(result,dict) or 'events' not in result:raise RuntimeError('Missing events in '+url)
            return result
        events=[];pages=[];url=meta['castsURL'];start=fight['start_time'];end=fight['end_time']
        for index in range(100):
            data=fetch(url)
            events.extend(data['events'])
            nxt=data.get('nextPageTimestamp')
            pages.append({'url':url,'count':len(data['events']),'next':nxt})
            print(json.dumps({'kind':'casts','page':index+1,'events':len(data['events']),'next':nxt}),flush=True)
            if not nxt:break
            if nxt<=start or nxt>end:raise RuntimeError('Invalid cast pagination progress')
            start=nxt
            parts=url.split('/');parts[5]=str(start);url='/'.join(parts)
        else:raise RuntimeError('Casts page limit exceeded')
        manifest['files'].append(write_json(out/'enemy-casts.json.gz',{'events':events,'pages':pages}))
        replay_events=[];segments=[]
        for start in range(fight['start_time'],end+1,240000):
            stop=min(end,start+239999)
            url=f'/reports/replaysegment/{args.report}/{fight["boss"]}/{start}/{stop}'
            data=fetch(url)
            name=f'replay-{start}-{stop}.json.gz'
            item=write_json(out/name,data);item.update(start=start,end=stop,url=url,events=len(data['events']))
            manifest['files'].append(item);segments.append(item);replay_events.extend(data['events'])
            print(json.dumps({'kind':'replay','start':start,'end':stop,'events':len(data['events'])}),flush=True)
        manifest['replay_segments']=segments
        manifest['event_types']=dict(Counter(e.get('type','unknown') for e in replay_events))
        manifest['cast_events']=len(events);manifest['replay_events']=len(replay_events)
        manifest['complete']=bool(segments and segments[0]['start']==fight['start_time'] and segments[-1]['end']==end and all(b['start']==a['end']+1 for a,b in zip(segments,segments[1:])) and not pages[-1]['next'])
        (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        browser.close()
    print(json.dumps({'output':str(out),'complete':manifest['complete'],'casts':manifest['cast_events'],'replay_events':manifest['replay_events'],'event_types':manifest['event_types']}))

if __name__=='__main__':main()
