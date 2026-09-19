extends SceneTree

const Sim = preload("res://Scripts/Sim/U13LaneSandbox.gd")
const UI = preload("res://Prototype/U13/U13LaneSandbox.gd")
const Preparation = preload("res://Prototype/U13/U13LanePreparation.gd")
const Playback = preload("res://Prototype/U13/U13SmokePlayback.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + description)

static func state(sim) -> Dictionary:
	var streams: Array = []
	for spawner in sim.spawners:
		streams.append({"seed": spawner.seed_value, "owner": spawner.owner, "deck": spawner.deck, "discard": spawner.discard, "saved": spawner.saved, "goal": spawner.goal, "shuffle": spawner.shuffle_number})
	return {"world": sim.world, "seed": sim.seed_value, "round": sim.round_number, "serial": sim.serial, "streams": streams, "waves": sim.last_waves, "totals": sim.totals, "goals": sim.goal_ids, "swapped": sim.seats_swapped}.duplicate(true)

static func replay_state(playback) -> Dictionary:
	# Capture every stored replay property, not only a few sampled positions.
	var snapshot: Dictionary = {}
	for property in playback.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			snapshot[property.name] = playback.get(property.name)
	return snapshot.duplicate(true)

static func reference_commit(sim, inputs: Dictionary) -> void:
	for request in inputs.pending: sim.spawn(request.name, request.owner, request.center, request.turret)
	sim.random_waves(inputs.owners)
	sim.prepare_releases(inputs.releases)

static func request(name: String, owner: int = 0) -> Dictionary:
	return {"name": name, "owner": owner, "center": false, "turret": false}

func await_active(arena) -> void:
	var deadline: int = Time.get_ticks_msec() + 30000
	while arena.preparing() and Time.get_ticks_msec() < deadline:
		await process_frame
		arena._process(0)
	check(arena.active and not arena.preparing(), "interval becomes ready within the deadline")

func await_next(arena) -> void:
	var deadline: int = Time.get_ticks_msec() + 30000
	while (arena.next_packet.is_empty() or arena.next_key != arena._interval_inputs(arena.sim.round_number + 1)) and Time.get_ticks_msec() < deadline:
		await process_frame
		arena._process(0)
	check(not arena.next_packet.is_empty() and arena.next_key == arena._interval_inputs(arena.sim.round_number + 1), "next interval prepares for the current choices")

func make_arena(seed_text: String):
	var arena = UI.new()
	root.add_child(arena)
	arena.set_process(false)
	arena.seed_entry.text = seed_text
	arena.reset()
	arena.mode.select(1)
	arena.home_toggle.button_pressed = true
	arena.enemy_toggle.button_pressed = true
	return arena

func parity_checks() -> void:
	for swapped in [false, true]:
		for capacity in [0, 15]:
			var sim = Sim.new("lookahead-parity", true, true, swapped, capacity)
			# Exercise clone state after deck reshuffles, savings and manual IDs.
			for pid in [0, 1]:
				for round_number in range(1, 25): sim.spawners[pid].next_wave(round_number, [])
				sim.spawn("Vulture", pid, true)
				sim.spawn("Butcher", pid, true)
			sim.random_waves([0, 1])
			sim.prepare_releases()
			for offset in range(3):
				var original: Dictionary = state(sim)
				var clone = sim.fork()
				check(state(clone) == original, "fork copies both card streams and all arena state (%s/%d/%d)" % [swapped, capacity, offset])
				var finished: Dictionary = Sim.resolve_round(sim.world, sim.seed_value, sim.round_number)
				var tape_before: Dictionary = finished.duplicate(true)
				var inputs: Dictionary = {"pending": [request("Wright", offset % 2)], "owners": [0, 1] if offset != 1 else [1], "releases": ["March", "Hold"] if offset == 1 else ["Auto", "Auto"]}
				var worker := Thread.new()
				worker.start(Preparation.next_interval.bind(clone, {"world": finished.world.duplicate(true), "events": finished.events}, inputs.duplicate(true)))
				# Resolve the same upcoming interval serially with the pre-existing
				# operations, concurrently with the speculative worker.
				var expected = sim.fork()
				expected.finish(finished.duplicate(true))
				reference_commit(expected, inputs)
				var expected_result: Dictionary = Sim.resolve_round(expected.world, expected.seed_value, expected.round_number)
				var expected_playback = Playback.new()
				expected_playback.build(expected_result.events.map(func(row): return row.event))
				while worker.is_alive(): await process_frame
				var packet: Dictionary = worker.wait_to_finish()
				check(packet.action == "prepared" and state(packet.sim) == state(expected), "threaded commitment matches serial cards, staging, totals and seats")
				check(packet.result == expected_result, "all 200 ticks and final world match serial simulation exactly")
				check(replay_state(packet.playback) == replay_state(expected_playback), "background replay build matches every serial replay property")
				check(state(sim) == original and finished == tape_before, "preparation leaves the live arena and current result untouched")
				sim = packet.sim
				sim.finish(packet.result)

func handoff_checks() -> void:
	var arena = make_arena("lookahead-ui")
	check(arena.prepare_ahead.button_pressed, "continuous preparation defaults on")
	arena.start()
	await await_active(arena)
	var before: Dictionary = state(arena.sim)
	var scoreboard: Array = [arena.home_goal_note.text, arena.enemy_goal_note.text]
	await await_next(arena)
	check(state(arena.sim) == before and scoreboard == [arena.home_goal_note.text, arena.enemy_goal_note.text], "ready future does not expose future draws, reserves or goals")
	var prepared: Dictionary = arena.next_packet
	arena.speed.select(4)
	arena._process(3)
	check(arena.active and arena.job == null and not arena.waiting_next and arena.sim.round_number == 2, "5x playback hands off a ready interval without another preparation wait")
	check(arena.result == prepared.result and state(arena.sim) == state(prepared.sim), "handoff adopts exactly the prepared replay and committed arena")
	check(arena.pending.is_empty() and arena.release_choices.all(func(choice): return choice.selected == 0), "handoff does not duplicate requests or change Auto choices")
	await await_next(arena)
	var old_key: Dictionary = arena.next_key.duplicate(true)
	arena.pause()
	arena.request_spawn("Vulture")
	arena.request_spawn("Sooge")
	arena.request_spawn("Sooge")
	arena.release_choices[0].select(2)
	arena.enemy_toggle.button_pressed = false
	var changed: Dictionary = arena._interval_inputs(3)
	var expected = arena.sim.fork()
	expected.finish(arena.result.duplicate(true))
	reference_commit(expected, changed)
	var expected_result: Dictionary = Sim.resolve_round(expected.world, expected.seed_value, expected.round_number)
	arena._process(0)
	check(arena.next_packet.is_empty() and not arena.running and arena.pending.size() == 3, "paused edits discard the stale future without consuming requests")
	arena.start()
	await await_next(arena)
	check(arena.next_key != old_key and arena.next_packet.result == expected_result and state(arena.next_packet.sim) == state(expected), "manual spawns, release choice and random toggle rebuild the correct future")
	check(arena.next_packet.outcomes.size() == 3 and arena.next_packet.outcomes.back().action == "invalid", "a rejected duplicate limited monster cannot poison preparation")
	var key: Dictionary = arena.next_key.duplicate(true)
	arena.speed.select(3)
	arena._process(0)
	check(arena.next_key == key and not arena.next_packet.is_empty(), "changing playback speed retains valid preparation")
	arena._process(5)
	check(arena.active and arena.sim.round_number == 3 and arena.pending.is_empty(), "edited requests commit once at the boundary")
	check(arena.release_choices[0].selected == 1, "one-shot March returns to Hold after commitment")
	check(arena.result == expected_result and state(arena.sim) == state(expected), "edited handoff keeps the same complete result as serial execution")
	await await_next(arena)
	var generation: int = arena.arena_generation
	arena.reset()
	check(arena.arena_generation == generation + 1 and arena.next_packet.is_empty() and arena.sim.round_number == 1 and arena.sim.totals[0].reached_goal == 0, "same-seed reset clears prepared futures and scores")
	arena.prepare_ahead.button_pressed = false
	arena.start()
	await await_active(arena)
	arena._process(0)
	check(arena.next_job == null and arena.next_packet.is_empty(), "comparison toggle restores preparation only at boundaries")
	arena.prepare_ahead.button_pressed = true
	await await_next(arena)
	arena.mode.select(0)
	arena._process(0)
	check(arena.next_packet.is_empty(), "pause-between mode discards speculative preparation")
	arena._process(5)
	check(not arena.running and not arena.active and arena.sim.round_number == 2, "pause-between mode still stops at the boundary")
	arena.free()

# A semaphore makes a slow worker deterministic without relying on CPU speed.
# The callable has no arena/Node reference, just owned packet data.
static func gated_packet(gate: Semaphore, packet: Dictionary) -> Dictionary:
	gate.wait()
	return packet

func sealed_boundary_checks() -> void:
	var arena = make_arena("lookahead-sealed")
	arena.start()
	await await_active(arena)
	arena.release_choices[0].select(2)
	arena.request_spawn("Vulture")
	await await_next(arena)
	var sealed_packet: Dictionary = arena.next_packet
	var sealed_state: Dictionary = state(sealed_packet.sim)
	var gate := Semaphore.new()
	arena.next_packet = {}
	arena.next_job = Thread.new()
	arena.next_job.start(gated_packet.bind(gate, sealed_packet))
	arena._process(15)
	check(arena.waiting_next and not arena.active and arena.sim.round_number == 2 and arena.elapsed == 0, "slow preparation waits at the boundary with a fresh interval clock")
	check(arena.pending.is_empty() and arena.release_choices[0].selected == 1, "boundary seals requests and consumes one-shot March before the worker finishes")
	arena.request_spawn("Butcher")
	arena.enemy_toggle.button_pressed = false
	arena.release_choices[0].select(2)
	arena.mode.select(0)
	arena.pause()
	arena.start()
	check(arena.waiting_next and arena.job == null and arena.pending.size() == 1, "resuming an in-flight handoff does not start a duplicate commitment")
	arena.pause()
	gate.post()
	await await_active(arena)
	check(not arena.running and arena.elapsed == 0 and arena.field.animation_paused, "completed preparation installs while paused without advancing playback")
	check(state(arena.sim) == sealed_state and arena.result == sealed_packet.result, "later selector edits cannot rewrite the already sealed interval")
	check(arena.pending.size() == 1 and arena.release_choices[0].selected == 2 and arena.spawn_status.text.contains("Butcher queued for interval 3"), "requests made during the wait survive for the following interval")
	var next_inputs: Dictionary = arena._interval_inputs(3)
	var expected = arena.sim.fork()
	expected.finish(arena.result.duplicate(true))
	reference_commit(expected, next_inputs)
	arena.start()
	arena._process(15)
	arena.start()
	await await_active(arena)
	check(state(arena.sim) == state(expected) and arena.release_choices[0].selected == 1, "the later manual request and one-shot release apply exactly one interval later")
	arena.free()

func invalidation_checks() -> void:
	var arena = make_arena("lookahead-reset")
	arena.start()
	await await_active(arena)
	await await_next(arena)
	var old_packet: Dictionary = arena.next_packet
	var gate := Semaphore.new()
	arena.next_packet = {}
	arena.next_job = Thread.new()
	arena.next_job.start(gated_packet.bind(gate, old_packet))
	var before_generation: int = arena.arena_generation
	arena._process(15)
	check(arena.waiting_next and not arena.reset_button.disabled and not arena.swap_seats_button.disabled, "reset and swap remain available while a speculative worker finishes")
	arena.pause()
	arena.swap_seats()
	check(arena.seats_swapped and arena.arena_generation > before_generation and not arena.waiting_next, "seat swap cancels an in-flight handoff without waiting for its worker")
	var reset_state: Dictionary = state(arena.sim)
	gate.post()
	var deadline: int = Time.get_ticks_msec() + 30000
	while arena.next_job != null and Time.get_ticks_msec() < deadline:
		await process_frame
		arena._process(0)
	check(arena.next_packet.is_empty() and state(arena.sim) == reset_state, "stale completion cannot overwrite a reset arena in opposite seats")
	arena.start()
	await await_active(arena)
	await await_next(arena)
	# A last-moment edit can miss the cache entirely. It must use the ordinary
	# path, not discard the edit or reuse a future for different instructions.
	arena.request_spawn("Vulture")
	var inputs: Dictionary = arena._interval_inputs(2)
	var expected = arena.sim.fork()
	expected.finish(arena.result.duplicate(true))
	reference_commit(expected, inputs)
	arena.elapsed = 15
	arena._process(0)
	await await_active(arena)
	check(state(arena.sim) == state(expected), "last-moment cache miss preserves edited inputs and swapped card streams")
	var live_worker: Thread = arena.next_job
	arena.free()
	check(live_worker == null or not live_worker.is_started(), "closing the sandbox joins its speculative worker")

func goal_timing_checks() -> void:
	var arena = make_arena("lookahead-goals")
	arena.home_toggle.button_pressed = false
	arena.enemy_toggle.button_pressed = false
	arena.sim = Sim.new("lookahead-goals", true)
	# Use one side: an opposing melee unit beyond a goal would cause pursuit
	# back into the lane, rather than the unconditional arrivals needed here.
	for i in range(2): arena.sim.spawn("Butcher", 0)
	var ids = Sim.Ids.new()
	ids.restore(arena.sim.world.entities)
	var units: Array = arena.sim.units()
	for i in range(units.size()):
		var unit: Dictionary = units[i]
		unit.attributes.x_fp = 2398 if unit.owner == 0 else 2
		unit.attributes.y_fp = 100 + 160 * i
		unit.attributes.movement_ready_round = 2 if i == 1 else 1
		ids.update(unit.id, unit.owner, unit.attributes)
	arena.sim.world.entities = ids.snapshot()
	arena._show_idle()
	arena.start()
	await await_active(arena)
	await await_next(arena)
	check(arena.goal_rows.size() == 1 and arena.next_packet.sim.goal_arrivals(arena.next_packet.result.events).size() == 1, "fixture has one current goal and one goal in the prepared future")
	check(arena.home_goal_note.text.contains("0 reached") and arena.enemy_goal_note.text.contains("0 reached") and arena.sim.totals[0].reached_goal == 0, "preparing a future with known goals cannot reveal them early")
	arena._process(1)
	check(arena.home_goal_note.text.contains("1 reached") and arena.enemy_goal_note.text.contains("0 reached"), "current arrivals score at their own playback time")
	arena._process(14)
	check(arena.active and arena.sim.round_number == 2 and arena.home_goal_note.text.contains("1 reached") and arena.sim.totals[0].reached_goal == 1, "ready handoff credits previous arrivals once and keeps the future arrival hidden")
	arena.mode.select(0)
	arena._process(15)
	check(arena.sim.totals[0].reached_goal == 2 and arena.sim.totals[1].reached_goal == 0 and arena.home_goal_note.text.contains("2 reached"), "second interval credits only its new arrival without double counting")
	arena.free()

func idle_edit_checks() -> void:
	var arena = make_arena("lookahead-idle-edit")
	arena.start()
	await await_active(arena)
	await await_next(arena)
	var old_packet: Dictionary = arena.next_packet
	var gate := Semaphore.new()
	arena.next_packet = {}
	arena.next_job = Thread.new()
	arena.next_job.start(gated_packet.bind(gate, old_packet))
	arena.mode.select(0)
	arena._process(15)
	check(not arena.active and not arena.running and arena.next_job != null, "fixture stops between rounds while old speculation remains in flight")
	arena.request_spawn("Vulture")
	var expected = arena.sim.fork()
	reference_commit(expected, arena._interval_inputs(2))
	arena.mode.select(1)
	arena.start()
	check(arena.job != null and not arena.waiting_next, "an immediate idle spawn invalidates the old worker's base world")
	gate.post()
	await await_active(arena)
	check(state(arena.sim) == state(expected), "resuming continuous mode retains units added between rounds")
	arena.free()

func benchmark(enabled: bool) -> Dictionary:
	var arena = make_arena("lane-f881e7ec-e3aebe70")
	arena.prepare_ahead.button_pressed = enabled
	arena.speed.select(4)
	var started: int = Time.get_ticks_usec()
	var previous: int = started
	var wait_usec: int = 0
	var frames: int = 0
	var signatures: Array = []
	var recorded: int = 0
	arena.start()
	while arena.sim.round_number <= 8 and Time.get_ticks_usec() - started < 120000000:
		await create_timer(1.0 / 120.0).timeout
		var now: int = Time.get_ticks_usec()
		var delta: float = (now - previous) / 1000000.0
		if arena.preparing(): wait_usec += now - previous
		previous = now
		arena._process(delta)
		frames += 1
		if arena.active and arena.sim.round_number != recorded:
			recorded = arena.sim.round_number
			if recorded <= 8: signatures.append(JSON.stringify({"state": state(arena.sim), "result": arena.result}).sha256_text())
	var measured: Dictionary = {"prepare_ahead": enabled, "speed": 5, "rounds": 8, "wall_ms": (Time.get_ticks_usec() - started) / 1000.0, "preparation_wait_ms": wait_usec / 1000.0, "frames": frames, "round_signatures": signatures}
	check(arena.sim.round_number == 9 and signatures.size() == 8, "timed 5x run completes eight intervals")
	arena.free()
	return measured

func run() -> void:
	if "--benchmark" in OS.get_cmdline_user_args():
		var without: Dictionary = await benchmark(false)
		var ahead: Dictionary = await benchmark(true)
		check(without.round_signatures == ahead.round_signatures, "timed runs have identical complete simulation and arena state in every interval")
		print("LOOKAHEAD_BENCHMARK ", JSON.stringify({"godot": Engine.get_version_info().string, "without": without, "ahead": ahead}))
	else:
		await parity_checks()
		await handoff_checks()
		await sealed_boundary_checks()
		await invalidation_checks()
		await goal_timing_checks()
		await idle_edit_checks()
	print("LOOKAHEAD TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
