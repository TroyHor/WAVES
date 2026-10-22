class_name CaseMesh
extends RefCounted
## Procedural meshes for the 3D prototype (no editor / Blender): rounded-corner
## instrument cases with a bevelled front edge, raised bezel rings and bulging
## CRT glass. All builders take a face laid out in flat 2D units (y down) and a
## scale `sc` (world units per flat unit); the mesh origin is the face's
## top-left corner, the face looks along +Z, x right, y up.

## Points per rounded corner.
const STEPS := 8


## Rounded-rect outline (TL, TR, BR, BL corners, clockwise in flat space):
## [points, outward directions]. Zero-radius corners repeat their point so
## outlines with different radii keep the same vertex count.
static func outline(rect: Rect2, radii: Vector4) -> Array:
	var pts := PackedVector2Array()
	var dirs := PackedVector2Array()
	var cs := [
		[rect.position + Vector2(radii.x, radii.x), radii.x, PI],
		[Vector2(rect.end.x - radii.y, rect.position.y + radii.y), radii.y, PI * 1.5],
		[rect.end - Vector2(radii.z, radii.z), radii.z, 0.0],
		[Vector2(rect.position.x + radii.w, rect.end.y - radii.w), radii.w, PI * 0.5],
	]
	for c in cs:
		for k in STEPS:
			var a: float = c[2] + PI * 0.5 * float(k) / float(STEPS - 1)
			var d := Vector2(cos(a), sin(a))
			pts.append(c[0] + d * float(c[1]))
			dirs.append(d)
	return [pts, dirs]


