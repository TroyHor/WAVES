extends Control
## Combat screen. Owns no rules: every number shown comes from Combat.preview()
## or Combat.resolve_turn().
##
## Layout follows docs/art_direction.md §4.1 — instruments on an oblique desk.
## Each instrument is a DeskDevice: its face is laid out flat and shown in
## perspective (input and effects are mapped through the same homography).
##   scope unit (upright, top wider): receiver row (enemy ports + amber
##     screen) above the main oscilloscope; "预计" counters in its left column
##   transmitter (L-shaped): an upright face (power bulbs, your cyan screen,
##     fire key) on a foot lying on the desk with one card slot per cell;
##     inserted cards stand in their slots (SlotCards); line-integrity meter
##     (upright) to its left, duty note to its right
##   beyond the desk edge: hand held as a fan, draw pile left, discard right
## Controls: drag a card into a slot (or onto the screens); right-click / R
## flips flippable cards; pull a standing card (or its wave) out to take it
## back; Enter/Space resolves.

const LAUNCH_SECONDS := 0.45
const IMPACT_SECONDS := 0.6
const SHOT_SECONDS := 0.5
## Flat face sizes of the devices (their own coordinate spaces).
const SCOPE_FLAT := Vector2(2000, 900)
## Transmitter (L-shaped, side view): the upright face, and the horizontal
## foot with the card slots lying on the desk in front of it.
## The face's width is set by the layout (_tx_w) so that its screen's columns
## line up with the main scope's; only the height is fixed.
const TX_FLAT := Vector2(1500, 205)
const TX_BULBS_W := 124.0
## Glass beside the grid inside the transmitter tube.
const TX_TUBE_PAD := 28.0
const FOOT_FLAT := Vector2(1500, 300)
## Share of the transmitter's on-screen height taken by the upright face.
const TX_FACE_SHARE := 0.6
## Front lip thickness of the foot (pixels).
const FOOT_LIP := 14.0
const GAUGE_FLAT := Vector2(380, 360)
## Scope unit face: left column (ports / counters) and right knob strip.
const SCOPE_LEFT := 400.0
const SCOPE_RIGHT := 110.0
const SCOPE_RX_H := 250.0
## Held hand: small overlapping fan below the desk edge. Open hand: raised,
## full size and spread out over the desk.
const HAND_SCALE := 0.62
const OPEN_SCALE := 1.05

var app: Node
var combat: Combat
var encounter: EncounterData
var seed_value := 0
var demo := false
## Set when this fight is part of a run (null for single-fight testing).
var run: RunState
var tutorial_enabled := true

