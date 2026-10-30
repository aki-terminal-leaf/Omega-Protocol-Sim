"""Exact-input-only 32-bit native cinematic sampler; execute under private guard.py."""
import argparse
import json
import math
from pathlib import Path
import struct
from extract_cinematic_rigs import verify,pin,confined

MAGIC=b'\x57\xe0\xe0\x57\x10\xc0\xc0\x10'

def packfile(data):
    if len(data)<64 or data[:8]!=MAGIC:raise ValueError('Havok signature/bounds')
    # 32-bit little endian Havok packfile layout, not an arbitrary buffer.
    if data[16]!=4 or data[17]!=1:raise ValueError('Havok pointer size/endian')

def pap_header(data):
    if len(data)<26 or data[:4]!=b'pap ' or data[4:8]!=b'\x01\x00\x02\x00':raise ValueError('PAP signature/version/bounds')
    count,model,kind,variant,table,start,end=struct.unpack_from('<hHBBiii',data,8)
    if not 0<count<=1024 or table!=26 or not table+40*count<=start<end<=len(data):raise ValueError('PAP table/container bounds')
    clips=[]
    for i in range(count):
        record=data[table+i*40:table+(i+1)*40]
        if b'\0' not in record[:32]:raise ValueError('unterminated clip name')
        index=struct.unpack_from('<i',record,34)[0]
        if index<0:raise ValueError('negative clip index')
        clips.append({'index':index,'name':record[:32].split(b'\0')[0].decode('utf-8'),'duration':None,'bone_count':None})
    tagfile(data[start:end])
    container_status='OUTER_VALIDATED';container_reason='Exact pins required; native reader owns TAGFILE deserialization'
    return {'model':model,'type_byte':kind,'variant_byte':variant,'container_validation':container_status,'container_reason':container_reason,'container_offset':start,'container_end':end,'clips':clips,'skeleton_metadata':'UNKNOWN: bytes do not establish body/SKLB mapping'}

def sklb_payload(data):
    if len(data)<16 or data[:4]!=b'blks':raise ValueError('SKLB signature/bounds')
    version=data[4:8]
    if version not in (b'0031',b'0021'):raise ValueError('unsupported SKLB version')
    offset=struct.unpack_from('<H',data,12 if version==b'0031' else 10)[0]
    if offset<16 or offset>=len(data):raise ValueError('SKLB offset bounds')
    tagfile(data[offset:]);return data[offset:]

def validate_parents(parents):
    if not parents or len(parents)>4096:raise ValueError('bone count')
    for i,p in enumerate(parents):
        if not -1<=p<len(parents):raise ValueError('parent range')
        seen=set();j=i
        while j!=-1:
            if j in seen:raise ValueError('parent cycle')
            seen.add(j);j=parents[j]

def sample_times(duration,bones,used=0):
    if not math.isfinite(duration) or duration<=0:raise ValueError('nonpositive/nonfinite duration')
    if not 0<bones<=4096:raise ValueError('bone count')
    if duration > (64*1024**2-used)/(bones*512*30):raise ValueError('OPEN resource cap before allocation')
    # Logical 30 Hz grid, deduplicated in the actual float32 native ABI.
    endpoint=struct.unpack('<f',struct.pack('<f',duration))[0]
    if endpoint<=0:raise ValueError('duration underflows native float32')
    times=[];i=0;previous=-1.0
    while i/30<duration:
        t=i/30;native=struct.unpack('<f',struct.pack('<f',t))[0];i+=1
        if previous<native<endpoint:
            times.append(t);previous=native
    times.append(duration)
    if used+len(times)*bones*512>64*1024**2:raise ValueError('OPEN resource cap before allocation')
    return times

TAG=bytes.fromhex('1e0db0cacefa11d0')
def tagfile(data):
    if len(data)<16 or data[:8]!=TAG:raise ValueError('TAGFILE signature/bounds')
import ctypes as C
import hashlib
import sys
SUPPLEMENT_SHA='6b63fa26f7c874a1fc014ccd2523bfb7c291c1ae0cbdf592ec315e1c827c7d49'
PYTHON=r'D:\Dev\OpenClawCodexBridge\tools\python32-top\python.exe'
DLL=r'C:\Users\a9501\Downloads\Godbert\hkAnimationInterop.dll'

def checked(path, expected):
    data=path.read_bytes()
    if hashlib.sha256(data).hexdigest()!=expected['sha256'] or ('bytes' in expected and len(data)!=expected['bytes']):raise ValueError('pin mismatch: '+str(path))
    return data

