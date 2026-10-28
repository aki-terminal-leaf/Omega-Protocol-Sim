import * as THREE from 'three';
import {applyBackgroundMaterials} from './bg-materials.js';
import {createActorState} from './actor-state.js';
import {createAudioDirector} from './audio-sync.js';
import {AvfxRuntime,axes as avfxAxes} from './avfx-runtime.js';
import {installMaterials} from './avfx-materials.js';
installMaterials(AvfxRuntime);
import {installPolylines} from './avfx-polyline.js';
installPolylines(AvfxRuntime);
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
import {clone as cloneRig} from 'three/addons/utils/SkeletonUtils.js';
const W=window.TOP_WEAPONS;
const R=window.TOP_RECORD,M=window.TOP_MANIFEST,$=id=>document.getElementById(id);
const colors=[0x77caff,0x9faafa,0x7addad,0xd8b2fa,0xf5a4ba,0xf0cd86,0x77ddd9,0xf2a775];
const party=Object.values(R.actors).filter(a=>a.player),isEnemy=k=>k&&!R.actors[k]?.friendly;
const eventList=R.relevant_event_indexes.map(i=>R.events[i]);
const casts=R.events.filter(e=>e.type==='begincast'&&isEnemy(e.s)).map(e=>{
 const hit=R.events.find(f=>f.t>=e.t&&f.t<e.t+30000&&f.type==='cast'&&f.s===e.s&&f.a===e.a);
 return {...e,end:hit?.t??e.t+(e.castDuration||e.duration||2000)};
});
const deaths=R.events.filter(e=>e.type==='death');
const weaponFamily=a=>[31525,31526].includes(a)?'male':[31530,31533].includes(a)?'female':null;
const weaponForm=(a,base)=>weaponFamily(a)+(base?.endsWith('_p5')?'_p5':'');
const actorState=createActorState(R,M);
const actionAnimations=new Map();
for(const e of R.events){if(e.type!=='cast')continue;const base=M.bindings[e.s]?.form,form=W.actions[e.a]?weaponForm(e.a,base):(actorState.formAt(e.s,e.t)||base),row=M.action_rows?.[e.a],binding=M.action_animation_bindings?.[form]?.[row?.end];if(!binding||!binding.playback_eligible)continue;
 const start=e.t+binding.node_time/30*1000,duration=binding.flags===1?binding.node_duration/30:binding.duration_s;
 if(!(duration>0&&duration<=60))continue;const list=actionAnimations.get(e.s)||[];list.push({event:e,binding,form,start,end:start+duration*1000});actionAnimations.set(e.s,list);}
for(const list of actionAnimations.values())list.sort((a,b)=>a.start-b.start);
function currentAction(k,form){const list=actionAnimations.get(k)||[],i=upper(list,time,x=>x.start)-1;if(i<0)return null;const c=list[i];return c.form===form&&time<c.end?c:null;}
function motionAt(k,a,p){const transform=actorState.transitionAt(k,time);if(transform&&transform.from===a.form){const b=transform.binding,age=(time-transform.start)/1000;return {clip:b.clip,seconds:b.flags===1?(b.animation_start+(b.animation_end-b.animation_start)*age/(b.node_duration/30))/30:age,once:true,basis:'original transform PAP; clip-end swap approximation'};}const hold=actorState.heldPoseAt(k,time);if(hold&&hold.form===a.form)return {clip:hold.binding.clip,seconds:(time-hold.start)/1000,once:true,basis:hold.basis};const end=currentAction(k,a.form),cast=casts.find(c=>c.s===k&&c.t<=time&&time<c.end),row=cast&&M.action_rows?.[cast.a],start=row&&M.cast_start_clips?.[row.start];
 if(cast&&start&&a.actions.has(start.path)&&(!end||cast.t>end.start))return {clip:start.path,seconds:(time-cast.t)/1000,once:true,basis:'source cast-start; last pose held, original cast loop unresolved'};
 if(end){const b=end.binding,age=(time-end.start)/1000;return {clip:b.clip,seconds:b.flags===1?(b.animation_start+(b.animation_end-b.animation_start)*age/(b.node_duration/30))/30:age,once:true,basis:'source PAP + C010; FFLogs cast anchor / reconstructed scheduler'};}
 return {clip:R.actors[k]?.player?(p.moving?'cbnm_02f_lp0':'cbnm_id0'):'cbbm_id0',seconds:time/1000,once:false,basis:'resident idle/movement preview'};
}

const fmt=raw=>{const t=Math.max(0,Math.round(raw));return `${String(Math.floor(t/60000)).padStart(2,'0')}:${(t%60000/1000).toFixed(3).padStart(6,'0')}`;};
const name=a=>R.abilities[a]?.name||String(a),esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function upper(a,t,fn=x=>x[0]){let lo=0,hi=a.length;while(lo<hi){let m=(lo+hi)>>1;if(fn(a[m])<=t)lo=m+1;else hi=m;}return lo;}
function phaseAt(t){return R.phase_markers.reduce((a,b)=>b.t<=t?b:a,R.phase_markers[0]);}
function position(k,t,smooth=false){const a=R.tracks[k];if(!a?.length)return null;const i=upper(a,t)-1;if(i<0)return null;const s=a[i],n=a[i+1],age=t-s[0];let x=s[1],z=s[2],moving=false;
 if(n&&n[0]>s[0]&&n[0]-s[0]<=1500&&Math.hypot(n[1]-x,n[2]-z)<=12*(n[0]-s[0])/1000){const f=age/(n[0]-s[0]);if(smooth){x+=(n[1]-x)*f;z+=(n[2]-z)*f;}moving=Math.hypot(n[1]-s[1],n[2]-s[2])>.15;}
 return {x,z,heading:s[3],age,moving,sample:s[0]};}
