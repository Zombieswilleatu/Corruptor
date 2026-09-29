extends SceneTree
const Model = preload("res://Prototype/U13/Encounters/U13EncounterModel.gd")
const Objectives = Model.Objectives
const Marching = Model.Marching
const Lab = preload("res://Prototype/U13/Encounters/U13EncounterLab.gd")
var checks: int = 0
var failed: int = 0
func check(value: bool, message: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + message)
	if not value: failed += 1
func _initialize() -> void: call_deferred("run")
func combat(m) -> Dictionary:
	var req: Dictionary = m.begin()
	if req.has("error"): return req
	return Model.resolve(req.world, req.seed, req.round)
func run() -> void:
	var m = Model.new("fixture")
	var twin = Model.new("fixture")
	check(m.waves == twin.waves, "seed fixes the complete finite enemy expedition")
	check(m.ordinary == {"Penitent": 5, "Vulture": 3, "Wright": 3, "Butcher": 3} and m.power == Model.START_POWER, "base 3 plus fixed retinue bonus gives 14 recruits")
	for suit in Model.SUITS:
		var leader = Model.new("leader", "gate", 2, 1, Model.Monsters.NAMES, suit)
		check(leader.ordinary[suit] == 5 and leader.ordinary_remaining() == 14, suit + " retinue changes composition without rank scaling")
	var unled = Model.new("unled", "gate", 2, 1, Model.Monsters.NAMES, "")
	check(unled.ordinary_remaining() == 12, "no-retinue test has baseline 12")
	for difficulty in [0, 1, 2]:
		for mode in ["gate", "lamp"]:
			var enemy = Model.new("budgets", mode, 2, difficulty)
			var paid: int = 0
			var serials: Array = []
			var unique: bool = true
			for wave in enemy.waves:
				for order in wave:
					paid += int(Model.OPPOSITION_COST.get(order.name, 2))
					unique = unique and order.serial not in serials
					serials.append(order.serial)
			check(unique and paid == enemy.enemy_spent and paid <= enemy.enemy_budget, "%s difficulty %d has a finite audited budget and unique orders" % [mode, difficulty])
	var plans_seen: Dictionary = {}
	for seed_id in range(1, 13):
		var planned = Model.new("crossing-%d" % seed_id)
		plans_seen[planned.enemy_plan] = true
		check(planned.forecast()[0].has("x") and planned.forecast()[0].has("y"), "planned approach is fixed before deployment seed %d" % seed_id)
	check(plans_seen.size() == 3, "seed panel covers shield, volley and raider plans")
	var light_plan = Model.new("crossing-1", "gate", 2, 0)
	var standard_plan = Model.new("crossing-1", "gate", 2, 1)
	var heavy_plan = Model.new("crossing-1", "gate", 2, 2)
	check(light_plan.enemy_budget < standard_plan.enemy_budget and standard_plan.enemy_budget < heavy_plan.enemy_budget, "Gate difficulty uses ascending finite expedition budgets")
	check(light_plan.enemy_budget == 59 and standard_plan.enemy_budget == 70 and heavy_plan.enemy_budget == 80, "new difficulty ladder has increasing finite budgets")
	check(not standard_plan.waves[1].any(func(o):return o.name == "Muno") and standard_plan.waves[2].any(func(o):return o.name == "Muno"), "Standard Gate skirmisher waits until round three")
	for tier in [standard_plan, heavy_plan]:
		var pushes: Array = [6,9,12]
		for r in pushes:
			check(tier.waves[r-1].size() >= 2 and tier.waves[r-1].any(func(o):return o.name in Model.Monsters.NAMES) and tier.waves[r-1].any(func(o):return o.name in Model.SUITS), "reinforced push includes troops and monster")
			check(tier.waves[r].is_empty(), "fixed recovery gap follows each reinforced push")
		check(tier.waves.slice(12).all(func(w):return w.is_empty()), "finite expedition ends without lone late trickles")
	check(standard_plan.forecast().any(func(o):return o.name == "Kopita") and standard_plan.forecast().any(func(o):return o.name == "Lemek"), "Standard support arrives with its front line")
	var dense = Model.new("dense")
	dense.waves = [[dense._enemy_order("Penitent", 222222)]]
	dense.waves[0][0].x = 1980; dense.waves[0][0].y = 300
	for i in range(60): dense.arena.spawn("Penitent", 0)
	var dense_ids = Marching.Ids.new(); dense_ids.restore(dense.arena.world.entities)
	var dense_rows: Array = dense.arena.units()
	for i in range(dense_rows.size()):
		var dense_unit: Dictionary = dense_rows[i]
		dense_unit.attributes.x_fp = 1980 + (i % 5) * 43
		dense_unit.attributes.y_fp = 60 + floori(float(i) / 5.0) * 43
		dense_ids.update(dense_unit.id, dense_unit.owner, dense_unit.attributes)
	dense.arena.world.entities = dense_ids.snapshot()
	var dense_totals: Array = dense.arena.totals.duplicate(true)
	check(dense.begin().has("world") and dense.waiting_enemies.size() == 1 and dense.arena.units().size() == 60 and dense.arena.totals == dense_totals, "crowded formation defers exact order and rolls back spawn accounting")
	var opening_options = Model.new("opening-options")
	check(opening_options.unlocked.filter(func(name): return opening_options.unavailable(name).is_empty()) == ["Varn","Fyra","Kopita","Tumler"], "four distinct monsters are affordable at the opening")
	var opening_before: Dictionary = opening_options._snapshot()
	check(opening_options.deploy("Lemek",Vector2(200,300)).has("error") and opening_options._snapshot() == opening_before, "opening Lemek is unaffordable without changing state")
	for name in ["Lemek", "Muno"]:
		var priced = Model.new("price-" + name)
		var cost: int = 6 if name == "Lemek" else 7
		priced.power = cost - 1
		var before_price: Dictionary = priced._snapshot()
		check(priced.deploy(name,Vector2(200,300)).has("error") and priced._snapshot() == before_price, name + " rejects one power short without spending anything")
		priced.power = cost
		check(priced.deploy(name,Vector2(200,300)).has("ok") and priced.power == 0 and priced.metrics.power_spent == cost and priced.capacity_used() == 3, name + " charges its new exact price and retains capacity 3")
		check(priced.undo() and priced.power == cost and priced.metrics.power_spent == 0 and priced.capacity_used() == 0 and priced.arena.units().is_empty(), name + " undo refunds new price and removes the summon")
	var lamp_opening = Model.new("crossing-1", "lamp", 2, 1)
	check(lamp_opening.forecast().size() < standard_plan.forecast().size() and lamp_opening.enemy_budget == 58 and standard_plan.enemy_budget == 70, "Lamp uses its own smaller opening and finite budget without changing Gate")
	var original: Dictionary = m.arena.world.duplicate(true)
	check(m.deploy("Penitent", Vector2(1000, 300)).has("error") and m.arena.world == original, "illegal placement changes nothing")
	check(m.deploy("Sooge", Vector2(200, 300)).has("error"), "power limits an unaffordable summon")
	check(m.deploy("Penitent", Vector2(200, 300)).has("ok") and m.power == Model.START_POWER and m.ordinary.Penitent == 4 and m.deployments == 1, "ordinary deployment spends reserve and slot, not power")
	check(m.undo() and m.arena.world == original and m.ordinary.Penitent == 5 and m.deployments == 0, "undo restores all ordinary state")
	for i in range(4): check(m.deploy("Penitent", Vector2(100 + i * 60, 300)).has("ok"), "deployment slot %d available" % (i + 1))
	check(m.deploy("Varn", Vector2(350, 400)).has("error") and m.deployments == 4, "ordinary and monster purchases share the four-slot limit")
	var forecast_copy: Array = m.forecast()
	forecast_copy.clear()
	check(not m.forecast().is_empty(), "editing forecast copy cannot change locked orders")
	var swarm_wave = Model.new("announced-swarm")
	swarm_wave.waves[0] = [swarm_wave._enemy_order("Varn", 111111)]
	var expected_count: int = swarm_wave.forecast()[0].bodies
	swarm_wave.begin()
	check(swarm_wave.arena.units().size() == expected_count, "forecast Varn body count matches actual spawn")
	check(swarm_wave.remaining_enemy_bodies() == swarm_wave.waves.slice(1).reduce(func(total, wave): return total + wave.reduce(func(subtotal, order): return subtotal + order.bodies, 0), 0), "already-spawned wave is excluded from remaining reserve")
	var frozen: Array = m.forecast(1)
	var out: Dictionary = combat(m)
	check(out.action == "resolved" and m.accept(out), "normal battle resolves and accepts")
	check(m.forecast() == frozen and m.power == Model.START_POWER + 2 and m.deployments == 0, "next announced wave advances unchanged; power and slots refresh")
	var after: Dictionary = m.arena.world.duplicate(true)
	check(not m.accept(out) and m.arena.world == after and m.power == Model.START_POWER + 2, "same result cannot be accepted twice")
	var savings = Model.new("savings")
	savings.waves = []
	for i in range(5): savings.accept(combat(savings))
	check(savings.power == Model.START_POWER + 10 and savings.ordinary_remaining() == 14, "power banks without carry cap while ordinary reserve never refills")
	var locked = Model.new("locked", "gate", 2, 1, ["Lemek"])
	locked.power = 100
	check(locked.deploy("Varn", Vector2(200,300)).has("error"), "monster unlock list is enforced")
	for monster in Model.Monsters.NAMES:
		var sample = Model.new("monster", "gate")
		sample.power = 20
		var deployed: Dictionary = sample.deploy(monster, Vector2(200,300))
		check(deployed.has("ok") and sample.capacity_used() == int(Model.WEIGHT[monster]) and Marching.valid(sample.arena.world), monster + " actual engine entity occupies its paid capacity")
		check(sample.undo() and sample.power == 20 and sample.capacity_used() == 0 and sample.deployments == 0, monster + " undo restores power and capacity")
	var combo = Model.new("combo")
	combo.power = 100
	combo.deploy("Sooge", Vector2(200,300))
	combo.deploy("Varn", Vector2(350,300))
	check(combo.capacity_used() == 7 and combo.deploy("Kopita", Vector2(200,400)).has("error"), "Sooge plus Varn fits; spare power cannot bypass capacity")
	var ci = Marching.Ids.new()
	ci.restore(combo.arena.world.entities)
	var varn_ids: Array = combo.groups[1].ids
	for i in range(varn_ids.size() - 1): ci.retire(varn_ids[i])
	combo.arena.world.entities = ci.snapshot()
	check(combo.capacity_used() == 7, "partial swarm loss does not free Varn capacity")
	ci.retire(varn_ids[-1]); combo.arena.world.entities = ci.snapshot()
	check(combo.capacity_used() == 6 and combo.power == 89, "last Varn removed frees capacity but refunds no power")
	var sooge: Dictionary = ci.get_entity(combo.groups[0].ids[0])
	sooge.attributes["charm_owner"] = 0
	sooge.attributes["sprite_form"] = "turret"
	sooge.attributes["step_fp"] = 0
	ci.update(sooge.id, 1, sooge.attributes); combo.arena.world.entities = ci.snapshot()
	check(combo.capacity_used() == 6, "charm and transformation keep original summon capacity occupied")
	ci.retire(sooge.id); combo.arena.world.entities = ci.snapshot()
	check(combo.capacity_used() == 0, "permanent banishment frees the departed summon")
	var repeats = Model.new("repeat")
	repeats.power = 100
	repeats.deploy("Varn", Vector2(180,150)); repeats.deploy("Varn", Vector2(350,400))
	check(repeats.groups.size() == 2 and repeats.capacity_used() == 2, "duplicate affordable swarms allowed within capacity")
	# Player recruitment cannot alter enemy body counts or placement.
	var left = Model.new("enemy-independence")
	var right = Model.new("enemy-independence")
	right.deploy("Penitent", Vector2(200,300)); right.deploy("Varn", Vector2(350,300))
	left.begin(); right.begin()
	check(left.arena.units().filter(func(u): return u.owner == 1) == right.arena.units().filter(func(u): return u.owner == 1), "enemy positions and IDs are independent of player spawn count")
	var full = Model.new("full")
	for i in range(Model.Arena.LIMIT): full.arena.spawn("Penitent", 0)
	var first_wave: Array = full.forecast()
	check(full.begin().has("world") and full.waiting_enemies == first_wave, "capacity-blocked enemies remain exact queued orders")
	var wi = Marching.Ids.new(); wi.restore(full.arena.world.entities)
	for unit in full.arena.units(): wi.retire(unit.id)
	full.arena.world.entities = wi.snapshot()
	full.accept({"action":"resolved", "world":full.arena.world})
	full.begin()
	check(full.waiting_enemies.is_empty() and full.arena.units().size() >= first_wave.size(), "queued orders deploy later without blocking round advancement")
	# Gate objective: simultaneous impacts and victory have no seat priority.
	var gate = Model.new("gate")
	gate.arena.spawn("Butcher", 0)
	var ids = Marching.Buffer.new()
	ids.restore(gate.arena.world.entities)
	var u: Dictionary = ids.marchers()[0]
	u.attributes.x_fp = 2400
	u.attributes.waiting = true
	u.attributes.waiting_since_round = 1
	ids.update(u.id, u.owner, u.attributes)
	gate.arena.world.data.encounter.gate_hp[1] = 3
	Objectives.step(gate.arena.world, ids, 1, 0)
	check(gate.arena.world.data.encounter.outcome == "victory", "gate breach ends encounter")
	var lamp = Model.new("lamp", "lamp")
	lamp.arena.spawn("Butcher", 0)
	ids.restore(lamp.arena.world.entities)
	u = ids.marchers()[0]
	u.attributes.x_fp = 1200
	u.attributes.y_fp = 300
	ids.update(u.id, 0, u.attributes)
	Objectives.step(lamp.arena.world, ids, 1, 0)
	check(lamp.arena.world.data.encounter.carrier.is_empty(), "lamp cannot be grabbed instantly")
	for tick in range(1, Objectives.SECURE_TICKS): Objectives.step(lamp.arena.world, ids, 1, tick)
	check(lamp.arena.world.data.encounter.carrier == u.id and ids.get_entity(u.id).attributes.encounter_carrier, "ordinary troop picks up lamp")
	lamp.arena.world.entities = ids.snapshot()
	var run_lamp: Dictionary = Model.resolve(lamp.arena.world, "lamp", 1)
	check(run_lamp.action == "resolved" and run_lamp.world.entities.entities[0].attributes.x_fp < 1200, "carrier physically walks toward own camp")
	ids.retire(u.id)
	Objectives.step(lamp.arena.world, ids, 1, 1)
	check(lamp.arena.world.data.encounter.carrier.is_empty() and lamp.arena.world.data.encounter.lamp_x == 1200, "death or banishment drops lamp at last position")
	var enemy = Model.new("enemy-lamp", "lamp")
	enemy.arena.spawn("Penitent", 1)
	ids.restore(enemy.arena.world.entities)
	u = ids.marchers()[0]
	u.attributes.x_fp = 1200
	u.attributes.y_fp = 300
	ids.update(u.id, 1, u.attributes)
	for tick in range(Objectives.SECURE_TICKS): Objectives.step(enemy.arena.world, ids, 1, tick)
	u = ids.get_entity(u.id)
	u.attributes.x_fp = 2335
	ids.update(u.id, 1, u.attributes)
	Objectives.step(enemy.arena.world, ids, 1, 1)
	check(enemy.arena.world.data.encounter.outcome == "defeat", "enemy extraction ends in defeat")
	# Early victories must remain valid replay tapes, with the real tick length.
	var quick = Model.new("quick", "lamp")
	quick.arena.spawn("Butcher", 0)
	var quick_id: String = quick.arena.units()[0].id
	quick.arena.world.entities.entities[0].attributes.x_fp = 68
	quick.arena.world.entities.entities[0].attributes["encounter_carrier"] = true
	quick.arena.world.data.encounter.carrier = quick_id
	quick.arena.world.data.encounter.carrier_owner = 0
	var quick_result: Dictionary = Model.resolve(quick.arena.world, "quick", 1)
	var tape = preload("res://Prototype/U13/U13SmokePlayback.gd").new()
	check(quick_result.world.data.encounter.outcome == "victory" and tape.build(quick_result.events.map(func(row): return row.event)), "early victory produces complete playable tape")
	check(tape.duration < 1.0, "victory stops at actual extraction time")
	var charmed = Model.new("charm", "lamp")
	charmed.arena.spawn("Butcher", 0)
	ids.restore(charmed.arena.world.entities)
	u = ids.marchers()[0]
	u.attributes.x_fp = 1200
	u.attributes.y_fp = 300
	ids.update(u.id, 0, u.attributes)
	for tick in range(Objectives.SECURE_TICKS): Objectives.step(charmed.arena.world, ids, 1, tick)
	u = ids.get_entity(u.id)
	u.attributes.direction = -1
	ids.update(u.id, 1, u.attributes)
	Objectives.step(charmed.arena.world, ids, 1, 1)
	check(charmed.arena.world.data.encounter.carrier.is_empty() and not ids.get_entity(u.id).attributes.has("encounter_carrier"), "charm drops lamp and clears carrier movement")
	# Both sides, including visible monsters, deny uncontested pickup.
	var control = Model.new("control", "lamp")
	control.arena.spawn("Butcher", 0)
	control.arena.spawn("Lemek", 1)
	ids.restore(control.arena.world.entities)
	var attacker: Dictionary = ids.marchers().filter(func(row): return row.owner == 0)[0]
	var defender: Dictionary = ids.marchers().filter(func(row): return row.owner == 1)[0]
	attacker.attributes.x_fp = 1200
	attacker.attributes.y_fp = 300
	defender.attributes.x_fp = 1600
	defender.attributes.y_fp = 300
	ids.update(attacker.id, 0, attacker.attributes)
	ids.update(defender.id, 1, defender.attributes)
	for tick in range(20): Objectives.step(control.arena.world, ids, 1, tick)
	check(control.arena.world.data.encounter.secure_ticks == 20, "uncontested pickup accumulates control time")
	defender.attributes.x_fp = 1450
	ids.update(defender.id, 1, defender.attributes)
	Objectives.step(control.arena.world, ids, 1, 20)
	check(control.arena.world.data.encounter.contested and control.arena.world.data.encounter.secure_ticks == 0, "enemy monster resets pickup progress")
	ids.retire(defender.id)
	for tick in range(1, Objectives.SECURE_TICKS): Objectives.step(control.arena.world, ids, 1, 20 + tick)
	check(control.arena.world.data.encounter.carrier.is_empty(), "clearing defenders requires a fresh full hold")
	Objectives.step(control.arena.world, ids, 1, 60)
	check(control.arena.world.data.encounter.carrier == attacker.id, "clearing and holding awards the lamp")
	var seeker = Model.new("seeker", "lamp")
	seeker.arena.spawn("Butcher", 0)
	seeker.arena.world.entities.entities[0].attributes.x_fp = 1400
	seeker.arena.world.entities.entities[0].attributes.y_fp = 500
	var sought: Dictionary = Model.resolve(seeker.arena.world, "seeker", 1)
	check(sought.action == "resolved" and not sought.world.data.encounter.carrier.is_empty(), "idle marcher returns to an off-axis loose lamp and secures it")
	# Impossibility is conservative about charm and future carriers.
	var impossible = Model.new("impossible", "lamp", 2, 1, [])
	impossible.reinforcements_received = true
	for suit in Model.SUITS: impossible.ordinary[suit] = 0
	var lost: Dictionary = combat(impossible)
	check(lost.world.data.encounter.outcome == "defeat" and lost.world.data.encounter.winning_tick == 0 and tape.build(lost.events.map(func(row): return row.event)), "no recoverable carrier ends Lamp at tick zero with valid replay")
	impossible.accept(lost)
	check(impossible.aftermath.run_continues and impossible.aftermath.marring_eligible and not impossible.aftermath.reward_eligible, "mission failure previews marring without ending run")
	var possible = Model.new("recoverable", "lamp")
	possible.reinforcements_received = true
	for suit in Model.SUITS: possible.ordinary[suit] = 0
	possible._sync_objective_inputs()
	check(Objectives.carrier_possible(possible.arena.world.data.encounter, []), "future affordable Fyra and enemy ordinary reserves prevent false impossibility")
	possible.arena.spawn("Penitent", 0)
	var pi = Marching.Ids.new(); pi.restore(possible.arena.world.entities)
	var pu: Dictionary = possible.arena.units()[0]
	pu.attributes["charm_owner"] = 0; pi.update(pu.id, 1, pu.attributes)
	possible.arena.world.data.encounter.future_charm = false
	possible.arena.world.data.encounter.enemy_ordinary_pending = false
	check(Objectives.carrier_possible(possible.arena.world.data.encounter, pi.snapshot().entities), "temporarily charmed own marcher can return")
	for mode in ["gate", "lamp"]:
		var deadline = Model.new("deadline", mode)
		deadline.arena.round_number = deadline.round_limit()
		deadline.phase = "resolving"
		deadline.accept({"action":"resolved", "world": deadline.arena.world})
		check(deadline.phase == "finished" and deadline.aftermath.outcome == "defeat", mode + " published deadline remains binding")
	var withdraw = Model.new("withdraw")
	check(withdraw.withdraw() and not withdraw.withdraw() and withdraw.aftermath.grade_ceiling == "worst" and withdraw.aftermath.marring_eligible, "withdraw is an idempotent failure and worst possible future grade")
	var blocked = Model.new("blocked-withdraw")
	blocked.begin()
	check(not blocked.withdraw(), "withdraw cannot mutate a resolving worker world")
	quick.phase = "resolving"; quick.accept(quick_result)
	check(quick.aftermath.reward_eligible and quick.aftermath.promotion_eligible and quick.aftermath.preview_only, "victory previews reward and promotion without persistent writes")
	root.size = Vector2i(1440, 810)
	var lab = Lab.new(); lab.embedded = true; root.add_child(lab)
	await process_frame
	check(lab.model.ordinary_remaining() == 14 and lab.hand_row.get_child_count() == 4, "UI exposes four finite ordinary pools")
	check(lab.speed.selected == 1 and Lab.SPEEDS[lab.speed.selected] == 3.0, "UI defaults to 3x with explicit rate mapping")
	check(lab.forecast.text.contains("THIS ROUND") and lab.forecast.text.contains("NEXT ROUND"), "UI displays two locked waves")
	check(lab.forecast.text.contains(lab.model.enemy_plan.to_upper()) and lab.forecast.text.contains("approach"), "UI exposes plan and approach before player commitment")
	check(lab._suit_hint("Penitent").contains("50%") and lab._suit_hint("Vulture").contains("+1"), "UI explains existing marcher counters")
	await process_frame; await process_frame
	var bounds := Rect2(Vector2.ZERO, Vector2(1440,810))
	check(bounds.encloses(lab.speed.get_global_rect()) and bounds.encloses(lab.flip.get_global_rect()) and bounds.encloses(lab.hand_row.get_global_rect()), "planning controls fit 1440 by 810 window")
	lab._select("Penitent", -1)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true
	click.position = lab.field.point(200,300)
	lab.field._gui_input(click)
	check(lab.model.ordinary.Penitent == 4, "UI placement consumes chosen reserve")
	lab._undo(); check(lab.model.ordinary.Penitent == 5, "UI undo restores reserve")
	lab.speed.select(3); lab.restart()
	check(lab.speed.selected == 3, "restart preserves chosen playback speed")
	lab._request_withdraw(); check(lab.withdraw_dialog.visible, "withdraw opens concrete consequence confirmation")
	lab.withdraw_dialog.hide(); lab._withdraw()
	check(lab.model.phase == "finished" and lab.status.text.contains("No campaign changes"), "UI withdrawal shows local aftermath")
	var endpoint: Dictionary = {}
	lab.set_process(false)
	for rate in range(Lab.SPEEDS.size()):
		lab.speed.select(rate); lab.restart()
		lab._select("Penitent", -1); lab._place(Vector2(200,300))
		lab._begin()
		while lab.worker != null and lab.worker.is_alive(): await create_timer(0.01).timeout
		lab._process(0.0)
		check(lab.model.phase == "playback", "%sx starts a real worker replay" % Lab.SPEEDS[rate])
		lab._pause(); lab._process(0.5)
		check(lab.elapsed == 0.0, "%sx pause freezes replay" % Lab.SPEEDS[rate])
		lab._pause(); lab._process(0.62)
		check(lab.elapsed == 0.0 and not lab.field.hourglass.is_turning(), "hourglass landing uses no replay time")
		lab._process(0.25)
		check(is_equal_approx(lab.elapsed, 0.25 * float(Lab.SPEEDS[rate])), "%sx advances at selected rate" % Lab.SPEEDS[rate])
		for frame in range(100):
			if lab.model.phase != "playback": break
			lab._process(0.25)
		if rate == 0: endpoint = lab.model.arena.world.duplicate(true)
		check(lab.model.phase == "planning" and lab.model.arena.round_number == 2 and lab.model.arena.world == endpoint, "%sx replay commits identical final world" % Lab.SPEEDS[rate])
	# The earliest possible failure still traverses worker -> replay -> aftermath.
	lab.restart(); lab.model = Model.new("ui-impossible", "lamp", 2, 1, [])
	lab.model.reinforcements_received = true
	for suit in Model.SUITS: lab.model.ordinary[suit] = 0
	lab.model.waves = []
	lab._begin()
	while lab.worker != null and lab.worker.is_alive(): await create_timer(0.01).timeout
	lab._process(0.62) # hourglass introduction
	lab._process(0.25)
	check(lab.model.phase == "finished" and lab.shown_objective.outcome == "defeat" and lab.field.objective.outcome == "defeat", "Lamp impossibility displays the same ending as committed world")
	for mode in ["gate", "lamp"]:
		lab.restart(); lab.model = Model.new("ui-reinforcements", mode, 2, 1, [])
		lab.model.waves = []
		lab.model.arena.round_number = lab.model.reinforcement_round() - 1
		for suit in Model.SUITS: lab.model.ordinary[suit] = 0
		lab._refresh()
		check(lab.forecast.text.contains("YOUR REINFORCEMENTS"), mode + " UI announces shipment before arrival")
		lab._begin()
		while lab.worker != null and lab.worker.is_alive(): await create_timer(0.01).timeout
		lab._process(0.0)
		check(lab.model.phase == "playback" and lab.model.ordinary_remaining() == 0, mode + " replay does not deliver shipment early")
		lab._process(0.62) # finish the presentation intro before advancing the tape
		lab._process(100.0)
		check(lab.model.phase == "planning" and lab.model.ordinary_remaining() == 8 and lab.model.deployments == 0, mode + " replay completion delivers usable reserves")
		check(lab.forecast.text.contains("REINFORCEMENTS ARRIVED") and lab.status.text.contains("Reinforcements arrived"), mode + " UI announces completed arrival")
	lab.dismiss(); await process_frame
	print("Crossing checks complete: %d passed, %d failed." % [checks - failed, failed])
	quit(1 if failed else 0)
