class_name TurnReport
extends RefCounted
## What happened when a turn was resolved; consumed by the UI for animation.

var result: TrackResult
## Enemy that received this turn's damage (the front enemy at resolution time).
var target: EnemyState
var player_hp_before := 0
var target_hp_before := 0
var killed := false
var swapped := false
var outcome := Combat.Outcome.ONGOING
