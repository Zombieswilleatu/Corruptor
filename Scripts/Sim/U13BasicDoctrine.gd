extends RefCounted

const Context = preload("res://Scripts/Sim/U13DoctrineView.gd")
const Common = preload("res://Scripts/Sim/U13CommonDoctrine.gd")
const Powers = preload("res://Scripts/Sim/U13PowerDoctrine.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const VERSION: String = "U13_BASIC_DOCTRINE_V1"
const CANDIDATE_LIMIT: int = 32

static func ranked(options: Array) -> Array:
	var useful: Array = options.filter(func(x): return x.score > 0)
	for option in useful:
		option["key"] = JSON.stringify(option.payload, "", true)
	useful.sort_custom(func(a, b): return a.key < b.key if a.score == b.score else a.score > b.score)
	var unique: Array = []
	var seen: Dictionary = {}
	for option in useful:
		if not seen.has(option.key):
			seen[option.key] = true
			unique.append(option)
	return unique.slice(0, CANDIDATE_LIMIT)

static func choose(owner, pid: int, powers: Array, base: Dictionary, options: Array) -> Dictionary:
	var shortlist: Array = ranked(options)
	if shortlist.is_empty():
		return base
	var legal: Array = owner.legal_order_candidates(pid, powers, shortlist.map(func(x): return x.payload))
	# Ordered positive utility choices; Pass is an intentional scored option.
	# Never catch a failed final preview and silently substitute a pass.
	return base if legal.is_empty() else legal[0].duplicate(true)

static func plan(owner, pid: int) -> Dictionary:
	var view: Dictionary = owner.player_view(pid, 0)
	if view.action == "invalid" or view.next_hook != "submission_lock" or view.submitted:
		return Data.invalid("doctrine_not_planning")
	var c = Context.new(view)
	var order: Dictionary = {}
	# Reserve winning/economical rites and resummoning before optional power costs.
	for stage in ["waiters", "invocation", "profane_ruins"]:
		order = choose(owner, pid, [], order, Common.rites(c, [], order, stage))
	order = choose(owner, pid, [], order, Common.summon(c, [], order))
	var powers: Array = []
	var options: Array = ranked(Powers.options(c, order))
	var admitted: Array = owner.legal_power_candidates(pid, options.map(func(x): return x.payload)) if not options.is_empty() else []
	# Check the already-reserved rite/summon cart too. Bound expensive complete
	# previews to four, rather than discovering conflicts after the whole plan.
	for source in admitted.slice(0, 4):
		if owner.preview_submission(pid, [source], order).action != "invalid":
			powers = [source]
			break
	order = choose(owner, pid, powers, order, Common.castles(c, powers, order))
	order = choose(owner, pid, powers, order, Common.combat(c, powers, order))
	for index in range(mini(3, int(c.w.guard_placement_limits[pid]))):
		var next: Dictionary = choose(owner, pid, powers, order, Common.guards(c, powers, order))
		if next == order:
			break
		order = next
	var checked: Dictionary = owner.preview_submission(pid, powers, order)
	if checked.action == "invalid":
		return checked
	return {"action": "bot_plan", "powers": powers, "order": order}

static func to_planning(game) -> Dictionary:
	for attempt in range(12):
		var result: Dictionary = game.to_planning()
		if result.action not in ["game_draw_choice", "game_market_choice"]:
			return result
		var pid: int = result.player_id
		var c = Context.new(game._owner.player_view(pid, 0))
		if result.action == "game_draw_choice":
			var cards: Array = c.w.game_economy.stockpile_pending.card_ids.duplicate()
			cards.sort_custom(func(a, b): return a < b if c.card_score(a) == c.card_score(b) else c.card_score(a) > c.card_score(b))
			result = game.choose_stockpile(pid, cards[0])
		else:
			var choice: Dictionary = {"market": "Pass"}
			var best: float = 0.0
			for option in game.market_choices(pid):
				if option.market != "Swap":
					continue
				var gain: float = c.card_score(option.take_id) - c.card_score(option.give_id)
				if gain > best:
					best = gain
					choice = option
			result = game.choose_market(pid, choice)
		if result.action == "invalid":
			return result
	return Data.invalid("doctrine_choice_limit")
