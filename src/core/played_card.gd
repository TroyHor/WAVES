class_name PlayedCard
extends RefCounted
## A wave card currently sitting on the track (before resolution).

var card: CardInstance
var offset: int
var flipped: bool


func _init(p_card: CardInstance, p_offset := 0, p_flipped := false) -> void:
	card = p_card
	offset = p_offset
	flipped = p_flipped


func wave() -> PackedInt32Array:
	return WaveMath.invert(card.data.wave) if flipped else card.data.wave


## All placements this card produces (itself plus effect copies such as echo).
func placements() -> Array[WavePlacement]:
	var w := wave()
	var out: Array[WavePlacement] = [WavePlacement.new(w, offset, card.uid)]
	if card.data.has_effect("echo"):
		out.append(WavePlacement.new(w, offset + card.data.effect_value("echo", "offset"), card.uid))
	return out
