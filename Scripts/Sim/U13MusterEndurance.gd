extends RefCounted

const THRESHOLD: float = 25.0
const KEY: String = "humbaba_muster_endurance"

static func credit(world: Dictionary, target: Dictionary, attacker: Dictionary, hp_before: float, hp_after: float, projectile_block: bool, number: int, tick: int) -> Array:
	var a: Dictionary = target.get("attributes", {})
	if target.get("kind") != "marcher" or a.get("source_power_id") != "MusterTheFaithful" or a.get("suit") != "Penitent" or not a.has("source_effect_id") or hp_before <= 0:
		return []
	var pid: int = target.owner
	if attacker.get("owner") != 1 - pid or world.players[pid].lord_id != "Humbaba" or a.get("muster_owner", pid) != pid:
		return []
	var damage: float = maxf(0, minf(hp_before, hp_before - hp_after))
	var block: int = int(projectile_block)
	if damage + block <= 0: return []
	var group_id: String = a.source_effect_id
	if not world.data.has(KEY): world.data[KEY] = {}
	var groups: Dictionary = world.data[KEY]
	if not groups.has(group_id): groups[group_id] = {"owner": pid, "points": 0.0, "rewarded": false}
	var group: Dictionary = groups[group_id]
	if group.owner != pid or group.rewarded: return []
	group.points = snappedf(float(group.points) + damage + block, 0.00000001)
	var facts: Dictionary = {"player_id": pid, "effect_id": group_id, "round": number, "tick": tick, "points": group.points, "hp_damage": damage, "projectile_blocks": block, "source": "EnduranceOfTheFaithful"}
	var events: Array = [public_event("MUSTER_ENDURANCE_PROGRESS", facts)]
	var alive: bool = false
	for entity in world.entities.entities:
		if entity.id == world.players[pid].lord_entity_id:
			alive = entity.attributes.alive
			break
	if group.points >= THRESHOLD and alive:
		group.rewarded = true
		world.players[pid].resources.personal_tears += 1
		for kind in ["PERSONAL_TEAR_CREATED", "MUSTER_ENDURANCE_REWARDED"]:
			var reward: Dictionary = facts.duplicate(true)
			reward["amount"] = 1
			var event: Dictionary = public_event(kind, reward)
			event.event.text = "Endurance: Muster group earned 1 Personal Tear."
			for view in event.views: view.text = event.event.text
			events.append(event)
	return events

static func public_event(kind: String, data: Dictionary) -> Dictionary:
	var event: Dictionary = {"type": kind, "text": "", "data": data}
	return {"event": event, "views": [event, event]}
