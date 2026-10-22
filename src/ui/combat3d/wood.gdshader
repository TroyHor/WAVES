shader_type spatial;
// Procedural desk wood: grain running away from the operator (along z).

uniform vec3 light_col : source_color = vec3(0.27, 0.17, 0.10);
uniform vec3 dark_col : source_color = vec3(0.15, 0.09, 0.055);

varying vec3 wp;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wp.xz;
	float n = noise(p * vec2(2.0, 0.35)) * 2.0 + noise(p * vec2(9.0, 1.2)) * 0.5;
	float g = fract(p.x * 7.0 + n);
	float ring = smoothstep(0.0, 0.25, g) * smoothstep(1.0, 0.6, g);
	float fine = noise(p * vec2(160.0, 6.0));
	vec3 c = mix(dark_col, light_col, ring * 0.55 + fine * 0.15);
	ALBEDO = c;
	ROUGHNESS = 0.55 + fine * 0.2;
	SPECULAR = 0.4;
}
