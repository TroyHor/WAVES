class_name Deck
extends RefCounted
## Draw pile / hand / discard pile for one combat.

var draw_pile: Array[CardInstance] = []
var hand: Array[CardInstance] = []
var discard_pile: Array[CardInstance] = []
var _rng: RandomNumberGenerator


func _init(cards: Array[CardInstance], rng: RandomNumberGenerator) -> void:
	_rng = rng
	draw_pile = cards.duplicate()
	_shuffle(draw_pile)


## Draws up to `n` cards, reshuffling the discard pile when the draw pile runs
## out and stopping at `max_hand`. Returns how many were drawn.
func draw(n: int, max_hand: int) -> int:
	var drawn := 0
	for i in n:
		if hand.size() >= max_hand:
			break
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile = discard_pile
			discard_pile = []
			_shuffle(draw_pile)
		hand.append(draw_pile.pop_back())
		drawn += 1
	return drawn


func discard_hand() -> void:
	discard_pile.append_array(hand)
	hand.clear()


func total_cards() -> int:
	return draw_pile.size() + hand.size() + discard_pile.size()


## Fisher-Yates with our seeded RNG (Array.shuffle uses the global RNG).
func _shuffle(cards: Array[CardInstance]) -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := cards[i]
		cards[i] = cards[j]
		cards[j] = tmp