var _scope_dev: DeskDevice
var _tx_dev: DeskDevice
var _foot_dev: DeskDevice
## Current flat width of the transmitter face and foot.
var _tx_w := TX_FLAT.x
var _gauge_dev: DeskDevice
## Device faces (flat coordinates inside each device).
var _receiver: InstrumentCase
var _transmitter: InstrumentCase
var _integrity: InstrumentCase
## Fire key artwork on the transmitter face (the clickable area is
## _resolve_btn, an invisible button over its on-screen footprint).
var _fire_art: FireKey
var _note: DeskNote
var _slot: SlotBar
var _slot_cards: SlotCards
var _prev_energy := -1
var _enemy_screen: ScopeScreen
var _player_screen: ScopeScreen
## Phosphor tubes holding the two screens (amber receiver, cyan transmitter).
var _enemy_tube: TubeScreen
var _player_tube: TubeScreen
var _merged: MergedView
var _fx: FxLayer
var _hand_root: Control
var _card_views: Array[CardView] = []
var _player_hp: NeedleMeter
## EnemyState -> {"figure": FigureView, "panel": EnemyPanel}
var _enemy_views := {}
var _to_enemy_label: FlipCounter
var _to_player_label: FlipCounter
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
## Whether the hand is opened (raised, enlarged and spread).
var _hand_open := false
## A card pressed but not yet dragged: release = click (open/close the hand),
## move = drag.
var _press_card: CardInstance
var _press_pos := Vector2.ZERO
var _resolve_btn: Button
## Pause panel (Esc): continue / back to the menu.
var _pause: Control
var _spark_t := 0.0
## Fire wind-up: >0 while the transmitter builds up before launching
## (tremble and sparks scale with it).
var _charge := 0.0
var _toast: Label
var _overlay: Control
var _hint: HintSlip
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
	_scope_dev = _make_device(SCOPE_FLAT)
	_receiver = InstrumentCase.new()
	_receiver.desk_shadow = false
	_receiver.texture_id = "item_main_scope"
	_receiver.size = SCOPE_FLAT
	_scope_dev.content.add_child(_receiver)
	_enemy_screen = _make_screen(1.0, Color("ffb02e"), Color("170c02"))
	_enemy_tube = _make_tube(_enemy_screen, Color(0.05, 0.03, 0.01), _scope_dev.content)
	_merged = MergedView.new()
	_merged.track_length = combat.rules.track_length
	_merged.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_merged.embedded = true
	_scope_dev.content.add_child(_merged)

	for e in combat.enemies:
		var fig := FigureView.new()
		fig.shape = e.data.figure_shape
		fig.color = Assets.color(e.data.color_id)
		fig.texture = Assets.texture(e.data.texture_id) if e.data.texture_id != "" else null
		_scope_dev.content.add_child(fig)
		var panel := EnemyPanel.new()
		_scope_dev.content.add_child(panel)
		_enemy_views[e] = {"figure": fig, "panel": panel}

	_to_enemy_label = FlipCounter.new()
	_to_enemy_label.color = Assets.color("damage_to_enemy")
	_scope_dev.content.add_child(_to_enemy_label)
	_to_player_label = FlipCounter.new()
	_to_player_label.color = Assets.color("damage_to_player")
	_scope_dev.content.add_child(_to_player_label)
	for up in [true, false]:
		var arrow := ArrowIcon.new()
		arrow.up = up
		arrow.color = Assets.color("damage_to_enemy") if up else Assets.color("damage_to_player")
		arrow.size = Vector2(56, 60)
		_scope_dev.content.add_child(arrow)
		_arrows.append(arrow)

	_tx_dev = _make_device(TX_FLAT)
	# Square bottom corners: the face joins the foot there.
	_tx_dev.radii = Vector4(InstrumentStyle.CASE_RADIUS, InstrumentStyle.CASE_RADIUS, 0, 0)
	_tx_dev.cast_shadow = false
	_transmitter = InstrumentCase.new()
	_transmitter.radii = _tx_dev.radii
	_transmitter.desk_shadow = false
	_transmitter.texture_id = "item_transmitter"
	_transmitter.size = TX_FLAT
	_tx_dev.content.add_child(_transmitter)
	_player_screen = _make_screen(-1.0, Color("4fd8ff"), Color("021318"))
	_player_tube = _make_tube(_player_screen, Color(0.01, 0.04, 0.05), _tx_dev.content)
	_energy = EnergyView.new()
	_tx_dev.content.add_child(_energy)
	_fire_art = FireKey.new()
	_tx_dev.content.add_child(_fire_art)
	_foot_dev = _make_device(FOOT_FLAT)
	_foot_dev.depth = 0.0
	_foot_dev.front_depth = FOOT_LIP
	_foot_dev.radii = Vector4(0, 0, InstrumentStyle.CASE_RADIUS, InstrumentStyle.CASE_RADIUS)
	_slot = SlotBar.new()
	_slot.track_length = combat.rules.track_length
	_slot.radii = _foot_dev.radii
	_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot.size = FOOT_FLAT
	_foot_dev.content.add_child(_slot)
	_slot_cards = SlotCards.new()
	add_child(_slot_cards)

	_gauge_dev = _make_device(GAUGE_FLAT)
	_integrity = InstrumentCase.new()
	_integrity.desk_shadow = false
	_integrity.texture_id = "item_integrity"
	_integrity.size = GAUGE_FLAT
	_gauge_dev.content.add_child(_integrity)
	_player_hp = NeedleMeter.new()
	_player_hp.color = Assets.color("player_wave")
	_gauge_dev.content.add_child(_player_hp)

	_note = DeskNote.new()
	add_child(_note)
	_turn_label = _make_label(20, Assets.color("case_print"))
	_turn_label.visible = false

	_draw_pile = PileIcon.new()
	add_child(_draw_pile)
	_discard_pile = PileIcon.new()
	_discard_pile.discard = true
	add_child(_discard_pile)

	# Invisible click area over the fire key's on-screen footprint.
	_resolve_btn = Button.new()
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		_resolve_btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	_resolve_btn.pressed.connect(_resolve)
	_resolve_btn.mouse_entered.connect(func() -> void: _fire_art.hovered = true)
	_resolve_btn.mouse_exited.connect(func() -> void: _fire_art.hovered = false)
	add_child(_resolve_btn)


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


func _make_screen(dir: float, phosphor: Color, bg: Color) -> ScopeScreen:
	var sc := ScopeScreen.new()
	sc.track_length = combat.rules.track_length
	sc.launch_dir = dir
	sc.phosphor = phosphor
	sc.bg_color = bg
	sc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sc


func _make_tube(screen: ScopeScreen, glass: Color, parent: Control) -> TubeScreen:
	var tube := TubeScreen.new(screen)
	tube.glass_tint = glass
	parent.add_child(tube)
	return tube


func _make_device(flat: Vector2) -> DeskDevice:
	var d := DeskDevice.new()
	d.flat_size = flat
	d.depth = 16.0
	add_child(d)
	return d