// FFLogs facing uses centiradians in this source. Three cardinal Optical samples
// independently fit this axis transform; actual bone-front calibration remains separate.
const yaw=h=>h==null?0:Math.PI/2-h/100;
let time=0,playing=false,phase=-1,desiredPhase=-1,phasePromise=null,ready=false,revision=0,loadingCount=0,lastFrame=performance.now(),lastUi=-1;
const renderer=new THREE.WebGLRenderer({canvas:$('view'),antialias:true,preserveDrawingBuffer:true});
renderer.setPixelRatio(Math.min(devicePixelRatio,1.5));renderer.outputColorSpace=THREE.SRGBColorSpace;renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.15;
const scene=new THREE.Scene();scene.background=new THREE.Color(0x090f1c);scene.fog=new THREE.Fog(0x090f1c,140,350);
const camera=new THREE.PerspectiveCamera(43,1,.1,1200),controls=new OrbitControls(camera,renderer.domElement);controls.maxPolarAngle=Math.PI/2-.04;controls.minDistance=18;controls.maxDistance=180;controls.target.set(0,2,0);controls.enableDamping=false;
function resetCamera(){camera.position.set(28,36,45);controls.target.set(0,2,0);controls.update();render();}
scene.add(new THREE.HemisphereLight(0xd9eaff,0x495572,2.4));const light=new THREE.DirectionalLight(0xfff3db,3.2);light.position.set(20,45,30);scene.add(light);
const arenaRoot=new THREE.Group(),actorRoot=new THREE.Group(),fxRoot=new THREE.Group();scene.add(arenaRoot,actorRoot,fxRoot);
const backgroundDiagnostics=new Map();
const cache=new Map(),promises=new Map(),actors=new Map(),floors=new Map(),textureCache=new Map();
async function loadAsset(id){if(cache.has(id))return cache.get(id);if(promises.has(id))return promises.get(id);const spec=M.assets[id];if(!spec)throw Error('Missing declared asset: '+id);
 const promise=(async()=>{loadingCount++;$('loadtext').textContent='載入 '+id;try{
 if(!window.TOP_ASSETS[id])await new Promise((resolve,reject)=>{const script=document.createElement('script');script.src=spec.file;script.onload=resolve;script.onerror=()=>reject(Error('無法載入 '+spec.file));document.head.append(script);});
 const raw=Uint8Array.from(atob(window.TOP_ASSETS[id]),c=>c.charCodeAt(0));delete window.TOP_ASSETS[id];
 const buffer=await new Response(new Blob([raw]).stream().pipeThrough(new DecompressionStream('gzip'))).arrayBuffer();
 if(buffer.byteLength!==spec.bytes)throw Error('Asset size mismatch '+id);
 let data;if(spec.kind==='json'){data=JSON.parse(new TextDecoder().decode(buffer));}else if(spec.kind==='encoded_audio'){data=buffer;}else if(spec.kind==='png'){
  const url=URL.createObjectURL(new Blob([buffer],{type:'image/png'}));try{data=await new THREE.TextureLoader().loadAsync(url);data.colorSpace=THREE.SRGBColorSpace;data.wrapS=data.wrapT=THREE.RepeatWrapping;}finally{URL.revokeObjectURL(url);}
 }else{data=await new GLTFLoader().parseAsync(buffer,'');data.scene.traverse(o=>{if(o.isMesh){o.frustumCulled=false;if(o.material){o.material.side=THREE.DoubleSide;o.material.needsUpdate=true;}}});}
 if(data?.scene)backgroundDiagnostics.set(id,applyBackgroundMaterials(data.scene,{background:id.startsWith('scene_')}));
 if(id==='female'||id==='female_p5'){
 const c=W.legClip,tracks=[];for(const b of c.bones){if(!data.scene.getObjectByName(b.name))throw Error('Missing leg animation bone '+b.name);tracks.push(new THREE.VectorKeyframeTrack(b.name+'.position',c.times,b.translation),new THREE.QuaternionKeyframeTrack(b.name+'.quaternion',c.times,b.rotation),new THREE.VectorKeyframeTrack(b.name+'.scale',c.times,b.scale));}
 data.animations.push(new THREE.AnimationClip(c.name,c.duration,tracks));
 }
 cache.set(id,data);return data;
 }finally{loadingCount--;}})().catch(e=>{promises.delete(id);throw e;});promises.set(id,promise);return promise;}
