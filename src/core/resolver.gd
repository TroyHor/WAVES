class_name Resolver
extends RefCounted
## Superposition + per-cell resolution. The single source of truth for both the
## live preview and the real end-of-turn resolution.


## enemy_lanes[i] is the enemy intent on lane i (each of length rules.track_length).
## Placements on lanes that don't exist are ignored (e.g. extra chord voices).
static func resolve(enemy_lanes: Array[PackedInt32Array], placements: Array[WavePlacement], rules: RulesConfig) -> Resolution:
	var res := Resolution.new()
	for lane in enemy_lanes.size():
		var player := WaveMath.empty_track(rules.track_length)
		for p in placements:
			if p.lane == lane:
				player = WaveMath.add(player, WaveMath.place(p.wave, p.offset, rules.track_length, rules.offtrack_mode))
		var lr := resolve_lane(enemy_lanes[lane], player, rules.overflow_ratio)
		res.lanes.append(lr)
		res.to_player += lr.to_player
	return res


static func resolve_lane(enemy: PackedInt32Array, player: PackedInt32Array, overflow_ratio := 1.0) -> LaneResult:
	assert(enemy.size() == player.size(), "Resolver: lane length mismatch")
	var lr := LaneResult.new()
	lr.enemy = enemy.duplicate()
	lr.player = player.duplicate()
	lr.net = WaveMath.add(enemy, player)
	var n := enemy.size()
	lr.outcome.resize(n)
	lr.damage.resize(n)
	for t in n:
		var e := enemy[t]
		var net := lr.net[t]
		var outcome := LaneResult.Outcome.EMPTY
		var dmg := 0
		if e != 0:
			if net == 0:
				outcome = LaneResult.Outcome.CANCELLED
				lr.perfect_cancels += 1
			elif signi(net) == signi(e):
				outcome = LaneResult.Outcome.PLAYER_HIT
				dmg = absi(net)
				lr.to_player += dmg
			else:
				outcome = LaneResult.Outcome.OVERFLOW
				dmg = floori(absi(net) * overflow_ratio)
				lr.to_enemy += dmg
				lr.overflow_damage += dmg
		elif net != 0:
			outcome = LaneResult.Outcome.ENEMY_HIT
			dmg = absi(net)
			lr.to_enemy += dmg
		lr.outcome[t] = outcome
		lr.damage[t] = dmg
	return lr
