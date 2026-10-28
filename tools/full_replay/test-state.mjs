// Meaningful contracts: reverse seeking transforms, repeated nested instances, arena coordinates, cycles.
import fs from 'node:fs';import assert from 'node:assert/strict';
import {createActorState} from './src/actor-state.js';import {flattenSceneGraph} from './src/scene-graph.js';
const input=process.argv[2];if(!input)throw Error('Pass private offline input directory');
const get=(f,n)=>JSON.parse(fs.readFileSync(input+'/'+f,'utf8').replace('window.'+n+'=','').replace(/;\s*$/,''));const r=get('record.js','TOP_RECORD'),m=get('manifest.js','TOP_MANIFEST');const raw=JSON.stringify([r,m]);const s=createActorState(r,m);
for(const t of [200000,140000,221000,240000,165000,200000,255000]){
 const expected=t<157790||t>=229000?'female':'male';assert.equal(s.formAt('19:0',t),expected);
 const expected20=t<157790||t>=254000?'male':'female';assert.equal(s.formAt('20:0',t),expected20);
}
assert.equal(s.transitionAt('19:0',158000).from,'female');assert.equal(s.transitionAt('19:0',158000).to,'male');assert.equal(s.transitionAt('19:0',227000).from,'male');assert.equal(s.formAt('19:0',227000),'male');assert.equal(s.formAt('19:0',229000),'female');assert.equal(JSON.stringify([r,m]),raw);
if(m.action_animation_bindings.male['3210']){assert.equal(s.heldPoseAt('19:0',208000)?.form,'male');assert.equal(s.heldPoseAt('19:0',226652)?.actor,'19:0');assert.equal(s.heldPoseAt('19:0',226653),null);assert.equal(s.heldPoseAt('19:0',200000),null);}
const tr=(x=0,y=0,z=0)=>({Translation:{X:x,Y:y,Z:z},Rotation:{X:0,Y:0,Z:0},Scale:{X:1,Y:1,Z:1}});
const obj=(id,type,path,x,y,z)=>({InstanceId:id,AssetType:type,Transform:tr(x,y,z),Object:{AssetPath:path}});
const layer=(Name,InstanceObjects)=>({Name,InstanceObjects});
const scenes={root:{properties:{Layers:[layer('p1',[obj(1,'SharedGroup','child',100,0,100),obj(2,'SharedGroup','child',110,0,100)]),layer('cut_op',[obj(3,'BG','cut',100,0,100)])]}},child:{properties:{LayerGroups:[{Layers:[layer('child',[obj(4,'BG','mesh',1,2,3),obj(5,'SharedGroup','root',0,0,0)])]}]}}};
const x=flattenSceneGraph(scenes,'root',['p1','cut_op']);const meshes=x.nodes.filter(n=>n.assetType==='BG');assert.equal(meshes.length,2);assert.deepEqual(meshes.map(n=>n.worldMatrix.slice(12,15)),[[1,2,3],[11,2,3]]);assert.equal(new Set(x.nodes.map(n=>n.key)).size,x.nodes.length);assert.equal(x.diagnostics.filter(d=>d.code==='cycle').length,2);assert(x.diagnostics.some(d=>d.code==='excluded-cut-layer'));assert(!x.nodes.some(n=>n.path==='cut'));
console.log(JSON.stringify({status:'PASS',actual_record_seeks:7,transform_boundaries:4,repeat_parent_transform_and_cycle:true,full_fidelity:false}));