async function loadSerial(ids){for(const id of [...new Set(ids)])await loadAsset(id);}
function textSprite(text,color='#eaf4ff',scale=3){const c=document.createElement('canvas');c.width=256;c.height=64;const cx=c.getContext('2d');cx.font='bold 27px system-ui';cx.textAlign='center';cx.strokeStyle='#07101b';cx.lineWidth=7;cx.strokeText(text,128,43);cx.fillStyle=color;cx.fillText(text,128,43);const tex=new THREE.CanvasTexture(c),sp=new THREE.Sprite(new THREE.SpriteMaterial({map:tex,depthTest:false}));sp.scale.set(scale,scale/4,1);return sp;}
for(const [txt,x,z] of [['N',0,-23],['E',23,0],['S',0,23],['W',-23,0]]){const sp=textSprite(txt,'#b6cde8',2.2);sp.position.set(x,.5,z);sp.visible=false;scene.add(sp);}
function addRig(k,form,scale){if(actors.has(k))return;const data=cache.get(form),root=new THREE.Group(),mesh=cloneRig(data.scene);root.add(mesh);mesh.scale.setScalar(scale);actorRoot.add(root);const mixer=new THREE.AnimationMixer(mesh),actions=new Map();
 for(const clip of data.animations){const action=mixer.clipAction(clip);action.setLoop(THREE.LoopRepeat,Infinity);actions.set(clip.name,action);}
 const a=R.actors[k],color=colors[party.findIndex(x=>x.id===k)]||0xf1c58c;const label=textSprite(a?.player?a.label:(a?.label||form),a?.player?'#'+color.toString(16).padStart(6,'0'):'#e5ceab',a?.player?2.4:4);label.position.y=a?.player?2.7:6;root.add(label);
 if(a?.player){const ring=new THREE.Mesh(new THREE.RingGeometry(.45,.60,32),new THREE.MeshBasicMaterial({color,side:THREE.DoubleSide,transparent:true,opacity:.8}));ring.rotation.x=-Math.PI/2;ring.position.y=.06;root.add(ring);}
 actors.set(k,{root,mesh,mixer,actions,label,form,clip:null,scale,baseForm:form,variants:new Map()});
}
function selectActorForm(a,form){
 if(a.form===form)return;if(!cache.has(form))throw Error('Missing form '+form);
 a.variants.set(a.form,{mesh:a.mesh,mixer:a.mixer,actions:a.actions,clip:a.clip});a.mesh.visible=false;
 let v=a.variants.get(form);if(!v){const mesh=cloneRig(cache.get(form).scene);mesh.scale.setScalar(a.scale);a.root.add(mesh);const mixer=new THREE.AnimationMixer(mesh),actions=new Map();for(const clip of cache.get(form).animations){const x=mixer.clipAction(clip);x.setLoop(THREE.LoopRepeat,Infinity);actions.set(clip.name,x);}v={mesh,mixer,actions,clip:null};a.variants.set(form,v);}
 Object.assign(a,v,{form});a.mesh.visible=true;const prior=a.label;a.label=textSprite(form.startsWith('female')?'Omega-F':'Omega-M','#e5ceab',4);a.label.position.y=6;a.root.add(a.label);prior.removeFromParent();prior.material.map?.dispose();prior.material.dispose();
}
function activeWeapon(k){const c=weaponCues.find(c=>c.source===k&&c.cast<=time&&time<c.end);if(c)return c;const pre=casts.find(c=>W.actions[c.a]&&c.s===k&&c.t<=time&&time<c.end);return pre?{ability:pre.a,source:k,cast:pre.end}:null;}
function formAt(k,a){const c=!actorState.hasTransform(k)&&activeWeapon(k);return c?weaponForm(c.ability,a.baseForm):(actorState.formAt(k,time)||a.baseForm);}
async function ensurePhase(p){const rev=++revision;desiredPhase=p.id;ready=false;fullAudio.sync();$('loading').classList.remove('hidden');$('play').disabled=true;
 try{const layers=M.floor_layers[p.id],placements=M.placements.filter(x=>layers.includes(x.layer));
 const sceneNodes=window.TOP_SCENES?.phases?.[p.id]?.nodes||[];
 const needed=Object.entries(M.bindings).filter(([k,b])=>R.events.some(e=>e.phase===p.id&&(e.s===k||e.d===k))).map(([k,b])=>b.form);
 await loadSerial([...sceneNodes.map(n=>n.asset),...(window.TOP_FULL.phase_assets[p.id]||[]),'player',...([2,5].includes(p.id)?['male','female','male_p5','female_p5',...Object.values(W.textures)]:[]),...needed,...placements.map(x=>x.path.split('/').at(-1).replace('.mdl','')),'p3_loading_ring','p3_loading_volume','p3_loading_left_ring','p3_loading_left_volume','p3_impact_ring','p3_impact_sphere','p3_circuit','p3_electric','p3_glow','p3_impact']);
 if(rev!==revision)return;
 if(!floors.has(p.id)){const group=new THREE.Group();for(const place of placements){const id=place.path.split('/').at(-1).replace('.mdl','');const g=cache.get(id).scene.clone(true);g.position.set(place.translation[0]-100,place.translation[1],place.translation[2]-100);g.rotation.set(...place.rotation,'ZYX');g.scale.set(...place.scale);group.add(g);}const backdrop=new THREE.Group();backdrop.name='source-background';for(const n of sceneNodes){const g=cache.get(n.asset).scene.clone(true);g.matrixAutoUpdate=false;g.matrix.fromArray(n.worldMatrix);g.userData.sourceNode=n.key;backdrop.add(g);}group.add(backdrop);arenaRoot.add(group);floors.set(p.id,group);}
 for(const [id,g] of floors)g.visible=id===p.id;
 for(const a of party)addRig(a.id,'player',.55);
 for(const [k,b] of Object.entries(M.bindings))if(cache.has(b.form))addRig(k,b.form,b.scale);
 phase=p.id;ready=true;lastFrame=performance.now();$('loading').classList.add('hidden');$('play').disabled=false;$('retry').hidden=true;window.replayError=null;render();
 }catch(e){if(rev!==revision)return;$('retry').hidden=false;$('loadtext').textContent='載入失敗：'+e.message;window.replayError=e.message;throw e;}}
function animate(a,clip,seconds,once=false){let action=a.actions.get(clip);if(!action){clip=[...a.actions.keys()].find(k=>k.endsWith(a.form==='player'?'cbnm_id0':'cbbm_id0'));action=a.actions.get(clip);}if(!action)return;
 if(a.clip!==clip){a.mixer.stopAllAction();action.reset().play();a.clip=clip;}
 action.enabled=true;action.setEffectiveWeight(1);action.time=once?Math.min(seconds,action.getClip().duration-.0001):((seconds%action.getClip().duration)+action.getClip().duration)%action.getClip().duration;a.mixer.update(0);
}
function stance(a,k){if(!a.form.startsWith('male')&&!a.form.startsWith('female'))return;const weapon=activeWeapon(k),nearby=weapon?{a:weapon.ability}:casts.find(c=>c.s===k&&c.t<=time&&time<c.end+700);let s=actorState.heldPoseAt(k,time)?'SHIELD':'NEUTRAL';if(nearby){if([31525].includes(nearby.a))s='SHIELD';if([31526,31527,31528].includes(nearby.a))s='SWORD';if([31532,31530].includes(nearby.a))s='LEGS';if([31533,31531].includes(nearby.a))s='STAFF';}
 a.mesh.traverse(o=>{if(!o.isMesh)return;if(o.name.includes('atr_parts_a'))o.visible=s===(a.form.startsWith('male')?'SHIELD':'LEGS');else if(o.name.includes('atr_parts_b'))o.visible=a.form.startsWith('female')?s!=='LEGS':s!=='NEUTRAL'&&s!=='SHIELD';else if(o.name.includes('atr_bv_c'))o.visible=s!=='LEGS';});}
