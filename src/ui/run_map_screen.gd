extends Control
## Between fights: the linear run as a signal chain of nodes, current HP, and
## the next action (next fight / victory / defeat).

var app: Node
var run: RunState
var _t := 0.0


func _ready() -> void:
	var b := Button.new()
	b.size = Vector2(380, 72)
	b.add_theme_font_size_override("font_size", Assets.fs(28))
	add_child(b)
	var back := Button.new()
	back.text = "返回菜单"
	back.size = Vector2(240, 60)
	back.pressed.connect(func() -> void: app.show_menu())
	add_child(back)
	if run.is_won():
		b.text = "再来一局"
		b.pressed.connect(func() -> void: app.start_run(randi()))
	elif run.lost:
		b.text = "重新开始"
		b.pressed.connect(func() -> void: app.start_run(randi()))
	else:
		b.text = "进入第 %d 战  ▶" % (run.index + 1)
		b.pressed.connect(func() -> void: app.start_run_fight())
	resized.connect(func() -> void:
		b.position = Vector2(size.x * 0.5 - 190, size.y * 0.68)
		back.position = Vector2(size.x * 0.5 - 120, size.y * 0.68 + 96))
	b.position = Vector2(size.x * 0.5 - 190, size.y * 0.68)
	back.position = Vector2(size.x * 0.5 - 120, size.y * 0.68 + 96)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var title := "信号链"
	var title_col := Assets.color("text")
	if run.is_won():
		title = "全部信号已清除 · 通关"
		title_col = Assets.color("damage_to_enemy")
	elif run.lost:
		title = "信号丢失 · 本局结束"
		title_col = Assets.color("damage_to_player")
	draw_string(font, Vector2(0, size.y * 0.18), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, Assets.fs(64), title_col)

	var n := run.encounter_ids.size()
	var y := size.y * 0.42
	var x0 := size.x * 0.5 - (n - 1) * 170.0
	# The chain itself: a live sine line between the nodes.
	var pts := PackedVector2Array()
	for i in 200:
		var x := x0 + (n - 1) * 340.0 * i / 199.0
		pts.append(Vector2(x, y + sin(i * 0.25 - _t * 3.0) * 6.0))
	WaveDraw.trace(self, pts, Color(Assets.color("grid_major"), 0.9), 2.0)
	for i in n:
		var c := Vector2(x0 + i * 340.0, y)
		var enc: EncounterData = app.db.encounter(run.encounter_ids[i])
		var col := Assets.color("disabled")
		var tag := ""
		if i < run.index:
			col = Assets.color("damage_to_enemy")
			tag = "已清除"
		elif i == run.index and not run.is_over():
			col = Assets.color("energy").lerp(Color.WHITE, 0.3 * (0.5 + 0.5 * sin(_t * 4.0)))
			tag = "下一战"
		elif i == run.index and run.lost:
			col = Assets.color("damage_to_player")
			tag = "失败"
		var box := Rect2(c - Vector2(110, 44), Vector2(220, 88))
		draw_rect(box, Assets.color("panel"))
		draw_rect(box, col, false, 3.0)
		draw_string(font, Vector2(box.position.x, c.y + 8), enc.name, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, Assets.fs(26), col)
		draw_string(font, Vector2(box.position.x, box.end.y + 30), tag, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, Assets.fs(18), col)
		draw_string(font, Vector2(box.position.x, box.position.y - 14), "%d" % (i + 1), HORIZONTAL_ALIGNMENT_CENTER, box.size.x, Assets.fs(16), Assets.color("text_dim"))

	var hp_text := "玩家 HP  %d / %d" % [run.player_hp, run.player_max_hp]
	draw_string(font, Vector2(0, size.y * 0.58), hp_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, Assets.fs(30), Assets.color("player_wave"))
	if not run.is_over():
		draw_string(font, Vector2(0, size.y * 0.58 + 36), "血量在战斗之间不会恢复", HORIZONTAL_ALIGNMENT_CENTER, size.x, Assets.fs(18), Assets.color("text_dim"))