def trusted(root):
    repo=Path(__file__).resolve().parents[2]
    old=verify(root,repo)
    m=json.loads(checked(root/'native-sampler-inputs.json',{'sha256':SUPPLEMENT_SHA}))
    if m.get('schema')!=1 or m.get('source_base')!=old['source_base'] or m.get('inherited_input_sha256')!='40ec9bd72ff51ebda0b9111500038838cca65f319c4b63b177378bfc2858d6f8':raise ValueError('supplement metadata')
    if len(m.get('protected_seed_pins',{}))!=6 or len(m.get('extra_pins',{}))!=7 or len(m.get('pairs',[]))!=4:raise ValueError('supplement required keys')
    for name,p in m['protected_seed_pins'].items():checked(confined(repo,name),p)
    for name,p in m['extra_pins'].items():checked(confined(root,'references/native-source/'+name),p)
    if {(p['model'],p['base']) for p in m['pairs']}!={(110,1),(424,2),(8277,1),(771,1)}:raise ValueError('unknown pairs')
    blobs={}
    for pair in m['pairs']:
        model=pair['model']
        if not pair['mdl_bones'] or set(pair['files'])!={'mdl','sklb'}:raise ValueError('pair keys')
        for kind,p in pair['files'].items():blobs[(model,kind)]=checked(root/('parent-extraction-v1/m%04d.%s'%(model,kind)),p)
    for name,p in old['inputs'].items():
        b=checked(confined(root,name),p)
        if name.endswith('.pap'):
            h=pap_header(b)
            if h['model'] not in (110,424,8277,771) or h['type_byte']!=1 or h['variant_byte']!=0:raise ValueError('unknown PAP metadata '+str(h))
            if len(h['clips'])!=(3 if h['model']==110 else 2) or sorted(c['index'] for c in h['clips'])!=list(range(len(h['clips']))):raise ValueError('PAP indices')
            blobs[(h['model'],'pap')]=(b,h,name,p)
    if len(blobs)!=12:raise ValueError('missing PAP')
    checked(Path(PYTHON),{'sha256':'4d33ac58a36d25332ee361c0b27ae73ba7936a799eb7520915a87e03861846a2','bytes':102168})
    checked(Path(DLL),{'sha256':'912da6dc273cd821aea8cabde510e84cd7d37b2544edc8fc9db5fa33e020b437','bytes':10936320})
    return m,blobs

class Transform(C.Structure):_fields_=[('values',C.c_float*12)]
assert C.sizeof(Transform)==48

def guarded(typ,n):
    class Buffer(C.Structure):_fields_=[('before',C.c_uint32*4),('data',typ*n),('after',C.c_uint32*4)]
    b=Buffer()
    for i in range(4):b.before[i]=b.after[i]=0xA93D12F7
    return b

def intact(b):
    if list(b.before)!=[0xA93D12F7]*4 or list(b.after)!=[0xA93D12F7]*4:raise ValueError('buffer canary')

def bone_name(address):
    class Region(C.Structure):_fields_=[('base',C.c_void_p),('allocation',C.c_void_p),('allocation_protect',C.c_ulong),('size',C.c_size_t),('state',C.c_ulong),('protect',C.c_ulong),('type',C.c_ulong)]
    query=C.windll.kernel32.VirtualQuery;query.argtypes=[C.c_void_p,C.POINTER(Region),C.c_size_t];query.restype=C.c_size_t
    if not address:raise ValueError('null name')
    r=Region()
    if not query(address,C.byref(r),C.sizeof(r)) or r.state!=0x1000 or r.protect&0x100 or (r.protect&255) not in (2,4,8,32,64,128):raise ValueError('unreadable name')
    n=min(256,r.base+r.size-address)
    raw=C.string_at(address,n)
    if b'\0' not in raw:raise ValueError('unbounded name')
    name=raw.split(b'\0')[0].decode('utf-8')
    if not name:raise ValueError('empty name')
    return name

