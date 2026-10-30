shader_type canvas_item;
render_mode unshaded, blend_disabled;
// Pixel-only SM5 port; no source_color hint, alpha modulation or native VS claim.
uniform sampler2D s_input : filter_linear, repeat_disable;
uniform sampler2D s_merge : filter_linear, repeat_disable;
uniform vec4 viewport;
uniform vec4 radii;
uniform vec4 merge_param;
uniform vec4 uv_rect;
void fragment() {
    vec2 uv = UV * uv_rect.xy + uv_rect.zw;
    vec4 r = (uv.xyxy - merge_param.xyxy) / radii;
    vec2 d = vec2(dot(r.xy, r.xy) - 1.0, 1.0 - dot(r.zw, r.zw));
    float f = clamp(min(d.x * merge_param.z + 1.0, d.y * merge_param.z + 0.5), 0.0, 1.0) * merge_param.w;
    vec2 coord = clamp(uv, vec2(0.0), vec2(1.0)) * viewport.xy;
    vec4 base = texture(s_input, coord);
    vec4 merged = texture(s_merge, coord);
    COLOR = base + f * (merged - base);
}
