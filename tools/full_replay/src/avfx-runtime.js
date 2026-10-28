// SPDX-License-Identifier: MIT
// Deterministic AVFX source-graph particle player for Three.js.
// Direct port of source-snapshot/avfx_player.gd + avfx_animation.gd.
// Bounded source-graph preview. NOT an original-game renderer certification and
// NOT a game-equivalence claim. The GD reference is not guaranteed game truth.
//
// Document schema: avfx_preview_pack.py compile_pack() (schema 1).
// Time unit: native AVFX frames. seek() always re-samples from scratch.
import * as THREE from 'three';

const MAX_FRAME = 1800;
const MAX_WORK = 16000;
const MAX_PARTICLES = 2048;
const MAX_DEPTH = 16;
const MAX_TIMELINE_CYCLES = 256;
const SUPPORTED_KINDS = [1, 2, 5, 8, 10, 12, 13];
const TAU = Math.PI * 2;

const CLIP_KILL = 1280067915;
const CLIP_RESET = 1414743378;
const CLIP_END = 541347397;
const CLIP_FADE_IN = 1229209926;
const CLIP_UNLOCK_LOOP = 1347177557;
const CLIP_TRIGGER = 541545044;
const CLIP_RANDOM_TRIGGER = 1196577874;

// Source rotation-order index -> three.js Euler order (same matrix convention as Godot's
// Basis.from_euler with [0,3,4,1,2,5] remap: XYZ, YZX, ZXY, XZY, YXZ, ZYX).
const EULER_ORDERS = ['XYZ', 'YZX', 'ZXY', 'XZY', 'YXZ', 'ZYX'];
const AXIS_LINKS = [{}, { Y: 'X', Z: 'X' }, { Y: 'X' }, { Z: 'X' }, { X: 'Y', Z: 'Y' }, { X: 'Y' }, { Z: 'Y' }, { X: 'Z', Y: 'Z' }, { X: 'Z' }, { Y: 'Z' }];

// ---------------------------------------------------------------------------
// small helpers (GDScript semantics where it matters)
// ---------------------------------------------------------------------------
const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);
const isEmpty = (o) => {
  if (o === null || o === undefined) return true;
  for (const _ in o) return false;
  return true;
};
const dget = (o, k, d) => (o !== null && o !== undefined && o[k] !== undefined ? o[k] : d);
const num = (v, d = 0) => (v === null || v === undefined || Number.isNaN(Number(v)) ? d : Number(v));
const int = (v, d = 0) => Math.trunc(num(v, d));
const fposmod = (x, y) => {
  let v = x % y;
  if ((v < 0 && y > 0) || (v > 0 && y < 0)) v += y;
  return v;
};
// GDScript str(float): integral values keep ".0".
const fmtFloat = (x) => (Number.isInteger(x) ? x.toFixed(1) : String(x));
export const srgbToLinear = (c) => {
  const v = Math.max(0, c);
  return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
};

function enabled(values, field) {
  let v = dget(values, field, undefined);
  if (isObj(v)) v = v.value;
  if (typeof v === 'boolean') return v;
  return typeof v === 'number' ? v === 1 : false;
}

// ---------------------------------------------------------------------------
// curve runtime (avfx_animation.gd). null === unsupported / malformed.
// ---------------------------------------------------------------------------
const validCurves = new WeakMap();

function curveIsValid(curve) {
  const keys = curve.keys;
  if (!Array.isArray(keys) || keys.length === 0) return false;
  for (let i = 0; i < keys.length; i++) {
    const k = keys[i];
    if (![0, 1, 2].includes(int(k.type, -1))) return false;
    if (i > 0 && Number(k.time) <= Number(keys[i - 1].time)) return false;
    if (!Array.isArray(k.data) || k.data.length < 3) return false;
    for (const n of k.data) if (!Number.isFinite(Number(n))) return false;
  }
  return isEmpty(curve.unknown_fields);
}

const keyValue = (key, rgb) => (rgb ? [Number(key.data[0]), Number(key.data[1]), Number(key.data[2])] : Number(key.data[2]));
const lerpValue = (l, r, u, rgb) => (rgb ? l.map((x, i) => x + (r[i] - x) * u) : l + (r - l) * u);

export function curveValue(curve, time) {
  if (!Number.isFinite(time) || !isObj(curve)) return null;
  let ok = validCurves.get(curve);
  if (ok === undefined) { ok = curveIsValid(curve); validCurves.set(curve, ok); }
  if (!ok) return null;
  const keys = curve.keys;
  const rgb = String(dget(curve, 'kind', 'scalar')) === 'rgb';
  const start = Number(keys[0].time);
  const end = Number(keys[keys.length - 1].time);
  let t = time;
  let cycles = 0;
  if (t < start || t > end) {
    const behavior = t < start ? curve.BvPr : curve.BvPo;
    if (behavior === null || behavior === undefined) return null;
    const b = int(behavior);
    if (b === 0) t = Math.min(Math.max(t, start), end);
    else if ((b === 1 || b === 2) && end > start) {
      cycles = Math.floor((t - start) / (end - start));
      t = start + fposmod(t - start, end - start);
      if (b === 1) cycles = 0;
    } else return null;
  }
  let result = null;
  for (let i = 0; i < keys.length; i++) {
    const ti = Number(keys[i].time);
    if (t === ti) { result = keyValue(keys[i], rgb); break; }
    if (i === 0 || t > ti) continue;
    const left = keys[i - 1];
    const right = keys[i];
    const x0 = Number(left.time);
    const x3 = Number(right.time);
    let u = (t - x0) / (x3 - x0);
    const leftType = int(left.type);
    if (leftType === 2) u = 0;
    else if (leftType === 0) {
      if (rgb) return null;
      const half = (x3 - x0) / 2;
      const x1 = x0 + Number(left.data[0]) * half;
      const x2 = x3 - Number(left.data[1]) * half;
      const a = x1 - x0;
      const b = x2 - x1;
      const c = x3 - x2;
      const qa = a - 2 * b + c;
      const qb = 2 * (b - a);
      let minimum = Math.min(a, c);
      if (qa > 0) {
        const critical = -qb / (2 * qa);
        if (critical > 0 && critical < 1) minimum = Math.min(minimum, (qa * critical + qb) * critical + a);
      }
      if (minimum < 0) return null;
      let low = 0;
      let high = 1;
      for (let n = 0; n < 48; n++) {
        const q = (low + high) / 2;
        const v = 1 - q;
        const x = v * v * v * x0 + 3 * v * v * q * x1 + 3 * v * q * q * x2 + q * q * q * x3;
        if (x < t) low = q; else high = q;
      }
      u = (low + high) / 2;
      u = u * u * (3 - 2 * u);
    }
    result = lerpValue(keyValue(left, rgb), keyValue(right, rgb), u, rgb);
    break;
  }
  if (result === null) return null;
  if (cycles !== 0) {
    const first = keyValue(keys[0], rgb);
    const last = keyValue(keys[keys.length - 1], rgb);
    result = rgb ? result.map((x, i) => x + (last[i] - first[i]) * cycles) : result + (last - first) * cycles;
  }
  return result;
}

