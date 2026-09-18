extends RefCounted

# A bounded card-driven spawner, not a second combat implementation.
const Economy = preload("res://Scripts/Sim/U13GameEconomy.gd")
const Monsters = preload("res://Scripts/Sim/U13MonsterRules.gd")
const Market = preload("res://Scripts/Sim/U13GameMarket.gd")
const Rng = preload("res://Scripts/Sim/U13KeyedRng.gd")
var seed_value: String
var owner: int = 1
var deck: Array = []
var discard: Array = []
var saved: Array = []
var goal: String = ""
var shuffle_number: int = 0

func _init(seed_text: String = "lane-balance-1", player_id: int = 1) -> void:
	owner = player_id
	# Preserve the existing enemy stream; home has its own deck and choices.
	seed_value = seed_text if owner == 1 else seed_text + ":home"
	for suit in Economy.SUITS:
		var cards: Array = []
		for value in range(Economy.COUNTS.size()):
			for copy in range(Economy.COUNTS[value]):
				cards.append({"id": "%s:%d:%d" % [suit, value, copy], "kind": "card", "attributes": {"suit": suit, "value": value + 1}})
		Economy._shuffle(cards, seed_value, "trim:" + suit)
		deck.append_array(cards.slice(3))
	Economy._shuffle(deck, seed_value, "sandbox:opening")

func pick(round_number: int, purpose: String, count: int) -> int:
	return int(Rng.draw(seed_value, "sandbox:enemy", purpose, round_number, count).value)

func draw() -> Dictionary:
	if deck.is_empty():
		deck = discard
		discard = []
		shuffle_number += 1
		Economy._shuffle(deck, seed_value, "sandbox:reshuffle:%d" % shuffle_number)
	return {} if deck.is_empty() else deck.pop_back()

func ingredients(hand: Array, name: String) -> Array:
	var chosen: Array = []
	for suit in Monsters.ROSTER[name].recipe:
		var matches: Array = hand.filter(func(c): return c.attributes.suit == suit)
		chosen.append_array(matches.slice(0, Monsters.ROSTER[name].recipe[suit]))
	return chosen

func next_wave(round_number: int, living: Array) -> Dictionary:
	if goal.is_empty() or (Monsters.limited(goal) and Monsters.living(living, owner, goal)):
		var roll: int = pick(round_number, "goal-tier", 100)
		var tier: String = "Easy" if roll < 45 else ("Moderate" if roll < 75 else ("Hard" if roll < 95 else "Very hard"))
		var options: Array = Monsters.NAMES.filter(func(n): return Monsters.ROSTER[n].tier == tier and (not Monsters.limited(n) or not Monsters.living(living, owner, n)))
		goal = "Lemek" if options.is_empty() else options[pick(round_number, "goal", options.size())]
	var hand: Array = saved.duplicate(true)
	saved = []
	for i in range(Economy.ROUND_CARDS):
		var card: Dictionary = draw()
		if not card.is_empty(): hand.append(card)
	# One optional trade from a three-card market. No extra card is created.
	var offers: Array = []
	for i in range(Market.SIZE):
		var card: Dictionary = draw()
		if not card.is_empty(): offers.append(card)
	var keep: Array = ingredients(hand, goal)
	var spare: Array = hand.filter(func(c): return c not in keep)
	for offer in offers.duplicate():
		var suit: String = offer.attributes.suit
		if not spare.is_empty() and Monsters.ROSTER[goal].recipe.get(suit, 0) > hand.filter(func(c): return c.attributes.suit == suit).size():
			hand.erase(spare[0]); discard.append(spare[0])
			hand.append(offer); offers.erase(offer)
			break
	discard.append_array(offers)
	# Spare pairs have a 50% chance to fund defense before commitment.
	keep = ingredients(hand, goal)
	for suit in Economy.SUITS:
		var pair: Array = hand.filter(func(c): return c.attributes.suit == suit and c not in keep)
		if pair.size() >= 2 and pick(round_number, "defense:" + suit, 2) == 0:
			for card in pair.slice(0, 2): hand.erase(card); discard.append(card)
	var choices: Array = Monsters.available(hand + living, hand.map(func(c): return c.id), owner)
	var monster: String = ""
	if goal in choices:
		monster = goal
	elif not choices.is_empty():
		# Favor the largest recipe already in hand, preserving rare natural draws.
		choices.sort_custom(func(a, b): return ingredients(hand, a).size() > ingredients(hand, b).size())
		monster = choices[0]
	var committed: Array = []
	if not monster.is_empty():
		committed = ingredients(hand, monster)
		goal = ""
	else:
		saved = ingredients(hand, goal).slice(0, 2)
	var budget: int = maxi(committed.size(), 2 + pick(round_number, "commitment-size", 4))
	var rest: Array = hand.filter(func(c): return c not in committed and c not in saved)
	Economy._shuffle(rest, seed_value, "sandbox:commit:%d" % round_number)
	committed.append_array(rest.slice(0, maxi(0, budget - committed.size())))
	for card in hand:
		if card not in saved: discard.append(card)
	return {"cards": committed.duplicate(true), "monster": monster, "saved": saved.size()}
