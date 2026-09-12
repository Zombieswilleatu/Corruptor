extends RefCounted

const Base = preload("res://Scripts/Sim/U13ValakScenario.gd")
const Content = preload("res://Scripts/Sim/U13Kanifous.gd")
const Decl = preload("res://Scripts/Sim/U13LordPowerDeclaration.gd")


static func world(opponent: String = "Gremory") -> Dictionary:
	var choices: Array = ["Keep", "Bastion", "SummoningCircle", "Stockpile", "SiegeEngine"]
	return loadout_world(["Kanifous", opponent], [choices, choices])


static func loadout_world(lords: Array, choices: Array) -> Dictionary:
	var base_lords: Array = lords.duplicate()
	for pid in range(base_lords.size()):
		if base_lords[pid] == "Kanifous":
			base_lords[pid] = "Gremory"
	var result: Dictionary = Base.loadout_world(base_lords, choices)
	if result.get("action") == "invalid":
		return result
	result.data["kanifous_profile"] = Content.Lamp.VERSION
	result.data["kanifous_objects"] = []
	result.data["kanifous_prices"] = []
	result.data["kanifous_losses"] = []
	result.data["kanifous_loss_round"] = 0
	var ids = Content.Ids.new()
	ids.restore(result.entities)
	for pid in [0, 1]:
		if lords[pid] == "Kanifous":
			result.players[pid].lord_id = "Kanifous"
			var lord: Dictionary = ids.get_entity(result.players[pid].lord_entity_id)
			lord.attributes.lord_id = "Kanifous"
			lord.attributes["threat"] = 0
			ids.update(lord.id, pid, lord.attributes)
	result.entities = ids.snapshot()
	preload("res://Scripts/Sim/U13RangedMarching.gd").configure(result)
	return result


static func source(pid: int, round_number: int, target: Dictionary, index: int = 0, power: String = "WishWealth") -> Dictionary:
	var rule: Dictionary = Content.rules()[power]
	return Decl.create(Content.MatchOwner.declaration_id(pid, round_number, index), pid, "Kanifous", power, round_number, rule.fire_hook, round_number, index, "public", target, {}, {})

static func enumerate(owner, pid: int) -> Dictionary:
	var result: Dictionary = Base.enumerate(owner, pid)
	var view: Dictionary = owner.player_view(pid, 0)
	if result.action == "invalid" or view.world.lord_ids[pid] != "Kanifous":
		return result
	result.powers = [source(pid, owner.round_number(), {})]
	for lane in ["Lord", "Castle"]:
		result.powers.append(source(pid, owner.round_number(), {"lane": lane}, 0, "WishPower"))
		result.powers.append(source(pid, owner.round_number(), {"kind": "guard_zone", "zone": lane}, 0, "WishResurrection"))
		for x in [600, 1200, 1800]:
			result.powers.append(source(pid, owner.round_number(), {"lane": lane, "field_position": {"x_fp": x, "y_fp": 300}}, 0, "WishDeath"))
	for row in view.world.entities:
		if Content.longevity_target(row, pid):
			result.powers.append(source(pid, owner.round_number(), {"entity_id": row.id}, 0, "WishLongevity"))
	return result

static func plan(owner, pid: int) -> Dictionary:
	if owner.player_view(pid, 0).world.lord_ids[pid] != "Kanifous":
		return Base.plan(owner, pid)
	return preload("res://Scripts/Sim/U13RandomLegal.gd").plan(owner, pid, Callable(preload("res://Scripts/Sim/U13KanifousScenario.gd"), "enumerate"))