// Portable preview PRNG (FNV-1a + integer mix); not the game's RNG.
export function unit(seed, channel, tick = 0) {
  const bytes = new TextEncoder().encode(`${seed}:${channel}:${tick}`);
  let bits = 2166136261;
  for (const byte of bytes) bits = Math.imul((bits ^ byte) >>> 0, 16777619) >>> 0;
  bits = Math.imul((bits ^ (bits >>> 16)) >>> 0, 0x45d9f3b) >>> 0;
  bits = Math.imul((bits ^ (bits >>> 16)) >>> 0, 0x45d9f3b) >>> 0;
  bits = (bits ^ (bits >>> 16)) >>> 0;
  return bits / 4294967296;
}

function randomValue(mode, seed, channel, time) {
  if (mode < 0 || mode > 5) return null;
  const n = unit(seed, channel, mode >= 3 ? Math.floor(time) : 0);
  switch (mode % 3) {
    case 0: return n * 2 - 1;
    case 1: return n;
    default: return -n;
  }
}

export function scalar(curve, randomCurve, time, seed, channel, defaultValue) {
  let result = isEmpty(curve) ? defaultValue : curveValue(curve, time);
  if (result === null) return null;
  if (!isEmpty(randomCurve)) {
    const amplitude = curveValue(randomCurve, time);
    if (amplitude === null) return null;
    if (amplitude !== 0) {
      const mode = dget(curve, 'RanT', dget(randomCurve, 'RanT', null));
      if (mode === null) return null;
      const n = randomValue(int(mode), seed, channel, time);
      if (n === null) return null;
      result += amplitude * n;
    }
  }
  return result;
}

// Returns THREE.Vector3 or null.
export function axes(data, time, seed, channel, defaultValue) {
  const curves = dget(data, 'axes', {});
  const raw = {};
  const randomAxes = {};
  for (const axis of ['X', 'Y', 'Z']) {
    const main = dget(curves, axis, {});
    const random = dget(curves, axis + 'R', {});
    const base = isEmpty(main) ? defaultValue : curveValue(main, time);
    const amplitude = isEmpty(random) ? 0 : curveValue(random, time);
    if (base === null || amplitude === null) return null;
    raw[axis] = base;
    randomAxes[axis] = amplitude;
  }
  const link = dget(data, 'ACT', 0);
  const randomLink = dget(data, 'ACTR', 0);
  if (link === null || randomLink === null || int(link) < 0 || int(link) >= AXIS_LINKS.length || int(randomLink) < 0 || int(randomLink) >= AXIS_LINKS.length) return null;
  const out = {};
  for (const axis of ['X', 'Y', 'Z']) {
    const mainAxis = AXIS_LINKS[int(link)][axis] ?? axis;
    const randomAxis = AXIS_LINKS[int(randomLink)][axis] ?? axis;
    const mainCurve = dget(curves, mainAxis, {});
    const mode = dget(mainCurve, 'RanT', dget(dget(curves, randomAxis + 'R', {}), 'RanT', null));
    let offset = 0;
    if (randomAxes[randomAxis] !== 0) {
      if (mode === null) return null;
      const draw = randomValue(int(mode), seed, `${channel}/${randomAxis}`, time);
      if (draw === null) return null;
      offset = randomAxes[randomAxis] * draw;
    }
    out[axis] = raw[mainAxis] + offset;
  }
  return new THREE.Vector3(out.X, out.Y, out.Z);
}

// Returns [r,g,b,a] or null.
export function colour(data, time, seed, channel) {
  const rgb = !isObj(data) || !('RGB' in data) ? [1, 1, 1] : curveValue(data.RGB, time);
  if (!Array.isArray(rgb)) return null;
  const alpha = scalar(dget(data, 'A', {}), dget(data, 'RanA', {}), time, seed, `${channel}/A`, 1);
  const brightness = scalar(dget(data, 'Bri', {}), dget(data, 'RBri', {}), time, seed, `${channel}/Bri`, 1);
  if (alpha === null || brightness === null) return null;
  const out = [0, 0, 0, 1];
  for (let i = 0; i < 4; i++) {
    const axis = 'RGBA'[i];
    const multiplier = scalar(dget(data, 'Scl' + axis, {}), i < 3 ? dget(data, 'Ran' + axis, {}) : {}, time, seed, `${channel}/${axis}`, 1);
    if (multiplier === null) return null;
    out[i] = (i < 3 ? srgbToLinear(rgb[i]) * brightness : alpha) * multiplier;
  }
  return out;
}

