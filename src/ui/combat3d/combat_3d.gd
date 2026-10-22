extends Control
## 3D comparison prototype of the combat scene (dev flag --scene3d).
##
## The real 2D CombatScreen still runs (rules, preview, hand, demo state) in an
## offscreen SubViewport. Its instrument faces are already rendered flat into
## SubViewports (DeskDevice, TubeScreen, OscilloscopeView); here they become
## textures on 3D objects built in code: rounded cream cases with real
## thickness, raised tube bezels, convex CRT glass, a 3D fire key and power
## bulbs, on a wooden desk under a warm lamp. Their warped 2D versions are
## hidden; the hand, piles and slotted cards stay 2D and are drawn on top
## (slot positions are projected from the 3D foot).
## Input: every frame the hidden 2D devices get the projected quads of their
## 3D faces, so the 2D screen's own hit tests (slots, screens, fire key) and
## effect positions line up with the 3D instruments; input is forwarded to it.
## --camyaw=DEG orbits the camera.

const CombatScreen := preload("res://src/ui/combat/combat_screen.gd")
const FACE_SHADER := preload("res://src/ui/combat3d/face.gdshader")
const GLASS_SHADER := preload("res://src/ui/combat3d/crt_glass.gdshader")
const WOOD_SHADER := preload("res://src/ui/combat3d/wood.gdshader")

## World units per scope face unit (the scope face is 2.0 × 0.9).
const SCOPE_S := 0.001
const CASE_DEPTH := 0.35
const TX_DEPTH := 0.16
const FOOT_D := 0.34
const FOOT_T := 0.022
const GAP := 0.18
const BEVEL := 0.012
const GAUGE_W := 0.27
const CAM_POS := Vector3(0.0, 1.85, 4.6)
const CAM_TARGET := Vector3(0.0, 0.42, -0.3)
const CAM_FOV := 16.5
const LAMP_POS := Vector3(-2.4, 3.4, 2.6)

var app: Node
var combat: Combat
var encounter: EncounterData
var seed_value := 0
var demo := false
var run: RunState
var tutorial_enabled := true

var _screen: Control
var _src_vp: SubViewport
var _vp3: SubViewport
var _world: Node3D
var _cam: Camera3D
var _scope: Node3D
var _tx: Node3D
var _foot: Node3D
var _gauge: Node3D
var _s_tx := 0.001
var _foot_sy := 0.001
var _bulbs: Array[MeshInstance3D] = []
var _bulb_lights: Array[OmniLight3D] = []
var _built := false
## Fire key cap (sinks with FireKey.press_amount) and rest positions of the
## transmitter parts (they tremble with the 2D device).
var _key_cap: Node3D
var _tx_rest := Vector3.ZERO
var _foot_rest := Vector3.ZERO


func _ready() -> void:
	_vp3 = SubViewport.new()
	_vp3.own_world_3d = true
	_vp3.msaa_3d = Viewport.MSAA_4X
	_vp3.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp3)
	var view3 := TextureRect.new()
	view3.texture = _vp3.get_texture()
	_fill(view3)
	add_child(view3)

	_src_vp = SubViewport.new()
	_src_vp.disable_3d = true
	_src_vp.transparent_bg = true
	_src_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_src_vp)
	var screen := CombatScreen.new()
	screen.app = app
	screen.combat = combat
	screen.encounter = encounter
	screen.seed_value = seed_value
	screen.run = run
	screen.tutorial_enabled = tutorial_enabled
	screen.demo = demo
	screen.theme = ThemeFactory.shared()
	_screen = screen
	_src_vp.add_child(_screen)
	var over := TextureRect.new()
	over.texture = _src_vp.get_texture()
	_fill(over)
	add_child(over)
	resized.connect(_fit)
	_fit()
	# Let the 2D screen lay itself out before reading its faces.
	await get_tree().process_frame
	await get_tree().process_frame
	_build()


func _fill(tr: TextureRect) -> void:
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Dev flags (--autoresolve, --openhand) reach the 2D screen through these.
func demo_resolve() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_screen.demo_resolve()


func _set_hand_open(open: bool) -> void:
	_screen._set_hand_open(open)


func _input(event: InputEvent) -> void:
	_src_vp.push_input(event)
	get_viewport().set_input_as_handled()


