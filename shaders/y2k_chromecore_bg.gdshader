shader_type canvas_item;

// Hypnotic Y2K Liquid Chrome Background
uniform vec4 color_1 : source_color = vec4(0.8, 0.9, 1.0, 1.0); // Bright Silver/Cyan
uniform vec4 color_2 : source_color = vec4(0.1, 0.3, 0.8, 1.0); // Deep Cobalt Blue
uniform vec4 color_3 : source_color = vec4(0.9, 0.9, 1.0, 1.0); // Pure Chrome White
uniform float speed = 0.5;

void fragment() {
    vec2 uv = UV;
    
    // Distort UVs for liquid metal flow
    vec2 flow_uv = uv * 3.0;
    flow_uv.x += sin(flow_uv.y * 2.0 + TIME * speed) * 0.5;
    flow_uv.y += cos(flow_uv.x * 2.5 + TIME * speed * 1.2) * 0.5;
    
    // Create an iridescent oil-spill / liquid chrome pattern
    float n = sin(flow_uv.x * 3.0 + flow_uv.y * 2.0) * 0.5 + 0.5;
    n = pow(n, 1.5);
    
    // Mix colors based on the chaotic noise
    vec3 final_color = mix(color_2.rgb, color_1.rgb, n);
    
    // Add sharp specular chrome highlights
    float spec = smoothstep(0.7, 0.9, sin(flow_uv.y * 5.0 - flow_uv.x * 4.0 + TIME));
    final_color = mix(final_color, color_3.rgb, spec * 0.8);
    
    // Overlay a subtle perspective grid
    vec2 grid_uv = (uv - 0.5) * 2.0;
    grid_uv.x *= 1.0 + grid_uv.y * 0.5; // Fake perspective warp
    vec2 grid = fract(grid_uv * 10.0 - vec2(0.0, TIME * 2.0));
    float lines = smoothstep(0.05, 0.0, grid.x) + smoothstep(0.05, 0.0, grid.y);
    
    final_color += vec3(lines * 0.15); // Subtle white grid glow
    
    // Vignette
    float vig = length(UV - 0.5) * 2.0;
    final_color -= vec3(smoothstep(0.5, 1.5, vig) * 0.4);

    COLOR = vec4(final_color, 1.0);
}
