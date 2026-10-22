shader_type spatial;
render_mode cull_disabled;
// Phosphor picture behind convex glass: the screen SubViewport is emitted,
// darkened towards the edges and scanned; the glass itself is glossy, so the
// lamp's highlight and the fresnel rim come from the real curved geometry.

uniform sampler2D screen_tex : source_color, filter_linear;
uniform vec3 glass_tint : source_color = vec3(0.02, 0.03, 0.03);
uniform float energy = 1.4;
uniform float lines = 220.0;

void fragment() {
	vec3 c = texture(screen_tex, UV).rgb;
	vec2 q = UV * 2.0 - 1.0;
	float vig = clamp(1.0 - 0.45 * pow(abs(q.x), 6.0) - 0.6 * pow(abs(q.y), 4.0), 0.0, 1.0);
	float scan = 0.88 + 0.12 * sin(UV.y * lines * 6.2832);
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = glass_tint;
	ROUGHNESS = 0.05;
	SPECULAR = 0.9;
	// Reflection of the desk lamp's shade, fixed just above-left of the view
	// direction: it only shows where the bulge tilts the glass towards it, so
	// it sits on the upper-left shoulder of each tube and slides with parallax.
	vec3 r = reflect(-VIEW, NORMAL);
	float d = dot(r, normalize(vec3(-0.07, 0.09, 1.0)));
	float spot = smoothstep(0.9975, 0.9996, d) * 0.5 + pow(max(d, 0.0), 900.0) * 0.25;
	vec3 refl = vec3(1.0, 0.9, 0.75) * spot;
	EMISSION = c * energy * vig * scan + refl + vec3(0.5, 0.45, 0.4) * fr * 0.25;
}
