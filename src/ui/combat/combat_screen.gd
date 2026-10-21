extends Control
## Combat screen. Owns no rules: every number shown comes from Combat.preview()
## or Combat.resolve_turn().
##
## Layout (top to bottom): enemy signal panel (flat, polylines), the centre
## bench oscilloscope (smooth overlaid waves + strength bars + readout), the
## player signal panel, then the hand. A left column holds the enemy figure(s),
## the preview totals + resolve, and the player figure/HP/energy/piles. All
## three wave panels share the same cell columns.
##
## Controls: drag a card onto the scopes; right-click / R flips flippable cards;
## drag a placed wave off the scopes to take it back; Enter/Space resolves.

const BACKGROUND_SHADER := preload("res://src/ui/crt/pcb_background.gdshader")
const LAUNCH_SECONDS := 0.45
const IMPACT_SECONDS := 0.6
const SHOT_SECONDS := 0.5
const LEFT_COL := 330.0
const RIGHT_MARGIN := 24.0
## Grid inset inside each wave panel (name plate on the left, knobs on the right).
const GRID_INSET_L := 150.0
const GRID_INSET_R := 120.0

var app: Node
var combat: Combat
var encounter: EncounterData
var seed_value := 0
var demo := false
## Set when this fight is part of a run (null for single-fight testing).
var run: RunState
var tutorial_enabled := true

var _enemy_scope: FlatScopeView
var _player_scope: FlatScopeView
var _merged: MergedView
var _fx: FxLayer
var _hand_root: Control
var _card_views: Array[CardView] = []
var _player_figure: FigureView
var _player_hp: HpBar
## EnemyState -> {"figure": FigureView, "panel": EnemyPanel}
var _enemy_views := {}
var _to_enemy_label: Label
var _to_player_label: Label
var _turn_label: Label
var _energy: EnergyView
var _draw_pile: PileIcon
var _discard_pile: PileIcon
var _bg_mat: ShaderMaterial
var _arrows: Array[ArrowIcon] = []
var _enemy_row := Rect2()
var _resolve_btn: Button
var _menu_btn: Button
var _toast: Label
var _overlay: Control
var _hint: HintPanel
var _hint_data := {}

# Drag state. Picking a placed wave back up unplays it, so every drag is a
# drag "from hand" and preview uses a hypothetical PlayedCard.
var _drag_card: CardInstance
var _drag_grab := 0
var _drag_flipped := false
var _drag_offset := 0
var _drag_over := false
var _drag_ghost: CardView
var _hover_card: CardInstance
var _hover_cell := -1
var _animating := false


func _ready() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_mat = ShaderMaterial.new()
	_bg_mat.shader = BACKGROUND_SHADER
	bg.material = _bg_mat
	add_child(bg)

	_enemy_scope = _make_scope("敌方信号", Assets.color("enemy_ch1"), 1.0)
	_merged = MergedView.new()
	_merged.track_length = combat.rules.track_length
	_merged.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_merged)
	_player_scope = _make_scope("我方信号", Assets.color("player_wave"), -1.0)

	for e in combat.enemies:
		var fig := FigureView.new()
		fig.shape = e.data.figure_shape
		fig.color = Assets.color(e.data.color_id)
		fig.texture = Assets.texture(e.data.texture_id) if e.data.texture_id != "" else null
		add_child(fig)
		var panel := EnemyPanel.new()
		add_child(panel)
		_enemy_views[e] = {"figure": fig, "panel": panel}

	_player_figure = FigureView.new()
	_player_figure.shape = "player"
	_player_figure.color = Assets.color("player_wave")
	_player_figure.texture = Assets.texture("player")
	_player_figure.size = Vector2(130, 110)
	add_child(_player_figure)

	_player_hp = HpBar.new()
	_player_hp.label = "HP"
	_player_hp.color = Assets.color("player_wave")
	_player_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_player_hp)

	_to_enemy_label = _make_label(48, Assets.color("damage_to_enemy"))
	_to_player_label = _make_label(48, Assets.color("damage_to_player"))
	_turn_label = _make_label(18, Assets.color("text_dim"))
	for up in [true, false]:
		var arrow := ArrowIcon.new()
		arrow.up = up
		arrow.color = Assets.color("damage_to_enemy") if up else Assets.color("damage_to_player")
		arrow.tooltip_text = "预计对敌人造成的伤害" if up else "预计你受到的伤害"
		arrow.size = Vector2(44, 48)
		add_child(arrow)
		_arrows.append(arrow)

	_energy = EnergyView.new()
	add_child(_energy)
	_draw_pile = PileIcon.new()
	add_child(_draw_pile)
	_discard_pile = PileIcon.new()
	_discard_pile.discard = true
	add_child(_discard_pile)

	_resolve_btn = Button.new()
	_resolve_btn.text = "结算  ⏎"
	_resolve_btn.add_theme_font_size_override("font_size", Assets.fs(28))
	_resolve_btn.pressed.connect(_resolve)
	add_child(_resolve_btn)

	_menu_btn = Button.new()
	_menu_btn.text = "菜单"
	_menu_btn.pressed.connect(func() -> void: app.show_menu())
	add_child(_menu_btn)

	_hand_root = Control.new()
	_hand_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hand_root)

	_fx = FxLayer.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fx)

	_toast = _make_label(40, Assets.color("net_wave"))
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0

	resized.connect(_layout)
	combat.start()
	_layout()
	if demo:
		_demo_setup()
	refresh()


