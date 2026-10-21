extends Control
## Entry scene. Placeholder until the combat scene exists (milestone 1, step 3).


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Assets.color("background")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var label := Label.new()
	label.text = "WAVES — prototype skeleton"
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Assets.color("text"))
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(label)
