extends SceneTree

const Batch = preload("res://Scripts/Sim/U13FullMatchBatch.gd")
const Game = Batch.Game
const Bot = preload("res://Scripts/Sim/U13BasicDoctrine.gd")
const Reference = preload("res://Scripts/Sim/U13WorldInstallReference.gd")
var failures: int = 0
var checks: int = 0
var cases: Array = []
var validation_calls: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)
	return ok

func same(a, b) -> bool:
	return var_to_bytes(a) == var_to_bytes(b)

func opening(index: int):
	var setup: Dictionary = Batch.setup(index)
	var game = Game.new()
	if not check(game.start(setup.seed, setup.lords, setup.castles, true).action != "invalid", "start " + str(index)):
		return null
	return game

func run() -> void:
	var output: String = ""
	var checkpoints: Array = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		elif arg.begins_with("--checkpoint="): checkpoints.append(arg.trim_prefix("--checkpoint="))
		else:
			check(false, "unknown argument " + arg)
			quit(1)
			return
	boundaries()
	for index in [9, 19, 29, 39, 49, 59, 69, 79, 8]:
		var game = opening(index)
		if game != null: compare_round(game, "opening-%d" % index, index % 2 == 0)
	for path in checkpoints:
		var source = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not check(typeof(source) == TYPE_DICTIONARY and typeof(source.get("save_json")) == TYPE_STRING, "checkpoint envelope " + path.get_file()):
			continue
		# Repeats alternate execution order; comparison and save work is untimed.
		for repeat in range(3):
			var game = Game.new()
			if check(game.restore_json(source.save_json).action != "invalid", "checkpoint restore"):
				compare_round(game, "%s-repeat-%d" % [path.get_file(), repeat], repeat % 2 == 0)
	var totals: Dictionary = {"reference_ms": 0.0, "cached_ms": 0.0, "world_cache_hits": 0, "world_validations": 0, "hooks": 0}
	for row in cases:
		for key in totals: totals[key] += row[key]
	var report: Dictionary = {"engine": Engine.get_version_info().string, "reference_commit": "217565b088171a1a9276fa8257107aac5500bb29", "checks": checks, "failures": failures, "totals": totals, "cases": cases}
	if not output.is_empty():
		var file = FileAccess.open(output, FileAccess.WRITE)
		if check(file != null, "profile report opened"):
			file.store_string(JSON.stringify(report, "\t"))
	print("Resolution totals (execution only): ", JSON.stringify(totals))
	print("U13 resolution cache failures: %d" % failures)
	quit(failures)

