class_name ThemeFactory
extends RefCounted
## Builds the instrument-panel Theme in code (no .tres to hand-edit).


static var _shared: Theme


## One Theme instance for the whole app (also used inside SubViewports).
static func shared() -> Theme:
	if _shared == null:
		_shared = build()
	return _shared


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = Assets.font("main")
	t.default_font_size = Assets.fs(22)

	t.set_color("font_color", "Label", Assets.color("text"))

	var normal := _box(Assets.color("panel"), Assets.color("panel_border"))
	var hover := _box(Assets.color("panel").lightened(0.06), Assets.color("text"))
	var pressed := _box(Assets.color("grid_major"), Assets.color("text"))
	var disabled := _box(Assets.color("background"), Assets.color("disabled"))
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Assets.color("text"))
	t.set_color("font_hover_color", "Button", Assets.color("net_wave"))
	t.set_color("font_pressed_color", "Button", Assets.color("net_wave"))
	t.set_color("font_disabled_color", "Button", Assets.color("disabled"))
	t.set_font_size("font_size", "Button", Assets.fs(24))

	t.set_stylebox("panel", "Panel", _box(Assets.color("panel"), Assets.color("panel_border")))
	return t


static func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(2)
	b.set_corner_radius_all(3)
	b.content_margin_left = 18
	b.content_margin_right = 18
	b.content_margin_top = 10
	b.content_margin_bottom = 10
	return b