func _make_scope(title: String, accent: Color, dir: float) -> FlatScopeView:
	var s := FlatScopeView.new()
	s.title = title
	s.accent = accent
	s.screen.track_length = combat.rules.track_length
	s.screen.launch_dir = dir
	add_child(s)
	return s


func _make_label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", Assets.fs(font_size))
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


# --- Layout ----------------------------------------------------------------

func _layout() -> void:
	var w := size.x
	var h := size.y
	var x := LEFT_COL
	var pw := w - LEFT_COL - RIGHT_MARGIN
	var gx0 := GRID_INSET_L
	var gx1 := pw - GRID_INSET_R
	# Rows scale with the available height (16:10 screens get taller panels).
	var hand_h := CardView.CARD_SIZE.y + 30.0
	var avail := h - hand_h - 10.0
	var row_h := maxf(196.0, avail * 0.22)
	var mid_h := avail - row_h * 2 - 16.0
	var e0 := 10.0
	var m0 := e0 + row_h + 8.0
	var p0 := m0 + mid_h + 8.0
	_enemy_row = Rect2(0, e0, LEFT_COL, row_h)
	_enemy_scope.position = Vector2(x, e0)
	_enemy_scope.size = Vector2(pw, row_h)
	_merged.position = Vector2(x, m0)
	_merged.size = Vector2(pw, mid_h)
	_player_scope.position = Vector2(x, p0)
	_player_scope.size = Vector2(pw, row_h)
	for s in [_enemy_scope, _player_scope]:
		s.grid_x0 = gx0
		s.grid_x1 = gx1
		s.layout_screen()
	_merged.grid_x0 = gx0
	_merged.grid_x1 = gx1
	_merged.layout_parts()
	_bg_mat.set_shader_parameter("size_px", size)

	_layout_enemies(false)

	# Centre-left column: preview totals (arrow icons + big numbers) and resolve.
	_arrows[0].position = Vector2(30, m0 + 38)
	_arrows[1].position = Vector2(30, m0 + 38 + Assets.fs(80))
	_to_enemy_label.position = Vector2(84, m0 + 20)
	_to_player_label.position = Vector2(84, m0 + 20 + Assets.fs(80))
	_turn_label.position = Vector2(24, m0 + 30 + Assets.fs(160))
	_resolve_btn.position = Vector2(24, m0 + mid_h - 100)
	_resolve_btn.size = Vector2(LEFT_COL - 48, 90)

	# Player column beside the player panel, piles underneath.
	_player_figure.position = Vector2(14, p0 + 2)
	_energy.position = Vector2(160, p0 + 24)
	_energy.size = Vector2(150, 64)
	_player_hp.position = Vector2(20, p0 + row_h - 76)
	_player_hp.size = Vector2(LEFT_COL - 44, 70)
	var piles_y := p0 + row_h + 16
	var pile_h := minf(140.0, h - piles_y - 14)
	_draw_pile.position = Vector2(24, piles_y)
	_draw_pile.size = Vector2(120, pile_h)
	_discard_pile.position = Vector2(170, piles_y)
	_discard_pile.size = Vector2(120, pile_h)

	_hand_root.position = Vector2(0, h - CardView.CARD_SIZE.y - 14)
	_hand_root.size = Vector2(w, CardView.CARD_SIZE.y)
	_menu_btn.position = Vector2(w - 130, h - 60)
	_menu_btn.size = Vector2(110, 48)
	_toast.position = Vector2(LEFT_COL, m0 + 60)
	_toast.size = Vector2(pw, 60)
	_layout_hand()


