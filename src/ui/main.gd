extends Control
## App root. The game renders into a SubViewport which is shown through the CRT
## shader; mouse input is remapped through the same barrel distortion so clicks
## land on what the player sees. Also routes between screens.
##
## Dev flags (after `--`): --encounter=ID --seed=N --demo --nocrt --shot=PATH
##   --notutorial  disable tutorial hints
##   --runfight  start a new run and jump into its first fight
##   --autoresolve  (with --demo) resolve the turn shortly after start
##   --shotframes=N  frames to wait before --shot (default 45)
##   --selftest  runs tests/ui_smoke.gd through the real input path and quits

const CRT_SHADER := preload("res://src/ui/crt/crt.gdshader")
const MenuScreen := preload("res://src/ui/menu_screen.gd")
const CombatScreen := preload("res://src/ui/combat/combat_screen.gd")
const RunMapScreen := preload("res://src/ui/run_map_screen.gd")

var db: GameDatabase
var rules: RulesConfig
var theme_res: Theme
var progress: Progress
var run: RunState
var tutorial_enabled := true

var _viewport: SubViewport
var _display: TextureRect
var _crt_material: ShaderMaterial
var _crt_enabled := true
var _screen: Control
var _args := {}
var _glitch := 0.0


func _ready() -> void:
	_args = _parse_args()
	db = GameDatabase.load_default()
	rules = RulesConfig.load_file()
	theme_res = ThemeFactory.build()
	progress = Progress.load_from(Platform.save_path(Progress.FILE))
	tutorial_enabled = not (_args.has("notutorial") or _args.has("selftest"))

	_viewport = SubViewport.new()
	_viewport.handle_input_locally = true
	_viewport.disable_3d = true
	add_child(_viewport)

	_crt_material = ShaderMaterial.new()
	_crt_material.shader = CRT_SHADER
	for key in Assets.CRT:
		_crt_material.set_shader_parameter(key, Assets.CRT[key])

	_display = TextureRect.new()
	_display.texture = _viewport.get_texture()
	_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_display.stretch_mode = TextureRect.STRETCH_SCALE
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_display)

	set_crt_enabled(not _args.has("nocrt"))
	resized.connect(_on_resized)
	_on_resized()

	if _args.has("runfight"):
		start_run(int(_args.get("seed", randi())))
		start_run_fight()
	elif _args.has("encounter"):
		start_combat(_args["encounter"], int(_args.get("seed", randi())))
	else:
		show_menu()
	if _args.has("autoresolve") and _screen.has_method("demo_resolve"):
		_screen.demo_resolve.call_deferred()
	if _args.has("shot"):
		_take_screenshot_and_quit(_args["shot"], int(_args.get("shotframes", 45)))
	if _args.has("selftest"):
		var smoke = load("res://tests/ui_smoke.gd").new()
		get_tree().quit(await smoke.run(self))


func show_menu() -> void:
	var menu := MenuScreen.new()
	menu.app = self
	_set_screen(menu)


## Single fight outside a run (testing).
func start_combat(encounter_id: String, seed_value: int) -> void:
	run = null
	_show_combat(Combat.from_encounter(db, encounter_id, seed_value, rules), encounter_id, seed_value)


func start_run(seed_value: int) -> void:
	run = RunState.new_run(db, rules, seed_value)
	show_run_map()


func show_run_map() -> void:
	var screen := RunMapScreen.new()
	screen.app = self
	screen.run = run
	_set_screen(screen)


func start_run_fight() -> void:
	_show_combat(run.make_combat(db, rules), run.current_encounter_id(), run.seed_value + run.index * 7919)


func finish_run_fight(combat: Combat) -> void:
	run.complete_combat(combat)
	show_run_map()


func _show_combat(combat: Combat, encounter_id: String, seed_value: int) -> void:
	var screen := CombatScreen.new()
	screen.app = self
	screen.combat = combat
	screen.encounter = db.encounter(encounter_id)
	screen.seed_value = seed_value
	screen.run = run
	screen.tutorial_enabled = tutorial_enabled
	screen.demo = _args.has("demo")
	_set_screen(screen)


## Triggers a transient CRT glitch burst (0..1), decaying over ~0.5 s.
func glitch(amount: float) -> void:
	_glitch = maxf(_glitch, clampf(amount, 0.0, 1.0))


func _process(delta: float) -> void:
	_glitch = move_toward(_glitch, 0.0, delta * 2.0)
	_crt_material.set_shader_parameter("glitch", _glitch)


func set_crt_enabled(enabled: bool) -> void:
	_crt_enabled = enabled
	_display.material = _crt_material if enabled else null


func _set_screen(screen: Control) -> void:
	if _screen != null:
		_screen.queue_free()
	_screen = screen
	_screen.theme = theme_res
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport.add_child(_screen)


func _on_resized() -> void:
	_viewport.size = Vector2i(size)
	_crt_material.set_shader_parameter("source_size", size)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F2:
		set_crt_enabled(not _crt_enabled)
		get_viewport().set_input_as_handled()
		return
	var ev := event.duplicate()
	if ev is InputEventMouse:
		var local: Vector2 = ev.position - global_position
		ev.position = _crt_map(local)
		ev.global_position = ev.position
	_viewport.push_input(ev, true)
	get_viewport().set_input_as_handled()


## Screen position -> game position. Mirrors barrel() in crt.gdshader: the pixel
## shown at screen uv is sampled from the game image at barrel(uv).
func _crt_map(p: Vector2) -> Vector2:
	if not _crt_enabled or size.x <= 0 or size.y <= 0:
		return p
	var c := (p / size) * 2.0 - Vector2.ONE
	c *= 1.0 + float(Assets.CRT["curvature"]) * c.dot(c)
	return (c * 0.5 + Vector2(0.5, 0.5)) * size


## Inverse of _crt_map (game position -> screen position), by fixed-point
## iteration. Used by the UI smoke test to aim synthetic clicks.
func crt_unmap(game_pos: Vector2) -> Vector2:
	var p := game_pos
	for i in 20:
		p -= _crt_map(p) - game_pos
	return p + global_position


func current_screen() -> Control:
	return _screen


func _take_screenshot_and_quit(path: String, frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("screenshot saved: ", path)
	get_tree().quit()


func _parse_args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		var eq := s.find("=")
		if eq >= 0:
			out[s.substr(0, eq)] = s.substr(eq + 1)
		else:
			out[s] = true
	return out
