shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled;

uniform vec4 grid_color : source_color = vec4(0.0, 0.5, 1.0, 0.3);

void fragment() {
    // UV x goes from 0 to 1. We mapped X=-50 to X=0.
    // So UV.x = 1 is X=0 (The boundary)
    
    vec2 grid_uv = UV * vec2(25.0, 100.0); 
    grid_uv.y -= TIME * 0.5; // Flow towards the core
    
    vec2 grid = fract(grid_uv);
    float line_x = step(0.95, grid.x);
    float line_y = step(0.95, grid.y);
    float lines = max(line_x, line_y);
    
    // Distance to the boundary (UV.x = 1.0)
    float dist_to_edge = 1.0 - UV.x;
    
    // Warning line right at the edge
    float edge_line = smoothstep(0.005, 0.0, dist_to_edge);
    float edge_glow = smoothstep(0.02, 0.0, dist_to_edge) * (sin(TIME * 5.0) * 0.5 + 0.5);
    
    // Fade out towards the back (UV.x = 0)
    float back_fade = smoothstep(0.0, 0.5, UV.x);
    
    vec3 col = grid_color.rgb;
    col += edge_line * vec3(1.0); // White solid edge
    col += edge_glow * grid_color.rgb * 2.0;
    
    float alpha = (lines * grid_color.a + edge_line + edge_glow) * back_fade;
    
    ALBEDO = col;
    ALPHA = clamp(alpha, 0.0, 1.0);
}
