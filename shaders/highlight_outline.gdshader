shader_type canvas_item;

uniform sampler2D highlighted_viewport_tex : filter_nearest;
uniform vec4 color_outline : source_color = vec4(0.86, 0.08, 0.24, 1.0);
uniform float width_outline = 3.0;

// Hardcoding the radius as a constant avoids compiler unroll errors on WebGL/GLES 
// while retaining perfectly dense, gapless 3-pixel outlines.
const int OUTLINE_RADIUS = 3;

void fragment() {
    vec4 tex = texture(highlighted_viewport_tex, UV);
    if (tex.a > 0.01) {
        discard; // Hollow inside so original rendering shows through
    }
    
    vec2 pixel_size = 1.0 / vec2(textureSize(highlighted_viewport_tex, 0));
    bool is_outline = false;
    
    for (int x = -OUTLINE_RADIUS; x <= OUTLINE_RADIUS; x++) {
        for (int y = -OUTLINE_RADIUS; y <= OUTLINE_RADIUS; y++) {
            if (x == 0 && y == 0) continue;
            
            vec2 offset = vec2(float(x), float(y)) * pixel_size;
            if (texture(highlighted_viewport_tex, UV + offset).a > 0.01) {
                is_outline = true;
                break;
            }
        }
        if (is_outline) break;
    }
    
    if (is_outline) {
        COLOR = color_outline;
    } else {
        discard;
    }
}