func _fit() -> void:
	_vp3.size = Vector2i(size)
	_src_vp.size = Vector2i(size)
	_screen.position = Vector2.ZERO
	_screen.size = size


# --- Scene -------------------------------------------------------------------

func _build() -> void:
	var s = _screen
	_world = Node3D.new()
	_vp3.add_child(_world)
	_env()
	_cam = Camera3D.new()
	_cam.fov = CAM_FOV
	_world.add_child(_cam)
	# --camyaw=DEG orbits the camera around the scene (shows real parallax).
	var yaw := deg_to_rad(float(app._args.get("camyaw", 0.0)))
	_cam.look_at_from_position(CAM_TARGET + (CAM_POS - CAM_TARGET).rotated(Vector3.UP, yaw), CAM_TARGET)
	_desk()

	# Hide the 2D (warped) instruments; keep rendering their flat faces.
	for dev in [s._scope_dev, s._tx_dev, s._foot_dev, s._gauge_dev]:
		dev._tex.visible = false
		dev.self_modulate.a = 0.0
		dev._vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for tube in [s._enemy_tube, s._player_tube]:
		tube._tex.visible = false
		tube._vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	s._merged.scope._tube.visible = false
	s._merged.scope._vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	s._fire_art.visible = false
	s._energy.visible = false

	var z_tx := -FOOT_D
	var z_scope := z_tx - TX_DEPTH - GAP

	# Transmitter scale: its grid columns project exactly onto the main scope's.
	var m = s._merged
	var scope_x0 := -CombatScreen.SCOPE_FLAT.x * SCOPE_S * 0.5
	var gl := Vector3(scope_x0 + (m.position.x + m.grid_x0) * SCOPE_S, 0.6, z_scope)
	var gr := Vector3(scope_x0 + (m.position.x + m.grid_x1) * SCOPE_S, 0.6, z_scope)
	var tl := _ray_to_z(_cam.unproject_position(gl), z_tx)
	var trr := _ray_to_z(_cam.unproject_position(gr), z_tx)
	_s_tx = (trr.x - tl.x) / float(s._player_screen.grid_w)
	var tx_flat := Vector2(s._tx_w, CombatScreen.TX_FLAT.y)
	var tx_grid0: float = s._player_tube.position.x + s._player_screen.grid_x0
	var tx_x0 := tl.x - tx_grid0 * _s_tx
	var tx_h := tx_flat.y * _s_tx

	# Transmitter face, standing on the desk behind its foot.
	var r := float(InstrumentStyle.CASE_RADIUS)
	_tx = _device(s._tx_dev, tx_flat, Vector2(_s_tx, _s_tx), Vector4(r, r, 0, 0), TX_DEPTH)
	_tx.position = Vector3(tx_x0, tx_h, z_tx)
	_bezel(_tx, Rect2(s._player_tube.position, s._player_tube.size), Vector2(_s_tx, _s_tx), s._player_tube._vp, Color(0.01, 0.04, 0.05))
	_fire_key(Rect2(s._fire_art.position, s._fire_art.size))
	_power_bulbs(Rect2(s._energy.position, s._energy.size))

	# Foot: lies on the desk, slots towards the operator.
	_foot_sy = FOOT_D / CombatScreen.FOOT_FLAT.y
	_foot = _device(s._foot_dev, Vector2(s._tx_w, CombatScreen.FOOT_FLAT.y), Vector2(_s_tx, _foot_sy), Vector4(0, 0, r, r), FOOT_T)
	_foot.basis = Basis(Vector3.RIGHT, -PI * 0.5)
	_foot.position = Vector3(tx_x0, FOOT_T, z_tx)

	# Scope unit: on a riser so its face clears the transmitter's top.
	var over_tx := _ray_to_z(_cam.unproject_position(Vector3(0.0, tx_h, z_tx - TX_DEPTH)), z_scope)
	var scope_bottom := over_tx.y + 0.012
	var scope_h: float = CombatScreen.SCOPE_FLAT.y * SCOPE_S
	_scope = _device(s._scope_dev, CombatScreen.SCOPE_FLAT, Vector2(SCOPE_S, SCOPE_S), Vector4(r, r, r, r), CASE_DEPTH)
	_scope.position = Vector3(scope_x0, scope_bottom + scope_h, z_scope)
	var riser := MeshInstance3D.new()
	var rb := BoxMesh.new()
	rb.size = Vector3(CombatScreen.SCOPE_FLAT.x * SCOPE_S * 0.9, scope_bottom, CASE_DEPTH * 0.8)
	riser.mesh = rb
	riser.material_override = _plain(Color("2a2420"), 0.6)
	riser.position = Vector3(0, scope_bottom * 0.5, z_scope - CASE_DEPTH * 0.5)
	_world.add_child(riser)
	_bezel(_scope, Rect2(s._enemy_tube.position, s._enemy_tube.size), Vector2(SCOPE_S, SCOPE_S), s._enemy_tube._vp, Color(0.05, 0.03, 0.01))
	var mt: Rect2 = m.scope.tube_rect()
	_bezel(_scope, Rect2(m.position + mt.position, mt.size), Vector2(SCOPE_S, SCOPE_S), m.scope._vp, Color(0.01, 0.04, 0.02))

	# Line-integrity meter: small upright box in front-left, turned a little.
	var gs := GAUGE_W / CombatScreen.GAUGE_FLAT.x
	_gauge = _device(s._gauge_dev, CombatScreen.GAUGE_FLAT, Vector2(gs, gs), Vector4(r, r, r, r), 0.12)
	_gauge.basis = Basis(Vector3.UP, 0.22) * Basis(Vector3.BACK, 0.05)
	_gauge.position = Vector3(tx_x0 - 0.36, CombatScreen.GAUGE_FLAT.y * gs, z_tx + 0.12)

	_tx_rest = _tx.position
	_foot_rest = _foot.position
	_built = true
	_sync_2d()