export function life(data, seed, channel) {
  if (isEmpty(data) || !dget(data, 'enabled', true)) return -1;
  const base = dget(data, 'Val', null);
  const amplitude = dget(data, 'ValR', null);
  if (base === null || amplitude === null) return null;
  if (Number(amplitude) === 0) return Number(base);
  const mode = dget(data, 'Type', null);
  if (mode === null) return null;
  const draw = randomValue(int(mode), seed, channel, 0);
  return draw === null ? null : Number(base) + Number(amplitude) * draw;
}

// ---------------------------------------------------------------------------
// matrix helpers (Matrix4 product order == Godot Transform3D product order)
// ---------------------------------------------------------------------------
const mul = (...ms) => ms.slice(1).reduce((acc, m) => acc.multiply(m), ms[0].clone());

function columns(m) {
  const e = m.elements;
  return [new THREE.Vector3(e[0], e[1], e[2]), new THREE.Vector3(e[4], e[5], e[6]), new THREE.Vector3(e[8], e[9], e[10])];
}

function basisScale(m) {
  const c = columns(m);
  const sign = Math.sign(m.determinant()) || 1;
  return new THREE.Vector3(c[0].length(), c[1].length(), c[2].length()).multiplyScalar(sign);
}

// Gram-Schmidt on columns, as Basis.orthonormalized().
function orthonormalColumns(m) {
  const [x, y0, z0] = columns(m);
  x.normalize();
  const y = y0.sub(x.clone().multiplyScalar(x.dot(y0))).normalize();
  const z = z0.sub(x.clone().multiplyScalar(x.dot(z0))).sub(y.clone().multiplyScalar(y.dot(z0))).normalize();
  return [x, y, z];
}

function setBasis(m, cols) {
  const e = m.elements;
  cols.forEach((c, j) => { e[4 * j] = c.x; e[4 * j + 1] = c.y; e[4 * j + 2] = c.z; });
}

const clearOrigin = (m) => { m.elements[12] = 0; m.elements[13] = 0; m.elements[14] = 0; };

// ---------------------------------------------------------------------------
// shared geometry builders
// ---------------------------------------------------------------------------
function makeGeometry(positions, uvs, colors, indices) {
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.BufferAttribute(positions, 3));
  g.setAttribute('uv', new THREE.BufferAttribute(uvs, 2));
  g.setAttribute('aColor', new THREE.BufferAttribute(colors, 4));
  g.setIndex(new THREE.BufferAttribute(indices, 1));
  return g;
}

// Godot QuadMesh(size 1): XY plane, UV (0,0) at top-left.
function makeQuad() {
  return makeGeometry(
    new Float32Array([-0.5, -0.5, 0, 0.5, -0.5, 0, 0.5, 0.5, 0, -0.5, 0.5, 0]),
    new Float32Array([0, 1, 1, 1, 1, 0, 0, 0]),
    new Float32Array(16).fill(1),
    new Uint16Array([0, 1, 2, 0, 2, 3]),
  );
}

// ---------------------------------------------------------------------------
// shader (port of the Godot preview shader; UV math unchanged)
// ---------------------------------------------------------------------------
const VERTEX_SHADER = `
attribute vec4 aColor;
varying vec2 vUv0;
varying vec4 vColor;
void main(){ vUv0 = uv; vColor = aColor; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }`;

const FRAGMENT_SHADER = `
uniform vec4 particleColor;
uniform sampler2D baseTexture;
uniform bool textured;
uniform bool colorToAlpha;
uniform bool flipV;
uniform vec2 uvScale;
uniform vec2 uvScroll;
uniform float uvRotation;
varying vec2 vUv0;
varying vec4 vColor;
void main(){
  vec2 p = (vUv0 - vec2(0.5)) * uvScale;
  float c = cos(uvRotation); float s = sin(uvRotation);
  vec2 uv = mat2(vec2(c, s), vec2(-s, c)) * p + vec2(0.5) + uvScroll;
  if (flipV) uv.y = 1.0 - uv.y;
  vec4 ink = textured ? texture2D(baseTexture, uv) : vec4(1.0);
  if (colorToAlpha) ink.a *= max(ink.r, max(ink.g, ink.b));
  gl_FragColor = vec4(particleColor.rgb * vColor.rgb * ink.rgb, clamp(particleColor.a * vColor.a * ink.a, 0.0, 1.0));
  #include <colorspace_fragment>
}`;

// ---------------------------------------------------------------------------
// player
// ---------------------------------------------------------------------------
export class AvfxRuntime {
  /**
   * @param {object} document compiled schema-1 document (avfx_preview_pack.py)
   * @param {Map<string,THREE.Texture>|Object<string,THREE.Texture>} textureMap keyed by game texture path
   * @param {number} seed
   * @param {{binderResolver?:(spec:object)=>number}} [options] optional; returns a binder index (>=0) or -1
   */
  constructor(document, textureMap, seed = 1, options = {}) {
    this.document = document;
    this.textureMap = textureMap ?? new Map();
    this.seed = int(seed, 1);
    this.options = options;
    this.root = new THREE.Group();
    this.root.name = 'AvfxRuntime';
    this.diagnostics = new Set();
    this.frame = 0;
    this.lastParticles = [];
    this.triggers = [];
    this.work = 0;
    this.valid = false;
    this.binders = new Map(); // binder index -> THREE.Group (parent drives its transform later)
    this._draws = new Map(); // particle key -> { mesh, material, ownsGeometry }
    this._geometryCache = new Map(); // immutable shared geometry
    this._materialDefs = new Map(); // Ptcl index -> immutable material description
    this._disposed = false;

    if (!isObj(document) || document.schema !== 1 || !isObj(document.groups)) {
      this.diagnostics.add('invalid_document');
      return;
    }
    this.valid = true;
    this.diagnostics.add('experimental_preview_not_game_equivalence');
    for (const item of document.unsupported ?? []) this.diagnostics.add(`source_unsupported/${item.reason}`);
    for (const group of ['Efct']) {
      if ((document.groups[group] ?? []).length) this.diagnostics.add(`unsupported_group/${group}`);
    }
  }

