#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Bounded read-only ShPk/DXBC inspector, not a shader executor or translator.
Layout reference (MIT): Ottermandias/Penumbra.GameData
b6c5de34c05459c6af97ad14c2dac3d269aa84d9, Files/ShpkFile.cs.
Stored DXBC checksum is reported, not cryptographically recomputed.
"""
import argparse,hashlib,json,os,struct
MAX=64<<20; STAGES=("vertex","pixel","hull","domain","geometry"); VERSIONS={0x0C01,0x0D01,0x0E01}
class ShpkError(ValueError):pass
class R:
 def __init__(s,d):s.d=d;s.p=0;s.limit=len(d)
 def b(s,n,w):
  if n<0 or s.p+n>s.limit:raise ShpkError(f"truncated {w} at {s.p}")
  x=s.d[s.p:s.p+n];s.p+=n;return x
 def h(s,w):return struct.unpack("<H",s.b(2,w))[0]
 def i(s,w):return struct.unpack("<I",s.b(4,w))[0]
def lim(n,m,w):
 if n>m:raise ShpkError(f"{w} count {n} exceeds {m}")
 return n
def res(r,d,so):
 i,o,n=r.i("resource id"),r.i("name offset"),r.h("name size")
 if o+n>len(d)-so:raise ShpkError("resource name outside string table")
 x=d[so+o:so+o+n];x=x[:-1] if x.endswith(b"\0") else x
 return {"id":i,"name":x.decode("utf8","surrogateescape"),"is_texture":r.h("flag"),"slot":r.h("slot"),"size":r.h("resource size")}
def dxbc(b,required=False):
 o={"format":"unknown","size":len(b),"sha256":hashlib.sha256(b).hexdigest(),"chunks":[]}
 if not b.startswith(b"DXBC"):
  if required:raise ShpkError("DirectX 11 program is not DXBC")
  return o
 if len(b)<32:raise ShpkError("truncated DXBC header")
 u,z,n=struct.unpack_from("<III",b,20)
 if z!=len(b):raise ShpkError(f"DXBC declared size {z} != blob size {len(b)}")
 lim(n,4096,"DXBC chunk")
 if 32+4*n>len(b):raise ShpkError("truncated DXBC chunk table")
 spans=[]
 for j in range(n):
  p=struct.unpack_from("<I",b,32+4*j)[0]
  if p<32+4*n or p%4 or p+8>len(b):raise ShpkError("DXBC chunk header outside payload")
  q=struct.unpack_from("<I",b,p+4)[0]
  if p+8+q>len(b):raise ShpkError("DXBC chunk payload outside blob")
  if any(p<end and start<p+8+q for start,end in spans):raise ShpkError("overlapping DXBC chunks")
  spans.append((p,p+8+q))
  o["chunks"].append({"index":j,"fourcc":b[p:p+4].decode("ascii","replace"),"offset":p,"size":q,"sha256":hashlib.sha256(b[p+8:p+8+q]).hexdigest()})
 o.update(format="DXBC",checksum=b[4:20].hex(),header_unknown=u,declared_size=z);return o
def inspect(d):
 if type(d)is not bytes:raise TypeError("data must be bytes")
 if len(d)>MAX:raise ShpkError("input exceeds 64 MiB")
 r=R(d)
 if r.b(4,"magic")!=b"ShPk":raise ShpkError("not an ShPk file")
 v=r.i("version")
 if v not in VERSIONS:raise ShpkError(f"unsupported ShPk version 0x{v:04X}; supported: 0x0C01, 0x0D01, 0x0E01")
 tag=r.b(4,"DX tag")
 if tag not in (b"DX9\0",b"DX11"):raise ShpkError("unsupported DirectX tag")
 fs,bo,so=r.i("size"),r.i("blobs"),r.i("strings")
 if fs!=len(d):raise ShpkError("declared file size mismatch")
 if not r.p<=bo<=so<=len(d):raise ShpkError("invalid section offsets")
 vs,ps,ms=r.i("vs"),r.i("ps"),r.i("material size");mc,hd=r.h("materials"),r.h("defaults")
 counts_global=[r.i("constants"),r.h("samplers"),r.h("textures"),r.i("uavs")]
 sk,ck,mk,nc,ac=[r.i(x) for x in ("system keys","scene keys","material keys","nodes","aliases")]
 counts=[vs,ps,0,0,0]
 if v>=0x0D01:counts[2:]=[r.i("hs"),r.i("ds"),r.i("gs")]
 cluster=r.i("clusters") if v>=0x0E01 else 0
 lim(sum(counts),20000,"program");lim(nc,100000,"node");lim(ac,100000,"alias");lim(cluster,4096,"alias cluster")
 r.limit=bo
 programs={s:[] for s in STAGES};vh=4 if tag==b"DX9\0" else 8
 resource_total=0
 def many(n):
  nonlocal resource_total
  resource_total+=n;lim(resource_total,250000,"total binding")
  return [res(r,d,so) for _ in range(lim(n,100000,"resource"))]
 for st,n in zip(STAGES,counts):
  for ix in range(n):
   off,z=r.i("blob offset"),r.i("blob size");bn=[r.h("binding count") for _ in range(4)];unk=r.i("shader unknown") if v>=0x0D01 else {"vertex":1,"pixel":4,"geometry":8}.get(st,0)
   if off+z>so-bo:raise ShpkError(f"{st} shader {ix} blob outside table")
   eh=vh if st=="vertex" else 0
   if z<eh:raise ShpkError("shader shorter than additional header")
   raw=d[bo+off:bo+off+z];bind={k:many(n) for k,n in zip(("constants","samplers","uavs","textures"),bn)}
   programs[st].append({"index":ix,"blob_offset":off,"stored_size":z,"additional_header":raw[:eh].hex(),"unknown_0d01":unk,"bindings":bind,"bytecode":dxbc(raw[eh:],required=tag==b"DX11")})
 mats=[{"id":r.i("mat id"),"byte_offset":r.h("mat offset"),"byte_size":r.h("mat size")}for _ in range(mc)];md=r.b(ms,"defaults")if hd else b""
 glob={k:many(n)for k,n in zip(("constants","samplers","textures","uavs"),counts_global)}
 def keys(n,w):return [{"id":r.i(w+" id"),"default":r.i(w+" default")}for _ in range(lim(n,20000,w))]
 ko={"system":keys(sk,"system"),"scene":keys(ck,"scene"),"material":keys(mk,"material")};sub=[r.i("subview1"),r.i("subview2")];nodes=[];tp=0
 for ni in range(nc):
  sel,pc=r.i("selector"),r.i("pass count");tp+=pc;lim(tp,500000,"pass");pi=list(r.b(16,"pass indices"));uk=[r.i("unknown key")for _ in range(2)]if v>=0x0D01 else []
  kv={"system":[r.i("system value")for _ in range(sk)],"scene":[r.i("scene value")for _ in range(ck)],"material":[r.i("material value")for _ in range(mk)],"subview":[r.i("subview value")for _ in range(2)]};pss=[]
  for _ in range(pc):
   p={"id":r.i("pass id"),"vertex":r.i("vs ref"),"pixel":r.i("ps ref")}
   for st in STAGES[2:]:p[st]=r.i(st+" ref")if v>=0x0D01 else 0xffffffff
   for st in STAGES:
    if p[st]!=0xffffffff and p[st]>=len(programs[st]):raise ShpkError(f"node {ni} pass references missing {st} shader {p[st]}")
   pss.append(p)
  nodes.append({"index":ni,"selector":sel,"pass_indices":pi,"unknown_0d01_keys":uk or kv["subview"],"keys":kv,"passes":pss})
 aliases=[]
 for _ in range(ac):
  s,n=r.i("alias selector"),r.i("alias node")
  if n>=nc:raise ShpkError("alias references missing node")
  aliases.append({"selector":s,"node":n})
 cls=[];subcluster_total=0
 for ci in range(cluster):
  v2,v1,n,u=[r.i(x)for x in("subview2","subview1","subclusters","cluster unknown")];subs=[]
  subcluster_total+=n;lim(subcluster_total,100000,"total subcluster")
  for _ in range(lim(n,100000,"subcluster")):
   raw=r.b(392,"alias subcluster");own,an=struct.unpack_from("<HH",raw)
   if an>48:raise ShpkError("alias count exceeds capacity")
   aa=[{"selector":struct.unpack_from("<I",raw,4+8*j)[0],"node":struct.unpack_from("<I",raw,8+8*j)[0]}for j in range(an)];subs.append({"own_index":own,"aliases":aa,"additional_data":raw[4+8*an:].hex()})
  cls.append({"subview_value_2":v2,"subview_value_1":v1,"unknown_0e01":u,"subclusters":subs})
 if r.p>bo:raise ShpkError("metadata overlaps blobs")
 return {"format":"ShPk","source_sha256":hashlib.sha256(d).hexdigest(),"shader_execution":False,"rendering_complete":False,"version":f"0x{v:04X}","directx":9 if tag==b"DX9\0"else 11,"file_size":fs,"offsets":{"blobs":bo,"strings":so},"programs":programs,"material_params_size":ms,"has_material_defaults":bool(hd),"material_params":mats,"material_defaults_sha256":hashlib.sha256(md).hexdigest()if hd else None,"resources":glob,"keys":ko,"subview_defaults":sub,"nodes":nodes,"aliases":aliases,"alias_clusters":cls,"additional_metadata":{"bytes":bo-r.p,"sha256":hashlib.sha256(d[r.p:bo]).hexdigest()}}
def main():
 p=argparse.ArgumentParser();p.add_argument("input");p.add_argument("--extract-stage",choices=STAGES);p.add_argument("--extract-index",type=int);p.add_argument("--output");a=p.parse_args();x=(a.extract_stage,a.extract_index,a.output)
 if any(y is not None for y in x)and not all(y is not None for y in x):p.error("all extract options required")
 with open(a.input,"rb")as f:d=f.read(MAX+1)
 o=inspect(d)
 if a.output:
  if not 0<=a.extract_index<len(o["programs"][a.extract_stage]):p.error("extract index outside requested shader stage")
  q=o["programs"][a.extract_stage][a.extract_index];start=o["offsets"]["blobs"]+q["blob_offset"]+len(bytes.fromhex(q["additional_header"]));fd=os.open(a.output,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o644)
  with os.fdopen(fd,"wb")as f:f.write(d[start:start+q["bytecode"]["size"]])
 print(json.dumps(o,sort_keys=True,separators=(",",":")))
if __name__=="__main__":main()
