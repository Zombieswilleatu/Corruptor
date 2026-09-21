extends "res://Scripts/Sim/U13GameEconomyTestRunner.gd"

const Stage = Game.Content.Staging
const Trace = preload("res://Scripts/Sim/U13ParityTrace.gd")
const Codec = preload("res://Scripts/Sim/U13ExactData.gd")
const Monsters = Game.Content.Monsters
const Marching = Stage.Marching
var operations: Array = []
var trace_game
var assertions: int = 0

func checked(ok: bool, label: String) -> bool:
	assertions += 1
	return check(ok, label)

func apply(operation: Dictionary) -> bool:
	var result: Dictionary = Trace.apply(trace_game, operation)
	if not checked(result.action != "invalid", "full-game " + str(operation.kind)):
		print(result)
		return false
	operations.append(operation.duplicate(true))
	return true

func planning() -> bool:
	while trace_game._owner.next_hook() != "submission_lock":
		var w: Dictionary = trace_game._owner.player_view(0, 0).world
		if not w.game_economy.stockpile_pending.is_empty():
			var pending: Dictionary = w.game_economy.stockpile_pending
			var pid: int = pending.player_id
			var choices: Array = trace_game._owner.player_view(pid, 0).world.game_economy.stockpile_pending.card_ids
			if not apply({"kind": "stockpile", "player_id": pid, "keep_id": choices[0]}): return false
		elif w.game_market.seat != 2:
			if not apply({"kind": "market", "player_id": w.game_market.seat, "choice": {"market": "Pass"}}): return false
		elif not apply({"kind": "step", "hook": trace_game._owner.next_hook()}): return false
	return true

func put(world: Dictionary, name: String, pid: int, lane: String, birth: int, ordinal: int = 0) -> Dictionary:
	var ids = Marching.Ids.new()
	ids.restore(world.entities)
	var a: Dictionary = Monsters.profile(name, lane, pid, birth, birth + 1) if name in Monsters.NAMES else Marching.profile(name, lane, pid, birth, birth + 1, true)
	var made: Dictionary = ids.create("marcher", "staging-fixture:" + name + lane + str(pid), ordinal, pid, a)
	world.entities = ids.snapshot()
	return made.entity

