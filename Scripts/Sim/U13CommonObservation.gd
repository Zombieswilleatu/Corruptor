extends RefCounted

# Trusted projection boundary. Only this allowlisted result crosses into the
# planner process. Use the same pre-submission world as the human planning view.
const Data = preload("res://Scripts/Sim/U13EffectData.gd")

static func effects(records: Array, pid: int) -> Array:
	var result: Array = []
	for record in records:
		var source: Dictionary = record.declaration
		if source.player_id != pid and source.visibility != "public": continue
		var projected: Dictionary = {}
		for key in ["effect_id", "effect_key", "target", "stages", "stage_index", "activated_round", "phase", "ready_round", "cooldown_rounds", "first_blocked_round", "persistent_effect_id", "fire_round", "fire_hook"]:
			if record.has(key): projected[key] = record[key]
		projected["declaration"] = {}
		for key in ["declaration_id", "player_id", "power_id", "declared_round", "visibility"]:
			projected.declaration[key] = source[key]
		result.append(projected)
	return result

# Only past public reveals cross the process boundary. Reconstructing this
# small window also makes memory survive save/load and fresh worker processes.
static func opponent_history(rows: Array, pid: int, number: int) -> Array:
	var first: int = maxi(1, number - 6)
	var rounds: Dictionary = {}
	for index in range(rows.size() - 1, -1, -1):
		var event = rows[index].views[pid]
		if event == null or event.type != "COMBAT_ORDER_REVEALED": continue
		var detail: Dictionary = event.data
		var turn: int = detail.round
		if turn < first: break
		if turn >= number or detail.player_id == pid: continue
		if not rounds.has(turn):
			rounds[turn] = {"round": turn, "action": "Pass", "lane": "", "cards": 0, "strength": 0, "ward_strength": 0}
		var strength: int = 0
		for card in detail.cards: strength += int(card.attributes.value)
		if detail.order.get("action") in ["Hunt", "Siege"]:
			rounds[turn].action = detail.order.action
			rounds[turn].lane = detail.order.lane
			rounds[turn].cards = detail.cards.size()
			rounds[turn].strength = strength
		elif detail.order.get("action") == "Ward":
			rounds[turn].ward_strength = strength
	var result: Array = []
	if rounds.is_empty(): return result
	for turn in range(first, number):
		result.append(rounds.get(turn, {"round": turn, "action": "Pass", "lane": "", "cards": 0, "strength": 0, "ward_strength": 0}))
	return result

static func read(owner, pid: int) -> Dictionary:
	if pid not in [0, 1]: return Data.invalid("common_bot_player_invalid")
	var world: Dictionary = owner._presentation_world if owner.next_hook() == "submission_lock" else owner._world
	var data: Dictionary = world.data
	var zones: Dictionary = data.card_zones
	var rows: Array = world.entities.entities
	var by_id: Dictionary = {}
	for row in rows: by_id[row.id] = row
	var public: Array = rows.filter(func(row): return (row.kind != "card" or row.attributes.get("role") == "guard") and (row.owner == pid or not row.attributes.get("hidden", false)))
	var allowed: Dictionary = {}
	for key in ["ward_experiment", "tempo_experiment", "neutral_tears", "breach_lord", "sigils", "guard_public_limits", "orias_marks", "kanifous_prices", "kanifous_losses"]:
		if data.has(key): allowed[key] = data[key]
	allowed["veil_breaches"] = data.get("veil_breaches", {})
	allowed["monsters"] = data.get("monsters", {})
	if data.has("game_staging"):
		allowed["game_staging"] = data.game_staging.duplicate(true)
		for tray in allowed.game_staging.lanes.values():
			tray.units = tray.units.filter(func(unit): return unit.owner == pid)
	if not data.get("field_structures", []).is_empty():
		allowed["field_structures"] = data.field_structures.duplicate(true)
		allowed.field_structures.sort_custom(func(a, b): return a.id < b.id)
	allowed["guard_work"] = {"targets": data.guard_work.targets, "pairs": data.guard_work.pairs}
	allowed["invocation_rounds"] = data.dominion_rites.invocation_rounds
	allowed["vacant_counts"] = data.vacant_throne.counts
	var pending: Dictionary = data.game_economy.stockpile_pending
	var stockpile: Array = pending.card_ids.map(func(id): return by_id[id]) if not pending.is_empty() and pending.player_id == pid else []
	var result: Dictionary = {
		"player_id": pid, "round": owner.round_number(), "hook": owner.next_hook(),
		"players": world.players, "board": public, "data": allowed,
		"hand": zones.hands[pid].map(func(id): return by_id[id]),
		"market": zones.market.map(func(id): return by_id[id]), "stockpile": stockpile,
		"cooldowns": effects(owner._cooldowns.snapshot().locks, pid),
		"persistent": effects(owner._persistent.snapshot().active, pid),
		"pending": effects(owner._pending.snapshot().pending, pid)
	}
	var history: Array = opponent_history(owner._events._rows, pid, owner.round_number())
	if not history.is_empty(): result["opponent_history"] = history
	return result.duplicate(true)
