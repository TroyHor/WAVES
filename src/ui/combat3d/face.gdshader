shader_type spatial;
render_mode cull_disabled;
// Instrument face: the 2D face art (rendered in a SubViewport) on cream
// plastic; transparent corners fall back to the case colour. Saturated print
// (lamps, digits, HP bars) glows a little so it reads as lit.

uniform sampler2D face_tex : source_color, filter_linear;
uniform vec3 case_col : source_color = vec3(0.86, 0.82, 0.72);
uniform float glow = 0.5;
// The face art already carries painted shading; keep it below white under the lamp.
uniform float albedo_scale = 0.78;

void fragment() {
	vec4 t = texture(face_tex, UV);
	vec3 c = mix(case_col, t.rgb, t.a);
	ALBEDO = c * albedo_scale;
	ROUGHNESS = 0.55;
	SPECULAR = 0.35;
	float sat = max(max(c.r, c.g), c.b) - min(min(c.r, c.g), c.b);
	EMISSION = c * smoothstep(0.45, 0.85, sat) * glow;
}
