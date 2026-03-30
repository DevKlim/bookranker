shader_type canvas_item;

uniform vec4 bg_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 dot_color : source_color = vec4(0.05, 0.05, 0.05, 1.0);
uniform float spacing : hint_range(10.0, 100.0) = 40.0;
uniform float dot_size : hint_range(0.01, 0.5) = 0.05;
uniform vec2 scroll_speed = vec2(12.0, 12.0);

void fragment() {
    // Scroll the coordinates slowly over time for the Y2K aesthetic
    vec2 pos = FRAGCOORD.xy + (TIME * scroll_speed);
    
    // Create the repeating grid
    vec2 grid = fract(pos / spacing) - 0.5;
    float dist = length(grid);
    
    // Anti-alias the dot edges smoothly
    float aa = 1.0 / spacing; 
    float circle = smoothstep(dot_size + aa, dot_size - aa, dist);
    
    // Mix the colors
    COLOR = mix(bg_color, dot_color, circle);
}
