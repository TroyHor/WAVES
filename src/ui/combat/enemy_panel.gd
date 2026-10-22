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
		var compact := size.y < 110
		_hp.font_size = 18 if compact else 26
		var h := Assets.fs(_hp.font_size) + (20.0 if compact else 28.0)
		_hp.position = Vector2(0, size.y - h)
		_hp.size = Vector2(size.x, h)


func update_view(p_enemy: EnemyState, p_front: bool, p_multi: bool, p_swap_in: int, preview_loss: int) -> void:
	enemy = p_enemy
	is_front = p_front
	multi = p_multi
	swap_in = p_swap_in
	_hp.color = Assets.color(enemy.data.color_id)
	_hp.text_color = Assets.color("case_print")
	_hp.label = "HP"
	_hp.set_values(enemy.hp, enemy.data.max_hp, preview_loss if is_front else 0)
	queue_redraw()


## Printed on the receiver's cream case: a colour swatch for the enemy's
## channel, its name, current move and (twins) front/back marker.
func _draw() -> void:
	if enemy == null:
		return
	var font := get_theme_default_font()
	var col := Assets.color(enemy.data.color_id)
	var ink := Assets.color("case_print")
	var alive := enemy.is_alive()
	var compact := size.y < 110
	var name_fs := Assets.fs(18 if compact else 22)
	var small_fs := Assets.fs(13 if compact else 16)
	draw_rect(Rect2(0, name_fs * 0.2, 8, name_fs * 0.8), col if alive else Color(ink, 0.4))
	var title := enemy.data.name
	if multi and alive:
		# Front is marked with ▶; the back twin is just dimmed (no extra text).
		title = ("▶ " if is_front else "") + title
	draw_string(font, Vector2(14, name_fs), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 14, name_fs, ink if alive else Color(ink, 0.45))
	var intent := "已清除"
	if alive and enemy.move != null:
		intent = "意图：%s" % enemy.move.name
	var intent_col := Color(ink, 0.85 if is_front or not multi else 0.55)
	if compact:
		# Twins: intent shares the name line (right-aligned) so the HP bar fits.
		draw_string(font, Vector2(0, name_fs), intent, HORIZONTAL_ALIGNMENT_RIGHT, size.x, small_fs, intent_col)
	else:
		draw_string(font, Vector2(14, name_fs + small_fs + 6), intent, HORIZONTAL_ALIGNMENT_LEFT, size.x - 14, small_fs, intent_col)
