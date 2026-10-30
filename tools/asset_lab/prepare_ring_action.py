"""Frozen-input transport for atomic 31567. No extraction or source rewrites."""
import sys
sys.dont_write_bytecode = True
import argparse, hashlib, json, math, pathlib, shutil
ROOT = pathlib.Path(__file__).resolve().parents[2]
EXPECTED = '8825b3041da9958d724bd686b95282b5e4a3a506e77170b11120b3fac04f3bb4'
SOURCE = '3719a1cfcb102a31469770f53aca9b8edd8ec84bb490c645dbc080a1c7487201'
PACK = 'full_fx_7d52f33034935c9aabf2'
KEY = '265044|17:1|-1:0|31567|end|7|vfx/monster/gimmick4/eff/z3oz_b0_g03c0t1.avfx'
NEW = ['top/scripts/original_ring_action.gd','top/scripts/ring_action_preview.gd','top/scenes/ring_action_preview.tscn','tools/asset_lab/prepare_ring_action.py','tools/asset_lab/run_ring_action.py','tools/asset_lab/test_ring_action.gd','tests/test_ring_action.py','docs/asset-lab/RING_ACTION.md','docs/asset-lab/ring-action.json']
NEW += ['tools/avfx_preview_pack.py','tools/tests/test_avfx_preview_pack.py','top/scripts/asset_lab_effect.gd','top/scripts/asset_lab_lifetime.gd','top/scripts/source_avfx_player.gd','top/scripts/avfx_animation.gd','top/scripts/asset_lab_radial_effect.gd']

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p): return json.loads(p.read_text(encoding='utf8'), parse_constant=lambda x: (_ for _ in ()).throw(ValueError('nonfinite JSON '+x)))
def require(ok, reason):
    if not ok: raise ValueError(reason)
def pin(p, expected):
    require(p.is_file() and p.stat().st_size == expected['bytes'] and sha(p) == expected['sha256'], 'pin mismatch: '+str(p))
def safe(root, name):
    p=(root/name).resolve(); require(p.is_relative_to(root.resolve()), 'path escape'); return p
def validate(path, digest):
    require(path.is_absolute() and digest == EXPECTED and sha(path)==EXPECTED, 'manifest SHA/path')
    m=read(path); require(m['atomic_action']==31567 and m['asset']==PACK and m['pack_file']=='assets/'+PACK+'.json', 'action identity')
    require(sha(pathlib.Path(m['previous_manifest']))==m['previous_manifest_sha256'],'previous handoff pin')
    for n,p in m['protected_sources'].items():
        pin(safe(ROOT,n),p); pin(safe(pathlib.Path(m['source_root']),n),p)
    require(len(m['initial_source_pins'])==102 and len(m['protected_sources'])==87,'source cardinality')
    for n,p in m['initial_source_pins'].items(): pin(safe(pathlib.Path(m['source_root']),n),p)
    for n,p in m['input_files'].items(): pin(safe(pathlib.Path(m['input_root']),n),p)
    for n,p in m['cache_files'].items(): pin(safe(pathlib.Path(m['cache_root']),n),p)
    for n,p in m['runtime_pins'].items(): pin(pathlib.Path(m['runtime'][n]),p)
    require(pathlib.Path(sys.executable).resolve()==pathlib.Path(m['runtime']['python']).resolve(),'pinned Python required')
    require('_console' not in m['runtime']['godot'].lower(),'main Godot executable required')
    return m
def enabled(v): return v.get('value') is True if isinstance(v,dict) else v == 1

