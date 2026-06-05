shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;
uniform vec4 color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float fresnel_power = 2.0;

void fragment() {
    float f = pow(1.0 - dot(normalize(NORMAL), normalize(VIEW)), fresnel_power);
    vec2 grid = fract(UV * 10.0 + vec2(TIME * 0.5));
    float line = step(0.1, grid.x) * step(0.1, grid.y);
    ALBEDO = color.rgb;
    ALPHA = color.a * f * (1.0 - line + 0.2);
}
