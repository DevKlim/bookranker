shader_type canvas_item;

// Draws rotating tech rings and crosshairs perfectly in screen space
uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 0.3);
uniform vec2 resolution = vec2(1920.0, 1080.0);

float sdCircle(vec2 p, float r) {
    return length(p) - r;
}

mat2 rot(float a) {
    float s = sin(a), c = cos(a);
    return mat2(vec2(c, -s), vec2(s, c));
}

void fragment() {
    // Normalize coordinates respecting aspect ratio
    vec2 uv = (FRAGCOORD.xy * 2.0 - resolution.xy) / resolution.y;
    
    vec3 final = vec3(0.0);
    float alpha = 0.0;
    
    // Outer dashed rotating ring
    vec2 r_uv = uv * rot(TIME * 0.2);
    float d1 = abs(sdCircle(r_uv, 0.8));
    float angle1 = atan(r_uv.y, r_uv.x);
    // Create dashes
    float dash1 = step(0.5, fract(angle1 * 10.0));
    if (d1 < 0.005 && dash1 > 0.0) alpha += 1.0;
    
    // Inner fast rotating segmented ring
    vec2 r_uv2 = uv * rot(-TIME * 0.5);
    float d2 = abs(sdCircle(r_uv2, 0.6));
    float angle2 = atan(r_uv2.y, r_uv2.x);
    float dash2 = step(0.2, fract(angle2 * 4.0));
    if (d2 < 0.01 && dash2 > 0.0) alpha += 0.8;
    
    // Crosshair lines
    if (abs(uv.x) < 0.002 && abs(uv.y) < 0.9 && abs(uv.y) > 0.2) alpha += 0.5;
    if (abs(uv.y) < 0.002 && abs(uv.x) < 0.9 && abs(uv.x) > 0.2) alpha += 0.5;
    
    // Add some random static data blocks on the sides
    vec2 block_uv = fract(UV * vec2(20.0, 40.0) + vec2(0.0, TIME));
    if (UV.x > 0.85 && UV.x < 0.9 && UV.y > 0.2 && UV.y < 0.8) {
        if (block_uv.x > 0.2 && block_uv.y > 0.2 && fract(sin(UV.y * 100.0 + TIME)*10.0) > 0.5) {
            alpha += 0.2;
        }
    }
    
    COLOR = vec4(color.rgb, clamp(alpha, 0.0, 1.0) * color.a);
}
