extends Control
## Combat screen. Owns no rules: every number shown comes from Combat.preview()
## or Combat.resolve_turn().
##
## Layout follows docs/art_direction.md §4.1 — items standing on an oblique desk:
##   top:    receiver (observation ports with the enemy, enemy signal screen)
##   middle: counter box | main oscilloscope | line-integrity box
##   bottom: transmitter (power lamps, your signal screen, fire key)
##   beyond the desk's front edge: the hand of punch cards (small; click to
##   enlarge), the draw pile on the left and the discard pile on the right.
## All three wave screens share the same cell columns; spacing uses the
## InstrumentStyle size tokens.
##
## Controls: drag a card onto the scopes; right-click / R flips flippable cards;
## drag a placed wave off the scopes to take it back; Enter/Space resolves.

const LAUNCH_SECONDS := 0.45
const IMPACT_SECONDS := 0.6
const SHOT_SECONDS := 0.5
## Width of the side boxes beside the main scope (counter / integrity).
const SIDE_W := 256.0
## Desk visible around the instruments (sides / top).
const MARGIN := 72.0
const MARGIN_TOP := 56.0
## Oblique view: the far (top) instrument's case is inset on both sides so the
## rows read as standing at different depths on the desk. Screens keep their
## shared columns; only the cases narrow.
const DEPTH_INSET := 40.0
## Hand cards are held small below the desk edge; the clicked card is shown
## enlarged on the desk.
const HAND_SCALE := 0.72
const EXPANDED_SCALE := 1.75
## Grid inset inside the main scope (name plate on the left, knobs on the right).
const GRID_INSET_L := 150.0
const GRID_INSET_R := 110.0

var app: Node
var combat: Combat
var encounter: EncounterData
var seed_value := 0
var demo := false
## Set when this fight is part of a run (null for single-fight testing).
var run: RunState
var tutorial_enabled := true

var _receiver: InstrumentCase
var _transmitter: InstrumentCase
var _counter_box: InstrumentCase
var _integrity: InstrumentCase
var _enemy_screen: ScopeScreen
var _player_screen: ScopeScreen
var _merged: MergedView
var _fx: FxLayer
var _hand_root: Control
var _card_views: Array[CardView] = []
var _player_hp: HpBar
## EnemyState -> {"figure": FigureView, "panel": EnemyPanel}
var _enemy_views := {}
var _to_enemy_label: Label
var _to_player_label: Label
var _turn_label: Label
var _energy: EnergyView
var _draw_pile: PileIcon
var _discard_pile: PileIcon
var _arrows: Array[ArrowIcon] = []
## Card uids that were in hand at the last rebuild (new ones fly in from the pile).
var _known_hand := {}
var _last_draw_count := -1
## Receiver area left of its screen, in screen coordinates (enemy ports).
var _enemy_area := Rect2()
## Y of the desk's front edge (the hand is held below it).
var _edge_y := 0.0
## Card shown enlarged on the desk after a click (null when none).
var _expanded: CardView
## A card pressed but not yet dragged: release = click (enlarge), move = drag.
var _press_card: CardInstance
var _press_pos := Vector2.ZERO
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
	_receiver = InstrumentCase.new()
	add_child(_receiver)
	_transmitter = InstrumentCase.new()
	add_child(_transmitter)
	_counter_box = InstrumentCase.new()
	add_child(_counter_box)
	_integrity = InstrumentCase.new()
	add_child(_integrity)
	_enemy_screen = _make_screen(1.0)
	_player_screen = _make_screen(-1.0)

	_merged = MergedView.new()
	_merged.track_length = combat.rules.track_length
	_merged.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_merged)

	for e in combat.enemies:
		var fig := FigureView.new()
		fig.shape = e.data.figure_shape
		fig.color = Assets.color(e.data.color_id)
		fig.texture = Assets.texture(e.data.texture_id) if e.data.texture_id != "" else null
		add_child(fig)
		var panel := EnemyPanel.new()
		add_child(panel)
		_enemy_views[e] = {"figure": fig, "panel": panel}

	_player_hp = HpBar.new()
	_player_hp.label = ""
	_player_hp.color = Assets.color("player_wave")
	_player_hp.font_size = 54
	_player_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_player_hp)

	_to_enemy_label = _make_label(52, Assets.color("damage_to_enemy"))
	_to_player_label = _make_label(52, Assets.color("damage_to_player"))
	_turn_label = _make_label(20, Assets.color("case_print"))
	for up in [true, false]:
		var arrow := ArrowIcon.new()
		arrow.up = up
		arrow.color = Assets.color("damage_to_enemy") if up else Assets.color("damage_to_player")
		arrow.tooltip_text = "预计对杂波造成的伤害" if up else "预计你受到的伤害"
		arrow.size = Vector2(48, 52)
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
	_resolve_btn.text = "发射"
	_resolve_btn.add_theme_font_size_override("font_size", Assets.fs(30))
	ThemeFactory.style_fire_key(_resolve_btn)
	_resolve_btn.pressed.connect(_resolve)
	add_child(_resolve_btn)

	_menu_btn = Button.new()
	_menu_btn.text = "菜单"
	_menu_btn.add_theme_font_size_override("font_size", Assets.fs(18))
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


