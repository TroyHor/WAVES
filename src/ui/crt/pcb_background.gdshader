shader_type canvas_item;
// Game backdrop: a dark lab bench / circuit board — a faint dot grid with
// sparse orthogonal traces and a soft overhead light. Almost static (very slow
// drift) so it never competes with the instruments.

uniform vec4 base_color : source_color = vec4(0.035, 0.04, 0.045, 1.0);
uniform vec4 dot_color : source_color = vec4(0.12, 0.15, 0.14, 1.0);
uniform vec4 trace_color : source_color = vec4(0.09, 0.13, 0.11, 1.0);
uniform vec2 size_px = vec2(1920.0, 1080.0);
uniform float pitch = 26.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453);
}

void fragment() {
	vec2 px = UV * size_px + vec2(TIME * 1.5, 0.0);
	vec2 cell = floor(px / pitch);
	vec2 f = fract(px / pitch) - 0.5;
	float dot_mask = smoothstep(0.12, 0.06, length(f));
	// Sparse traces: some cells carry a horizontal or vertical line.
	float h = hash(cell);
	float trace = 0.0;
	if (h > 0.82) trace = smoothstep(0.06, 0.02, abs(f.y));
	else if (h > 0.70) trace = smoothstep(0.06, 0.02, abs(f.x));
	vec3 col = base_color.rgb;
	col = mix(col, trace_color.rgb, trace * 0.7);
	col = mix(col, dot_color.rgb, dot_mask * 0.8);
	// Soft overhead light.
	float light = 1.0 - smoothstep(0.2, 0.95, length((UV - vec2(0.55, 0.35)) * vec2(1.4, 1.0)));
	col *= 0.75 + 0.45 * light;
	COLOR = vec4(col, 1.0);
}
