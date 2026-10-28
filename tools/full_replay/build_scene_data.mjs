// SPDX-License-Identifier: MIT
// Build private scene delivery data from local-game extraction. No network or game launch.
import {readFile,writeFile,cp,mkdir,stat} from 'node:fs/promises';
import {resolve,join,basename} from 'node:path';import {createHash} from 'node:crypto';import {gzipSync} from 'node:zlib';
import {flattenSceneGraph} from './src/scene-graph.js';
const args=process.argv.slice(2),arg=k=>args[args.indexOf(k)+1];
for(const k of ['--scenes','--models','--data','--out'])if(!args.includes(k))throw Error('Usage: node build_scene_data.mjs --scenes SCENE_JSON --models EXPORTED_MODEL_DIRECTORY --data PRIVATE_DATA --out NEW_DIRECTORY');
const out=resolve(arg('--out')),data=resolve(arg('--data')),models=resolve(arg('--models'));
try{await stat(out);throw Error('Output must be fresh');}catch(e){if(e.code!=='ENOENT')throw e;}
const sha=b=>createHash('sha256').update(b).digest('hex');
const scenes=JSON.parse(await readFile(arg('--scenes'),'utf8')),proof=JSON.parse(await readFile(join(models,'export-proof.json'),'utf8'));
const manifest=JSON.parse((await readFile(join(data,'manifest.js'),'utf8')).replace(/^window.TOP_MANIFEST=/,'').replace(/;\s*$/,''));
const layers={1:['p1_boss','p1_enkei','p1_light'],2:['p1_boss','p2_boss','p2_enkei','p1_light','p2_light'],3:['p3_boss','p3_enkei'],4:['p4_boss','p4_enkei'],5:['p5_boss','p5_enkei'],6:['p7_boss','p7_enkei','p7_light']};
const flat=Object.fromEntries(Object.entries(layers).map(([id,names])=>[id,flattenSceneGraph(scenes,'bg/ex2/05_zon_z3/ome/z3oz/level/bg.lgb',names)]));
// Only background-layer meshes. Never activate every mechanic/cinematic/shared-group candidate.
const selected=Object.fromEntries(Object.entries(flat).map(([id,g])=>[id,g.nodes.filter(n=>n.assetType==='BG'&&n.source.rootLayer.includes('enkei'))]));
await cp(data,out,{recursive:true,dereference:true,force:false,errorOnExist:true});await mkdir(join(out,'assets'),{recursive:true});
const paths=new Set(Object.values(selected).flat().map(n=>n.path));
for(const path of paths){const key=basename(path,'.mdl'),row=proof.models[key];if(!row||row.source_path!==path)throw Error('Missing/ambiguous exported model: '+path);
 const b=await readFile(join(models,row.file));if(sha(b)!==row.sha256)throw Error('Model hash mismatch '+key);const id='scene_'+key,z=gzipSync(b,{mtime:0});
 await writeFile(join(out,'assets',id+'.js'),'window.TOP_ASSETS['+JSON.stringify(id)+']='+JSON.stringify(z.toString('base64'))+';');
 manifest.assets[id]={file:'assets/'+id+'.js',bytes:b.length,compressed_bytes:z.length,sha256:sha(b),kind:'glb',source_path:path,source_sha256:row.source_sha256,rendering_complete:false};
}
const result={phases:{},limitations:['Static phase-layer reconstruction, not proven original activation timing','Shared-group timelines and original BG shader, lights, fog, material animation unresolved','Source IsVisible flags are not runtime activation evidence; existing verified floors also report zero'],source:'Territory1122 original LVB/LGB/SGB; raw source hashes in extraction proof'};
for(const [id,nodes] of Object.entries(selected))result.phases[id]={nodes:nodes.map(n=>({key:n.key,asset:'scene_'+basename(n.path,'.mdl'),path:n.path,worldMatrix:n.worldMatrix,source:n.source})),unresolved_dynamic_nodes:flat[id].nodes.filter(n=>n.assetType!=='BG').length,lights_metadata:flat[id].nodes.filter(n=>n.assetType==='LayLight'),basis:'phase-name layer selection; static preview, not exact activation proof'};
await writeFile(join(out,'manifest.js'),'window.TOP_MANIFEST='+JSON.stringify(manifest)+';');await writeFile(join(out,'scene-data.js'),'window.TOP_SCENES='+JSON.stringify(result)+';');
console.log(JSON.stringify({models:paths.size,nodes:Object.fromEntries(Object.entries(selected).map(([k,v])=>[k,v.length])),complete:false}));