func compare_round(game, label: String, reference_first: bool) -> void:
	var mirror = Game.new()
	mirror._owner = Reference.from_owner(game._owner)
	if not check(mirror._owner != null, label + " reference restore"): return
	var planned: Dictionary = Bot.to_planning(game)
	if not check(planned.action == "game_planning" and same(planned, Bot.to_planning(mirror)) and same(game.snapshot(), mirror.snapshot()), label + " exact planning boundary"): return
	var before: Dictionary = game.snapshot()
	var plans: Array = [Bot.plan(game._owner, 0), Bot.plan(game._owner, 1)]
	var repeated: Array = [Bot.plan(mirror._owner, 0), Bot.plan(mirror._owner, 1)]
	if not check(plans.all(func(p): return p.action == "bot_plan") and same(plans, repeated) and same(before, game.snapshot()) and same(before, mirror.snapshot()), label + " identical read-only plans"): return
	# The conductor normally constructs a fresh GameContent owner here. Build
	# the same transaction using the frozen install boundary for the reference.
	var submitted: Dictionary = game.submit(plans)
	var candidate = Reference.from_owner(mirror._owner)
	if not check(candidate != null and submitted.action == "game_submitted", label + " submission setup"): return
	for pid in [0, 1]:
		if not check(candidate.submit(pid, repeated[pid].powers, repeated[pid].order).action != "invalid", label + " reference seat " + str(pid)): return
	mirror._owner = candidate
	if not check(same(game.snapshot(), mirror.snapshot()), label + " exact accepted plans"): return
	var row: Dictionary = {"case": label, "round": game._owner.round_number(), "reference_ms": 0.0, "cached_ms": 0.0, "world_cache_hits": 0, "world_validations": 0, "hooks": 0, "hook_timings": []}
	while not game._owner.next_hook().is_empty():
		var hook: String = game._owner.next_hook()
		var fast: Dictionary = {}
		var old: Dictionary = {}
		var a: Dictionary
		var b: Dictionary
		if reference_first:
			b = measured_step(mirror, old)
			a = measured_step(game, fast)
		else:
			a = measured_step(game, fast)
			b = measured_step(mirror, old)
		if not check(a.action != "invalid" and same(a, b) and same(game.snapshot(), mirror.snapshot()), label + " exact hook " + hook): return
		row.reference_ms += old.ms
		row.cached_ms += fast.ms
		row.world_cache_hits += fast.get("world_cache_hits", 0)
		row.world_validations += fast.get("world_validations", 0)
		row.hooks += 1
		row.hook_timings.append({"hook": hook, "cached": fast, "reference": old})
	var restored = Game.new()
	check(restored.restore_json(game.snapshot_json()).action != "invalid" and same(game.snapshot(), restored.snapshot()) and same(game.outcome(), mirror.outcome()), label + " exact save and outcome")
	for pid in [0, 1]:
		check(same(game.player_view(pid), mirror.player_view(pid)), label + " exact player history " + str(pid))
	cases.append(row)
	print("PROFILE ", label, " reference=", snappedf(row.reference_ms, 0.1), "ms cached=", snappedf(row.cached_ms, 0.1), "ms cache hits=", row.world_cache_hits, " validations=", row.world_validations)

func measured_step(game, details: Dictionary) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = game.step(details)
	details["ms"] = (Time.get_ticks_usec() - started) / 1000.0
	return result

func boundaries() -> void:
	var game = opening(79)
	if game == null: return
	var owner = game._owner
	var world: Dictionary = owner.snapshot().world
	var original: Dictionary = owner.snapshot()
	check(not Game.Content.MatchOwner.new()._cache_world_validation, "custom owners default to full validation")
	var variants: Array = []
	for amount in [false, true, -1, 0.5, "0", null, NAN, INF]:
		var raw: Dictionary = world.duplicate(true)
		raw.players[0].resources.souls = amount
		variants.append({"label": "resource type/value " + str(amount), "world": raw})
	var bad_key: Dictionary = world.duplicate(true)
	bad_key.data[1] = 0
	variants.append({"label": "non-string key", "world": bad_key})
	var bad_fp: Dictionary = world.duplicate(true)
	bad_fp.data["cache_probe_fp"] = 0.5
	variants.append({"label": "fractional fixed point", "world": bad_fp})
	var duplicate_id: Dictionary = world.duplicate(true)
	duplicate_id.entities.entities.append(duplicate_id.entities.entities[0].duplicate(true))
	variants.append({"label": "duplicate entity", "world": duplicate_id})
	var lord: Dictionary = world.duplicate(true)
	lord.players[0].lord_entity_id = "missing"
	variants.append({"label": "missing Lord", "world": lord})
	var owner_type: Dictionary = world.duplicate(true)
	owner_type.entities.entities[0].owner = false
	variants.append({"label": "boolean entity owner", "world": owner_type})
	var zones: Dictionary = world.duplicate(true)
	zones.data.card_zones = {}
	variants.append({"label": "invalid card zones", "world": zones})
	for variant in variants:
		var fast = owner._fork_validated()
		var old = Reference.from_owner(owner)
		var result: Dictionary = fast._install_world(variant.world)
		check(result.action == "invalid" and same(result, old._install_world(variant.world)) and same(fast.snapshot(), old.snapshot()) and same(original, fast.snapshot()), "cached rejection matches original: " + variant.label)
		check(fast._install_world(world).action != "invalid" and fast._world_cache_hits == 1 and same(original, fast.snapshot()), "failed install cannot poison cache: " + variant.label)
	var json_world: Dictionary = JSON.parse_string(JSON.stringify(world))
	var normalized = owner._fork_validated()
	var old_normalized = Reference.from_owner(owner)
	check(same(normalized._install_world(json_world), old_normalized._install_world(json_world)) and same(normalized.snapshot(), old_normalized.snapshot()), "JSON integer/float normalization preserves original result")
	var warm = owner._fork_validated()
	check(warm._install_world(world).action != "invalid" and warm._world_cache_hits == 1, "identical canonical world uses checked cache")
	var changed: Dictionary = world.duplicate(true)
	changed.players[0].resources.souls += 1
	check(warm._install_world(changed).action != "invalid" and warm._world_validations == 1, "changed valid world is fully revalidated")
	changed.players[0].resources.souls = -900
	check(warm._world.players[0].resources.souls >= 0 and same(owner.snapshot(), original), "input mutation and child install cannot change owned cache or parent")
	var sibling = owner._fork_validated()
	sibling._world.players[0].resources.souls += 7
	sibling._entities.retire(world.players[0].lord_entity_id)
	check(sibling._install_world(world).action != "invalid" and same(sibling.snapshot(), original) and same(owner.snapshot(), original), "cache restores isolated world and entity registry")
	var callback = owner._fork_validated()
	callback._world_validator = func(_world): return false
	check(callback._install_world(world).action == "invalid" and callback._world_cache_hits == 0, "changed validator cannot reuse old acceptance")
	# A new restore transaction must check its input even if this live owner
	# has previously validated precisely the same world.
	var observed = owner._fork_validated()
	observed._world_validator = Callable(self, "observe_valid_world")
	observed._install_world(world)
	validation_calls = 0
	check(observed.restore(original).action != "invalid" and validation_calls > 0, "external restore performs fresh world validation")
	var bad_save: Dictionary = original.duplicate(true)
	bad_save.world.players[0].resources.souls = -1
	check(observed.restore(bad_save).action == "invalid" and same(observed.snapshot(), original), "failed external restore is atomic")
	var full = owner._fork_validated()
	full._cache_world_validation = false
	full._world_validator = Callable(self, "observe_valid_world")
	validation_calls = 0
	full._install_world(world)
	full._install_world(world)
	check(validation_calls == 2, "non-opted-in validator is called on every install")
	transform_boundaries(owner, world)

