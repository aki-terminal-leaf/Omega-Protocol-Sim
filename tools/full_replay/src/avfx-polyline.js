// SPDX-License-Identifier: MIT
// Bounded AVFX type-6 (PrVT=6, Polyline) RECONSTRUCTION for the Three.js AvfxRuntime.
// Not the original particle implementation and NOT a game-equivalence claim.
// Only parent-supplied, endpoint-connected polylines are drawn:
//   options.polylineEndpoints(spec) -> {start, end, camera} (THREE.Vector3, runtime ROOT LOCAL) | null
// The screen-space ribbon orientation is a declared approximation. Source fields that
// are not reproduced (bSpl, bLcl, bEdg, bNtB, BWpT, LnCT, NBBA, PnED, Len) are diagnosed only.
import * as THREE from 'three';
import { scalar, colour, life, unit } from './avfx-runtime.js';

const MAX_PARTICLES = 2048;
const MAX_POINTS = 64;
const EPSILON = 1e-4;
const INSTALLED = Symbol.for('avfx.polyline.installed');
const UNREPRODUCED = ['bSpl', 'bLcl', 'bEdg', 'bNtB', 'BWpT', 'LnCT', 'NBBA'];

const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);
const isEmpty = (o) => {
  if (o === null || o === undefined) return true;
  for (const _ in o) return false;
  return true;
};
const num = (v, d = 0) => (v === null || v === undefined || Number.isNaN(Number(v)) ? d : Number(v));
const int = (v, d = 0) => Math.trunc(num(v, d));
const enabled = (values, field) => {
  let v = values?.[field];
  if (isObj(v)) v = v.value;
  if (typeof v === 'boolean') return v;
  return typeof v === 'number' ? v === 1 : false;
};
const finiteVec = (v) => !!v && Number.isFinite(v.x) && Number.isFinite(v.y) && Number.isFinite(v.z);

function polyDraws(rt) {
  if (!rt._polyDraws) rt._polyDraws = new Map(); // particle key -> { mesh, material }
  return rt._polyDraws;
}

function removePolyDraw(rt, key) {
  const draw = polyDraws(rt).get(key);
  if (!draw) return;
  draw.mesh.removeFromParent();
  draw.material.dispose();
  draw.mesh.geometry.dispose();
  polyDraws(rt).delete(key);
}

function clearPolyDraws(rt) {
  for (const key of [...polyDraws(rt).keys()]) removePolyDraw(rt, key);
}

// ---------------------------------------------------------------------------
// source curve sampling. Returns null (with diagnostic) when anything is missing/invalid.
// ---------------------------------------------------------------------------
function sampleWidths(rt, data, spec) {
  const out = {};
  for (const field of ['Wd', 'WdB', 'WdC', 'WdE']) {
    // Existing compiler omits these; never substitute a default width.
    if (isEmpty(data[field])) { rt.diagnostics.add(`polyline_missing_data/${field}`); return null; }
    const value = scalar(data[field], data[field + 'R'] ?? {}, spec.age, rt.seed, `${spec.key}/polyline/${field}`, 0);
    if (value === null || !Number.isFinite(value)) { rt.diagnostics.add('polyline_curve'); return null; }
    out[field] = Math.max(0, value);
  }
  return out;
}

function sampleColours(rt, data, spec) {
  const out = {};
  for (const field of ['ColB', 'ColC', 'ColE']) {
    if (isEmpty(data[field])) {
      rt.diagnostics.add(`polyline_color_missing_neutral_white/${field}`);
      out[field] = [1, 1, 1, 1];
      continue;
    }
    const value = colour(data[field], spec.age, rt.seed, `${spec.key}/polyline/${field}`);
    if (!value || !value.every(Number.isFinite)) { rt.diagnostics.add('polyline_curve'); return null; }
    out[field] = value;
  }
  return out;
}