## Full power: the transmitter keeps trembling and throws overload sparks.
func _process(delta: float) -> void:
	if combat == null or _tx_dev == null:
		return
	var full := combat.outcome == Combat.Outcome.ONGOING and not _animating \
		and combat.energy <= 0 and not combat.played.is_empty()
	_tx_dev.tremble = 1.0 if full else 0.0
	if _charge > 0.0:
		full = true
		_tx_dev.tremble = 1.0 + _charge * 2.5
	_foot_dev.tremble = _tx_dev.tremble
	_slot_cards.position = _foot_dev.jitter()
	if not full:
		return
	_spark_t -= delta
	if _spark_t > 0.0:
		return
	_spark_t = randf_range(0.05, 0.12) / (1.0 + _charge * 2.0)
	# Small bursts from the bulb column and along the transmitter's far edge.
	var bulbs := _tx_dev.flat_rect_to_screen(_energy.get_rect())
	var p := Vector2(randf_range(bulbs.position.x, bulbs.end.x), randf_range(bulbs.position.y, bulbs.end.y))
	if randf() < 0.5:
		var q0 := _tx_dev.global_position + _tx_dev.quad[0]
		var q1 := _tx_dev.global_position + _tx_dev.quad[1]
		p = q0.lerp(q1, randf())
	var col := Assets.color("energy").lerp(Color("ff8a3a"), randf() * 0.6)
	for i in randi_range(2, 4):
		_fx.spark(p, col)


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
	_edge_y = h - float(Assets.DESK["edge_from_bottom"])
	_layout_faces()

	# Scope unit: upright at the back, top slightly wider than the bottom.
	var y0 := 26.0
	var y1 := _edge_y - 300.0
	var hs := y1 - y0
	var tw := minf(w - 240.0, hs * (SCOPE_FLAT.x / SCOPE_FLAT.y) * 1.03)
	# Faces are almost frontal (easy to read); depth comes from the visible
	# case tops, shadows and overlaps.
	var bw := tw * 0.985
	var cx := w * 0.5
	_scope_dev.set_quad(PackedVector2Array([Vector2(cx - tw * 0.5, y0), Vector2(cx + tw * 0.5, y0),
		Vector2(cx + bw * 0.5, y1), Vector2(cx - bw * 0.5, y1)]))

	# Transmitter (L-shaped): the upright face stands in front of the scope
	# unit; its foot lies on the desk towards the operator. Its screen's grid
	# columns sit exactly under the main scope's (so the face's flat width
	# follows the layout).
	var t0 := y1 + 22.0
	var t1 := _edge_y - 8.0
	var tm := t0 + (t1 - t0) * TX_FACE_SHARE
	var ym := _merged.position.y + _merged.size.y
	var gx0_s := _scope_dev.flat_to_screen(Vector2(_merged.position.x + _merged.grid_x0, ym)).x
	var gx1_s := _scope_dev.flat_to_screen(Vector2(_merged.position.x + _merged.grid_x1, ym)).x
	var ts := (tm - t0) / TX_FLAT.y
	_tx_w = _tx_left() + (gx1_s - gx0_s) / ts + _tx_right()
	_tx_dev.set_flat_size(Vector2(_tx_w, TX_FLAT.y))
	_foot_dev.set_flat_size(Vector2(_tx_w, FOOT_FLAT.y))
	_layout_tx_face()
	var nl := gx0_s - _tx_left() * ts
	var nr := nl + _tx_w * ts
	var nb := nr - nl
	cx = (nl + nr) * 0.5
	_tx_dev.set_quad(PackedVector2Array([Vector2(nl, t0), Vector2(nr, t0), Vector2(nr, tm), Vector2(nl, tm)]))
	# The near edge only a little wider, so the slots stay under their columns.
	var fb := nb * 1.02
	_foot_dev.set_quad(PackedVector2Array([Vector2(nl, tm), Vector2(nr, tm),
		Vector2(cx + fb * 0.5, t1 - FOOT_LIP), Vector2(cx - fb * 0.5, t1 - FOOT_LIP)]))
	var bases := PackedVector2Array()
	for t in combat.rules.track_length:
		bases.append(_foot_dev.flat_to_screen(_slot.slit_point(t)) - global_position)
	_slot_cards.size = size
	_slot_cards.bases = bases
	_slot_cards.cell_px = bases[1].x - bases[0].x

	# Line-integrity meter standing at the left, in front of the scope's
	# lower-left corner, turned a little counter-clockwise (not too tidy); it
	# may cover the transmitter's left frame edge, never its bulbs.
	var gx1 := nl + 8.0
	var gw := minf(gx1 - 28.0, 300.0)
	var gh := gw * GAUGE_FLAT.y / GAUGE_FLAT.x
	var gy1 := _edge_y - 10.0
	var gy0 := gy1 - gh
	var gq := PackedVector2Array([Vector2(gx1 - gw, gy0), Vector2(gx1, gy0),
		Vector2(gx1, gy1), Vector2(gx1 - gw, gy1)])
	var gc := Vector2(gx1 - gw * 0.5, (gy0 + gy1) * 0.5)
	for i in gq.size():
		gq[i] = gc + (gq[i] - gc).rotated(-0.09)
	_gauge_dev.set_quad(gq)

	# Duty note taped over the scope unit's right knob strip (frame and
	# decorative knobs only), hanging past its edge onto the desk; it stays
	# above the transmitter so the fire key and its lamp remain clear.
	var hood_r := _scope_dev.flat_to_screen(Vector2(_merged.position.x + _merged.grid_x1 + OscilloscopeView.TUBE_MARGIN + 16.0, ym)).x
	var nx := hood_r + 4.0
	_note.place(nx, t0 - 12.0, clampf(w - nx - 6.0, 150.0, 240.0))
	_note.rotation = 0.05

	# Fire key click area = the key's footprint on screen.
	_resolve_btn.position = _tx_dev.flat_rect_to_screen(_fire_art.get_rect()).position
	_resolve_btn.size = _tx_dev.flat_rect_to_screen(_fire_art.get_rect()).size

	# Beyond the desk edge: draw pile (left), hand (centre), discard (right).
	var pile_h := minf(140.0, h - _edge_y + 30.0)
	_draw_pile.position = Vector2(48.0, h - pile_h - 12)
	_draw_pile.size = Vector2(120, pile_h)
	_discard_pile.position = Vector2(w - 168.0, h - pile_h - 12)
	_discard_pile.size = Vector2(120, pile_h)
	_hand_root.position = Vector2.ZERO
	_hand_root.size = size
	_toast.position = Vector2(cx - 500.0, y0 + hs * 0.45)
	_toast.size = Vector2(1000.0, 60.0)
	_layout_hand()
	if _hint != null:
		_hint.place(_hint_spots(_hint_data.get("anchor", "none")))


