extends Control
## Combat screen. Owns no rules: every number shown comes from Combat.preview()
## or Combat.resolve_turn().
##
## Layout (top to bottom): enemy figures/HP, enemy scope, collision strip,
## player scope, then player figure / hand / resolve. The three wave bands share
## the same cell columns so a card's cells line up with the enemy's.
##
## Controls: drag a card onto the scopes; right-click / R flips flippable cards;
## drag a placed wave off the scopes to take it back; Enter/Space resolves.

const LAUNCH_SECONDS := 0.45
const IMPACT_SECONDS := 0.5
const SHOT_SECONDS := 0.5

var app: Node
var combat: Combat
var encounter: EncounterData
var seed_value := 0
var demo := false
## Set when this fight is part of a run (null for single-fight testing).
var run: RunState
var tutorial_enabled := true

var _enemy_scope: ScopeView
var _player_scope: ScopeView
var _strip: CollisionStrip
var _fx: FxLayer
var _hand_root: Control
var _card_views: Array[CardView] = []
var _player_figure: FigureView
var _player_hp: HpBar
## EnemyState -> {"figure": FigureView, "panel": EnemyPanel}
var _enemy_views := {}
var _to_enemy_label: Label
var _to_player_label: Label
var _energy_label: Label
var _pile_label: Label
var _hint_label: Label
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
	bg.color = Assets.color("background")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_enemy_scope = _make_scope(1.0)
	_strip = CollisionStrip.new()
	_strip.track_length = combat.rules.track_length
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_strip)
	_player_scope = _make_scope(-1.0)

	for e in combat.enemies:
		var fig := FigureView.new()
		fig.shape = e.data.figure_shape
		fig.color = Assets.color(e.data.color_id)
		fig.texture = Assets.texture(e.data.texture_id) if e.data.texture_id != "" else null
		fig.size = Vector2(160, 160)
		add_child(fig)
		var panel := EnemyPanel.new()
		panel.size = Vector2(420, 118)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(panel)
		_enemy_views[e] = {"figure": fig, "panel": panel}

	_player_figure = FigureView.new()
	_player_figure.shape = "player"
	_player_figure.color = Assets.color("player_wave")
	_player_figure.texture = Assets.texture("player")
	_player_figure.size = Vector2(190, 170)
	add_child(_player_figure)

	_player_hp = HpBar.new()
	_player_hp.label = "HP"
	_player_hp.color = Assets.color("player_wave")
	_player_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_player_hp)

	_to_enemy_label = _make_label(30, Assets.color("damage_to_enemy"))
	_to_player_label = _make_label(30, Assets.color("damage_to_player"))
	_energy_label = _make_label(26, Assets.color("energy"))
	_pile_label = _make_label(16, Assets.color("text_dim"))
	_hint_label = _make_label(16, Assets.color("text_dim"))
	_hint_label.text = "拖动卡牌到示波器 · 右键/R 反相 · 把已放置的波拖出示波器可撤回 · Enter 结算 · F2 切换 CRT"

	_resolve_btn = Button.new()
	_resolve_btn.text = "结算  ⏎"
	_resolve_btn.add_theme_font_size_override("font_size", 30)
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


func _make_scope(dir: float) -> ScopeView:
	var s := ScopeView.new()
	s.track_length = combat.rules.track_length
	s.launch_dir = dir
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(s)
	return s


func _make_label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


# --- Layout ----------------------------------------------------------------

