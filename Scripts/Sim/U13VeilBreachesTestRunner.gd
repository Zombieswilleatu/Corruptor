extends SceneTree

const Game = preload("res://Scripts/Sim/U13GameConductor.gd")
const Content = preload("res://Scripts/Sim/U13GameContent.gd")
const Veil = preload("res://Scripts/Sim/U13VeilBreaches.gd")
const Effects = preload("res://Scripts/Sim/U13VeilEffects.gd")
const Structures = preload("res://Scripts/Sim/U13Structures.gd")
const Guards = preload("res://Scripts/Sim/U13GuardDeployment.gd")
const Wheel = preload("res://Prototype/U13/U13VeilWheel.gd")
var failures: int = 0
var probes: Array = []

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + label)

func fresh(lords: Array = ["Deimos", "Gremory"]) -> Dictionary:
	var game = Game.new()
	var result: Dictionary = game.start("veil-tests", lords, [Game.Slots.TYPES, Game.Slots.TYPES])
	check(result.action != "invalid", "fixture starts")
	return game.snapshot().world

func context(world: Dictionary, n: int = 1, hook: String = "round_start_scheduled", seed_value: String = "veil-tests") -> Dictionary:
	return {"world": world.duplicate(true), "round": n, "hook": hook, "seed": seed_value, "player_order": [0, 1], "combat_orders": [{}, {}], "persistent_effects": []}

func probe(c: Dictionary) -> Dictionary:
	var content = Content.new()
	content.batch_events = true
	var result: Dictionary = content.on_hook(c)
	probes.append({"context": c.duplicate(true), "result": result.duplicate(true)})
	check(result.action != "invalid", "hook resolves " + c.hook)
	return result

