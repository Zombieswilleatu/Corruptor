extends SceneTree

const Scenario = preload("res://Scripts/Sim/U13AlphaScenario.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_endurance_after_actual_marching()
	_legacy_keys_are_inert()
	print("U13 Marching audit failures: %d" % failures)
	quit(0 if failures == 0 else 1)


# Printed stats, real contact/exchanges, real Step 3 -> Step 12 -> Step 13.
# A damaged enemy waiter does not regenerate. Two Vulture bypass hits leave
# the Penitent at 1 HP; it defeats that waiter on its second exchange.
func _endurance_after_actual_marching() -> void:
	var world: Dictionary = Scenario.world(["Humbaba", "Gremory"])
	var ids = Ids.new()
	ids.restore(world.entities)
	var penitent: Dictionary = Marching.profile("Penitent", "Lord", 0, 0, 1)
	penitent.hp = 3
	penitent.x_fp = 100
	var created: Dictionary = ids.create("marcher", "audit:penitent", 0, 0, penitent)
	var penitent_id: String = created.entity.id
	var vulture: Dictionary = Marching.profile("Vulture", "Lord", 1, 0, 1)
	vulture.hp = 1
	vulture.x_fp = 0
	vulture.waiting = true
	vulture.waiting_since_round = 1
	created = ids.create("marcher", "audit:waiter", 0, 1, vulture)
	var vulture_id: String = created.entity.id
	world.entities = ids.snapshot()
	var owner = Scenario.create_owner()
	if not _check(
		owner.start("u13-marching-audit", world, [0, 1]).action != "invalid", "audit_owner_starts"
	):
		return
	var replay = Scenario.create_owner()
	var restored: bool = false
	while not owner.next_hook().is_empty():
		var hook: String = owner.next_hook()
		if hook == Timeline.SUBMISSION_LOCK:
			for pid in [0, 1]:
				if not _check(owner.submit(pid, [], {}).action != "invalid", "audit_pass_sealed"):
					return
		if hook == Timeline.MARCHING:
			if not _check(
				(
					replay.restore(JSON.parse_string(JSON.stringify(owner.snapshot()))).action
					!= "invalid"
				),
				"audit_pre_marching_json_restore"
			):
				return
			restored = true
		if not _check(owner.run_next_hook().action != "invalid", "audit_hook_" + hook):
			return
		if restored:
			if not _check(
				replay.run_next_hook().action != "invalid", "audit_restored_hook_" + hook
			):
				return
			_check(replay.snapshot() == owner.snapshot(), "audit_restored_state_" + hook)
		if hook == Timeline.ROUND_START_AUTOMATIC:
			_check(
				_entity(owner, penitent_id).attributes.hp == 5,
				"audit_penitent_regenerates_at_step_three"
			)
			_check(_entity(owner, vulture_id).attributes.hp == 1, "audit_waiter_skips_regeneration")
		if hook == Timeline.MARCHING:
			var survivor: Dictionary = _entity(owner, penitent_id)
			if not _check(not survivor.is_empty(), "audit_penitent_survives_real_duel"):
				return
			_check(survivor.attributes.hp == 1, "audit_real_marching_leaves_exactly_one_hp")
			_check(survivor.attributes.armor == 3, "audit_bypass_survivor_still_has_armor")
			_check(_entity(owner, vulture_id).is_empty(), "audit_waiter_defeated_by_real_duel")
		if hook == Timeline.END_MARCHING_CHECKS:
			var awarded: int = 0
			for event in owner.player_view(0).events:
				if (
					event.type == "NEUTRAL_TEAR_CREATED"
					and event.data.get("source") == "EnduranceOfTheFaithful"
				):
					awarded += int(event.data.amount)
			_check(awarded == 1, "audit_endurance_reachable_after_regen_and_marching")


func _entity(owner, entity_id: String) -> Dictionary:
	for row in owner.snapshot().world.entities.entities:
		if row.id == entity_id:
			return row
	return {}


func _legacy_keys_are_inert() -> void:
	var ids = Ids.new()
	for pid in [0, 1]:
		var a: Dictionary = Marching.profile("Vulture", "Castle", pid, 0, 1)
		a.x_fp = 900 if pid == 0 else 1500
		a.y_fp = 100 if pid == 0 else 500
		ids.create("marcher", "audit:legacy", pid, pid, a)
	var context: Dictionary = {
		"world": {"entities": ids.snapshot(), "data": {}},
		"hook": Timeline.MARCHING,
		"round": 1,
		"seed": "audit:legacy",
		"player_order": [0, 1]
	}
	var baseline: Dictionary = Marching.resolve(context, Callable(self, "_reaction"))
	if not _check(baseline.action == "resolved", "audit_legacy_baseline_resolves"):
		return
	var keys: Dictionary = {
		"march_steps": 1,
		"march_damage": 999,
		"march_suit_bonus": 999,
		"march_threshold": 1,
		"march_max_in_flight": 0,
		"march_exception_pair": true
	}
	context.world.data.merge(keys)
	var altered: Dictionary = Marching.resolve(context, Callable(self, "_reaction"))
	if not _check(altered.action == "resolved", "audit_legacy_sentinel_resolves"):
		return
	for key in keys:
		altered.world.data.erase(key)
	_check(altered == baseline, "audit_legacy_keys_do_not_change_positions_combat_or_events")


static func _reaction(
	world: Dictionary, _event: Dictionary, _seed: String, _order: Array
) -> Dictionary:
	return {"action": "resolved", "world": world, "events": []}


func _check(ok: bool, label: String) -> bool:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1
	return ok