## Flat layouts of the device faces (independent of the window size).
func _layout_faces() -> void:
	var IN := InstrumentStyle.WINDOW_INSET
	var TB := InstrumentStyle.TITLE_BASELINE
	# --- Scope unit: receiver row above, main scope below.
	var main_rect := Rect2(IN, SCOPE_RX_H + IN, SCOPE_FLAT.x - IN * 2, SCOPE_FLAT.y - SCOPE_RX_H - IN * 2)
	_merged.position = main_rect.position
	_merged.size = main_rect.size
	_merged.grid_x0 = SCOPE_LEFT
	_merged.grid_x1 = main_rect.size.x - SCOPE_RIGHT
	_merged.layout_parts()
	var gx0 := main_rect.position.x + SCOPE_LEFT
	var gx1 := main_rect.position.x + main_rect.size.x - SCOPE_RIGHT
	var win := Rect2(gx0 - OscilloscopeView.TUBE_MARGIN, IN, gx1 - gx0 + OscilloscopeView.TUBE_MARGIN * 2, SCOPE_RX_H - IN)
	_receiver.windows = [win]
	_enemy_tube.position = win.position
	_enemy_tube.size = win.size
	_enemy_screen.grid_x0 = gx0 - win.position.x
	_enemy_screen.grid_w = gx1 - gx0
	_enemy_area = Rect2(IN, IN * 0.5, win.position.x - IN * 2 - 6.0, SCOPE_RX_H - IN)
	# Preview counters in the left column, their window flush with the tube
	# hood (hood = tube rect grown by 12; a window draws 6 beyond its rect).
	var hood_pad := OscilloscopeView.TUBE_PAD_Y - 12.0 + 6.0
	var cwin := Rect2(IN * 2, main_rect.position.y + hood_pad, SCOPE_LEFT - IN * 3 - 24.0, main_rect.size.y - hood_pad * 2)
	_receiver.labels = []
	_receiver.windows.append(cwin)
	var row1 := cwin.position.y + cwin.size.y * 0.28
	var row2 := cwin.position.y + cwin.size.y * 0.72
	var ctr_h := minf(cwin.size.y * 0.3, 110.0)
	for pair in [[_to_enemy_label, _arrows[0], row1], [_to_player_label, _arrows[1], row2]]:
		var fc: FlipCounter = pair[0]
		var ar: ArrowIcon = pair[1]
		ar.position = Vector2(cwin.position.x + 16, pair[2] - ar.size.y * 0.5)
		fc.position = Vector2(cwin.position.x + 90, pair[2] - ctr_h * 0.5)
		fc.size = Vector2(cwin.size.x - 106, ctr_h)
	_layout_enemies(false)

	_layout_tx_face()

	# --- Integrity meter.
	# --- Integrity meter.
	var iwin := Rect2(IN + 6, IN + 6, GAUGE_FLAT.x - IN * 2 - 12, GAUGE_FLAT.y - IN * 2 - 12)
	_integrity.windows = [iwin]
	_integrity.labels = []
	_player_hp.position = iwin.position + Vector2(10, 10)
	_player_hp.size = iwin.size - Vector2(20, 20)
	for c in [_receiver, _transmitter, _integrity]:
		c.queue_redraw()


## Flat width left of the transmitter's grid (frame, bulbs, glass).
func _tx_left() -> float:
	return InstrumentStyle.WINDOW_INSET * 2 + TX_BULBS_W + TX_TUBE_PAD


func _tx_key_d() -> float:
	return (TX_FLAT.y - InstrumentStyle.WINDOW_INSET * 2) * 0.6


## Flat width right of the transmitter's grid (glass, fire key, frame).
func _tx_right() -> float:
	return TX_TUBE_PAD + InstrumentStyle.WINDOW_INSET * 2 + _tx_key_d() + 36.0


## Transmitter face: bulbs | screen | fire key (the foot is _slot), laid out
## in the current flat width _tx_w.
func _layout_tx_face() -> void:
	var IN := InstrumentStyle.WINDOW_INSET
	var face_h := TX_FLAT.y
	_transmitter.size = Vector2(_tx_w, face_h)
	_slot.size = Vector2(_tx_w, FOOT_FLAT.y)
	var bulbs := Rect2(IN, IN, TX_BULBS_W, face_h - IN * 2)
	# Fire key on its metal plate, its ready lamp above it.
	var key_d := _tx_key_d()
	var key_w := key_d + 36.0
	var twin := Rect2(bulbs.end.x + IN, IN, _tx_w - bulbs.end.x - IN * 3 - key_w, face_h - IN * 2)
	_transmitter.windows = [twin]
	_transmitter.labels = []
	_energy.position = bulbs.position
	_energy.size = bulbs.size
	_player_tube.position = twin.position
	_player_tube.size = twin.size
	_player_screen.grid_x0 = TX_TUBE_PAD
	_player_screen.grid_w = twin.size.x - TX_TUBE_PAD * 2
	var key := Rect2(twin.end.x + IN + (key_w - key_d) * 0.5 - 6.0, (face_h - key_d) * 0.5 + 8.0, key_d, key_d)
	_fire_art.position = key.position
	_fire_art.size = key.size
	_transmitter.lamps = [{"center": Vector2(key.get_center().x, (IN + key.position.y) * 0.5 - 2.0), "on": false, "color": Color("ff4d3a")}]
	_slot.grid_x0 = twin.position.x + _player_screen.grid_x0
	_slot.grid_w = _player_screen.grid_w

	_transmitter.queue_redraw()
	_slot.queue_redraw()


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


