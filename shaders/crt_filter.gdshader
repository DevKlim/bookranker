shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float curvature : hint_range(0.0, 10.0) = 10.0;
uniform float vignette_multiplier : hint_range(0.0, 5.0) = 0.5;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float bloom_intensity : hint_range(0.0, 1.0) = 0.25;
uniform float blur_amount : hint_range(0.0, 5.0) = 2.0;

void fragment() {
    // 1. Curvature
    vec2 centered_uv = SCREEN_UV * 2.0 - 1.0;
    vec2 offset = centered_uv.yx / curvature;
    vec2 warped_uv = centered_uv + centered_uv * offset * offset;
    warped_uv = warped_uv * 0.5 + 0.5;
    
    if (warped_uv.x < 0.0 || warped_uv.x > 1.0 || warped_uv.y < 0.0 || warped_uv.y > 1.0) {
        COLOR = vec4(0.0, 0.0, 0.0, 1.0);
    } else {
        vec2 tex_size = vec2(textureSize(SCREEN_TEXTURE, 0));
        vec2 pixel_size = 1.0 / tex_size;
        
        // 2. Dithery Blur (Simulate phosphor bleeding horizontally)
        // Sample slightly left, center, right
        vec3 col_l = texture(SCREEN_TEXTURE, warped_uv - vec2(pixel_size.x * blur_amount, 0.0)).rgb;
        vec3 col_c = texture(SCREEN_TEXTURE, warped_uv).rgb;
        vec3 col_r = texture(SCREEN_TEXTURE, warped_uv + vec2(pixel_size.x * blur_amount, 0.0)).rgb;
        
        // Combine with mild chromatic aberration
        vec3 col = vec3(
            col_l.r * 0.5 + col_c.r * 0.5,
            col_c.g,
            col_r.b * 0.5 + col_c.b * 0.5
        );
        
        // 3. Bloom / Glow (using mipmap)
        vec3 glow = textureLod(SCREEN_TEXTURE, warped_uv, 2.0).rgb;
        col = col + glow * bloom_intensity;
        
        // 4. Phosphor Mask (CRT-Guest/Royale style RGB mask)
        // Create a repeating mask pattern based on screen fragments
        vec2 frag_coord = FRAGCOORD.xy;
        float mod_x = mod(frag_coord.x, 3.0);
        float mask_darken = 0.8;
        vec3 mask = vec3(1.0);
        
        if (mod_x < 1.0) {
            mask = vec3(1.0, mask_darken, mask_darken);
        } else if (mod_x < 2.0) {
            mask = vec3(mask_darken, 1.0, mask_darken);
        } else {
            mask = vec3(mask_darken, mask_darken, 1.0);
        }
        
        // Apply mask but keep overall brightness relatively high
        col *= mix(vec3(1.0), mask, 0.5);
        
        // 5. Scanlines (smooth sine wave)
        float scanline_weight = (sin(warped_uv.y * tex_size.y * 3.14159) * 0.5 + 0.5);
        col = mix(col, col * 0.7, scanline_weight * scanline_intensity);
        
        // 6. Vignette
        float vignette = length(centered_uv);
        vignette = smoothstep(0.5, 1.5, vignette);
        col *= 1.0 - (vignette * vignette_multiplier);
        
        // Gamma correction to give it that punchy CRT look
        col = pow(col, vec3(1.1));
        
        COLOR = vec4(col, 1.0);
    }
}