def trace(pack):
    """Exact enumeration of this constant-interval graph, not a native lifetime claim."""
    g=pack['groups']; edges=[]; births=[]; reached=set(); disabled=[]
    def node(group,index):
        require(isinstance(index,int) and 0<=index<len(g[group]), 'invalid '+group+' reference')
        reached.add((group,index)); return g[group][index]
    def constant(n,key):
        c=n['curves'][key]; require(not c.get('unknown_fields') and len(c['keys'])==1 and c['keys'][0]['type']==1 and not n['curves'].get(key+'R'), 'nonconstant emission')
        value=c['keys'][0]['data'][2]; require(math.isfinite(value),'nonfinite emission'); return value
    def life(n):
        d=n['life']; require(d['enabled'] and not d['unknown_fields'] and d['ValR']==0 and math.isfinite(d['Val']) and d['Val']>=0, 'unbounded life')
        require(n['values']['LpEd']<=n['values']['LpSt'],'loop needs host semantics'); return d['Val']
    def emit(index,birth,stop,parents):
        require(index not in parents,'emitter cycle'); n=node('Emit',index); end=min(stop,birth+life(n)); interval=constant(n,'CrI'); count=constant(n,'CrC')
        require(interval>0 and count==1 and n['values']['ClCn']>=10,'unsupported count/cap trace')
        if n['values']['EfNo']>=0: node('Efct',n['values']['EfNo'])
        for j,item in enumerate(n['items']):
            v=item['values']; ptr=f'groups/Emit/{index}/items/{j}'
            if not enabled(v['bEnb']) or v['CrPr']==0 or v['CrCn']==0: disabled.append(ptr); continue
            require(v['CrPr']==100 and v['CrCn']==1 and v['GenD']==0 and not enabled(v['bOvr']),'unsupported emission trace')
            at=birth+max(0,v['CrTm']-1)
            while at<=end:
                edges.append({'pointer':ptr,'birth':at,'stop':stop,'target':v['TgtB'],'role':item['role']})
                require(len(edges)<1000,'trace budget')
                if item['role']=='child_emitter': emit(v['TgtB'],at,stop,parents+[index])
                else:
                    require(item['role']=='child_particle','unknown role'); p=node('Ptcl',v['TgtB']); death=at+life(p)-v['StFr']; births.append({'particle':v['TgtB'],'birth':at,'death':death,'pointer':ptr})
                at+=interval
    for s in g['Schd']:
        for i,item in enumerate(s['items']):
            v=item['values']; ptr=f"groups/Schd/{s['index']}/items/{i}"
            if not enabled(v['bEna']) or v['TlNo']<0: disabled.append({'pointer':ptr,'values':v}); continue
            require(item['role']=='scheduled_timeline','external trigger lifetime')
            t=node('TmLn',v['TlNo']); require(t['values']['LpEd']<=t['values']['LpSt'],'timeline loop')
            if t['values']['BnNo']>=0: node('Bind',t['values']['BnNo'])
            for it in t['items']:
                x=it['values']; require(x['ClNo'] is None and x['EfNo']==-1,'timeline control')
                if enabled(x['bEna']): emit(x['EmNo'],v['StTm']+x['StTm'],v['StTm']+x['EdTm'],[])
    flags=[]
    for flag in pack['unsupported']:
        path=flag['path']; state='active_unknown'; proof=path
        if '/Trgr' in path: state='unreachable'; proof='groups/Schd/0/items/1..12: TlNo=-1 (all twelve)'
        elif path.startswith('Ptcl['):
            index=int(path.split('[')[1].split(']')[0]); slot=path.split('/')[1]
            if ("Ptcl",index) not in reached: state='unreachable'
            elif not enabled(g['Ptcl'][index]['materials'][slot]['bEna']): state='disabled'; proof=f'groups/Ptcl/{index}/materials/{slot}/bEna=0'
        flags.append(dict(flag,classification=state,evidence=proof))
    return {'reachable':sorted([f'{a}/{b}' for a,b in reached]),'disabled':disabled,'emissions':edges,'particles':births,'supported_last_death':max(x['death'] for x in births),'envelope_scope':'finite source-graph particle/emitter subset only; excludes native post-effects, host triggers and release','flags':flags,'original_lifetime_finite':False,'blocker':'groups/Emit/1/values/EfNo=0 -> groups/Efct/0/values/EfVT=7: unsupported active effector; asset_lab_lifetime.upper_bound rejects it'}

def radial_pack(m, prior):
    # Recompile privately; prove the descriptor independently against raw TLV.
    sys.path.insert(0,str(ROOT/'tools'))
    import avfx_preview_pack as compiler
    raw=(pathlib.Path(m['input_root'])/'original.avfx').read_bytes()
    require(compiler.hashlib.sha256(raw).hexdigest()==prior['source_sha256']==SOURCE,'preserved source hash equality')
    if 'raw_avfx_base64' in prior:
        require(compiler.base64.b64decode(prior['raw_avfx_base64'],validate=True)==raw,'preserved embedded raw equality')
    fresh=compiler.compile_pack(raw)
    root=compiler.mesh.blocks(compiler.mesh.blocks(raw)[0][1])
    payload=[v for t,v in root if t=='Efct'][0]
    fields=compiler.mesh.blocks(payload)
    data=compiler.mesh.unique(fields,'Data')
    decoded,_=compiler.decode_effector_data(data,7)
    node=fresh['groups']['Efct'][0]
    require(node['values']['EfVT']==7 and node['data']==decoded,'independent effector join')
    # All other semantics, including original meshes, remain byte-value equivalent.
    import copy, struct
    result=copy.deepcopy(prior)
    require({k:v for k,v in node.items() if k!='data'}=={k:v for k,v in prior['groups']['Efct'][0].items() if k!='data'},'non-data effector drift')
    result['groups']['Efct'][0]['data']=decoded
    result['radial_transformation']={'operation':'splice only source-decoded Efct0.data','source_sha256':SOURCE,'payload_sha256':compiler.hashlib.sha256(data).hexdigest(),'prior_pack_sha256':m['cache_files'][m['pack_file']]['sha256'],'upstream_commit':'05f6eb0cce19a6a91ae275bce609299d573914b3','rendering_accepted':False}
    # Independent raw key extraction, without compiler curve evaluator, for engine oracle.
    rows=compiler.mesh.blocks(data); oracle={}
    for tag,value in rows:
        if tag in compiler.RADIAL_CURVES:
            keys=compiler.mesh.unique(compiler.mesh.blocks(value),'Keys')
            oracle[tag]=[{'time':t,'type':kind,'value':z} for t,kind,x,y,z in struct.iter_unpack('<hHfff',keys)]
        else: oracle[tag]=struct.unpack('<i' if tag=='FaBP' else '<f',value)[0]
    return result, fresh, oracle