const fxObjects=new Map();
function disposeFx(group){group.traverse(o=>{if(o.userData.ownedGeometry)o.geometry?.dispose();if(o.material)o.material.dispose();});group.removeFromParent();}
function effectMaterial(color,texture=null,opacity=.65){return new THREE.MeshBasicMaterial({color,map:texture,alphaMap:texture,transparent:true,opacity,blending:THREE.AdditiveBlending,depthWrite:false,side:THREE.DoubleSide});}
function ring(parent,x,z,r,color,width=.3){const m=new THREE.Mesh(new THREE.RingGeometry(Math.max(.02,r-width),r,64),effectMaterial(color,null,.7));m.userData.ownedGeometry=true;m.rotation.x=-Math.PI/2;m.position.set(x,.12,z);parent.add(m);return m;}
function sourceMesh(id,texture,color){const g=cache.get(id).scene.clone(true);g.traverse(o=>{if(o.isMesh)o.material=effectMaterial(color,cache.get(texture),.55);});return g;}
function beam(parent,from,to,color,width=.25){const v=new THREE.Vector3().subVectors(to,from);if(v.length()<.01)return;const m=new THREE.Mesh(new THREE.CylinderGeometry(width,width*.7,v.length(),12,1,true),effectMaterial(color,cache.get('p3_electric'),.7));m.userData.ownedGeometry=true;m.position.copy(from).add(to).multiplyScalar(.5);m.quaternion.setFromUnitVectors(new THREE.Vector3(0,1,0),v.normalize());parent.add(m);}
// Effect geometry is an explicit reconstruction. Only this allowlist is rendered;
// unsupported abilities remain events, rather than receiving invented generic visuals.
const config={
 31521:{kind:'optical',duration:1300,color:0x8acbff},31596:{kind:'monitor',duration:850,color:0x62b6ff},31597:{kind:'monitor',duration:850,color:0x62b6ff},31638:{kind:'monitor',duration:850,color:0x62b6ff},31639:{kind:'monitor',duration:850,color:0x62b6ff},

 31500:{kind:'target',radius:5,duration:750,color:0xff925f},31496:{kind:'target',radius:3,duration:750,color:0x71baff},
 31503:{kind:'beam',duration:850,color:0xff6e8f},31504:{kind:'beam',duration:850,color:0xff6e8f},31505:{kind:'beam',duration:850,color:0xff6e8f},
 31614:{kind:'target',radius:6,duration:900,color:0x72c9ff},31615:{kind:'target',radius:6,duration:900,color:0x72c9ff},31618:{kind:'target',radius:6,duration:900,color:0x72c9ff},31619:{kind:'target',radius:6,duration:900,color:0x72c9ff},31620:{kind:'target',radius:6,duration:900,color:0x72c9ff},
 31661:{kind:'beam',duration:950,color:0x79dcff},31663:{kind:'beam',duration:950,color:0x79dcff},31662:{kind:'beam',duration:950,color:0x79dcff},31658:{kind:'beam',duration:950,color:0x79dcff},31659:{kind:'beam',duration:950,color:0x79dcff},
 31625:{kind:'target',radius:6,duration:900,color:0x8be1ff},31626:{kind:'target',radius:6,duration:900,color:0x8be1ff},33040:{kind:'target',radius:6,duration:900,color:0xf0b1ff},33041:{kind:'target',radius:6,duration:900,color:0xf0b1ff},
 31588:{kind:'raidwide',radius:20,duration:1100,color:0x8ab6ff},31611:{kind:'raidwide',radius:20,duration:1600,color:0x669eff},31649:{kind:'raidwide',radius:20,duration:1500,color:0xb0d7ff},31670:{kind:'raidwide',radius:20,duration:1700,color:0xdbadff},
 31482:{kind:'target',radius:3,duration:1000,color:0xffb75e},31667:{kind:'target',radius:8,duration:1200,color:0xffa564},31668:{kind:'target',radius:8,duration:1200,color:0xffa564}
};
const fxCues=[];const seen=new Set();
// Cast anchors win. Result-only attacks use calculateddamage, never additionally damage.
for(const c of R.cues){if(!config[c.ability]||!['cast','calculateddamage'].includes(c.type))continue;if(c.type==='calculateddamage'&&R.cues.some(x=>x.type==='cast'&&x.source===c.source&&x.ability===c.ability&&Math.abs(x.t-c.t)<100))continue;const key=[c.t,c.source,c.ability,c.packetID].join('|');if(seen.has(key))continue;seen.add(key);const linked=R.cues.filter(x=>x.source===c.source&&x.ability===c.ability&&x.packetID===c.packetID&&Math.abs(x.t-c.t)<100&&['cast','calculateddamage'].includes(x.type));fxCues.push({...c,targets:[...new Set(linked.flatMap(x=>x.targets))],event_indexes:[...new Set(linked.flatMap(x=>x.event_indexes))],key,config:config[c.ability]});}
fxCues.sort((a,b)=>a.t-b.t);
const loadingStatuses=[],openStatuses=new Map();
for(const e of R.events){if(![1003452,1003453].includes(e.a))continue;const key=e.d+'|'+e.a;
 if(['applydebuff','refreshdebuff'].includes(e.type)){if(!openStatuses.has(key))openStatuses.set(key,{key:'status|'+e.t+'|'+e.d,start:e.t,end:R.duration_ms,actor:e.d,a:e.a,end_basis:'display bounded by record end; removal missing'});}
 else if(e.type==='removedebuff'&&openStatuses.has(key)){const o=openStatuses.get(key);o.end=e.t;o.end_basis='recorded removal';loadingStatuses.push(o);openStatuses.delete(key);}
}loadingStatuses.push(...openStatuses.values());
const skippedEffects=new Set();

function cuePosition(c,side,k){const e=c.event_indexes.map(i=>R.events[i]).find(e=>e[side==='target'?'d':'s']===k&&e[side+'_pos']),raw=e?.[side+'_pos'];if(raw)return {x:raw[0],z:raw[1],heading:raw[2],age:0};const p=position(k,c.t,false);return p&&p.age<=10000?p:null;}
function createFx(c){const cf=c.config,g=new THREE.Group(),s=cuePosition(c,'source',c.source),targets=c.targets.map(k=>({k,p:cuePosition(c,'target',k)})).filter(x=>x.p);g.userData.label=name(c.ability);g.userData.cue=c;
 const source=s?new THREE.Vector3(s.x,3,s.z):null;
 if(cf.kind==='optical'&&source){const d=new THREE.Vector3(-s.x,0,-s.z).normalize();beam(g,source,new THREE.Vector3(source.x,1,source.z).addScaledVector(d,90),cf.color,1.2);}
 else if(['beam','monitor'].includes(cf.kind)&&source){for(const {p} of targets){beam(g,source,new THREE.Vector3(p.x,1,p.z),cf.color,cf.kind==='monitor'?.22:.6);if(cf.kind==='monitor'){const mesh=sourceMesh('p3_impact_ring','p3_impact',cf.color);mesh.position.set(p.x,.12,p.z);g.add(mesh);}}}
 else if(['circle','donut'].includes(cf.kind)&&s){ring(g,s.x,s.z,cf.radius,cf.color,cf.kind==='donut'?cf.radius-cf.inner:cf.radius);}
 else if(cf.kind==='raidwide'){ring(g,0,0,20,cf.color,1);}
 else if(cf.kind==='target'){for(const {p} of targets)ring(g,p.x,p.z,cf.radius,cf.color,.5);}
 if(!g.children.length){skippedEffects.add(c.key);return null;}fxRoot.add(g);return g;}
