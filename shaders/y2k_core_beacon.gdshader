shader_type spatial;
render_mode blend_add, unshaded, cull_disabled;

uniform vec4 core_color : source_color = vec4(0.0, 1.0, 0.8, 1.0);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float damage_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float alpha_multiplier : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    vec2 uv = UV;
    uv.y += TIME * 0.5;
    
    // Add jitter based on damage
    float glitch = (texture(noise_tex, vec2(TIME * 5.0, UV.y * 2.0)).r - 0.5) * 2.0;
    uv.x += glitch * damage_intensity * 0.1;
    
    vec4 noise = texture(noise_tex, uv * vec2(2.0, 1.0));
    
    // Core beam fading at edges
    float edge_fade = sin(UV.x * 3.14159);
    edge_fade = pow(edge_fade, 3.0);
    
    // Energy pulses
    float pulse = sin(UV.y * 10.0 - TIME * 3.0) * 0.5 + 0.5;
    float energy = mix(noise.r, pulse, 0.5);
    
    // Darken/glitch horizontally when damaged
    float damage_strips = step(0.8, fract(UV.y * 20.0 + TIME * 10.0 * damage_intensity)) * damage_intensity;
    
    vec3 final_color = core_color.rgb * energy * 2.0;
    final_color += vec3(damage_strips * 2.0, 0.0, 0.0); // Red glitches
    
    float alpha = edge_fade * core_color.a * (energy + 0.2) * (1.0 - damage_strips);
    
    // Soft fade near ground
    float ground_fade = smoothstep(0.0, 0.05, UV.y);
    alpha *= ground_fade;
    
    ALBEDO = final_color;
    ALPHA = clamp(alpha * alpha_multiplier, 0.0, 1.0);
}