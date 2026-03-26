shader_type spatial;
// Using blend_add for that glowing arcade aesthetic. 
// Standard culling prevents seeing the glowing inside of backfaces through holes.
render_mode unshaded, blend_add, depth_draw_opaque;

uniform vec4 glow_color : source_color = vec4(0.0, 0.8, 1.0, 1.0);
uniform float fresnel_power : hint_range(0.1, 10.0) = 2.0;
uniform float edge_intensity : hint_range(0.0, 5.0) = 0.5;

void fragment() {
    vec3 normal = normalize(NORMAL);
    vec3 view = normalize(VIEW);
    
    // Calculate grazing angle. 
    // Using abs() protects against flipped normals caused by bad topology!
    float fresnel = 1.0 - clamp(abs(dot(normal, view)), 0.0, 1.0);
    fresnel = pow(fresnel, fresnel_power);
    
    // Add a nostalgic pulsing effect
    float pulse = 0.8 + 0.2 * sin(TIME * 3.0);
    
    ALBEDO = glow_color.rgb * edge_intensity;
    ALPHA = fresnel * glow_color.a * pulse;
}
