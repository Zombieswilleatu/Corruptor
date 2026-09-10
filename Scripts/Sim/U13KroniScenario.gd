extends RefCounted

const Base = preload("res://Scripts/Sim/U13OdradekScenario.gd")
const Content = preload("res://Scripts/Sim/U13Kroni.gd")
const Decl = preload("res://Scripts/Sim/U13LordPowerDeclaration.gd")


static func world(opponent: String = "Gremory") -> Dictionary:
	var choices: Array = ["Keep", "Bastion", "SummoningCircle", "Stockpile", "SiegeEngine"]
	return loadout_world(["Kroni", opponent], [choices, choices])


static func loadout_world(lords: Array, choices: Array) -> Dictionary:
	var base_lords: Array = lords.duplicate()
	for pid in range(base_lords.size()):
		if base_lords[pid] == "Kroni":
			base_lords[pid] = "Gremory"
	var result: Dictionary = Base.loadout_world(base_lords, choices)
	if result.get("action") == "invalid":
		return result
	result.data["kroni_profile"] = Content.KRONI_POLICY
	result.data["kroni_feed_round"] = 0
	result.data["kroni_action_round"] = 0
	result.data["kroni_breach_round"] = 0
	result.data["kroni_fed"] = [0, 0]
	result.data["kroni_actors"] = []
	var ids = Content.Ids.new()
	ids.restore(result.entities)
	for pid in [0, 1]:
		if lords[pid] == "Kroni":
			result.players[pid].lord_id = "Kroni"
			var lord: Dictionary = ids.get_entity(result.players[pid].lord_entity_id)
			lord.attributes.lord_id = "Kroni"
			lord.attributes["threat"] = 0
			lord.attributes["hunger"] = 0
			lord.attributes["hunger_milestone"] = false
			ids.update(lord.id, pid, lord.attributes)
	result.entities = ids.snapshot()
	return result


static func source(pid: int, round_number: int, target: Dictionary = {}, index: int = 0, power: String = Content.RAVENOUS) -> Dictionary:
	if power == Content.RAVENOUS and target.is_empty():
		target = {"lane": "Lord", "field_position": {"x_fp": 0 if pid == 0 else 2400, "y_fp": 300}}
	var rule: Dictionary = Content.rules()[power]
	return Decl.create(Content.MatchOwner.declaration_id(pid, round_number, index), pid, "Kroni", power, round_number, rule.fire_hook, round_number + int(rule.delay_rounds), index, "public", target, rule.cost)


static func enumerate(owner, pid: int) -> Dictionary:
	var result: Dictionary = Base.enumerate(owner, pid)
	var view: Dictionary = owner.player_view(pid, 0)
	if result.action == "invalid" or view.world.lord_ids[pid] != "Kroni":
		return result
	result.powers = []
	# Position candidates only: bots cannot inspect or choose the launch angle.
	for lane in ["Lord", "Castle"]:
		for lateral in [0, 150, 300, 450, 600]:
			result.powers.append(source(pid, owner.round_number(), {"lane": lane, "field_position": {"x_fp": 0 if pid == 0 else 2400, "y_fp": lateral}}))
	for row in view.world.entities:
		if row.kind == "card" and row.owner == 1 - pid and row.attributes.get("role") == "guard":
			result.powers.append(source(pid, owner.round_number(), {"entity_id": row.id}, 0, Content.CONSUME))
	return result


static func plan(owner, pid: int) -> Dictionary:
	if owner.player_view(pid, 0).world.lord_ids[pid] == "Odradek":
		return Base.plan(owner, pid)
	return preload("res://Scripts/Sim/U13RandomLegal.gd").plan(owner, pid, Callable(preload("res://Scripts/Sim/U13KroniScenario.gd"), "enumerate"))
