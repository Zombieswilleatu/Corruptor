class_name U13BattleEvents
extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")


# Authoritative transition boundary, not a contact finder or damage calculator.
# Marching/combat adapters supply already-resolved damage. Facts retain attribution
# before removal so rewards do not guess from a missing entity or an event label.
static func apply(
	raw: Dictionary, command: Dictionary, round_number: int, hook: String = ""
) -> Dictionary:
	if (
		not Data.is_data(command)
		or typeof(command.get("command_id")) != TYPE_STRING
		or command.command_id.is_empty()
	):
		return Data.invalid("battle_command_id_required")
	var world: Dictionary = raw.duplicate(true)
	var used: Dictionary = world.data.get("battle_commands", {}).duplicate(true)
	var event_id: String = Data.instance_id("battle", str(round_number), command.command_id)
	if used.has(event_id):
		return Data.invalid("battle_command_already_applied")
	var entities = Ids.new()
	if entities.restore(world.entities).action == "invalid":
		return Data.invalid("battle_entities_invalid")
	var target: Dictionary = entities.get_entity(String(command.get("target_id", "")))
	var details: Dictionary = {"event_id": event_id, "round": round_number, "hook": hook}
	var event_type: String = ""
	match command.get("kind"):
		"destroy_castle":
			if (
				target.is_empty()
				or target.kind != "castle"
				or target.attributes.get("construction_state", "active") != "active"
			):
				return Data.invalid("castle_missing")
			details["castle"] = target
			entities.retire(target.id)
			event_type = "CASTLE_DESTROYED"
		"ruin_castle":
			if world.data.get("combat_profile") != "U13_CORE_ARTILLERY_COMBAT_V1":
				return Data.invalid("ruined_structure_profile_required")
			if (
				target.is_empty()
				or target.kind != "castle"
				or target.attributes.get("status") not in ["standing", "defunct"]
				or target.attributes.get("construction_state", "active") != "active"
			):
				return Data.invalid("castle_not_ruinable")
			if (
				not Data.is_integer(command.get("player_id"))
				or command.player_id not in [0, 1]
				or target.owner != 1 - int(command.player_id)
			):
				return Data.invalid("castle_ruination_attribution_invalid")
			details["castle"] = target.duplicate(true)
			details["player_id"] = command.player_id
			details["cause"] = command.get("cause", "siege")
			details["source_id"] = command.get("source_id", "")
			target.attributes.integrity = 0
			target.attributes.status = "ruined"
			target.attributes.artillery_target = ""
			entities.update(target.id, target.owner, target.attributes)
			if (
				world.data.has("construction_targets")
				and world.data.construction_targets[target.owner] == target.id
			):
				world.data.construction_targets[target.owner] = ""
			event_type = "CASTLE_DESTROYED"
		"repair_castle":
			if (
				target.is_empty()
				or target.kind != "castle"
				or target.attributes.get("construction_state", "active") != "active"
				or not Data.is_integer(target.attributes.get("max_integrity"))
			):
				return Data.invalid("castle_missing")
			target.attributes["integrity"] = target.attributes.max_integrity
			target.attributes["status"] = "standing"
			entities.update(target.id, target.owner, target.attributes)
			details["castle_id"] = target.id
			event_type = "CASTLE_RESTORED"
		"banish_lord":
			if target.is_empty() or target.kind != "lord":
				return Data.invalid("lord_missing")
			target.attributes["alive"] = false
			entities.update(target.id, target.owner, target.attributes)
			details["lord_id"] = target.id
			event_type = "LORD_BANISHED"
		"set_breach":
			if typeof(command.get("lord_id")) != TYPE_STRING:
				return Data.invalid("breach_lord_invalid")
			world.data["breach_lord"] = command.lord_id
			details["lord_id"] = command.lord_id
			event_type = "BREACH_CHANGED"
		"defeat_guard":
			if (
				target.is_empty()
				or target.kind != "card"
				or target.attributes.get("role") != "guard"
			):
				return Data.invalid("guard_missing")
			details["guard"] = target.duplicate(true)
			target.attributes["role"] = "card"
			entities.update(target.id, -1, target.attributes)
			world.data.card_zones.discard.append(target.id)
			event_type = "GUARD_DEFEATED"
		"marcher_damage":
			if (
				target.is_empty()
				or target.kind != "marcher"
				or not Data.is_integer(target.attributes.get("hp"))
			):
				return Data.invalid("marcher_missing")
			if (
				not Data.is_integer(command.get("damage"))
				or command.damage < 0
				or command.get("cause") not in ["combat", "hazard"]
			):
				return Data.invalid("damage_invalid")
			var attacker: Dictionary = entities.get_entity(String(command.get("attacker_id", "")))
			if command.cause == "combat":
				if hook != Timeline.MARCHING:
					return Data.invalid("marching_combat_hook_required")
				if (
					attacker.is_empty()
					or attacker.kind != "marcher"
					or attacker.owner != 1 - target.owner
					or attacker.attributes.get("lane") != target.attributes.get("lane")
					or attacker.attributes.get("hp", 0) <= 0
				):
					return Data.invalid("combat_attribution_invalid")
			details["victim"] = target.duplicate(true)
			details["attacker"] = attacker
			details["cause"] = command.cause
			target.attributes.hp = maxi(0, int(target.attributes.hp) - int(command.damage))
			if target.attributes.hp == 0:
				entities.retire(target.id)
				event_type = "MARCHER_DEFEATED"
			else:
				entities.update(target.id, target.owner, target.attributes)
				event_type = "MARCHER_DAMAGED"
		_:
			return Data.invalid("battle_command_unknown")
	used[event_id] = true
	world.data["battle_commands"] = used
	world.entities = entities.snapshot()
	return {
		"action": "resolved",
		"world": world,
		"event": {"type": event_type, "text": "", "data": details}
	}