func fixtures() -> void:
	var schema: Dictionary = Game.Scenario.loadout_world(["Gremory", "Humbaba"], [Slots.TYPES, Slots.TYPES])
	var w: Dictionary = Economy.initialize(schema, "staging-fixtures").world
	Stage.configure(w)
	var monster: Dictionary = put(w, "Sooge", 0, "Lord", 1)
	var wright: Dictionary = put(w, "Wright", 0, "Castle", 1)
	Stage.capture(w, [Marching.public_event("MARCHER_SPAWNED", monster), Marching.public_event("MARCHER_SPAWNED", wright)], 1)
	checked(Stage.valid(w) and Game.Content.new().valid_world(w), "protected identities validate in the complete world")
	checked(w.entities.entities.all(func(u): return u.id not in [monster.id, wright.id]), "reserves cannot be battlefield or power targets")
	Stage.prepare(w, 1, [{"staging": {"Lord": "March", "Castle": "Hold"}}, {}])
	checked(Stage.rows(w).size() == 2, "MARCH queues the whole group for next round, never this round")
	var frozen: Array = Stage.rows(w).duplicate(true)
	var context: Dictionary = {"world": w, "round": 1, "seed": "staging-fixtures", "player_order": [0, 1], "hook": "marching", "persistent_effects": [], "full_roster": true}
	var resolved: Dictionary = Marching.resolve(context, Callable(Game.Content.new(), "react"))
	checked(resolved.action == "resolved" and Stage.rows(resolved.world) == frozen, "native full-game Marching leaves reserve HP and ability clocks frozen")
	checked(not resolved.events.any(func(r): return r.event.type in ["WRIGHT_BUILD_ASSIGNED", "MONSTER_BEAM_FIRED"]), "reserves neither build nor attack")
	checked(Monsters.living(Monsters.reserves(w), 0, "Sooge"), "protected Sooge reserves its living-copy slot")
	var bad: Dictionary = w.duplicate(true)
	bad.data.game_staging.lanes.Lord.units.append(bad.data.game_staging.lanes.Lord.units[0].duplicate(true))
	checked(not Stage.valid(bad), "duplicate protected identity rejected")
	bad = w.duplicate(true)
	bad.data.game_staging.lanes.Lord.units[0].attributes.hp = 0
	checked(not Stage.valid(bad), "invalid protected combat stats rejected")
	# Real match history distinguishes reserves from retired units.
	var owner = Game.Content.new().create_combat_match()
	checked(owner.start("staging-history", w, [0, 1]).action != "invalid", "protected world installs in match authority")
	var retired: Dictionary = w.duplicate(true)
	retired.data.game_staging.lanes.Lord.units.clear()
	checked(owner._apply_transform({"action": "resolved", "world": retired, "events": []}).action != "invalid", "removing a reserve retires its identity")
	checked(owner._apply_transform({"action": "resolved", "world": w, "events": []}).get("reason") == "retired_entity_resurrected", "retired identity cannot be smuggled back into staging")
	for i in range(12):
		var enemy: Dictionary = put(w, "Butcher", 1, "Castle", 0, i)
		w.entities.entities.filter(func(u): return u.id == enemy.id)[0].attributes.x_fp = 1200
	Stage.prepare(w, 2, [{}, {}])
	checked(w.entities.entities.any(func(u): return u.id == monster.id) and Stage.rows(w).any(func(u): return u.id == wright.id), "only the explicitly commanded Lord lane deploys next round")
	var saved: Dictionary = w.duplicate(true)
	Stage.prepare(w, 2, [{"staging": {"Castle": "March"}}, {}])
	checked(w == saved, "one release per lane per round")
	Stage.prepare(w, 3, [{"staging": {"Castle": "March"}}, {}])
	checked(Stage.rows(w).size() == 1 and w.data.game_staging.lanes.Castle.march_round == [4, 0], "MARCH does not release old reserves immediately")
	checked(Stage.valid(w), "pending next-round release validates")
	Stage.prepare(w, 4, [{}, {}])
	checked(Stage.rows(w).is_empty() and w.entities.entities.any(func(u): return u.id == wright.id and u.attributes.deployed_round == 4), "manual March releases an eligible group against pressure")
	Stage.configure(w)
	for i in range(16):
		var recruit: Dictionary = put(w, "Penitent", 0, "Castle", 3, i)
		Stage.capture(w, [Marching.public_event("MARCHER_SPAWNED", recruit)], 3)
	Stage.prepare(w, 3, [{"staging": {"Castle": "Hold"}}, {}])
	checked(Stage.rows(w).size() == 16, "newborn overflow stays protected")
	Stage.prepare(w, 4, [{"staging": {"Castle": "Hold"}}, {}])
	checked(Stage.rows(w).size() == 16 and w.data.game_staging.lanes.Castle.decisions[0].overflow == 0, "full tray never forces an uncommanded release")
	Stage.prepare(w, 5, [{"staging": {"Castle": "March"}}, {}])
	checked(Stage.rows(w).size() == 16, "full tray still waits during command round")
	Stage.prepare(w, 6, [{}, {}])
	checked(Stage.rows(w).is_empty() and w.data.game_staging.lanes.Castle.decisions[0].released == 16 and w.data.game_staging.lanes.Castle.march_round == [0, 0], "entire group deploys and the one-shot command clears")
	var late: Dictionary = put(w, "Wright", 0, "Castle", 6, 99)
	Stage.capture(w, [Marching.public_event("MARCHER_SPAWNED", late)], 6)
	Stage.prepare(w, 7, [{}, {}])
	checked(Stage.rows(w).size() == 1, "later recruits wait for a fresh MARCH command")
	var malformed: Dictionary = w.duplicate(true)
	malformed.data.game_staging.lanes.Castle.march_round = [99, 0]
	checked(not Stage.valid(malformed), "invalid queued release clock is rejected")

