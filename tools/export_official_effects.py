#!/usr/bin/env python3
"""Preserve original local AVFX and referenced images for effect reconstruction.

This exports source data, not a claim to render the original shader/particle graph.
Only raw local SqPack reads are used. Game assets are not distributed with source.
"""
import argparse,hashlib,io,json,re
from pathlib import Path
import export_official_models as models
EFFECTS={
 'meteor':{'npc':15726,'model_chara':3417,'model':213,'base':1,'vfx':1,'body_hidden':True},
 'comet':{'npc':15727,'model_chara':819,'model':213,'base':1,'vfx':2,'body_hidden':True},
 'fist_b6':{'npc':15710,'model_chara':2375,'model':114,'base':6,'vfx':1,'body_hidden':False},
}
def main():
 p=argparse.ArgumentParser(description=__doc__)
 for name in ['game-dir','lumina-dir','textools-dir','output']:p.add_argument('--'+name,type=Path,required=True)
 p.add_argument('--pythonnet-dir',type=Path);p.add_argument('--forms',nargs='+',choices=list(EFFECTS),default=list(EFFECTS));a=p.parse_args();realm=models.initialize(a)
 from Lumina.Data import FileResource
 from Lumina.Data.Files import TexFile
 from PIL import Image
 manifest={'schema':1,'scope':'original AVFX graph and referenced images; rendering reconstruction pending','effects':{}}
 for form in a.forms:
  meta=EFFECTS[form];mid,bid,vfx=meta['model'],meta['base'],meta['vfx'];path=f'chara/monster/m{mid:04d}/obj/body/b{bid:04d}/vfx/eff/vm{vfx:04d}.avfx';resource=realm.GetFile[FileResource](path)
  if resource is None:raise RuntimeError('Missing original effect: '+path)
  raw=bytes(resource.Data);folder=a.output/form;folder.mkdir(exist_ok=True,parents=True);(folder/'effect.avfx').write_bytes(raw)
  entry=dict(meta,source_path=path,sha256=hashlib.sha256(raw).hexdigest(),textures=[],rendering_complete=False)
  for reference in sorted(set(re.findall(rb'[a-zA-Z0-9_/.-]{8,}\.(?:atex|tex)',raw))):
   texture_path=reference.decode('ascii');tex=realm.GetFile[TexFile](texture_path)
   if tex is None:raise RuntimeError('Missing effect texture: '+texture_path)
   data=bytes(tex.ImageData);im=Image.frombytes('RGBA',(int(tex.Header.Width),int(tex.Header.Height)),data,'raw','BGRA');target=folder/(Path(texture_path).stem+'.png');im.save(target)
   entry['textures'].append({'source':texture_path,'file':str(target.relative_to(a.output)),'width':im.width,'height':im.height,'raw_sha256':hashlib.sha256(bytes(tex.Data)).hexdigest(),'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
  manifest['effects'][form]=entry;print(form,'original AVFX',len(raw),'textures',len(entry['textures']),flush=True)
  (a.output/'effects-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 realm.Dispose()
if __name__=='__main__':main()
