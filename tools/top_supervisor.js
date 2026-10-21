// Deterministic observation only: no implementation, retries or resubmission.
function output(r) {
  if (typeof r === 'string') return r;
  for (const key of ['aggregated','stdout','output','text']) if (typeof r?.[key] === 'string') return r[key];
  if (Array.isArray(r?.content)) return r.content.filter(x => x.type === 'text').map(x => x.text).join('\n');
  if (r?.details) return output(r.details);
  throw new Error('Unknown guard result shape');
}
const result = await exec({command:'python3 tools/work_guard.py check',workdir:'/home/brewuser/.openclaw/workspace/projects/Omega-Protocol-Sim',timeoutSeconds:20,yieldMs:10000,title:'TOP bounded-stage supervisor check'});
const raw = output(result);
const observed = JSON.parse(raw.slice(raw.indexOf('{'),raw.lastIndexOf('}')+1));
const previous = trigger.state || {};
const signature = [observed.stage,observed.started,observed.status,observed.reason].join('|');
const state = {lastObservedStatus:observed.status,lastAttentionSignature:previous.lastAttentionSignature || null};
let notify;
if (observed.status === 'blocked' && signature !== state.lastAttentionSignature) {
  state.lastAttentionSignature = signature;
  notify = 'TOP 監督已停止本段：'+observed.stage+'（'+observed.reason+'）。已保留日誌；不會自動重試。下一步需縮小案例或更換方法後再續接。';
}
json({state,...(notify ? {notify} : {})});
