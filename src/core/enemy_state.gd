class_name EnemyState
extends RefCounted
## Runtime state of one enemy in combat: HP, owned lanes, and this turn's intent.

var data: EnemyData
var hp := 0
var max_hp := 0
var first_lane := 0
## Intent per owned lane (index 0 = first_lane), each track_length long.
var intent: Array[PackedInt32Array] = []
var current_move: EnemyData.Move = null
var _repeat_count := 0


func _init(p_data: EnemyData = null, p_first_lane := 0) -> void:
	data = p_data
	first_lane = p_first_lane
	if data:
		hp = data.hp
		max_hp = data.hp


func is_alive() -> bool:
	return hp > 0


func owns_lane(lane: int) -> bool:
	return lane >= first_lane and lane < first_lane + data.lanes


## Picks this turn's move at random (respecting next / max_repeat) and builds the intent.
func roll_intent(rng: RandomNumberGenerator, track_length: int) -> void:
	var move := _choose_move(rng)
	_repeat_count = _repeat_count + 1 if move == current_move else 1
	current_move = move
	intent.clear()
	for i in data.lanes:
		intent.append(WaveMath.empty_track(track_length))
	for w in move.waves:
		var shape := w.shape
		if w.random_flip and rng.randf() < 0.5:
			shape = WaveMath.invert(shape)
		var offset := rng.randi_range(w.offset_min, w.offset_max)
		intent[w.lane] = WaveMath.add(intent[w.lane], WaveMath.place(shape, offset, track_length))


func _choose_move(rng: RandomNumberGenerator) -> EnemyData.Move:
	if current_move and current_move.next != "":
		return data.move_by_id(current_move.next)
	var candidates: Array[EnemyData.Move] = []
	var total := 0.0
	for m in data.moves:
		if m.weight <= 0.0:
			continue
		if m == current_move and m.max_repeat > 0 and _repeat_count >= m.max_repeat:
			continue
		candidates.append(m)
		total += m.weight
	if candidates.is_empty():
		return data.moves[0]
	var roll := rng.randf() * total
	for m in candidates:
		roll -= m.weight
		if roll < 0.0:
			return m
	return candidates[-1]
