extends Control
## Combat screen. Owns no rules: every number shown comes from Combat.preview()
## or Combat.resolve_turn().
##
## Controls: drag a card onto the scope; right-click / R flips flippable cards;
## drag a placed wave off the scope to take it back; Enter/Space resolves.

const SWEEP_SECONDS := 1.1

var app: Node
var combat: Combat
var encounter: EncounterData
var seed_value := 0
var demo := false

var _scope: ScopeView
var _hand_root: Control
var _card_views: Array[CardView] = []
var _player_hp: HpBar
var _enemy_panels: Array[EnemyPanel] = []
var _to_enemy_label: Label
var _to_player_label: Label
var _energy_label: Label
var _pile_label: Label
var _hint_label: Label
var _resolve_btn: Button
var _menu_btn: Button
var _toast: Label
var _overlay: Control

# Drag state. Picking a placed wave back up unplays it, so every drag is a
# drag "from hand" and preview uses a hypothetical PlayedCard.
var _drag_card: CardInstance
var _drag_grab := 0
var _drag_flipped := false
var _drag_offset := 0
var _drag_over_scope := false
var _drag_ghost: CardView
var _hover_card: CardInstance
var _animating := false


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Assets.color("background")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_scope = ScopeView.new()
	_scope.track_length = combat.rules.track_length
	_scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scope)

	for i in combat.enemies.size():
		var p := EnemyPanel.new()
		p.size = Vector2(600, 118)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(p)
		_enemy_panels.append(p)

	_player_hp = HpBar.new()
	_player_hp.label = "玩家 HP"
	_player_hp.color = Assets.color("player_wave")
	_player_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_player_hp)

	_to_enemy_label = _make_label(34, Assets.color("damage_to_enemy"))
	_to_player_label = _make_label(34, Assets.color("damage_to_player"))
	_energy_label = _make_label(30, Assets.color("energy"))
	_pile_label = _make_label(18, Assets.color("text_dim"))
	_hint_label = _make_label(17, Assets.color("text_dim"))
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

	_toast = _make_label(44, Assets.color("net_wave"))
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0

	resized.connect(_layout)
	combat.start()
	_layout()
	if demo:
		_demo_setup()
	refresh()


func _make_label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _layout() -> void:
	var w := size.x
	var h := size.y
	var margin := 70.0
	var panel_w := 600.0
	var total := _enemy_panels.size() * panel_w + (_enemy_panels.size() - 1) * 40.0
	for i in _enemy_panels.size():
		_enemy_panels[i].position = Vector2((w - total) * 0.5 + i * (panel_w + 40.0), 18)
	_scope.position = Vector2(margin, 172)
	_scope.size = Vector2(w - margin * 2, h * 0.47)
	var info_y := _scope.position.y + _scope.size.y + 14
	_player_hp.position = Vector2(margin, info_y)
	_player_hp.size = Vector2(520, 56)
	_to_enemy_label.position = Vector2(w * 0.5 - 330, info_y + 8)
	_to_player_label.position = Vector2(w * 0.5 + 20, info_y + 8)
	_energy_label.position = Vector2(w - margin - 470, info_y + 10)
	_resolve_btn.position = Vector2(w - margin - 220, info_y + 2)
	_resolve_btn.size = Vector2(220, 62)
	_menu_btn.position = Vector2(w - margin - 96, h - 56)
	_pile_label.position = Vector2(margin, h - 50)
	_hint_label.position = Vector2(margin, h - 26)
	_hand_root.position = Vector2(0, h - CardView.CARD_SIZE.y - 60)
	_hand_root.size = Vector2(w, CardView.CARD_SIZE.y)
	_toast.position = Vector2(0, _scope.position.y + _scope.size.y * 0.35)
	_toast.size = Vector2(w, 60)
	_layout_hand()


func _layout_hand() -> void:
	var gap := 16.0
	var total := _card_views.size() * CardView.CARD_SIZE.x + maxf(0, _card_views.size() - 1) * gap
	var x := (size.x - total) * 0.5
	for v in _card_views:
		v.position = Vector2(x, 0)
		x += CardView.CARD_SIZE.x + gap


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
	if _drag_card == null or not _drag_over_scope or not _drag_card.data.is_wave_card():
		return null
	return PlayedCard.new(_drag_card, _drag_offset, _drag_flipped)


func _refresh_preview() -> void:
	if _animating:
		return
	var extra := _drag_played_card()
	var result := combat.preview(extra)
	_set_scope_channels()
	var waves: Array = []
	for p in combat.played:
		waves.append_array(_wave_entries(p, p.card == _hover_card))
	if extra != null:
		waves.append_array(_wave_entries(extra, true))
	_scope.player_waves = waves
	_scope.result = result
	_scope.turn = combat.turn
	_scope.queue_redraw()

	_player_hp.set_values(combat.player_hp, combat.player_max_hp, result.to_player)
	_update_enemy_panels(result.to_enemy)
	_to_enemy_label.text = "预计对敌  %d" % result.to_enemy
	_to_player_label.text = "预计受到  %d" % result.to_player
	_energy_label.text = "能量 %s %d/%d" % ["◆".repeat(combat.energy) + "◇".repeat(maxi(0, combat.rules.energy_per_turn - combat.energy)), combat.energy, combat.rules.energy_per_turn]
	_pile_label.text = "抽牌堆 %d   弃牌堆 %d   ·   %s   ·   种子 %d" % [combat.deck.draw_pile.size(), combat.deck.discard_pile.size(), encounter.name, seed_value]
	_resolve_btn.disabled = _animating or combat.outcome != Combat.Outcome.ONGOING