func _layout() -> void:
	var w := size.x
	var h := size.y
	var side := 60.0
	var scope_w := w - side * 2
	_enemy_scope.position = Vector2(side, 190)
	_enemy_scope.size = Vector2(scope_w, 212)
	_strip.position = Vector2(side, 404)
	_strip.size = Vector2(scope_w, 96)
	_player_scope.position = Vector2(side, 502)
	_player_scope.size = Vector2(scope_w, 212)

	_layout_enemies(false)

	var bottom := 728.0
	_player_figure.position = Vector2(56, bottom + 4)
	_player_hp.position = Vector2(40, bottom + 182)
	_player_hp.size = Vector2(270, 52)
	_energy_label.position = Vector2(40, bottom + 244)
	_hand_root.position = Vector2(0, h - CardView.CARD_SIZE.y - 40)
	_hand_root.size = Vector2(w, CardView.CARD_SIZE.y)
	_to_enemy_label.position = Vector2(w - 330, bottom + 12)
	_to_player_label.position = Vector2(w - 330, bottom + 56)
	_resolve_btn.position = Vector2(w - 300, bottom + 120)
	_resolve_btn.size = Vector2(240, 72)
	_menu_btn.position = Vector2(w - 160, h - 64)
	_pile_label.position = Vector2(w - 640, h - 30)
	_hint_label.position = Vector2(330, h - 30)
	_toast.position = Vector2(0, _strip.position.y + 20)
	_toast.size = Vector2(w, 60)
	_layout_hand()


## Front enemy takes the first slot; with `animate` the figures glide (swap).
func _layout_enemies(animate: bool) -> void:
	var n := combat.enemies.size()
	var group_w := 600.0
	var gap := 80.0
	var total := n * group_w + (n - 1) * gap
	var tw: Tween = create_tween().set_parallel(true) if animate else null
	for i in n:
		var e := combat.enemies[i]
		var v: Dictionary = _enemy_views[e]
		var x := (size.x - total) * 0.5 + i * (group_w + gap)
		var fig_pos := Vector2(x, 14)
		var panel_pos := Vector2(x + 175, 26)
		if tw != null:
			tw.tween_property(v["figure"], "position", fig_pos, 0.5).set_trans(Tween.TRANS_BACK)
			tw.tween_property(v["panel"], "position", panel_pos, 0.5).set_trans(Tween.TRANS_BACK)
		else:
			v["figure"].position = fig_pos
			v["panel"].position = panel_pos


func _layout_hand() -> void:
	var gap := 14.0
	var total := _card_views.size() * CardView.CARD_SIZE.x + maxf(0, _card_views.size() - 1) * gap
	var x := (size.x - total) * 0.5
	for v in _card_views:
		v.position = Vector2(x, 0)
		x += CardView.CARD_SIZE.x + gap


## Rect (screen-local) of a named UI element, for tutorial highlighting.
func anchor_rect(anchor: String) -> Rect2:
	match anchor:
		"enemy_scope": return _enemy_scope.get_rect()
		"player_scope": return _player_scope.get_rect()
		"collision": return _strip.get_rect()
		"resolve": return _resolve_btn.get_rect()
		"player_figure": return _player_figure.get_rect().merge(_player_hp.get_rect())
		"energy": return _energy_label.get_rect()
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

	# Shared vertical scale for both scopes.
	var amp := 10.0
	for v in enemy_track:
		amp = maxf(amp, absf(v))
	for v in result.player:
		amp = maxf(amp, absf(v))
	_enemy_scope.amp_scale = amp
	_player_scope.amp_scale = amp

	var echans: Array = []
	var legend: Array = []
	var alive := combat.alive_enemies()
	for i in alive.size():
		var e := alive[i]
		var col := Assets.color(e.data.color_id)
		echans.append({"track": e.intent, "color": col, "width": 2.6})
		legend.append(["CH%d %s" % [1 if i == 0 else 3, e.data.name], col])
	if alive.size() > 1:
		echans.append({"track": enemy_track, "color": Color(Assets.color("net_wave"), 0.5), "width": 1.6, "dashed": true})
		legend.append(["Σ 合成", Color(Assets.color("net_wave"), 0.6)])
	_enemy_scope.channels = echans
	_enemy_scope.legend = legend
	_enemy_scope.info = "T%02d   敌方信号" % combat.turn
	_enemy_scope.tint_track = enemy_track
	_enemy_scope.tint_color = Assets.color("enemy_ch1")

	var pchans: Array = []
	# Dashed guide: the wave that would cancel the enemy exactly.
	pchans.append({"track": WaveMath.invert(enemy_track), "color": Color(Assets.color("player_wave"), 0.3), "width": 1.4, "dashed": true})
	var count := 0
	for p in combat.played:
		pchans.append_array(_wave_entries(p, p.card == _hover_card))
		count += 1
	if extra != null:
		pchans.append_array(_wave_entries(extra, true))
		count += 1
	if count > 1:
		pchans.append({"track": result.player, "color": Assets.color("player_wave"), "width": 3.4})
	_player_scope.channels = pchans
	_player_scope.legend = [["CH2 玩家", Assets.color("player_wave")], ["- - 完美抵消", Color(Assets.color("player_wave"), 0.5)]]
	_player_scope.info = "我方信号"
	_player_scope.tint_track = enemy_track
	_player_scope.tint_color = Assets.color("enemy_ch1")

	_strip.result = result
	_strip.reveal = 1.0
	for s in [_enemy_scope, _player_scope, _strip]:
		s.highlight_cell = _hover_cell

	_player_hp.set_values(combat.player_hp, combat.player_max_hp, result.to_player)
	_update_enemy_panels(result.to_enemy)
	_to_enemy_label.text = "预计对敌  %d" % result.to_enemy
	_to_player_label.text = "预计受到  %d" % result.to_player
	_energy_label.text = "能量 %s %d/%d" % ["◆".repeat(combat.energy) + "◇".repeat(maxi(0, combat.rules.energy_per_turn - combat.energy)), combat.energy, combat.rules.energy_per_turn]
	var where := encounter.name
	if run != null:
		where = "第 %d/%d 战 · %s" % [run.index + 1, run.encounter_ids.size(), encounter.name]
	_pile_label.text = "抽牌堆 %d  弃牌堆 %d  ·  %s  ·  种子 %d" % [combat.deck.draw_pile.size(), combat.deck.discard_pile.size(), where, seed_value]
	_resolve_btn.disabled = _animating or combat.outcome != Combat.Outcome.ONGOING
	_update_tutorial(result)