## Fan layout. Held: small, overlapping, fanned, below the desk edge.
## Open: raised over the desk, full size, spread with a gentle arc.
## `snap` places cards immediately (rebuild/resize) instead of gliding.
func _layout_hand(snap := false) -> void:
	var n := _card_views.size()
	if n == 0:
		return
	var W := CardView.CARD_SIZE.x
	var H := CardView.CARD_SIZE.y
	var s := OPEN_SCALE if _hand_open else HAND_SCALE
	var spacing := W * s * (1.0 + 0.08) if _hand_open else W * s * 0.52
	var max_w := size.x - 2.0 * 220.0
	if spacing * (n - 1) + W * s > max_w:
		spacing = (max_w - W * s) / maxf(1.0, n - 1)
	var spread := minf(0.05 * (n - 1), 0.3) if not _hand_open else minf(0.02 * (n - 1), 0.1)
	var base_y := _edge_y + H * 0.06 if _hand_open else size.y + H * s * 0.12
	var arc := 3.0 if _hand_open else 7.0
	var mid := (n - 1) * 0.5
	for i in n:
		var v := _card_views[i]
		var k := float(i) - mid
		var cx := size.x * 0.5 + k * spacing
		var by := base_y + k * k * arc
		v.base_scale = s
		v.use_targets = true
		v.hover_lift = 18.0 if _hand_open else 60.0
		v.target_pos = Vector2(cx - W * 0.5, by - H)
		v.target_rot = (k / maxf(1.0, mid)) * spread * 0.5 if n > 1 else 0.0
		if snap:
			v.position = v.target_pos
			v.rotation = v.target_rot
			v.scale = Vector2(s, s)


func _set_hand_open(open: bool) -> void:
	if open == _hand_open:
		return
	_hand_open = open
	_layout_hand(false)


## Screen point over the transmitter screen at the centre of cell `t`.
func cell_screen_point(t: float) -> Vector2:
	var cw := _player_screen.grid_w / combat.rules.track_length
	var f := _player_tube.position + Vector2(_player_screen.grid_x0 + (t + 0.5) * cw, _player_tube.size.y * 0.5)
	return _tx_dev.flat_to_screen(f)


## Screen point of a cell's damage readout on the main scope.
func _readout_screen_point(t: int) -> Vector2:
	return _scope_dev.flat_to_screen(_merged.position + _merged.readout_local(t))


func _figure_screen_center(e: EnemyState) -> Vector2:
	var fig: FigureView = _enemy_views[e]["figure"]
	return _scope_dev.flat_to_screen(fig.position + fig.size * 0.5)


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
	_layout_hand(true)
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
	var from := _draw_pile.get_global_rect().get_center() - _hand_root.global_position - CardView.CARD_SIZE * Vector2(0.5, 1.0)
	var known := {}
	for v in _card_views:
		known[v.card.uid] = true
		if _known_hand.has(v.card.uid):
			continue
		v.position = from
		v.scale = Vector2(0.3, 0.3)
		v.rotation = -0.4
		v.hold = delay
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
		var cs := _slot_cards.card_scale()
		v.position = _slot_cards.slot_rect(p.offset).position - v.pivot_offset * (1.0 - cs)
		v.scale = Vector2.ONE * cs
		flying.append(v)
	var delay := 0.0
	for v in flying:
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.ghost = true
		v.use_targets = false
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
	var stubs: Array = []
	_slot.lit_from = 0
	_slot.lit_to = 0
	for p in combat.played:
		stubs.append({"card": p.card, "offset": p.offset, "flipped": p.flipped})
		if p.card == _hover_card:
			_slot.lit_from = p.offset
			_slot.lit_to = p.offset + p.wave().size()
	if extra != null:
		stubs.append({"card": extra.card, "offset": extra.offset, "flipped": extra.flipped, "ghost": true})
		_slot.lit_from = extra.offset
		_slot.lit_to = extra.offset + extra.wave().size()
	_slot_cards.stubs = stubs
	_slot_cards.hover_uid = _hover_card.uid if _hover_card != null else -1
	_slot.queue_redraw()
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
	_to_enemy_label.value = result.to_enemy
	_to_player_label.value = result.to_player
	_turn_label.text = "第 %d 回合" % combat.turn
	if combat.swap_in() > 0:
		_turn_label.text += "\n%d 回合后交换" % combat.swap_in()
	_energy.energy = combat.energy
	_energy.max_energy = combat.rules.energy_per_turn
	# Power just filled up: the transmitter trembles.
	if _prev_energy > 0 and combat.energy == 0 and not _animating:
		_tx_dev.shake(0.8)
	_prev_energy = combat.energy
	var turn_lines := PackedStringArray(["第 %d 回合" % combat.turn])
	if combat.swap_in() > 0:
		turn_lines.append("%d 回合后交换" % combat.swap_in())
	_note.set_lines(turn_lines)
	_draw_pile.count = combat.deck.draw_pile.size()
	_discard_pile.count = combat.deck.discard_pile.size()
	_resolve_btn.disabled = _animating or combat.outcome != Combat.Outcome.ONGOING
	_fire_art.disabled = _resolve_btn.disabled
	if not _transmitter.lamps.is_empty():
		_transmitter.lamps[0]["on"] = not _resolve_btn.disabled
		_transmitter.queue_redraw()
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
	_hint = HintSlip.new()
	_hint.text = h["text"]
	_hint.show_tick = h.get("complete", "button") == "button"
	_hint.dismissed.connect(_complete_hint.bind("button"))
	add_child(_hint)
	# Under the hand, so held / dragged cards pass over the slip.
	move_child(_hint, _hand_root.get_index())
	_hint.place(_hint_spots(h.get("anchor", "none")))
	_hint.appear()


