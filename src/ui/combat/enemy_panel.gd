class_name EnemyPanel
extends Control
## Compact enemy readout beside its figure: name and HP (with the
## previewed-damage ghost); the twins' front one is marked ▶. The move itself
## is shown by the wave, so it is not spelled out.

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


## Name and HP bar form one block, centred vertically in the panel.
func _name_fs() -> int:
	return Assets.fs(18 if size.y < 110 else 22)


func _block_top() -> float:
	return maxf(0.0, (size.y - _name_fs() - 8.0 - _hp.size.y) * 0.5)


func _place_bar() -> void:
	if _hp != null:
		var compact := size.y < 110
		_hp.font_size = 18 if compact else 26
		var h := Assets.fs(_hp.font_size) + (16.0 if compact else 22.0)
		_hp.size = Vector2(size.x, h)
		_hp.position = Vector2(0, _block_top() + _name_fs() + 8.0)


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
## channel, its name and (twins) front marker.
func _draw() -> void:
	if enemy == null:
		return
	var font := get_theme_default_font()
	var col := Assets.color(enemy.data.color_id)
	var ink := Assets.color("case_print")
	var alive := enemy.is_alive()
	var name_fs := _name_fs()
	var y0 := _block_top()
	draw_rect(Rect2(0, y0 + name_fs * 0.2, 8, name_fs * 0.8), col if alive else Color(ink, 0.4))
	var title := enemy.data.name
	if multi and alive:
		# Front is marked with ▶; the back twin is just dimmed (no extra text).
		title = ("▶ " if is_front else "") + title
	draw_string(font, Vector2(14, y0 + name_fs), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 14, name_fs, ink if alive else Color(ink, 0.45))
