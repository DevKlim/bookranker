shader_type sky;

uniform sampler2D cross_tex : filter_nearest, source_color;
uniform float exposure : hint_range(0.01, 10.0) = 1.0;
uniform float color_depth : hint_range(1.0, 256.0) = 15.0; // 15-bit color like DS

void sky() {
    vec3 d = EYEDIR;
    vec3 abs_d = abs(d);
    vec2 uv = vec2(0.0);
    vec2 offset = vec2(0.0);
    
    // Determine which face of the cubemap we are looking at
    if (abs_d.x > abs_d.y && abs_d.x > abs_d.z) {
        if (d.x > 0.0) {
            // Right face (+X)
            uv = vec2(d.z, -d.y) / d.x * 0.5 + 0.5;
            offset = vec2(0.5, 0.3333333);
        } else {
            // Left face (-X)
            uv = vec2(-d.z, -d.y) / -d.x * 0.5 + 0.5;
            offset = vec2(0.0, 0.3333333);
        }
    } else if (abs_d.y > abs_d.x && abs_d.y > abs_d.z) {
        if (d.y > 0.0) {
            // Top face (+Y)
            uv = vec2(d.x, -d.z) / d.y * 0.5 + 0.5;
            offset = vec2(0.25, 0.0);
        } else {
            // Bottom face (-Y)
            uv = vec2(d.x, d.z) / -d.y * 0.5 + 0.5;
            offset = vec2(0.25, 0.6666667);
        }
    } else {
        if (d.z > 0.0) {
            // Back face (+Z)
            uv = vec2(-d.x, -d.y) / d.z * 0.5 + 0.5;
            offset = vec2(0.75, 0.3333333);
        } else {
            // Front / Center face (-Z)
            uv = vec2(d.x, -d.y) / -d.z * 0.5 + 0.5;
            offset = vec2(0.25, 0.3333333);
        }
    }
    
    // Clamp the local UV slightly to prevent bilinear filtering from bleeding 
    // into the "empty" black cells of the 4x3 cross format.
    uv = clamp(uv, 0.001, 0.999);
    uv = uv * vec2(0.25, 0.3333333) + offset;
    
    vec3 col = texture(cross_tex, uv).rgb;
    
    // N64 / DS Retro Color Banding (Posterization)
    col = floor(col * color_depth + 0.5) / color_depth;
    
    COLOR = col * exposure;
}
