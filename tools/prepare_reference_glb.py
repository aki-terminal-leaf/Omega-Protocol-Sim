#!/usr/bin/env python3
"""Prepare a local reference GLB for Godot 4.4 without changing its source.

Bake static KHR_node_visibility into mesh references and limit texture size.
Geometry, skeleton and animation tracks are preserved byte-for-byte.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import struct
from PIL import Image

def prepare(source: Path, target: Path, maximum: int):
    if source.resolve()==target.resolve():raise ValueError('Preserve the original GLB in a separate directory')
    raw=source.read_bytes();jlen,jtype=struct.unpack_from('<II',raw,12)
    if jtype!=0x4e4f534a:raise ValueError('Not a JSON-first GLB')
    doc=json.loads(raw[20:20+jlen]);blen,btype=struct.unpack_from('<II',raw,20+jlen)
    if btype!=0x004e4942:raise ValueError('Missing binary chunk')
    original=raw[28+jlen:28+jlen+blen];images={im['bufferView'] for im in doc.get('images',[]) if 'bufferView' in im}
    output=bytearray();resized=0
    for index,view in enumerate(doc['bufferViews']):
        start=view.get('byteOffset',0);data=original[start:start+view['byteLength']]
        if index in images:
            image=Image.open(io.BytesIO(data))
            if max(image.size)>maximum:
                image.thumbnail((maximum,maximum),Image.Resampling.LANCZOS)
                stream=io.BytesIO();image.save(stream,format='PNG');data=stream.getvalue();resized+=1
        output.extend(b'\0'*(-len(output)%4));view['byteOffset']=len(output);view['byteLength']=len(data);output.extend(data)
    hidden=[]
    def bake(index, inherited=True):
        node=doc['nodes'][index];extensions=node.get('extensions',{});visible=inherited and extensions.pop('KHR_node_visibility',{}).get('visible',True)
        if not extensions:node.pop('extensions',None)
        if not visible and 'mesh' in node:hidden.append(node['name']);node.pop('mesh',None);node.pop('skin',None)
        for child in node.get('children',[]):bake(child,visible)
    for scene in doc.get('scenes',[]):
        for node in scene.get('nodes',[]):bake(node)
    for key in ['extensionsUsed','extensionsRequired']:
        if key in doc:
            doc[key]=[e for e in doc[key] if e!='KHR_node_visibility']
            if not doc[key]:doc.pop(key)
    doc['buffers'][0]['byteLength']=len(output)
    doc.setdefault('asset',{}).setdefault('extras',{})['top_local_conversion']={'original_sha256':hashlib.sha256(raw).hexdigest(),'maximum_texture_size':maximum,'baked_hidden_meshes':hidden}
    j=json.dumps(doc,separators=(',',':')).encode();j+=b' '*(-len(j)%4);output.extend(b'\0'*(-len(output)%4))
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_bytes(struct.pack('<III',0x46546c67,2,12+8+len(j)+8+len(output))+struct.pack('<II',len(j),0x4e4f534a)+j+struct.pack('<II',len(output),0x004e4942)+output)
    return {'source_sha256':hashlib.sha256(raw).hexdigest(),'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'resized_textures':resized,'baked_hidden_meshes':hidden,'bytes':target.stat().st_size}

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('source',type=Path);p.add_argument('target',type=Path);p.add_argument('--max-texture-size',type=int,default=512);args=p.parse_args()
    if args.max_texture_size<1:p.error('Texture size must be positive')
    print(json.dumps(prepare(args.source,args.target,args.max_texture_size),indent=2))
if __name__=='__main__':main()
