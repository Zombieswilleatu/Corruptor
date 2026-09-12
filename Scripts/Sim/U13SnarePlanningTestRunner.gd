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
	world.players[0].resources.repair_tokens = 1
	var game = Game.new()
	game._owner = Game.Content.new().create_combat_match(true)
	if not check(game._owner.start("conduit", world, [0, 1]).action != "invalid" and planning_with_market_passes(game).action == "game_planning", "Snare planning fixture %d" % integrity):
		return
	var hand: Array = game.player_view(0).world.hand
	var circle: String = Slots.castle_id(0, 2)
	var source: Dictionary = Candidates.snare_source(0, 1)
	var repair: Dictionary = {"castle_action": {"action": "Repair", "target_id": circle, "card_ids": [hand[0]], "use_repair_token": false}}
	var token: Dictionary = repair.duplicate(true)
	token.castle_action.card_ids = []
	token.castle_action.use_repair_token = true
	var other: Dictionary = repair.duplicate(true)
	other.castle_action.target_id = Slots.castle_id(0, 0)
	var duplicate: Dictionary = repair.duplicate(true)
	duplicate.castle_action.target_id = Slots.castle_id(0, 4)
	var mixed: Dictionary = repair.duplicate(true)
	mixed.merge({"action": "Ward", "lane": "Lord", "card_ids": [hand[1]], "guard_moves": [{"card_id": hand[2], "lane": "Castle", "slot": 0}]})
	var overlap: Dictionary = mixed.duplicate(true)
	overlap.guard_moves[0].card_id = hand[0]
	var orders: Array = [{}, repair, token, other, duplicate, mixed, overlap, {"action": "Ward", "lane": "Castle", "card_ids": [hand[0]]}]
	var before: Dictionary = game.snapshot()
	for powers in [[], [source]]:
		var expected: Array = []
		for order in orders:
			if game._owner.preview_submission(0, powers, order).action != "invalid":
				expected.append(order)
		check(game._owner.legal_order_candidates(0, powers, orders) == expected, "bulk and complete preview agree at Integrity %d with Snare %s" % [integrity, not powers.is_empty()])
		check(game.snapshot() == before, "candidate checks preserve live state, events and resources")
	var quote: Dictionary = game._owner.preview_submission(0, [source], repair)
	# With the first Circle below the floor, the second is also unavailable.
	check((quote.action == "invalid") == (integrity in [7, 8, 9]), "only a new vulnerability lock rejects the paid Repair")
	check(game._owner.legal_power_candidates(0, [source]) == [source], "Snare itself remains legal")
	if integrity in [7, 8, 9]:
		check(game.submit([{"powers": [source], "order": repair}, {"powers": [], "order": {}}]).action == "invalid" and game.snapshot() == before, "locked Repair rejects joint submission without paying or sealing")
	# A different castle can still be repaired alongside Snare; verify real lock,
	# payment, exact save/restore and complete resolution without applying cost twice.
	if integrity in [7, 10, 21]:
		var chosen: Dictionary = other if integrity == 7 else repair
		if not check(game.submit([{"powers": [source], "order": chosen}, {"powers": [], "order": {}}]).action != "invalid" and game.step().action != "invalid", "Snare plus legal Repair commits at Integrity %d" % integrity):
			return
		check(row(game.snapshot().world, circle).attributes.integrity == integrity - 3 and row(game.snapshot().world, circle).attributes.get("repair_lock_until_round", 0) == (2 if integrity == 7 else 0), "actual submission exerts once and retains expected repair lock")
		var restored = Game.new()
		check(restored.restore_json(game.snapshot_json()).action != "invalid", "Snare and Repair save restores")
		check(game.finish_round().action != "invalid" and restored.finish_round().action != "invalid" and game.snapshot() == restored.snapshot(), "Snare and legal Repair replay exactly")