// ---------------------------------------------------------------------------
// geometry: segmented camera-facing ribbon, attributes match the material shaders.
// ---------------------------------------------------------------------------
function buildRibbon(rt, spec, start, end, camera) {
  const node = rt._node('Ptcl', spec.index);
  const data = node?.data;
  if (!isObj(data)) { rt.diagnostics.add('polyline_missing_data'); return null; }
  if (!enabled(data, 'bCtg')) { rt.diagnostics.add('polyline_not_endpoint_connected'); return null; }
  for (const field of UNREPRODUCED) {
    const v = data[field];
    if (v !== undefined && v !== null && num(isObj(v) ? v.value : v, 1) !== 0) rt.diagnostics.add(`polyline_field_not_reproduced/${field}`);
  }
  if (num(data.PnED) !== 0 && data.PnED !== undefined) rt.diagnostics.add('polyline_field_not_reproduced/PnED');
  if (!isEmpty(data.Len)) rt.diagnostics.add('polyline_len_ignored_endpoint_connected');

  let count = int(data.PnC);
  if (count < 2) { rt.diagnostics.add('polyline_point_count'); return null; }
  if (count > MAX_POINTS) { count = MAX_POINTS; rt.diagnostics.add('polyline_point_count_capped'); }
  let centre = num(data.PnCC, -1) / int(data.PnC);
  if (!(centre > 0 && centre < 1)) { centre = 0.5; rt.diagnostics.add('polyline_center_index_assumed_half'); }

  const widths = sampleWidths(rt, data, spec);
  const cols = widths && sampleColours(rt, data, spec);
  if (!widths || !cols) return null;

  const a = enabled(data, 'bCtr') ? end : start; // bCtr: reverse endpoint order (reconstruction)
  const b = enabled(data, 'bCtr') ? start : end;
  const axis = new THREE.Vector3().subVectors(b, a);
  const length = axis.length();
  if (!Number.isFinite(length) || length < EPSILON) { rt.diagnostics.add('polyline_degenerate_endpoints'); return null; }
  axis.divideScalar(length);

  const positions = new Float32Array(count * 2 * 3);
  const normals = new Float32Array(count * 2 * 3);
  const uvs = new Float32Array(count * 2 * 2);
  const colors = new Float32Array(count * 2 * 4);
  const point = new THREE.Vector3();
  const toCamera = new THREE.Vector3();
  const side = new THREE.Vector3();
  const normal = new THREE.Vector3();
  let fallback = false;

  for (let i = 0; i < count; i++) {
    const t = i / (count - 1);
    point.copy(a).addScaledVector(axis, length * t);
    toCamera.subVectors(camera, point);
    side.crossVectors(axis, toCamera);
    if (side.lengthSq() < EPSILON * EPSILON) { // camera on the line: pick any perpendicular
      fallback = true;
      side.crossVectors(axis, Math.abs(axis.y) < 0.9 ? new THREE.Vector3(0, 1, 0) : new THREE.Vector3(1, 0, 0));
    }
    side.normalize();
    normal.crossVectors(side, axis).normalize();

    const lerpSeg = (lo, hi, from, to) => (t - from) / (to - from) * (hi - lo) + lo;
    const first = t <= centre;
    const width = widths.Wd * (first ? lerpSeg(widths.WdB, widths.WdC, 0, centre) : lerpSeg(widths.WdC, widths.WdE, centre, 1));
    const from = first ? cols.ColB : cols.ColC;
    const to = first ? cols.ColC : cols.ColE;
    const u = first ? t / centre : (t - centre) / (1 - centre);
    for (let side_i = 0; side_i < 2; side_i++) {
      const v = i * 2 + side_i;
      const sign = side_i === 0 ? -0.5 : 0.5; // Wd treated as full width
      positions[v * 3] = point.x + side.x * width * sign;
      positions[v * 3 + 1] = point.y + side.y * width * sign;
      positions[v * 3 + 2] = point.z + side.z * width * sign;
      normals.set([normal.x, normal.y, normal.z], v * 3);
      uvs[v * 2] = t; // along length
      uvs[v * 2 + 1] = side_i;
      for (let c = 0; c < 4; c++) colors[v * 4 + c] = (from[c] + (to[c] - from[c]) * u) * spec.color[c]; // spec.color applied once, here
    }
  }
  if (fallback) rt.diagnostics.add('polyline_camera_on_axis_fallback');
  if (![positions, colors].every((arr) => arr.every(Number.isFinite))) { rt.diagnostics.add('polyline_non_finite'); return null; }

  const indices = new Uint16Array((count - 1) * 6);
  for (let i = 0; i < count - 1; i++) {
    const v = i * 2;
    indices.set([v, v + 1, v + 2, v + 1, v + 3, v + 2], i * 6);
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.BufferAttribute(positions, 3));
  g.setAttribute('normal', new THREE.BufferAttribute(normals, 3));
  g.setAttribute('uv', new THREE.BufferAttribute(uvs, 2));
  g.setAttribute('aColor', new THREE.BufferAttribute(colors, 4));
  for (let i = 1; i < 4; i++) g.setAttribute('vfxUv' + i, new THREE.BufferAttribute(uvs.slice(), 2));
  g.setIndex(new THREE.BufferAttribute(indices, 1));
  return g;
}

