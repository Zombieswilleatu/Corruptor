# Directed pre-match fixtures; full submission preview is the legality oracle.
extends "res://Scripts/Sim/U13BloodConduitTestRunner.gd"

func run() -> void:
	for integrity in [6, 7, 8, 9, 10, 21]:
		planning_boundary(integrity)
	print("U13 Snare planning failures: %d" % failures)
	quit(failures)

func planning_boundary(integrity: int) -> void:
	var world: Dictionary = fixture("Orias", integrity, 2)
	patch(world, world.players[0].lord_entity_id, {"threat": 1})
	patch(world, Slots.castle_id(0, 0), {"integrity": 18})
	var game = Game.new()
	game._owner = Game.Content.new().create_combat_match(true)
	if not check(game._owner.start("conduit", world, [0, 1]).action != "invalid" and planning_with_market_passes(game).action == "game_planning", "Snare planning fixture %d" % integrity):
		return
	var hand: Array = game.player_view(0).world.hand
	var circle: String = Slots.castle_id(0, 2)
	var source: Dictionary = Candidates.snare_source(0, 1)
	var work: Dictionary = {"castle_action": Game.Content.GuardWork.choice(circle), "guard_moves": [{"card_id": hand[0], "lane": "Castle", "slot": 0}]}
	var other: Dictionary = work.duplicate(true)
	other.castle_action.target_id = Slots.castle_id(0, 0)
	var duplicate: Dictionary = work.duplicate(true)
	duplicate.castle_action.target_id = Slots.castle_id(0, 4)
	var mixed: Dictionary = work.duplicate(true)
	mixed.merge({"action": "Ward", "lane": "Lord", "card_ids": [hand[1]]})
	var overlap: Dictionary = mixed.duplicate(true)
	overlap.card_ids = [hand[0]]
	var retired_repair: Dictionary = {"castle_action": {"action": "Repair", "target_id": circle, "card_ids": [hand[0]], "use_repair_token": false}}
	var token: Dictionary = {"castle_action": {"action": "Work", "target_id": circle, "card_ids": [], "use_repair_token": true}}
	var orders: Array = [{}, work, retired_repair, token, other, duplicate, mixed, overlap, {"action": "Ward", "lane": "Castle", "card_ids": [hand[0]]}]
	var before: Dictionary = game.snapshot()
	for powers in [[], [source]]:
		var expected: Array = []
		for order in orders:
			if game._owner.preview_submission(0, powers, order).action != "invalid":
				expected.append(order)
		check(game._owner.legal_order_candidates(0, powers, orders) == expected, "bulk and complete preview agree at Integrity %d with Snare %s" % [integrity, not powers.is_empty()])
		check(game.snapshot() == before, "candidate checks preserve live state, events and resources")
	check(game._owner.preview_submission(0, [source], work).action != "invalid", "Snare permits Work even when its exertion repair-locks the target")
	for invalid_order in [retired_repair, token, overlap]:
		check(game._owner.preview_submission(0, [source], invalid_order).action == "invalid" and game.snapshot() == before, "retired payment or overlapping Guard commitment rejects without mutation")
	check(game._owner.legal_power_candidates(0, [source]) == [source], "Snare itself remains legal")
	if not check(game.submit([{"powers": [source], "order": work}, {"powers": [], "order": {}}]).action != "invalid" and game.step().action != "invalid", "Snare plus Work commits at Integrity %d" % integrity): return
	var exerted: int = integrity - 3 if integrity >= 7 else integrity
	var locked: bool = integrity in [7, 8, 9]
	check(row(game.snapshot().world, circle).attributes.integrity == exerted and row(game.snapshot().world, circle).attributes.get("repair_lock_until_round", 0) == (2 if locked else 0), "submission exerts once and retains expected repair lock")
	var restored = Game.new()
	check(restored.restore_json(game.snapshot_json()).action != "invalid", "Snare and Work save restores")
	if not check(game.step().action != "invalid" and restored.step().action != "invalid" and game.snapshot() == restored.snapshot(), "Development replay agrees"): return
	check(row(game.snapshot().world, circle).attributes.integrity == exerted + (0 if locked else 1), "deployment Work respects Snare repair lock at Integrity %d" % integrity)
	check(game.finish_round().action != "invalid" and restored.finish_round().action != "invalid" and game.snapshot() == restored.snapshot(), "Snare and Work replay exactly")
