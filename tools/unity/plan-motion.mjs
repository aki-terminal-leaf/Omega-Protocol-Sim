// SPDX-License-Identifier: MIT
// Compile seekable intervals; no per-frame baked playback or global video retiming.
import {readFile,writeFile} from 'node:fs/promises';
import {join} from 'node:path';
import {createActorState,buildCastWindows} from './replay-state.mjs';
const dir=process.argv[2];if(!dir)throw Error('Usage: node plan-motion.mjs NATIVE_DATA');
const read=async n=>JSON.parse(await readFile(join(dir,n+'.json'),'utf8'));
const R=await read('record'),M=await read('manifest'),W=await read('weapon-data');
const state=createActorState(R,M),casts=buildCastWindows(R,M),allActions=[];
const weaponFamily=a=>[31525,31526].includes(a)?'male':[31530,31533].includes(a)?'female':null;
const weaponForm=(ability,base)=>weaponFamily(ability)+(base.endsWith('_p5')?'_p5':'');
const weaponWindows=R.events.filter(e=>e.type==='cast'&&W.actions[e.a]).map(e=>({...e,end:e.t+Math.max(...W.actions[e.a].nodes.map(n=>n.time/30*1000+6000))}));
function activeWeapon(id,t){return weaponWindows.find(e=>e.s===id&&e.t<=t&&t<e.end)||casts.find(c=>c.s===id&&W.actions[c.a]&&c.t<=t&&t<c.end);}
function appearance(id,t){const base=M.bindings[id]?.form,w=!state.hasTransform(id)&&activeWeapon(id,t);return w?weaponForm(w.a,base):state.formAt(id,t)||base;}

for(const e of R.events){if(e.type!=='cast')continue;const base=M.bindings[e.s]?.form,form=W.actions[e.a]&&base?weaponForm(e.a,base):(state.formAt(e.s,e.t)||base),row=M.action_rows[e.a],b=M.action_animation_bindings[form]?.[row?.end];if(!b?.playback_eligible)continue;const duration=b.flags===1?b.node_duration/30:b.duration_s;if(!(duration>0&&duration<=60))continue;const start=e.t+b.node_time/30*1000;allActions.push({actor:e.s,form,start,end:start+duration*1000,binding:b,ability:e.a});}
allActions.sort((a,b)=>a.start-b.start);
const report=state.report(),actors={};
for(const [id,binding] of Object.entries(M.bindings)){
 const actions=allActions.filter(a=>a.actor===id),cs=casts.filter(c=>c.s===id),cuts=new Set([0,R.duration_ms]);
 for(const x of actions){cuts.add(x.start);cuts.add(x.end);}
 for(const x of cs){cuts.add(x.t);cuts.add(x.end);const row=M.action_rows[x.a],st=M.cast_start_clips?.[row?.start];if(st)cuts.add(x.t+(st.time+st.duration)/30*1000);}
 for(const x of report.transforms[id]||[]){cuts.add(x.start);cuts.add(x.end);}
 for(const x of report.holds.filter(x=>x.actor===id)){cuts.add(x.start);cuts.add(x.end);}
 const ts=[...cuts].filter(x=>Number.isFinite(x)&&0<=x&&x<=R.duration_ms).sort((a,b)=>a-b),segments=[];
 const motion=t=>{
  const form=appearance(id,t),tr=state.transitionAt(id,t),hold=state.heldPoseAt(id,t),a=actions.filter(a=>a.start<=t).at(-1),end=a&&a.form===form&&t<a.end?a:null;
  let clip='cbbm_id0',anchor=0,offset=0,rate=1,period=0,once=false,basis='resident idle';
  const take=(b,start)=>{clip=b.clip;anchor=start;once=true;if(b.flags===1){offset=b.animation_start/30;rate=(b.animation_end-b.animation_start)/b.node_duration;}};
  if(tr&&tr.from===form){take(tr.binding,tr.start);basis='source transform; clip-end boundary approximate';}
  else if(hold&&hold.form===form){take(hold.binding,hold.start);basis=hold.basis;}
  else {
   const c=cs.find(c=>c.t<=t&&t<c.end),row=c&&M.action_rows[c.a],st=row&&M.cast_start_clips?.[row.start],loops=row&&M.cast_loop_clips?.[row.start]?.animations,loop=loops?.length===1?loops[0]:null;
   if(c&&st&&M.assets[form]?.clips.includes(st.path)&&(!end||c.t>end.start)){
    const boundary=c.t+(st.time+st.duration)/30*1000;
    if(loop&&M.assets[form]?.clips.includes(loop.path)&&t>=boundary){clip=loop.path;anchor=boundary;offset=-loop.time/30;period=loop.duration/30;once=false;basis='source paired cast-loop; reconstructed scheduling';}
    else {clip=st.path;anchor=c.t;once=true;basis='source cast start';}
   }else if(end){take(end.binding,end.start);basis='source action PAP/C010';}
  }
  let stance=hold?'SHIELD':'NEUTRAL';const weapon=activeWeapon(id,t),near=weapon||cs.find(c=>c.t<=t&&t<c.end+700);
  if(near){if(near.a===31525)stance='SHIELD';if([31526,31527,31528].includes(near.a))stance='SWORD';if([31532,31530].includes(near.a))stance='LEGS';if([31533,31531].includes(near.a))stance='STAFF';}
  return {form,clip,anchor,offset,rate,period,once,basis,stance,activeAction:!!end};
 };
 // Stance uses weapon cast +6 s and prep cast +700 ms boundaries too.
 for(const e of weaponWindows.filter(e=>e.s===id)){cuts.add(e.t);cuts.add(e.end);}
 for(const c of cs)cuts.add(c.end+700);
 const boundaries=[...cuts].filter(x=>Number.isFinite(x)&&0<=x&&x<=R.duration_ms).sort((a,b)=>a-b);
 for(let i=0;i<boundaries.length-1;i++){const start=boundaries[i],end=boundaries[i+1],s=motion(start);const prior=segments.at(-1);if(prior&&JSON.stringify({...prior,start:0,end:0})===JSON.stringify({...s,start:0,end:0}))prior.end=end;else segments.push({...s,start,end});}
 actors[id]={...binding,motions:segments,opticalCasts:cs.map(c=>({start:c.t,end:c.end+1300,castEnd:c.end}))};
}
const output={schema:1,duration:R.duration_ms,actors,castWindows:casts,actorState:report,complete:false};
await writeFile(join(dir,'motion-plan.json'),JSON.stringify(output));console.log(JSON.stringify({actors:Object.keys(actors).length,segments:Object.values(actors).reduce((n,a)=>n+a.motions.length,0),diagnostics:report.diagnostics}));
