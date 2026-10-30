shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
// Conditional AddLayer0 0x5D82881C, Color, VS0/PS0. NOT live guard/index evidence.
uniform vec4 material_cb[5];
uniform vec4 camera_cb[59];
uniform vec4 parameter_cb[3];
uniform vec4 instance_cb[1];
uniform vec4 common_cb[4];
uniform vec4 fog_cb[10];
uniform float source_clock;
uniform vec3 render_origin;
uniform vec4 native_sv_position;
uniform float inspection_exposure;
uniform sampler2D sampler0 : filter_linear, repeat_disable;
uniform sampler2D sampler1 : filter_linear, repeat_disable;
uniform sampler2D sampler2 : filter_linear, repeat_disable;
varying vec4 source_texcoord1;
varying vec4 source_world;
varying vec4 source_clip;
float ties_even(float x) { float f=floor(x); float t=x-f; return t<0.5 ? f : (t>0.5 ? f+1.0 : (mod(abs(f),2.0)==0.0 ? f : f+1.0)); }
// Undefined-domain safety policy only; not an assertion of native NaN/Inf behavior.
float native_div(float a,float b) { return b==0.0 ? 0.0 : a/b; }
float native_rsq(float a) { return a<=0.0 ? 0.0 : inversesqrt(a); }
void vertex() {
vec4 v0=vec4(VERTEX,1.0);
vec4 r0; vec4 r1; vec4 r2; vec4 r3; vec4 o0; vec4 o1; vec4 o2; vec4 tmp;
// 0 mov r0.w, l(1.0)
tmp.w = 1.0;
r0.w = tmp.w;
// 1 add r0.xyz, v0.xyzx, cb3[0].xyzx
tmp.x = (v0.x + instance_cb[0].x);
tmp.y = (v0.y + instance_cb[0].y);
tmp.z = (v0.z + instance_cb[0].z);
r0.xyz = tmp.xyz;
// 2 dp4 o0.x, cb1[6].xyzw, r0.xyzw
tmp.x = ((camera_cb[6].x * r0.x) + (camera_cb[6].y * r0.y) + (camera_cb[6].z * r0.z) + (camera_cb[6].w * r0.w));
o0.x = tmp.x;
// 3 dp4 o0.y, cb1[7].xyzw, r0.xyzw
tmp.y = ((camera_cb[7].x * r0.x) + (camera_cb[7].y * r0.y) + (camera_cb[7].z * r0.z) + (camera_cb[7].w * r0.w));
o0.y = tmp.y;
// 4 dp4 o0.z, cb1[8].xyzw, r0.xyzw
tmp.z = ((camera_cb[8].x * r0.x) + (camera_cb[8].y * r0.y) + (camera_cb[8].z * r0.z) + (camera_cb[8].w * r0.w));
o0.z = tmp.z;
// 5 dp4 o0.w, cb1[9].xyzw, r0.xyzw
tmp.w = ((camera_cb[9].x * r0.x) + (camera_cb[9].y * r0.y) + (camera_cb[9].z * r0.z) + (camera_cb[9].w * r0.w));
o0.w = tmp.w;
// 6 mov o2.xyzw, r0.xyzw
tmp.x = r0.x;
tmp.y = r0.y;
tmp.z = r0.z;
tmp.w = r0.w;
o2.xyzw = tmp.xyzw;
// 7 lt r0.w, l(0.0), -cb0[3].y
tmp.w = ((0.0 < (-material_cb[3].y)) ? -1.0 : 0.0);
r0.w = tmp.w;
// 8 lt r1.x, -cb0[3].y, l(0.0)
tmp.x = (((-material_cb[3].y) < 0.0) ? -1.0 : 0.0);
r1.x = tmp.x;
// 9 iadd r0.w, r1.x, -r0.w
tmp.w = (r1.x + (-r0.w));
r0.w = tmp.w;
// 10 itof r0.w, r0.w
tmp.w = r0.w;
r0.w = tmp.w;
// 11 add r1.xyz, r0.xyzx, -cb2[0].xyzx
tmp.x = (r0.x + (-parameter_cb[0].x));
tmp.y = (r0.y + (-parameter_cb[0].y));
tmp.z = (r0.z + (-parameter_cb[0].z));
r1.xyz = tmp.xyz;
// 12 mul r0.w, r0.w, r1.y
tmp.w = (r0.w * r1.y);
r0.w = tmp.w;
// 13 max r0.w, r0.w, l(0.0010000000474974513)
tmp.w = max(r0.w,0.0010000000474974513);
r0.w = tmp.w;
// 14 div r0.w, cb0[4].x, r0.w
tmp.w = native_div(material_cb[4].x,r0.w);
r0.w = tmp.w;
// 15 mul r1.xy, r0.wwww, r1.xzxx
tmp.x = (r0.w * r1.x);
tmp.y = (r0.w * r1.z);
r1.xy = tmp.xy;
// 16 add r0.w, -cb0[4].y, l(1.0)
tmp.w = ((-material_cb[4].y) + 1.0);
r0.w = tmp.w;
// 17 mad r1.zw, r0.wwww, r1.xxxy, r0.xxxz
tmp.z = (r0.w * r1.x + r0.x);
tmp.w = (r0.w * r1.y + r0.z);
r1.zw = tmp.zw;
// 18 add r0.w, cb0[4].y, l(1.0)
tmp.w = (material_cb[4].y + 1.0);
r0.w = tmp.w;
// 19 mad r0.xz, r0.wwww, r1.xxyx, r0.xxzx
tmp.x = (r0.w * r1.x + r0.x);
tmp.z = (r0.w * r1.y + r0.z);
r0.xz = tmp.xz;
// 20 mov o1.y, r0.y
tmp.y = r0.y;
o1.y = tmp.y;
// 21 add r0.xy, r0.xzxx, r1.zwzz
tmp.x = (r0.x + r1.z);
tmp.y = (r0.z + r1.w);
r0.xy = tmp.xy;
// 22 round_ne r0.zw, cb0[2].xxxy
tmp.z = ties_even(material_cb[2].x);
tmp.w = ties_even(material_cb[2].y);
r0.zw = tmp.zw;
// 23 mul r0.zw, r0.zzzw, cb2[0].wwww
tmp.z = (r0.z * source_clock);
tmp.w = (r0.w * source_clock);
r0.zw = tmp.zw;
// 24 mul r1.x, cb0[4].z, l(0.5)
tmp.x = (material_cb[4].z * 0.5);
r1.x = tmp.x;
// 25 mad o1.xz, r1.xxxx, r0.xxyx, -r0.zzwz
tmp.x = (r1.x * r0.x + (-r0.z));
tmp.z = (r1.x * r0.y + (-r0.w));
o1.xz = tmp.xz;
// 26 dp2 r0.x, v0.xzxx, v0.xzxx
tmp.x = ((v0.x * v0.x) + (v0.z * v0.z));
r0.x = tmp.x;
// 27 sqrt o1.w, r0.x
tmp.w = sqrt(r0.x);
o1.w = tmp.w;
source_texcoord1=o1; source_world=o2; source_clip=o0;
// Chosen Godot camera projection, separate from retained native clip equations.
VERTEX=o2.xyz-render_origin;
}
void fragment() {
vec4 v0=native_sv_position; vec4 v1=source_texcoord1; vec4 v2=source_world;
vec4 r0; vec4 r1; vec4 r2; vec4 r3; vec4 o0; vec4 o1; vec4 o2; vec4 tmp;
// 0 add r0.x, v2.y, -cb3[4].z
tmp.x = (v2.y + (-fog_cb[4].z));
r0.x = tmp.x;
// 1 max r0.yz, cb3[4].xxwx, l(0.0,9.999999747378752e-05,9.999999747378752e-05,0.0)
tmp.y = max(fog_cb[4].x,9.999999747378752e-05);
tmp.z = max(fog_cb[4].w,9.999999747378752e-05);
r0.yz = tmp.yz;
// 2 mul r0.x, r0.z, -r0.x
tmp.x = (r0.z * (-r0.x));
r0.x = tmp.x;
// 3 mul r0.x, r0.x, l(0.5459683537483215)
tmp.x = (r0.x * 0.5459683537483215);
r0.x = tmp.x;
// 4 exp r0.x, r0.x
tmp.x = exp2(r0.x);
r0.x = tmp.x;
// 5 mul r0.x, r0.x, cb3[4].y
tmp.x = (r0.x * fog_cb[4].y);
r0.x = tmp.x;
// 6 add r0.z, v2.y, -cb3[3].w
tmp.z = (v2.y + (-fog_cb[3].w));
r0.z = tmp.z;
// 7 mul r0.y, r0.y, -r0.z
tmp.y = (r0.y * (-r0.z));
r0.y = tmp.y;
// 8 mul r0.y, r0.y, l(0.5459683537483215)
tmp.y = (r0.y * 0.5459683537483215);
r0.y = tmp.y;
// 9 exp r0.y, r0.y
tmp.y = exp2(r0.y);
r0.y = tmp.y;
// 10 mad r0.x, r0.y, cb3[3].z, r0.x
tmp.x = (r0.y * fog_cb[3].z + r0.x);
r0.x = tmp.x;
// 11 max r0.y, cb3[3].x, l(0.0)
tmp.y = max(fog_cb[3].x,0.0);
r0.y = tmp.y;
// 12 add r1.xyz, v2.xyzx, -cb3[7].xyzx
tmp.x = (v2.x + (-fog_cb[7].x));
tmp.y = (v2.y + (-fog_cb[7].y));
tmp.z = (v2.z + (-fog_cb[7].z));
r1.xyz = tmp.xyz;
// 13 dp3 r0.z, r1.xyzx, r1.xyzx
tmp.z = ((r1.x * r1.x) + (r1.y * r1.y) + (r1.z * r1.z));
r0.z = tmp.z;
// 14 max r0.w, r0.z, l(9.99999993922529e-09)
tmp.w = max(r0.z,9.99999993922529e-09);
r0.w = tmp.w;
// 15 rsq r0.w, r0.w
tmp.w = native_rsq(r0.w);
r0.w = tmp.w;
// 16 mad r0.y, -r0.y, r0.w, l(1.0)
tmp.y = ((-r0.y) * r0.w + 1.0);
r0.y = tmp.y;
// 17 mul r1.w, r0.w, r0.z
tmp.w = (r0.w * r0.z);
r1.w = tmp.w;
// 18 rsq r0.z, r0.z
tmp.z = native_rsq(r0.z);
r0.z = tmp.z;
// 19 mad r0.z, -r1.y, r0.z, cb3[9].x
tmp.z = ((-r1.y) * r0.z + fog_cb[9].x);
r0.z = tmp.z;
// 20 mul r1.xyz, r0.wwww, r1.xyzx
tmp.x = (r0.w * r1.x);
tmp.y = (r0.w * r1.y);
tmp.z = (r0.w * r1.z);
r1.xyz = tmp.xyz;
// 21 mul_sat r0.z, r0.z, cb3[9].y
tmp.z = clamp((r0.z * fog_cb[9].y),0.0,1.0);
r0.z = tmp.z;
// 22 mul r0.z, r0.z, cb3[9].z
tmp.z = (r0.z * fog_cb[9].z);
r0.z = tmp.z;
// 23 mad r0.w, r1.w, r0.y, -cb3[5].x
tmp.w = (r1.w * r0.y + (-fog_cb[5].x));
r0.w = tmp.w;
// 24 mul r0.y, r0.y, r1.w
tmp.y = (r0.y * r1.w);
r0.y = tmp.y;
// 25 mul r0.y, r0.y, -r0.x
tmp.y = (r0.y * (-r0.x));
r0.y = tmp.y;
// 26 exp r0.y, r0.y
tmp.y = exp2(r0.y);
r0.y = tmp.y;
// 27 min r0.y, r0.y, l(1.0)
tmp.y = min(r0.y,1.0);
r0.y = tmp.y;
// 28 max r0.y, r0.y, cb3[3].y
tmp.y = max(r0.y,fog_cb[3].y);
r0.y = tmp.y;
// 29 add r0.y, -r0.y, l(1.0)
tmp.y = ((-r0.y) + 1.0);
r0.y = tmp.y;
// 30 mul_sat r0.y, r0.y, cb3[5].w
tmp.y = clamp((r0.y * fog_cb[5].w),0.0,1.0);
r0.y = tmp.y;
// 31 max r0.w, r0.w, l(0.0)
tmp.w = max(r0.w,0.0);
r0.w = tmp.w;
// 32 mul r0.x, r0.w, -r0.x
tmp.x = (r0.w * (-r0.x));
r0.x = tmp.x;
// 33 exp r0.x, r0.x
tmp.x = exp2(r0.x);
r0.x = tmp.x;
// 34 min r0.x, r0.x, l(1.0)
tmp.x = min(r0.x,1.0);
r0.x = tmp.x;
// 35 mad r0.w, r1.y, l(1.0750000476837158), l(-0.07500000298023224)
tmp.w = (r1.y * 1.0750000476837158 + -0.07500000298023224);
r0.w = tmp.w;
// 36 mul r1.w, r0.w, l(12740000.0)
tmp.w = (r0.w * 12740000.0);
r1.w = tmp.w;
// 37 mad r1.w, r1.w, r1.w, l(407936008192.0)
tmp.w = (r1.w * r1.w + 407936008192.0);
r1.w = tmp.w;
// 38 sqrt r1.w, r1.w
tmp.w = sqrt(r1.w);
r1.w = tmp.w;
// 39 mad r0.w, -r0.w, l(12740000.0), r1.w
tmp.w = ((-r0.w) * 12740000.0 + r1.w);
r0.w = tmp.w;
// 40 mul r0.w, r0.w, l(-9.999999747378752e-06)
tmp.w = (r0.w * -9.999999747378752e-06);
r0.w = tmp.w;
// 41 exp r0.w, r0.w
tmp.w = exp2(r0.w);
r0.w = tmp.w;
// 42 add r0.xw, -r0.xxxw, l(1.0,0.0,0.0,1.0)
tmp.x = ((-r0.x) + 1.0);
tmp.w = ((-r0.w) + 1.0);
r0.xw = tmp.xw;
// 43 dp3 r1.w, -r1.xyzx, cb3[8].xyzx
tmp.w = (((-r1.x) * fog_cb[8].x) + ((-r1.y) * fog_cb[8].y) + ((-r1.z) * fog_cb[8].z));
r1.w = tmp.w;
// 44 dp3_sat r1.x, r1.xyzx, cb3[8].xyzx
tmp.x = clamp(((r1.x * fog_cb[8].x) + (r1.y * fog_cb[8].y) + (r1.z * fog_cb[8].z)),0.0,1.0);
r1.x = tmp.x;
// 45 log r1.x, r1.x
tmp.x = log2(r1.x);
r1.x = tmp.x;
// 46 mad r1.y, r1.w, r1.w, l(1.0)
tmp.y = (r1.w * r1.w + 1.0);
r1.y = tmp.y;
// 47 mul r0.w, r0.w, r1.y
tmp.w = (r0.w * r1.y);
r0.w = tmp.w;
// 48 mad r1.yzw, r0.wwww, l(0.0,0.05968310311436653,0.05968310311436653,0.05968310311436653), cb3[0].xxyz
tmp.y = (r0.w * 0.05968310311436653 + fog_cb[0].x);
tmp.z = (r0.w * 0.05968310311436653 + fog_cb[0].y);
tmp.w = (r0.w * 0.05968310311436653 + fog_cb[0].z);
r1.yzw = tmp.yzw;
// 49 max r0.w, cb3[5].z, l(1.0)
tmp.w = max(fog_cb[5].z,1.0);
r0.w = tmp.w;
// 50 mul r0.w, r1.x, r0.w
tmp.w = (r1.x * r0.w);
r0.w = tmp.w;
// 51 exp r0.w, r0.w
tmp.w = exp2(r0.w);
r0.w = tmp.w;
// 52 mul r1.x, cb3[6].w, cb3[6].w
tmp.x = (fog_cb[6].w * fog_cb[6].w);
r1.x = tmp.x;
// 53 mul r0.w, r0.w, r1.x
tmp.w = (r0.w * r1.x);
r0.w = tmp.w;
// 54 mul r2.xyz, r0.wwww, cb3[6].xyzx
tmp.x = (r0.w * fog_cb[6].x);
tmp.y = (r0.w * fog_cb[6].y);
tmp.z = (r0.w * fog_cb[6].z);
r2.xyz = tmp.xyz;
// 55 mad r1.xyz, r2.xyzx, r0.xxxx, r1.yzwy
tmp.x = (r2.x * r0.x + r1.y);
tmp.y = (r2.y * r0.x + r1.z);
tmp.z = (r2.z * r0.x + r1.w);
r1.xyz = tmp.xyz;
// 56 max r1.xyz, r1.xyzx, l(0.0,0.0,0.0,0.0)
tmp.x = max(r1.x,0.0);
tmp.y = max(r1.y,0.0);
tmp.z = max(r1.z,0.0);
r1.xyz = tmp.xyz;
// 57 mov r2.xyz, v2.xyzx
tmp.x = v2.x;
tmp.y = v2.y;
tmp.z = v2.z;
r2.xyz = tmp.xyz;
// 58 mov r2.w, l(1.0)
tmp.w = 1.0;
r2.w = tmp.w;
// 59 dp4 r0.x, cb2[2].xyzw, r2.xyzw
tmp.x = ((camera_cb[2].x * r2.x) + (camera_cb[2].y * r2.y) + (camera_cb[2].z * r2.z) + (camera_cb[2].w * r2.w));
r0.x = tmp.x;
// 60 mad r2.x, cb3[2].w, -r0.x, cb3[2].z
tmp.x = (fog_cb[2].w * (-r0.x) + fog_cb[2].z);
r2.x = tmp.x;
// 61 mov r2.yw, l(0.0,0.5,0.0,1.0)
tmp.y = 0.5;
tmp.w = 1.0;
r2.yw = tmp.yw;
// 62 sample_l_indexable(texture2d)(float,float,float,float) r0.xw, r2.xyxx, t2.xzwy, s2, l(0.0)
tmp.x = textureLod(sampler2, vec2(r2.x,r2.y), 0.0).x;
tmp.w = textureLod(sampler2, vec2(r2.x,r2.y), 0.0).y;
r0.xw = tmp.xw;
// 63 mad r2.xy, v0.xyxx, cb1[0].xyxx, cb1[0].zwzz
tmp.x = (v0.x * common_cb[0].x + common_cb[0].z);
tmp.y = (v0.y * common_cb[0].y + common_cb[0].w);
r2.xy = tmp.xy;
// 64 sample_l_indexable(texture2d)(float,float,float,float) r3.xyz, r2.xyxx, t1.xyzw, s1, l(0.0)
tmp.x = textureLod(sampler1, vec2(r2.x,r2.y), 0.0).x;
tmp.y = textureLod(sampler1, vec2(r2.x,r2.y), 0.0).y;
tmp.z = textureLod(sampler1, vec2(r2.x,r2.y), 0.0).z;
r3.xyz = tmp.xyz;
// 65 sample_indexable(texture2d)(float,float,float,float) r1.w, r2.xyxx, t0.yzwx, s0
tmp.w = textureLod(sampler0, vec2(r2.x,r2.y), 0.0).x;
r1.w = tmp.w;
// 66 max r2.z, r1.w, l(1.0000000116860974e-07)
tmp.z = max(r1.w,1.0000000116860974e-07);
r2.z = tmp.z;
// 67 add r3.xyz, r3.xyzx, -cb3[0].xyzx
tmp.x = (r3.x + (-fog_cb[0].x));
tmp.y = (r3.y + (-fog_cb[0].y));
tmp.z = (r3.z + (-fog_cb[0].z));
r3.xyz = tmp.xyz;
// 68 mad r3.xyz, r0.wwww, r3.xyzx, cb3[0].xyzx
tmp.x = (r0.w * r3.x + fog_cb[0].x);
tmp.y = (r0.w * r3.y + fog_cb[0].y);
tmp.z = (r0.w * r3.z + fog_cb[0].z);
r3.xyz = tmp.xyz;
// 69 max r0.x, r0.y, r0.x
tmp.x = max(r0.y,r0.x);
r0.x = tmp.x;
// 70 max r3.xyz, r3.xyzx, l(0.0,0.0,0.0,0.0)
tmp.x = max(r3.x,0.0);
tmp.y = max(r3.y,0.0);
tmp.z = max(r3.z,0.0);
r3.xyz = tmp.xyz;
// 71 mad r3.xyz, r0.zzzz, -r3.xyzx, r3.xyzx
tmp.x = (r0.z * (-r3.x) + r3.x);
tmp.y = (r0.z * (-r3.y) + r3.y);
tmp.z = (r0.z * (-r3.z) + r3.z);
r3.xyz = tmp.xyz;
// 72 add r1.xyz, r1.xyzx, -r3.xyzx
tmp.x = (r1.x + (-r3.x));
tmp.y = (r1.y + (-r3.y));
tmp.z = (r1.z + (-r3.z));
r1.xyz = tmp.xyz;
// 73 mad r0.yzw, r0.yyyy, r1.xxyz, r3.xxyz
tmp.y = (r0.y * r1.x + r3.x);
tmp.z = (r0.y * r1.y + r3.y);
tmp.w = (r0.y * r1.z + r3.z);
r0.yzw = tmp.yzw;
// 74 mad r2.xy, v0.xyxx, cb1[1].xyxx, cb1[1].zwzz
tmp.x = (v0.x * common_cb[1].x + common_cb[1].z);
tmp.y = (v0.y * common_cb[1].y + common_cb[1].w);
r2.xy = tmp.xy;
// 75 dp4 r1.x, cb2[11].xyzw, r2.xyzw
tmp.x = ((camera_cb[11].x * r2.x) + (camera_cb[11].y * r2.y) + (camera_cb[11].z * r2.z) + (camera_cb[11].w * r2.w));
r1.x = tmp.x;
// 76 dp4 r1.y, cb2[13].xyzw, r2.xyzw
tmp.y = ((camera_cb[13].x * r2.x) + (camera_cb[13].y * r2.y) + (camera_cb[13].z * r2.z) + (camera_cb[13].w * r2.w));
r1.y = tmp.y;
// 77 div r1.x, r1.x, r1.y
tmp.x = native_div(r1.x,r1.y);
r1.x = tmp.x;
// 78 add r1.x, -r1.x, v1.y
tmp.x = ((-r1.x) + v1.y);
r1.x = tmp.x;
// 79 lt r1.y, l(0.0), cb0[3].y
tmp.y = ((0.0 < material_cb[3].y) ? -1.0 : 0.0);
r1.y = tmp.y;
// 80 lt r1.z, cb0[3].y, l(0.0)
tmp.z = ((material_cb[3].y < 0.0) ? -1.0 : 0.0);
r1.z = tmp.z;
// 81 iadd r1.y, r1.z, -r1.y
tmp.y = (r1.z + (-r1.y));
r1.y = tmp.y;
// 82 itof r1.y, r1.y
tmp.y = r1.y;
r1.y = tmp.y;
// 83 mul r1.x, r1.x, r1.y
tmp.x = (r1.x * r1.y);
r1.x = tmp.x;
// 84 mul r1.x, r1.x, cb4[1].w
tmp.x = (r1.x * parameter_cb[1].w);
r1.x = tmp.x;
// 85 mul r1.x, r1.x, |cb0[3].y|
tmp.x = (r1.x * abs(material_cb[3].y));
r1.x = tmp.x;
// 86 max r1.x, r1.x, l(0.0)
tmp.x = max(r1.x,0.0);
r1.x = tmp.x;
// 87 mad r1.y, cb0[3].z, r1.x, l(1.0)
tmp.y = (material_cb[3].z * r1.x + 1.0);
r1.y = tmp.y;
// 88 min o0.w, r1.x, cb0[0].w
tmp.w = min(r1.x,material_cb[0].w);
o0.w = tmp.w;
// 89 div r1.x, l(1.0,1.0,1.0,1.0), r1.y
tmp.x = native_div(1.0,r1.y);
r1.x = tmp.x;
// 90 add r1.yzw, cb4[1].xxyz, -cb4[2].xxyz
tmp.y = (parameter_cb[1].x + (-parameter_cb[2].x));
tmp.z = (parameter_cb[1].y + (-parameter_cb[2].y));
tmp.w = (parameter_cb[1].z + (-parameter_cb[2].z));
r1.yzw = tmp.yzw;
// 91 mad r1.xyz, r1.xxxx, r1.yzwy, cb4[2].xyzx
tmp.x = (r1.x * r1.y + parameter_cb[2].x);
tmp.y = (r1.x * r1.z + parameter_cb[2].y);
tmp.z = (r1.x * r1.w + parameter_cb[2].z);
r1.xyz = tmp.xyz;
// 92 mad r0.yzw, -cb0[0].xxyz, r1.xxyz, r0.yyzw
tmp.y = ((-material_cb[0].x) * r1.x + r0.y);
tmp.z = ((-material_cb[0].y) * r1.y + r0.z);
tmp.w = ((-material_cb[0].z) * r1.z + r0.w);
r0.yzw = tmp.yzw;
// 93 mul r1.xyz, r1.xyzx, cb0[0].xyzx
tmp.x = (r1.x * material_cb[0].x);
tmp.y = (r1.y * material_cb[0].y);
tmp.z = (r1.z * material_cb[0].z);
r1.xyz = tmp.xyz;
// 94 mad o0.xyz, r0.xxxx, r0.yzwy, r1.xyzx
tmp.x = (r0.x * r0.y + r1.x);
tmp.y = (r0.x * r0.z + r1.y);
tmp.z = (r0.x * r0.w + r1.z);
o0.xyz = tmp.xyz;
ALBEDO=o0.rgb*inspection_exposure; ALPHA=o0.a;
}