## Where a hint slip may go for `anchor`, best first (see HintSlip.place):
## the knob strip right of the scope unit above the turn note ("side"), or
## hanging from the desk edge left / right of the held hand ("floor"). None of
## them covers a reading, the counters, the fire key or the slots; the
## grease-pencil arrow runs over frames and desk to the real object.
func _hint_spots(anchor: String) -> Array:
	var cx := size.x * 0.5
	var n := maxi(_card_views.size(), combat.rules.hand_size)
	var hand_half := CardView.CARD_SIZE.x * HAND_SCALE * (1.0 + 0.52 * (n - 1)) * 0.5 + 40.0
	var floor_top := _edge_y - 4.0
	var floor_h := size.y - 4.0 - floor_top
	var fl_x := _draw_pile.position.x + _draw_pile.size.x + 16.0
	var fl := Rect2(fl_x, floor_top, cx - hand_half - fl_x, floor_h)
	var fr := Rect2(cx + hand_half, floor_top, _discard_pile.position.x - 16.0 - cx - hand_half, floor_h)
	var side_top := _scope_dev.get_rect().position.y + 4.0
	var side := Rect2(_note.position.x, side_top, size.x - 6.0 - _note.position.x, _note.position.y - 16.0 - side_top)
	# Frame band above the receiver tube: arrows to the left column run along it.
	var band_y := _scope_dev.flat_to_screen(Vector2(0, InstrumentStyle.WINDOW_INSET * 0.5)).y
	# Foot surface in front of slot t's slit (clear of standing cards).
	var foot_pt := func(t: int) -> Vector2:
		var sp := _slot.slit_point(t)
		return _foot_dev.flat_to_screen(Vector2(sp.x + _slot.cell_width() * 0.4, (sp.y + FOOT_FLAT.y) * 0.5))
	# `gap`: room kept free on the hand's side of each floor spot.
	var floors := func(tip: Vector2, first_left: bool, align_l: float, align_r: float, gap: float) -> Array:
		var l := {"spot": fl.grow_side(SIDE_RIGHT, -gap), "align": align_l, "tip": tip}
		var r := {"spot": fr.grow_side(SIDE_LEFT, -gap), "align": align_r, "tip": tip}
		return [l, r] if first_left else [r, l]
	var along_top := func(tip: Vector2) -> Array:
		return [{"spot": side, "prefer_y": side_top, "tip": tip,
			"via": PackedVector2Array([Vector2(side.position.x - 10.0, band_y), Vector2(tip.x + 30.0, band_y)])}]
	match anchor:
		"enemy_scope":
			var win: Rect2 = _receiver.windows[0]
			# Tip on the glass just past the end of the trace.
			var tip := _scope_dev.flat_to_screen(Vector2(_merged.position.x + _merged.grid_x1 + 10.0, win.get_center().y))
			return [{"spot": side, "prefer_y": tip.y, "tip": tip, "start_dy": 70.0}]
		"collision":
			var tip := _scope_dev.flat_to_screen(Vector2(_merged.position.x + _merged.grid_x1 + 10.0,
				_merged.position.y + _merged.size.y * 0.4))
			return [{"spot": side, "prefer_y": tip.y, "tip": tip, "start_dy": 70.0}]
		"enemy_figure":
			var front := combat.front_enemy()
			if front != null:
				var fig: Rect2 = _enemy_views[front]["figure"].get_rect()
				return along_top.call(_scope_dev.flat_to_screen(fig.position + fig.size * Vector2(0.5, 0.15)))
		"counter":
			var cw: Rect2 = _receiver.windows[1]
			return along_top.call(_scope_dev.flat_to_screen(cw.position + Vector2(cw.size.x * 0.5, 6.0)))
		"player_scope", "slot":
			return floors.call(foot_pt.call(combat.rules.track_length - 4), false, 0.0, 1.0, 0.0)
		"resolve":
			var r := _resolve_btn.get_rect()
			return floors.call(Vector2(r.get_center().x, r.end.y + 4.0), false, 0.0, 1.0, 0.0)
		"energy":
			var b := _tx_dev.flat_rect_to_screen(_energy.get_rect())
			return floors.call(Vector2(b.get_center().x, b.end.y + 4.0), true, 0.0, 1.0, 0.0)
		"player_figure":
			var g := _gauge_dev.get_rect()
			return floors.call(g.position + g.size * Vector2(0.92, 0.8), true, 0.0, 1.0, 0.0)
		"hand":
			# Room for a visible stroke between the slip and the fan.
			return floors.call(Vector2(cx - hand_half + 70.0, size.y - 70.0), true, 1.0, 0.0, 70.0)
	return [{"spot": side, "prefer_y": side_top}]


