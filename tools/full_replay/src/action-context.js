// SPDX-License-Identifier: MIT
import {createActorState} from './actor-state.js';
// A source actor's NPC identity does not select its current model's TMB.
export function resolveActionContexts(record,manifest,timelineKeys){
 const state=createActorState(record,manifest),events=[],missing=[];
 for(let i=0;i<record.events.length;i++){
  const e=record.events[i],base=manifest.bindings[e.s]?.form;
  if(!['cast','begincast'].includes(e.type)||!/^(male|female)(_p5)?$/.test(base||'')||[31525,31526,31530,31533].includes(e.a))continue;
  const kind=e.type==='begincast'?'start':'end',id=manifest.action_rows?.[e.a]?.[kind];if(!Number.isInteger(id)||id<=0)continue;
  const key=timelineKeys instanceof Map?timelineKeys.get(id):timelineKeys[id];if(!key){missing.push({event_index:i,ability:e.a,timeline:id,kind});continue;}
  const form=state.formAt(e.s,e.t),model=form.startsWith('female')?'m0514':'m0513';
  events.push({event_index:i,source:e.s,ability:e.a,phase:e.phase,anchor:e.t,form,kind,path:'chara/action/'+key.replaceAll('[skl_id]',model)+'.tmb'});
 }
 return {events,roots:[...new Set(events.map(x=>x.path))],missing};
}
