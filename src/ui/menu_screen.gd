extends Control
## Prototype menu: pick an encounter to test.

var app: Node
var _t := 0.0


func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.position = Vector2(-260, -40)
	box.custom_minimum_size = Vector2(520, 0)
	add_child(box)

	var sub := Label.new()
	sub.text = "选择一场战斗（原型）"
	sub.add_theme_color_override("font_color", Assets.color("text_dim"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	for id in app.db.encounter_ids():
		var enc: EncounterData = app.db.encounter(id)
		var b := Button.new()
		var names := PackedStringArray()
		for eid in enc.enemy_ids:
			names.append(app.db.enemy(eid).name)
		b.text = enc.name if names.size() <= 1 else "%s（%s）" % [enc.name, " + ".join(names)]
		b.custom_minimum_size = Vector2(520, 64)
		b.pressed.connect(func() -> void: app.start_combat(id, randi()))
		box.add_child(b)

	var hint := Label.new()
	hint.text = "F2 切换 CRT 效果"
	hint.add_theme_color_override("font_color", Assets.color("text_dim"))
	hint.add_theme_font_size_override("font_size", 18)
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
	draw_string(font, Vector2(0, 220), "W A V E S", HORIZONTAL_ALIGNMENT_CENTER, size.x, 120, Assets.color("text"))
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
	draw_polyline(pts_a, Color(Assets.color("enemy_ch1"), 0.5), 2.0, true)
	draw_polyline(pts_b, Color(Assets.color("player_wave"), 0.5), 2.0, true)
	draw_polyline(pts_n, Color(Assets.color("net_wave"), 0.18), 10.0, true)
	draw_polyline(pts_n, Assets.color("net_wave"), 3.0, true)