## Enemy column beside the enemy panel; the twins stack vertically, front on
## top. With `animate` the figures glide into their new slots (swap).
func _layout_enemies(animate: bool) -> void:
	var n := combat.enemies.size()
	var row := _enemy_row
	var tw: Tween = create_tween().set_parallel(true) if animate else null
	for i in n:
		var e := combat.enemies[i]
		var v: Dictionary = _enemy_views[e]
		var fig_rect: Rect2
		var panel_rect: Rect2
		if n == 1:
			var fh := row.size.y * 0.5
			fig_rect = Rect2(LEFT_COL * 0.5 - fh * 0.6, row.position.y, fh * 1.2, fh)
			panel_rect = Rect2(20, row.position.y + fh, LEFT_COL - 44, row.size.y - fh)
		else:
			var slot := row.size.y / n
			var y := row.position.y + i * slot
			fig_rect = Rect2(10, y + 4, 84, slot - 8)
			panel_rect = Rect2(100, y + 2, LEFT_COL - 124, slot - 4)
		v["figure"].size = fig_rect.size
		v["panel"].size = panel_rect.size
		if tw != null:
			tw.tween_property(v["figure"], "position", fig_rect.position, 0.5).set_trans(Tween.TRANS_BACK)
			tw.tween_property(v["panel"], "position", panel_rect.position, 0.5).set_trans(Tween.TRANS_BACK)
		else:
			v["figure"].position = fig_rect.position
			v["panel"].position = panel_rect.position


func _layout_hand() -> void:
	var gap := 14.0
	var total := _card_views.size() * CardView.CARD_SIZE.x + maxf(0, _card_views.size() - 1) * gap
	var x := LEFT_COL + (size.x - LEFT_COL - total) * 0.5
	for v in _card_views:
		v.position = Vector2(x, 0)
		x += CardView.CARD_SIZE.x + gap


## Rect (screen-local) of a named UI element, for tutorial highlighting.
func anchor_rect(anchor: String) -> Rect2:
	match anchor:
		"enemy_scope": return _enemy_scope.get_rect()
		"player_scope": return _player_scope.get_rect()
		"collision": return _merged.get_rect()
		"resolve": return _resolve_btn.get_rect()
		"player_figure": return _player_figure.get_rect().merge(_player_hp.get_rect())
		"energy": return _energy.get_rect()
		"enemy_figure":
			var front := combat.front_enemy()
			if front != null:
				var v: Dictionary = _enemy_views[front]
				return v["figure"].get_rect().merge(v["panel"].get_rect())
		"hand":
			if not _card_views.is_empty():
				var r: Rect2 = _card_views[0].get_global_rect()
				for c in _card_views:
					r = r.merge(c.get_global_rect())
				return Rect2(r.position - global_position, r.size)
	return Rect2()


# --- Refresh ---------------------------------------------------------------

func refresh() -> void:
	_rebuild_hand()
	_refresh_preview()


func _rebuild_hand() -> void:
	for v in _card_views:
		v.queue_free()
	_card_views.clear()
	for c in combat.deck.hand:
		var v := CardView.new(c)
		v.playable = combat.can_play(c) and not _animating
		v.visible = c != _drag_card
		v.grabbed.connect(_on_card_grabbed)
		_hand_root.add_child(v)
		_card_views.append(v)
	_layout_hand()


