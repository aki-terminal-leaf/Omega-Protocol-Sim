shader_type spatial;
// Chosen inspection state; native blend/depth remains unknown.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 M[5];
uniform vec4 I[10];
uniform vec3 camera_cb2;
uniform vec3 original_world_offset;
uniform float common3x;
uniform float source_clock;
uniform float inspection_exposure;
uniform sampler2D sampler0 : repeat_enable, filter_linear;
uniform sampler2D sampler1 : repeat_enable, filter_linear;
varying vec4 source_uv;
varying vec3 shaft_color;
float round_ne(float x) {
 float lo=floor(x);float f=x-lo;
 if(f<0.5){return lo;} if(f>0.5){return lo+1.0;}
 return mod(lo,2.0)==0.0 ? lo : lo+1.0;
}
vec3 rotate_source(vec3 v){return vec3(dot(I[3].xyz,v),dot(I[4].xyz,v),dot(I[5].xyz,v));}
void vertex(){
 vec4 p=vec4(VERTEX,1.0);
 vec3 world=vec3(dot(I[0],p),dot(I[1],p),dot(I[2],p));
 source_uv=vec4(UV,dot(rotate_source(M[1].xyz),world)+round_ne(M[4].x)*source_clock,dot(rotate_source(M[2].xyz),world)+round_ne(M[4].y)*source_clock);
 float a=abs(dot(camera_cb2,rotate_source(CUSTOM0.xyz)));
 float angular=a*a*(1.0-M[3].w)+M[3].w;
 shaft_color=M[3].rgb*I[7].rgb*COLOR.a*angular*clamp(M[2].w*I[6].w-1.0,0.0,1.0)*common3x;
 VERTEX=world-original_world_offset;
}
void fragment(){
 vec3 exact_rgb=texture(sampler0,source_uv.xy).rgb*shaft_color*texture(sampler1,source_uv.zw).rgb;
 ALBEDO=exact_rgb*inspection_exposure;
 // Native PS alpha is zero; this is explicitly a different output policy.
 ALPHA=1.0;
}
