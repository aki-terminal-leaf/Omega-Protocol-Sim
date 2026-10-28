// Source-field material subset. No game shader binary or screen-space distortion claim.
import * as THREE from 'three';
import {axes,scalar} from './avfx-runtime.js';
const slots=['TC1','TC2','TC3','TC4'];
const remap=d=>({...d,ACT:[0,2,5][d?.ACT??0]??0,ACTR:[0,2,5][d?.ACTR??0]??0});
const vertex=`attribute vec4 aColor;attribute vec2 vfxUv1;attribute vec2 vfxUv2;attribute vec2 vfxUv3;
varying vec4 vColor;varying vec2 uv0;varying vec2 uv1;varying vec2 uv2;varying vec2 uv3;varying vec3 worldPos;
void main(){vColor=aColor;uv0=uv;uv1=vfxUv1;uv2=vfxUv2;uv3=vfxUv3;worldPos=(modelMatrix*vec4(position,1.)).xyz;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);}`;
const fragment=`uniform vec4 particleColor;uniform bool decal;varying vec4 vColor;varying vec2 uv0;varying vec2 uv1;varying vec2 uv2;varying vec2 uv3;varying vec3 worldPos;
${slots.map((_,i)=>`uniform sampler2D tex${i};uniform bool ena${i};uniform bool c2a${i};uniform int uvn${i};uniform int cop${i};uniform int aop${i};uniform vec2 scale${i};uniform vec2 scroll${i};uniform float rot${i};`).join('\n')}
vec2 coord(int n,vec2 sc,vec2 tr,float ro){vec2 v=n==0?uv0:n==1?uv1:n==2?uv2:uv3;v=(v-vec2(.5))*sc;float c=cos(ro),s=sin(ro);v=mat2(c,s,-s,c)*v+vec2(.5)+tr;v.y=1.-v.y;return v;}
vec4 mergeInk(vec4 a,vec4 b,int co,int ao){vec3 c=co==0?a.rgb*b.rgb:co==1?a.rgb+b.rgb:co==2?a.rgb-b.rgb:co==3?max(a.rgb,b.rgb):min(a.rgb,b.rgb);float x=ao==0?a.a*b.a:ao==1?max(a.a,b.a):ao==2?min(a.a,b.a):a.a;return vec4(c,x);}
void main(){if(decal&&length(worldPos.xz)>20.5)discard;vec4 ink=vec4(1.);
${slots.map((_,i)=>`if(ena${i}){vec4 b=texture2D(tex${i},coord(uvn${i},scale${i},scroll${i},rot${i}));if(c2a${i})b.a*=max(b.r,max(b.g,b.b));${i===0?'ink=b;':`ink=mergeInk(ink,b,cop${i},aop${i});`}}`).join('\n')}
gl_FragColor=vec4(max(vec3(0.),particleColor.rgb*vColor.rgb*ink.rgb),clamp(particleColor.a*vColor.a*ink.a,0.,1.));

#include <colorspace_fragment>
}`;
export function installMaterials(Runtime){
 const oldModel=Runtime.prototype._modelGeometry,oldGeom=Runtime.prototype._sharedGeometry;
 Runtime.prototype._modelGeometry=function(source,id){const g=oldModel.call(this,source,id);if(g)for(let i=1;i<4;i++)g.setAttribute('vfxUv'+i,new THREE.Float32BufferAttribute(source.vertices.flatMap(v=>v.uv[i]||v.uv[0]),2));return g;};
 Runtime.prototype._sharedGeometry=function(spec){let g;if(spec.kind===10){const key='decal';g=this._geometryCache.get(key);if(!g){g=new THREE.PlaneGeometry(1,1).rotateX(-Math.PI/2);g.setAttribute('aColor',new THREE.Float32BufferAttribute(Array(16).fill(1),4));this._geometryCache.set(key,g);}this.diagnostics.add('flat_arena_decal_projection');}else g=oldGeom.call(this,spec);if(g)for(let i=1;i<4;i++)if(!g.getAttribute('vfxUv'+i))g.setAttribute('vfxUv'+i,g.getAttribute('uv'));return g;};
 const oldDisc=Runtime.prototype._discGeometry;Runtime.prototype._discGeometry=function(s){const g=oldDisc.call(this,s);if(g)for(let i=1;i<4;i++)g.setAttribute('vfxUv'+i,g.getAttribute('uv'));return g;};
 Runtime.prototype._materialDef=function(index){if(this._materialDefs.has(index))return this._materialDefs.get(index);const node=this._node('Ptcl',index),layers=[];
 for(const tag of slots){const m=node.materials?.[tag]||{};let tex=null;if(m.bEna){const idx=m.TxNo??m.TLst?.[0],path=this.document.textures[idx],raw=this.textureMap[path];if(raw){tex=raw.clone();tex.wrapS=[THREE.RepeatWrapping,THREE.ClampToEdgeWrapping,THREE.MirroredRepeatWrapping][m.TBUT??0];tex.wrapT=[THREE.RepeatWrapping,THREE.ClampToEdgeWrapping,THREE.MirroredRepeatWrapping][m.TBVT??0];tex.needsUpdate=true;}else this.diagnostics.add('missing_texture/'+path);if((m.TCCT??0)>4)this.diagnostics.add('unknown_color_operator/'+m.TCCT);}
 layers.push({m,tex});}
 if(node.materials?.TD?.bEna)this.diagnostics.add('uv_distortion_not_reproduced');if(node.values?.bSCt)this.diagnostics.add('simple_animation_not_reproduced');
 const d={index,node,layers,blendMode:node.values.RMT};this._materialDefs.set(index,d);return d;};
 Runtime.prototype._createMaterial=function(d){const uniforms={particleColor:{value:new THREE.Vector4(1,1,1,1)},decal:{value:d.node.values.PrVT===10}};
 d.layers.forEach(({m,tex},i)=>{Object.assign(uniforms,{['tex'+i]:{value:tex},['ena'+i]:{value:!!tex&&(i===0||(m.TCCT??0)<=4)},['c2a'+i]:{value:!!m.bC2A},['uvn'+i]:{value:m.UvSN??0},['cop'+i]:{value:Math.min(m.TCCT??0,4)},['aop'+i]:{value:m.TCAT??0},['scale'+i]:{value:new THREE.Vector2(1,1)},['scroll'+i]:{value:new THREE.Vector2()},['rot'+i]:{value:0}});});
 const mat=new THREE.ShaderMaterial({uniforms,vertexShader:vertex,fragmentShader:fragment,toneMapped:false,transparent:true,depthWrite:false,side:THREE.DoubleSide,polygonOffset:d.node.values.PrVT===10,polygonOffsetFactor:-2});
 if(d.blendMode===2)mat.blending=THREE.AdditiveBlending;
 else if(d.blendMode===4){mat.blending=THREE.CustomBlending;mat.blendSrc=THREE.SrcAlphaFactor;mat.blendDst=THREE.OneMinusSrcColorFactor;}
 else if(d.blendMode===1){mat.blending=THREE.CustomBlending;mat.blendSrc=THREE.DstColorFactor;mat.blendDst=THREE.OneMinusSrcAlphaFactor;}
 else if(d.blendMode!==0)this.diagnostics.add('unsupported_blend/'+d.blendMode);
 return mat;};
 Runtime.prototype._animateMaterial=function(mat,s,d){const u=mat.uniforms,c=s.color;u.particleColor.value.set(c[0],c[1],c[2],c[3]);
 d.layers.forEach(({m},i)=>{const uv=d.node.uv_sets?.[m.UvSN??0]||{};const scale=axes(remap(uv.Scl||{}),s.age,this.seed,s.key+'/scale'+i,1),scroll=axes(remap(uv.Scr||{}),s.age,this.seed,s.key+'/scroll'+i,0),rot=scalar(uv.Rot||{},uv.RotR||{},s.age,this.seed,s.key+'/rot'+i,0);if(!scale||!scroll||rot===null){this.diagnostics.add('uv_curve');return;}u['scale'+i].value.set(scale.x,scale.y);u['scroll'+i].value.set(scroll.x,scroll.y);u['rot'+i].value=rot;});};
 const dispose=Runtime.prototype.dispose;Runtime.prototype.dispose=function(){for(const d of this._materialDefs.values())for(const l of d.layers||[])l.tex?.dispose();dispose.call(this);};
}
