class_name WavePlacement
extends RefCounted
## One waveform placed on one lane. A chord (multi-lane) card produces several.

var wave: PackedInt32Array
var lane: int
var offset: int
## Opaque id of whatever produced this placement (e.g. a card instance), for UI lookups.
var source_id: int


func _init(p_wave: PackedInt32Array = PackedInt32Array(), p_offset := 0, p_lane := 0, p_source_id := -1) -> void:
	wave = p_wave
	offset = p_offset
	lane = p_lane
	source_id = p_source_id