  /** Queue a trigger_timeline event (slot 0..11) at a native frame. */
  trigger(slot, atFrame) {
    if (!(slot >= 0 && slot < 12) || !Number.isFinite(atFrame) || atFrame < 0 || atFrame > MAX_FRAME) return false;
    this.triggers.push({ slot, frame: atFrame });
    return true;
  }

  /** Get (creating on demand) the group a parent can transform for a binder index. */
  getBinderGroup(index) {
    let group = this.binders.get(index);
    if (!group) {
      group = new THREE.Group();
      group.name = `AvfxBinder${index}`;
      this.binders.set(index, group);
      this.root.add(group);
    }
    return group;
  }

  /** Deterministic: depends only on (document, seed, triggers, nativeFrame). Returns false on invalid/budget. */
  seek(nativeFrame) {
    if (this._disposed || !this.valid) return false;
    const particles = this._sampleAt(nativeFrame);
    if (this.diagnostics.has('budget_exceeded') || this.diagnostics.has('invalid_frame')) {
      // Unlike the GD reference (keeps stale draws) clear, so output never depends on seek history.
      this.lastParticles = [];
      this._syncDraws([]);
      return false;
    }
    this.frame = nativeFrame;
    this.lastParticles = particles;
    this._syncDraws(particles);
    return true;
  }

  report() {
    return {
      source_sha256: this.document?.source_sha256 ?? '',
      frame: this.frame,
      seed: this.seed,
      particles: this.lastParticles.length,
      work: this.work,
      diagnostics: [...this.diagnostics],
      source_unsupported: this.document?.unsupported ?? [],
      rendering_complete: false,
      gameplay_eligible: false,
    };
  }

  dispose() {
    if (this._disposed) return;
    this._disposed = true;
    this._syncDraws([]);
    for (const g of this._geometryCache.values()) g?.dispose();
    this._geometryCache.clear();
    this._materialDefs.clear();
    this.root.removeFromParent();
    this.root.clear();
    this.binders.clear();
    this.lastParticles = [];
  }

  // ------------------------------------------------------------ sampling
  _sampleAt(atFrame) {
    this.diagnostics.delete('invalid_frame');
    this.diagnostics.delete('budget_exceeded');
    this.work = 0;
    if (!Number.isFinite(atFrame) || atFrame < 0 || atFrame > MAX_FRAME) {
      this.diagnostics.add('invalid_frame');
      return [];
    }
    const result = [];
    const keys = new Set();
    const schedulers = this.document.groups.Schd ?? [];
    for (const scheduler of schedulers) {
      let slot = 0;
      for (const item of scheduler.items ?? []) {
        const values = item.values ?? {};
        if (item.role === 'trigger_timeline') {
          for (const event of this.triggers) {
            if (event.slot === slot) this._schedule(values, event.frame, atFrame, `s${scheduler.index}/t${slot}/${fmtFloat(event.frame)}`, result, keys);
          }
          slot++;
        } else {
          this._schedule(values, 0, atFrame, `s${scheduler.index}/${item.source_index}`, result, keys);
        }
      }
    }
    return this.diagnostics.has('budget_exceeded') ? [] : result;
  }

  _node(group, index) {
    const nodes = this.document.groups[group] ?? [];
    if (index < 0 || index >= nodes.length) { this.diagnostics.add(`invalid_reference/${group}`); return null; }
    return nodes[index];
  }

  _tick() {
    this.work++;
    if (this.work > MAX_WORK) { this.diagnostics.add('budget_exceeded'); return false; }
    return true;
  }

  _schedule(values, start, now, key, result, keys) {
    if (!enabled(values, 'bEna') || int(values.TlNo, -1) < 0) return;
    const birth = start + num(values.StTm);
    if (now < birth) return;
    const node = this._node('TmLn', int(values.TlNo));
    if (!node) return;
    for (const item of node.items ?? []) {
      const v = item.values ?? {};
      if (!enabled(v, 'bEna')) continue;
      const clipIndex = int(v.ClNo ?? -1, -1);
      if (clipIndex >= 0) { this._clip(node, clipIndex, birth + num(v.StTm), now); continue; }
      const emitter = int(v.EmNo, -1);
      if (emitter < 0) continue;
      this._activeBinder = num(v.BdNo,-1)>=0 ? v.BdNo : num(node.values?.BnNo,-1);
      const itemStart = num(v.StTm);
      const itemEnd = num(v.EdTm, -1);
      this._scheduleItem(emitter, birth, itemStart, itemEnd, now, `${key}/i${item.source_index}`, result, keys);
      const loopStart = num(node.values?.LpSt);
      const loopEnd = num(node.values?.LpEd);
      if (loopEnd <= loopStart || itemStart < loopStart || itemStart >= loopEnd) continue;
      const period = loopEnd - loopStart;
      let cycle = 1;
      while (cycle <= MAX_TIMELINE_CYCLES) {
        const shifted = itemStart + period * cycle;
        if (birth + shifted > now) break;
        if (!this._tick()) return;
        this._scheduleItem(emitter, birth, shifted, itemEnd >= 0 ? itemEnd + period * cycle : -1, now, `${key}/i${item.source_index}/c${cycle}`, result, keys);
        cycle++;
      }
      if (cycle > MAX_TIMELINE_CYCLES && birth + itemStart + period * cycle <= now) this.diagnostics.add('timeline_cycle_limit');
    }
  }

