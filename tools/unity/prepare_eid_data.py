#!/usr/bin/env python3
"""Build private original NPC EID metadata from pinned resources into a fresh snapshot.
Layout: MIT Dalamud-VFXEditor EidFile/EidBindPointNew at
05f6eb0cce19a6a91ae275bce609299d573914b3. No game runtime is embedded.
Only verified version-21, 64-byte records are accepted. Stored radians/offsets
are retained; original game host rotation/lifecycle fidelity is not certified.
"""
import argparse, hashlib, json, math, re, shutil, struct
from pathlib import Path


def sha(data):return hashlib.sha256(data).hexdigest()


def parse_eid(data):
    magic,v1,v2,count,unknown=struct.unpack_from('<IhhII',data)
    assert magic==0x00656964 and v1==0x3132, 'Unsupported EID format'
    assert 0<count<=4096 and len(data)==16+count*64
    rows=[];rebuilt=bytearray(data[:16]);ids=set()
    for index in range(count):
        offset=16+index*64;name_bytes,identifier,*values=struct.unpack_from('<32si6fI',data,offset)
        name=name_bytes.split(b'\0',1)[0].decode('ascii');assert name and name_bytes==name.encode().ljust(32,b'\0')
        position=values[:3];rotation=values[3:6];padding=values[6]
        assert identifier not in ids and all(math.isfinite(v) for v in position+rotation)
        ids.add(identifier);rebuilt.extend(struct.pack('<32si6fI',name.encode().ljust(32,b'\0'),identifier,*position,*rotation,padding))
        rows.append({'id':identifier,'bone':name,'position':position,'rotation_radians':rotation})
    assert rebuilt==data, 'EID binary roundtrip differs'
    return {'count':count,'rows':rows,'sha256':sha(data),'binary_roundtrip':True,'version':[v1,v2]}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ['data','raw','manifest','out']:p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args();assert not a.out.exists(), 'Fresh output required'
    resource=json.loads(a.manifest.read_text(encoding='utf-8'))['resources'];families={}
    for source in a.raw.rglob('*.eid'):
        path=source.relative_to(a.raw).as_posix();data=source.read_bytes()
        assert sha(data)==resource[path]['sha256'],path
        match=re.search(r'chara/monster/(m\d+)/',path);assert match,path
        family=match[1];assert family not in families
        table=parse_eid(data);table['source_path']=path;families[family]=table
    assert families, 'Empty EID corpus'
    weapons=json.loads((a.data/'weapon-data.json').read_text(encoding='utf-8'))
    for family in ['m0513','m0514']:
        assert families[family]['rows']==weapons['eid'][family]['rows'], 'Existing independently parsed M/F EID mismatch'
    manifest=json.loads((a.data/'manifest.json').read_text(encoding='utf-8'));forms={};unmapped=[]
    for key,spec in manifest['native_assets'].items():
        if spec['kind']!='glb':continue
        data=(a.data/spec['file']).read_bytes();n=struct.unpack_from('<I',data,12)[0];doc=json.loads(data[20:20+n]);path=doc['asset'].get('extras',{}).get('source_game_path','');match=re.search(r'chara/monster/(m\d+)/',path)
        if not match:continue
        family=match[1]
        if family in families:forms[key]=family
        else:unmapped.append({'form':key,'source_model':path,'family':family})
    result={'schema':1,'format_reference':'Dalamud-VFXEditor@05f6eb0cce19a6a91ae275bce609299d573914b3 EidBindPointNew','families':families,'byForm':forms,'unmapped':unmapped,'game_host_equivalence':False}
    shutil.copytree(a.data,a.out);(a.out/'attachment-data.json').write_text(json.dumps(result,separators=(',',':')),encoding='utf-8')
    print(json.dumps({'families':len(families),'rows':sum(t['count'] for t in families.values()),'mapped_forms':forms,'unmapped':unmapped,'output':str(a.out)}))

if __name__=='__main__':main()
