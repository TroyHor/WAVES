class_name Deck
extends RefCounted
## Card piles for one combat. Uses the combat's RNG so runs are reproducible.

var draw_pile: Array[CardInstance] = []
var hand: Array[CardInstance] = []
var discard_pile: Array[CardInstance] = []
var exhaust_pile: Array[CardInstance] = []
var _rng: RandomNumberGenerator


func _init(cards: Array[CardInstance] = [], rng: RandomNumberGenerator = null) -> void:
	_rng = rng if rng else RandomNumberGenerator.new()
	draw_pile = cards.duplicate()
	_shuffle(draw_pile)


## Draws up to `count` cards, reshuffling the discard pile when needed.
## Stops early if the hand is full or both piles are empty.
func draw(count: int, max_hand: int) -> Array[CardInstance]:
	var drawn: Array[CardInstance] = []
	for i in count:
		if hand.size() >= max_hand:
			break
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile = discard_pile
			discard_pile = []
			_shuffle(draw_pile)
		var c: CardInstance = draw_pile.pop_back()
		hand.append(c)
		drawn.append(c)
	return drawn


func discard_hand() -> void:
	discard_pile.append_array(hand)
	hand.clear()


func total_cards() -> int:
	return draw_pile.size() + hand.size() + discard_pile.size() + exhaust_pile.size()


func _shuffle(pile: Array[CardInstance]) -> void:
	for i in range(pile.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := pile[i]
		pile[i] = pile[j]
		pile[j] = tmp
