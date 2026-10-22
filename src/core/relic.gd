class_name Relic
extends RefCounted
## Base class for relics. Override only the hooks you need; every hook is a
## no-op by default. Combat calls them in this order:
##   on_combat_start  once, before the first turn is drawn
##   on_turn_start    each turn, after drawing and rolling enemy intents
##   modify_result    inside Combat.preview(), so the live preview and the real
##                    resolution always agree (call result.recount() after
##                    changing per-cell damage)
##   after_resolve    after this turn's damage is applied, before win/loss is
##                    decided (so healing here can save the player)

var id := ""


func on_combat_start(_combat: Combat) -> void:
	pass


func on_turn_start(_combat: Combat) -> void:
	pass


func modify_result(_combat: Combat, _result: TrackResult) -> void:
	pass


func after_resolve(_combat: Combat, _report: TurnReport) -> void:
	pass