  _scheduleItem(emitter, timelineBirth, itemStart, itemEnd, now, key, result, keys) {
    const emitterBirth = timelineBirth + itemStart;
    if (now < emitterBirth) return;
    const stop = itemEnd >= 0 ? timelineBirth + itemEnd : Infinity;
    this._emit(emitter, emitterBirth, now, [], key, result, keys, 0, stop, {});
  }

  // Clips need runtime state this stateless sampler does not model: diagnose, never emulate.
  _clip(timeline, index, at, now) {
    const clips = timeline.clips ?? [];
    if (index < 0 || index >= clips.length) { this.diagnostics.add('invalid_timeline_clip_reference'); return; }
    if (now < at) return;
    const kind = int(clips[index].type);
    if (kind === CLIP_KILL || kind === CLIP_END) this.diagnostics.add('timeline_clip_stop_requires_runtime_state');
    else if (kind === CLIP_RESET) this.diagnostics.add('timeline_clip_reset_requires_runtime_state');
    else if (kind === CLIP_UNLOCK_LOOP) this.diagnostics.add('timeline_clip_unlock_requires_runtime_state');
    else if (kind === CLIP_FADE_IN) this.diagnostics.add('timeline_clip_fade_requires_runtime_state');
    else if (kind === CLIP_TRIGGER || kind === CLIP_RANDOM_TRIGGER) this.diagnostics.add('timeline_clip_trigger_requires_runtime_state');
    else this.diagnostics.add(`timeline_clip_unknown/${kind}`);
  }

  _local(node, age) {
    const start = num(node.values?.LpSt);
    const end = num(node.values?.LpEd);
    return end > start && age >= end ? start + fposmod(age - start, end - start) : age;
  }

  _emit(index, birth, now, ancestors, key, result, keys, depth, stop, influence) {
    if (depth >= MAX_DEPTH || !this._tick()) { this.diagnostics.add('budget_exceeded'); return; }
    const node = this._node('Emit', index);
    if (!node) return;
    const lifeValue = life(node.life ?? {}, this.seed, key);
    if (lifeValue === null) { this.diagnostics.add('life'); return; }
    if (now - birth < 0) return;
    const looped = num(node.values?.LpEd) > num(node.values?.LpSt);
    let end = Math.min(now, stop);
    if (lifeValue >= 0 && !looped) end = Math.min(end, birth + lifeValue);
    const chain = [...ancestors, { group: 'Emit', index, birth, influence, key }];
    const emitterType = int(node.values?.EVT, -1);
    if (emitterType !== 0 && emitterType !== 5) { this.diagnostics.add(`emitter_type/${emitterType}`); return; }
    for (const item of node.items ?? []) {
      const v = item.values ?? {};
      if (!enabled(v, 'bEnb')) continue;
      let generation = Math.max(0, num(v.CrTm, 1) - 1);
      let eventIndex = 0;
      while (birth + generation <= end) {
        if (!this._tick()) return;
        const clock = this._local(node, generation);
        const interval = scalar(dget(node.curves, 'CrI', {}), dget(node.curves, 'CrIR', {}), clock, this.seed, `${key}/interval`, 1);
        const count = scalar(dget(node.curves, 'CrC', {}), dget(node.curves, 'CrCR', {}), clock, this.seed, `${key}/count`, 1);
        if (interval === null || count === null || interval <= 0 || count < 0) { this.diagnostics.add('emission_curve'); break; }
        const chance = num(v.CrPr, 100);
        if (int(v.CrCn, 1) < 0 || chance < 0 || chance > 100) { this.diagnostics.add('invalid_emission_item'); return; }
        const amount = Math.floor(count) * int(v.CrCn, 1);
        if (amount > MAX_PARTICLES) { this.diagnostics.add('budget_exceeded'); return; }
        for (let number = 0; number < amount; number++) {
          if (!this._tick()) return;
          const childKey = `${key}/${int(item.source_index)}/${eventIndex}/${number}`;
          if (unit(this.seed, `${childKey}/chance`) * 100 >= chance) continue;
          const childBirth = birth + generation + num(v.GenD) * (enabled(v, 'bGD') ? number : 1);
          if (childBirth > now) continue;
          const childIndex = int(v.TgtB, -1);
          if (childIndex < 0) continue;
          const childInfluence = { ...v };
          if (emitterType === 5) {
            childInfluence.emission_model = int(node.data?.MdNo, -1);
            childInfluence.emission_number = number;
            childInfluence.emission_method = int(node.data?.GeMT, -1);
          }
          if (item.role === 'child_emitter') this._emit(childIndex, childBirth, now, chain, childKey, result, keys, depth + 1, stop, childInfluence);
          else if (item.role === 'child_particle') this._particle(childIndex, childBirth, now, chain, childKey, result, keys, childInfluence);
        }
        eventIndex++;
        generation += Math.max(0.01, interval);
      }
    }
  }

