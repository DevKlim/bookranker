shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, unshaded;

uniform vec4 shield_color : source_color = vec4(0.3, 0.0, 0.4, 0.8);
uniform vec4 halftone_color : source_color = vec4(0.1, 0.0, 0.2, 1.0);
uniform float dot_size : hint_range(0.01, 1.0) = 0.35;
uniform float dot_spacing : hint_range(10.0, 100.0) = 45.0;
uniform float fresnel_power : hint_range(0.1, 5.0) = 2.0;

void fragment() {
    // Edge highlight / Fresnel
    float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
    
    // Screen-space Halftone Dots (Y2K Manga/Screentone Aesthetic)
    vec2 pos = FRAGCOORD.xy;
    vec2 grid = fract(pos / dot_spacing) - 0.5;
    float dist = length(grid);
    float circle = smoothstep(dot_size, dot_size - 0.05, dist);
    
    // Smooth outer edge for "Inverted Hull" outline feel
    float edge = smoothstep(0.7, 0.9, f);
    
    vec3 final_color = mix(shield_color.rgb, halftone_color.rgb, circle * (1.0 - edge));
    final_color = mix(final_color, vec3(0.9, 0.6, 1.0), edge); // Glowing bright purple/white rim
    
    ALBEDO = final_color;
    // Fade out centers slightly unless hitting a screentone dot
    ALPHA = clamp(shield_color.a * f + (circle * 0.6), 0.0, 1.0);
}
