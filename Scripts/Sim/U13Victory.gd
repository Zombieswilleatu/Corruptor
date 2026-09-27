extends RefCounted

const SplitWard = preload("res://Scripts/Sim/U13SplitWard.gd")
const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const Throne = preload("res://Scripts/Sim/U13VacantThrone.gd")
const Rites = preload("res://Scripts/Sim/U13DominionRites.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const VERSION: String = "U13_VICTORY_V2_ROUND_PRESSURE"
# Baseline adopted 2026-09-23: 15 Souls / 7 personal Tears; simultaneous Ritual uses the full checkdown.
const RITUAL_SOULS: int = 15
const DOMINION_VEIL: int = 12
const DOMINION_TEARS: int = 7
const FINAL_COLLAPSE_VEIL: int = 26
const ROUND_LIMIT: int = 20


static func configure(world: Dictionary) -> void:
	world.data["victory"] = {"version": VERSION, "checked_round": 0, "winner": -1, "win_by": "", "round_limit": ROUND_LIMIT}


# Saves without this field retain their original deadline.
static func round_limit(state: Dictionary) -> int:
	return int(state.get("round_limit", 25))


static func deadline_winner(world: Dictionary) -> int:
	# Archived saves retain their original adjudication rules.
	if not world.data.get("victory", {}).has("round_limit"):
		return 1 if world.players[1].resources.souls > world.players[0].resources.souls else 0
	return tiebreak_winner(world)


# Seat position is the final fallback after all four comparisons tie.
static func tiebreak_winner(world: Dictionary) -> int:
	var scores: Array = []
	for pid in [0, 1]:
		var castles: int = 0
		for row in world.entities.entities:
			if row.kind == "castle" and row.owner == pid and row.attributes.status == "standing" and row.attributes.construction_state == "active" and row.attributes.integrity > 0:
				castles += 1
		scores.append([int(world.players[pid].resources.souls), int(world.players[pid].resources.personal_tears), castles, int(Throne.alive(world, pid))])
	for index in range(4):
		if scores[0][index] != scores[1][index]: return 1 if scores[1][index] > scores[0][index] else 0
	return 0


static func evaluate(world: Dictionary, round_number: int = 0) -> Dictionary:
	var ritual: Array[int] = []
	for pid in [0, 1]:
		if Throne.alive(world, pid) and world.players[pid].resources.souls >= RITUAL_SOULS:
			ritual.append(pid)
	if not ritual.is_empty():
		return {"winner": ritual[0] if ritual.size() == 1 else tiebreak_winner(world), "win_by": "Ritual"}
	var veil: int = Rites.veil(world)
	if not SplitWard.tempo_enabled(world) and veil >= FINAL_COLLAPSE_VEIL:
		var winner: int = deadline_winner(world)
		return {"winner": winner, "win_by": "FinalCollapse"}
	if veil >= DOMINION_VEIL:
		for pid in [0, 1]:
			var tears: int = world.players[pid].resources.personal_tears
			if tears >= DOMINION_TEARS and tears > world.players[1 - pid].resources.personal_tears:
				return {"winner": pid, "win_by": "Dominion"}
	if SplitWard.tempo_enabled(world) and round_number >= round_limit(world.data.get("victory", {})):
		return {"winner": deadline_winner(world), "win_by": "RoundLimit"}
	return {"winner": -1, "win_by": ""}


static func valid(world: Dictionary) -> bool:
	var state = world.data.get("victory")
	if typeof(state) != TYPE_DICTIONARY or state.size() not in [4, 5] or state.get("version") != VERSION:
		return false
	if state.has("round_limit") and (not Data.is_integer(state.round_limit) or state.round_limit not in [20, 25]): return false
	if state.size() == 5 and not state.has("round_limit"): return false
	if not Data.is_integer(state.get("checked_round")) or state.checked_round < 0 or not Data.is_integer(state.get("winner")):
		return false
	if state.winner == -1:
		return state.get("win_by") == ""
	if state.winner not in [0, 1] or state.checked_round == 0:
		return false
	var expected: Dictionary = evaluate(world, state.checked_round)
	return state.winner == expected.winner and state.get("win_by") == expected.win_by


static func neutral_pressure(round_number: int) -> int:
	return 2 if round_number > 20 else (1 if round_number > 12 else 0)


# Only the final hook calls this, after both players' Vacant Throne rewards.
# No mid-round truncation: all sealed actions and Marching settle first.
static func finish(world: Dictionary, round_number: int) -> Dictionary:
	var state: Dictionary = world.data.victory
	if state.winner != -1 or state.checked_round != round_number - 1:
		return Data.invalid("victory_already_resolved")
	var events: Array = []
	var gain: int = neutral_pressure(round_number)
	if gain > 0:
		world.data.neutral_tears += gain
		events.append(Marching.public_event("NEUTRAL_TEAR_CREATED", {
			"round": round_number, "amount": gain, "source": "RoundPressure"
		}))
	state.merge(evaluate(world, round_number), true)
	state.checked_round = round_number
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
		var expected: Dictionary = evaluate(context.world, context.round)
		return state.winner == expected.winner and state.win_by == expected.win_by
	return true