func _env() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("120c08")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("6b5a48")
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	we.environment = env
	_world.add_child(we)
	# Warm desk lamp, upper left in front, casting soft shadows.
	var lamp := SpotLight3D.new()
	lamp.light_color = Color("ffd9a8")
	lamp.light_energy = 5.0
	lamp.spot_range = 12.0
	lamp.spot_angle = 40.0
	lamp.spot_attenuation = 0.6
	lamp.shadow_enabled = true
	lamp.shadow_blur = 2.0
	lamp.shadow_bias = 0.08
	lamp.shadow_normal_bias = 2.0
	_world.add_child(lamp)
	lamp.look_at_from_position(LAMP_POS, Vector3(0.1, 0.3, -0.4))
	# Dim cool fill from the right so case sides separate.
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("9fb4c8")
	fill.light_energy = 0.25
	_world.add_child(fill)
	fill.look_at_from_position(Vector3(2, 1.5, 2), Vector3.ZERO)


func _desk() -> void:
	var top := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(8.0, 0.08, 4.0)
	top.mesh = box
	var wood := ShaderMaterial.new()
	wood.shader = WOOD_SHADER
	top.material_override = wood
	top.position = Vector3(0, -0.04, -1.6)
	_world.add_child(top)
	var wall := MeshInstance3D.new()
	var wm := PlaneMesh.new()
	wm.size = Vector2(10, 6)
	wall.mesh = wm
	wall.material_override = _plain(Color("2b2119"), 0.9)
	wall.basis = Basis(Vector3.RIGHT, PI * 0.5)
	wall.position = Vector3(0, 2.0, -3.4)
	_world.add_child(wall)


## A case whose front face shows `dev`'s flat face texture.
func _device(dev: DeskDevice, flat: Vector2, sc: Vector2, radii: Vector4, depth: float) -> Node3D:
	var node := Node3D.new()
	_world.add_child(node)
	var face := ShaderMaterial.new()
	face.shader = FACE_SHADER
	face.set_shader_parameter("face_tex", dev._vp.get_texture())
	face.set_shader_parameter("case_col", Assets.color("case"))
	var mi := MeshInstance3D.new()
	mi.mesh = CaseMesh.build_case(flat, sc, radii, depth, BEVEL, face, _plain(Assets.color("case").darkened(0.08), 0.5))
	node.add_child(mi)
	return node