function resolveEndpoints(rt, spec) {
  let ends = null;
  try { ends = rt.options.polylineEndpoints(spec); } catch { rt.diagnostics.add('polyline_endpoint_callback_error'); return null; }
  if (!ends) { rt.diagnostics.add('polyline_endpoint_missing'); return null; }
  if (!finiteVec(ends.start) || !finiteVec(ends.end) || !finiteVec(ends.camera)) { rt.diagnostics.add('polyline_endpoint_invalid'); return null; }
  return ends;
}

function syncPolylines(rt, specs) {
  const visible = new Set();
  for (const spec of specs) {
    const ends = resolveEndpoints(rt, spec);
    const geometry = ends && buildRibbon(rt, spec, ends.start, ends.end, ends.camera);
    if (!geometry) { removePolyDraw(rt, spec.key); continue; }
    visible.add(spec.key);
    const def = rt._materialDef(spec.index);
    let draw = polyDraws(rt).get(spec.key);
    if (!draw) {
      const material = rt._createMaterial(def);
      const mesh = new THREE.Mesh(geometry, material);
      mesh.matrixAutoUpdate = false; // vertices are already in root-local space
      mesh.frustumCulled = false;
      mesh.name = spec.key;
      draw = { mesh, material };
      polyDraws(rt).set(spec.key, draw);
    } else {
      draw.mesh.geometry.dispose();
      draw.mesh.geometry = geometry;
    }
    if (draw.mesh.parent !== rt.root) rt.root.add(draw.mesh); // endpoints are root local: ignore binder
    // Source colour is already in the vertex attribute; keep the uniform tint neutral to avoid double tint.
    rt._animateMaterial(draw.material, { ...spec, color: [1, 1, 1, 1] }, def);
  }
  for (const key of [...polyDraws(rt).keys()]) if (!visible.has(key)) removePolyDraw(rt, key);
}

// ---------------------------------------------------------------------------
export function installPolylines(Runtime) {
  const proto = Runtime.prototype;
  if (proto[INSTALLED]) return false;
  proto[INSTALLED] = true;

  const originalParticle = proto._particle;
  const originalSync = proto._syncDraws;
  const originalDispose = proto.dispose;
  const originalReport = proto.report;

  proto._particle = function (index, birth, now, ancestors, key, result, keys, influence) {
    const peek = (this.document?.groups?.Ptcl ?? [])[index];
    if (int(peek?.values?.PrVT, -1) !== 6 || typeof this.options?.polylineEndpoints !== 'function') {
      return originalParticle.call(this, index, birth, now, ancestors, key, result, keys, influence);
    }
    // Mirrors the base sampler (budget, life, chains, duplicates, binderResolver) for kind 6.
    if (!this._tick()) return;
    const node = this._node('Ptcl', index);
    if (!node) return;
    const age = now - birth + num(influence.StFr);
    let lifeValue = life(node.life ?? {}, this.seed, key);
    if (enabled(influence, 'bOvr')) lifeValue = num(influence.OvrV) + unit(this.seed, `${key}/override`) * num(influence.OvrR);
    if (lifeValue === null) { this.diagnostics.add('life'); return; }
    const looped = num(node.values?.LpEd) > num(node.values?.LpSt);
    if (age < 0 || (!looped && lifeValue >= 0 && age >= lifeValue)) return;
    const chain = [...ancestors, { group: 'Ptcl', index, birth, influence, key }];
    const pose = this._chainTransform(chain, now);
    const tint = this._chainColor(chain, now);
    if (!pose || !tint) return;
    if (result.length >= MAX_PARTICLES) { this.diagnostics.add('budget_exceeded'); return; }
    if (keys.has(key)) { this.diagnostics.add('duplicate_particle_key'); return; }
    keys.add(key);
    this.diagnostics.add('polyline_reconstruction_not_game_equivalence');
    const spec = { key, index, kind: 6, polyline: true, age: this._local(node, age), transform: pose, color: tint, binder: this._activeBinder ?? -1 };
    if (typeof this.options.binderResolver === 'function') spec.binder = int(this.options.binderResolver(spec), -1);
    result.push(spec);
  };

  proto._syncDraws = function (particles) {
    const lines = [];
    const others = [];
    for (const spec of particles) (spec.polyline ? lines : others).push(spec);
    originalSync.call(this, others);
    if (this._disposed) clearPolyDraws(this);
    else syncPolylines(this, lines);
  };

  proto.dispose = function () {
    clearPolyDraws(this);
    originalDispose.call(this); // idempotent in base; also clears via _syncDraws([])
    clearPolyDraws(this);
  };

  proto.report = function () {
    const report = originalReport.call(this);
    report.polylines_drawn = polyDraws(this).size;
    report.polyline_rendering = 'reconstruction_screen_space_ribbon_approximation';
    return report;
  };
  return true;
}