func run() -> void:
	fixtures()
	var setup: Dictionary = {"seed": "live-staging-integration", "lords": ["Deimos", "Gremory"], "castles": [Slots.TYPES, Slots.TYPES]}
	trace_game = Game.new()
	if not checked(trace_game.start(setup.seed, setup.lords, setup.castles, true).action != "invalid", "new full game enables staging"): quit(1); return
	for n in range(1, 5):
		if not planning(): quit(1); return
		var snapshot: Dictionary = trace_game.snapshot()
		var restored = Game.new()
		checked(restored.restore(snapshot).action != "invalid" and restored.snapshot() == snapshot, "protected saves restore exactly in round " + str(n))
		var plans: Array = []
		for pid in [0, 1]:
			var w: Dictionary = trace_game._owner.player_view(pid, 0).world
			var lane: String = "Lord" if n % 2 == 1 else "Castle"
			var order: Dictionary = {"action": "Ward", "lane": lane, "card_ids": w.hand.duplicate(), "staging": {"Lord": "March" if n == 1 else "Hold", "Castle": "Hold"}}
			if n == 3: order.staging.Lord = "Hold"
			if n == 3: order.staging.Castle = "March"
			var available: Array = Monsters.available(w.entities + Stage.rows(trace_game.snapshot().world), w.hand, pid)
			if not available.is_empty(): order["monster_choice"] = available[0]
			plans.append({"powers": [], "order": order})
		var invalid_order: Dictionary = plans[0].order.duplicate(true)
		invalid_order.staging.Lord = "Teleport"
		checked(trace_game._owner.preview_submission(0, [], invalid_order).action == "invalid", "invalid release choice rejected atomically")
		checked(trace_game._owner.preview_submission(0, [], {"staging": {"Lord": "Hold"}}).action != "invalid", "Pass can carry staging controls")
		if not apply({"kind": "submit", "plans": plans}): quit(1); return
		while not trace_game._owner.next_hook().is_empty():
			var hook: String = trace_game._owner.next_hook()
			if not apply({"kind": "step", "hook": hook}): quit(1); return
			var w: Dictionary = trace_game.snapshot().world
			if hook == "commitment_reveal":
				checked(not Stage.rows(w).is_empty() and w.entities.entities.all(func(u): return u.kind != "marcher" or u.attributes.birth_round != n), "card recruits and recipe monsters enter protected staging round " + str(n))
			if hook == "marching_start" and n == 2:
				checked(w.entities.entities.any(func(u): return u.kind == "marcher" and u.attributes.lane == "Lord") and not w.entities.entities.any(func(u): return u.kind == "marcher" and u.attributes.lane == "Castle"), "round-two Lord group deploys while Castle newborns stay protected")
			if hook == "marching_start" and n == 4:
				checked(w.entities.entities.any(func(u): return u.kind == "marcher" and u.attributes.lane == "Castle" and u.attributes.get("deployed_round") == 4), "full-game Castle March control deploys old reserves")
		if n < 4 and not apply({"kind": "next_round"}): quit(1); return
	var legacy_world: Dictionary = Economy.initialize(Game.Scenario.loadout_world(setup.lords, setup.castles), "legacy-save").world
	var legacy_owner = Game.Content.new().create_combat_match()
	checked(legacy_owner.start("legacy-save", legacy_world, [0, 1]).action != "invalid", "legacy deployment world starts without migration")
	var legacy_game = Game.new()
	checked(legacy_game.restore(legacy_owner.snapshot()).action != "invalid" and not Stage.enabled(legacy_game.snapshot().world), "older saves retain their deployment behavior")
	var final: Dictionary = trace_game.snapshot()
	var restored = Game.new()
	checked(restored.restore(final).action != "invalid" and restored.snapshot() == final, "completed battle and reserves restore exactly")
	if not OS.get_cmdline_user_args().is_empty():
		var path: String = OS.get_cmdline_user_args()[0]
		var output = FileAccess.open(path, FileAccess.WRITE)
		var encoded: Dictionary = Codec.encode({"setup": setup, "operations": operations, "state": final})
		checked(encoded.action != "invalid", "exact parity fixture encodes")
		output.store_string(encoded.text)
		output.close()
	print("U13 game staging assertions: %d; failures: %d" % [assertions, failures])
	quit(failures)
