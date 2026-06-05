shader_type spatial;
render_mode blend_add, unshaded, cull_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 emission_color : source_color = vec4(0.2, 0.9, 1.0, 0.8);
uniform float erosion : hint_range(0.0, 1.0) = 0.0;
uniform float distortion_strength : hint_range(0.0, 1.0) = 0.3;

void fragment() {
    vec2 scrolling_uv = UV + vec2(TIME * 0.5, TIME * 0.2);
    vec4 noise = texture(noise_tex, scrolling_uv);
    
    // Y2K energy wave pattern
    float wave = sin(UV.y * 20.0 + TIME * 5.0) * 0.5 + 0.5;
    float alpha = noise.r * wave;
    
    // Smoothly erode the alpha mask over time
    alpha = smoothstep(erosion, erosion + 0.1, alpha);
    
    ALBEDO = emission_color.rgb * (1.0 + distortion_strength * noise.g);
    ALPHA = alpha * emission_color.a * (1.0 - erosion);
}
