shader_type canvas_item;

// Cyber Y2K / Futurism background shader
uniform vec4 bg_top : source_color = vec4(0.02, 0.05, 0.15, 1.0); // Deep cyber blue
uniform vec4 bg_bottom : source_color = vec4(0.75, 0.9, 1.0, 1.0); // Bright silver/cyan horizon
uniform vec4 grid_color : source_color = vec4(0.0, 0.8, 1.0, 0.8); // Glowing cyan grid
uniform float speed : hint_range(0.0, 5.0) = 1.5;

void fragment() {
    vec2 uv = UV;
    vec2 centered_uv = uv * 2.0 - 1.0; // -1.0 to 1.0
    
    // Sleek gradient background
    vec3 col = mix(bg_top.rgb, bg_bottom.rgb, smoothstep(-0.5, 1.0, uv.y));
    
    // Bottom Half - Perspective Grid (Classic Cyber Y2K staple)
    if (centered_uv.y > 0.0) {
        // Perspective divide to simulate 3D ground plane
        vec2 plane_uv = vec2(centered_uv.x / centered_uv.y, 1.0 / centered_uv.y);
        plane_uv.y -= TIME * speed;
        
        // Create grid lines
        vec2 grid = fract(plane_uv * 4.0);
        // Make lines thinner further away to prevent moire patterns
        float line_thickness = mix(0.02, 0.15, centered_uv.y); 
        float lines = step(1.0 - line_thickness, grid.x) + step(1.0 - line_thickness, grid.y);
        
        // Depth fade for grid (fade out near the horizon)
        float fade = smoothstep(0.0, 0.6, centered_uv.y);
        
        col = mix(col, grid_color.rgb, clamp(lines, 0.0, 1.0) * fade * grid_color.a);
        
        // Add a pulsing bright horizon line
        float horizon_glow = smoothstep(0.1, 0.0, centered_uv.y) * abs(sin(TIME * 2.0)) * 0.5;
        col += grid_color.rgb * horizon_glow;
    } 
    // Top Half - Floating Tech Rings & Data Streams
    else {
        vec2 sky_uv = centered_uv;
        sky_uv.y += 0.4; // Shift center focus up
        float radius = length(sky_uv);
        
        // Expanding abstract vector rings
        float ring_val = fract(radius * 4.0 - TIME * 0.5);
        float ring = smoothstep(0.9, 1.0, ring_val) * smoothstep(0.0, 0.8, radius); 
        
        // Inner digital glow
        float glow = 0.01 / (abs(ring_val - 0.5) + 0.01);
        
        col += grid_color.rgb * ring * 0.4;
        col += grid_color.rgb * glow * 0.15 * smoothstep(1.0, 0.0, radius);
    }
    
    // Subtle digital scanlines overlay
    float scanline = sin(UV.y * 900.0) * 0.03;
    col -= scanline;
    
    COLOR = vec4(col, 1.0);
}
