extends "res://Scripts/Sim/U13MonsterTestRunner.gd"
const Crossing = preload("res://Scripts/Sim/U13CrossingMonsters.gd")
const Encounter = preload("res://Prototype/U13/Encounters/U13EncounterModel.gd")
const Field = preload("res://Prototype/U13/Encounters/U13EncounterField.gd")

func crossing_world() -> Dictionary:
	var w: Dictionary = phase_world()
	w.data["encounter"] = {"monster_profile": Crossing.PROFILE}
	return w

func tick_world(w: Dictionary, tick: int, seed_value: String = "crossing-monsters", number: int = 2) -> Dictionary:
	var buffer = Marching.Buffer.new(); buffer.restore(w.entities)
	var c: Dictionary = context(w, seed_value); c.round = number
	return MonsterFX.step(w, buffer, c, tick, Callable(Game.Content.new(), "react"))

func run() -> void:
	for owner in [0, 1]:
		var w: Dictionary = crossing_world()
		var dotra: Dictionary = put(w, "Dotra", owner, 300)
		w = tick_world(w, 0).world
		check(not Kanifous._entity(tick_world(w, 26).world, dotra.id).attributes.get("hidden", false), "Dotra remains visible during 2-second windup, side %d" % owner)
		w = tick_world(w, 27).world
		check(Kanifous._entity(w, dotra.id).attributes.hidden, "Dotra conceals at tick 27, side %d" % owner)
		put(w, "Butcher", 1-owner, 500)
		var ambush: Dictionary = tick_world(w, 28)
		check(facts(ambush, "MONSTER_ATTACK").any(func(d): return d.ability == "Ambush"), "early concealment produces a real ambush")
		check(facts(tick_world(ambush.world, 100), "MONSTER_CONCEALMENT").is_empty(), "Dotra never repeats concealment on same summon")
		w = phase_world(); dotra = put(w, "Dotra", owner, 300)
		w = tick_world(w, 0).world
		check(not Kanifous._entity(tick_world(w, 27).world, dotra.id).attributes.get("hidden", false), "main-game Dotra still needs 200 ticks")

		w = crossing_world()
		var sooge: Dictionary = put(w, "Sooge", owner, 100)
		var prey: Dictionary = put(w, "Butcher", 1-owner, 2200, {"hp": 100, "max_hp": 100, "armor": 0})
		w = tick_world(w, 0).world
		check(Kanifous._entity(w, sooge.id).attributes.sprite_form == "mobile", "Sooge does not root uselessly at camp")
		var buffer = Marching.Buffer.new(); buffer.restore(w.entities)
		prey = buffer.get_entity(prey.id); prey.attributes.x_fp = 1250
		buffer.update(prey.id, prey.owner, prey.attributes); w.entities = buffer.snapshot()
		var rooted: Dictionary = tick_world(w, 20)
		check(facts(rooted, "MONSTER_ROOTED").size() == 1 and Kanifous._entity(rooted.world, sooge.id).attributes.sprite_form == "turret", "Sooge roots immediately within 1200 mid-round")
		var fired: Dictionary = tick_world(rooted.world, 36)
		check(facts(fired, "MONSTER_BEAM_FIRED").size() == 1 and facts(fired, "MONSTER_BEAM_FIRED")[0].range_fp == 2400, "Sooge charges 16 ticks and fires extended beam")
		check(facts(tick_world(fired.world, 37), "MONSTER_BEAM_FIRED").is_empty(), "Sooge cannot spam beams")
		var blast: Dictionary = tick_world(fired.world, 44)
		check(facts(blast, "MONSTER_ATTACK").any(func(d): return d.ability == "Beam" and d.damage_dealt == 3), "beam retains original damage")
		var charging: Dictionary = tick_world(blast.world, 20, "crossing-monsters", 3)
		check(facts(charging, "MONSTER_BEAM_FIRED").is_empty(), "next round begins with charge, not an extra shot")
		check(facts(tick_world(charging.world, 36, "crossing-monsters", 3), "MONSTER_BEAM_FIRED").size() == 1, "Crossing beam cooldown stays exactly 200 ticks")

		w = crossing_world()
		var sino: Dictionary = put(w, "Sinodek", owner, 300)
		prey = put(w, "Butcher", 1-owner, 1201)
		w = tick_world(w, 0).world
		check(not Kanifous._entity(w, sino.id).attributes.has("sinodek_portal_round"), "out-of-range enemy spends no portal attempt")
		buffer = Marching.Buffer.new(); buffer.restore(w.entities)
		prey = buffer.get_entity(prey.id); prey.attributes.x_fp = 1200
		buffer.update(prey.id, prey.owner, prey.attributes); w.entities = buffer.snapshot()
		var opened: Dictionary = tick_world(w, 1)
		check(facts(opened, "MONSTER_FIELD_CREATED").size() == 1 and facts(opened, "MONSTER_BANISHED").size() == 1, "Sinodek first portal guaranteed at 900 and actually banishes")
		check(Kanifous._entity(opened.world, sino.id).attributes.crossing_portal_opened, "first-portal guarantee is saved on the summon")
		put(opened.world, "Butcher", 1-owner, 900, {}, 1)
		check(facts(tick_world(opened.world, 2), "MONSTER_FIELD_CREATED").is_empty(), "Sinodek gets at most one attempt per round")
		for wanted in [true, false]:
			var chosen_seed: String = ""
			for i in range(100):
				var candidate: String = "portal-next-%d" % i
				if (MonsterFX.Lamp.draw(candidate, sino.id + ":3", "PORTAL", 100) < 50) == wanted:
					chosen_seed = candidate; break
			var later: Dictionary = tick_world(opened.world.duplicate(true), 0, chosen_seed, 3)
			check((facts(later, "MONSTER_FIELD_CREATED").size() == 1) == wanted, "later portal obeys 50 percent roll, not permanent guarantee")

	var m = Encounter.new("mode-profile")
	check(Crossing.enabled(m.arena.world) and not Crossing.enabled(phase_world()), "only explicit Crossing worlds enable buffs")
	check(Field.unit_height({"attributes":{"monster_id":"Varn"}}) == 36.0 and Field.unit_height({"attributes":{"monster_id":"Varn"}}, true) == 31.0, "Varn living and death sprites are half size")
	check(Field.unit_height({"attributes":{"monster_id":"Lemek"}}) == 72.0 and Field.unit_height({"attributes":{"suit":"Vulture"}}) == 57.0, "other sprite sizes unchanged")
	check(Encounter.monster_ability("Sinodek").contains("900") and Encounter.monster_ability("Varn") == Monsters.ROSTER.Varn.ability, "tooltips describe mode-specific and unchanged abilities")
	# Exercise real Marching + event replay validation for the changed abilities.
	for name in ["Dotra", "Sooge", "Sinodek"]:
		var w: Dictionary = crossing_world()
		put(w, name, 0, 300)
		put(w, "Butcher", 1, 1200, {"hp": 100, "max_hp": 100})
		phase("crossing_" + name, w)
	# Existing main-game behavior remains covered by its original assertions.
	sooge_ramp_checks()
	beam_boundary_checks()
	sinodek_portal_checks()
	dotra_stalking_checks()
	print("Crossing monster checks complete: %d failed." % failures)
	quit(0 if failures == 0 else 1)
