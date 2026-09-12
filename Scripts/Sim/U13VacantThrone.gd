extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const VERSION: String = "U13_VACANT_THRONE_V1"
const GRACE_ROUNDS: int = 2


static func configure(world: Dictionary) -> void:
	world.data["vacant_throne"] = {"version": VERSION, "round": 0, "completed_round": 0, "prior_counts": [0, 0], "counts": [0, 0], "present": [false, false]}


static func alive(world: Dictionary, pid: int) -> bool:
	for entity in world.entities.entities:
		if entity.id == world.players[pid].lord_entity_id:
			return bool(entity.attributes.alive)
	return false


static func valid(world: Dictionary) -> bool:
	var state = world.data.get("vacant_throne")
	if typeof(state) != TYPE_DICTIONARY or state.size() != 6 or state.get("version") != VERSION:
		return false
	for key in ["round", "completed_round"]:
		if not Data.is_integer(state.get(key)) or state[key] < 0:
			return false
	if state.completed_round not in [state.round, state.round - 1]:
		return false
	for key in ["prior_counts", "counts", "present"]:
		if typeof(state.get(key)) != TYPE_ARRAY or state[key].size() != 2:
			return false
	for pid in [0, 1]:
		if typeof(state.present[pid]) != TYPE_BOOL:
			return false
		for key in ["prior_counts", "counts"]:
			if not Data.is_integer(state[key][pid]) or state[key][pid] < 0 or state[key][pid] > state.round:
				return false
		if state.round == 0:
			if state.present[pid] or state.counts[pid] != 0 or state.prior_counts[pid] != 0:
				return false
		else:
			var expected: int = state.prior_counts[pid]
			if state.completed_round == state.round:
				expected = 0 if state.present[pid] else expected + 1
			if state.counts[pid] != expected:
				return false
	return true


# Called before ordinary round work. A banishment reaction can also open this
# ledger if a scheduled effect removes a Lord before the first ordinary hook.
static func begin(world: Dictionary, round_number: int) -> bool:
	var state: Dictionary = world.data.vacant_throne
	if state.round == round_number:
		return state.completed_round == round_number - 1
	if state.round != round_number - 1 or state.completed_round != state.round:
		return false
	state.round = round_number
	state.prior_counts = state.counts.duplicate()
	state.present = [alive(world, 0), alive(world, 1)]
	return true


static func note_banishment(world: Dictionary, fact: Dictionary) -> bool:
	var pid: int = -1
	for player in [0, 1]:
		if world.players[player].lord_entity_id == fact.data.get("lord_id"):
			pid = player
	if pid == -1 or not begin(world, int(fact.data.round)):
		return false
	# Banishment is proof of earlier presence, even if no ordinary hook saw it.
	world.data.vacant_throne.present[pid] = true
	return true


static func observe(world: Dictionary) -> void:
	for pid in [0, 1]:
		if alive(world, pid):
			world.data.vacant_throne.present[pid] = true


static func finish(world: Dictionary, round_number: int) -> Dictionary:
	var state: Dictionary = world.data.vacant_throne
	if state.round != round_number or state.completed_round != round_number - 1:
		return Data.invalid("vacant_throne_already_resolved")
	observe(world)
	var events: Array = []
	# Both counters settle before any later victory evaluator runs. A recipient
	# can be absent too; the living-Lord Ritual gate belongs to that evaluator.
	for pid in [0, 1]:
		var count: int = 0 if state.present[pid] else state.prior_counts[pid] + 1
		var gain: int = 1 if count > GRACE_ROUNDS else 0
		state.counts[pid] = count
		if gain:
			world.players[1 - pid].resources.souls += gain
		events.append(Marching.public_event("VACANT_THRONE_RESOLVED", {
			"round": round_number, "player_id": pid,
			"lord_present_this_round": state.present[pid],
			"vacant_rounds_before": state.prior_counts[pid], "vacant_rounds_after": count,
			"grace_rounds": GRACE_ROUNDS, "soul_gain": gain,
			"soul_recipient": 1 - pid if gain else -1,
			"reason": "lord_present_this_round" if state.present[pid] else "vacant_round"
		}))
	state.completed_round = round_number
	return {"action": "resolved", "world": world, "events": events}


static func snapshot_valid(context: Dictionary) -> bool:
	var state: Dictionary = context.world.data.vacant_throne
	var cursor: int = context.next_hook_index
	var current: int = context.round
	if state.round != current - (1 if cursor == 0 else 0):
		return false
	if state.completed_round != current - (1 if cursor <= Timeline.hook_rank(Timeline.AFTERMATH) else 0):
		return false
	if cursor > Timeline.hook_rank(Timeline.PRESENT_PUBLIC_STATE):
		var prior: Dictionary = context.presentation_world.data.vacant_throne
		if state.prior_counts != prior.prior_counts:
			return false
		for pid in [0, 1]:
			var returned: bool = context.world.data.summon_counts[pid] > context.presentation_world.data.summon_counts[pid]
			if state.present[pid] != (prior.present[pid] or returned):
				return false
	return true
