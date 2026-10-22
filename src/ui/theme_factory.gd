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

	# Buttons are cream plastic keys with dark print (art_direction §5).
	var normal := _box(Assets.color("case"), Assets.color("case_edge"))
	var hover := _box(Assets.color("case").lightened(0.08), Assets.color("case_print"))
	var pressed := _box(Assets.color("case_dark"), Assets.color("case_print"))
	var disabled := _box(Assets.color("case_dark").darkened(0.15), Assets.color("case_edge"))
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Assets.color("case_print"))
	t.set_color("font_hover_color", "Button", Assets.color("bezel"))
	t.set_color("font_pressed_color", "Button", Assets.color("bezel"))
	t.set_color("font_disabled_color", "Button", Color(Assets.color("case_print"), 0.45))
	t.set_font_size("font_size", "Button", Assets.fs(24))

	# Panels (hint box, result sheet) are black bakelite with phosphor text.
	t.set_stylebox("panel", "Panel", _box(Assets.color("bezel"), Assets.color("case_edge")))
	return t


## The big red fire key on the transmitter.
static func style_fire_key(b: Button) -> void:
	var red := Color("c8352b")
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(14)
		box.set_border_width_all(3)
		box.border_color = Color("6e1712")
		box.shadow_color = Color(0, 0, 0, 0.45)
		box.shadow_size = 6
		box.shadow_offset = Vector2(0, 4)
		match state:
			"normal": box.bg_color = red
			"hover": box.bg_color = red.lightened(0.12)
			"pressed":
				box.bg_color = red.darkened(0.2)
				box.shadow_offset = Vector2(0, 1)
				box.content_margin_top = 4
			"disabled": box.bg_color = Color("7d5f58")
		b.add_theme_stylebox_override(state, box)
	for key in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(key, Color("fff3e6"))
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.4))


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
