/* Bounded Web Audio source-cue playback director (plain browser JS, no deps).
 * Times are milliseconds everywhere (cue.start/end, getState().time).
 * Source positioning / gain / distance attenuation are NOT original-game behaviour.
 *
 * Race contract:
 *  - Voices are only ever started synchronously inside sync(), from fresh getState().
 *    Async load/decode never starts a node; it only fills the cache and then calls sync().
 *  - Every async completion checks disposed / ctx identity / enableToken before acting.
 *  - A voice is removed from the map BEFORE stop(); onended only mutates state if
 *    voices.get(key).node === its own node, so an old node never deletes a replacement.
 *  - Load failures are recorded once per asset in `failed` and never retried until dispose().
 * Errors: enable() never hangs (resume bounded by resumeTimeoutMs) and resolves report()
 * with blocked:true / enabled:false instead of throwing; other failures go to diagnostics.
 */
const root=globalThis;
  'use strict';

  export function createAudioDirector(opts) {
    opts = opts || {};
    const cues = Array.isArray(opts.cues) ? opts.cues : [];
    const loadBytes = opts.loadBytes;
    const getState = opts.getState;
    const position = typeof opts.position === 'function' ? opts.position : null;
    const GAIN = Number.isFinite(opts.gain) ? opts.gain : 0.3;
    const MAX_DECODED = Math.max(1, opts.maxDecoded | 0 || 128);
    const CONC = Math.min(4, Math.max(1, opts.concurrency | 0 || 2));
    const SPATIAL = !!opts.spatial;
    const RESUME_MS = opts.resumeTimeoutMs || 1500;
    const JUMP_MS = opts.jumpMs || 1500;
    const MAX_DIAG = 50;

    let ctx = null, master = null;
    let enabled = false, muted = false, disposed = false, blocked = false;
    let epoch = 0, enableToken = 0, lastTime = null;
    const voices = new Map();      // key -> {node, gain, pan, asset}
    const ended = new Set();       // keys finished/failed in this epoch
    const buffers = new Map();     // asset -> AudioBuffer (LRU, insertion order)
    const pending = new Set();     // assets queued or loading
    const queue = [];
    const loading = new Set();
    const failed = new Map();      // asset -> message
    const diagnostics = [];
    let running = 0;

    function diag(kind, msg, extra) {
      diagnostics.push(Object.assign({ kind, msg: String((msg && msg.message) || msg) }, extra || {}));
      if (diagnostics.length > MAX_DIAG) diagnostics.shift();
    }

    function stopVoice(key) {
      const v = voices.get(key);
      if (!v) return;
      voices.delete(key);
      v.node.onended = null;
      try { v.node.stop(); } catch (e) { /* not started / already stopped */ }
      for (const n of [v.node, v.pan, v.gain]) { if (n) { try { n.disconnect(); } catch (e) { /* ignore */ } } }
    }
    function stopAll() { for (const k of Array.from(voices.keys())) stopVoice(k); }
    function reset() { epoch++; stopAll(); ended.clear(); lastTime = null; }

    function cacheGet(asset) {
      const b = buffers.get(asset);
      if (b) { buffers.delete(asset); buffers.set(asset, b); }
      return b;
    }
    function cachePut(asset, b) {
      buffers.delete(asset); buffers.set(asset, b);
      while (buffers.size > MAX_DECODED) buffers.delete(buffers.keys().next().value);
    }

    function request(asset) {
      if (pending.has(asset) || failed.has(asset) || buffers.has(asset)) return;
      pending.add(asset); queue.push(asset); pump();
    }
    function pump() {
      while (!disposed && enabled && ctx && running < CONC && queue.length) {
        const asset = queue.shift();
        running++;loading.add(asset);
        load(asset, ctx).then(() => {}, () => {}).then(() => { running--; pump(); });
      }
    }
    async function load(asset, myCtx) {
      let ok = false;
      try {
        const bytes = await loadBytes(asset);
        if (disposed || ctx !== myCtx) return;
        const buf = await myCtx.decodeAudioData(bytes.slice(0));
        if (disposed || ctx !== myCtx) return;
        cachePut(asset, buf); ok = true;
      } catch (e) {
        failed.set(asset, String((e && e.message) || e));
        diag('load', e, { asset });
      } finally {
        pending.delete(asset);loading.delete(asset);
      }
      if (ok && !disposed && enabled && ctx === myCtx) sync();
    }

    function startVoice(cue, buf, st) {
      const age = (st.time - cue.start) / 1000;
      if (!(age >= 0) || age >= buf.duration) { ended.add(cue.key); return; }
      let node = null, gain = null, pan = null;
      try {
        node = ctx.createBufferSource();
        node.buffer = buf;
        node.playbackRate.value = st.speed;
        gain = ctx.createGain(); gain.gain.value = 1;
        node.connect(gain);
        let tail = gain;
        if (SPATIAL && ctx.createStereoPanner) { pan = ctx.createStereoPanner(); gain.connect(pan); tail = pan; }
        tail.connect(master);
        const v = { node, gain, pan, asset: cue.asset };
        node.onended = () => {
          const cur = voices.get(cue.key);
          if (cur && cur.node === node) { voices.delete(cue.key); ended.add(cue.key); }
          for (const n of [node, pan, gain]) { if (n) { try { n.disconnect(); } catch (e) { /* ignore */ } } }
        };
        voices.set(cue.key, v);
        node.start(0, age);
        updatePan(cue, v, st);
      } catch (e) {
        if (voices.get(cue.key) && voices.get(cue.key).node === node) voices.delete(cue.key);
        if (node) { node.onended = null; }
        for (const n of [node, pan, gain]) { if (n) { try { n.disconnect(); } catch (e2) { /* ignore */ } } }
        ended.add(cue.key);
        diag('start', e, { key: cue.key });
      }
    }
    function updatePan(cue, v, st) {
      if (!SPATIAL || !v.pan || !position) return;
      try {
        const p = position(cue.source, st.time);
        if (p && Number.isFinite(p.x)) v.pan.pan.value = Math.max(-1, Math.min(1, p.x / 20));
      } catch (e) { /* position errors are non-fatal */ }
    }

    function sync() {
      if (disposed) return;
      if (!enabled || !ctx) { if (voices.size) stopAll(); return; }
      let st;
      try { st = getState(); } catch (e) { diag('state', e); stopAll(); return; }
      if (!st || !st.playing || !st.ready || !(st.speed > 0)) {
        if (voices.size) stopAll();
        if (!st || !st.playing) { epoch++; ended.clear(); lastTime = null; }
        return;
      }
      const t = st.time;
      if (lastTime !== null && (t < lastTime || t - lastTime > JUMP_MS * Math.max(1, st.speed))) reset();
      lastTime = t;
      const want = new Set();
      for (let i = 0; i < cues.length; i++) {
        const c = cues[i];
        if (c.start > t) break;
        if (t < c.end) want.add(c.key);
        else continue;
        const v = voices.get(c.key);
        if (v) {
          if (v.node.playbackRate.value !== st.speed) v.node.playbackRate.value = st.speed;
          updatePan(c, v, st);
          continue;
        }
        if (ended.has(c.key) || failed.has(c.asset)) continue;
        const buf = cacheGet(c.asset);
        if (buf) startVoice(c, buf, st); else request(c.asset);
      }
      for (const k of Array.from(voices.keys())) if (!want.has(k)) stopVoice(k);
      pump();
    }

    function applyGain() { if (master) master.gain.value = muted ? 0 : GAIN; }

    async function enable(on, o) {
      if (disposed) return report();
      const token = ++enableToken;
      if (!on) {
        enabled = false; blocked = false; reset(); queue.length = 0; for(const a of [...pending])if(!loading.has(a))pending.delete(a);
        if (ctx && ctx.state === 'running') { try { ctx.suspend().catch(() => {}); } catch (e) { /* ignore */ } }
        return report();
      }
      muted = !!(o && o.muted);
      try {
        if (!ctx) {
          const AC = root.AudioContext || root.webkitAudioContext;
          if (!AC) throw new Error('Web Audio unavailable');
          ctx = new AC();
          master = ctx.createGain(); master.connect(ctx.destination);
        }
        applyGain();
        if (ctx.state !== 'running') {
          let timer;
          const timeout = new Promise((_, rej) => { timer = setTimeout(() => rej(new Error('resume timeout')), RESUME_MS); });
          try { await Promise.race([ctx.resume(), timeout]); } finally { clearTimeout(timer); }
        }
        if (disposed || token !== enableToken) return report();
        if (ctx.state !== 'running') throw new Error('AudioContext not running: ' + ctx.state);
        blocked = false; enabled = true; reset();
        sync();
      } catch (e) {
        if (token === enableToken) { enabled = false; blocked = true; stopAll(); }
        diag('enable', e);
      }
      return report();
    }

    function seekReset() { if (!disposed) { reset(); sync(); } }

    function dispose() {
      if (disposed) return;
      disposed = true; enabled = false; epoch++; enableToken++;
      stopAll(); ended.clear(); queue.length = 0; pending.clear(); buffers.clear();
      const c = ctx; ctx = null; master = null;
      if (c) { try { c.close().catch(() => {}); } catch (e) { /* ignore */ } }
    }

    function report() {
      return {
        enabled, muted, blocked, disposed, epoch,
        contextState: ctx ? ctx.state : 'none',
        activeKeys: Array.from(voices.keys()),
        decodedCount: buffers.size,
        pendingCount: pending.size,
        failedAssets: Array.from(failed.keys()),
        diagnostics: diagnostics.slice(),
        mixing: { gain: GAIN, spatial: SPATIAL, original: false },
        rendering_complete: false,
        auditory_validation: 'NOT_RUN'
      };
    }

    return { enable, sync, seekReset, dispose, report };
  }