func _drag_played_card() -> PlayedCard:
	if _drag_card == null or not _drag_over or not _drag_card.data.is_wave_card():
		return null
	return PlayedCard.new(_drag_card, _drag_offset, _drag_flipped)


func _refresh_preview() -> void:
	if _animating:
		return
	var extra := _drag_played_card()
	var result := combat.preview(extra)
	var enemy_track := combat.enemy_track()

	# Shared vertical scale for both bench scopes.
	var amp := 10.0
	for v in enemy_track:
		amp = maxf(amp, absf(v))
	for v in result.player:
		amp = maxf(amp, absf(v))
	var es := _enemy_scope.screen
	var ps := _player_scope.screen
	es.amp_scale = amp
	ps.amp_scale = amp

	var echans: Array = []
	var merged_enemy: Array = []
	var alive := combat.alive_enemies()
	for i in alive.size():
		var e := alive[i]
		var col := Assets.color(e.data.color_id)
		echans.append({"track": e.intent, "color": col, "width": 2.6})
		merged_enemy.append({"track": e.intent, "color": col, "label": e.data.name})
	if alive.size() > 1:
		echans.append({"track": enemy_track, "color": Color(Assets.color("net_wave"), 0.5), "width": 1.6, "dashed": true})
	es.channels = echans
	es.tint_track = enemy_track
	es.tint_color = Assets.color("enemy_ch1")

	var pchans: Array = []
	# Dashed guide: the wave that would cancel the enemy exactly.
	pchans.append({"track": WaveMath.invert(enemy_track), "color": Color(Assets.color("player_wave"), 0.3), "width": 1.4, "dashed": true})
	# Only the combined player wave is shown (individual cards are not drawn).
	var parts: Array = []
	if not combat.played.is_empty() or extra != null:
		parts.append({"track": result.player, "from": 0, "to": combat.rules.track_length - 1, "emphasis": true})
		pchans.append({"track": result.player, "color": Assets.color("player_wave"), "width": 3.0})
	ps.channels = pchans
	ps.tint_track = enemy_track
	ps.tint_color = Assets.color("enemy_ch1")

	_merged.enemy_channels = merged_enemy
	_merged.enemy_sum = enemy_track
	_merged.player_parts = parts
	_merged.result = result
	_merged.reveal = 1.0
	_merged.arrive = 1.0
	_merged.merge = 0.0
	es.highlight_cell = _hover_cell
	ps.highlight_cell = _hover_cell
	_merged.highlight_cell = _hover_cell

	_player_hp.set_values(combat.player_hp, combat.player_max_hp, result.to_player)
	_update_enemy_panels(result.to_enemy)
	_to_enemy_label.text = str(result.to_enemy)
	_to_player_label.text = str(result.to_player)
	_turn_label.text = "回合 %d" % combat.turn
	if combat.swap_in() > 0:
		_turn_label.text += "  ·  交换倒计时 %d" % combat.swap_in()
	_energy.energy = combat.energy
	_energy.max_energy = combat.rules.energy_per_turn
	_draw_pile.count = combat.deck.draw_pile.size()
	_discard_pile.count = combat.deck.discard_pile.size()
	_resolve_btn.disabled = _animating or combat.outcome != Combat.Outcome.ONGOING
	_update_tutorial(result)


func _update_enemy_panels(to_enemy: int) -> void:
	var front := combat.front_enemy()
	var multi := combat.enemies.size() > 1
	for e in combat.enemies:
		var v: Dictionary = _enemy_views[e]
		v["panel"].update_view(e, e == front, multi, combat.swap_in(), to_enemy)
		v["figure"].dead = not e.is_alive()
		v["figure"].back_row = multi and e != front and e.is_alive()


# --- Tutorial --------------------------------------------------------------

