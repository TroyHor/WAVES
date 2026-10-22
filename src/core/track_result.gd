class_name TrackResult
extends RefCounted
## Per-cell resolution of the wave track. Produced by Resolver; read by UI previews.

enum Outcome {
	EMPTY,        ## E = 0 and N = 0: nothing happens
	PLAYER_HIT,   ## E != 0, residual has enemy's sign: player takes |N|
	CANCELLED,    ## E != 0, N = 0: perfect cancellation
	OVERFLOW,     ## E != 0, residual has player's sign: enemy takes |N| * overflow_ratio
	ENEMY_HIT,    ## E = 0, N != 0: enemy takes |N|
}

var enemy: PackedInt32Array
var player: PackedInt32Array
var net: PackedInt32Array
var outcome: PackedInt32Array
## Damage dealt by each cell (to whichever side `outcome` says).
var damage: PackedInt32Array
## How much of the enemy's wave the player cancelled in each cell (0..|E|).
## Amplifying the enemy (same sign) blocks nothing.
var blocked: PackedInt32Array

var to_player := 0
var to_enemy := 0
var overflow_damage := 0
var perfect_cancels := 0
var blocked_total := 0


## Recomputes the totals from `outcome` / `damage` / `blocked` (for relics that
## change per-cell results in Relic.modify_result).
func recount() -> void:
	to_player = 0
	to_enemy = 0
	overflow_damage = 0
	perfect_cancels = 0
	blocked_total = 0
	for t in outcome.size():
		match outcome[t]:
			Outcome.PLAYER_HIT:
				to_player += damage[t]
			Outcome.OVERFLOW:
				to_enemy += damage[t]
				overflow_damage += damage[t]
			Outcome.ENEMY_HIT:
				to_enemy += damage[t]
			Outcome.CANCELLED:
				perfect_cancels += 1
		blocked_total += blocked[t]