func _make_screen(dir: float) -> ScopeScreen:
	var sc := ScopeScreen.new()
	sc.track_length = combat.rules.track_length
	sc.launch_dir = dir
	sc.bg_color = Color(0, 0, 0, 0)
	sc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Launched traces must not spill out of the window.
	sc.clip_contents = true
	add_child(sc)
	return sc


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
	var G := InstrumentStyle.GAP
	var IN := InstrumentStyle.WINDOW_INSET
	_edge_y = h - float(Assets.DESK["edge_from_bottom"])
	var avail := _edge_y - MARGIN_TOP - G
	var row_h := maxf(160.0, avail * 0.21)
	var mid_h := avail - row_h * 2 - G * 2
	var e0 := MARGIN_TOP
	var m0 := e0 + row_h + G
	var p0 := m0 + mid_h + G
	var x0 := MARGIN
	var x1 := w - MARGIN

	# Main oscilloscope between the two side boxes; its grid defines the columns.
	var main_x := x0 + SIDE_W + G
	var main_w := x1 - SIDE_W - G - main_x
	_merged.position = Vector2(main_x, m0)
	_merged.size = Vector2(main_w, mid_h)
	_merged.grid_x0 = GRID_INSET_L
	_merged.grid_x1 = main_w - GRID_INSET_R
	_merged.layout_parts()
	var gx0 := main_x + GRID_INSET_L
	var gx1 := main_x + main_w - GRID_INSET_R
	var sx0 := gx0 - OscilloscopeView.TUBE_MARGIN
	var sx1 := gx1 + OscilloscopeView.TUBE_MARGIN

	# Receiver (top) and transmitter (bottom) share the outer edges x0..x1;
	# their screens line up with the main tube.
	for row in [[_receiver, _enemy_screen, e0, DEPTH_INSET], [_transmitter, _player_screen, p0, 0.0]]:
		var case: InstrumentCase = row[0]
		var screen: ScopeScreen = row[1]
		var inset: float = row[3]
		case.position = Vector2(x0 + inset, row[2])
		case.size = Vector2(x1 - x0 - inset * 2, row_h)
		var win := Rect2(sx0 - case.position.x, IN, sx1 - sx0, row_h - IN * 2)
		case.windows = [win]
		screen.position = case.position + win.position
		screen.size = win.size
		screen.grid_x0 = gx0 - screen.position.x
		screen.grid_w = gx1 - gx0
	var right_x := sx1 + G + 6.0
	var right_w := x1 - IN - right_x
	var rx_right_w := right_w - DEPTH_INSET

	# Receiver: observation ports on the left, status print + menu on the right.
	var rx0 := x0 + DEPTH_INSET
	_enemy_area = Rect2(rx0 + IN, e0 + IN * 0.5, sx0 - rx0 - IN - G - 6.0, row_h - IN)
	_receiver.labels = [{"pos": Vector2(right_x - rx0, InstrumentStyle.TITLE_BASELINE), "text": "接收机", "size": 20, "width": rx_right_w, "align": HORIZONTAL_ALIGNMENT_CENTER}]
	_turn_label.position = Vector2(right_x, e0 + InstrumentStyle.TITLE_BASELINE + 8)
	_turn_label.size = Vector2(rx_right_w, 60)
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_btn.position = Vector2(right_x, e0 + row_h - IN - 44)
	_menu_btn.size = Vector2(rx_right_w, 44)
	_layout_enemies(false)

	# Transmitter: power lamps on the left, fire key on the right.
	var left_w := sx0 - x0 - IN - G - 6.0
	_transmitter.labels = [{"pos": Vector2(IN, InstrumentStyle.TITLE_BASELINE), "text": "发射功率", "size": 20, "width": left_w, "align": HORIZONTAL_ALIGNMENT_CENTER}]
	_energy.position = Vector2(x0 + IN, p0 + InstrumentStyle.TITLE_BASELINE + 12)
	_energy.size = Vector2(left_w, row_h - InstrumentStyle.TITLE_BASELINE - 12 - IN)
	_resolve_btn.position = Vector2(right_x, p0 + IN)
	_resolve_btn.size = Vector2(right_w, row_h - IN * 2)

	# Counter box (left) and line-integrity box (right), aligned to x0 / x1.
	var box_win := Rect2(IN, InstrumentStyle.TITLE_BASELINE + 16, SIDE_W - IN * 2, mid_h - InstrumentStyle.TITLE_BASELINE - 16 - IN)
	for box in [[_counter_box, x0, "预计"], [_integrity, x1 - SIDE_W, "线路完整度"]]:
		var c: InstrumentCase = box[0]
		c.position = Vector2(box[1], m0)
		c.size = Vector2(SIDE_W, mid_h)
		c.windows = [box_win]
		c.labels = [{"pos": Vector2(0, InstrumentStyle.TITLE_BASELINE), "text": box[2], "size": 20, "width": SIDE_W, "align": HORIZONTAL_ALIGNMENT_CENTER}]
	var row1 := m0 + box_win.position.y + box_win.size.y * 0.3
	var row2 := m0 + box_win.position.y + box_win.size.y * 0.72
	_arrows[0].position = Vector2(x0 + IN + 16, row1 - 26)
	_arrows[1].position = Vector2(x0 + IN + 16, row2 - 26)
	_to_enemy_label.position = Vector2(x0 + IN + 76, row1 - Assets.fs(52) * 0.7)
	_to_player_label.position = Vector2(x0 + IN + 76, row2 - Assets.fs(52) * 0.7)
	var hp_h := minf(box_win.size.y - 24.0, Assets.fs(54) * 2.6)
	_player_hp.position = _integrity.position + box_win.position + Vector2(16, (box_win.size.y - hp_h) * 0.5)
	_player_hp.size = Vector2(box_win.size.x - 32, hp_h)
	for b in [_counter_box, _integrity, _receiver, _transmitter]:
		b.queue_redraw()

	# Beyond the desk edge: draw pile (left), hand (centre), discard (right).
	var pile_h := minf(140.0, h - _edge_y + 30.0)
	_draw_pile.position = Vector2(x0 + 8, h - pile_h - 12)
	_draw_pile.size = Vector2(120, pile_h)
	_discard_pile.position = Vector2(x1 - 128, h - pile_h - 12)
	_discard_pile.size = Vector2(120, pile_h)
	_hand_root.position = Vector2.ZERO
	_hand_root.size = size
	_toast.position = Vector2(main_x, m0 + 60)
	_toast.size = Vector2(main_w, 60)
	_layout_hand()


