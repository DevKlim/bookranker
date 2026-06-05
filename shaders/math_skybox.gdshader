shader_type canvas_item;

uniform vec4 color_top : source_color = vec4(0.08, 0.05, 0.2, 1.0); // Deep violet space
uniform vec4 color_bottom : source_color = vec4(0.0, 0.6, 0.8, 1.0); // Bright cyan horizon
uniform vec4 grid_color : source_color = vec4(0.3, 0.9, 1.0, 0.4); // Tech grid
uniform sampler2D text_viewport : filter_linear_mipmap;

void fragment() {
    // Dreamcast wavy UV distortion
    vec2 uv = UV;
    uv.x += sin(uv.y * 6.0 + TIME * 0.6) * 0.02;
    uv.y += cos(uv.x * 5.0 + TIME * 0.4) * 0.02;

    // Gradient background
    vec3 bg = mix(color_bottom.rgb, color_top.rgb, UV.y);

    // Scrolling wireframe tech-grid
    vec2 grid_uv = fract(uv * 15.0 + vec2(TIME * 0.05, TIME * 0.1));
    float grid_line = step(0.95, grid_uv.x) + step(0.95, grid_uv.y);
    bg = mix(bg, grid_color.rgb, grid_line * grid_color.a);

    // Wavy scrolling for the symbols viewport
    vec2 sym_uv = UV;
    sym_uv.x += sin(sym_uv.y * 3.0 - TIME * 0.5) * 0.03;
    sym_uv.y += TIME * 0.05; // Base upward drift
    
    vec4 sym_tex = texture(text_viewport, fract(sym_uv));

    // Blend the symbols over the background
    vec3 final_color = mix(bg, vec3(1.0), sym_tex.a);

    COLOR = vec4(final_color, 1.0);
}
