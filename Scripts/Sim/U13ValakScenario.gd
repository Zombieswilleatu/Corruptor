extends RefCounted

const Base = preload("res://Scripts/Sim/U13KroniScenario.gd")
const Content = preload("res://Scripts/Sim/U13Valak.gd")
const Decl = preload("res://Scripts/Sim/U13LordPowerDeclaration.gd")


static func world(opponent: String = "Gremory") -> Dictionary:
	var choices: Array = ["Keep", "Bastion", "SummoningCircle", "Stockpile", "SiegeEngine"]
	return loadout_world(["Valak", opponent], [choices, choices])


static func loadout_world(lords: Array, choices: Array) -> Dictionary:
	var base_lords: Array = lords.duplicate()
	for pid in range(base_lords.size()):
		if base_lords[pid] == "Valak":
			base_lords[pid] = "Gremory"
	var result: Dictionary = Base.loadout_world(base_lords, choices)
	if result.get("action") == "invalid":
		return result
	result.data["valak_profile"] = Content.Essence.VERSION
	result.data["valak_reserved"] = [0, 0]
	result.data["valak_orbs"] = []
	var ids = Content.Ids.new()
	ids.restore(result.entities)
	for pid in [0, 1]:
		result.players[pid].resources[Content.Essence.RESOURCE] = 0
		if lords[pid] == "Valak":
			result.players[pid].lord_id = "Valak"
			var lord: Dictionary = ids.get_entity(result.players[pid].lord_entity_id)
			lord.attributes.lord_id = "Valak"
			lord.attributes["threat"] = 0
			ids.update(lord.id, pid, lord.attributes)
	result.entities = ids.snapshot()
	return result


static func source(pid: int, round_number: int, target: Dictionary, index: int = 0, power: String = Content.ORB, spend: int = 0) -> Dictionary:
	var rule: Dictionary = Content.rules()[power]
	return Decl.create(Content.MatchOwner.declaration_id(pid, round_number, index), pid, "Valak", power, round_number, rule.fire_hook, round_number, index, "public", target, {}, {"spend": spend} if power == Content.PROJECTION else {})


static func enumerate(owner, pid: int) -> Dictionary:
	var result: Dictionary = Base.enumerate(owner, pid)
	var view: Dictionary = owner.player_view(pid, 0)
	if result.action == "invalid" or view.world.lord_ids[pid] != "Valak":
		return result
	result.powers = []
	for zone in ["Lord", "Castle"]:
		for spend in range(1, int(view.world.life_essence[pid]) + 1):
			result.powers.append(source(pid, owner.round_number(), {"kind": "guard_zone", "player_id": 1 - pid, "zone": zone}, 0, Content.PROJECTION, spend))
		for forward in [600, 1200, 1800]:
			for lateral in [150, 300, 450]:
				result.powers.append(source(pid, owner.round_number(), {"lane": zone, "field_position": {"x_fp": forward, "y_fp": lateral}}))
	return result


static func plan(owner, pid: int) -> Dictionary:
	if owner.player_view(pid, 0).world.lord_ids[pid] != "Valak":
		return Base.plan(owner, pid)
	return preload("res://Scripts/Sim/U13RandomLegal.gd").plan(owner, pid, Callable(preload("res://Scripts/Sim/U13ValakScenario.gd"), "enumerate"))