func _tutorial_ctx(result: TrackResult) -> Dictionary:
	var keywords: Array = []
	var effects: Array = []
	for c in combat.deck.hand:
		for k in c.data.keywords:
			keywords.append(k)
		for e in c.data.effects:
			effects.append(e["type"])
	var forced := false
	for e in combat.alive_enemies():
		if e.move != null and e.move.next != "":
			forced = true
	return {
		"encounter": encounter.id, "turn": combat.turn, "run_index": run.index if run != null else -1,
		"hand_keywords": keywords, "hand_effects": effects,
		"preview_outcomes": TutorialRules.outcome_names(result),
		"multi_enemy": combat.enemies.size() > 1, "forced_next": forced, "played": combat.played.size(),
	}


func _update_tutorial(result: TrackResult) -> void:
	if not tutorial_enabled or _hint != null or _overlay != null or _drag_card != null:
		return
	var h := TutorialRules.next_hint(app.db.hints, _tutorial_ctx(result), app.progress.seen_hints)
	if h.is_empty():
		return
	_hint_data = h
	_hint = HintPanel.new()
	_hint.text = h["text"]
	_hint.anchor_rect = anchor_rect(h.get("anchor", "none"))
	_hint.show_button = h.get("complete", "button") == "button"
	_hint.dismissed.connect(_complete_hint.bind("button"))
	add_child(_hint)


func _complete_hint(kind: String) -> void:
	if _hint == null or _hint_data.get("complete", "button") != kind:
		return
	app.progress.mark_seen(_hint_data["id"])
	_hint.queue_free()
	_hint = null
	_hint_data = {}
	if not _animating:
		_refresh_preview()


# --- Input -----------------------------------------------------------------

func _on_card_grabbed(view: CardView) -> void:
	if _animating or _drag_card != null or not combat.can_play(view.card):
		return
	_start_drag(view.card, view.card.data.wave.size() / 2, false)


func _start_drag(card: CardInstance, grab: int, flipped: bool) -> void:
	_drag_card = card
	_drag_grab = grab
	_drag_flipped = flipped
	_drag_over = false
	_drag_ghost = CardView.new(card)
	_drag_ghost.ghost = true
	_drag_ghost.flipped = flipped
	_drag_ghost.modulate.a = 0.85
	add_child(_drag_ghost)
	_update_drag(get_global_mouse_position())
	refresh()


## Both bench scopes and the merged panel together form the drop area.
func _over_scopes(mouse: Vector2) -> bool:
	var r := _enemy_scope.get_global_rect().merge(_player_scope.get_global_rect())
	return r.grow(10).has_point(mouse)


func _cell_at(mouse: Vector2) -> int:
	return _merged.cell_at(mouse - _merged.global_position)


func _update_drag(mouse: Vector2) -> void:
	_drag_over = _over_scopes(mouse)
	_hover_cell = _cell_at(mouse) if _drag_over else -1
	_drag_offset = _cell_at(mouse) - _drag_grab
	if _drag_ghost != null:
		_drag_ghost.global_position = mouse - CardView.CARD_SIZE * 0.5
		# Over the scopes the wave itself is the feedback; hide the card.
		_drag_ghost.visible = not (_drag_over and _drag_card.data.is_wave_card())
	_refresh_preview()


func _end_drag(drop: bool) -> void:
	var card := _drag_card
	var played := false
	if drop and card != null:
		if card.data.is_wave_card():
			if _drag_over:
				played = combat.play(card, _drag_offset, _drag_flipped)
		elif get_global_mouse_position().y < _hand_root.global_position.y - 20:
			played = combat.play(card)
	_drag_card = null
	if _drag_ghost != null:
		_drag_ghost.queue_free()
		_drag_ghost = null
	if played:
		_complete_hint("card_played")
	refresh()


func _toggle_drag_flip() -> void:
	if _drag_card != null and _drag_card.data.has_keyword("flippable"):
		_drag_flipped = not _drag_flipped
		if _drag_ghost != null:
			_drag_ghost.flipped = _drag_flipped
			_drag_ghost.queue_redraw()
		_refresh_preview()


