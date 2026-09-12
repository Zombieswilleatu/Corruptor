extends "res://Scripts/Sim/U13GameEconomyTestRunner.gd"
const Reference = preload("res://Scripts/Sim/U13PowerPlanningReference.gd")
const RegistryReference = preload("res://Scripts/Sim/U13EntityIdsReference.gd")

func run() -> void:
	registry_parity()
	for lord in Game.LORDS:
		var game = Game.new()
		if not check(game.start("planning-parity-" + lord, [lord, "Gremory"], [Slots.TYPES, Slots.TYPES]).action != "invalid" and planning_with_market_passes(game).action == "game_planning", lord + " planning setup"):
			continue
		var baseline: Dictionary = game.snapshot()
		var reference = Reference.from_owner(game._owner)
		if not check(reference != null, lord + " reference restore"):
			continue
		var sources: Array = Game.Scenario.enumerate(game._owner, 0).powers
		var malformed: Dictionary = sources[0].duplicate(true)
		malformed.declaration_id = "wrong"
		sources.append_array([null, "invalid", {}, malformed])
		var expected: Array = reference.legal_power_candidates(0, sources)
		check(game._owner.legal_power_candidates(0, sources) == expected, lord + " complete power domain matches full transactions")
		check(game.plan(0) == Game.GameBot.plan(reference, 0), lord + " same seeded complete plan")
		check(game.snapshot() == baseline and reference.snapshot() == baseline, lord + " previews leave both owners unchanged")
		check(game._owner.legal_order_candidates(0, [], []).is_empty() and game.snapshot() == baseline, lord + " empty order batch is read only")
		if lord == "Gremory":
			for validator in [Callable(), Callable(self, "malformed_adapter")]:
				game._owner._order_validator = validator
				reference._order_validator = validator
				check(game._owner.legal_power_candidates(0, sources) == reference.legal_power_candidates(0, sources), "missing/malformed predicate keeps full transaction fallback")
	print("U13 planning performance failures: %d" % failures)
	quit(failures)

func malformed_adapter(_context: Dictionary) -> Dictionary:
	return {"action": "legal_orders", "indices": ["invalid"]}

func registry_parity() -> void:
	var registry = Game.Content.Ids.new()
	registry.create("card", "parity", 0, 0, {"value": 3, "nested": {"hp_fp": 20}})
	registry.create("marcher", "parity", 1, -1, {"hp": 2})
	var base: Dictionary = registry.snapshot()
	var cases: Array = [base, JSON.parse_string(JSON.stringify(base))]
	for changes in [{"owner": 2}, {"owner": 0.5}, {"ordinal": -1}, {"ordinal": 0.5}, {"kind": "bad"}, {"origin": ""}, {"id": "wrong"}, {"attributes": {"hp_fp": 1.5}}, {"extra": "ignored"}]:
		var raw: Dictionary = base.duplicate(true)
		raw.entities[0].merge(changes, true)
		cases.append(raw)
	var duplicate: Dictionary = base.duplicate(true)
	duplicate.entities.append(duplicate.entities[0].duplicate(true))
	cases.append(duplicate)
	var missing: Dictionary = base.duplicate(true)
	missing.used_ids.clear()
	cases.append(missing)
	var retired: Dictionary = base.duplicate(true)
	retired.used_ids.append("retired-identity")
	cases.append(retired)
	for index in range(cases.size()):
		var fast = Game.Content.Ids.new()
		var old = RegistryReference.new()
		fast.restore(base)
		old.restore(base)
		check(fast.restore(cases[index]) == old.restore(cases[index]) and fast.snapshot() == old.snapshot(), "registry reference parity and atomic rejection %d" % index)
	var owned: Dictionary = base.duplicate(true)
	registry.restore(owned)
	owned.entities[0].attributes.nested.hp_fp = 999
	check(registry.snapshot() == base, "registry restore owns nested data")
