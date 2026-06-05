shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

uniform vec4 base_color : source_color = vec4(0.8, 0.9, 1.0, 0.4);
uniform vec4 iridescence : source_color = vec4(1.0, 0.5, 0.8, 1.0);
uniform float speed = 2.0;

void fragment() {
    // Calculate Fresnel to fade the center slightly
    float fresnel = sqrt(1.0 - dot(NORMAL, VIEW));
    fresnel = smoothstep(0.3, 1.0, fresnel);
    
    // Distort and add color waves for that Y2K liquid plastic look
    float wave = sin(TIME * speed + VERTEX.y * 10.0 + VERTEX.x * 5.0) * 0.5 + 0.5;
    float wave2 = cos(TIME * speed * 0.7 - VERTEX.z * 8.0) * 0.5 + 0.5;
    
    vec3 final_color = mix(base_color.rgb, iridescence.rgb, fresnel * (wave * wave2));
    
    // Specular highlight dot
    float spec = pow(max(0.0, dot(reflect(-VIEW, NORMAL), vec3(0.5, 0.8, 0.5))), 16.0);
    final_color += vec3(spec);
    
    ALBEDO = final_color;
    ALPHA = base_color.a + (fresnel * 0.5) + spec;
}

