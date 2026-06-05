shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_disabled, unshaded;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 base_color : source_color = vec4(0.2, 0.8, 1.0, 0.8);
uniform vec4 tip_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float speed = 8.0;

void fragment() {
    vec2 scroll_uv = UV;
    // Cylinder V (UV.y) goes from 0 at the target (+Y) to 1 at the cannon (-Y)
    // We want the water to flow from cannon to target, so we animate towards negative UV.y
    scroll_uv.y += TIME * speed;
    float noise = texture(noise_tex, scroll_uv).r;
    
    // Fresnel to soften the cylinder silhouettes into a glowing energy column seamlessly
    float fresnel = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 1.5);
    float edge = clamp(1.0 - fresnel, 0.0, 1.0);
    
    // UV.y = 0.0 is the target tip. We blend to white tip color precisely here.
    float tip_mix = smoothstep(0.3, 0.0, UV.y);
    vec3 final_color = mix(base_color.rgb, tip_color.rgb, tip_mix);
        
    ALBEDO = final_color + vec3(noise * 0.4);
    ALPHA = mix(base_color.a, tip_color.a, tip_mix) * edge * (noise * 0.7 + 0.3);
}
