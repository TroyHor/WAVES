class_name MergedView
extends Control
## Centre instrument: a bench oscilloscope (ink-green flowing backdrop, smooth
## overlaid waves + strength bars in its tube) with a damage readout strip on
## the case below. Owns the shared cell geometry used for dragging.

const READOUT_H := 70.0
const READOUT_GAP := 10.0

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
var graph := MergedScreen.new()
var readout := ReadoutStrip.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	scope.title = "MATH"
	scope.accent = Assets.color("net_wave")
	scope.screen = graph
	scope.flow_background = true
	scope.bottom_pad = READOUT_H + READOUT_GAP
	readout.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	add_child(scope)
	add_child(readout)
	resized.connect(layout_parts)
	layout_parts()


func layout_parts() -> void:
	scope.position = Vector2.ZERO
	scope.size = size
	scope.grid_x0 = grid_x0
	scope.grid_x1 = grid_x1
	scope.layout_tube()
	readout.position = Vector2(0, size.y - READOUT_H - 14)
	readout.size = Vector2(size.x, READOUT_H)
	readout.grid_x0 = grid_x0
	readout.grid_x1 = grid_x1


func cell_width() -> float:
	return (grid_x1 - grid_x0) / track_length


func cell_center_x(t: float) -> float:
	return grid_x0 + (t + 0.5) * cell_width()


func cell_at(local: Vector2) -> int:
	return floori((local.x - grid_x0) / cell_width())


## Global position of a cell's damage readout (projectile origin).
func cell_global(t: int, to_enemy: bool) -> Vector2:
	var y := readout.position.y + (20.0 if to_enemy else READOUT_H - 18.0)
	return global_position + Vector2(cell_center_x(t), y)


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
	readout.track_length = track_length
	readout.result = result
	readout.reveal = reveal
	readout.highlight_cell = highlight_cell
