shader_type spatial;
// Added depth_test_disabled and blend_mix to prevent an opaque quad from occluding all transparent sprites behind it
render_mode cull_disabled, unshaded, shadows_disabled, fog_disabled, depth_test_disabled, blend_mix;

uniform int width_outline = 3;
uniform vec4 color_inner : source_color = vec4(1.0, 1.0, 1.0, 0.0); // Transparent fill
uniform vec4 color_outline : source_color = vec4(0.05, 0.05, 0.15, 1.0); // Dark Indigo

uniform sampler2D highlighted_viewport_tex : repeat_disable;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 suv = SCREEN_UV;
	
	vec4 h_tex = texture(highlighted_viewport_tex, suv);
	bool is_inner = h_tex.a > 0.01;
	bool is_outline = false;
	
	if (!is_inner) {
		vec2 p = 1.0 / vec2(VIEWPORT_SIZE.xy);
		for (int x = -width_outline; x <= width_outline && !is_outline; ++x) {
			for (int y = -width_outline; y <= width_outline && !is_outline; ++y) {
				if (y == 0 && x == 0) { continue; }
				vec2 n_uv = suv + vec2(p.x * float(x), p.y * float(y));
				vec4 n_h_tex = texture(highlighted_viewport_tex, n_uv);
				if (n_h_tex.a > 0.01) {
					is_outline = true;
				}
			}
		}
	}
	
	// Write purely the outline overlay without interfering with the screen textures behind it
	if (is_inner) {
		ALBEDO = color_inner.rgb;
		ALPHA = color_inner.a;
	} else if (is_outline) {
		ALBEDO = color_outline.rgb;
		ALPHA = color_outline.a;
	} else {
		discard;
	}
}