func _set_scope_channels() -> void:
	var channels: Array = []
	for e in combat.alive_enemies():
		channels.append({"track": e.intent, "color": Assets.color(e.data.color_id), "label": e.data.name})
	_scope.enemy_channels = channels


func _wave_entries(p: PlayedCard, emphasis: bool) -> Array:
	var out: Array = []
	for pl in p.placements():
		var track := WaveMath.place(pl.wave, pl.offset, combat.rules.track_length, combat.rules.offtrack_mode)
		out.append({"track": track, "start": pl.offset, "end": pl.offset + pl.wave.size(), "emphasis": emphasis})
	return out


func _update_enemy_panels(to_enemy: int) -> void:
	var front := combat.front_enemy()
	var multi := combat.enemies.size() > 1
	for i in _enemy_panels.size():
		var e := combat.enemies[i]
		_enemy_panels[i].update_view(e, e == front, multi, combat.swap_in(), to_enemy)


# --- Input -----------------------------------------------------------------

func _on_card_grabbed(view: CardView) -> void:
	if _animating or _drag_card != null or not combat.can_play(view.card):
		return
	_start_drag(view.card, view.card.data.wave.size() / 2, false)


func _start_drag(card: CardInstance, grab: int, flipped: bool) -> void:
	_drag_card = card
	_drag_grab = grab
	_drag_flipped = flipped
	_drag_over_scope = false
	_drag_ghost = CardView.new(card)
	_drag_ghost.ghost = true
	_drag_ghost.flipped = flipped
	_drag_ghost.modulate.a = 0.85
	add_child(_drag_ghost)
	_drag_ghost.global_position = get_global_mouse_position() - CardView.CARD_SIZE * 0.5
	_update_drag(get_global_mouse_position())
	refresh()


func _update_drag(mouse: Vector2) -> void:
	var local := mouse - _scope.global_position
	_drag_over_scope = _scope.accepts_drop(local)
	_drag_offset = _scope.cell_at(local) - _drag_grab
	if _drag_ghost != null:
		_drag_ghost.global_position = mouse - CardView.CARD_SIZE * 0.5
		# Over the scope the wave itself is the feedback; hide the card.
		_drag_ghost.visible = not (_drag_over_scope and _drag_card.data.is_wave_card())
	_refresh_preview()


func _end_drag(drop: bool) -> void:
	var card := _drag_card
	if drop and card != null:
		if card.data.is_wave_card():
			if _drag_over_scope:
				combat.play(card, _drag_offset, _drag_flipped)
		elif get_global_mouse_position().y < _hand_root.global_position.y - 20:
			combat.play(card)
	_drag_card = null
	if _drag_ghost != null:
		_drag_ghost.queue_free()
		_drag_ghost = null
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
	var local := mouse - _scope.global_position
	if not _scope.accepts_drop(local):
		return null
	var cell := _scope.cell_at(local)
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
		else:
			var p := _placed_card_at(event.position)
			var hovered := p.card if p != null else null
			if hovered != _hover_card:
				_hover_card = hovered
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
				var local: Vector2 = event.position - _scope.global_position
				var grab := _scope.cell_at(local) - p.offset
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
	var waves := _scope.player_waves.duplicate()
	for w in waves:
		w["emphasis"] = false
	var report := combat.resolve_turn()
	_animating = true
	# Freeze the scope on the resolved turn while the beam sweeps across.
	_scope.player_waves = waves
	_scope.result = report.result
	_resolve_btn.disabled = true
	for v in _card_views:
		v.playable = false
		v.queue_redraw()
	_scope.sweep = 0.0
	var tw := create_tween()
	tw.tween_property(_scope, "sweep", 1.0, SWEEP_SECONDS)
	await tw.finished
	_scope.sweep = -1.0
	_animating = false

	var msgs := PackedStringArray()
	if report.result.perfect_cancels > 0:
		msgs.append("完美抵消 ×%d" % report.result.perfect_cancels)
	if report.killed and combat.outcome == Combat.Outcome.ONGOING:
		msgs.append("%s 被击破" % report.target.data.name)
	if report.swapped:
		msgs.append("双子交换位置！")
	if not msgs.is_empty():
		_show_toast("  ·  ".join(msgs))
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
	var again := Button.new()
	again.text = "再战（新种子）"
	again.position = Vector2(80, 240)
	again.size = Vector2(260, 64)
	again.pressed.connect(func() -> void: app.start_combat(encounter.id, randi()))
	panel.add_child(again)
	var back := Button.new()
	back.text = "返回菜单"
	back.position = Vector2(380, 240)
	back.size = Vector2(260, 64)
	back.pressed.connect(func() -> void: app.show_menu())
	panel.add_child(back)


# --- Demo (screenshots) ----------------------------------------------------

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
				var r := combat.preview(pc)
				var score := r.to_enemy - r.to_player * 1.5
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
			_drag_over_scope = true