## Enemy observation ports in the receiver, left of its screen. The twins get
## two ports stacked vertically (front on top); with `animate` the figures
## glide between ports when they swap.
func _layout_enemies(animate: bool) -> void:
	var n := combat.enemies.size()
	var area := _enemy_area
	var ports: Array = []
	var tw: Tween = create_tween().set_parallel(true) if animate else null
	for i in n:
		var e := combat.enemies[i]
		var v: Dictionary = _enemy_views[e]
		var slot_h := area.size.y / n
		var rad := minf(slot_h * 0.5 - 8.0, 66.0)
		var c := Vector2(area.position.x + rad + 10.0, area.position.y + slot_h * (i + 0.5))
		ports.append({"center": c - _receiver.position, "radius": rad, "glow": Assets.color(e.data.color_id)})
		var fig_rect := Rect2(c - Vector2(rad, rad) * 0.85, Vector2(rad, rad) * 1.7)
		var px := c.x + rad + InstrumentStyle.GAP + 4.0
		var panel_rect := Rect2(px, area.position.y + slot_h * i + 4.0, area.end.x - px, slot_h - 8.0)
		v["figure"].size = fig_rect.size
		v["panel"].size = panel_rect.size
		if tw != null:
			tw.tween_property(v["figure"], "position", fig_rect.position, 0.5).set_trans(Tween.TRANS_BACK)
			tw.tween_property(v["panel"], "position", panel_rect.position, 0.5).set_trans(Tween.TRANS_BACK)
		else:
			v["figure"].position = fig_rect.position
			v["panel"].position = panel_rect.position
	_receiver.ports = ports
	_receiver.queue_redraw()