  _particle(index, birth, now, ancestors, key, result, keys, influence) {
    if (!this._tick()) return;
    const node = this._node('Ptcl', index);
    if (!node) return;
    const age = now - birth + num(influence.StFr);
    let lifeValue = life(node.life ?? {}, this.seed, key);
    if (enabled(influence, 'bOvr')) lifeValue = num(influence.OvrV) + unit(this.seed, `${key}/override`) * num(influence.OvrR);
    if (lifeValue === null) { this.diagnostics.add('life'); return; }
    const looped = num(node.values?.LpEd) > num(node.values?.LpSt);
    if (age < 0 || (!looped && lifeValue >= 0 && age >= lifeValue)) return;
    const kind = int(node.values?.PrVT, -1);
    if (!SUPPORTED_KINDS.includes(kind)) { this.diagnostics.add(`particle_type/${kind}`); return; }
    const chain = [...ancestors, { group: 'Ptcl', index, birth, influence, key }];
    const pose = this._chainTransform(chain, now);
    const tint = this._chainColor(chain, now);
    if (!pose || !tint) return;
    if (result.length >= MAX_PARTICLES) { this.diagnostics.add('budget_exceeded'); return; }
    if (keys.has(key)) { this.diagnostics.add('duplicate_particle_key'); return; } // never emit twice
    keys.add(key);
    const spec = { key, index, kind, age: this._local(node, age), transform: pose, color: tint, binder: this._activeBinder ?? -1 };
    if (typeof this.options.binderResolver === 'function') spec.binder = int(this.options.binderResolver(spec), -1);
    result.push(spec);
  }

  // ------------------------------------------------------------ transforms / colour
  _chainTransform(chain, atFrame) {
    if (chain.length === 0) return new THREE.Matrix4();
    const link = chain[chain.length - 1];
    const node = this._node(link.group, link.index);
    if (!node) return null;
    const influence = link.influence;
    const age = this._local(node, Math.max(0, atFrame - link.birth));
    const nodeAxes = node.axes ?? {};
    const position = axes(dget(nodeAxes, 'Pos', {}), age, this.seed, `${link.key}/Pos`, 0);
    const rotation = axes(dget(nodeAxes, 'Rot', {}), age, this.seed, `${link.key}/Rot`, 0);
    const scaleValue = axes(dget(nodeAxes, 'Scl', {}), age, this.seed, `${link.key}/Scl`, 1);
    if (!position || !rotation || !scaleValue) { this.diagnostics.add('transform_curve'); return null; }
    const rotationOrder = int(node.values?.[link.group === 'Emit' ? 'ROT' : 'RoOT'], 0);
    if (rotationOrder < 0 || rotationOrder > 5) { this.diagnostics.add('rotation_order'); return null; }
    const R = new THREE.Matrix4().makeRotationFromEuler(new THREE.Euler(rotation.x, rotation.y, rotation.z, EULER_ORDERS[rotationOrder]));
    const S = new THREE.Matrix4().makeScale(scaleValue.x, scaleValue.y, scaleValue.z);
    const T = new THREE.Matrix4().makeTranslation(position.x, position.y, position.z);
    let local;
    switch (int(node.values?.CCOT, 0)) {
      case 0: local = mul(T, R, S); break;
      case 1: local = mul(R, S, T); break;
      case 2: local = mul(S, T, R); break;
      case 3: local = mul(S, R, T); break;
      case 4: local = mul(R, T, S); break;
      case 5: local = mul(T, S, R); break;
      default: this.diagnostics.add('coordinate_order'); return null;
    }
    if (chain.length === 1) return local;
    const mode = int(influence.PICd, 2);
    const parentTime = [0, 1, 3, 5].includes(mode) ? link.birth : atFrame;
    let inherited = this._chainTransform(chain.slice(0, -1), parentTime);
    if (!inherited) return null;
    if (mode === 6) inherited = new THREE.Matrix4();
    else if (mode === 4 || mode === 5 || mode === 7) clearOrigin(inherited);
    else if (!(mode >= 0 && mode <= 3)) { this.diagnostics.add('parent_influence'); return null; }
    if (mode === 1 || mode === 7) {
      const s = enabled(influence, 'ICbS') ? basisScale(inherited) : new THREE.Vector3(1, 1, 1);
      const r = enabled(influence, 'ICbR') ? orthonormalColumns(inherited) : [new THREE.Vector3(1, 0, 0), new THREE.Vector3(0, 1, 0), new THREE.Vector3(0, 0, 1)];
      // Godot Basis.scaled(): rows multiplied by scale, i.e. diag(s) * R.
      const scaled = [0, 1, 2].map((j) => new THREE.Vector3(r[j].x * s.x, r[j].y * s.y, r[j].z * s.z));
      setBasis(inherited, scaled);
      if (!enabled(influence, 'ICbP')) clearOrigin(inherited);
    }
    if ('emission_model' in influence) {
      const models = this.document.models ?? [];
      const modelIndex = int(influence.emission_model);
      if (modelIndex < 0 || modelIndex >= models.length) { this.diagnostics.add('emission_model'); return null; }
      const vertices = models[modelIndex].emission_vertices ?? [];
      const ordering = models[modelIndex].emission_order ?? [];
      const method = int(influence.emission_method, -1);
      if (method !== 3 || vertices.length === 0) { this.diagnostics.add(`model_emission_method/${method}`); return null; }
      let vertexIndex = int(influence.emission_number) % vertices.length;
      if (ordering.length) vertexIndex = int(ordering[vertexIndex % ordering.length]);
      if (vertexIndex < 0 || vertexIndex >= vertices.length) { this.diagnostics.add('emission_order'); return null; }
      const p = vertices[vertexIndex].position;
      local.elements[12] += p[0]; local.elements[13] += p[1]; local.elements[14] += p[2];
    }
    return inherited.multiply(local);
  }

  _chainColor(chain, atFrame) {
    if (chain.length === 0) return [1, 1, 1, 1];
    const link = chain[chain.length - 1];
    const node = this._node(link.group, link.index);
    if (!node) return null;
    const tint = colour(node.color ?? {}, this._local(node, Math.max(0, atFrame - link.birth)), this.seed, `${link.key}/color`);
    if (!tint) { this.diagnostics.add('color_curve'); return null; }
    const mode = int(link.influence.PICo, 0);
    if (chain.length > 1 && mode !== 0) {
      const parent = this._chainColor(chain.slice(0, -1), mode === 1 ? link.birth : atFrame);
      if (!parent) return null;
      for (let i = 0; i < 4; i++) tint[i] *= parent[i];
    }
    return tint;
  }