## Case: front face (surface 0, UV = flat position / size, including the
## bevel so the face art wraps onto it) and body walls + back (surface 1).
static func build_case(size: Vector2, sc: Vector2, radii: Vector4, depth: float, bevel: float,
		face_mat: Material, body_mat: Material) -> ArrayMesh:
	var bf := bevel / sc.x
	var outer: Array = outline(Rect2(Vector2.ZERO, size), radii)
	var r_in := Vector4(maxf(radii.x - bf, 0.0), maxf(radii.y - bf, 0.0), maxf(radii.z - bf, 0.0), maxf(radii.w - bf, 0.0))
	var inner: Array = outline(Rect2(Vector2(bf, bf), size - Vector2(bf, bf) * 2.0), r_in)
	var o: PackedVector2Array = outer[0]
	var od: PackedVector2Array = outer[1]
	var ip: PackedVector2Array = inner[0]
	var n := o.size()
	var mesh := ArrayMesh.new()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := size * 0.5
	for i in n:
		var j := (i + 1) % n
		_tri(st, [_v(c, 0.0, sc), _v(ip[i], 0.0, sc), _v(ip[j], 0.0, sc)],
			[Vector3.BACK, Vector3.BACK, Vector3.BACK], [c / size, ip[i] / size, ip[j] / size])
	for i in n:
		var j := (i + 1) % n
		var ni := (_d(od[i]) + Vector3.BACK * 0.6).normalized()
		var nj := (_d(od[j]) + Vector3.BACK * 0.6).normalized()
		_quad_r(st, _v(ip[i], 0.0, sc), _v(ip[j], 0.0, sc), _v(o[j], -bevel, sc), _v(o[i], -bevel, sc),
			Vector3.BACK.lerp(ni, 0.5).normalized(), Vector3.BACK.lerp(nj, 0.5).normalized(), nj, ni,
			ip[i] / size, ip[j] / size, o[j] / size, o[i] / size)
	st.commit(mesh)
	mesh.surface_set_material(0, face_mat)

	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var j := (i + 1) % n
		_quad_r(st, _v(o[i], -bevel, sc), _v(o[j], -bevel, sc), _v(o[j], -depth, sc), _v(o[i], -depth, sc),
			_d(od[i]), _d(od[j]), _d(od[j]), _d(od[i]), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
		_tri(st, [_v(c, -depth, sc), _v(o[j], -depth, sc), _v(o[i], -depth, sc)],
			[Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD], [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	st.commit(mesh)
	mesh.surface_set_material(1, body_mat)
	return mesh


## Raised frame between an outer and an inner rounded rect (a tube bezel),
## standing `height` in front of the face.
static func build_ring(outer_rect: Rect2, inner_rect: Rect2, r_out: float, r_in: float, height: float,
		sc: Vector2, mat: Material) -> ArrayMesh:
	var outer: Array = outline(outer_rect, Vector4(r_out, r_out, r_out, r_out))
	var inner: Array = outline(inner_rect, Vector4(r_in, r_in, r_in, r_in))
	var o: PackedVector2Array = outer[0]
	var od: PackedVector2Array = outer[1]
	var ip: PackedVector2Array = inner[0]
	var idr: PackedVector2Array = inner[1]
	var n := o.size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z := Vector2.ZERO
	for i in n:
		var j := (i + 1) % n
		# Front lip, rounded towards both walls.
		var ao := (_d(od[i]) * 0.5 + Vector3.BACK).normalized()
		var bo := (_d(od[j]) * 0.5 + Vector3.BACK).normalized()
		var ai := (-_d(idr[i]) * 0.5 + Vector3.BACK).normalized()
		var bi := (-_d(idr[j]) * 0.5 + Vector3.BACK).normalized()
		_quad(st, _v(o[i], height, sc), _v(o[j], height, sc), _v(ip[j], height, sc), _v(ip[i], height, sc),
			ao, bo, bi, ai, z, z, z, z)
		_quad_r(st, _v(o[i], height, sc), _v(o[j], height, sc), _v(o[j], 0.0, sc), _v(o[i], 0.0, sc),
			_d(od[i]), _d(od[j]), _d(od[j]), _d(od[i]), z, z, z, z)
		_quad(st, _v(ip[i], height, sc), _v(ip[j], height, sc), _v(ip[j], -0.02, sc), _v(ip[i], -0.02, sc),
			-_d(idr[i]), -_d(idr[j]), -_d(idr[j]), -_d(idr[i]), z, z, z, z)
	var mesh := ArrayMesh.new()
	st.commit(mesh)
	mesh.surface_set_material(0, mat)
	return mesh


## Convex CRT glass over `rect`: z = base + bulge·(1−u²)(1−v²), so the picture
## bends with real geometry (and catches the lamp's highlight).
static func build_glass(rect: Rect2, sc: Vector2, base: float, bulge: float, mat: Material) -> ArrayMesh:
	var nx := 48
	var ny := 16
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := []
	for j in ny + 1:
		for i in nx + 1:
			var uv := Vector2(float(i) / nx, float(j) / ny)
			var q := uv * 2.0 - Vector2.ONE
			var zz := base + bulge * (1.0 - q.x * q.x) * (1.0 - q.y * q.y)
			var p := rect.position + uv * rect.size
			var w := rect.size * sc * 0.5
			var dzx := bulge * -2.0 * q.x * (1.0 - q.y * q.y) / w.x
			var dzy := bulge * -2.0 * q.y * (1.0 - q.x * q.x) / w.y
			pts.append([_v(p, zz, sc), Vector3(-dzx, dzy, 1.0).normalized(), uv])
	for j in ny:
		for i in nx:
			var a: Array = pts[j * (nx + 1) + i]
			var b: Array = pts[j * (nx + 1) + i + 1]
			var c: Array = pts[(j + 1) * (nx + 1) + i + 1]
			var d: Array = pts[(j + 1) * (nx + 1) + i]
			_quad(st, a[0], b[0], c[0], d[0], a[1], b[1], c[1], d[1], a[2], b[2], c[2], d[2])
	var mesh := ArrayMesh.new()
	st.commit(mesh)
	mesh.surface_set_material(0, mat)
	return mesh


static func _v(p: Vector2, z: float, sc: Vector2) -> Vector3:
	return Vector3(p.x * sc.x, -p.y * sc.y, z)


static func _d(d: Vector2) -> Vector3:
	return Vector3(d.x, -d.y, 0.0)


static func _tri(st: SurfaceTool, v: Array, nrm: Array, uv: Array) -> void:
	for k in 3:
		st.set_normal(nrm[k])
		st.set_uv(uv[k])
		st.add_vertex(v[k])


## _quad with the opposite winding (Godot front faces are clockwise).
static func _quad_r(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	_quad(st, a, d, c, b, na, nd, nc, nb, ua, ud, uc, ub)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	_tri(st, [a, b, c], [na, nb, nc], [ua, ub, uc])
	_tri(st, [a, c, d], [na, nc, nd], [ua, uc, ud])