## Raised dark bezel around a tube and the convex glass inside it.
func _bezel(parent: Node3D, tube: Rect2, sc: Vector2, vp: SubViewport, tint: Color) -> void:
	var ring := MeshInstance3D.new()
	ring.mesh = CaseMesh.build_ring(tube.grow(16), tube.grow(3), 18.0, 10.0, 0.022, sc, _plain(Assets.color("bezel"), 0.45))
	parent.add_child(ring)
	var mat := ShaderMaterial.new()
	mat.shader = GLASS_SHADER
	mat.set_shader_parameter("screen_tex", vp.get_texture())
	mat.set_shader_parameter("glass_tint", tint)
	mat.set_shader_parameter("lines", tube.size.y / 3.0)
	var glass := MeshInstance3D.new()
	glass.mesh = CaseMesh.build_glass(tube.grow(4), sc, 0.004, minf(tube.size.y * sc.y * 0.12, 0.022), mat)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(glass)


## Red mushroom fire key on a brushed metal plate (transmitter face coords).
func _fire_key(rect: Rect2) -> void:
	var s := _s_tx
	var c := rect.get_center()
	var root := Node3D.new()
	root.position = Vector3(c.x * s, -c.y * s, 0.0)
	_tx.add_child(root)
	_key_cap = Node3D.new()
	var side := minf(rect.size.x, rect.size.y) * s
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("b9b8b2")
	metal.metallic = 0.85
	metal.roughness = 0.35
	metal.anisotropy_enabled = true
	metal.anisotropy = 0.6
	var plate := MeshInstance3D.new()
	var pb := BoxMesh.new()
	pb.size = Vector3(side, side, 0.008)
	plate.mesh = pb
	plate.material_override = metal
	plate.position.z = 0.004
	root.add_child(plate)
	for k in 4:
		var screw := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = side * 0.045
		sm.bottom_radius = side * 0.045
		sm.height = 0.004
		screw.mesh = sm
		screw.material_override = _plain(Color("8a8984"), 0.3, 0.9)
		screw.basis = Basis(Vector3.RIGHT, PI * 0.5)
		var sx := (1 if k % 2 == 0 else -1) * side * 0.38
		var sy := (1 if k < 2 else -1) * side * 0.38
		screw.position = Vector3(sx, sy, 0.009)
		root.add_child(screw)
	var collar := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = side * 0.33
	cm.bottom_radius = side * 0.36
	cm.height = 0.016
	collar.mesh = cm
	collar.material_override = _plain(Color("e4e4e0"), 0.12, 1.0)
	collar.basis = Basis(Vector3.RIGHT, PI * 0.5)
	collar.position.z = 0.016
	root.add_child(collar)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("c8221a")
	red.roughness = 0.18
	red.clearcoat_enabled = true
	red.clearcoat = 0.8
	var stem := MeshInstance3D.new()
	var stm := CylinderMesh.new()
	stm.top_radius = side * 0.3
	stm.bottom_radius = side * 0.3
	stm.height = 0.02
	stem.mesh = stm
	stem.material_override = red
	stem.basis = Basis(Vector3.RIGHT, PI * 0.5)
	stem.position.z = 0.032
	_key_cap.add_child(stem)
	var cap := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = side * 0.3
	sp.height = side * 0.3
	sp.is_hemisphere = true
	cap.mesh = sp
	cap.material_override = red
	cap.basis = Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(1, 0.55, 1))
	cap.position.z = 0.042
	_key_cap.add_child(cap)
	root.add_child(_key_cap)


## Glass power bulbs in their sockets (lit by EnergyView's state each frame).
func _power_bulbs(rect: Rect2) -> void:
	var s := _s_tx
	var n: int = maxi(_screen._energy.max_energy, 1)
	var step := rect.size.y / n
	var r := minf(step * 0.34, rect.size.x * 0.36) * 1.2
	for i in n:
		var c := rect.position + Vector2(rect.size.x * 0.5, rect.size.y - step * (i + 0.5))
		var socket := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = r * s * 0.75
		sm.bottom_radius = r * s * 0.85
		sm.height = 0.012
		socket.mesh = sm
		socket.material_override = _plain(Color("3b3a36"), 0.4, 0.6)
		socket.basis = Basis(Vector3.RIGHT, PI * 0.5)
		socket.position = Vector3(c.x * s, -c.y * s, 0.006)
		_tx.add_child(socket)
		var bulb := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = r * s
		bm.height = r * s * 2.0
		bulb.mesh = bm
		bulb.position = Vector3(c.x * s, -c.y * s, 0.012 + r * s * 0.5)
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_tx.add_child(bulb)
		_bulbs.append(bulb)
		var light := OmniLight3D.new()
		light.light_color = Assets.color("energy")
		light.omni_range = 0.12
		light.position = bulb.position + Vector3(0, 0, r * s * 1.5)
		_tx.add_child(light)
		_bulb_lights.append(light)


