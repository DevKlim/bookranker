shader_type spatial;
// Added blend_mix so alpha controls function cleanly
render_mode unshaded, cull_back, depth_test_disabled, blend_mix;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 base_color : source_color = vec4(0.02, 0.0, 0.05, 1.0);
uniform vec4 rim_color : source_color = vec4(0.4, 0.0, 0.8, 1.0);
uniform float alpha_mult : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    float f = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
    float noise = texture(noise_tex, UV + vec2(TIME * 0.15, TIME * 0.05)).r;

    // Hard cutoff for Y2K cel-shaded feel on the rim
    float rim = smoothstep(0.6, 0.8, f + (noise * 0.3));

    vec3 col = mix(base_color.rgb, rim_color.rgb, rim);
    ALBEDO = col;
    ALPHA = alpha_mult;
}
