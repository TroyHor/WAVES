class_name PlayedCard
extends RefCounted
## A card currently placed on the track this turn (still movable until resolve).

var card: CardInstance
var lane := 0
var offset := 0
var inverted := false


func _init(p_card: CardInstance = null, p_lane := 0, p_offset := 0, p_inverted := false) -> void:
	card = p_card
	lane = p_lane
	offset = p_offset
	inverted = p_inverted


## Expands into per-lane placements: one voice per chord lane, plus echo copies.
func placements() -> Array[WavePlacement]:
	var out: Array[WavePlacement] = []
	var data := card.data
	for voice in data.waves.size():
		var w := data.waves[voice]
		if inverted:
			w = WaveMath.invert(w)
		out.append(WavePlacement.new(w, offset, lane + voice, card.uid))
		if data.echo != 0:
			out.append(WavePlacement.new(w, offset + data.echo, lane + voice, card.uid))
	return out


## True if this card puts any sample on (lane, cell).
func covers(p_lane: int, cell: int) -> bool:
	for p in placements():
		if p.lane == p_lane and cell >= p.offset and cell < p.offset + p.wave.size():
			return true
	return false
