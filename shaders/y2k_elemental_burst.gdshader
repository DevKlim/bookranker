shader_type spatial;
render_mode blend_add, unshaded, cull_disabled;

uniform vec4 burst_color : source_color = vec4(0.2, 0.8, 1.0, 1.0);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float time_scale = 2.0;
uniform float erosion : hint_range(0.0, 1.0) = 0.0;
uniform float distortion : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    vec2 uv = UV;
    // Y2K swirl distortion
    vec2 centered = uv - 0.5;
    float dist = length(centered);
    float angle = atan(centered.y, centered.x) + dist * 5.0 * distortion - TIME * time_scale;
    vec2 swirl_uv = vec2(cos(angle), sin(angle)) * dist + 0.5;
    
    vec4 noise = texture(noise_tex, swirl_uv + vec2(TIME * 0.5, TIME * 0.2));
    
    float ring = smoothstep(0.4, 0.5, dist) - smoothstep(0.5, 0.6, dist);
    float energy = noise.r * ring * 2.0;
    
    // Core glow
    float core = smoothstep(0.3, 0.0, dist) * noise.g;
    
    float alpha = (energy + core) * (1.0 - erosion);
    alpha = smoothstep(erosion, erosion + 0.1, alpha);
    
    ALBEDO = burst_color.rgb * (1.0 + core * 2.0);
    ALPHA = clamp(alpha * burst_color.a, 0.0, 1.0);
}
