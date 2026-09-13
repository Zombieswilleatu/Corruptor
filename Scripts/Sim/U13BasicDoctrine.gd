extends RefCounted

const Context = preload("res://Scripts/Sim/U13DoctrineView.gd")
const Common = preload("res://Scripts/Sim/U13CommonDoctrine.gd")
const Powers = preload("res://Scripts/Sim/U13PowerDoctrine.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const BotPlanning = preload("res://Scripts/Sim/U13BotPlanning.gd")
const VERSION: String = "U13_BASIC_DOCTRINE_V3"
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

static func plan(owner, pid: int, reuse_validation: bool = true) -> Dictionary:
	if reuse_validation:
		owner = owner.planning_session(pid)
		if owner == null:
			return Data.invalid("doctrine_not_planning")
	owner = BotPlanning.new(owner, pid)
	var view: Dictionary = owner.player_view(pid, 0)
	if view.action == "invalid" or view.next_hook != "submission_lock" or view.submitted:
		return Data.invalid("doctrine_not_planning")
	var c = Context.new(view)
	var order: Dictionary = {}
	# Reserve winning/economical rites and resummoning before optional power costs.
	for stage in ["waiters", "invocation", "profane_ruins"]:
		order = choose(owner, pid, [], order, Common.rites(c, [], order, stage))
	order = choose(owner, pid, [], order, Common.summon(c, [], order))
	# Wishes fire after combat. Score them against our actual committed cards,
	# guards and Repair, without simulating the opponent's sealed order.
	var late_wish: bool = c.w.lord_ids[pid] == "Kanifous"
	var powers: Array = [] if late_wish else choose_power(owner, pid, c, order)
	order = choose(owner, pid, powers, order, Common.castles(c, powers, order))
	order = choose(owner, pid, powers, order, Common.combat(c, powers, order))
	# Re-evaluate only the selected power against our own chosen combat. If it
	# becomes predictably redundant, drop it and spend the released cards on the
	# same two bounded development/combat stages. No opponent-order forecasting.
	if not powers.is_empty() and Powers.redundant(c, powers[0], order):
		powers = choose_power(owner, pid, c, order)
		if powers.is_empty():
			var reserved: Dictionary = {}
			for key in ["rites", "summon"]:
				if order.has(key):
					reserved[key] = order[key].duplicate(true)
			order = choose(owner, pid, powers, reserved, Common.castles(c, powers, reserved))
			order = choose(owner, pid, powers, order, Common.combat(c, powers, order))
	for index in range(mini(3, int(c.w.guard_placement_limits[pid]))):
		var next: Dictionary = choose(owner, pid, powers, order, Common.guards(c, powers, order))
		if next == order:
			break
		order = next
	if late_wish:
		powers = choose_power(owner, pid, c, order)
	var checked: Dictionary = owner.preview_submission(pid, powers, order)
	if checked.action == "invalid":
		return checked
	return owner.canonical_plan({"action": "bot_plan", "powers": powers, "order": order})

static func choose_power(owner, pid: int, c, order: Dictionary) -> Array:
	var options: Array = ranked(Powers.options(c, order).filter(func(x): return not Powers.redundant(c, x.payload, order)))
	var admitted: Array = owner.legal_power_candidates(pid, options.map(func(x): return x.payload)) if not options.is_empty() else []
	# The full cart, including rites and resummoning, must be admitted together.
	for source in admitted.slice(0, 4):
		if owner.preview_submission(pid, [source], order).action != "invalid":
			return [source]
	return []

static func to_planning(game) -> Dictionary:
	for attempt in range(12):
		var result: Dictionary = game.to_planning()
		if result.action not in ["game_draw_choice", "game_market_choice"]:
			return result
		result = resolve_choice(game, result)
		if result.action == "invalid":
			return result
	return Data.invalid("doctrine_choice_limit")

# Resolve only the supplied seat. The playable adapter pauses for human input.
static func resolve_choice(game, pending: Dictionary) -> Dictionary:
	if pending.get("action") not in ["game_draw_choice", "game_market_choice"]:
		return Data.invalid("doctrine_choice_invalid")
	var pid: int = pending.player_id
	var c = Context.new(BotPlanning.new(game._owner, pid).player_view(pid, 0))
	if pending.action == "game_draw_choice":
		var cards: Array = c.w.game_economy.stockpile_pending.card_ids.duplicate()
		cards.sort_custom(func(a, b): return a < b if c.card_score(a) == c.card_score(b) else c.card_score(a) > c.card_score(b))
		return game.choose_stockpile(pid, cards[0])
	var choice: Dictionary = {"market": "Pass"}
	var best: float = 0.0
	for option in game.market_choices(pid):
		if option.market != "Swap":
			continue
		var gain: float = c.card_score(option.take_id) - c.card_score(option.give_id)
		if gain > best:
			best = gain
			choice = option
	return game.choose_market(pid, choice)
