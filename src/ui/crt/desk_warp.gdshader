shader_type canvas_item;
// Projective quad warp for DeskDevice: each screen pixel of the device's
// bounding box is mapped back through the inverse homography to the flat
// face texture. Lets an instrument stand upright (top wider) or lie flat on
// the desk (far edge narrower) with correct perspective.

uniform mat3 inv_h;
uniform vec2 rect_size = vec2(100.0, 100.0);
uniform vec2 flat_size = vec2(100.0, 100.0);

void fragment() {
	vec3 r = inv_h * vec3(UV * rect_size, 1.0);
	vec2 uv = r.xy / r.z;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0);
	} else {
		vec4 c = texture(TEXTURE, uv);
		// Soft 1px edge so the warped outline is not jagged.
		vec2 e = min(uv, 1.0 - uv) * flat_size;
		c.a *= clamp(min(e.x, e.y) * 0.8, 0.0, 1.0);
		COLOR = c;
	}
}
