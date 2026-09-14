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
	var ok: bool = text.contains("(+2 net)") and text.contains("(-1 net)") and not text.contains("99") and text.find("Banished") < text.find("OPPONENT") and text.find("Destroyed") > text.find("SHARED") and not text.contains("Raised") and events == saved
	var siege: Dictionary = {"type": "SIEGE_RESOLVED", "data": {"round": 2, "player_id": 0, "target_id": "keep", "damage": 0}}
	var hits: Array = [
		{"type": "BASTION_SCREENED", "data": {"round": 2, "player_id": 1, "target_id": "keep", "damage": 4}},
		{"type": "BASTION_SCREENED", "data": {"round": 1, "player_id": 1, "target_id": "keep", "damage": 99}},
		{"type": "BASTION_SCREENED", "data": {"round": 2, "player_id": 0, "target_id": "keep", "damage": 99}},
		{"type": "BASTION_SCREENED", "data": {"round": 2, "player_id": 1, "target_id": "other", "damage": 99}}, siege]
	var result: String = Ledger.render(world, hits, 2)
	ok = ok and result.contains("Bastion interposed and took 4 damage") and not result.contains("0 Castle damage") and result.find("Bastion interposed") < result.find("OPPONENT")
	siege.data.damage = 2
	result = Ledger.render(world, hits, 2)
	ok = ok and result.contains("original target took 2 damage")
	var actions: Array = []
	for action in ["Siege", "Hunt", "Ward"]:
		actions.append({"type": "COMBAT_ORDER_REVEALED", "data": {"round": 2, "player_id": 1, "order": {"action": action}}})
	actions.append({"type": "POWER_RESOLVED", "data": {"round": 2, "player_id": 0, "power_id": "WarMachine"}})
	var pending: Array = [{"declaration": {"declared_round": 2, "player_id": 1, "power_id": "InevitableRuin"}, "fire_round": 3}]
	result = Ledger.render(world, actions, 2, {}, pending)
	for action in ["Siege", "Hunt", "Ward"]: ok = ok and result.contains("Action: " + action)
	ok = ok and result.contains("Power: War Machine") and result.contains("Power: Inevitable Ruin · scheduled for round 3")
	var board = preload("res://Prototype/U13/U13DirectBoard.gd").new()
	board._visible_world = {"entities": [{"id": "a", "attributes": {"value": 3}}, {"id": "b", "attributes": {"value": 7}}]}
	board._intent = "Siege"
	board._target = {"id": "keep"}
	board._draft_combat = {"card_ids": ["a", "b"]}
	ok = ok and board._staged_card_value() == 10 and board._guide().contains("2 cards staged · 10 total value")
	board._draft_combat.card_ids = ["a"]
	ok = ok and board._staged_card_value() == 3
	board.free()
	print(result)
	print("U13 aftermath ledger failures: ", 0 if ok else 1)
	quit(0 if ok else 1)
