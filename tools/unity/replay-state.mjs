// SPDX-License-Identifier: MIT
// Actor identity is immutable; appearance is an independently seekable timeline.
// Source C010 clip-end is a preview boundary, NOT a certified model-swap frame.
const simulation=new Map([[31515,'female'],[31516,'male'],[31506,'female'],[31507,'male']]);
const family=new Map([[31742,'male'],[31743,'female']]);
const related=f=>/^(male|female)(_p5)?$/.test(f||'');
const variant=(base,f)=>f+(base.endsWith('_p5')?'_p5':'');
function upper(rows,t){let lo=0,hi=rows.length;while(lo<hi){const m=(lo+hi)>>1;if(rows[m].t<=t)lo=m+1;else hi=m;}return lo;}
export function createActorState(record,manifest){
 const timelines=new Map(),transforms=new Map(),diagnostics=[];
 for(const [id,b] of Object.entries(manifest.bindings))if(related(b.form))timelines.set(id,[{t:-Infinity,form:b.form,basis:'original NPC identity'}]);
 const events=record.events.map((e,i)=>({...e,index:i})).map(e=>({...e,s:String(e.s)})).filter(e=>timelines.has(e.s)&&['cast','begincast'].includes(e.type)).sort((a,b)=>a.t-b.t||a.index-b.index);
 for(const e of events){const rows=timelines.get(e.s),base=manifest.bindings[e.s].form,prior=rows[upper(rows,e.t)-1].form;
  if(e.type==='cast'&&simulation.has(e.a)){
   const form=variant(base,simulation.get(e.a)),row=manifest.action_rows?.[e.a],binding=manifest.action_animation_bindings?.[prior]?.[row?.end];
   if(form===prior)continue;
   if(!binding?.playback_eligible||!Number.isFinite(binding.duration_s)||binding.duration_s<=0||!Number.isFinite(binding.node_time)||binding.node_time<0||(binding.flags===1&&(!Number.isFinite(binding.node_duration)||binding.node_duration<=0))){diagnostics.push({actor:e.s,ability:e.a,time:e.t,reason:'missing source transform duration; no invented swap'});continue;}
   const duration=(binding.flags===1?binding.node_duration/30:binding.duration_s)*1000;
   const start=e.t+binding.node_time/30*1000,end=start+duration;
   const ts=transforms.get(e.s)||[];ts.push({start,end,from:prior,to:form,ability:e.a,binding,event_index:e.index});transforms.set(e.s,ts);
   rows.push({t:end,form,basis:'C010 transform clip-end preview boundary',ability:e.a,event_index:e.index});rows.sort((a,b)=>a.t-b.t);
  }else if(family.has(e.a)){
   const form=variant(base,family.get(e.a));if(transforms.has(e.s)){if(form!==prior)diagnostics.push({actor:e.s,ability:e.a,time:e.t,reason:'family observation conflicts with transform estimate; no automatic override'});continue;}if(form!==prior){rows.push({t:e.t,form,basis:'observed family-specific action',ability:e.a,event_index:e.index});rows.sort((a,b)=>a.t-b.t);}
  }
 }
 function formAt(id,t){id=String(id);const rows=timelines.get(id);return rows?rows[upper(rows,t)-1].form:manifest.bindings[id]?.form;}
 const holds=[];
 for(const e of record.events){if(e.type!=='cast'||e.a!==31556||e.phase!==2)continue;const id=String(e.s),form=formAt(id,e.t),row=manifest.action_rows?.[e.a],binding=manifest.action_animation_bindings?.[form]?.[row?.end];const stop=record.events.find(x=>x.t>e.t&&x.type==='targetabilityupdate'&&String(x.s)===id&&x.targetable===0);if(!binding?.playback_eligible||!stop){diagnostics.push({actor:id,time:e.t,reason:'shield pose missing original clip or observed stop'});continue;}holds.push({actor:id,form,start:e.t,end:stop.t,binding,basis:'original shield PAP final pose retained until recorded targetability loss; original blend/host loop unresolved'});}
 return {formAt,heldPoseAt:(id,t)=>holds.find(x=>x.actor===String(id)&&x.start<=t&&t<x.end)||null,hasTransform:id=>transforms.has(String(id)),transitionAt:(id,t)=>(transforms.get(id)||[]).find(c=>c.start<=t&&t<c.end)||null,report:()=>({holds,timelines:Object.fromEntries([...timelines].map(([k,v])=>[k,v.map(x=>({...x,t:Number.isFinite(x.t)?x.t:null}))])),transforms:Object.fromEntries(transforms),diagnostics,boundary_precision:'C010 clip-end approximation; exact appearance-swap frame unverified'})};
}

// Reconstruct cast windows from observed completion and the corroborated P2 death/return sequence.
export function buildCastWindows(record,manifest){
 const events=record.events;
 return events.filter(e=>e.type==='begincast'&&e.s&&!record.actors[e.s]?.friendly).map(e=>{
  const horizon=Math.max(30000,e.castDuration||e.duration||0)+1000;
  const hit=events.find(f=>f.t>=e.t&&f.t<e.t+horizon&&f.type==='cast'&&f.s===e.s&&f.a===e.a);
  let end=hit?.t??e.t+(e.castDuration||e.duration||2000),end_basis=hit?'recorded cast completion':'recorded cast duration fallback';
  const scheduled_end=end;
  if(e.phase===2&&related(manifest.bindings[e.s]?.form)){
   const ret=events.find(f=>f.t>e.t&&f.t<end&&f.s===e.s&&f.type==='cast'&&[31506,31507].includes(f.a));
   if(ret){const loss=events.filter(f=>f.t>e.t&&f.t<=ret.t&&f.s===e.s&&f.type==='targetabilityupdate'&&f.targetable===0).at(-1);end=loss?.t??ret.t;end_basis=loss?'recorded targetability loss before appearance-return action':'recorded appearance-return action';}
  }
  return {...e,end,scheduled_end,end_basis};
 });
}