func _plain(col: Color, rough: float, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	return m


## Screen point -> point on the plane z = `z` (camera ray).
func _ray_to_z(p: Vector2, z: float) -> Vector3:
	var o := _cam.project_ray_origin(p)
	var d := _cam.project_ray_normal(p)
	return o + d * ((z - o.z) / d.z)


func _world_of(node: Node3D, p: Vector2, sc: Vector2, z := 0.0) -> Vector3:
	return node.global_transform * Vector3(p.x * sc.x, -p.y * sc.y, z)


## Gives a hidden 2D device the on-screen quad of its 3D face (rest pose), so
## its homography equals the camera's projection of that face plane.
func _map_device(dev: DeskDevice, node: Node3D, sc: Vector2) -> void:
	var f := dev.flat_size
	var pts := PackedVector2Array()
	for p in [Vector2.ZERO, Vector2(f.x, 0), f, Vector2(0, f.y)]:
		pts.append(_cam.unproject_position(_world_of(node, p, sc)))
	# Re-apply only on change (the 2D layout may reset it on resize), so the
	# device's own shake / tremble offset survives.
	var lo := pts[0]
	for p in pts:
		lo = lo.min(p)
	var rel := PackedVector2Array()
	for p in pts:
		rel.append(p - lo)
	if dev._base_pos != lo or dev.quad != rel:
		dev.set_quad(pts)


# --- Per frame ---------------------------------------------------------------

func _process(_delta: float) -> void:
	if not _built:
		return
	var s = _screen
	var j: Vector2 = s._tx_dev.jitter() * 0.0006
	_tx.position = _tx_rest + Vector3(j.x, -j.y, 0.0)
	_foot.position = _foot_rest + Vector3(j.x, 0.0, j.y)
	_key_cap.position.z = -0.014 * s._fire_art.press_amount
	_sync_2d()
	var ev: EnergyView = _screen._energy
	var used := clampi(ev.max_energy - ev.energy, 0, _bulbs.size())
	var lamp := Assets.color("energy")
	for i in _bulbs.size():
		var lit := i < used
		var m := StandardMaterial3D.new()
		m.albedo_color = lamp * 0.4 if lit else Color("4a4234")
		m.roughness = 0.1
		m.emission_enabled = lit
		m.emission = lamp
		m.emission_energy_multiplier = 2.0
		_bulbs[i].material_override = m
		_bulb_lights[i].light_energy = 0.12 if lit else 0.0


## 2D things drawn over the 3D view follow the 3D devices: slotted cards stand
## on the foot's slits; the duty note hangs over the scope's knob strip.
func _sync_2d() -> void:
	var s = _screen
	_map_device(s._scope_dev, _scope, Vector2(SCOPE_S, SCOPE_S))
	_map_device(s._tx_dev, _tx, Vector2(_s_tx, _s_tx))
	_map_device(s._foot_dev, _foot, Vector2(_s_tx, _foot_sy))
	var gs := GAUGE_W / CombatScreen.GAUGE_FLAT.x
	_map_device(s._gauge_dev, _gauge, Vector2(gs, gs))
	var key: Rect2 = s._tx_dev.flat_rect_to_screen(s._fire_art.get_rect())
	s._resolve_btn.position = key.position
	s._resolve_btn.size = key.size
	var bases := PackedVector2Array()
	for t in combat.rules.track_length:
		bases.append(_cam.unproject_position(_world_of(_foot, s._slot.slit_point(t), Vector2(_s_tx, _foot_sy))))
	s._slot_cards.size = size
	s._slot_cards.bases = bases
	s._slot_cards.cell_px = bases[1].x - bases[0].x
	var m = s._merged
	var hood := Vector2(m.position.x + m.grid_x1 + OscilloscopeView.TUBE_MARGIN + 16.0, m.position.y + m.size.y)
	var hp := _cam.unproject_position(_world_of(_scope, hood, Vector2(SCOPE_S, SCOPE_S)))
	var nx := hp.x + 4.0
	s._note.place(nx, hp.y + 10.0, clampf(size.x - nx - 6.0, 150.0, 240.0))
