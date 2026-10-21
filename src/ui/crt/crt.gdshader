shader_type canvas_item;
// Old CRT / oscilloscope tube look applied to the whole game image:
// barrel distortion (edges stretched), radial chromatic aberration, phosphor
// bloom, scanlines, rolling band, line wobble, noise, flicker and vignette.
// Glitch: ambient short bursts plus event-driven `glitch` (impacts, damage):
// slice tearing, wavy horizontal displacement, stronger RGB split, block noise.
// barrel() must stay in sync with Main._crt_map() (input remapping); glitch
// displacement is transient and deliberately not remapped.

uniform float curvature = 0.045;
uniform float scanline_strength = 0.22;
uniform float scanline_density = 540.0;
uniform float aberration = 1.0;
uniform float vignette = 0.35;
uniform float noise_strength = 0.045;
uniform float bloom = 0.45;
uniform float flicker = 0.02;
uniform float wobble = 0.0008;
uniform float glitch = 0.0;
uniform float ambient_glitch = 0.25;
uniform vec2 source_size = vec2(1920.0, 1080.0);

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
	uv.x += sin(uv.y * 160.0 + TIME * 5.0) * wobble * (0.6 + 0.4 * sin(TIME * 0.9));

	// Ambient bursts: roughly one short glitch every few seconds.
	float g = glitch;
	float slot = floor(TIME * 3.0);
	if (hash(vec2(slot, 7.0)) > 0.9) {
		g = max(g, ambient_glitch * (0.4 + 0.6 * hash(vec2(slot, 3.0))));
	}
	if (g > 0.001) {
		float tick = floor(TIME * 24.0);
		// Slice tearing: random horizontal bands shift sideways.
		float band = floor(uv.y * 28.0);
		if (hash(vec2(band, tick)) < g * 0.4) {
			uv.x += (hash(vec2(band, tick + 1.0)) - 0.5) * 0.09 * g;
		}
		// Wavy distortion running down the screen.
		uv.x += sin(uv.y * 34.0 + TIME * 40.0) * 0.006 * g;
		// Vertical jump.
		uv.y += (hash(vec2(tick, 5.0)) - 0.5) * 0.012 * g * step(0.7, hash(vec2(tick, 9.0)));
	}

	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec2 px = 1.0 / source_size;
		vec2 dir = uv - 0.5;
		vec2 off = dir * length(dir) * aberration * 6.0 * px + vec2(g * 6.0 * px.x, 0.0);
		vec3 col = vec3(texture(TEXTURE, uv + off).r, texture(TEXTURE, uv).g, texture(TEXTURE, uv - off).b);

		// Cheap phosphor bloom: 8-tap blur of the bright parts.
		vec3 glow = vec3(0.0);
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.785398;
			vec2 o = vec2(cos(a), sin(a));
			glow += texture(TEXTURE, uv + o * px * 3.0).rgb;
			glow += texture(TEXTURE, uv + o * px * 7.0).rgb;
		}
		glow /= 16.0;
		col += max(glow - 0.15, vec3(0.0)) * bloom;

		float scan = 0.5 + 0.5 * sin(uv.y * scanline_density * 6.28318);
		col *= 1.0 - scanline_strength * (1.0 - scan);

		float band = smoothstep(0.0, 0.2, abs(fract(uv.y * 0.6 - TIME * 0.06) - 0.5));
		col *= 0.96 + 0.04 * band;

		col += (hash(uv * source_size + fract(TIME) * 61.0) - 0.5) * noise_strength;
		// Block noise ("花屏") only for event-driven glitches, never ambient.
		if (glitch > 0.05) {
			vec2 block = floor(uv * vec2(48.0, 27.0));
			float bn = hash(block + floor(TIME * 24.0));
			if (bn < glitch * 0.025) {
				col = mix(col, vec3(hash(block), hash(block + 1.0), hash(block + 2.0)) * 0.8, 0.6);
			}
		}
		col *= 1.0 - flicker * hash(vec2(floor(TIME * 30.0), 1.0));

		float vig = pow(16.0 * uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y), vignette);
		col *= vig;

		COLOR = vec4(col, 1.0);
	}
}
