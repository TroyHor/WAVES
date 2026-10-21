class_name Resolution
extends RefCounted
## Result of resolving all lanes for one turn. Lane i's enemy damage belongs to
## whichever enemy owns lane i (combat layer maps lanes to enemies).

var lanes: Array[LaneResult] = []
var to_player := 0


func to_lane(lane: int) -> int:
	return lanes[lane].to_enemy


func to_enemy_total() -> int:
	var total := 0
	for l in lanes:
		total += l.to_enemy
	return total
