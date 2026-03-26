shader_type spatial;
render_mode unshaded, depth_draw_opaque, cull_disabled, blend_mix;

uniform sampler2D texture_albedo : source_color, filter_nearest;
uniform vec4 glow_color : source_color = vec4(0.2, 0.8, 1.0, 0.2);
uniform float width : hint_range(0.0, 10.0) = 2.0;

void fragment() {
	vec4 col = texture(texture_albedo, UV);
	vec2 size = vec2(textureSize(texture_albedo, 0));
	float px = width / size.x;
	float py = width / size.y;
	
	float alpha = col.a;
	// Soft sampling for a glowing aura instead of a hard outline
	alpha += texture(texture_albedo, UV + vec2(px, 0.0)).a * 0.5;
	alpha += texture(texture_albedo, UV + vec2(-px, 0.0)).a * 0.5;
	alpha += texture(texture_albedo, UV + vec2(0.0, py)).a * 0.5;
	alpha += texture(texture_albedo, UV + vec2(0.0, -py)).a * 0.5;
	alpha += texture(texture_albedo, UV + vec2(px, py)).a * 0.25;
	alpha += texture(texture_albedo, UV + vec2(-px, -py)).a * 0.25;
	alpha += texture(texture_albedo, UV + vec2(px, -py)).a * 0.25;
	alpha += texture(texture_albedo, UV + vec2(-px, py)).a * 0.25;
	
	float pulse = 0.8 + 0.2 * sin(TIME * 3.0);
	
	if (col.a < 0.1) {
		if (alpha > 0.1) {
			ALBEDO = glow_color.rgb;
			ALPHA = clamp(alpha, 0.0, 1.0) * glow_color.a * pulse;
		} else {
			discard;
		}
	} else {
		ALBEDO = col.rgb;
		ALPHA = col.a;
	}
}
