#!/usr/bin/env python3
"""Read original version-21 EID bind points with a complete byte roundtrip."""
import argparse,hashlib,json,math,struct
from pathlib import Path
HEADER=struct.Struct("<4sHHII")
ROW=struct.Struct("<32si6fI")
def parse(data):
 if len(data)<HEADER.size:raise ValueError("Truncated EID")
 magic,v1,v2,count,unknown=HEADER.unpack_from(data)
 if magic!=b"die\0" or v1!=0x3132 or not 0<count<=4096:raise ValueError("Unsupported EID header")
 if len(data)!=HEADER.size+count*ROW.size:raise ValueError("EID row boundary mismatch")
 rows=[];encoded=bytearray(HEADER.pack(magic,v1,v2,count,unknown))
 for i in range(count):
  fields=ROW.unpack_from(data,HEADER.size+i*ROW.size);name,ident,*tail=fields
  numbers,padding=tail[:6],tail[6]
  if not all(math.isfinite(v) for v in numbers):raise ValueError("Nonfinite EID transform")
  bone=name.split(b"\0",1)[0].decode("ascii")
  rows.append({"id":ident,"bone":bone,"position":numbers[:3],"rotation_radians":numbers[3:]})
  encoded.extend(ROW.pack(*fields))
 if bytes(encoded)!=data:raise ValueError("Lossless EID roundtrip failed")
 return {"count":count,"rows":rows,"source_sha256":hashlib.sha256(data).hexdigest(),"roundtrip_equal":True,"rotation_order":"YawPitchRoll(Y,X,Z); Godot EULER_ORDER_YXZ"}
def main():
 a=argparse.ArgumentParser(description=__doc__);a.add_argument("--input",type=Path,required=True);a.add_argument("--output",type=Path,required=True);args=a.parse_args()
 d=parse(args.input.read_bytes());args.output.write_text(json.dumps(d,indent=2));print(json.dumps({k:v for k,v in d.items() if k!="rows"}))
if __name__=="__main__":main()

