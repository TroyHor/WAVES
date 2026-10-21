shader_type canvas_item;
// Whole-screen finishing pass. Deliberately calm (Balatro-like): soft phosphor
// bloom, a faint constant colour fringe, slow film grain and a vignette. The
// only motion is an event-driven smooth shockwave ripple on impacts; there is
// no random tearing, flicker or block noise.
// `curvature` defaults to 0; if raised, Main._fx_map() mirrors barrel().

uniform float curvature = 0.0;
uniform float bloom = 0.35;
uniform float aberration = 0.5;
uniform float vignette = 0.22;
uniform float grain = 0.018;
uniform vec2 source_size = vec2(1920.0, 1080.0);
// Ripple: centre in UV, time since impact in seconds (< 0 = none), strength 0..1.
uniform vec2 ripple_center = vec2(0.5, 0.5);
uniform float ripple_t = -1.0;
uniform float ripple_strength = 0.0;

vec2 barrel(vec2 uv) {
	vec2 c = uv * 2.0 - 1.0;
	c *= 1.0 + curvature * dot(c, c);
	return c * 0.5 + 0.5;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = barrel(UV);
	float aspect = source_size.x / source_size.y;

	if (ripple_t >= 0.0 && ripple_strength > 0.0) {
		vec2 d = uv - ripple_center;
		d.x *= aspect;
		float dist = length(d);
		float radius = ripple_t * 1.6;
		float fade = 1.0 - clamp(ripple_t / 0.9, 0.0, 1.0);
		float ring = exp(-pow((dist - radius) * 14.0, 2.0)) * ripple_strength * fade;
		vec2 dir = d / max(dist, 1e-4);
		dir.x /= aspect;
		uv -= dir * ring * 0.014;
	}

	vec2 px = 1.0 / source_size;
	vec2 dir = uv - 0.5;
	vec2 off = dir * length(dir) * aberration * 4.0 * px;
	vec3 col = vec3(texture(TEXTURE, uv + off).r, texture(TEXTURE, uv).g, texture(TEXTURE, uv - off).b);

	vec3 glow = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		vec2 o = vec2(cos(a), sin(a));
		glow += texture(TEXTURE, uv + o * px * 3.0).rgb;
		glow += texture(TEXTURE, uv + o * px * 8.0).rgb;
	}
	glow /= 16.0;
	col += max(glow - 0.12, vec3(0.0)) * bloom;

	col += (hash(floor(uv * source_size * 0.5) + floor(TIME * 8.0)) - 0.5) * grain;

	float vig = pow(16.0 * uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y), vignette);
	col *= vig;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		col = vec3(0.0);
	}
	COLOR = vec4(col, 1.0);
}