function updateFx(){skippedEffects.clear();const desired=new Map();if($('effects').checked){for(const c of fxCues){if(c.t>time)break;if(time<c.t+c.config.duration&&!fullCues.some(f=>f.ability===c.ability&&f.source===c.source&&f.start<=time&&time<f.end&&fullPlayers.has(f.key)&&!fullSkipped.has(f.key)&&(fullPlayers.get(f.key).player._draws.size+(fullPlayers.get(f.key).player._polyDraws?.size||0)>0)))desired.set(c.key,c);}for(const s of loadingStatuses)if(time>=s.start&&time<s.end)desired.set(s.key,s);}
 for(const [key,obj] of fxObjects)if(!desired.has(key)){disposeFx(obj);fxObjects.delete(key);}
 for(const [key,c] of desired){let g=fxObjects.get(key);if(!g){if(c.config){g=createFx(c);if(!g)continue;}else{g=new THREE.Group();const m=sourceMesh(c.a===1003453?'p3_loading_left_volume':'p3_loading_volume','p3_circuit',0x66bbff);m.rotation.x=-Math.PI/2;g.add(m);const r=sourceMesh(c.a===1003453?'p3_loading_left_ring':'p3_loading_ring','p3_glow',0x8acbff);r.rotation.x=-Math.PI/2;g.add(r);fxRoot.add(g);g.userData.label='Oversampled Loading（原版網格／重建附著）';}fxObjects.set(key,g);}
 if(c.config){const f=(time-c.t)/c.config.duration;g.traverse(o=>{if(o.material)o.material.opacity=Math.max(0,.65*(1-f));});if(c.config.kind==='raidwide')g.scale.setScalar(.15+.85*f);}
 else{const p=position(c.actor,time,$('smooth').checked);g.visible=!!p;if(p){g.position.set(p.x,1.4,p.z);g.rotation.y=yaw(p.heading)+(c.a===1003453?-Math.PI/2:Math.PI/2);g.scale.setScalar(.55);}}
 }
}
const weaponPlayers=new Map(),weaponSkipped=new Set(),weaponCues=[];
for(const e of R.events){if(e.type!=='cast'||!W.actions[e.a])continue;const action=W.actions[e.a];for(const n of action.nodes){const key=`${e.t}|${e.s}|${e.a}|${n.id}`;if(weaponCues.some(c=>c.key===key))continue;weaponCues.push({key,source:e.s,ability:e.a,cast:e.t,start:e.t+n.time/30*1000,end:e.t+n.time/30*1000+6000,node:n});}}
weaponCues.sort((a,b)=>a.start-b.start);
function weaponState(){return [...weaponPlayers].map(([key,v])=>({key,ability:v.cue.ability,source:v.cue.source,path:v.cue.node.path,start:v.cue.start,age:(time-v.cue.start)*.03,particles:v.player.lastParticles.length,bindings:[...v.player.binders].map(([i,g])=>({index:i,visible:g.visible,matrix:g.matrix.elements.slice()})),diagnostics:[...v.player.diagnostics],signature:v.player.lastParticles.map(p=>[p.key,p.index,p.kind,p.age,...(p.transform?.elements||[])]),position:v.player.root.position.toArray()}));}
function updateWeaponFx(){
 const desired=new Map();weaponSkipped.clear();if($('effects').checked)for(const c of weaponCues){if(c.start>time)break;if(time<c.end)desired.set(c.key,c);}
 for(const [key,v] of weaponPlayers)if(!desired.has(key)){v.player.dispose();v.player.root.removeFromParent();weaponPlayers.delete(key);}
 for(const [key,c] of desired){let v=weaponPlayers.get(key);if(!v){const p=position(c.source,c.cast,false);if(!p||p.age>10000){weaponSkipped.add(key);continue;}const textures=Object.fromEntries(Object.entries(W.textures).map(([path,id])=>[path,cache.get(id)]));if(Object.values(textures).some(x=>!x)){weaponSkipped.add(key);continue;}
 const player=new AvfxRuntime(W.packs[c.node.path],textures,Array.from(key).reduce((h,x)=>Math.imul(h^x.charCodeAt(0),16777619)>>>0,2166136261));player.root.position.set(p.x,0,p.z);player.root.rotation.y=yaw(p.heading);player.root.updateMatrixWorld(true);fxRoot.add(player.root);v={player,cue:c,origin:p};weaponPlayers.set(key,v);}
 v.player.seek((time-c.start)*.03);
 const doc=W.packs[c.node.path],actor=actors.get(c.source);v.player.root.updateMatrixWorld(true);
 for(const [index,group] of v.player.binders){const b=doc.groups.Bind[index],prop=b?.properties?.PrpS;if(!prop)continue;
 group.matrixAutoUpdate=false;group.matrix.identity();const offset=avfxAxes(prop.Pos||{},(time-c.start)*.03,1,'binder'+index,0)||new THREE.Vector3();
 if(prop.BPTP===3){const eid=W.eid[weaponFamily(c.ability)==='female'?'m0514':'m0513'].rows.find(r=>r.id===prop.BPID),bone=eid&&actor?.mesh.getObjectByName(eid.bone);
 if(!bone){group.visible=false;v.player.diagnostics.add('missing_EID_bone/'+prop.BPID);continue;}group.visible=true;
 const local=new THREE.Matrix4().compose(new THREE.Vector3(...eid.position),new THREE.Quaternion().setFromEuler(new THREE.Euler(...eid.rotation_radians,'XYZ')),new THREE.Vector3(1,1,1));
 const world=bone.matrixWorld.clone().multiply(local),pos=new THREE.Vector3(),q=new THREE.Quaternion(),scale=new THREE.Vector3();world.decompose(pos,q,scale);
 group.matrix.copy(v.player.root.matrixWorld).invert().multiply(new THREE.Matrix4().compose(pos,q,new THREE.Vector3(1,1,1)));
 }else if(![0,1].includes(prop.BPTP)){v.player.diagnostics.add('unsupported_bind_target/'+prop.BPTP);group.visible=false;continue;}
 group.matrix.multiply(new THREE.Matrix4().makeTranslation(offset.x,offset.y,offset.z));group.matrixWorldNeedsUpdate=true;
 }

 }
}

