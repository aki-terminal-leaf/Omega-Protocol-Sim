shader_type canvas_item;
render_mode unshaded, blend_disabled;
// Pixel-only SM5 port; no source_color hint, alpha modulation or native VS claim.
uniform sampler2D s_input : filter_linear, repeat_disable;
uniform sampler2D s_merge : filter_linear, repeat_disable;
uniform bool native_merge_mixed_lod0;
uniform vec4 viewport;
uniform vec4 radii;
uniform vec4 merge_param;
uniform vec4 uv_rect;
int mirror_index(int i, int n) {
    int period = 2 * n;
    int r = ((i % period) + period) % period;
    return r < n ? r : period - 1 - r;
}
vec4 merge_linear_sample(vec2 coord) {
    if (!native_merge_mixed_lod0) {
        return texture(s_merge, coord); // Retain explicit clamp compatibility.
    }
    ivec2 size0 = textureSize(s_merge, 0);
    vec2 p = coord * vec2(size0) - vec2(0.5);
    ivec2 lo = ivec2(floor(p));
    vec2 f = p - floor(p);
    ivec2 a = ivec2(mirror_index(lo.x, size0.x), mirror_index(lo.y, size0.y));
    ivec2 b = ivec2(mirror_index(lo.x + 1, size0.x), mirror_index(lo.y + 1, size0.y));
    vec4 c00 = texelFetch(s_merge, a, 0);
    vec4 c10 = texelFetch(s_merge, ivec2(b.x, a.y), 0);
    vec4 c01 = texelFetch(s_merge, ivec2(a.x, b.y), 0);
    vec4 c11 = texelFetch(s_merge, b, 0);
    vec4 row0 = c00 + (c10 - c00) * f.x;
    vec4 row1 = c01 + (c11 - c01) * f.x;
    return row0 + (row1 - row0) * f.y;
}
// Diagnostic POINT: f32(coord*N), floor, then integer MIRROR. Never fold UV.
// Exact integer products follow the normative boundary rule; noninteger D3D
// subtexel precision is implementation dependent. |coord|<=16, N<=4096.
vec4 merge_point_sample(vec2 coord) {
    if (!native_merge_mixed_lod0) { return texture(s_input, coord); }
    ivec2 size0 = textureSize(s_input, 0);
    vec2 scaled = coord * vec2(size0);
    ivec2 i = ivec2(floor(scaled));
    return texelFetch(s_input, ivec2(mirror_index(i.x, size0.x), mirror_index(i.y, size0.y)), 0);
}
void fragment() {
    vec2 uv = UV * uv_rect.xy + uv_rect.zw;
    vec4 r = (uv.xyxy - merge_param.xyxy) / radii;
    vec2 d = vec2(dot(r.xy, r.xy) - 1.0, 1.0 - dot(r.zw, r.zw));
    float f = clamp(min(d.x * merge_param.z + 1.0, d.y * merge_param.z + 0.5), 0.0, 1.0) * merge_param.w;
    vec2 coord = clamp(uv, vec2(0.0), vec2(1.0)) * viewport.xy;
    vec4 base = merge_point_sample(coord);
    vec4 merged = merge_linear_sample(coord);
    COLOR = base + f * (merged - base);
}
