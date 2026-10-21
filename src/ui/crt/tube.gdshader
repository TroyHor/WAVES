shader_type canvas_item;
// CRT tube inside a bench oscilloscope. Applied to the TextureRect that shows a
// scope's SubViewport. The barrel is normalised by (1 + curvature) so the
// centre line's ends and middle stay where they were: grid columns keep
// lining up with the merged panel, while the corners bulge and round off.

uniform float curvature = 0.05;
uniform float scanline_strength = 0.16;
uniform float glow = 0.5;
uniform float vignette = 0.35;
uniform vec4 glass_tint : source_color = vec4(0.02, 0.05, 0.035, 1.0);
uniform vec2 tube_size = vec2(1400.0, 160.0);

vec2 barrel(vec2 uv) {
	vec2 c = uv * 2.0 - 1.0;
	c *= (1.0 + curvature * dot(c, c)) / (1.0 + curvature);
	return c * 0.5 + 0.5;
}

void fragment() {
	vec2 uv = barrel(UV);
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = glass_tint;
	} else {
		vec2 px = 1.0 / tube_size;
		vec3 col = texture(TEXTURE, uv).rgb;
		vec3 g = vec3(0.0);
		for (int i = 0; i < 6; i++) {
			float a = float(i) * 1.047198;
			g += texture(TEXTURE, uv + vec2(cos(a), sin(a)) * px * 3.0).rgb;
		}
		col += max(g / 6.0 - 0.1, vec3(0.0)) * glow;
		float scan = 0.5 + 0.5 * sin(uv.y * tube_size.y * 3.14159);
		col *= 1.0 - scanline_strength * (1.0 - scan);
		// Soft falloff toward the glass edge.
		vec2 e = uv * (1.0 - uv);
		col *= pow(clamp(e.x * e.y * 30.0, 0.0, 1.0), vignette);
		col = mix(glass_tint.rgb, col, smoothstep(0.0, 0.012, min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y))));
		COLOR = vec4(col, 1.0);
	}
}
