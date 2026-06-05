shader_type spatial;
// Added depth_test_disabled so it draws over geometry like blocks
render_mode blend_mix, unshaded, depth_test_disabled;

uniform vec4 aura_color : source_color = vec4(0.7, 0.1, 1.0, 1.0);
uniform float pulse_expand = 0.0;
uniform float screentone_scale = 0.5; // Adjusted for absolute pixel coordinates

void vertex() {
    // Y2K Billboard setup ensuring it faces the camera perfectly
    mat4 modified_model_view = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
    MODELVIEW_MATRIX = modified_model_view;

    // Push vertex space away from the camera to render seamlessly *behind* the enemy
    VERTEX.z -= 1.0;
}

void fragment() {
    // Local UV of the quad from -1.0 to 1.0
    vec2 uv = UV * 2.0 - 1.0;
    float dist = length(uv);

    float radius = 0.7 + (pulse_expand * 0.3);
    
    // Y2K Screentone Dots using absolute screen pixels to prevent aspect ratio stretching
    vec2 screen_uv = FRAGCOORD.xy * screentone_scale;
    float dot_pattern = sin(screen_uv.x) * sin(screen_uv.y);
    float halftone = smoothstep(0.0, 0.25, dot_pattern);

    // Hollow out the center slightly so it frames the enemy (Halo effect)
    float halo = smoothstep(0.1, radius * 0.4, dist);
    
    // Soft fade-out the further the aura is from the enemy (Radial Falloff)
    float radial_fade = smoothstep(radius, radius * 0.01, dist);

    ALBEDO = aura_color.rgb;
    ALPHA = halftone * halo * radial_fade * aura_color.a;
}
