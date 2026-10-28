// SPDX-License-Identifier: MIT
import * as THREE from 'three';
// Original g_EmissiveColor constant. Diffuse=0 is valid for emissive sky/energy surfaces.
// Still PBR reconstruction: no claim of original BG shader or animated material fidelity.
export function applyBackgroundMaterials(root,{background=false}={}){
 const diagnostics=[];
 root.traverse(o=>{if(!o.isMesh||!o.material)return;const list=Array.isArray(o.material)?o.material:[o.material];
  const out=list.map(m=>{const shader=m.userData?.original_shader;if(!shader)return m;
   if(['lightshaft.shpk','verticalfog.shpk'].includes(shader)){o.visible=false;diagnostics.push({mesh:o.name,shader,reason:'unsupported volumetric shader; opaque fallback rejected'});return m;}
   if(!['bg.shpk','bguvscroll.shpk','bgcolorchange.shpk','bgcrestchange.shpk'].includes(shader))return m;
   const constants=m.userData.original_shader_constants,c=constants?.['0x38a64362'];if(!c||c.length<3||!c.slice(0,3).every(Number.isFinite))return m;
   const result=m.clone();if(background)result.fog=false;result.emissive.setRGB(Math.max(0,c[0]),Math.max(0,c[1]),Math.max(0,c[2]),THREE.LinearSRGBColorSpace);result.emissiveMap=result.map;result.needsUpdate=true;
   if(shader!=='bg.shpk')diagnostics.push({mesh:o.name,shader,reason:'static material only; UV/color animation unresolved'});
   return result;
  });o.material=Array.isArray(o.material)?out:out[0];
 });return diagnostics;
}
