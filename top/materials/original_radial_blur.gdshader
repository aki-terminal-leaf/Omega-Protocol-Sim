shader_type canvas_item;
render_mode unshaded, blend_disabled;
// Pixel-only SM5 port. Helper requires an explicit named sampling policy.
uniform sampler2D s_input : filter_linear, repeat_disable;
uniform bool native_radial_mirror_lod0;
uniform vec4 viewport;
uniform vec4 radial;
// Explicit Godot UV bridge: scale.xy, offset.zw; no implicit Y flip.
uniform vec4 uv_rect;
// Texel centers are i+0.5. Mirror the infinite integer lattice with duplicated
// edge texels: ...1,0,0,1,...,N-1,N-1,... . Positive modulo is essential for i<0.
int mirror_index(int i, int n) {
    int period = 2 * n;
    int r = ((i % period) + period) % period;
    return r < n ? r : period - 1 - r;
}
vec4 radial_sample(vec2 coord) {
    if (!native_radial_mirror_lod0) {
        return texture(s_input, coord); // Retain explicit clamp compatibility.
    }
    ivec2 size0 = textureSize(s_input, 0);
    vec2 p = coord * vec2(size0) - vec2(0.5);
    ivec2 lo = ivec2(floor(p));
    vec2 f = p - floor(p);
    ivec2 a = ivec2(mirror_index(lo.x, size0.x), mirror_index(lo.y, size0.y));
    ivec2 b = ivec2(mirror_index(lo.x + 1, size0.x), mirror_index(lo.y + 1, size0.y));
    vec4 c00 = texelFetch(s_input, a, 0);
    vec4 c10 = texelFetch(s_input, ivec2(b.x, a.y), 0);
    vec4 c01 = texelFetch(s_input, ivec2(a.x, b.y), 0);
    vec4 c11 = texelFetch(s_input, b, 0);
    vec4 row0 = c00 + (c10 - c00) * f.x;
    vec4 row1 = c01 + (c11 - c01) * f.x;
    return row0 + (row1 - row0) * f.y;
}
void fragment() {
    vec2 uv = UV * uv_rect.xy + uv_rect.zw;
    vec2 delta = radial.xy - uv;
    vec4 sum_rgba = vec4(0.0);
    float sum_weight = 0.0;
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float x = (fi * radial.w) * 0.3333333432674407958984375;
        float w = 1.0 - (fi * radial.z) * 0.25;
        vec2 coord = min(clamp(delta * x + uv, vec2(0.0), vec2(1.0)) * viewport.xy, viewport.zw);
        sum_rgba += radial_sample(coord) * w;
        sum_weight += w;
    }
    COLOR = sum_rgba / sum_weight;
}
