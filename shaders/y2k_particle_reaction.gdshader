shader_type spatial;
render_mode blend_add, unshaded, depth_test_disabled, cull_disabled;

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float erosion_speed = 2.0;

void vertex() {
    // Billboard perfectly aligned to Camera
    mat4 modified_model_view = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
    MODELVIEW_MATRIX = modified_model_view;
}

void fragment() {
    vec4 tex = texture(texture_albedo, UV);
    // Distort inner noise based on time to simulate morphing energy
    vec2 noise_uv = UV + vec2(TIME * 0.5, -TIME * 0.5);
    float noise_val = texture(noise_tex, noise_uv).r;
    
    // Falloff mapping from center of particle out
    vec2 centered = UV * 2.0 - 1.0;
    float dist = length(centered);
    float core = smoothstep(1.0, 0.0, dist);
    
    // Mix the base particle effect mapping with the noise overlay
    float energy = core * (noise_val + 0.5);
    
    // Erode gracefully over particle lifetime 
    // Uses ParticleProcessMaterial COLOR.a directly to control effect threshold
    float erosion_threshold = 1.0 - COLOR.a;
    float mask = smoothstep(erosion_threshold, erosion_threshold + 0.1, energy);
    
    // Additive Overbright glow colors
    ALBEDO = COLOR.rgb * 2.0;
    
    // Final masking considers both the shader's core boundaries and the base texture alpha (for diverse shapes)
    ALPHA = mask * COLOR.a * tex.a;
}
