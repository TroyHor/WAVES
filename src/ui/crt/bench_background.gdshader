shader_type canvas_item;
// Game backdrop: a dark lab bench the cream instruments sit on. Deliberately
// NOT a grid and NOT green, so it never echoes the oscilloscope screen: warm
// charcoal with a soft desk-lamp pool of light, a fine anti-static-mat grain,
// low-frequency mottling, and a few dust motes drifting very slowly.

uniform vec4 shadow_color : source_color = vec4(0.045, 0.043, 0.048, 1.0);
uniform vec4 lit_color : source_color = vec4(0.18, 0.16, 0.135, 1.0);
uniform vec2 lamp_center = vec2(0.62, -0.08);
uniform vec2 size_px = vec2(1920.0, 1080.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	float aspect = size_px.x / size_px.y;
	vec2 p = UV * vec2(aspect, 1.0);
	// Desk-lamp pool: broad and soft.
	float d = length((UV - lamp_center) * vec2(aspect * 0.55, 1.0));
	float lamp = 1.0 - smoothstep(0.05, 1.15, d);
	vec3 col = mix(shadow_color.rgb, lit_color.rgb, lamp * lamp);
	// Low-frequency mottling + fine mat grain (static).
	col *= 0.92 + 0.12 * noise(p * 3.0);
	col += (hash(floor(UV * size_px)) - 0.5) * 0.018;
	// A few dust motes catching the lamp light.
	for (int i = 0; i < 14; i++) {
		float fi = float(i);
		vec2 m = vec2(hash(vec2(fi, 1.3)), hash(vec2(fi, 7.1)));
		m += vec2(sin(TIME * 0.05 + fi), cos(TIME * 0.04 + fi * 1.7)) * 0.03 + vec2(TIME * 0.004, 0.0);
		m = fract(m);
		float r = length((UV - m) * vec2(aspect, 1.0));
		col += vec3(1.0, 0.95, 0.85) * smoothstep(0.004, 0.0, r) * 0.12 * lamp;
	}
	COLOR = vec4(col, 1.0);
}
