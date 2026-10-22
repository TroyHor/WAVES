class_name CardView
extends Control
## A card drawn as a small instrument module with its own mini scope.

signal grabbed(view: CardView)

const CARD_SIZE := Vector2(156, 214)

var card: CardInstance
var playable := true
var flipped := false
## Ghost = the copy following the mouse while dragging.
var ghost := false
var _hovered := false
var _t := randf() * 10.0
## Resting scale: held cards are small, the opened hand is full size.
var base_scale := 1.0
## Hand layout targets: the card glides toward them (fan / open hand).
var use_targets := false
var target_pos := Vector2.ZERO
var target_rot := 0.0
## Seconds to wait before gliding (staggers cards flying in from the pile).
var hold := 0.0
## How far the card rises (local -y) while hovered.
var hover_lift := 16.0


func _init(p_card: CardInstance) -> void:
	card = p_card
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if ghost else Control.MOUSE_FILTER_STOP
	# Scale from the bottom centre so held cards grow upward onto the desk.
	pivot_offset = Vector2(CARD_SIZE.x * 0.5, CARD_SIZE.y)
	mouse_entered.connect(func() -> void: _hovered = true; queue_redraw())
	mouse_exited.connect(func() -> void: _hovered = false; queue_redraw())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		grabbed.emit(self)
		accept_event()


## Gentle idle sway; hovering straightens the card and lifts it.
func _process(delta: float) -> void:
	_t += delta
	if use_targets:
		if hold > 0.0:
			hold -= delta
		else:
			position = position.lerp(target_pos, minf(1.0, delta * 12.0))
	var sway := 0.0 if (_hovered or ghost) else sin(_t * 1.3) * 0.015
	var target := (target_rot if use_targets else 0.0) + sway
	if _hovered and use_targets:
		target = 0.0
	rotation = lerpf(rotation, target, minf(1.0, delta * 10.0))
	z_index = 50 if _hovered else 0
	var s := base_scale * (1.12 if _hovered and not ghost else 1.0)
	scale = scale.lerp(Vector2(s, s), minf(1.0, delta * 12.0))


func _draw() -> void:
	var font := get_theme_default_font()
	var lift := -hover_lift if _hovered and not ghost else 0.0
	var r := Rect2(Vector2(0, lift), CARD_SIZE)
	# Soft shadow under the card.
	draw_colored_polygon(PunchCard.outline(Rect2(r.position + Vector2(4, 6), r.size)), Color(0, 0, 0, 0.3))
	PunchCard.draw_card(self, font, r, card.data, flipped, playable, 0.92 if ghost else 1.0)
	if _hovered and not ghost:
		var closed := PunchCard.outline(r)
		closed.append(closed[0])
		draw_polyline(closed, Assets.color("energy"), 3.0, true)
