shader_type canvas_item;
// Ink-green flowing-wave backdrop inside the main oscilloscope tube: two
// warped wave fields whose sum is drawn as soft drifting phosphor bands, like
// persistence trails on an old analogue scope. Sits behind the traces.

uniform vec4 base_color : source_color = vec4(0.012, 0.055, 0.035, 1.0);
uniform vec4 band_color : source_color = vec4(0.04, 0.20, 0.12, 1.0);
uniform vec4 glow_color : source_color = vec4(0.10, 0.30, 0.18, 1.0);
uniform float speed = 0.08;
uniform float aspect = 4.0;

void fragment() {
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0) * 2.4;
	float t = TIME * speed;
	float a = sin(p.x * 1.5 + sin(p.y * 2.2 + t * 2.3) * 1.3 + t * 3.0);
	float b = sin(p.y * 3.1 + sin(p.x * 0.7 - t * 1.7) * 1.6 - t * 2.4);
	float f = a + b;
	float bands = smoothstep(0.6, 1.0, abs(sin(f * 2.4)));
	vec3 col = mix(base_color.rgb, band_color.rgb, bands * 0.3);
	col += glow_color.rgb * smoothstep(1.3, 2.0, f) * 0.1;
	COLOR = vec4(col, 1.0);
}
