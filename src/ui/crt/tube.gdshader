shader_type canvas_item;
// CRT tube inside a bench oscilloscope. Applied to the TextureRect that shows a
// scope's SubViewport. Depth comes from the glass: the hood in front of the tube shades its rim
// (most along the top, since the operator looks down at it) and the bulging
// glass catches a curved highlight. The barrel (normalised by 1 + curvature
// so the centre line's ends and middle stay put and grid columns keep lining
// up) shows the bulge; the lighting is applied over picture and bare glass
// alike so the warp reads as curved glass rather than a flat effect.

uniform float curvature = 0.05;
// Rim shading from the hood, in pixels (top, sides, bottom).
uniform vec3 rim_px = vec3(26.0, 14.0, 8.0);
uniform float rim_strength = 0.6;
uniform float scanline_strength = 0.16;
uniform float glow = 0.5;
uniform float vignette = 0.35;
uniform vec4 glass_tint : source_color = vec4(0.02, 0.05, 0.035, 1.0);
uniform vec2 tube_size = vec2(1400.0, 160.0);
// Curved-glass reflection (soft diagonal sheen + bright upper edge).
uniform float reflection = 0.08;
// Rounded tube corners, in pixels.
uniform float corner_radius = 22.0;

vec2 barrel(vec2 uv) {
	vec2 c = uv * 2.0 - 1.0;
	c *= (1.0 + curvature * dot(c, c)) / (1.0 + curvature);
	return c * 0.5 + 0.5;
}

float corner_mask(vec2 uv01) {
	vec2 p = uv01 * tube_size;
	vec2 q = min(p, tube_size - p);
	if (q.x >= corner_radius || q.y >= corner_radius) {
		return 1.0;
	}
	float d = length(vec2(corner_radius) - q);
	return 1.0 - smoothstep(corner_radius - 1.5, corner_radius + 0.5, d);
}

void fragment() {
	vec2 uv = barrel(UV);
	vec3 col = glass_tint.rgb;
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	if (inside > 0.5) {
		vec2 px = 1.0 / tube_size;
		col = texture(TEXTURE, uv).rgb;
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
	}
	// The bulge is real glass: the same lighting covers the picture and the
	// bare glass in the corners, so the distortion reads as curvature.
	// Hood shading: the rim recedes under the bezel (stronger at the top).
	vec2 p = UV * tube_size;
	float top = 1.0 - smoothstep(0.0, rim_px.x, p.y);
	float side = 1.0 - smoothstep(0.0, rim_px.y, min(p.x, tube_size.x - p.x));
	float bottom = 1.0 - smoothstep(0.0, rim_px.z, tube_size.y - p.y);
	col *= 1.0 - rim_strength * max(max(top, side * 0.8), bottom * 0.6);
	// Where the picture's warped edge meets the glass, the curved surface
	// catches a thin line of light (brightest along the top, facing the lamp).
	vec2 c = UV * 2.0 - 1.0;
	float edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float fresnel = smoothstep(0.018, 0.0, abs(edge)) * (0.35 + 0.65 * smoothstep(0.2, -0.8, c.y));
	col += vec3(fresnel * reflection * 1.6 * step(0.0001, curvature));
	// Convex face plate: a soft sheen across the upper-left and a highlight
	// band that bows down toward the corners, following the bulge.
	float sheen = smoothstep(0.55, 0.0, UV.x * 0.35 + UV.y) * reflection * 0.7;
	float bx = UV.x - 0.5;
	float band_y = 0.1 + (0.5 + curvature * 4.0) * bx * bx;
	float band = smoothstep(0.05, 0.0, abs(UV.y - band_y)) * (1.0 - smoothstep(0.3, 0.5, abs(bx)));
	col += vec3(sheen + band * reflection * 0.9);
	COLOR = vec4(col, 1.0);
	COLOR = mix(glass_tint, COLOR, corner_mask(UV));
}
