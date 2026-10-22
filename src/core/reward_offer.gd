class_name RewardOffer
extends RefCounted
## What a reward node offers. The UI shows `cards` and calls
## RunState.choose_reward(index) or RunState.skip_reward().

var cards: Array[CardData] = []
var can_skip := true