## Placed card whose wave (or echo) covers the cell under `mouse`.
func _placed_card_at(mouse: Vector2) -> PlayedCard:
	if not _over_scopes(mouse):
		return null
	var cell := _cell_at(mouse)
	for i in range(combat.played.size() - 1, -1, -1):
		var p := combat.played[i]
		for pl in p.placements():
			if cell >= pl.offset and cell < pl.offset + pl.wave.size():
				return p
	return null


func _input(event: InputEvent) -> void:
	if _overlay != null:
		return
	if event is InputEventMouseMotion:
		if _drag_card != null:
			_update_drag(event.position)
		elif not _animating:
			var p := _placed_card_at(event.position)
			var hovered := p.card if p != null else null
			var cell := _cell_at(event.position) if _over_scopes(event.position) else -1
			if hovered != _hover_card or cell != _hover_cell:
				_hover_card = hovered
				_hover_cell = cell
				_refresh_preview()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if _drag_card != null:
				_toggle_drag_flip()
			else:
				var p := _placed_card_at(event.position)
				if p != null:
					combat.set_flipped(p.card, not p.flipped)
					_refresh_preview()
		elif event.button_index == MOUSE_BUTTON_LEFT and _drag_card == null and not _animating:
			var p := _placed_card_at(event.position)
			if p != null and combat.can_unplay(p.card):
				var grab := _cell_at(event.position) - p.offset
				var flipped := p.flipped
				combat.unplay(p.card)
				_start_drag(p.card, grab, flipped)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _drag_card != null:
			_end_drag(true)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				_toggle_drag_flip()
			KEY_ESCAPE:
				if _drag_card != null:
					_end_drag(false)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if _drag_card == null:
					_resolve()


# --- Resolution ------------------------------------------------------------

func _resolve() -> void:
	if _animating or _drag_card != null or combat.outcome != Combat.Outcome.ONGOING:
		return
	_complete_hint("resolve")
	if _hint != null:
		return  # an unanswered hint must be dismissed first
	var shown_player_hp := combat.player_hp
	var report := combat.resolve_turn()
	var r := report.result
	_animating = true
	_hover_cell = -1
	_resolve_btn.disabled = true
	for v in _card_views:
		v.playable = false
		v.queue_redraw()
	_player_hp.set_values(shown_player_hp, combat.player_max_hp, 0)

	# 1. Both bench scopes fire their waves into the merged panel.
	_merged.result = r
	_merged.arrive = 0.0
	_merged.reveal = 0.0
	_merged.merge = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_enemy_scope.screen, "launch", 1.0, LAUNCH_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_player_scope.screen, "launch", 1.0, LAUNCH_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_merged, "arrive", 1.0, LAUNCH_SECONDS + 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.1)
	await tw.finished

	# 2. Impact: soft rings where waves cancel, a smooth screen ripple, and
	#    the result bars / numbers pop in left to right.
	_merged.impact = 1.0
	app.impact(_merged.global_position + _merged.size * 0.5, 0.35 + 0.04 * r.perfect_cancels)
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(_merged, "impact", 0.0, IMPACT_SECONDS)
	tw2.tween_property(_merged, "reveal", 1.0, IMPACT_SECONDS)
	tw2.tween_property(_merged, "merge", 1.0, 0.4)
	await tw2.finished

	# 3. Residual waves fly from the readout to their targets.
	var target_fig: FigureView = _enemy_views[report.target]["figure"]
	var delay := 0.0
	for t in r.damage.size():
		var dmg := r.damage[t]
		if dmg <= 0:
			continue
		var to_enemy := r.outcome[t] != TrackResult.Outcome.PLAYER_HIT
		var from := _merged.cell_global(t, to_enemy)
		var to := target_fig.center_global() if to_enemy else _player_figure.center_global()
		var col := Assets.color("damage_to_enemy") if to_enemy else Assets.color("damage_to_player")
		_fx.shoot(from, to, col, delay, SHOT_SECONDS, 5.0 + dmg * 0.8)
		delay += 0.03
	await get_tree().create_timer(SHOT_SECONDS + delay).timeout

	if r.to_enemy > 0:
		target_fig.hit(r.to_enemy)
		_fx.float_text(target_fig.center_global(), "-%d" % r.to_enemy, Assets.color("damage_to_enemy"))
	if r.to_player > 0:
		_player_figure.hit(r.to_player)
		_fx.float_text(_player_figure.center_global(), "-%d" % r.to_player, Assets.color("damage_to_player"))
		app.impact(_player_figure.center_global(), clampf(0.2 + r.to_player * 0.03, 0.2, 0.6))
	_player_hp.set_values(combat.player_hp, combat.player_max_hp, 0)
	_update_enemy_panels(0)
	await get_tree().create_timer(0.45).timeout

	# 4. Reset for the next turn.
	_enemy_scope.screen.launch = 0.0
	_player_scope.screen.launch = 0.0
	if report.swapped:
		_layout_enemies(true)
	var msgs := PackedStringArray()
	if r.perfect_cancels > 0:
		msgs.append("完美抵消 ×%d" % r.perfect_cancels)
	if report.killed and combat.outcome == Combat.Outcome.ONGOING:
		msgs.append("%s 被击破" % report.target.data.name)
	if report.swapped:
		msgs.append("双子交换位置！")
	if not msgs.is_empty():
		_show_toast("  ·  ".join(msgs))
	_animating = false
	refresh()
	if combat.outcome != Combat.Outcome.ONGOING:
		_show_overlay()


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.6)


