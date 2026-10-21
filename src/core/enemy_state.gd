class_name EnemyState
extends RefCounted
## Runtime state of one enemy: HP and this turn's rolled intent.

var data: EnemyData
var hp: int
var move: EnemyMove
var intent := PackedInt32Array()
var _repeat_count := 0


func _init(p_data: EnemyData) -> void:
	data = p_data
	hp = data.max_hp


func is_alive() -> bool:
	return hp > 0


## Picks this turn's move (forced follow-up, else weighted random respecting
## max_repeat) and builds the full-length intent track.
func roll_intent(rng: RandomNumberGenerator, track_length: int) -> void:
	var previous := move
	var chosen: EnemyMove = null
	if previous != null and previous.next != "":
		chosen = data.find_move(previous.next)
	if chosen == null:
		chosen = _pick_weighted(rng, previous)
	_repeat_count = _repeat_count + 1 if chosen == previous else 1
	move = chosen
	intent = build_intent(chosen, rng, track_length)


## Random segments may cancel each other completely; re-roll so an attack is
## never silently empty.
static func build_intent(m: EnemyMove, rng: RandomNumberGenerator, track_length: int) -> PackedInt32Array:
	var track := _roll_segments(m, rng, track_length)
	for attempt in 10:
		if track.count(0) < track.size():
			break
		track = _roll_segments(m, rng, track_length)
	return track


static func _roll_segments(m: EnemyMove, rng: RandomNumberGenerator, track_length: int) -> PackedInt32Array:
	var track := WaveMath.empty_track(track_length)
	for seg in m.segments:
		var shape: PackedInt32Array = seg["shape"]
		var max_fit := maxi(0, track_length - shape.size())
		var lo: int = seg["offset_min"]
		var hi: int = seg["offset_max"]
		if lo == EnemyMove.AUTO:
			lo = 0
		if hi == EnemyMove.AUTO:
			hi = max_fit
		var count := rng.randi_range(seg["count_min"], seg["count_max"])
		for i in count:
			var w := shape
			if rng.randf() < seg["flip_chance"]:
				w = WaveMath.invert(shape)
			track = WaveMath.add(track, WaveMath.place(w, rng.randi_range(lo, hi), track_length))
	return track


func _pick_weighted(rng: RandomNumberGenerator, previous: EnemyMove) -> EnemyMove:
	var pool: Array[EnemyMove] = []
	var total := 0.0
	for m in data.moves:
		if m.weight <= 0:
			continue
		if previous == m and m.max_repeat > 0 and _repeat_count >= m.max_repeat:
			continue
		pool.append(m)
		total += m.weight
	if pool.is_empty():
		# Every pickable move is exhausted by max_repeat; ignore the limit.
		for m in data.moves:
			if m.weight > 0:
				pool.append(m)
				total += m.weight
	var roll := rng.randf() * total
	for m in pool:
		roll -= m.weight
		if roll < 0:
			return m
	return pool[pool.size() - 1]
