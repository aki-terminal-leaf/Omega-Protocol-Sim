#!/usr/bin/env python3
"""Append pinned, original lossless GLB images without replacing meshes or animations.

Private source mapping: {model_key: {path, sha256, allow_material_binding_changes?}}.
The optional exception is for a reviewed optical BG diffuse-binding correction;
all existing native materials are preserved. Original TEX shader fidelity is not
certified by restoring an earlier exporter PNG.
"""
import argparse, copy, hashlib, io, json, shutil, struct
from pathlib import Path
from PIL import Image


def sha(data):
    return hashlib.sha256(data).hexdigest()


def read_glb(path):
    data = path.read_bytes()
    magic, version, length = struct.unpack_from('<III', data)
    assert (magic, version, length) == (0x46546c67, 2, len(data))
    size, tag = struct.unpack_from('<II', data, 12)
    assert tag == 0x4e4f534a
    doc = json.loads(data[20:20+size])
    count, tag = struct.unpack_from('<II', data, 20+size)
    assert tag == 0x004e4942
    return doc, data[28+size:28+size+count], data


def image_bytes(doc, binary, image):
    assert image['mimeType'] == 'image/png', 'Lossless PNG source required'
    view = doc['bufferViews'][image['bufferView']]
    start = view.get('byteOffset', 0)
    return binary[start:start+view['byteLength']]


def accessor_bytes(doc, binary, index):
    a = doc['accessors'][index]; assert 'sparse' not in a
    v = doc['bufferViews'][a['bufferView']]
    width = {'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']] * {5120:1,5121:1,5122:2,5123:2,5125:4,5126:4}[a['componentType']]
    offset = v.get('byteOffset', 0)+a.get('byteOffset', 0)
    stride = v.get('byteStride', width)
    return b''.join(binary[offset+i*stride:offset+i*stride+width] for i in range(a['count']))


def restore(native, source, allow_material_binding_changes=False):
    doc, binary, before = read_glb(native); raw, rb, source_bytes = read_glb(source)
    original = copy.deepcopy(doc)
    assert [i.get('name') for i in doc['images']] == [i.get('name') for i in raw['images']]
    clean_textures=lambda rows:[{k:v for k,v in x.items() if not (k=='extensions' and v=={})} for x in rows]
    assert clean_textures(doc['textures']) == clean_textures(raw['textures']), 'Image-to-texture routing changed'
    assert doc['samplers'] == raw['samplers']
    if not allow_material_binding_changes:
        assert doc['materials'] == raw['materials'], 'Source colorset/material mismatch'
        a = doc['asset'].get('extras', {}).get('source_sha256')
        b = raw['asset'].get('extras', {}).get('source_sha256')
        assert a and a == b, 'Actual original model hash required'
    else:
        # The scoped optical exception still proves original static mesh bytes.
        assert doc['nodes'] == raw['nodes'] and doc['meshes'] == raw['meshes']
        assert [x.get('name') for x in doc['materials']] == [x.get('name') for x in raw['materials']]
        for mesh in doc['meshes']:
            for primitive in mesh['primitives']:
                for index in list(primitive['attributes'].values())+[primitive['indices']]:
                    assert accessor_bytes(doc, binary, index) == accessor_bytes(raw, rb, index)
    out = bytearray(binary); rows = []
    for index, image in enumerate(doc['images']):
        prior = image_bytes(doc, binary, image); data = image_bytes(raw, rb, raw['images'][index])
        size = Image.open(io.BytesIO(data)).size; old_size = Image.open(io.BytesIO(prior)).size
        assert size[0] >= old_size[0] and size[1] >= old_size[1]
        out.extend(b'\0'*(-len(out)%4)); offset = len(out); out.extend(data)
        image['bufferView'] = len(doc['bufferViews'])
        doc['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(data)})
        rows.append({'index':index,'name':image.get('name'),'old_dimensions':old_size,'source_dimensions':size,'source_png_sha256':sha(data)})
    out.extend(b'\0'*(-len(out)%4)); doc['buffers'][0]['byteLength'] = len(out)
    assert bytes(out[:len(binary)]) == binary, 'Original binary prefix changed'
    for field in ['accessors','animations','meshes','nodes','skins','materials','textures','samplers']:
        assert doc.get(field) == original.get(field), field
    j = json.dumps(doc,separators=(',',':')).encode(); j += b' '*(-len(j)%4)
    payload = struct.pack('<III',0x46546c67,2,28+len(j)+len(out))+struct.pack('<II',len(j),0x4e4f534a)+j+struct.pack('<II',len(out),0x004e4942)+out
    native.write_bytes(payload)
    readback, bb, _ = read_glb(native)
    for row, image in zip(rows,readback['images']):
        assert sha(image_bytes(readback,bb,image)) == row['source_png_sha256']
    return {'old_native_sha256':sha(before),'source_glb_sha256':sha(source_bytes),'native_sha256':sha(payload),'binary_prefix_unchanged':True,'materials_geometry_animations_unchanged':True,'images':rows}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ['data','sources','out']:p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args(); assert not a.out.exists(), 'Fresh output required'
    mapping=json.loads(a.sources.read_text(encoding='utf-8'));manifest=json.loads((a.data/'manifest.json').read_text(encoding='utf-8'))
    # Fail all source pins before copying or converting any asset.
    for key,spec in mapping.items():
        assert sha(Path(spec['path']).read_bytes()) == spec['sha256'], key
        assert manifest['native_assets'][key]['kind']=='glb', key
    shutil.copytree(a.data,a.out); proof={}
    for key,spec in mapping.items():
        native=a.out/manifest['native_assets'][key]['file']
        proof[key]=restore(native,Path(spec['path']),spec.get('allow_material_binding_changes',False))
        manifest['native_assets'][key]['lossless_source_images_sha256']=spec['sha256']
    (a.out/'manifest.json').write_text(json.dumps(manifest,separators=(',',':')),encoding='utf-8')
    (a.out/'source-image-restoration.json').write_text(json.dumps({'status':'SOURCE_EXPORT_IMAGES_RESTORED_NOT_GAME_SHADER_ACCEPTANCE','models':proof,'raw_TEX_full_resolution':'NOT_CERTIFIED_BY_THIS_GATE'},indent=2),encoding='utf-8')
    print(json.dumps({'models':len(proof),'images':sum(len(x['images']) for x in proof.values()),'output':str(a.out)}))

if __name__=='__main__':main()
