extends Control
## Title menu: start a run, reset the tutorial, or test a single fight.

var app: Node
var _t := 0.0


func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.position = Vector2(-260, -20)
	box.custom_minimum_size = Vector2(520, 0)
	add_child(box)

	var start := Button.new()
	start.text = "开始新的一局  ▶"
	start.custom_minimum_size = Vector2(520, 76)
	start.add_theme_font_size_override("font_size", Assets.fs(30))
	start.pressed.connect(func() -> void: app.start_run(randi()))
	box.add_child(start)

	var reset := Button.new()
	reset.text = "重置新手引导"
	reset.custom_minimum_size = Vector2(520, 52)
	reset.pressed.connect(func() -> void:
		app.progress.reset_hints()
		reset.text = "新手引导已重置")
	box.add_child(reset)

	var dev := Label.new()
	dev.text = "— 单场测试 —"
	dev.add_theme_color_override("font_color", Assets.color("text_dim"))
	dev.add_theme_font_size_override("font_size", Assets.fs(18))
	dev.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(dev)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	for id in app.db.encounter_ids():
		var enc: EncounterData = app.db.encounter(id)
		var b := Button.new()
		b.text = enc.name
		b.add_theme_font_size_override("font_size", Assets.fs(18))
		b.pressed.connect(func() -> void: app.start_combat(id, randi()))
		row.add_child(b)

	var hint := Label.new()
	hint.text = "F2 关闭画面特效"
	hint.add_theme_color_override("font_color", Assets.color("text_dim"))
	hint.add_theme_font_size_override("font_size", Assets.fs(16))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var cx := size.x * 0.5
	# Background drawn here (not a ColorRect child) so it stays behind the title.
	draw_rect(Rect2(Vector2.ZERO, size), Assets.color("background"))
	draw_string(font, Vector2(0, 220), "W A V E S", HORIZONTAL_ALIGNMENT_CENTER, size.x, Assets.fs(120), Assets.color("text"))
	# Two interfering traces under the title.
	var pts_a := PackedVector2Array()
	var pts_b := PackedVector2Array()
	var pts_n := PackedVector2Array()
	for i in 240:
		var x := cx - 600 + i * 5.0
		var a := sin(i * 0.08 + _t * 2.0) * 22.0
		var b := sin(i * 0.11 - _t * 1.4) * 18.0
		pts_a.append(Vector2(x, 300 + a))
		pts_b.append(Vector2(x, 300 + b))
		pts_n.append(Vector2(x, 300 + a + b))
	WaveDraw.trace(self, pts_a, Color(Assets.color("enemy_ch1"), 0.5), 2.0)
	WaveDraw.trace(self, pts_b, Color(Assets.color("player_wave"), 0.5), 2.0)
	WaveDraw.trace(self, pts_n, Assets.color("net_wave"), 3.0)
