extends "res://Scripts/Sim/U13GameConductor.gd"
const HotContent = preload("res://Scripts/Sim/U13HotseatContent.gd")

func start(seed_value: String, lords: Array, castles: Array, compact_events: bool = false, promoted_rules: bool = false, defensive_pressure: bool = true) -> Dictionary:
	if _owner != null or lords.size() != 2 or castles.size() != 2: return Data.invalid("game_setup_invalid")
	for pid in [0, 1]:
		if lords[pid] not in LORDS or not Slots.selection_valid(castles[pid]): return Data.invalid("game_loadout_invalid")
	var schema: Dictionary = Scenario.loadout_world(lords, castles)
	if schema.get("action") == "invalid": return schema
	var opening: Dictionary = Economy.initialize(schema, seed_value)
	if opening.action == "invalid": return opening
	Content.Staging.configure(opening.world)
	if promoted_rules:
		Content.SplitWard.configure(opening.world)
		if defensive_pressure: preload("res://Scripts/Sim/U13Embolden.gd").configure(opening.world)
	HotContent.HotEconomy.initialize(opening.world)
	var candidate = HotContent.new().create_combat_match(compact_events)
	var result: Dictionary = candidate.start(seed_value, opening.world, [0, 1])
	if result.action != "invalid": _owner = candidate
	return result

func to_planning(_random_choices: bool = false) -> Dictionary:
	if _owner == null: return Data.invalid("game_not_started")
	while true:
		if is_finished(): return outcome()
		var flow: Dictionary = _flow_view(0)
		var pending: Dictionary = flow.game_economy.stockpile_pending
		if not pending.is_empty(): return {"action": "game_draw_choice", "player_id": pending.player_id}
		if flow.game_market.seat != 2: return {"action": "game_market_choice", "player_id": flow.game_market.seat}
		if _owner.next_hook() == Timeline.SUBMISSION_LOCK: return {"action": "game_planning", "round": _owner.round_number()}
		if _owner.next_hook().is_empty(): return Data.invalid("game_round_complete")
		var result: Dictionary = step()
		if result.action == "invalid": return result
	return Data.invalid("game_planning_unreachable")

func restore(raw: Dictionary) -> Dictionary:
	var candidate = HotContent.new().create_combat_match(false)
	var result: Dictionary = candidate.restore(raw)
	if result.action != "invalid": _owner = candidate
	return result
