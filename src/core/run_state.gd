class_name RunState
extends RefCounted
## A run: walk the nodes of data/config/run.json in order (fight / reward /
## rest / event). Player HP, the deck and relics carry over between nodes; HP
## is never refilled automatically. Every random choice is derived from the run
## seed and the node index, so a run is reproducible without saving offers.
##
## UI flow: look at current_kind(), then
##   fight  -> make_combat() ... complete_combat(combat)
##   reward -> make_reward_offer() ... choose_reward(i) / skip_reward()
##   rest   -> complete_rest()
##   event  -> complete_event(effects)   (event engine to come)

var nodes: Array[RunNodeData] = []
## Index of the current node (== nodes.size() once every node is done).
var node_index := 0
## Fights won so far (also the index of the current/next fight).
var index := 0
var player_hp := 0
var player_max_hp := 0
var deck_ids := PackedStringArray()
var relic_ids := PackedStringArray()
var seed_value := 0
var lost := false
## Encounter ids of the fight nodes, in order (for the run map).
var encounter_ids := PackedStringArray()


static func new_run(db: GameDatabase, rules: RulesConfig, p_seed: int) -> RunState:
	var r := RunState.new()
	r.nodes = db.run_nodes.duplicate()
	r.encounter_ids = db.run_order.duplicate()
	r.player_max_hp = rules.player_max_hp
	r.player_hp = r.player_max_hp
	r.deck_ids = db.starter_deck.duplicate()
	r.seed_value = p_seed
	return r


# --- Queries ---------------------------------------------------------------

func current_node() -> RunNodeData:
	return nodes[node_index] if node_index < nodes.size() else null


## "fight" / "reward" / "rest" / "event", or "" when the run is over.
func current_kind() -> String:
	var n := current_node()
	return "" if n == null or lost else n.kind


## Encounter of the current fight node, else of the next fight ahead.
func current_encounter_id() -> String:
	for i in range(node_index, nodes.size()):
		if nodes[i].kind == RunNodeData.FIGHT:
			return nodes[i].encounter
	return ""


func is_won() -> bool:
	return not lost and node_index >= nodes.size()


func is_over() -> bool:
	return lost or is_won()


func deck_cards(db: GameDatabase) -> Array[CardData]:
	return db.cards_for(deck_ids)


## Seed for anything random at the current node. Fights keep the original
## `seed + fight_index * 7919` so existing seeds reproduce the same fights.
func node_seed(salt := 0) -> int:
	if current_kind() == RunNodeData.FIGHT and salt == 0:
		return seed_value + index * 7919
	return seed_value + (node_index + 1) * 104729 + salt * 31


# --- Fight -----------------------------------------------------------------

func make_combat(db: GameDatabase, rules: RulesConfig) -> Combat:
	var enc := db.encounter(current_encounter_id())
	var c := Combat.new(rules, deck_cards(db), db.encounter_enemies(enc), node_seed(), enc.swap_interval, player_hp)
	c.player_max_hp = player_max_hp
	c.relics = RelicRegistry.create_all(relic_ids)
	return c


func complete_combat(combat: Combat) -> void:
	player_hp = combat.player_hp
	if combat.outcome == Combat.Outcome.WON:
		index += 1
		advance()
	elif combat.outcome == Combat.Outcome.LOST:
		lost = true


# --- Reward ----------------------------------------------------------------

## Deterministic: calling it again at the same node gives the same offer.
func make_reward_offer(db: GameDatabase, rules: RulesConfig) -> RewardOffer:
	var offer := RewardOffer.new()
	offer.can_skip = rules.reward_allow_skip
	var n := current_node()
	if current_kind() != RunNodeData.REWARD:
		return offer
	var count := n.size if n.size > 0 else rules.reward_offer_size
	offer.cards = Rewards.card_offer(Rewards.pool_for(n, db), count, node_seed())
	return offer


func choose_reward(offer: RewardOffer, choice: int) -> bool:
	if current_kind() != RunNodeData.REWARD or choice < 0 or choice >= offer.cards.size():
		return false
	deck_ids.append(offer.cards[choice].id)
	advance()
	return true


func skip_reward(offer: RewardOffer) -> bool:
	if current_kind() != RunNodeData.REWARD or not offer.can_skip:
		return false
	advance()
	return true


# --- Rest / event (placeholders) -------------------------------------------

## Applies the rest node's data effects (none = no-op) and moves on.
func complete_rest() -> bool:
	if current_kind() != RunNodeData.REST:
		return false
	RunEffects.apply(self, current_node().effects)
	if not lost:
		advance()
	return true


## Applies the chosen outcome's effects and moves on. Until the event engine
## exists the UI may call this with no effects to just pass the node.
func complete_event(effects: Array[Dictionary] = []) -> bool:
	if current_kind() != RunNodeData.EVENT:
		return false
	RunEffects.apply(self, effects)
	if not lost:
		advance()
	return true


func advance() -> void:
	if node_index < nodes.size():
		node_index += 1
