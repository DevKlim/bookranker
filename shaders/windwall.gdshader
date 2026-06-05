shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_disabled, unshaded;

uniform sampler2D noise_tex;
uniform vec4 edge_color : source_color = vec4(0.6, 1.0, 0.8, 1.0);
uniform vec4 core_color : source_color = vec4(0.1, 0.8, 0.9, 0.5);
uniform float speed = 3.0;

void fragment() {
    vec2 uv = UV;
    uv.y -= TIME * speed;
    float noise = texture(noise_tex, uv).r;
    
    // Strong vertical crisp edges for that retro protective shield feel
    float edge = smoothstep(0.0, 0.1, UV.x) * smoothstep(1.0, 0.9, UV.x);
    float rim = 1.0 - edge;
    
    vec3 final_color = mix(core_color.rgb, edge_color.rgb, rim + noise * 0.5);
    float final_alpha = core_color.a * edge + rim + noise * 0.3;
    
    // Fade out at top and bottom smoothly
    final_alpha *= smoothstep(0.0, 0.2, UV.y) * smoothstep(1.0, 0.5, UV.y);
    
    ALBEDO = final_color;
    ALPHA = clamp(final_alpha, 0.0, 1.0);
}