func _complete_hint(kind: String) -> void:
	if _hint == null or _hint_data.get("complete", "button") != kind:
		return
	app.progress.mark_seen(_hint_data["id"])
	_hint.leave()
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


## True if `p` is over any hand card (respecting its rotation and scale).
func _point_on_cards(p: Vector2) -> bool:
	for v in _card_views:
		var local := v.get_global_transform().affine_inverse() * p
		if Rect2(Vector2.ZERO, CardView.CARD_SIZE).has_point(local):
			return true
	return false


func _start_drag(card: CardInstance, grab: int, flipped: bool) -> void:
	# The opened hand would cover the transmitter: fold it while dragging.
	_hand_open = false
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


## Drop area: the card slots, the transmitter screen or the scope unit's screens.
func _over_scopes(mouse: Vector2) -> bool:
	if _over_slots(mouse):
		return true
	if _tx_dev.contains_screen(mouse):
		var f := _tx_dev.screen_to_flat(mouse)
		return _player_tube.get_rect().grow(10).has_point(f)
	if _scope_dev.contains_screen(mouse):
		var f := _scope_dev.screen_to_flat(mouse)
		return _merged.get_rect().has_point(f) or _enemy_tube.get_rect().has_point(f)
	return false


## Over the transmitter's foot (its slots) or a card standing in one.
func _over_slots(mouse: Vector2) -> bool:
	return _foot_dev.contains_screen(mouse) or _slot_cards.card_at(mouse - _slot_cards.position) != null


## Cell under the mouse, read through whichever device it is over (on the
## foot: the slot under the mouse).
func _cell_at(mouse: Vector2) -> int:
	if _foot_dev.contains_screen(mouse):
		return _slot.cell_at(_foot_dev.screen_to_flat(mouse))
	if _tx_dev.contains_screen(mouse):
		var f := _tx_dev.screen_to_flat(mouse) - _player_tube.position
		var cw := _player_screen.grid_w / combat.rules.track_length
		return floori((f.x - _player_screen.grid_x0) / cw)
	var g := _scope_dev.screen_to_flat(mouse)
	return _merged.cell_at(g - _merged.position)


func _update_drag(mouse: Vector2) -> void:
	_drag_over = _over_scopes(mouse)
	_hover_cell = _cell_at(mouse) if _drag_over else -1
	# Dropped into a slot, the card starts at that slot; over the screens the
	# grabbed sample follows the mouse.
	# Every card stands in a real slot, so the start cell is clamped to the
	# track (a card dropped anywhere else would have no slot to show it).
	_drag_offset = clampi(_cell_at(mouse) - (0 if _foot_dev.contains_screen(mouse) else _drag_grab),
		0, combat.rules.track_length - 1)
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


## Placed card under `mouse`: the card standing in a slot, or (on the
## screens) the wave (or echo) covering that cell.
func _placed_card_at(mouse: Vector2) -> PlayedCard:
	var standing := _slot_cards.card_at(mouse - _slot_cards.position)
	if standing != null:
		return combat.find_played(standing)
	if _foot_dev.contains_screen(mouse) or not _over_scopes(mouse):
		return null
	var cell := _cell_at(mouse)
	for i in range(combat.played.size() - 1, -1, -1):
		var p := combat.played[i]
		for pl in p.placements():
			if cell >= pl.offset and cell < pl.offset + pl.wave.size():
				return p
	return null


