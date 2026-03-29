shader_type sky;

uniform sampler2D cross_tex : filter_linear, source_color;
uniform float exposure : hint_range(0.01, 10.0) = 1.0;

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
    // 0.001 is roughly half a pixel on a 512x512 face (2048x1536 total).
    uv = clamp(uv, 0.001, 0.999);
    
    // Scale UV to fit one 1/4 by 1/3 cell and apply offset
    uv = uv * vec2(0.25, 0.3333333) + offset;
    
    vec3 col = texture(cross_tex, uv).rgb;
    COLOR = col * exposure;
}