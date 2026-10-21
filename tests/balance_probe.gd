extends SceneTree
## Balance probe (not a test): plays every encounter with the greedy test bot
## over many seeds and prints win rate, fight length and HP lost.
##   scripts/balance.sh [seeds]

const BOT_STYLES := {"aggressive": 1.0, "careful": 1.5}


func _initialize() -> void:
	var seeds := 50
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		seeds = int(args[0])
	var db := GameDatabase.load_default()
	var rules := RulesConfig.load_file()
	var bot = load("res://tests/unit/test_combat.gd").new()
	print("%-20s %-11s %8s %8s %10s" % ["encounter", "bot", "win%", "turns", "hp lost"])
	for enc_id in db.encounter_ids():
		for style in BOT_STYLES:
			var wins := 0
			var turns := 0
			var lost := 0
			for s in seeds:
				var c := Combat.from_encounter(db, enc_id, s, rules)
				c.start()
				while c.outcome == Combat.Outcome.ONGOING and c.turn < 100:
					bot._bot_turn(c, BOT_STYLES[style])
					c.resolve_turn()
				if c.outcome == Combat.Outcome.WON:
					wins += 1
				turns += c.turn
				lost += c.player_max_hp - c.player_hp
			print("%-20s %-11s %7.0f%% %8.1f %10.1f" % [enc_id, style, 100.0 * wins / seeds, float(turns) / seeds, float(lost) / seeds])
	quit()
