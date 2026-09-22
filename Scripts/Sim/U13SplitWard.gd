extends RefCounted

# Explicit profile flags preserve old saves and archived replay semantics.
const VERSION: String = "U13_SPLIT_WARD_V1"
const TEMPO: String = "U13_VEIL_ATTACK_ROUND25_V1"
const SOUL_START_ROUND: int = 20

static func enabled(world: Dictionary) -> bool:
	return world.data.get("ward_experiment") == VERSION

static func tempo_enabled(world: Dictionary) -> bool:
	return world.data.get("tempo_experiment") == TEMPO

static func configure(world: Dictionary) -> void:
	world.data["ward_experiment"] = VERSION
	world.data["tempo_experiment"] = TEMPO
	world.data.sigils = [{"Lord": "", "Castle": ""}, {"Lord": "", "Castle": ""}]

static func valid(world: Dictionary) -> bool:
	if world.data.has("ward_experiment") and not enabled(world): return false
	if world.data.has("tempo_experiment") and (not enabled(world) or not tempo_enabled(world)): return false
	if enabled(world):
		for row in world.data.sigils:
			if row.Lord != "" or row.Castle != "": return false
	return true

static func ward(order: Dictionary) -> Dictionary:
	return order if order.get("action") == "Ward" else order.get("ward", {})

static func cards(order: Dictionary) -> Array:
	var result: Array = order.get("card_ids", []).duplicate() if typeof(order.get("card_ids", [])) == TYPE_ARRAY else []
	var part = order.get("ward", {})
	if typeof(part) == TYPE_DICTIONARY and typeof(part.get("card_ids", [])) == TYPE_ARRAY:
		result.append_array(part.get("card_ids", []))
	return result

static func attack_bonus(world: Dictionary) -> int:
	if not tempo_enabled(world): return 0
	var veil: int = world.data.neutral_tears
	for player in world.players: veil += int(player.resources.personal_tears)
	return int(veil >= 13) + int(veil >= 17) + int(veil >= 21)

static func succeeded(events: Array) -> bool:
	for i in range(events.size() - 1, -1, -1):
		var row: Dictionary = events[i].event
		if row.type == "HUNT_RESOLVED": return row.data.banished
		if row.type == "SIEGE_RESOLVED":
			return row.data.get("pillage_success", false) if row.data.get("pillage", false) else row.data.destroyed
	return false

static func public_event(kind: String, details: Dictionary) -> Dictionary:
	var row: Dictionary = {"type": kind, "text": "", "data": details}
	return {"event": row, "views": [row, row]}

static func reward(world: Dictionary, events: Array, pid: int, round_number: int, order: Dictionary, eligible: bool, would_succeed: bool) -> void:
	var saved: bool = eligible and would_succeed and not succeeded(events)
	if eligible:
		events.append(public_event("WARD_CONTESTED", {"player_id": 1 - pid, "attacker_id": pid, "round": round_number, "lane": order.lane, "target_id": order.target_id, "would_succeed_without_ward": would_succeed, "saved": saved}))
	if not world.data.has("ward_reward_rounds"): world.data["ward_reward_rounds"] = [0, 0]
	if saved and world.data.ward_reward_rounds[1 - pid] < round_number:
		world.data.ward_reward_rounds[1 - pid] = round_number
		world.players[1 - pid].resources.souls += 1
		events.append(public_event("WARD_SOUL_GAINED", {"player_id": 1 - pid, "round": round_number, "lane": order.lane, "amount": 1}))
	if not tempo_enabled(world) or round_number < SOUL_START_ROUND: return
	for i in range(events.size() - 1, -1, -1):
		var row: Dictionary = events[i].event
		if row.type not in ["HUNT_RESOLVED", "SIEGE_RESOLVED"]: continue
		var success: bool = row.data.get("banished", false) if row.type == "HUNT_RESOLVED" else (not row.data.get("pillage", false) and row.data.get("destroyed", false))
		if not success: return
		if not world.data.has("decisive_soul_rounds"): world.data["decisive_soul_rounds"] = [0, 0]
		if world.data.decisive_soul_rounds[pid] >= round_number: return
		world.data.decisive_soul_rounds[pid] = round_number
		world.players[pid].resources.souls += 1
		events.append(public_event("DECISIVE_SOUL_GAINED", {"player_id": pid, "round": round_number, "amount": 1, "target_id": row.data.target_id, "attack": "Hunt" if row.type == "HUNT_RESOLVED" else "Siege"}))
		return