func _input(event: InputEvent) -> void:
	if _pause != null:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_hide_pause()
			get_viewport().set_input_as_handled()
		return
	if _overlay != null:
		return
	if event is InputEventMouseMotion:
		if _press_card != null and event.position.distance_to(_press_pos) > 10.0:
			var card := _press_card
			_press_card = null
			if combat.can_play(card) and not _animating:
				_start_drag(card, card.data.wave.size() / 2, false)
			elif not _animating:
				# No power left for this card: the transmitter refuses it.
				_tx_dev.shake(0.8)
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
			if _hand_open and not _point_on_cards(event.position):
				_set_hand_open(false)
			var p := _placed_card_at(event.position)
			if p != null and combat.can_unplay(p.card):
				# Pulled from its slot the card is held by its start; picked
				# up on a screen, by the sample under the mouse.
				var grab := 0 if _over_slots(event.position) else _cell_at(event.position) - p.offset
				var flipped := p.flipped
				combat.unplay(p.card)
				_start_drag(p.card, grab, flipped)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _press_card != null:
			# Released without moving: a click opens (or folds) the whole hand.
			_press_card = null
			_set_hand_open(not _hand_open)
		elif _drag_card != null:
			_end_drag(true)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				_toggle_drag_flip()
			KEY_ESCAPE:
				if _drag_card != null:
					_end_drag(false)
				elif _hand_open:
					_set_hand_open(false)
				else:
					_show_pause()
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
	_fire_art.press()
	# Share of the turn's power that was loaded: drives how hard it hits.
	var power := clampf(float(combat.rules.energy_per_turn - combat.energy) / maxf(1.0, combat.rules.energy_per_turn), 0.0, 1.0)
	var shown_player_hp := combat.player_hp
	var played_before: Array[PlayedCard] = combat.played.duplicate()
	var report := combat.resolve_turn()
	var r := report.result
	_animating = true
	_hover_cell = -1
	_resolve_btn.disabled = true
	_fire_art.disabled = true
	for v in _card_views:
		v.playable = false
		v.queue_redraw()
	_player_hp.set_values(shown_player_hp, combat.player_max_hp, 0)

	# 0. Wind-up: the (overloaded) transmitter shakes harder and harder.
	var wind := 0.12 + 0.18 * power
	var tc := create_tween()
	tc.tween_property(self, "_charge", power, wind).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tc.finished

	# 1. Both bench scopes fire their waves into the merged panel; the
	#    transmitter kicks back and its wave streaks up into the main scope.
	_charge = 0.0
	_tx_dev.shake(0.6 + power)
	app.impact(_tx_dev.get_global_rect().get_center(), 0.1 + 0.15 * power, false)
	_merged.result = r
	_merged.arrive = 0.0
	_merged.reveal = 0.0
	_merged.merge = 0.0
	_launch_streaks(r, power)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_enemy_screen, "launch", 1.0, LAUNCH_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_player_screen, "launch", 1.0, LAUNCH_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_merged, "arrive", 1.0, LAUNCH_SECONDS + 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.1)
	await tw.finished

	# 2. Impact: screen shake and collision particles (no ripple), and the
	#    result bars / numbers pop in left to right.
	app.impact(_scope_dev.flat_to_screen(_merged.position + _merged.size * 0.5),
		0.25 + 0.3 * power + 0.03 * r.perfect_cancels, false)
	_scope_dev.shake(0.3 + 0.7 * power)
	_collision_bursts(r, power)
	var tw2 := create_tween().set_parallel(true)
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
		var from := _readout_screen_point(t)
		var to := _figure_screen_center(report.target) if to_enemy else _gauge_dev.get_global_rect().get_center()
		var col := Assets.color("damage_to_enemy") if to_enemy else Assets.color("damage_to_player")
		_fx.shoot(from, to, col, delay, SHOT_SECONDS, 5.0 + dmg * 0.8)
		delay += 0.03
	await get_tree().create_timer(SHOT_SECONDS + delay).timeout

	if r.to_enemy > 0:
		target_fig.hit(r.to_enemy)
		_fx.float_text(_figure_screen_center(report.target), "-%d" % r.to_enemy, Assets.color("damage_to_enemy"))
	if r.to_player > 0:
		_integrity.flash()
		_fx.float_text(_gauge_dev.get_global_rect().get_center(), "-%d" % r.to_player, Assets.color("damage_to_player"))
		app.impact(_gauge_dev.get_global_rect().get_center(), clampf(0.2 + r.to_player * 0.03, 0.2, 0.6))
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


## Player wave streaks from the transmitter screen up into the main scope,
## and the noise streaks down from the receiver, cell by cell.
func _launch_streaks(r: TrackResult, power: float) -> void:
	var cyan := Assets.color("player_wave")
	var amber := Assets.color("enemy_ch1")
	for t in r.player.size():
		var hit := _scope_dev.flat_to_screen(_merged.position + _merged.cell_center_local(t))
		if r.player[t] != 0:
			_fx.shoot(cell_screen_point(t), hit, cyan, t * 0.012, LAUNCH_SECONDS, 3.0 + absf(r.player[t]) * (0.5 + 0.5 * power), 0.0)
		if r.enemy[t] != 0:
			var top := _scope_dev.flat_to_screen(_enemy_tube.position + Vector2(_enemy_screen.grid_x0 + (t + 0.5) * _enemy_screen.grid_w / r.enemy.size(), _enemy_tube.size.y * 0.5))
			_fx.shoot(top, hit, amber, t * 0.012, LAUNCH_SECONDS, 3.0 + absf(r.enemy[t]) * 0.5, 0.0)


## Collision particles in every cell where the waves met, coloured by result
## (blue = your damage, red = damage to you, white = cancelled).
func _collision_bursts(r: TrackResult, power: float) -> void:
	for t in r.net.size():
		var mass := absi(r.enemy[t]) + absi(r.player[t])
		if mass == 0:
			continue
		var col := Assets.color("damage_to_enemy")
		match r.outcome[t]:
			TrackResult.Outcome.PLAYER_HIT: col = Assets.color("damage_to_player")
			TrackResult.Outcome.CANCELLED: col = Color(1, 0.97, 0.9)
		var p := _scope_dev.flat_to_screen(_merged.position + _merged.cell_center_local(t))
		_fx.burst(p, col, int(3 + mass * (0.6 + power)), 0.5 + 0.5 * power)


## Esc: a small bakelite panel to continue or leave the fight.
func _show_pause() -> void:
	if _pause != null or _overlay != null:
		return
	_pause = Control.new()
	_pause.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_pause)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(dim)
	var panel := Panel.new()
	panel.size = Vector2(520, 320)
	panel.position = (size - panel.size) * 0.5
	_pause.add_child(panel)
	var title := Label.new()
	title.text = "暂停"
	title.add_theme_font_size_override("font_size", Assets.fs(40))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 30)
	title.size = Vector2(panel.size.x, 60)
	panel.add_child(title)
	_add_overlay_button(panel, "继续", Vector2(130, 120), _hide_pause)
	_add_overlay_button(panel, "返回菜单", Vector2(130, 200), func() -> void: app.show_menu())


func _hide_pause() -> void:
	if _pause != null:
		_pause.queue_free()
		_pause = null


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.6)


func _show_overlay() -> void:
	if _hint != null:
		_hint.leave()
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
		if step < 2 or app._args.has("demofull"):
			combat.play(best.card, best.offset)
		else:
			_drag_card = best.card
			_drag_offset = best.offset
			_drag_over = true
