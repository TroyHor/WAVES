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