## Hand cards are held small below the desk edge, bottoms aligned.
func _layout_hand() -> void:
	var gap := 10.0
	var cw := CardView.CARD_SIZE.x * HAND_SCALE
	var total := _card_views.size() * cw + maxf(0, _card_views.size() - 1) * gap
	var cx := (size.x - total) * 0.5 + cw * 0.5
	for v in _card_views:
		v.base_scale = HAND_SCALE
		v.position = Vector2(cx - CardView.CARD_SIZE.x * 0.5, size.y - 10.0 - CardView.CARD_SIZE.y)
		cx += cw + gap


## Rect (screen-local) of a named UI element, for tutorial highlighting.
func anchor_rect(anchor: String) -> Rect2:
	match anchor:
		"enemy_scope": return _receiver.get_rect()
		"player_scope": return _transmitter.get_rect()
		"collision": return _merged.get_rect()
		"resolve": return _resolve_btn.get_rect()
		"player_figure": return _integrity.get_rect()
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
	if _expanded != null and not _expanded.card in combat.deck.hand:
		_close_expanded()
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
	_animate_draws()


## Cards that just entered the hand fly in from the draw pile, staggered.
## A reshuffle (draw pile grew) first streams card backs discard -> draw.
func _animate_draws() -> void:
	var draw_count := combat.deck.draw_pile.size()
	var delay := 0.0
	if _last_draw_count >= 0 and draw_count > _last_draw_count:
		for i in 6:
			_fx.shoot(_discard_pile.get_global_rect().get_center(), _draw_pile.get_global_rect().get_center(),
				Assets.color("text_dim"), i * 0.04, 0.35, 7.0)
		delay = 0.3
	_last_draw_count = draw_count
	var from := _draw_pile.get_global_rect().get_center() - _hand_root.global_position - CardView.CARD_SIZE * 0.5
	var known := {}
	for v in _card_views:
		known[v.card.uid] = true
		if _known_hand.has(v.card.uid):
			continue
		var target := v.position
		v.position = from
		v.scale = Vector2(0.3, 0.3)
		v.rotation = -0.4
		create_tween().tween_property(v, "position", target, 0.35).set_delay(delay) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		delay += 0.07
	_known_hand = known


## End of turn: remaining hand and the played cards fly into the discard pile.
func _animate_discards(played: Array[PlayedCard]) -> void:
	var to := _discard_pile.get_global_rect().get_center() - CardView.CARD_SIZE * 0.5
	var flying: Array[CardView] = []
	for v in _card_views:
		var gp := v.global_position
		_hand_root.remove_child(v)
		add_child(v)
		v.global_position = gp
		flying.append(v)
	_card_views.clear()
	for p in played:
		var v := CardView.new(p.card)
		v.ghost = true
		add_child(v)
		var x := _merged.global_position.x + _merged.cell_center_x(p.offset + p.card.data.wave.size() * 0.5)
		v.global_position = Vector2(x, _merged.global_position.y + _merged.size.y * 0.4) - CardView.CARD_SIZE * 0.5
		v.scale = Vector2(0.5, 0.5)
		flying.append(v)
	var delay := 0.0
	for v in flying:
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.ghost = true
		var tw := create_tween().set_parallel(true)
		tw.tween_property(v, "global_position", to, 0.35).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(v, "modulate:a", 0.0, 0.2).set_delay(delay + 0.2)
		tw.chain().tween_callback(v.queue_free)
		delay += 0.05
	_known_hand = {}


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
	var es := _enemy_screen
	var ps := _player_screen
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
	_turn_label.text = "第 %d 回合" % combat.turn
	if combat.swap_in() > 0:
		_turn_label.text += "\n%d 回合后交换" % combat.swap_in()
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

## Press on a card: it becomes a drag once the mouse moves, or a click
## (enlarge / shrink) if released in place.
func _on_card_grabbed(view: CardView) -> void:
	if _animating or _drag_card != null:
		return
	_press_card = view.card
	_press_pos = get_global_mouse_position()