def prepare(m, project):
    root=pathlib.Path(m['cache_root']); pack=read(root/m['pack_file']); require(pack['source_sha256']==SOURCE,'source AVFX pin')
    full=read(root/'full-data.json'); rows=[x for x in full['cues'] if x['key']==KEY]; require(len(rows)==1,'exact cue join'); cue=rows[0]
    event=read(root/'record.json')['events'][11638]
    require(cue['event_index']==11638 and event['a']==31567 and event['t']==265044 and cue['source_pos']==event['source_pos']==[0,0,-472],'record join')
    require(full['packs'][cue['path']]==PACK and cue['node']['tag']=='C012' and cue['node']['id']==7 and cue['node']['time']==0 and cue['node']['duration']==16,'C012 pack join')
    require(cue['node']['scale']==[1,1,1] and cue['node']['position']==[0,0,0] and cue['node']['rotation_radians']==[0,0,0],'root transform')
    require(len(pack['models'])==9 and set(pack['textures'])==set(m['textures']) and len(pack['textures'])==6,'dependency cardinality')
    for model in pack['models']:
        require(model['vertices'] and model['triangles'],'empty source mesh')
        for v in model['vertices']:
            require(len(v['position'])==4 and len(v['uv'])==4 and len(v['color'])==4,'vertex channels')
            require(all(math.isfinite(x) for x in v['position']+v['color']+sum(v['uv'],[])),'nonfinite vertex')
        require(all(len(t)==3 and all(isinstance(i,int) and 0<=i<len(model['vertices']) for i in t) for t in model['triangles']),'triangles')
    graph=trace(pack); pack,fresh,oracle=radial_pack(m,pack)
    raw=project/'raw'; raw.mkdir(parents=True)
    (project.parent/'full-recompile.json').write_text(json.dumps(fresh,separators=(',',':'),allow_nan=False))
    (project/'radial-oracle.json').write_text(json.dumps(oracle,allow_nan=False))
    assets={}; paths={}
    for name in [m['pack_file']]+[m['textures'][t]['file'] for t in pack['textures']]:
        target=raw/pathlib.Path(name).name
        if name==m['pack_file']: target.write_text(json.dumps(pack,separators=(',',':'),allow_nan=False),encoding='utf8')
        else: shutil.copyfile(root/name,target)
        uri='res://raw/'+target.name; assets[uri]={'bytes':target.stat().st_size,'sha256':sha(target)}
        if target.suffix == '.png': shutil.copyfile(target,target.with_name(target.name+'.source'))
    for t in pack['textures']:
        require(full['textures'][t]==m['textures'][t]['asset'],'texture join'); paths[t]='res://raw/'+pathlib.Path(m['textures'][t]['file']).name
    data={'schema':1,'action':31567,'unit':'P3-02','cue_key':KEY,'pack':'res://raw/'+pathlib.Path(m['pack_file']).name,'source_sha256':SOURCE,'assets':assets,'textures':paths,'seed':31567,'graph':graph,'inspector_end_frame':graph['supported_last_death'],'preview_rate':30,'clock_status':'CONDITIONAL: existing avfx_player.preview_rate=30; native numeric units to seconds not proven','placement':{'position':[0,0,0],'heading_radians':math.pi/2-(-472)/100,'evidence':'record.json/events/11638; asset_lab_composite.gd::_cue_root: Vector3(raw[0],0,raw[1]); third value is heading/100, not height'},'source_status':'BLOCKED','rendering_accepted':False,'all96_accepted':False}
    (project/'action-data.json').write_text(json.dumps(data,separators=(',',':')),encoding='utf8'); return data
if __name__=='__main__':
    a=argparse.ArgumentParser(); a.add_argument('--manifest',type=pathlib.Path,required=True); a.add_argument('--manifest-sha256',required=True); a.add_argument('--project',type=pathlib.Path,required=True); args=a.parse_args()
    require(args.project.resolve().is_relative_to(ROOT/'top/assets/official/top-ring-effector-50976/outputs'),'private output root required')
    args.project.mkdir(parents=True,exist_ok=False); prepare(validate(args.manifest,args.manifest_sha256),args.project)