func observe_valid_world(world: Dictionary) -> bool:
	validation_calls += 1
	return Game.Content.new().valid_world(world)

func transform_boundaries(owner, world: Dictionary) -> void:
	for rewrite in [false, true]:
		var fast = owner._fork_validated()
		var old = Reference.from_owner(owner)
		for target in [fast, old]:
			if rewrite:
				target._entities.create("card", "cache-history-probe", 0, 0, {})
			else:
				target._entities.retire(world.players[0].lord_entity_id)
		var result: Dictionary = fast._apply_transform({"action": "resolved", "world": world, "events": []})
		check(result.get("reason") == ("entity_history_rewritten" if rewrite else "retired_entity_resurrected") and same(result, old._apply_transform({"action": "resolved", "world": world, "events": []})) and fast._world_cache_hits == 1, "history checks survive cache hit: " + str(rewrite))
	var fast = owner._fork_validated()
	var old = Reference.from_owner(owner)
	var event: Dictionary = {"type": "CACHE_PRIVATE_PROBE", "text": "private", "data": {"hidden_value": 5}}
	var result: Dictionary = {"action": "resolved", "world": world, "events": [{"event": event, "views": [event, null]}]}
	check(same(fast._apply_transform(result), old._apply_transform(result)) and same(fast.snapshot(), old.snapshot()) and fast._world_cache_hits == 1, "no-op world still records private events exactly")
	check(fast._events.for_player(0).any(func(e): return e.type == "CACHE_PRIVATE_PROBE") and not fast._events.for_player(1).any(func(e): return e.type == "CACHE_PRIVATE_PROBE"), "cache hit keeps private event visibility")
	var invalid_event: Dictionary = {"action": "resolved", "world": world, "events": [{"event": event, "views": [event]}]}
	check(fast._apply_transform(invalid_event).action == "invalid" and same(fast.snapshot(), old.snapshot()), "cache hit still validates event projections")