// Source-event director, a bounded reconstruction; not a game-renderer fidelity certificate.
const F=window.TOP_FULL,fullPlayers=new Map(),fullSkipped=new Map();
let tetherPreview=null;
const fullCues=[...F.cues,...(F.bodyCues||[]),...F.tether_events.filter(e=>Number.isFinite(e.end)).map((e,index)=>({key:'record-tether/'+e.event_index,source:e.s,target:e.d,anchor:e.t,start:e.t,end:e.end,ability:0,phase:e.phase,path:F.channeling[e.tetherID],tetherID:e.tetherID,lifecycle_basis:e.lifetime_status,node:{},event_index:e.event_index}))].filter(c=>c.tetherID||(!R.actors[c.source]?.friendly&&!R.actors[c.source]?.player)).sort((a,b)=>a.start-b.start);
const boneIds={1:'j_kao',25:'n_atama',28:'j_sebo_c',29:'n_root',30:'n_hara',31:'j_kosi',32:'j_te_r',33:'j_te_l',42:'n_root',71:'n_root',77:'n_buki_r',78:'n_buki_l',107:'n_throw'};
function fullPoint(c,key,anchor=false){
 if(!key)return null;const raw=key===c.source?c.source_pos:key===c.target?c.target_pos:null;
 if(anchor&&raw&&raw.slice(0,2).every(Number.isFinite))return new THREE.Vector3(raw[0],0,raw[1]);
 const p=position(key,anchor?c.anchor:time,$('smooth').checked);return p&&p.age<=10000?new THREE.Vector3(p.x,0,p.z):null;
}
function fullBindWorld(v,prop,frame){
 const c=v.cue,key=prop.BPT===1?c.target:c.source;
 const freeze=prop.CoUF===1;
 let point=fullPoint(c,key,freeze);if(!point)return null;
 if(prop.BPTP===3&&freeze){v.player.diagnostics.add('frozen_bone_pose_unresolved');return null;}
 if(prop.BPTP===3){
  const a=actors.get(key),eidFamily=a?.form.startsWith('female')?'m0514':a?.form.startsWith('male')?'m0513':null;
  const eid=eidFamily&&W.eid[eidFamily]?.rows.find(x=>x.id===prop.BPID);
  const bone=a?.mesh.getObjectByName(eid?.bone||boneIds[prop.BPID]||'__unsupported_bone__');
  if(!bone){v.player.diagnostics.add('missing_attachment_bone/'+key+'/'+prop.BPID);return null;}
  const matrix=bone.matrixWorld.clone();
  if(eid)matrix.multiply(new THREE.Matrix4().compose(new THREE.Vector3(...eid.position),new THREE.Quaternion().setFromEuler(new THREE.Euler(...eid.rotation_radians,'XYZ')),new THREE.Vector3(1,1,1)));
  point.setFromMatrixPosition(matrix);
 }else if(![0,1,3].includes(prop.BPTP)){v.player.diagnostics.add('unsupported_bind_target/'+prop.BPTP);return null;}
 const offset=avfxAxes(prop.Pos||{},frame,v.player.seed,'binder-offset',0);
 if(!offset)return null;
 const heading=position(key,freeze?c.anchor:time,false)?.heading;
 offset.applyAxisAngle(new THREE.Vector3(0,1,0),yaw(heading));point.add(offset);
 return point;
}
function fullEndpoints(v,spec){
 const binder=v.player.document.groups.Bind[spec.binder],a=binder?.properties?.PrpS,b=binder?.properties?.PrpG;
 if(!a||!b)return null;
 const start=fullBindWorld(v,a,spec.age),end=fullBindWorld(v,b,spec.age);if(!start||!end)return null;
 v.player.root.updateMatrixWorld(true);const inv=v.player.root.matrixWorld.clone().invert();return {start:start.applyMatrix4(inv),end:end.applyMatrix4(inv),camera:camera.position.clone().applyMatrix4(inv)};
}
function activeFull(k){return fullCues.some(c=>c.start<=time&&time<c.end&&(c.source===k||c.target===k))||!!tetherPreview&&(tetherPreview.source===k||tetherPreview.target===k);}
function fullState(){return {instances:[...fullPlayers.values()].map(v=>({key:v.cue.key,ability:v.cue.ability,path:v.cue.path,source:v.cue.source,target:v.cue.target,start:v.cue.start,end:v.cue.end,particles:v.player.lastParticles.length,draws:v.player._draws.size,polylines:v.player._polyDraws?.size||0,frame:v.player.frame,position:v.player.root.position.toArray(),diagnostics:[...v.player.diagnostics],rendering_complete:false})),skipped:[...fullSkipped].map(([key,reason])=>({key,reason})),tetherPreview:tetherPreview?{id:tetherPreview.tetherID,index:tetherPreview.index,mode:'isolated source-event preview; lifetime unresolved'}:null};}
function updateFullFx(){
 const desired=new Map();fullSkipped.clear();
 if($('effects').checked){if(tetherPreview)desired.set(tetherPreview.key,tetherPreview);else for(const c of fullCues){if(c.start>time)break;if(time<c.end)desired.set(c.key,c);}}
 for(const [key,v] of fullPlayers)if(!desired.has(key)){v.player.dispose();fullPlayers.delete(key);}
 for(const [key,c] of desired){let v=fullPlayers.get(key);const doc=cache.get(F.packs[c.path]);if(!doc){if(v){v.player.dispose();fullPlayers.delete(key);}fullSkipped.set(key,'source pack not loaded');continue;}
  if(!v){const p=fullPoint(c,c.source,true);if(!p){fullSkipped.set(key,'no reliable source position');continue;}
   const textures=Object.fromEntries(doc.textures.map(p=>[p,cache.get(F.textures[p])]));if(Object.values(textures).some(x=>!x)){fullSkipped.set(key,'source texture not loaded');continue;}
   const seed=Array.from(key).reduce((h,x)=>Math.imul(h^x.charCodeAt(0),16777619)>>>0,2166136261);
   const player=new AvfxRuntime(doc,textures,seed,{polylineEndpoints:s=>fullEndpoints(v,s)});v={player,cue:c};
   player.root.position.copy(p);player.root.rotation.set(0,yaw(position(c.source,c.anchor,false)?.heading),0);fxRoot.add(player.root);fullPlayers.set(key,v);
   player.diagnostics.add(c.tetherID?'tether_lifetime/'+c.lifecycle_basis:c.isBody?'body_lifecycle/observed_activity_only':'C012_host_stop_semantics_unresolved');
  }
  const frame=c.isPreview?c.ageFrames:(time-c.start)*.03;
  v.player.root.updateMatrixWorld(true);
  // Stage attachment groups before sampling so geometry sees the current endpoints.
  for(let i=0;i<doc.groups.Bind.length;i++){
   const prop=doc.groups.Bind[i].properties?.PrpS,group=v.player.getBinderGroup(i);
   if(!prop){group.visible=false;v.player.diagnostics.add('missing_binder_properties/'+i);continue;}
   const world=fullBindWorld(v,prop,frame);group.visible=!!world;if(!world)continue;
   group.matrixAutoUpdate=false;group.matrix.copy(v.player.root.matrixWorld).invert().multiply(new THREE.Matrix4().makeTranslation(world.x,world.y,world.z));
   // Root/ground orientation follows the declared caster, not an arbitrary scene origin.
   const actorKey=prop.BPT===1?c.target:c.source,heading=position(actorKey,prop.CoUF===1?c.anchor:time,false)?.heading;
   group.matrix.multiply(new THREE.Matrix4().makeRotationY(yaw(heading)));group.matrixWorldNeedsUpdate=true;
  }
  const sampled=v.player.seek(frame);v.player.root.visible=sampled;if(!sampled)fullSkipped.set(key,'runtime sample rejected; diagnostics retained');
 }
}
async function previewTether(index,ageFrames=30){
 if(index==null){tetherPreview=null;render();return;}
 const e=F.tether_events[index];if(!e)throw Error('No such recorded tether event');
 await seek(e.t);
 const path=F.channeling[e.tetherID];await loadSerial([F.packs[path]]);await loadSerial(cache.get(F.packs[path]).textures.map(p=>F.textures[p]));
 tetherPreview={key:'tether-preview/'+index,index,source:e.s,target:e.d,anchor:e.t,start:e.t,end:e.t,phase:e.phase,path,tetherID:e.tetherID,isPreview:true,ageFrames};render();return fullState();
}
function skipCinematic(t){const cut=F.cutscene_skips.find(c=>c.start<=t&&t<c.end);return cut?cut.end:t;}

