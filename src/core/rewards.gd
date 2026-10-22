class_name Rewards
extends RefCounted
## Pure reward generation. Same pool + count + seed -> same offer, so offers
## are reproducible from the run seed and never need to be saved.


## Draws up to `count` distinct cards from `pool`, weighted by reward_weight,
## without replacement. Cards with weight 0 are never offered. `pool` order
## matters for reproducibility, so pass it in a stable (sorted) order.
static func card_offer(pool: Array[CardData], count: int, seed_value: int) -> Array[CardData]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var left: Array[CardData] = []
	for c in pool:
		if c.reward_weight > 0.0 and not c in left:
			left.append(c)
	var out: Array[CardData] = []
	while out.size() < count and not left.is_empty():
		var total := 0.0
		for c in left:
			total += c.reward_weight
		var roll := rng.randf() * total
		var pick := left.size() - 1
		for i in left.size():
			roll -= left[i].reward_weight
			if roll < 0.0:
				pick = i
				break
		out.append(left[pick])
		left.remove_at(pick)
	return out


## The pool a reward node draws from: its explicit pool, else every card.
static func pool_for(node: RunNodeData, db: GameDatabase) -> Array[CardData]:
	if node.pool.is_empty():
		return db.sorted_cards()
	return db.cards_for(node.pool)