func force_arrivals(world: Dictionary, lords: Array, n: int = 1) -> void:
	world.data.veil_breaches.checked_round = n
	world.data.veil_breaches.arrivals = []
	for i in range(lords.size()):
		world.data.veil_breaches.arrivals.append({"lord_id": lords[i], "threshold": 21 if i >= 4 else Veil.THRESHOLDS[i], "protection": 0 if i >= 4 else i + 1, "round": n, "veil": 21})
	if lords.size() > 4: world.data.veil_breaches.cascade_round = n

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world: Dictionary = fresh()
	var sequence: Array = []
	for spec in [[1, 0, 0], [2, 5, 1], [3, 18, 4], [4, 21, 4], [21, 21, 7]]:
		world.data.neutral_tears = spec[1]
		var before: Dictionary = world.duplicate(true)
		var admitted: Array = Veil.begin(world, spec[0], "sequence")
		sequence.append({"world": before, "round": spec[0], "seed": "sequence", "admitted": admitted, "after": world.duplicate(true)})
		check(world.data.veil_breaches.arrivals.size() == spec[2], "arrival count at Veil %d / round %d" % [spec[1], spec[0]])
	check(Veil.valid(world), "cascade state validates")
	check(world.data.veil_breaches.arrivals.all(func(row): return row.lord_id not in ["Deimos", "Gremory"]), "participants never enter the permanent pool")
	var restored: Dictionary = bytes_to_var(var_to_bytes(world))
	check(Veil.begin(restored, 21, "sequence").is_empty() and restored == world, "restored cascade cannot fire twice")
	world.data.victory.winner = 0
	check(Veil.begin(world, 22, "sequence").is_empty(), "no arrivals after victory")
	for lord in Veil.LORDS:
		world = fresh(["Orias", "Valak"] if lord in ["Deimos", "Gremory"] else ["Deimos", "Gremory"])
		force_arrivals(world, [lord])
		world.players[0].resources.personal_tears = 1
		var beneficial: bool = lord in Veil.BENEFICIAL
		check(Veil.affected_players(world, lord) == ([true, false] if beneficial else [false, true]), lord + " protection has the correct direction")
		world.players[1].resources.personal_tears = 1
		check(Veil.affected_players(world, lord) == [false, false], lord + " both protected")
		world.data.breach_lord = lord
		check(Veil.affected_players(world, lord) == [true, true], lord + " ordinary Breach stays unprotected")
	world = fresh(["Orias", "Gremory"])
	force_arrivals(world, ["Deimos"])
	world.players[0].resources.personal_tears = 1
	var ceiling: Dictionary = Effects.reconcile({"action": "resolved", "world": world, "events": []})
	var lost: Dictionary = ceiling.world.entities.entities.filter(func(row): return row.kind == "castle" and row.owner == 1)[0]
	var old_integrity: int = lost.attributes.integrity
	check(lost.attributes.max_integrity == lost.attributes.base_max_integrity - 5, "Deimos lowers only unprotected ceilings")
	check(Effects.reconcile(ceiling).world == ceiling.world, "ceiling does not shrink again")
	ceiling.world.players[1].resources.personal_tears = 1
	ceiling = Effects.reconcile(ceiling)
	lost = ceiling.world.entities.entities.filter(func(row): return row.id == lost.id)[0]
	check(lost.attributes.integrity == old_integrity and lost.attributes.max_integrity == lost.attributes.base_max_integrity, "late protection restores ceiling without healing")
	# Choose a reproducible first Humbaba arrival, exercise shock and later erosion.
	var seed_value: String = ""
	for i in range(100):
		world = fresh()
		world.data.neutral_tears = 4
		world.players[0].resources.personal_tears = 1
		var trial: Dictionary = world.duplicate(true)
		if Veil.begin(trial, 1, str(i))[0].lord_id == "Humbaba":
			seed_value = str(i)
			break
	var hit: Dictionary = probe(context(world, 1, "round_start_scheduled", seed_value))
	var damage: Array = hit.events.filter(func(row): return row.event.type == "CASTLE_DAMAGED")
	check(damage.size() == 3 and damage.all(func(row): return row.event.data.damage == 4), "Humbaba entry hits only exposed, unprotected Castles once")
	var targets: Array = hit.world.entities.entities.filter(func(row): return row.kind == "castle" and row.owner == 1 and Structures.targetable(row))
	targets[0].attributes.integrity = 1
	var erosion_context: Dictionary = context(hit.world, 2, "round_start_scheduled", seed_value)
	# Keep the callback owner alive when testing environmental kill reactions.
	var handler = Content.new()
	var erosion: Dictionary = Effects.begin(erosion_context, Callable(handler, "react"))
	probes.append({"kind": "erosion", "context": context(hit.world, 2, "round_start_scheduled", seed_value), "result": erosion.duplicate(true)})
	check(erosion.action != "invalid" and erosion.events.any(func(row): return row.event.type == "CASTLE_DESTROYED" and row.event.data.player_id == -1), "erosion destruction has no Siege credit")
	check(erosion.world.players[0].resources.souls == hit.world.players[0].resources.souls, "neutral erosion awards no Souls")
	# Late cascade sources coexist in one Marching phase; protection cannot block them.
	world = fresh()
	world.data.neutral_tears = 21
	force_arrivals(world, ["Humbaba", "Kalligan", "Orias", "Kanifous", "Kroni", "Odradek", "Valak"], 21)
	var cascade: Dictionary = probe(context(world, 21, "marching_start"))
	check(cascade.world.data.kroni_actors.size() == 1, "cascade Kroni manifests alongside Odradek and Valak")
	var actor: Dictionary = cascade.world.data.kroni_actors[0]
	var ids = Content.Ids.new()
	ids.restore(cascade.world.entities)
	for pid in [0, 1]:
		var a: Dictionary = Content.Marching.profile("Penitent", "Castle" if actor.y_fp >= 600 else "Lord", pid, 0, 21)
		a.x_fp = actor.x_fp
		a.y_fp = actor.y_fp % 600
		ids.create("marcher", "cascade-test", pid, pid, a)
	cascade.world.entities = ids.snapshot()
	cascade = probe(context(cascade.world, 21, "post_resolution_allegiance"))
	check(cascade.events.any(func(row): return row.event.type == "PARADOX_GEOMETRY"), "cascade Odradek transfers Marchers")
	cascade = probe(context(cascade.world, 21, "marching"))
	check(cascade.events.any(func(row): return row.event.type == "MARCHER_DEVOURED"), "cascade Kroni devours while Valak slows movement")
	world = fresh()
	force_arrivals(world, ["Kroni", "Valak"])
	world.players[0].resources.personal_tears = 2
	world = probe(context(world, 1, "marching_start")).world
	actor = world.data.kroni_actors[0]
	ids.restore(world.entities)
	for pid in [0, 1]:
		var a: Dictionary = Content.Marching.profile("Penitent", "Castle" if actor.y_fp >= 600 else "Lord", pid, 0, 1)
		a.x_fp = actor.x_fp
		a.y_fp = actor.y_fp % 600
		ids.create("marcher", "immune-test", pid, pid, a)
	world.entities = ids.snapshot()
	var protected_march: Dictionary = probe(context(world, 1, "marching"))
	var devoured: Array = protected_march.events.filter(func(row): return row.event.type == "MARCHER_DEVOURED")
	check(not devoured.is_empty() and devoured.all(func(row): return row.event.data.before.owner == 1), "protected Marchers cannot be devoured by permanent Kroni")
	# Admission, replay, and the accessible UI all use the same Breach-Wish rule.
	var game = Game.new()
	game.start("breach-access", ["Deimos", "Gremory"], [Game.Slots.TYPES, Game.Slots.TYPES])
	game._owner._world.data.neutral_tears = 5
	force_arrivals(game._owner._world, ["Kanifous"], 0)
	game._owner._world.data.veil_breaches.arrivals[0].round = 1
	game._owner._world.data.veil_breaches.checked_round = 0
	check(game.to_planning(true).action != "invalid", "non-Kanifous player reaches planning with Breach Wish")
	var source: Dictionary = Game.Scenario.source(0, 1, {}, 0, "BreachWishWealth")
	check(game._owner.preview_submission(0, [source], {}).action != "invalid", "Breach Wish is legal for Deimos")
	var baseline: Dictionary = game.snapshot()
	var copy_game = Game.new()
	check(copy_game.restore(baseline).action != "invalid", "active Breach saves restore")
	check(game.submit([{"powers": [source], "order": {}}, {"powers": [], "order": {}}]).action != "invalid", "Breach Wish commits")
	check(game.finish_round().action != "invalid", "Breach Wish round completes")
	check(game.snapshot().world.data.kanifous_prices.any(func(row): return row.get("breach", false)), "Breach Price provenance is saved")
	copy_game.submit([{"powers": [source], "order": {}}, {"powers": [], "order": {}}])
	copy_game.finish_round()
	check(game.snapshot() == copy_game.snapshot(), "save/replay reproduces Wish, Price and Veil state")
	baseline.world.players[1].resources.personal_tears = 1
	baseline.presentation_world = baseline.world.duplicate(true)
	check(copy_game.restore(baseline).action != "invalid" and copy_game._owner.preview_submission(0, [source], {}).action == "invalid", "enemy protection denies Breach Wish access")
	# Each weighted Breach Price outcome, including a non-Kanifous Lord's banishment.
	var price_game = Game.new()
	price_game.start("price-fixture", ["Humbaba", "Gremory"], [Game.Slots.TYPES, Game.Slots.TYPES])
	price_game.to_planning(true)
	var price_world: Dictionary = price_game.snapshot().world
	price_world.players[0].resources.souls = 2
	ids.restore(price_world.entities)
	var guard_id: String = price_world.data.card_zones.hands[0].pop_front()
	var guard: Dictionary = ids.get_entity(guard_id)
	guard.attributes.merge({"role": "guard", "lane": "Lord", "slot": 0})
	ids.update(guard_id, 0, guard.attributes)
	for i in range(2):
		ids.create("marcher", "price-test", i, 0, Content.Marching.profile("Penitent", "Lord", 0, 0, 1))
	price_world.entities = ids.snapshot()
	var debt: Dictionary = {"id": "price-fixture", "owner": 0, "created_round": 1, "due_round": 2, "breach": true}
	var outcomes: Array = []
	for i in range(800):
		var c: Dictionary = context(price_world, 1, "round_start_automatic", str(i))
		var paid: Dictionary = handler._price(price_world, debt, c)
		if paid.action == "invalid":
			check(false, "Price outcome rejected: " + str(paid))
			break
		var outcome: String = paid.events[-1].event.data.outcome
		if outcome in outcomes:
			continue
		outcomes.append(outcome)
		probes.append({"kind": "price", "context": c, "price": debt.duplicate(true), "result": paid.duplicate(true)})
		if outcome == "Wishmaster":
			check(paid.world.data.breach_lord == "Humbaba" and paid.events.any(func(row): return row.event.type == "THE_STONES_FORGET"), "Breach Price banishes the actual Lord and triggers its entry effect")
		if outcomes.size() == 7:
			break
	check(outcomes.size() == 7, "all seven heavier Price outcomes execute")
	var wheel = Wheel.new()
	root.add_child(wheel)
	wheel.bind_world(game.player_view(0).world, 1)
	check(wheel.milestone(5).label == "KANIFOUS" and wheel.milestone(5).tooltip.contains("HEAVIER PRICE"), "wheel reveals Kanifous and heavier Price after arrival")
	check(wheel.milestone(9).tooltip.contains("Identity stays hidden"), "wheel hides future identities")
	wheel.free()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		var file = FileAccess.open(args[0], FileAccess.WRITE)
		file.store_string(JSON.stringify({"sequence": sequence, "probes": probes, "rules_hash": game.snapshot().rules_hash, "policy_id": game.snapshot().policy_id}, "", true, true))
	print("U13 permanent Veil failures: ", failures)
	quit(1 if failures else 0)