def sample(root,model):
    m,blobs=trusted(root)
    if C.sizeof(C.c_void_p)!=4 or Path(sys.executable).resolve()!=Path(PYTHON).resolve():raise ValueError('exact 32 bit Python required')
    in_job=C.c_int();k=C.windll.kernel32;k.GetCurrentProcess.restype=C.c_void_p
    k.IsProcessInJob.argtypes=[C.c_void_p,C.c_void_p,C.POINTER(C.c_int)]
    if not k.IsProcessInJob(k.GetCurrentProcess(),None,C.byref(in_job)) or not in_job.value:raise ValueError('Job required')
    pair=next(p for p in m['pairs'] if p['model']==model)
    b,h,pap_path,pap_pin=blobs[(model,'pap')]
    skdata=C.create_string_buffer(sklb_payload(blobs[(model,'sklb')]))
    adata=C.create_string_buffer(b[h['container_offset']:h['container_end']])
    lib=C.CDLL(DLL);P=C.c_void_p;I=C.c_int
    def fn(name,result,args):
        f=getattr(lib,name);f.restype=result;f.argtypes=args;return f
    init=fn('initHkInterop',None,[]);quit=fn('quitHkInterop',None,[])
    loadsk=fn('loadSkeleton',P,[P,I]);unloadsk=fn('unloadSkeleton',None,[P]);nb=fn('getNumBones',I,[P])
    names=fn('getBoneNames',I,[P,P]);parents=fn('getParentIndices',I,[P,P]);ref=fn('getReferencePose',I,[P,P])
    loadac=fn('loadAnimationContainer',P,[P,P,I]);unloadac=fn('unloadAnimationContainer',None,[P]);na=fn('getNumAnimations',I,[P]);get=fn('getAnimation',P,[P,I]);dur=fn('getDuration',C.c_float,[P]);pose=fn('getPose',I,[P,C.c_float,P])
    sk=ac=None;init()
    try:
        sk=loadsk(skdata,len(skdata)-1)
        if not sk:raise ValueError('null skeleton')
        n=nb(sk)
        if not 0<n<=4096:raise ValueError('native bone count')
        ns=guarded(P,n);ps=guarded(I,n)
        for i in range(n):ps.data[i]=-2147483648
        returns={'names':names(sk,ns.data),'parents':parents(sk,ps.data)};intact(ns);intact(ps)
        bn=[bone_name(x) for x in ns.data];pa=list(ps.data);validate_parents(pa)
        missing=sorted(set(pair['mdl_bones'])-set(bn))
        if missing:raise ValueError('MDL names absent: '+str(missing))
        def read_pose(call,*args):
            ts=guarded(Transform,n)
            for t in ts.data:
                for j in range(12):t.values[j]=float('nan')
            ret=call(*args,ts.data);intact(ts)
            vals=[list(t.values) for t in ts.data]
            if not all(math.isfinite(v) for t in vals for v in t):raise ValueError('nonfinite/unwritten TRS')
            return vals,ret
        reference,returns['reference']=read_pose(ref,sk)
        ac=loadac(sk,adata,len(adata)-1)
        if not ac:raise ValueError('null animation container')
        count=na(ac)
        if count!=len(h['clips']):raise ValueError('animation count mismatch')
        plans=[];used=n*512
        for clip in h['clips']:
            if not 0<=clip['index']<count:raise ValueError('index')
            a=get(ac,clip['index'])
            if not a:raise ValueError('null animation')
            d=float(dur(a));times=sample_times(d,n,used);used+=len(times)*n*512
            plans.append((clip,a,d,times))
        clips=[]
        for clip,a,d,times in plans:
            frames=[];rs=[]
            for t in times:
                vals,r=read_pose(pose,a,t);frames.append(vals);rs.append(r)
            points=range(len(times)-1,-1,-1)
            reverse_returns=[]
            for i in points:
                v,r=read_pose(pose,a,times[i]);reverse_returns.append(r)
                if v!=frames[i]:raise ValueError('reverse requery mismatch')
            clips.append({**clip,'duration':d,'bone_count':n,'times':times,'native_query_times':[float(C.c_float(t).value) for t in times],'frames':frames,'pose_returns':rs,'reverse_returns':reverse_returns,'reverse_match':True,'reverse_requery_count':len(times),'first_three_distinct':len({json.dumps(v) for v in frames[:3]})})
        return {'numeric_status':'PASS','model':model,'base':pair['base'],'files':pair['files'],'pap':{'path':pap_path,**pap_pin},'names':bn,'parents':pa,'mdl_dictionary_missing':missing,'reference_local':reference,'pose_space':'model (upstream convention)','layout':'Translation4 Scale4 Rotation4','returns':returns,'bone_count':n,'native_animation_count':count,'clips':clips,'all96_accepted':False,'native_runtime_choice':'UNKNOWN','cadence_hz':30,'time_policy':'logical 30Hz grid filtered to unique float32 native query times, inclusive exact native duration'}
    finally:
        if ac:unloadac(ac)
        if sk:unloadsk(sk)
        quit()

def main():
    p=argparse.ArgumentParser();p.add_argument('--root',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--model',type=int,choices=[110,424,8277,771],required=True)
    a=p.parse_args();confined(a.root,str(a.output.resolve()));a.output.mkdir(exist_ok=False)
    try:
        result=sample(a.root,a.model);data=json.dumps(result,separators=(',',':'),allow_nan=False).encode('utf-8')
        if len(data)>64*1024**2:raise ValueError('OPEN actual JSON byte cap')
        (a.output/'samples.json').write_bytes(data)
        print(json.dumps({'model':a.model,'status':'PASS','bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}))
    except Exception as e:
        (a.output/'failure.json').write_text(json.dumps({'status':'OPEN','reason':str(e),'all96_accepted':False}),encoding='utf-8');raise
if __name__=='__main__':main()

