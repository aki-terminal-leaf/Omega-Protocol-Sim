shader_type canvas_item;
render_mode unshaded, blend_disabled;
// Pixel-only SM5 port. Explicit embedding sampler; native 0x265 is UNKNOWN.
uniform sampler2D s_input : filter_linear, repeat_disable;
uniform vec4 viewport;
uniform vec4 radial;
// Explicit Godot UV bridge: scale.xy, offset.zw; no implicit Y flip.
uniform vec4 uv_rect;
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
        sum_rgba += texture(s_input, coord) * w;
        sum_weight += w;
    }
    COLOR = sum_rgba / sum_weight;
}
