class_name FlatScopeView
extends Control
## Flat instrument panel (the enemy's or the player's signal): bordered panel
## with a short title in the left margin and a ScopeScreen grid whose columns
## match the centre oscilloscope.

var title := ""
var accent := Color.WHITE
var screen := ScopeScreen.new()
var grid_x0 := 100.0
var grid_x1 := 900.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Launched traces must not spill outside the panel.
	screen.clip_contents = true


func _ready() -> void:
	add_child(screen)
	resized.connect(layout_screen)
	layout_screen()


func layout_screen() -> void:
	screen.position = Vector2.ZERO
	screen.size = size
	screen.grid_x0 = grid_x0
	screen.grid_w = grid_x1 - grid_x0


func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Assets.color("panel"))
	draw_rect(Rect2(Vector2.ZERO, size), Assets.color("panel_border"), false, 2.0)
	draw_rect(Rect2(10, size.y * 0.5 - 18, 6, 36), accent)
	draw_string(font, Vector2(26, size.y * 0.5 + 9), title, HORIZONTAL_ALIGNMENT_LEFT, grid_x0 - 90, Assets.fs(24), accent)