func _wave_entries(p: PlayedCard, emphasis: bool) -> Array:
	var out: Array = []
	var col := Assets.color("player_wave")
	for pl in p.placements():
		var track := WaveMath.place(pl.wave, pl.offset, combat.rules.track_length, combat.rules.offtrack_mode)
		out.append({"track": track, "color": col if emphasis else Color(col, 0.7), "width": 3.0 if emphasis else 2.0,
			"from": pl.offset - 1, "to": pl.offset + pl.wave.size()})
	return out


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


## The enemy scope, strip and player scope together form the drop area.
func _over_scopes(mouse: Vector2) -> bool:
	var r := _enemy_scope.get_global_rect().merge(_player_scope.get_global_rect())
	return r.grow(10).has_point(mouse)


func _cell_at(mouse: Vector2) -> int:
	return _player_scope.cell_at(mouse - _player_scope.global_position)


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

	# 1. Both scopes fire their waves toward the collision strip.
	_strip.result = r
	_strip.reveal = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_enemy_scope, "launch", 1.0, LAUNCH_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_player_scope, "launch", 1.0, LAUNCH_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished

	# 2. Impact: flash, sparks where waves cancelled, CRT glitch burst.
	_strip.burst()
	_strip.reveal = 1.0
	app.glitch(0.45 + 0.03 * r.perfect_cancels)
	var tw2 := create_tween()
	tw2.tween_property(_strip, "impact", 0.0, IMPACT_SECONDS)
	await get_tree().create_timer(0.25).timeout

	# 3. Residual waves fly to their targets.
	var target_fig: FigureView = _enemy_views[report.target]["figure"]
	var delay := 0.0
	for t in r.damage.size():
		var dmg := r.damage[t]
		if dmg <= 0:
			continue
		var to_enemy := r.outcome[t] != TrackResult.Outcome.PLAYER_HIT
		var from := _strip.cell_global(t, to_enemy)
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
		app.glitch(clampf(0.3 + r.to_player * 0.05, 0.3, 0.9))
	_player_hp.set_values(combat.player_hp, combat.player_max_hp, 0)
	_update_enemy_panels(0)
	await get_tree().create_timer(0.45).timeout

	# 4. Reset for the next turn.
	_enemy_scope.launch = 0.0
	_player_scope.launch = 0.0
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
	title.add_theme_font_size_override("font_size", 52)
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