func _show_overlay() -> void:
	if _hint != null:
		_hint.queue_free()
		_hint = null
	var won := combat.outcome == Combat.Outcome.WON
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var panel := Panel.new()
	panel.size = Vector2(720, 360)
	panel.position = (size - panel.size) * 0.5
	_overlay.add_child(panel)
	var title := Label.new()
	title.text = "信号清除 · 胜利" if won else "信号丢失 · 失败"
	title.add_theme_font_size_override("font_size", Assets.fs(52))
	title.add_theme_color_override("font_color", Assets.color("damage_to_enemy") if won else Assets.color("damage_to_player"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 50)
	title.size = Vector2(panel.size.x, 70)
	panel.add_child(title)
	var sub := Label.new()
	sub.text = "%s · %d 回合 · 剩余 HP %d/%d" % [encounter.name, combat.turn, combat.player_hp, combat.player_max_hp]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 140)
	sub.size = Vector2(panel.size.x, 40)
	panel.add_child(sub)
	if run != null:
		_add_overlay_button(panel, "继续", Vector2(230, 240), func() -> void: app.finish_run_fight(combat))
	else:
		_add_overlay_button(panel, "再战（新种子）", Vector2(80, 240), func() -> void: app.start_combat(encounter.id, randi()))
		_add_overlay_button(panel, "返回菜单", Vector2(380, 240), func() -> void: app.show_menu())


func _add_overlay_button(panel: Control, text: String, pos: Vector2, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(260, 64)
	b.pressed.connect(cb)
	panel.add_child(b)


# --- Demo (screenshots) ----------------------------------------------------

## Commits the demo's mid-drag card and resolves (for animation screenshots).
func demo_resolve() -> void:
	if _drag_card != null:
		combat.play(_drag_card, _drag_offset, _drag_flipped)
		_drag_card = null
	refresh()
	_resolve()


## Places two cards greedily and leaves a third mid-drag, so a screenshot shows
## every layer of the preview.
func _demo_setup() -> void:
	for step in 3:
		var best: PlayedCard = null
		var best_score := -INF
		for card in combat.deck.hand:
			if not combat.can_play(card) or not card.data.is_wave_card():
				continue
			for off in range(0, combat.rules.track_length - card.data.wave.size() + 1):
				var pc := PlayedCard.new(card, off, false)
				var res := combat.preview(pc)
				var score := res.to_enemy - res.to_player * 1.5
				if score > best_score:
					best_score = score
					best = pc
		if best == null:
			return
		if step < 2:
			combat.play(best.card, best.offset)
		else:
			_drag_card = best.card
			_drag_offset = best.offset
			_drag_over = true
