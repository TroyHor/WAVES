class_name CardInstance
extends RefCounted
## A specific copy of a card in a deck (two "Pulse" cards are two instances).

static var _next_uid := 1

var uid: int
var data: CardData


func _init(p_data: CardData) -> void:
	data = p_data
	uid = _next_uid
	_next_uid += 1
