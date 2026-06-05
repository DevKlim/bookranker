shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// Perfect 2000s CG Abstract Object Shader
uniform float iridescence_strength : hint_range(0.0, 2.0) = 1.2;
uniform float metalness : hint_range(0.0, 1.0) = 1.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.05;

// Fake environmental reflection map generated mathematically
vec3 get_env_color(vec3 normal, vec3 view) {
    vec3 ref = reflect(-view, normal);
    float t = ref.y * 0.5 + 0.5;
    
    // Silver to Cyan to Deep Blue fake studio lighting
    vec3 sky = mix(vec3(0.0, 0.5, 1.0), vec3(1.0, 1.0, 1.0), smoothstep(0.0, 0.5, t));
    vec3 ground = mix(vec3(0.05, 0.1, 0.2), vec3(0.0, 0.5, 1.0), smoothstep(0.5, 1.0, t));
    
    // Add a sharp white horizon line
    float horizon = smoothstep(0.48, 0.5, t) * smoothstep(0.52, 0.5, t);
    return mix(ground, sky, t) + vec3(horizon * 2.0);
}

void fragment() {
    vec3 normal = normalize(NORMAL);
    vec3 view = normalize(VIEW);
    
    // Fresnel calculation for iridescence
    float fresnel = 1.0 - clamp(dot(normal, view), 0.0, 1.0);
    fresnel = pow(fresnel, 1.5);
    
    // Chromatic shifting based on angle (Pearlescent / CD back effect)
    vec3 iridescence = vec3(
        0.5 + 0.5 * sin(fresnel * 10.0 + TIME * 0.5),
        0.5 + 0.5 * sin(fresnel * 10.0 + TIME * 0.5 + 2.0),
        0.5 + 0.5 * sin(fresnel * 10.0 + TIME * 0.5 + 4.0)
    );
    
    vec3 env = get_env_color(normal, view);
    
    ALBEDO = mix(env, iridescence, fresnel * iridescence_strength);
    METALLIC = metalness;
    ROUGHNESS = roughness;
}
