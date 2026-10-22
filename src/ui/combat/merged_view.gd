class_name MergedView
extends Control
## Centre instrument: a bench oscilloscope (ink-green flowing backdrop, smooth
## overlaid waves + strength bars + per-cell damage numbers in its tube).
## Owns the shared cell geometry used for dragging.

var track_length := 16
var grid_x0 := 100.0
var grid_x1 := 900.0
var enemy_channels: Array = []
var enemy_sum := PackedInt32Array()
var player_parts: Array = []
var result: TrackResult
var highlight_cell := -1
var arrive := 1.0
var reveal := 1.0
var merge := 0.0
var impact := 0.0

var scope := OscilloscopeView.new()
## See OscilloscopeView.embedded.
var embedded := false:
	set(v):
		embedded = v
		scope.embedded = v
		scope.show_plate = not v
var graph := MergedScreen.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	scope.title = "MATH"
	scope.accent = Assets.color("net_wave")
	scope.screen = graph
	scope.flow_background = true


func _ready() -> void:
	add_child(scope)
	resized.connect(layout_parts)
	layout_parts()


func layout_parts() -> void:
	scope.position = Vector2.ZERO
	scope.size = size
	scope.grid_x0 = grid_x0
	scope.grid_x1 = grid_x1
	scope.layout_tube()


func cell_width() -> float:
	return (grid_x1 - grid_x0) / track_length


func cell_center_x(t: float) -> float:
	return grid_x0 + (t + 0.5) * cell_width()


func cell_at(local: Vector2) -> int:
	return floori((local.x - grid_x0) / cell_width())


## Local position of cell t on the tube's centre line (collision point).
func cell_center_local(t: int) -> Vector2:
	return scope.tube_rect().position + Vector2(graph.cell_center_x(t), graph.graph_rect().get_center().y)


## Local position of a cell's damage number in the tube (projectile origin).
func readout_local(t: int) -> Vector2:
	return scope.tube_rect().position + graph.readout_point(t)


func _process(_delta: float) -> void:
	graph.track_length = track_length
	graph.enemy_channels = enemy_channels
	graph.enemy_sum = enemy_sum
	graph.player_parts = player_parts
	graph.result = result
	graph.highlight_cell = highlight_cell
	graph.arrive = arrive
	graph.reveal = reveal
	graph.merge = merge
	graph.impact = impact
