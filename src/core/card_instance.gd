class_name CardInstance
extends RefCounted
## A concrete copy of a card in the player's deck (upgrades will live here).

var uid: int
var data: CardData


func _init(p_uid := 0, p_data: CardData = null) -> void:
	uid = p_uid
	data = p_data
