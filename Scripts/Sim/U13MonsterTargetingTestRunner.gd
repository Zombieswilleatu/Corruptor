extends "res://Scripts/Sim/U13MonsterTestRunner.gd"

const FieldMelee = preload("res://Scripts/Sim/U13FieldMelee.gd")
const Playback = preload("res://Prototype/U13/U13SmokePlayback.gd")

func portal_target_checks() -> void:
	for pid in [0, 1]:
		var direction: int = 1 if pid == 0 else -1
		for distance_fp in [600, 601]:
			var w: Dictionary = phase_world()
			var source: Dictionary = put(w, "Sinodek", pid, 1200, {"step_fp": 0})
			var prey: Dictionary = put(w, "Butcher", 1-pid, 1200 + direction * distance_fp, {"step_fp": 0})
			var result: Dictionary = phase("portal_boundary_%d_%d" % [pid, distance_fp], w, selected_seed(source.id, "PORTAL", 25))
			var portals: Array = facts(result, "MONSTER_FIELD_CREATED")
			check(portals.size() == (1 if distance_fp == 600 else 0), "Sinodek range includes 600 and excludes 601 on either seat")
			if not portals.is_empty():
				check(portals[0].field.target_id == prey.id and portals[0].field.x_fp == prey.attributes.x_fp, "portal is centered on the selected enemy")
			else:
				check(not Kanifous._entity(result.world, source.id).attributes.has("sinodek_portal_round"), "out-of-range enemies do not spend a portal attempt")
		var w: Dictionary = phase_world()
		var source: Dictionary = put(w, "Sinodek", pid, 1200, {"step_fp": 0})
		var ally: Dictionary = put(w, "Butcher", pid, 1200 + direction * 100, {"step_fp": 0})
		put(w, "Dotra", 1-pid, 1200 + direction * 350, {"hidden": true, "step_fp": 0})
		put(w, "Butcher", 1-pid, 1200 + direction * 50, {"lane": "Castle", "step_fp": 0})
		var prey: Dictionary = put(w, "Butcher", 1-pid, 1200 + direction * 500, {"step_fp": 0}, 1)
		put(w, "Vulture", 1-pid, 1200 + direction * 590, {"step_fp": 0})
		var result: Dictionary = phase("portal_nearest_visible_%d" % pid, w, selected_seed(source.id, "PORTAL", 25))
		var portals: Array = facts(result, "MONSTER_FIELD_CREATED")
		check(portals.size() == 1 and portals[0].field.target_id == prey.id, "nearer allies, concealed enemies and other lanes cannot become portal targets")
		check(not Kanifous._entity(result.world, ally.id).is_empty(), "nearby friendly front line is not the portal center")
		w = phase_world()
		source = put(w, "Sinodek", pid, 1200, {"step_fp": 0})
		prey = put(w, "Butcher", 1-pid, 1200 + direction * 700)
		result = phase("portal_enemy_enters_range_%d" % pid, w, selected_seed(source.id, "PORTAL", 25))
		portals = facts(result, "MONSTER_FIELD_CREATED")
		check(portals.size() == 1 and portals[0].tick > 0 and portals[0].field.target_id == prey.id, "Sinodek can attempt once when an enemy enters range after the phase begins")
		if not portals.is_empty():
			var playback = Playback.new()
			check(playback.build(result.events.map(func(row): return row.event)), "delayed portal replay builds")
			var at: float = playback.tick_time(portals[0].tick)
			check(playback.sample(at - 0.0001).monster_fields.is_empty() and playback.sample(at + 0.0001).monster_fields.size() == 1, "portal appears at its actual casting tick in replay")
		w = phase_world()
		source = put(w, "Sinodek", pid, 1200, {"step_fp": 0})
		put(w, "Butcher", pid, 1500, {"step_fp": 0})
		result = phase("portal_allies_only_%d" % pid, w, selected_seed(source.id, "PORTAL", 25))
		check(facts(result, "MONSTER_FIELD_CREATED").is_empty(), "Sinodek never opens a portal when only allies are present")

func portal_attempt_checks() -> void:
	var w: Dictionary = phase_world()
	var source: Dictionary = put(w, "Sinodek", 0, 1200, {"step_fp": 0})
	put(w, "Butcher", 1, 1700, {"step_fp": 0})
	var seed_value: String = ""
	for i in range(1000):
		var candidate: String = "portal-attempt:%d" % i
		if MonsterFX.Lamp.draw(candidate, source.id + ":2", "PORTAL", 100) >= 25 and MonsterFX.Lamp.draw(candidate, source.id + ":3", "PORTAL", 100) < 25:
			seed_value = candidate
			break
	check(not seed_value.is_empty(), "fixture misses this round and succeeds next round")
	var result: Dictionary = phase("portal_failed_attempt", w, seed_value)
	check(facts(result, "MONSTER_FIELD_CREATED").is_empty() and Kanifous._entity(result.world, source.id).attributes.sinodek_portal_round == 2, "a failed portal roll consumes exactly one round's attempt")
	var saved: Dictionary = JSON.parse_string(Game.encode_snapshot(result.world))
	w = bytes_to_var(Marshalls.base64_to_raw(saved.payload))
	check(w == result.world and Monsters.valid(w), "portal attempt survives save and reload")
	var buffer = Marching.Buffer.new(); buffer.restore(w.entities)
	for tick in [0, 1, 199]:
		var again: Dictionary = MonsterFX.step(w, buffer, context(w, seed_value), tick, Callable(Game.Content.new(), "react"))
		check(facts(again, "MONSTER_FIELD_CREATED").is_empty() and buffer.get_entity(source.id).attributes.sinodek_portal_round == 2, "same-round steps cannot retry a spent portal roll")
	result = phase("portal_next_round_attempt", w, seed_value, 3)
	check(facts(result, "MONSTER_FIELD_CREATED").size() == 1, "the next active round restores the portal attempt")
	for value in [-1, 0.5, "1", true, null]:
		var forged: Dictionary = source.attributes.duplicate(true)
		forged["sinodek_portal_round"] = value
		check(not Monsters.valid_unit(forged), "invalid portal attempt counter is rejected")

