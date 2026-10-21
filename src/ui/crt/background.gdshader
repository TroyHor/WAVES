shader_type canvas_item;
// Slowly flowing interference field behind the UI (our take on Balatro's
// swirling backdrop): two warped wave fields whose sum is drawn as soft
// contour bands. Low contrast so it never competes with the instruments.

uniform vec4 base_color : source_color = vec4(0.012, 0.03, 0.022, 1.0);
uniform vec4 band_color : source_color = vec4(0.05, 0.16, 0.11, 1.0);
uniform vec4 band_color_2 : source_color = vec4(0.08, 0.07, 0.03, 1.0);
uniform float speed = 0.06;
uniform float aspect = 1.777;

void fragment() {
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0) * 3.2;
	float t = TIME * speed;
	float a = sin(p.x * 1.7 + sin(p.y * 1.1 + t * 2.3) * 1.6 + t * 3.0);
	float b = sin(p.y * 2.1 + sin(p.x * 0.8 - t * 1.7) * 1.4 - t * 2.2);
	float f = a + b;
	float bands = smoothstep(0.55, 1.0, abs(sin(f * 2.2)));
	vec3 col = mix(base_color.rgb, band_color.rgb, bands * 0.55);
	col = mix(col, band_color_2.rgb, smoothstep(1.2, 2.0, f) * 0.35);
	COLOR = vec4(col, 1.0);
}
