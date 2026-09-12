extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const Throne = preload("res://Scripts/Sim/U13VacantThrone.gd")
const Rites = preload("res://Scripts/Sim/U13DominionRites.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const VERSION: String = "U13_VICTORY_V1"
# Carry forward Lab v6.5 thresholds and precedence; no legacy Humbaba Seal.
const RITUAL_SOULS: int = 12
const DOMINION_VEIL: int = 12
const DOMINION_TEARS: int = 5
const FINAL_COLLAPSE_VEIL: int = 26


static func configure(world: Dictionary) -> void:
	world.data["victory"] = {"version": VERSION, "checked_round": 0, "winner": -1, "win_by": ""}


static func evaluate(world: Dictionary) -> Dictionary:
	for pid in [0, 1]:
		if Throne.alive(world, pid) and world.players[pid].resources.souls >= RITUAL_SOULS:
			return {"winner": pid, "win_by": "Ritual"}
	var veil: int = Rites.veil(world)
	if veil >= FINAL_COLLAPSE_VEIL:
		var winner: int = 1 if world.players[1].resources.souls > world.players[0].resources.souls else 0
		return {"winner": winner, "win_by": "FinalCollapse"}
	if veil >= DOMINION_VEIL:
		for pid in [0, 1]:
			var tears: int = world.players[pid].resources.personal_tears
			if tears >= DOMINION_TEARS and tears > world.players[1 - pid].resources.personal_tears:
				return {"winner": pid, "win_by": "Dominion"}
	return {"winner": -1, "win_by": ""}


static func valid(world: Dictionary) -> bool:
	var state = world.data.get("victory")
	if typeof(state) != TYPE_DICTIONARY or state.size() != 4 or state.get("version") != VERSION:
		return false
	if not Data.is_integer(state.get("checked_round")) or state.checked_round < 0 or not Data.is_integer(state.get("winner")):
		return false
	if state.winner == -1:
		return state.get("win_by") == ""
	if state.winner not in [0, 1] or state.checked_round == 0:
		return false
	var expected: Dictionary = evaluate(world)
	return state.winner == expected.winner and state.get("win_by") == expected.win_by


# Only the final hook calls this, after both players' Vacant Throne rewards.
# No mid-round truncation: all sealed actions and Marching settle first.
static func finish(world: Dictionary, round_number: int) -> Dictionary:
	var state: Dictionary = world.data.victory
	if state.winner != -1 or state.checked_round != round_number - 1:
		return Data.invalid("victory_already_resolved")
	state.merge(evaluate(world), true)
	state.checked_round = round_number
	var events: Array = []
	if state.winner != -1:
		events.append(Marching.public_event("MATCH_FINISHED", {
			"round": round_number, "winner": state.winner, "win_by": state.win_by,
			"souls": [world.players[0].resources.souls, world.players[1].resources.souls],
			"personal_tears": [world.players[0].resources.personal_tears, world.players[1].resources.personal_tears],
			"veil_total": Rites.veil(world)
		}))
	return {"action": "resolved", "world": world, "events": events}


static func snapshot_valid(context: Dictionary) -> bool:
	var state: Dictionary = context.world.data.victory
	var complete: bool = context.next_hook_index > Timeline.hook_rank(Timeline.AFTERMATH)
	if state.checked_round != context.round - (0 if complete else 1):
		return false
	if state.winner != -1 and not complete:
		return false
	if complete:
		var expected: Dictionary = evaluate(context.world)
		return state.winner == expected.winner and state.win_by == expected.win_by
	return true