const fullAudio=createAudioDirector({cues:(window.TOP_FULL.audioCues||[]).filter(c=>!R.actors[c.source]?.friendly&&!R.actors[c.source]?.player),loadBytes:loadAsset,getState:()=>({time,playing,ready,speed:Number($('speed').value)}),position});
$('audio').onchange=async()=>{const result=await fullAudio.enable($('audio').checked);if(result.blocked)$('audio').checked=false;};

function render(){if(!ready)return;const smooth=$('smooth').checked;let visible=0,clips=[];
 for(const [k,a] of actors){if(a.baseForm.startsWith('male')||a.baseForm.startsWith('female'))selectActorForm(a,formAt(k,a));const isPlayer=R.actors[k]?.player,b=M.bindings[k];let p=position(k,time,smooth),show=isPlayer||b?.windows.some(w=>time>=w[0]&&time<=w[1]+800)||!!currentAction(k,a.form);
 if(a.form==='optical'){const cast=casts.find(c=>c.s===k&&time>=c.t&&time<c.end+1300);show=!!cast;if(cast){const tr=R.tracks[k]||[];const sample=tr.find(x=>x[0]>=cast.t&&x[0]<=cast.end+100);p=sample?{x:sample[1],z:sample[2],heading:sample[3],age:0}:null;}}
 if(!isPlayer&&p&&p.age>10000)show=false;show=show&&!!p;a.root.visible=show&&!isPlayer;if(!show&&!activeWeapon(k)&&!activeFull(k))continue;if(!p)continue;if(show&&!isPlayer)visible++;
 if(a.form==='optical'){a.root.position.set(0,0,0);a.root.rotation.y=Math.atan2(-p.x,-p.z);}else{a.root.position.set(p.x,0,p.z);a.root.rotation.y=yaw(p.heading);}
 a.mesh.visible=!isPlayer;a.label.visible=!isPlayer&&$('labels').checked;a.label.material.opacity=p.age>1500?.45:1;
 const death=deaths.find(d=>d.d===k&&d.t<=time);if(isPlayer&&death){a.mesh.rotation.z=0;a.label.material.color.set(0xff7788);}else{a.mesh.rotation.z=0;a.label.material.color.set(0xffffff);}
 const motion=motionAt(k,a,p);animate(a,motion.clip,motion.seconds,motion.once);a.motionBasis=motion.basis;const isModelSpace=!!a.clip?.startsWith('action_');a.mesh.traverse(o=>{if(o.isBone)o.matrixWorldAutoUpdate=!isModelSpace;});a.root.updateMatrixWorld(true);if(isModelSpace){a.mesh.traverse(o=>{if(o.isBone){o.updateMatrix();o.matrixWorld.copy(a.mesh.matrixWorld).multiply(o.matrix);o.matrixWorldNeedsUpdate=false;}});}a.currentAbility=currentAction(k,a.form)?.event.a;stance(a,k);clips.push(a.form+':'+a.clip);
 }
 updateFullFx();updateFx();updateWeaponFx();fullAudio.sync();const w=$('view').clientWidth,h=$('view').clientHeight;if(renderer.domElement.width!==Math.round(w*renderer.getPixelRatio())||renderer.domElement.height!==Math.round(h*renderer.getPixelRatio())){renderer.setSize(w,h,false);camera.aspect=w/h;camera.updateProjectionMatrix();}
 renderer.render(scene,camera);updateUi(visible,clips);
}
function updateUi(visible,clips){$('clock').textContent=fmt(time)+' / '+fmt(R.duration_ms);$('scrub').value=time;$('phase').textContent='P'+phase;$('chapter').textContent='完整戰鬥紀錄 · 強制過場略過';
 const originalSkills=[...actors.values()].filter(a=>a.root.visible&&a.clip?.startsWith('action_'));const current=casts.filter(c=>c.t<=time&&time<c.end).filter(c=>['12:0','19:0','20:0','26:0','31:0','38:0','25:0'].includes(c.s)).slice(0,2);
 $('cast').innerHTML=current.map(c=>`${esc(name(c.a))}<progress max="1" value="${(time-c.t)/Math.max(1,c.end-c.t)}"></progress>`).join('');
 $('status').textContent=`${visible} 個有採樣的模型 · ${fxObjects.size+weaponPlayers.size+fullPlayers.size} 組特效 · ${smooth?'平滑插值':'原始位置採樣'}`;
 if(Math.floor(time/200)===lastUi)return;lastUi=Math.floor(time/200);
 $('party').innerHTML=party.filter(()=>false).map((a,i)=>{const p=position(a.id,time,smooth);return `<span style="--c:#${colors[i].toString(16)}">${a.label} · ${deaths.some(d=>d.d===a.id&&d.t<=time)?'曾記錄死亡':p?(p.age>1500?'舊採樣':p.moving?'移動插值':'已採樣'):'待採樣'}</span>`;}).join('');
 $('inspect').textContent=fxObjects.size?[...fxObjects.values()].map(g=>g.userData.label).filter(Boolean).join('／'):'原版待機動畫；未映射的施法動作不冒配其他技能。';if(originalSkills.length)$('inspect').textContent='原版技能動作：'+originalSkills.map(a=>name(a.currentAbility)).join('、')+' · '+$('inspect').textContent;if(weaponPlayers.size)$('inspect').textContent+=' · 原版資源武器特效：'+[...new Set([...weaponPlayers.values()].map(x=>name(x.cue.ability)))].join('、');if(skippedEffects.size)$('inspect').textContent+=' · '+skippedEffects.size+' 組因缺位置未顯示';
 const idx=upper(eventList,time,e=>e.t);$('events').innerHTML=eventList.slice(Math.max(0,idx-2),idx+7).map(e=>`<div class="event" data-t="${e.t}">${fmt(e.t)} · ${esc(name(e.a))}<small>${esc(e.type)} · ${esc(R.actors[e.s]?.label||'未記錄來源')}</small></div>`).join('');$('events').querySelectorAll('[data-t]').forEach(e=>e.onclick=()=>seek(+e.dataset.t));
 $('phases').querySelectorAll('button').forEach(b=>b.classList.toggle('active',+b.dataset.id===phase));
}
async function seek(t){tetherPreview=null;time=skipCinematic(Math.max(0,Math.min(R.duration_ms,Number(t)||0)));fullAudio.seekReset();lastUi=-1;const p=phaseAt(time);if(p.id!==desiredPhase){phasePromise=ensurePhase(p);}if(phasePromise)await phasePromise;if(ready)render();return time;}
function toggle(){playing=!playing;$('play').textContent=playing?'Ⅱ 暫停':'▶ 播放';fullAudio.sync();}
$('phases').innerHTML=R.phase_markers.map(p=>`<button data-id="${p.id}" data-t="${p.t}">${p.label}</button>`).join('');$('phases').querySelectorAll('button').forEach(b=>b.onclick=()=>seek(+b.dataset.t));for(const a of R.anchors){const option=document.createElement('option');option.value=a.t;option.textContent=fmt(a.t)+' · '+a.name;$('anchor').append(option);}
for(const [t,label] of [[157000,'M 盾＋F 冰法'],[175000,'M 劍／分身'],[670500,'F 腿刃'],[725900,'P5 武器連續攻擊']]){const o=document.createElement('option');o.value=t;o.textContent='武器特效 · '+label;$('anchor').append(o);};
$('settings').onclick=()=>{const clean=$('layout').classList.toggle('clean');$('settings').setAttribute('aria-expanded',String(!clean));render();};
$('retry').onclick=()=>{desiredPhase=-1;seek(time).catch(e=>console.error(e));};$('anchor').onchange=e=>e.target.value!==''&&seek(+e.target.value);$('scrub').oninput=e=>seek(+e.target.value);$('play').onclick=toggle;$('back').onclick=()=>seek(time-5000);$('forward').onclick=()=>seek(time+5000);$('camera').onclick=resetCamera;$('panorama').onclick=()=>{camera.position.set(85,85,110);controls.target.set(0,4,0);controls.update();render();};for(const k of ['effects','players','labels','smooth'])$(k).onchange=()=>{lastUi=-1;render();};
window.addEventListener('pagehide',e=>{if(e.persisted){fullAudio.enable(false);$('audio').checked=false;}else fullAudio.dispose();});
window.addEventListener('keydown',e=>{if(e.code==='Space'&&!['INPUT','SELECT','BUTTON'].includes(document.activeElement.tagName)){e.preventDefault();toggle();}});controls.addEventListener('change',render);window.addEventListener('resize',render);
window.replay={sceneReport:()=>({materialDiagnostics:Object.fromEntries(backgroundDiagnostics),phase,nodes:window.TOP_SCENES?.phases?.[phase]?.nodes.length||0,limitations:window.TOP_SCENES?.limitations||[],complete:false}),actorStateReport:()=>actorState.report(),presentation:'playerless',seek,audioEnable:(on,o)=>fullAudio.enable(on,o),audioReport:()=>fullAudio.report(),audioDispose:()=>fullAudio.dispose(),previewTether,fullState,skipCinematic,fullCues:fullCues.map(({node,...c})=>c),getTime:()=>time,data:R,manifest:M,getState:()=>({time,phase,desiredPhase,ready,loadingCount,playing,playerVisuals:[...actors].filter(([k,a])=>R.actors[k]?.player).map(([k,a])=>({k,rootVisible:a.root.visible,meshVisible:a.mesh.visible,labelVisible:a.label.visible})),actors:[...actors].filter(([k,a])=>a.root.visible).map(([k,a])=>({k,form:a.form,clip:a.clip,motionBasis:a.motionBasis,position:a.root.position.toArray(),bones:a.mesh.getObjectByProperty('isBone',true)?.matrixWorld.elements.slice()})),effects:[...fxObjects].map(([key,g])=>({key,label:g.userData.label,visible:g.visible,children:g.children.length})),weaponEffects:weaponState(),fullEffects:fullState(),memory:renderer.info.memory,draw:renderer.info.render}),poseWorld:(k)=>{const a=actors.get(k),out=[];if(!a)return out;const inv=a.mesh.matrixWorld.clone().invert();a.mesh.traverse(o=>{if(o.isBone)out.push({name:o.name,matrix:inv.clone().multiply(o.matrixWorld).elements});});return out;},pose:(k)=>{const out=[];actors.get(k)?.mesh.traverse(o=>{if(o.isBone)out.push([o.name,...o.position.toArray(),...o.quaternion.toArray()]);});return out;},getEffectCues:()=>fxCues,weaponCues:weaponCues.map(({node,...c})=>({...c,path:node.path,node_time:node.time})),weaponState,focusActor:(k)=>{const a=actors.get(k);if(a){const v=a.root.position;camera.position.copy(v).add(new THREE.Vector3(18,15,23));controls.target.copy(v).add(new THREE.Vector3(0,3,0));controls.update();render();}},parts:(k)=>{const a=actors.get(k),r=[];a?.mesh.traverse(o=>{if(o.isMesh)r.push({name:o.name,visible:o.visible})});return r;},config};
function frame(now){const dt=Math.max(0,now-lastFrame);lastFrame=now;if(playing&&ready){time=skipCinematic(Math.min(R.duration_ms,time+dt*Number($('speed').value)));const p=phaseAt(time);if(p.id!==phase)seek(time).catch(e=>console.error(e));else render();if(time>=R.duration_ms){playing=false;$('play').textContent='▶ 播放';}}requestAnimationFrame(frame);}
resetCamera();seek(0).then(()=>{window.replayReady=true;requestAnimationFrame(frame);}).catch(e=>console.error(e));
