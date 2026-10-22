class_name Resolver
extends RefCounted
## Superposition + per-cell resolution. The single source of truth for both the
## live preview and the real end-of-turn resolution.


## `enemy` is the combined enemy intent (length rules.track_length). With several
## enemies (Interference Twins) the combat layer sums their waves before calling this.
static func resolve(enemy: PackedInt32Array, placements: Array[WavePlacement], rules: RulesConfig) -> TrackResult:
	return resolve_track(enemy, player_track(placements, rules), rules.overflow_ratio)


## Sum of all player placements on an empty track.
static func player_track(placements: Array[WavePlacement], rules: RulesConfig) -> PackedInt32Array:
	var player := WaveMath.empty_track(rules.track_length)
	for p in placements:
		player = WaveMath.add(player, WaveMath.place(p.wave, p.offset, rules.track_length, rules.offtrack_mode))
	return player


static func resolve_track(enemy: PackedInt32Array, player: PackedInt32Array, overflow_ratio := 1.0) -> TrackResult:
	assert(enemy.size() == player.size(), "Resolver: track length mismatch")
	var r := TrackResult.new()
	r.enemy = enemy.duplicate()
	r.player = player.duplicate()
	r.net = WaveMath.add(enemy, player)
	var n := enemy.size()
	r.outcome.resize(n)
	r.damage.resize(n)
	r.blocked.resize(n)
	for t in n:
		var e := enemy[t]
		var net := r.net[t]
		# Blocked = the part of the enemy wave an opposite-sign player wave cancels.
		if e != 0 and signi(player[t]) == -signi(e):
			r.blocked[t] = mini(absi(e), absi(player[t]))
			r.blocked_total += r.blocked[t]
		var outcome := TrackResult.Outcome.EMPTY
		var dmg := 0
		if e != 0:
			if net == 0:
				outcome = TrackResult.Outcome.CANCELLED
				r.perfect_cancels += 1
			elif signi(net) == signi(e):
				outcome = TrackResult.Outcome.PLAYER_HIT
				dmg = absi(net)
				r.to_player += dmg
			else:
				outcome = TrackResult.Outcome.OVERFLOW
				dmg = floori(absi(net) * overflow_ratio)
				r.to_enemy += dmg
				r.overflow_damage += dmg
		elif net != 0:
			outcome = TrackResult.Outcome.ENEMY_HIT
			dmg = absi(net)
			r.to_enemy += dmg
		r.outcome[t] = outcome
		r.damage[t] = dmg
	return r
