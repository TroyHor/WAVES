shader_type canvas_item;
// Glass of the main oscilloscope tube, behind the traces: deep green CRT
// phosphor with a brighter rim (light leaking at the curved edge, strongest at
// the bottom like a real tube), a faint residual glow in the middle and a very
// slow, barely visible phosphor shimmer so the screen feels alive.

uniform vec4 deep_color : source_color = vec4(0.01, 0.06, 0.04, 1.0);
uniform vec4 mid_color : source_color = vec4(0.03, 0.14, 0.09, 1.0);
uniform vec4 rim_color : source_color = vec4(0.12, 0.42, 0.24, 1.0);
uniform float aspect = 4.0;
uniform float shimmer = 0.05;

void fragment() {
	vec2 c = (UV - 0.5) * vec2(aspect, 1.0);
	float centre = 1.0 - smoothstep(0.0, aspect * 0.55, length(c * vec2(0.7, 1.6)));
	vec3 col = mix(deep_color.rgb, mid_color.rgb, centre);
	// Rim light: distance to the edge, boosted along the bottom.
	vec2 e = min(UV, 1.0 - UV);
	float edge = min(e.x * aspect, e.y);
	float rim = (1.0 - smoothstep(0.0, 0.12, edge)) * (0.55 + 0.45 * smoothstep(0.4, 1.0, UV.y));
	col = mix(col, rim_color.rgb, rim * 0.6);
	// Slow phosphor shimmer.
	float t = TIME * 0.07;
	float f = sin(c.x * 2.2 + sin(c.y * 3.0 + t * 2.0) * 1.2 + t * 3.0) + sin(c.y * 4.0 - t * 2.4);
	col += mid_color.rgb * smoothstep(0.8, 2.0, f) * shimmer * 4.0;
	COLOR = vec4(col, 1.0);
}
