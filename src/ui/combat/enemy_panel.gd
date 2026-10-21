class_name EnemyPanel
extends Control
## Compact enemy readout beside its figure: name, current move, HP (with the
## previewed-damage ghost) and, for the twins, front/back + swap countdown.

var enemy: EnemyState
var is_front := true
var multi := false
var swap_in := 0
var _hp: HpBar


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp = HpBar.new()
	_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hp)
	resized.connect(_place_bar)
	_place_bar()


func _place_bar() -> void:
	if _hp != null:
		var compact := size.y < 100
		_hp.font_size = 20 if compact else 26
		var h := 46.0 if compact else 56.0
		_hp.position = Vector2(0, size.y - h)
		_hp.size = Vector2(size.x, h)


func update_view(p_enemy: EnemyState, p_front: bool, p_multi: bool, p_swap_in: int, preview_loss: int) -> void:
	enemy = p_enemy
	is_front = p_front
	multi = p_multi
	swap_in = p_swap_in
	_hp.color = Assets.color(enemy.data.color_id)
	_hp.label = "HP"
	_hp.set_values(enemy.hp, enemy.data.max_hp, preview_loss if is_front else 0)
	queue_redraw()


func _draw() -> void:
	if enemy == null:
		return
	var font := get_theme_default_font()
	var col := Assets.color(enemy.data.color_id)
	var alive := enemy.is_alive()
	draw_string(font, Vector2(0, 20), enemy.data.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col if alive else Assets.color("text_dim"))
	var intent := "已击破"
	if alive and enemy.move != null:
		intent = "意图：%s" % enemy.move.name
	draw_string(font, Vector2(0, 20), intent, HORIZONTAL_ALIGNMENT_RIGHT, size.x, 15, Assets.color("text") if is_front or not multi else Assets.color("text_dim"))
	if multi and alive:
		var tag := "▶ 前排" if is_front else "后排 · 无法攻击"
		if is_front and swap_in > 0:
			tag += " · %d 回合后交换" % swap_in
		draw_string(font, Vector2(0, 38), tag, HORIZONTAL_ALIGNMENT_LEFT, size.x, 13, col if is_front else Assets.color("text_dim"))
