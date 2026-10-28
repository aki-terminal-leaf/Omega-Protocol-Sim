import { Matrix4, Vector3, Euler, Quaternion } from 'three';

// Reconstructed convention (not source-proven): Rotation XYZ fields are radians applied as Euler order 'ZYX'.
export const ROTATION_ORDER = 'ZYX';
export const ARENA_SHIFT = Object.freeze([-100, 0, -100]);
const CUT = /^cut_/i;
const CONTROL = /selector|timeline/i;

const num = (v) => typeof v === 'number' && Number.isFinite(v);
const vec = (v) => v && num(v.X) && num(v.Y) && num(v.Z) ? [v.X, v.Y, v.Z] : null;

function readTransform(t) {
  const translation = vec(t?.Translation), rotation = vec(t?.Rotation), scale = vec(t?.Scale);
  return translation && rotation && scale ? { translation, rotation, scale } : null;
}

function localMatrix({ translation: p, rotation: r, scale: s }) {
  return new Matrix4().compose(
    new Vector3(...p),
    new Quaternion().setFromEuler(new Euler(r[0], r[1], r[2], ROTATION_ORDER)),
    new Vector3(...s));
}

// LGB: properties.Layers[]; SGB: properties.LayerGroups[].Layers[]. Returns [{layer, layerIndex, groupIndex}].
function listLayers(scene) {
  const p = scene?.properties;
  if (Array.isArray(p?.Layers)) return p.Layers.map((layer, i) => ({ layer, layerIndex: i, groupIndex: null }));
  if (!Array.isArray(p?.LayerGroups)) return null;
  const out = [];
  p.LayerGroups.forEach((g, gi) => (g?.Layers || []).forEach((layer, li) =>
    out.push({ layer, layerIndex: out.length, groupIndex: gi, indexInGroup: li })));
  return out;
}

function pathFields(o) {
  const r = {};
  if (o && typeof o === 'object') for (const k of Object.keys(o).sort())
    if (/Path$/.test(k) && typeof o[k] === 'string' && o[k]) r[k] = o[k];
  return r;
}

export function flattenSceneGraph(scenes, rootPath, layerNames) {
  const nodes = [], diagnostics = [];
  const diag = (code, detail) => diagnostics.push({ code, ...detail });
  const wanted = new Set(layerNames || []);
  const rootShift = new Matrix4().makeTranslation(...ARENA_SHIFT); // applied once, at root only

  function walk(path, parentMatrix, rootLayerOnly, stack, keyPrefix, ancestry, rootLayer) {
    const scene = scenes?.[path];
    const layers = scene ? listLayers(scene) : null;
    if (!layers) { diag(scene ? 'unrecognized-structure' : 'missing-group', { path, ancestry }); return; }
    for (const { layer, layerIndex, groupIndex } of layers) {
      const name = layer?.Name ?? '';
      if (CUT.test(name)) { diag('excluded-cut-layer', { path, layer: name, layerIndex, ancestry }); continue; }
      if (rootLayerOnly && !wanted.has(name)) continue;
      const objs = Array.isArray(layer?.InstanceObjects) ? layer.InstanceObjects : [];
      objs.forEach((obj, oi) => {
        const id = obj?.InstanceId;
        const key = `${keyPrefix}L${layerIndex}:${name}/${id ?? `idx${oi}`}`;
        const t = readTransform(obj?.Transform);
        if (!t) { diag('missing-transform', { key, path, assetType: obj?.AssetType }); return; }
        const world = new Matrix4().multiplyMatrices(parentMatrix, localMatrix(t));
        const props = obj.Object;
        const assetPath = typeof props?.AssetPath === 'string' && props.AssetPath ? props.AssetPath : null;
        const rl = rootLayer ?? name;
        nodes.push({
          key, assetType: obj.AssetType, path: assetPath, layer: name, ancestry: [...ancestry],
          transform: t, worldMatrix: world.toArray(),
          source: {
            file: path, layerIndex, layerGroupIndex: groupIndex, layerId: layer.LayerId ?? null,
            instanceId: id ?? null, objectIndex: oi, name: obj.Name ?? '', rootLayer: rl,
            isVisible: props && 'IsVisible' in props ? props.IsVisible : null, // metadata only, never activates
            pathFields: pathFields(props),
          },
          properties: props,
        });
        if (obj.AssetType !== 'SharedGroup') return;
        const controls = Object.keys(props || {}).filter((k) => CONTROL.test(k)).sort();
        if (controls.length) diag('unresolved-selector-timeline', { key, controls });
        if (!assetPath) { diag('missing-group', { key, reason: 'no AssetPath' }); return; }
        if (stack.includes(assetPath)) { diag('cycle', { key, path: assetPath, stack: [...stack] }); return; }
        if (!scenes?.[assetPath]) { diag('missing-group', { key, path: assetPath }); return; }
        walk(assetPath, world, false, [...stack, assetPath], `${key}>`, [...ancestry, key], rl);
      });
    }
  }

  if (!scenes?.[rootPath]) diag('missing-root', { path: rootPath });
  else walk(rootPath, rootShift, true, [rootPath], '', [], null);
  return { nodes, diagnostics };
}
