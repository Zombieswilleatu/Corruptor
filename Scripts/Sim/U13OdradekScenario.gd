extends RefCounted

const Base = preload("res://Scripts/Sim/U13OriasScenario.gd")
const Content = preload("res://Scripts/Sim/U13Odradek.gd")
const Decl = preload("res://Scripts/Sim/U13LordPowerDeclaration.gd")


static func world(opponent: String = "Gremory") -> Dictionary:
	var choices: Array = ["Keep", "Bastion", "SummoningCircle", "Stockpile", "SiegeEngine"]
	return loadout_world(["Odradek", opponent], [choices, choices])


static func loadout_world(lords: Array, choices: Array) -> Dictionary:
	var base_lords: Array = lords.duplicate()
	for pid in range(base_lords.size()):
		if base_lords[pid] == "Odradek":
			base_lords[pid] = "Gremory"
	var result: Dictionary = Base.loadout_world(base_lords, choices)
	if result.get("action") == "invalid":
		return result
	result.data["odradek_profile"] = Content.ODRADEK_POLICY
	result.data["reconfiguration_round"] = 0
	result.data["interlock_rounds"] = [0, 0]
	result.data["paradox_round"] = 0
	var entities = Content.Ids.new()
	entities.restore(result.entities)
	for pid in [0, 1]:
		result.players[pid].resources[Content.RESOURCE] = 0
		if lords[pid] == "Odradek":
			result.players[pid].lord_id = "Odradek"
			var lord: Dictionary = entities.get_entity(result.players[pid].lord_entity_id)
			lord.attributes.lord_id = "Odradek"
			lord.attributes["threat"] = 0
			entities.update(lord.id, pid, lord.attributes)
	result.entities = entities.snapshot()
	return result


static func source(
	pid: int,
	round_number: int,
	target: Dictionary,
	index: int = 0,
	power: String = Content.REDIRECT
) -> Dictionary:
	var rule: Dictionary = Content.rules()[power]
	return Decl.create(
		Content.MatchOwner.declaration_id(pid, round_number, index),
		pid,
		"Odradek",
		power,
		round_number,
		rule.fire_hook,
		round_number + int(rule.delay_rounds),
		index,
		"public",
		target,
		rule.cost
	)


static func enumerate(owner, player_id: int) -> Dictionary:
	var result: Dictionary = Base.enumerate(owner, player_id)
	if (
		result.action == "invalid"
		or owner.player_view(player_id, 0).world.lord_ids[player_id] != "Odradek"
	):
		return result
	result.powers = []
	var view: Dictionary = owner.player_view(player_id, 0)
	for entity in view.world.entities:
		if entity.kind == "marcher":
			for power in [Content.REDIRECT, Content.SHIFT]:
				result.powers.append(
					source(
						player_id,
						owner.round_number(),
						{
							"lane": entity.attributes.lane,
							"field_position":
							{"x_fp": entity.attributes.x_fp, "y_fp": entity.attributes.y_fp}
						},
						0,
						power
					)
				)
		elif entity.kind == "card" and entity.attributes.get("role") == "guard":
			result.powers.append(
				source(
					player_id,
					owner.round_number(),
					{
						"entity_id": entity.id,
						"owner_id": entity.owner,
						"lane": "Castle" if entity.attributes.lane == "Lord" else "Lord"
					},
					0,
					Content.FALSE_ORDERS
				)
			)
	for lane in Content.Space.LANES:
		for power in [Content.REDIRECT, Content.SHIFT]:
			result.powers.append(
				source(
					player_id,
					owner.round_number(),
					{"lane": lane, "field_position": {"x_fp": 1200, "y_fp": 300}},
					0,
					power
				)
			)
		result.powers.append(
			source(
				player_id,
				owner.round_number(),
				{"owner_id": 1 - player_id, "lane": lane},
				0,
				Content.INVERSION
			)
		)
	return result


# Tier-1 resource-aware sampling. Sometimes bank instead of spending the sole
# point on Redirect every round; otherwise build an affordable ordered cart.
static func plan(owner, player_id: int) -> Dictionary:
	var RandomLegal = preload("res://Scripts/Sim/U13RandomLegal.gd")
	var view: Dictionary = owner.player_view(player_id, 0)
	if view.world.lord_ids[player_id] != "Odradek":
		return RandomLegal.plan(
			owner,
			player_id,
			func(match_owner, pid: int) -> Dictionary: return enumerate(match_owner, pid)
		)
	var raw: Dictionary = enumerate(owner, player_id)
	if raw.action == "invalid":
		return raw
	var identity: String = "odradek-bot:%d:%d" % [owner.round_number(), player_id]
	var bank: bool = (
		int(Content.Rng.draw(owner.rng_seed(), identity, "BANK_RESOURCE", 0, 3).value) == 0
	)
	if bank:
		raw.powers = []
	var provider: Callable = func(_owner, _pid: int) -> Dictionary: return raw
	var base: Dictionary = RandomLegal.plan(owner, player_id, provider)
	if base.action == "invalid" or bank:
		return base
	var remaining: int = int(view.world.reconfiguration[player_id])
	for item in base.powers:
		remaining -= int(item.cost[Content.RESOURCE])
	for index in range(base.powers.size(), 4):
		if remaining == 0:
			break
		var candidates: Array = []
		for item in raw.powers:
			if int(item.cost[Content.RESOURCE]) > remaining:
				continue
			var extra: Dictionary = source(
				player_id, owner.round_number(), item.target, index, item.power_id
			)
			var draft: Array = base.powers.duplicate(true)
			draft.append(extra)
			if owner.preview_submission(player_id, draft, base.order).action != "invalid":
				candidates.append(extra)
		if candidates.is_empty():
			break
		candidates.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:
				return JSON.stringify(a, "", true) < JSON.stringify(b, "", true)
		)
		base.powers.append(
			candidates[int(
				(
					Content
					. Rng
					. draw(
						owner.rng_seed(),
						identity,
						"EXTRA_RECONFIGURATION",
						index,
						candidates.size()
					)
					. value
				)
			)]
		)
		remaining -= int(base.powers[-1].cost[Content.RESOURCE])
	return base
