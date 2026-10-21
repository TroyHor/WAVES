extends SceneTree
## Balance simulation: the greedy bot fights every enemy from full HP.
##   godot --headless --path . -s res://tools/simulate.gd [-- runs]

func _initialize() -> void:
	var runs := 200
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		runs = int(args[0])
	var rules := RulesConfig.load_file()
	var lib := ContentLibrary.load_default()
	var deck: Array[CardData] = []
	for id in lib.starter_deck:
		deck.append(lib.cards[id])
	var bot := GreedyBot.new()

	print("enemy            win%%  avg_turns  avg_hp_lost  max_hp_lost   (%d runs, start HP %d)" % [runs, rules.player_max_hp])
	for enemy_id in lib.enemy_ids():
		var wins := 0
		var turns := 0
		var lost := 0
		var worst := 0
		for i in runs:
			var enemies: Array[EnemyData] = [lib.enemies[enemy_id]]
			var state := CombatState.new(rules, deck, enemies, rules.player_max_hp, i + 1)
			turns += bot.play_combat(state)
			var hp_lost := rules.player_max_hp - state.player_hp
			lost += hp_lost
			worst = maxi(worst, hp_lost)
			if state.status == CombatState.Status.WON:
				wins += 1
		print("%-16s %4.0f  %9.1f  %11.1f  %11d" % [enemy_id, 100.0 * wins / runs, float(turns) / runs, float(lost) / runs, worst])
	quit()
