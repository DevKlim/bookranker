shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec2 rect_size;
uniform float refraction : hint_range(0.0, 0.2) = 0.025;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.2);
uniform float specular : hint_range(0.0, 1.0) = 0.5;
uniform float corner_radius = 8.0;
uniform float bezel_width = 8.0;

float rounded_box(vec2 center_pos, vec2 half_size, float r) {
    vec2 q = abs(center_pos) - half_size + vec2(r);
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

void fragment() {
    vec2 pixel_pos = UV * rect_size;
    vec2 half_size = rect_size * 0.5;
    vec2 center_pos = pixel_pos - half_size;
    
    float dist = rounded_box(center_pos, half_size, corner_radius);
    if (dist > 0.0) {
        COLOR = vec4(0.0);
    } else {
        float d_border = -dist; 
        
        vec2 normal = vec2(0.0);
        float spec = 0.0;
        
        if (d_border < bezel_width) {
            vec2 q = abs(center_pos) - half_size + vec2(corner_radius);
            vec2 g = vec2(0.0);
            if (q.x > 0.0 && q.y > 0.0) {
                g = normalize(q);
            } else if (q.x > 0.0) {
                g = vec2(1.0, 0.0);
            } else if (q.y > 0.0) {
                g = vec2(0.0, 1.0);
            } else {
                if (q.x > q.y) {
                    g = vec2(1.0, 0.0);
                } else {
                    g = vec2(0.0, 1.0);
                }
            }
            g *= sign(center_pos);
            
            float t = d_border / bezel_width; 
            float curve = cos(t * 1.570796); 
            normal = g * curve;
            
            vec2 light_dir = normalize(vec2(-1.0, -1.0)); 
            spec = max(dot(g * curve, light_dir), 0.0) * pow(1.0 - t, 2.0);
        }
        
        vec2 uv_screen = SCREEN_UV - normal * refraction;
        vec3 color = textureLod(screen_texture, uv_screen, 1.0).rgb;
        
        color = mix(color, tint.rgb, tint.a);
        color += vec3(spec * specular);
        
        COLOR = vec4(color, 1.0);
    }
}