  // ------------------------------------------------------------ geometry
  /** Immutable shared geometry for sprites/models. Returns null when nothing drawable exists. */
  _sharedGeometry(spec) {
    const node = this._node('Ptcl', spec.index);
    if (!node) return null;
    let modelIndex = -1;
    if (spec.kind === 5) {
      const list = node.data?.MdNo ?? [];
      if (list.length) modelIndex = int(list[0]);
    } else if (spec.kind === 13) modelIndex = int(node.data?.MNO, -1);
    const models = this.document.models ?? [];
    const cacheKey = modelIndex >= 0 ? `model${modelIndex}` : `kind${spec.kind}`;
    if (this._geometryCache.has(cacheKey)) return this._geometryCache.get(cacheKey);
    let geometry = null;
    if (modelIndex >= 0 && modelIndex < models.length) {
      geometry = this._modelGeometry(models[modelIndex], modelIndex);
    } else if (spec.kind === 1 || spec.kind === 2 || spec.kind === 8) {
      geometry = makeQuad();
    } else {
      this.diagnostics.add('model_selection');
    }
    this._geometryCache.set(cacheKey, geometry);
    return geometry;
  }

  _modelGeometry(source, modelIndex) {
    const vs = source.vertices ?? [];
    const tris = source.triangles ?? [];
    if (!vs.length || !tris.length) { this.diagnostics.add(`empty_model/${modelIndex}`); return null; }
    const positions = new Float32Array(vs.length * 3);
    const uvs = new Float32Array(vs.length * 2);
    const colors = new Float32Array(vs.length * 4);
    vs.forEach((v, i) => {
      positions.set([v.position[0], v.position[1], v.position[2]], i * 3);
      uvs.set([v.uv[0][0], v.uv[0][1]], i * 2); // source UV set 0, unmodified
      colors.set([v.color[0] / 255, v.color[1] / 255, v.color[2] / 255, v.color[3] / 255], i * 4);
    });
    const indices = [];
    for (const face of tris) {
      for (const idx of face) {
        if (!(idx >= 0 && idx < vs.length)) { this.diagnostics.add(`model_index_out_of_range/${modelIndex}`); return null; }
        indices.push(int(idx));
      }
    }
    return makeGeometry(positions, uvs, colors, new Uint32Array(indices));
  }

  /** Per-frame disc/ring geometry (kind 12); owned by the draw, disposed when replaced. */
  _discGeometry(spec) {
    const node = this._node('Ptcl', spec.index);
    if (!node) return null;
    const data = node.data ?? {};
    const v = {};
    for (const field of ['Ang', 'WB', 'WE', 'RB', 'RE', 'HBI', 'HEI', 'HBO', 'HEO']) {
      const value = scalar(dget(data, field, {}), dget(data, field + 'R', {}), spec.age, this.seed, `${spec.key}/disc/${field}`, field === 'Ang' ? TAU : 0);
      if (value === null) { this.diagnostics.add('disc_curve'); return null; }
      v[field] = value;
    }
    const segments = int(data.PCnV);
    const radial = int(data.PCnU);
    if (segments < 1 || segments > 256 || radial < 1 || radial > 32 || Math.abs(v.Ang) > TAU * 16) { this.diagnostics.add('disc_budget'); return null; }
    const inner = colour(dget(data, 'CEI', {}), spec.age, this.seed, `${spec.key}/inner`);
    const outer = colour(dget(data, 'CEO', {}), spec.age, this.seed, `${spec.key}/outer`);
    if (!inner || !outer) { this.diagnostics.add('disc_curve'); return null; }
    const count = (segments + 1) * (radial + 1);
    const positions = new Float32Array(count * 3);
    const uvs = new Float32Array(count * 2);
    const colors = new Float32Array(count * 4);
    const lerp = (a, b, t) => a + (b - a) * t;
    let n = 0;
    for (let i = 0; i <= segments; i++) {
      const u = i / segments;
      const angle = v.Ang * u;
      const radius = lerp(v.RB, v.RE, u);
      const width = lerp(v.WB, v.WE, u);
      for (let j = 0; j <= radial; j++) {
        const t = j / radial;
        const r = radius + width * (t - 0.5);
        const h = lerp(lerp(v.HBI, v.HEI, u), lerp(v.HBO, v.HEO, u), t);
        positions.set([Math.cos(angle) * r, h, Math.sin(angle) * r], n * 3);
        uvs.set([u, t], n * 2);
        for (let c = 0; c < 4; c++) colors[n * 4 + c] = lerp(inner[c], outer[c], t);
        n++;
      }
    }
    const indices = new Uint32Array(segments * radial * 6);
    let k = 0;
    for (let i = 0; i < segments; i++) {
      for (let j = 0; j < radial; j++) {
        const a = i * (radial + 1) + j;
        const b = a + radial + 1;
        indices.set([a, b, a + 1, a + 1, b, b + 1], k);
        k += 6;
      }
    }
    return makeGeometry(positions, uvs, colors, indices);
  }

