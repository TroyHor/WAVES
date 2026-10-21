class_name EnemyPanel
extends Control
## Enemy readout: name, current move, HP, and front/back status for the twins.

var enemy: EnemyState
var is_front := true
var multi := false
var swap_in := 0
var _hp: HpBar


func _ready() -> void:
	_hp = HpBar.new()
	add_child(_hp)
	_hp.position = Vector2(16, 56)
	_hp.size = Vector2(size.x - 32, 52)


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
	var border := col if (is_front and alive) else Assets.color("disabled")
	draw_rect(Rect2(Vector2.ZERO, size), Assets.color("panel"))
	draw_rect(Rect2(Vector2.ZERO, size), border, false, 3.0 if is_front else 2.0)
	draw_rect(Rect2(16, 14, 14, 24), col if alive else Assets.color("disabled"))
	draw_string(font, Vector2(40, 36), enemy.data.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, col if alive else Assets.color("text_dim"))
	var status := ""
	if not alive:
		status = "已击破"
	elif enemy.move != null:
		status = "意图：%s" % enemy.move.name
	draw_string(font, Vector2(size.x - 236, 34), status, HORIZONTAL_ALIGNMENT_RIGHT, 220, 20, Assets.color("text"))
	if multi and alive:
		var tag := "▶ 前排 · 承受伤害" if is_front else "后排 · 无法攻击"
		draw_string(font, Vector2(16, size.y + 24), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col if is_front else Assets.color("text_dim"))
		if swap_in > 0:
			draw_string(font, Vector2(size.x - 236, size.y + 24), "%d 回合后交换" % swap_in, HORIZONTAL_ALIGNMENT_RIGHT, 220, 18, Assets.color("text_dim"))
