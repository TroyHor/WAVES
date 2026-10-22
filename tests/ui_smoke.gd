extends RefCounted
## UI smoke test, run via `godot --headless --path . -- --selftest`.
## Drives the real combat screen with synthetic mouse events that pass through
## Main's CRT input remap, then checks the resulting Combat state.

var _app: Node
var _failures := PackedStringArray()


func run(app: Node) -> int:
	_app = app
	app.start_combat("01_drone", 1)
	# Let the opening hand finish flying in from the draw pile.
	await _app.get_tree().create_timer(1.2).timeout
	var screen: Control = app.current_screen()
	var combat: Combat = screen.combat

	# 1. Drag the first playable wave card onto the middle of the scope.
	var view := _first_wave_card(screen)
	_check(view != null, "a playable wave card is in hand")
	if view == null:
		return _finish()
	var card := view.card
	var panel: MergedView = screen._merged
	var target := panel.global_position + Vector2(panel.cell_center_x(8), panel.size.y * 0.4)
	await _drag(_card_center(view), target)
	var played := combat.find_played(card)
	_check(played != null, "card was played by dragging onto the scope")
	_check(combat.energy == combat.rules.energy_per_turn - card.data.cost, "energy spent")
	if played != null:
		var expected := 8 - card.data.wave.size() / 2
		_check(played.offset == expected, "offset %d == %d (grab at wave centre)" % [played.offset, expected])

	# 2. Drag the placed wave off the scope (onto the hand area) to take it back.
	if played != null:
		var from := panel.global_position + Vector2(panel.cell_center_x(played.offset), panel.size.y * 0.4)
		await _drag(from, Vector2(screen.size.x * 0.5, screen.size.y - 60))
		_check(combat.find_played(card) == null, "card taken back off the scope")
		_check(card in combat.deck.hand, "card returned to hand")
		_check(combat.energy == combat.rules.energy_per_turn, "energy refunded")

	# 3. Play it again and resolve with Enter.
	view = _first_wave_card(screen)
	await _app.get_tree().create_timer(0.6).timeout
	await _drag(_card_center(view), target)
	var enemy := combat.front_enemy()
	var expected_hp := enemy.hp - combat.preview().to_enemy
	var expected_player := combat.player_hp - combat.preview().to_player
	_key(KEY_ENTER)
	await _app.get_tree().create_timer(4.0).timeout
	_check(combat.turn == 2, "turn advanced after resolving (turn=%d)" % combat.turn)
	_check(enemy.hp == expected_hp, "enemy HP matches the preview (%d == %d)" % [enemy.hp, expected_hp])
	_check(combat.player_hp == expected_player, "player HP matches the preview")

	# 4. Run flow: run map -> first fight (HP carried) -> back to map after a win.
	app.start_run(3)
	await _frames(3)
	_check(app.current_screen().get("run") != null, "run map shown")
	app.start_run_fight()
	await _frames(3)
	var fight: Control = app.current_screen()
	_check(fight.run == app.run and fight.encounter.id == app.db.run_order[0], "first run fight started")
	fight.combat.player_hp = 41
	fight.combat.outcome = Combat.Outcome.WON
	app.finish_run_fight(fight.combat)
	await _frames(3)
	_check(app.run.index == 1 and app.run.player_hp == 41, "run advanced with HP carried over")
	return _finish()


## Visual centre of a (possibly scaled / rotated) card.
func _card_center(view: CardView) -> Vector2:
	return view.get_global_transform() * (CardView.CARD_SIZE * 0.5)


func _first_wave_card(screen: Control) -> CardView:
	for v in screen._card_views:
		if v.card.data.is_wave_card() and screen.combat.can_play(v.card):
			return v
	return null


func _drag(from_game: Vector2, to_game: Vector2) -> void:
	_mouse_button(from_game, true)
	await _frames(2)
	for i in range(1, 6):
		_motion(from_game.lerp(to_game, i / 5.0))
		await _frames(1)
	_mouse_button(to_game, false)
	await _frames(3)


func _mouse_button(game_pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = _app.crt_unmap(game_pos)
	ev.global_position = ev.position
	_app._input(ev)


func _motion(game_pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = _app.crt_unmap(game_pos)
	ev.global_position = ev.position
	_app._input(ev)


func _key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	_app._input(ev)


func _frames(n: int) -> void:
	for i in n:
		await _app.get_tree().process_frame


func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures.append(what)


func _finish() -> int:
	if _failures.is_empty():
		print("UI SMOKE PASS")
		return 0
	for f in _failures:
		printerr("UI SMOKE FAIL  ", f)
	return 1
