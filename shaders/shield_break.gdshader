shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled;

uniform vec4 base_color : source_color = vec4(0.0, 0.8, 1.0, 0.8);
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D noise_tex;
uniform float threshold : hint_range(0.0, 1.0) = 0.0;
uniform float edge_thickness : hint_range(0.0, 0.2) = 0.05;

void fragment() {
    float n = texture(noise_tex, UV).r;
    
    // Dissolve the shield based on the noise map and threshold
    if (n < threshold) {
        discard;
    }
    
    // Y2K Neon/DS style edge glow along the breaking seams
    if (n < threshold + edge_thickness) {
        ALBEDO = rim_color.rgb;
        ALPHA = rim_color.a;
    } else {
        ALBEDO = base_color.rgb;
        ALPHA = base_color.a;
    }
}
