extends SceneTree
const Ledger = preload("res://Prototype/U13/U13AftermathLedger.gd")
func _initialize() -> void:
	var world: Dictionary = {"souls": [4, 2], "personal_tears": [1, 0], "neutral_tears": 3, "lord_ids": ["Orias", "Gremory"]}
	var events: Array = [
		{"type": "CASTLE_DESTROYED", "data": {"round": 2, "player_id": -1, "castle": {"owner": 1, "attributes": {"castle_type": "Keep"}}}},
		{"type": "LORD_BANISHED", "data": {"round": 2, "attacker": {"owner": 0}, "lord": {"owner": 1, "attributes": {"lord_id": "Gremory"}}}},
		{"type": "PERSONAL_TEAR_CREATED", "data": {"round": 1, "player_id": 0, "amount": 99}},
		{"type": "MARCHER_SPAWNED", "data": {"owner": 1, "attributes": {"birth_round": 2, "suit": "Vulture", "lane": "Lord"}}}
	]
	var saved: Array = events.duplicate(true)
	var text: String = Ledger.render(world, events, 2, {"souls": [2, 3], "personal_tears": [0, 0], "neutral_tears": 2})
	var ok: bool = text.contains("(+2 net)") and text.contains("(-1 net)") and not text.contains("99") and text.find("Banished") < text.find("OPPONENT") and text.find("Destroyed") > text.find("SHARED") and text.contains("Raised Opponent's Vulture") and events == saved
	print(text)
	print("U13 aftermath ledger failures: ", 0 if ok else 1)
	quit(0 if ok else 1)
