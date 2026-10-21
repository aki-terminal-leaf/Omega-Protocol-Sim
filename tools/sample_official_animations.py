"""Task-local ctypes adapter for Godbert's existing 32-bit Havok reader."""
import ctypes as C,json,struct,sys,argparse
from pathlib import Path
class Vec4(C.Structure):_fields_=[('x',C.c_float),('y',C.c_float),('z',C.c_float),('w',C.c_float)]
class Transform(C.Structure):_fields_=[('translation',Vec4),('scale',Vec4),('rotation',Vec4)]
def values(t):return {'translation':[t.translation.x,t.translation.y,t.translation.z],'rotation':[t.rotation.x,t.rotation.y,t.rotation.z,t.rotation.w],'scale':[t.scale.x,t.scale.y,t.scale.z]}
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--native-lib',type=Path,required=True)
parser.add_argument('--input',type=Path,required=True)
args=parser.parse_args()
if C.sizeof(C.c_void_p)!=4:raise RuntimeError('Use a 32-bit Python process for the 32-bit Godbert native library')
lib=C.CDLL(str(args.native_lib))
def signature(name,restype,args):
 f=getattr(lib,name);f.restype=restype;f.argtypes=args;return f
ptr=C.c_void_p;integer=C.c_int
init=signature('initHkInterop',None,[]);quit=signature('quitHkInterop',None,[])
loadsk=signature('loadSkeleton',ptr,[ptr,integer]);unloadsk=signature('unloadSkeleton',None,[ptr]);numbones=signature('getNumBones',integer,[ptr]);names=signature('getBoneNames',integer,[ptr,C.POINTER(C.c_char_p)]);parents=signature('getParentIndices',integer,[ptr,C.POINTER(integer)]);reference=signature('getReferencePose',integer,[ptr,C.POINTER(Transform)])
loadanim=signature('loadAnimationContainer',ptr,[ptr,ptr,integer]);unloadanim=signature('unloadAnimationContainer',None,[ptr]);numanim=signature('getNumAnimations',integer,[ptr]);anim=signature('getAnimation',ptr,[ptr,integer]);duration=signature('getDuration',C.c_float,[ptr]);pose=signature('getPose',integer,[ptr,C.c_float,C.POINTER(Transform)])
root=args.input;init()
for path in root.glob('*.sklb'):
 b=path.read_bytes();offset=struct.unpack_from('<H',b,12 if b[4:8]==b'0031' else 10)[0];data=C.create_string_buffer(b[offset:]);sk=loadsk(data,len(b)-offset)
 if not sk:raise RuntimeError('Native skeleton load failed: '+path.name)
 count=numbones(sk)
 if not 0<count<1000:raise RuntimeError('Invalid bone count '+str(count))
 ns=(C.c_char_p*count)();ps=(integer*count)();ts=(Transform*count)();names(sk,ns);parents(sk,ps);reference(sk,ts)
 result={'form':path.stem,'bones':[{'name':ns[i].decode(),'parent':ps[i],**values(ts[i])} for i in range(count)],'animations':[]}
 pap=path.with_suffix('.pap').read_bytes();n=struct.unpack_from('<h',pap,8)[0];off,end=struct.unpack_from('<ii',pap,18);data2=C.create_string_buffer(pap[off:end]);ac=loadanim(sk,data2,end-off)
 print(path.stem,'bones',count,'animations',numanim(ac),'names',[(pap[26+i*40:26+i*40+32].split(b'\0')[0].decode(),struct.unpack_from('<i',pap,60+i*40)[0]) for i in range(n)],flush=True)
 for i in range(n):
  name=pap[26+i*40:26+i*40+32].split(b'\0')[0].decode();index=struct.unpack_from('<i',pap,60+i*40)[0]
  # All resident clips are preserved. Battle idle is selected by the runtime.
  a=anim(ac,index);d=float(duration(a));frames=max(2,min(600,round(d*30)+1));times=[min(d,j/30) for j in range(frames)]
  if times[-1]<d:times.append(d)
  samples=[]
  for t in times:pose(a,t,ts);samples.append([values(ts[j]) for j in range(count)])
  result['animations'].append({'name':name,'duration':d,'times':times,'frames':samples})
 path.with_suffix('.json').write_text(json.dumps(result,separators=(',',':')))
 unloadanim(ac);unloadsk(sk)
quit()
