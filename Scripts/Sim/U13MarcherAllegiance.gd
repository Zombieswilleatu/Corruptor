extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const VERSION: String = "U13_MARCHER_ALLEGIANCE_V1"


# Shared transition for Odradek's Step 10C powers. Never edit an active Marching
# buffer: contact grids and aura eligibility are rebuilt at the next Marching.
# World ownership is authoritative; identity encodes birth, not current owner.
static func change_marcher_allegiance(
	raw: Dictionary, entity_id: String, new_owner, round_number: int, hook: String
) -> Dictionary:
	if hook != Timeline.POST_RESOLUTION_ALLEGIANCE or round_number < 1:
		return Data.invalid("allegiance_hook_invalid")
	if not Data.is_integer(new_owner) or new_owner not in [0, 1]:
		return Data.invalid("allegiance_owner_invalid")
	if not Data.is_data(raw):
		return Data.invalid("allegiance_world_invalid")
	var world: Dictionary = Data.copy_data(raw)
	var entities = Ids.new()
	if entities.restore(world.entities).action == "invalid":
		return Data.invalid("allegiance_registry_invalid")
	var unit: Dictionary = entities.get_entity(entity_id)
	if unit.is_empty() or unit.kind != "marcher" or unit.attributes.get("hp", 0) <= 0:
		return Data.invalid("allegiance_marcher_missing")
	if unit.owner == new_owner:
		return Data.invalid("allegiance_owner_unchanged")
	var before: Dictionary = unit.duplicate(true)
	var interrupted: Array = []
	var duels = world.data.get("marching_duels", {})
	if typeof(duels) != TYPE_DICTIONARY:
		return Data.invalid("allegiance_duels_invalid")
	# Cached duel records retain historical owners and sides. End the entire
	# encounter instead of relabeling an old exchange as a new friendly fight.
	for lane in duels.keys():
		var duel = duels[lane]
		if typeof(duel) != TYPE_DICTIONARY or typeof(duel.get("units")) != TYPE_ARRAY:
			return Data.invalid("allegiance_duels_invalid")
		var members: Array = []
		for member in duel.units:
			if typeof(member) != TYPE_DICTIONARY or typeof(member.get("id")) != TYPE_STRING:
				return Data.invalid("allegiance_duels_invalid")
			members.append(member.id)
		if entity_id not in members:
			continue
		interrupted.append(duel.get("id", ""))
		for id in members:
			var participant: Dictionary = entities.get_entity(id)
			if not participant.is_empty():
				participant.attributes.contact_tick = -1
				entities.update(id, participant.owner, participant.attributes)
		duels.erase(lane)
	if world.data.has("marching_duels"):
		world.data.marching_duels = duels
	unit.attributes.direction = 1 if new_owner == 0 else -1
	# A waiter at its former enemy gate is now at its own gate. It must travel
	# again; clearing eligibility also removes its old owner's Hunt support.
	unit.attributes.waiting = false
	unit.attributes.waiting_since_round = 0
	unit.attributes.contact_tick = -1
	entities.update(entity_id, int(new_owner), unit.attributes)
	world.entities = entities.snapshot()
	return {
		"action": "resolved",
		"world": world,
		"before": before,
		"after": entities.get_entity(entity_id),
		"interrupted_duels": interrupted
	}
