#!/usr/bin/env python3
"""Check the actual emitted original galaxy cutout GLB; no game media in Git."""
import sys,json,struct,io
from pathlib import Path
from PIL import Image
p=Path(sys.argv[1]);b=p.read_bytes();n=struct.unpack_from('<I',b,12)[0];j=json.loads(b[20:20+n]);at=20+n;bn=struct.unpack_from('<I',b,at)[0];binary=b[at+8:at+8+bn]
materials=[m for m in j['materials'] if m.get('extras',{}).get('original_shader_constants',{}).get('0x29ac0223')==[0.5]]
assert materials,'Expected original alpha-test galaxy layer'
for m in materials:
 assert m.get('alphaMode')=='MASK' and m.get('alphaCutoff')==0.5,m
 tex=j['textures'][m['pbrMetallicRoughness']['baseColorTexture']['index']];im=j['images'][tex['source']];v=j['bufferViews'][im['bufferView']];start=v.get('byteOffset',0);image=Image.open(io.BytesIO(binary[start:start+v['byteLength']])).convert('RGBA');lo,hi=image.getchannel('A').getextrema();assert lo<128<hi,(lo,hi)
print(json.dumps({'status':'PASS','materials':len(materials),'source_alpha_preserved':True,'original_threshold':0.5}))
