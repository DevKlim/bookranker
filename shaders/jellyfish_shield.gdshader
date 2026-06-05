shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

uniform vec4 base_color : source_color = vec4(0.0, 0.4, 0.8, 0.3);
uniform vec4 rim_color : source_color = vec4(0.0, 0.8, 1.0, 0.8);
uniform float wobble_speed = 2.0;
uniform float wobble_amount = 0.05;

void vertex() {
    float t = TIME * wobble_speed;
    // Height factor keeps the top more stable while wobbling the bottom tentacles
    float height_factor = 1.0 - clamp(VERTEX.y + 0.5, 0.0, 1.0);
    
    VERTEX.x += sin(t + VERTEX.y * 5.0) * wobble_amount * height_factor;
    VERTEX.z += cos(t + VERTEX.y * 5.0) * wobble_amount * height_factor;
    
    // Flatten the bottom heavily to simulate the jellyfish bell
    if (VERTEX.y < 0.0) {
        VERTEX.y *= 0.5;
        // Flare out the base
        float flare = smoothstep(0.0, -1.0, VERTEX.y) * 0.2;
        VERTEX.x *= 1.0 + flare + sin(t * 2.0) * 0.05;
        VERTEX.z *= 1.0 + flare + sin(t * 2.0) * 0.05;
    }
}

void fragment() {
    // Fresnel rim
    float f = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
    float rim = pow(f, 2.0);
    
    // Vertical gradient (fade out at the bottom)
    float v_fade = smoothstep(-0.5, 0.5, UV.y);
    
    vec4 col = mix(base_color, rim_color, rim);
    ALBEDO = col.rgb;
    ALPHA = col.a * v_fade * (0.5 + rim * 0.5);
}