func hunt_damage_checks() -> void:
	for pid in [0, 1]:
		var direction: int = 1 if pid == 0 else -1
		for marked in [true, false]:
			for armor in ([0, 2] if marked else [0]):
				var w: Dictionary = phase_world()
				var dog: Dictionary = put(w, "Tumler", pid, 1200)
				var prey: Dictionary = put(w, "Vulture" if marked else "Kurchin", 1-pid, 1200 + direction * 60, {"armor": armor, "max_armor": 2, "hp": 20, "max_hp": 20})
				var other: Dictionary = put(w, "Vulture", 1-pid, 1200 + direction * 500, {}, 1)
				dog.attributes["hunt_target"] = prey.id if marked else other.id
				var buffer = Marching.Buffer.new(); buffer.restore(w.entities)
				buffer.update(dog.id, dog.owner, dog.attributes)
				# An unrelated taunt may redirect melee without replacing the mark.
				var hit: Dictionary = FieldMelee.resolve(w, buffer, context(w), 0, {}, Callable(Game.Content.new(), "react"))
				var shots: Array = facts(hit, "MARCHER_MELEE_ATTACK").filter(func(d): return d.attacker.id == dog.id)
				check(shots.size() == 1 and shots[0].target.id == prey.id and shots[0].damage_dealt == (3 - armor if marked else 2), "Tumler deals 3 before Armor to marked prey and 2 to an unmarked taunt")
				check(buffer.get_entity(dog.id).attributes.attack == 2, "hunt bonus never changes Tumler's base attack stat")
		var w: Dictionary = phase_world()
		var dog: Dictionary = put(w, "Tumler", pid, 1200)
		var prey: Dictionary = put(w, "Vulture", 1-pid, 1200 + direction * 500)
		var interceptor: Dictionary = put(w, "Butcher", 1-pid, 1200 + direction * 60)
		dog.attributes["hunt_target"] = prey.id
		Kanifous._entity(w, dog.id).attributes["hunt_target"] = prey.id
		var retarget: Array = MonsterFX.intercept(dog, interceptor, w.entities.entities.filter(func(u): return u.kind == "marcher"), context(w), 0)
		check(retarget.size() == 1 and MonsterFX.hunt_bonus(dog, interceptor) == 1 and MonsterFX.hunt_bonus(dog, prey) == 0, "a landed interception transfers the damage bonus to the new marked individual")
		var fake_wall: Dictionary = interceptor.duplicate(true)
		fake_wall.kind = "fortification"
		check(MonsterFX.hunt_bonus(dog, fake_wall) == 0, "walls cannot inherit a hunt bonus")
		# Capture complete production movement/combat for native/Python parity.
		phase("tumler_hunt_interception_%d" % pid, w)

func charm_rate_checks() -> void:
	for pid in [0, 1]:
		for roll in [int(Monsters.TUNING.fyra_charm_chance)-1, int(Monsters.TUNING.fyra_charm_chance)]:
			var w: Dictionary = phase_world()
			var source: Dictionary = put(w, "Fyra", pid, 1200, {"step_fp": 0, "hp": 100, "max_hp": 100})
			var prey: Dictionary = put(w, "Butcher", 1-pid, 1260, {"step_fp": 0, "hp": 100, "max_hp": 100, "armor": 0, "attack": 1})
			var seed_value: String = ""
			for i in range(10000):
				var candidate: String = "charm-boundary:%d" % i
				if MonsterFX.Lamp.draw(candidate, "%s:2:0:%s" % [source.id, prey.id], "CHARM", 100) == roll:
					seed_value = candidate
					break
			check(not seed_value.is_empty(), "charm chance boundary has a deterministic fixture")
			var result: Dictionary = phase("charm_rate_%d_%d" % [pid, roll], w, seed_value)
			var first_charms: Array = facts(result, "MONSTER_CHARMED").filter(func(d): return d.tick == 0)
			check(first_charms.size() == (1 if roll < Monsters.TUNING.fyra_charm_chance else 0), "actual melee uses the tuned charm probability boundary")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty(): phase_output = FileAccess.open(args[0], FileAccess.WRITE)
	portal_target_checks()
	portal_attempt_checks()
	hunt_damage_checks()
	charm_rate_checks()
	if phase_output != null: phase_output.close()
	print("U13 targeted monster check failures: ", failures)
	quit(0 if failures == 0 else 1)
