shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, unshaded;

uniform vec4 aura_color : source_color = vec4(0.4, 0.0, 0.8, 1.0);
uniform vec4 core_color : source_color = vec4(0.1, 0.0, 0.2, 1.0);
uniform float speed = 5.0;
uniform float frequency = 10.0;
uniform float amplitude = 0.1;

void vertex() {
    // Make the mesh wobble erratically to simulate dark magic instability
    float wave = sin((VERTEX.y + TIME * speed) * frequency) * amplitude;
    VERTEX.x += wave;
    VERTEX.z += wave;
}

void fragment() {
    float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
    
    // Core is dark, rim pulses bright magic
    vec3 col = mix(core_color.rgb, aura_color.rgb, f * (0.8 + 0.2 * sin(TIME * 8.0)));
    
    ALBEDO = col;
    ALPHA = clamp(aura_color.a * f + 0.4, 0.0, 1.0);
}
