shader_type canvas_item;
// The operator's desk seen at an oblique angle (placeholder for the
// `desk_background` texture). The desk top fills the top, left and right of
// the screen; its wood grain and plank seams converge toward a vanishing point
// above the screen. Near the bottom the desk's front edge is visible, and
// beyond it a strip of dim floor where the player's hand of cards is held.

uniform vec2 size_px = vec2(1920.0, 1080.0);
// Top of the desk's front edge and its thickness, in pixels.
uniform float edge_y = 930.0;
uniform float edge_h = 34.0;
uniform vec4 wood_dark : source_color = vec4(0.22, 0.14, 0.09, 1.0);
uniform vec4 wood_light : source_color = vec4(0.46, 0.31, 0.19, 1.0);
uniform vec4 edge_color : source_color = vec4(0.40, 0.27, 0.17, 1.0);
uniform vec4 floor_color : source_color = vec4(0.07, 0.065, 0.065, 1.0);
uniform vec2 lamp = vec2(0.5, 0.32);

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
	vec2 p = UV * size_px;
	float aspect = size_px.x / size_px.y;
	vec3 col;
	// Lamp pool shared by desk and floor.
	float lampd = length((UV - lamp) * vec2(aspect * 0.6, 1.0));
	float light = 1.0 - smoothstep(0.1, 1.0, lampd);
	if (p.y < edge_y) {
		// Perspective coordinates: u is constant along lines toward the
		// vanishing point V, d grows with distance from the viewer.
		vec2 v = vec2(size_px.x * 0.5, -size_px.y * 1.6);
		float u = (p.x - v.x) / (p.y - v.y);
		float d = log(p.y - v.y);
		float grain = sin(u * 260.0 + noise(vec2(u * 30.0, d * 9.0)) * 4.0) * 0.5 + 0.5;
		grain = mix(grain, noise(vec2(u * 120.0, d * 40.0)), 0.35);
		float seam = smoothstep(0.012, 0.0, abs(fract(u * 4.2) - 0.5) - 0.488);
		col = mix(wood_dark.rgb, wood_light.rgb, 0.25 + grain * 0.35);
		col *= 1.0 - seam * 0.45;
		// Far side of the desk falls off into darkness.
		col *= mix(0.55, 1.0, smoothstep(0.0, edge_y, p.y));
		col *= 0.65 + 0.7 * light;
	} else if (p.y < edge_y + edge_h) {
		// Rounded front edge: bright lip on top, darker underside.
		float k = (p.y - edge_y) / edge_h;
		col = edge_color.rgb * mix(1.35, 0.55, k);
		col += vec3(0.12, 0.09, 0.06) * smoothstep(0.15, 0.0, k);
		col *= 0.7 + 0.45 * light;
	} else {
		// Floor beyond the desk: dark boards with a shadow under the desk.
		float fy = p.y - edge_y - edge_h;
		col = floor_color.rgb * (0.85 + 0.2 * noise(vec2(UV.x * 40.0, fy * 0.05)));
		float board = smoothstep(0.03, 0.0, abs(fract(fy / 46.0) - 0.5) - 0.47);
		col *= 1.0 - board * 0.3;
		col *= mix(0.35, 1.0, smoothstep(0.0, 70.0, fy));
		col *= 0.8 + 0.3 * light;
	}
	col += (hash(floor(UV * size_px)) - 0.5) * 0.015;
	COLOR = vec4(col, 1.0);
}
