extends RefCounted

const Content = preload("res://Scripts/Sim/U13Valak.gd")


static func lines(view: Dictionary, pid: int) -> PackedStringArray:
	var world: Dictionary = view.world
	var lord: String = world.get("lord_ids", ["Gremory", "Gremory"])[pid]
	var alive: bool = true
	for entity in world.entities:
		if entity.kind == "lord" and entity.owner == pid:
			alive = entity.attributes.alive
	var result := PackedStringArray()
	var rules: Dictionary = Content.rules()
	for power in rules:
		var rule: Dictionary = rules[power]
		if rule.lord_id != lord:
			continue
		var status: String = "Ready"
		var ready_round: int = int(view.round)
		var active: bool = false
		var firing: int = 0
		for clock in view.get("cooldowns", []):
			if not _matches(clock, pid, power):
				continue
			ready_round = maxi(ready_round, int(clock.get("ready_round", 0)))
			if clock.get("phase") == "awaiting_expiration":
				active = true
				for effect in view.get("persistent", []):
					if _matches(effect, pid, power):
						ready_round = maxi(ready_round, int(effect.activated_round) + effect.stages.size() + int(clock.cooldown_rounds))
		for pending in view.get("pending", []):
			if _matches(pending, pid, power):
				firing = int(pending.declaration.fire_round)
		if ready_round > int(view.round):
			status = "Round %d" % ready_round
		elif active:
			status = "Active"
		if firing > 0:
			status = "Fires round %d" % firing
		if status == "Ready":
			if not alive:
				status = "Banished"
			elif power == "Projection" and int(world.get("life_essence", [0, 0])[pid]) == 0:
				status = "Needs Essence"
			elif rule.cost.has("reconfiguration") and int(world.get("reconfiguration", [0, 0])[pid]) < int(rule.cost.reconfiguration):
				status = "Needs %d Reconfig" % rule.cost.reconfiguration
		var title: String = String(power).capitalize()
		if power == "Web":
			title = "Entanglement"
		result.append("%s: %s" % [title, status])
	return result


static func _matches(row: Dictionary, pid: int, power: String) -> bool:
	var source: Dictionary = row.get("declaration", {})
	return source.get("player_id") == pid and source.get("power_id") == power
