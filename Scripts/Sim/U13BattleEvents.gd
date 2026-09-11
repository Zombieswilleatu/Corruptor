class_name U13BattleEvents
extends RefCounted

const Allegiance = preload("res://Scripts/Sim/U13MarcherAllegiance.gd")
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
		"change_marcher_allegiance":
			var changed: Dictionary = Allegiance.change_marcher_allegiance(
				world,
				String(command.get("target_id", "")),
				command.get("new_owner"),
				round_number,
				hook
			)
			if changed.action == "invalid":
				return changed
			world = changed.world
			entities.restore(world.entities)
			details["entity_id"] = target.id
			details["previous_owner"] = changed.before.owner
			details["new_owner"] = changed.after.owner
			details["before"] = changed.before
			details["after"] = changed.after
			details["interrupted_duels"] = changed.interrupted_duels
			event_type = "MARCHER_ALLEGIANCE_CHANGED"
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
		"ruin_castle", "ruin_castle_hazard", "ruin_castle_fracture":
			if world.data.get("combat_profile") != "U13_CORE_ARTILLERY_COMBAT_V1":
				return Data.invalid("ruined_structure_profile_required")
			if (
				target.is_empty()
				or target.kind != "castle"
				or target.attributes.get("status") not in ["standing", "defunct"]
				or target.attributes.get("construction_state", "active") != "active"
			):
				return Data.invalid("castle_not_ruinable")
			var fracture: bool = command.kind == "ruin_castle_fracture"
			var hazard: bool = command.kind == "ruin_castle_hazard" or fracture
			if hazard:
				var source: Dictionary = entities.get_entity(String(command.get("source_id", "")))
				if (
					source.is_empty()
					or source.kind != "lord"
					or source.attributes.get("alive", true)
					or (not fracture and source.attributes.get("lord_id") != world.data.get("breach_lord"))
					or command.get("cause") != ("fracture" if fracture else "breach")
					or (fracture and (world.data.get("fracture_profile") != "U13_FRACTURE_V1" or source.owner != target.owner))
					or command.has("player_id")
				):
					return Data.invalid("castle_hazard_source_invalid")
			elif (
				not Data.is_integer(command.get("player_id"))
				or command.player_id not in [0, 1]
				or target.owner != 1 - int(command.player_id)
			):
				return Data.invalid("castle_ruination_attribution_invalid")
			details["castle"] = target.duplicate(true)
			# Environmental destruction has no credited attacker, even when
			# it hits the banished Lord's own Castle. It never earns Siege Souls.
			details["player_id"] = -1 if hazard else command.player_id
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
			if world.data.get("fracture_profile") == "U13_FRACTURE_V1":
				if not target.attributes.alive or command.get("fracture_target", "") not in ["", "subjects", "infrastructure"]:
					return Data.invalid("fracture_banishment_invalid")
				details["fracture_target"] = command.get("fracture_target", "")
				if target.attributes.has("threat"):
					target.attributes.threat = 0
			if command.has("attacker_id"):
				var attacker: Dictionary = entities.get_entity(String(command.attacker_id))
				if (
					attacker.is_empty()
					or attacker.kind != "lord"
					or attacker.owner != 1 - target.owner
					or not attacker.attributes.alive
					or not target.attributes.alive
					or hook != Timeline.COMBAT_RESOLUTION
					or command.get("attack_kind") != "Hunt"
				):
					return Data.invalid("banishment_attribution_invalid")
				details["attacker"] = attacker.duplicate(true)
				details["lord"] = target.duplicate(true)
				details["attack_kind"] = "Hunt"
			target.attributes["alive"] = false
			entities.update(target.id, target.owner, target.attributes)
			details["lord_id"] = target.id
			event_type = "LORD_BANISHED"
		"set_breach":
			if typeof(command.get("lord_id")) != TYPE_STRING:
				return Data.invalid("breach_lord_invalid")
			world.data["breach_lord"] = command.lord_id
			details["lord_id"] = command.lord_id
			if command.has("source_id"):
				var source: Dictionary = entities.get_entity(String(command.source_id))
				if (
					source.is_empty()
					or source.kind != "lord"
					or source.attributes.get("lord_id") != command.lord_id
					or source.attributes.get("alive", true)
				):
					return Data.invalid("breach_source_invalid")
				details["source_id"] = source.id
			event_type = "BREACH_CHANGED"
		"defeat_guard":
			if (
				target.is_empty()
				or target.kind != "card"
				or target.attributes.get("role") != "guard"
			):
				return Data.invalid("guard_missing")
			# Optional credited attack identity. Unattributed hazards keep their old
			# event shape and cannot masquerade as a Lord defeating a Guard.
			if command.has("attacker_id"):
				var attacker: Dictionary = entities.get_entity(String(command.attacker_id))
				if (
					attacker.is_empty()
					or attacker.kind != "lord"
					or attacker.owner != 1 - target.owner
					or hook != Timeline.COMBAT_RESOLUTION
					or command.get("attack_kind") not in ["Hunt", "Siege"]
					or (
						target.attributes.get("lane")
						!= ("Lord" if command.attack_kind == "Hunt" else "Castle")
					)
				):
					return Data.invalid("guard_attack_attribution_invalid")
				details["attacker"] = attacker.duplicate(true)
				details["attack_kind"] = command.attack_kind
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
			details["damage_dealt"] = int(command.damage)
			details["hp_before"] = int(target.attributes.hp)
			target.attributes.hp = maxi(0, int(target.attributes.hp) - int(command.damage))
			details["hp_after"] = int(target.attributes.hp)
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