  // ------------------------------------------------------------ materials
  /** Immutable per-Ptcl-node description (TC1 base texture only; other layers are unsupported). */
  _materialDef(index) {
    if (this._materialDefs.has(index)) return this._materialDefs.get(index);
    const node = this._node('Ptcl', index);
    const first = node?.materials?.TC1 ?? {};
    const mode = int(node?.values?.RMT, 0);
    if (mode !== 0 && mode !== 1 && mode !== 2) this.diagnostics.add(`blend_mode/${mode}`);
    const list = first.TLst ?? [];
    const texIndex = int(first.TxNo ?? (list.length ? list[0] : -1), -1);
    let texture = null;
    if (int(first.bEna, 0) !== 0) {
      const names = this.document.textures ?? [];
      if (texIndex >= 0 && texIndex < names.length) {
        const name = String(names[texIndex]);
        texture = (this.textureMap instanceof Map ? this.textureMap.get(name) : this.textureMap?.[name]) ?? null;
        if (!texture) this.diagnostics.add(`missing_texture/${texIndex}`);
        else if (texture.wrapS !== THREE.RepeatWrapping || texture.wrapT !== THREE.RepeatWrapping) this.diagnostics.add(`texture_wrap_not_repeat/${texIndex}`);
      }
    }
    const def = { blendMode: mode, texture, colorToAlpha: int(first.bC2A, 0) !== 0, flipV: !!texture?.flipY, uvSet: int(first.UvSN, 0) };
    this._materialDefs.set(index, def);
    return def;
  }

  /** Fresh per-instance material (own uniforms, shared texture reference). */
  _createMaterial(def) {
    const material = new THREE.ShaderMaterial({
      vertexShader: VERTEX_SHADER,
      fragmentShader: FRAGMENT_SHADER,
      uniforms: {
        particleColor: { value: new THREE.Vector4(1, 1, 1, 1) },
        baseTexture: { value: def.texture },
        textured: { value: !!def.texture },
        colorToAlpha: { value: def.colorToAlpha },
        flipV: { value: def.flipV },
        uvScale: { value: new THREE.Vector2(1, 1) },
        uvScroll: { value: new THREE.Vector2(0, 0) },
        uvRotation: { value: 0 },
      },
      transparent: true,
      depthWrite: false,
      side: THREE.DoubleSide,
    });
    if (def.blendMode === 2) material.blending = THREE.AdditiveBlending;
    else if (def.blendMode === 1) {
      // Godot blend_mul: src*dst + dst*(1-src.a)
      material.blending = THREE.CustomBlending;
      material.blendEquation = THREE.AddEquation;
      material.blendSrc = THREE.DstColorFactor;
      material.blendDst = THREE.OneMinusSrcAlphaFactor;
    } else material.blending = THREE.NormalBlending;
    return material;
  }

  _animateMaterial(material, spec, def) {
    const u = material.uniforms;
    const c = spec.color;
    // particle_color is source_color in the GD shader: sRGB -> linear, re-encoded on output.
    u.particleColor.value.set(srgbToLinear(c[0]), srgbToLinear(c[1]), srgbToLinear(c[2]), c[3]);
    const node = this._node('Ptcl', spec.index);
    const sets = node?.uv_sets ?? [];
    if (def.uvSet < 0 || def.uvSet >= sets.length) return;
    const uv = sets[def.uvSet];
    if (int(uv.CUvT, 0) !== 0) { this.diagnostics.add('pixel_uv'); return; }
    // UV uses AxisConnect2 (0,1,2) -> AxisConnect3 indices [0,2,5].
    const remap = (data) => {
      const copy = { ...data };
      for (const tag of ['ACT', 'ACTR']) {
        const link = int(copy[tag], 0);
        if (link !== 0 && link !== 1 && link !== 2) return null;
        copy[tag] = [0, 2, 5][link];
      }
      return copy;
    };
    const scaleData = remap(dget(uv, 'Scl', {}));
    const scrollData = remap(dget(uv, 'Scr', {}));
    if (!scaleData || !scrollData) { this.diagnostics.add('uv_axis_connect'); return; }
    const scaling = axes(scaleData, spec.age, this.seed, `${spec.key}/uv_scale`, 1);
    const scrolling = axes(scrollData, spec.age, this.seed, `${spec.key}/uv_scroll`, 0);
    const rotating = scalar(dget(uv, 'Rot', {}), dget(uv, 'RotR', {}), spec.age, this.seed, `${spec.key}/uv_rotation`, 0);
    if (!scaling || !scrolling || rotating === null) { this.diagnostics.add('uv_curve'); return; }
    u.uvScale.value.set(scaling.x, scaling.y);
    u.uvScroll.value.set(scrolling.x, scrolling.y);
    u.uvRotation.value = rotating;
  }

  // ------------------------------------------------------------ scene sync
  _removeDraw(key) {
    const draw = this._draws.get(key);
    if (!draw) return;
    draw.mesh.removeFromParent();
    draw.material.dispose();
    if (draw.ownsGeometry) draw.mesh.geometry.dispose();
    this._draws.delete(key);
  }

  _syncDraws(particles) {
    const visible = new Set();
    for (const spec of particles) {
      const isDisc = spec.kind === 12;
      const geometry = isDisc ? this._discGeometry(spec) : this._sharedGeometry(spec);
      if (!geometry) { this._removeDraw(spec.key); continue; }
      visible.add(spec.key);
      const def = this._materialDef(spec.index);
      let draw = this._draws.get(spec.key);
      if (!draw) {
        const material = this._createMaterial(def);
        const mesh = new THREE.Mesh(geometry, material);
        mesh.matrixAutoUpdate = false;
        mesh.frustumCulled = false; // disc geometry changes per frame
        mesh.name = spec.key;
        draw = { mesh, material, ownsGeometry: isDisc };
        this._draws.set(spec.key, draw);
      } else if (isDisc) {
        draw.mesh.geometry.dispose();
        draw.mesh.geometry = geometry;
      }
      const parent = spec.binder >= 0 ? this.getBinderGroup(spec.binder) : this.root;
      if (draw.mesh.parent !== parent) parent.add(draw.mesh);
      draw.mesh.matrix.copy(spec.transform);
      draw.mesh.matrixWorldNeedsUpdate = true;
      this._animateMaterial(draw.material, spec, def);
    }
    for (const key of [...this._draws.keys()]) if (!visible.has(key)) this._removeDraw(key);
  }
}