func _toggle_expanded(card: CardInstance) -> void:
	var same := _expanded != null and _expanded.card == card
	_close_expanded()
	if same:
		return
	_expanded = CardView.new(card)
	_expanded.base_scale = EXPANDED_SCALE
	_expanded.scale = Vector2.ONE * HAND_SCALE
	_expanded.playable = combat.can_play(card)
	_expanded.grabbed.connect(_on_card_grabbed)
	add_child(_expanded)
	# Shown on the desk, just above the edge, centred.
	_expanded.position = Vector2(size.x * 0.5 - CardView.CARD_SIZE.x * 0.5, _edge_y - 6.0 - CardView.CARD_SIZE.y)


func _close_expanded() -> void:
	if _expanded != null:
		_expanded.queue_free()
		_expanded = null


func _point_on_cards(p: Vector2) -> bool:
	if _expanded != null and Rect2(_expanded.global_position + _expanded.pivot_offset * (Vector2.ONE - _expanded.scale), CardView.CARD_SIZE * _expanded.scale).has_point(p):
		return true
	for v in _card_views:
		if v.get_global_rect().has_point(p):
			return true
	return false


func _start_drag(card: CardInstance, grab: int, flipped: bool) -> void:
	_close_expanded()
	_drag_card = card
	_drag_grab = grab
	_drag_flipped = flipped
	_drag_over = false
	_drag_ghost = CardView.new(card)
	_drag_ghost.ghost = true
	_drag_ghost.flipped = flipped
	_drag_ghost.modulate.a = 0.85
	_drag_ghost.base_scale = HAND_SCALE
	add_child(_drag_ghost)
	_update_drag(get_global_mouse_position())
	refresh()


## Both bench scopes and the merged panel together form the drop area.
func _over_scopes(mouse: Vector2) -> bool:
	var r := _enemy_screen.get_global_rect().merge(_player_screen.get_global_rect())
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
		elif get_global_mouse_position().y < _edge_y - 20:
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
		if _press_card != null and event.position.distance_to(_press_pos) > 10.0:
			var card := _press_card
			_press_card = null
			if combat.can_play(card) and not _animating:
				_start_drag(card, card.data.wave.size() / 2, false)
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
			if _expanded != null and not _point_on_cards(event.position):
				_close_expanded()
			var p := _placed_card_at(event.position)
			if p != null and combat.can_unplay(p.card):
				var grab := _cell_at(event.position) - p.offset
				var flipped := p.flipped
				combat.unplay(p.card)
				_start_drag(p.card, grab, flipped)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _press_card != null:
			# Released without moving: a click enlarges (or shrinks) the card.
			var card := _press_card
			_press_card = null
			_toggle_expanded(card)
		elif _drag_card != null:
			_end_drag(true)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				_toggle_drag_flip()
			KEY_ESCAPE:
				if _drag_card != null:
					_end_drag(false)
				_close_expanded()
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
	var played_before: Array[PlayedCard] = combat.played.duplicate()
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
	tw.tween_property(_enemy_screen, "launch", 1.0, LAUNCH_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_player_screen, "launch", 1.0, LAUNCH_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
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
		var to := target_fig.center_global() if to_enemy else _integrity.get_global_rect().get_center()
		var col := Assets.color("damage_to_enemy") if to_enemy else Assets.color("damage_to_player")
		_fx.shoot(from, to, col, delay, SHOT_SECONDS, 5.0 + dmg * 0.8)
		delay += 0.03
	await get_tree().create_timer(SHOT_SECONDS + delay).timeout

	if r.to_enemy > 0:
		target_fig.hit(r.to_enemy)
		_fx.float_text(target_fig.center_global(), "-%d" % r.to_enemy, Assets.color("damage_to_enemy"))
	if r.to_player > 0:
		_integrity.flash()
		_fx.float_text(_integrity.get_global_rect().get_center(), "-%d" % r.to_player, Assets.color("damage_to_player"))
		app.impact(_integrity.get_global_rect().get_center(), clampf(0.2 + r.to_player * 0.03, 0.2, 0.6))
	_player_hp.set_values(combat.player_hp, combat.player_max_hp, 0)
	_update_enemy_panels(0)
	await get_tree().create_timer(0.45).timeout

	# 4. Reset for the next turn.
	_enemy_screen.launch = 0.0
	_player_screen.launch = 0.0
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
	if combat.outcome == Combat.Outcome.ONGOING:
		_animate_discards(played_before)
		await get_tree().create_timer(0.45).timeout
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
