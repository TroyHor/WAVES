class_name GreedyBot
extends RefCounted
## Simple AI that plays a turn by repeatedly placing the single card/position
## that most improves the preview score. Used for tests and balance simulation;
## it is a baseline, not a strong player.

## How much one point of player HP is worth relative to one point of enemy damage.
## > 1 because player HP persists across the run.
var hp_weight := 1.5


func play_turn(state: CombatState) -> void:
	while state.status == CombatState.Status.ONGOING:
		var best: PlayedCard = null
		var best_score := score(state, state.preview())
		for card in state.deck.hand.duplicate():
			if not state.can_afford(card):
				continue
			if not card.data.has_wave():
				best = PlayedCard.new(card)
				best_score = INF
				break
			for lane in state.lane_count():
				if not state.is_lane_open(lane):
					continue
				for offset in range(-card.data.span() + 1, state.rules.track_length):
					for inv in ([false, true] if card.data.flippable else [false]):
						if not state.can_place(card, lane, offset):
							continue
						var ghost := PlayedCard.new(card, lane, offset, inv)
						var s := score(state, state.preview(ghost))
						if s > best_score:
							best_score = s
							best = ghost
		if best == null:
			return
		state.play(best.card, best.lane, best.offset, best.inverted)


func score(state: CombatState, res: Resolution) -> float:
	var dealt := 0
	var dmg := state.damage_by_enemy(res)
	for i in dmg.size():
		dealt += mini(dmg[i], state.enemies[i].hp)  # overkill is worthless
	return dealt - hp_weight * res.to_player


## Plays a whole combat; returns the number of turns taken (capped).
func play_combat(state: CombatState, max_turns := 100) -> int:
	if state.turn == 0:
		state.start()
	while state.status == CombatState.Status.ONGOING and state.turn <= max_turns:
		play_turn(state)
		state.end_turn()
	return state.turn
