class_name TurnReport
extends RefCounted
## What happened when a turn was resolved (for UI feedback and logs).

var turn := 0
var resolution: Resolution
var damage_to_player := 0
## Damage dealt to each enemy, indexed like CombatState.enemies.
var damage_to_enemies: Array[int] = []
var status := 0  ## CombatState.Status after this turn
