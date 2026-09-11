extends RefCounted

const Development = preload("res://Scripts/Sim/U13GameDevelopment.gd")
const Scenario = preload("res://Scripts/Sim/U13KanifousScenario.gd")
const Legality = preload("res://Scripts/Sim/U13Legality.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Rng = preload("res://Scripts/Sim/U13KeyedRng.gd")
const VERSION: String = "U13_GAME_RANDOM_LEGAL_V1"


static func plan(owner, pid: int) -> Dictionary:
	var view: Dictionary = owner.player_view(pid, 0)
	if view.action == "invalid" or view.next_hook != "submission_lock" or view.submitted:
		return Data.invalid("game_bot_not_planning")
	var raw: Dictionary = Scenario.enumerate(owner, pid)
	if raw.action == "invalid":
		return raw
	var groups: Array = Legality.legal_power_groups(owner, pid, raw.powers)
	var powers: Array = []
	var picked: int = _pick(owner, pid, "power", groups.size() + 1)
	if picked < groups.size():
		var choices: Array = groups[picked].candidates
		powers.append(choices[_pick(owner, pid, "power-target", choices.size())])
	var order: Dictionary = {}
	order = _choose(owner, pid, powers, order, Development.summon_orders(view, powers, order), "summon")
	order = _choose(owner, pid, powers, order, Development.castle_orders(view, powers, order), "castle")
	var combat: Array = []
	if not order.has("summon"):
		var seen: Dictionary = {}
		for original in raw.orders:
			if not original.has("action"):
				continue
			var candidate: Dictionary = order.duplicate(true)
			for key in ["action", "lane", "target_id", "card_ids"]:
				if original.has(key):
					candidate[key] = original[key]
			var identity: String = JSON.stringify(candidate, "", true)
			if not seen.has(identity):
				combat.append(candidate)
				seen[identity] = true
	order = _choose(owner, pid, powers, order, combat, "combat")
	var amount: int = _pick(owner, pid, "guard-count", int(view.world.guard_placement_limits[pid]) + 1)
	for index in range(amount):
		var legal: Array = owner.legal_order_candidates(pid, powers, Development.guard_orders(view, powers, order))
		if legal.is_empty():
			break
		order = legal[_pick(owner, pid, "guard:%d" % index, legal.size())].duplicate(true)
	var checked: Dictionary = owner.preview_submission(pid, powers, order)
	if checked.action == "invalid":
		return checked
	return {"action": "bot_plan", "powers": powers, "order": order}


static func _choose(owner, pid: int, powers: Array, base: Dictionary, candidates: Array, stage: String) -> Dictionary:
	var grouped: Dictionary = {}
	for order in owner.legal_order_candidates(pid, powers, candidates):
		var group: String = stage
		if stage == "castle":
			group = order.castle_action.action
		elif stage == "combat":
			group = order.action
		if not grouped.has(group):
			grouped[group] = []
		grouped[group].append(order)
	var names: Array = grouped.keys()
	names.sort()
	# Pass is an explicit legal choice, not a fallback that conceals errors.
	var index: int = _pick(owner, pid, stage, names.size() + 1)
	if index == names.size():
		return base
	var choices: Array = grouped[names[index]]
	return choices[_pick(owner, pid, stage + ":target", choices.size())].duplicate(true)


static func _pick(owner, pid: int, stage: String, count: int) -> int:
	return int(Rng.draw(owner.rng_seed(), "%s:%d:%d" % [VERSION, owner.round_number(), pid], stage, 0, count).value)
