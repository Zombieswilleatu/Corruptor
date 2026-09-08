extends SceneTree

const Session = preload("res://Scripts/Sim/U13LoadoutBoardSession.gd")
const Core = preload("res://Scripts/Sim/U13CoreScenario.gd")
const Combat = preload("res://Scripts/Sim/U13Combat.gd")
const Deimos = preload("res://Scripts/Sim/U13Deimos.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> bool:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1
	return ok


func _run() -> void:
	_screen_cases()
	_owner_replay()
	print("U13 Hunt failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _lord(world: Dictionary, pid: int) -> Dictionary:
	for entity in world.entities.entities:
		if entity.kind == "lord" and entity.owner == pid:
			return entity
	return {}


func _hunt_order(world: Dictionary, cards: Array) -> Dictionary:
	return {"action": "Hunt", "lane": "Lord", "target_id": _lord(world, 1).id, "card_ids": cards}


func _screen_cases() -> void:
	var content = Deimos.new(true, true, true)
	for lane in ["Lord", "Castle", ""]:
		var world: Dictionary = Core.duplicate_world()
		world.data["hunt_profile"] = Combat.HUNT_VERSION
		var cards: Array = world.data.card_zones.hands[0].slice(0, 2)
		var ward: Dictionary = (
			{}
			if lane.is_empty()
			else {
				"action": "Ward",
				"lane": lane,
				"card_ids": world.data.card_zones.hands[1].slice(2, 4)
			}
		)
		var result: Dictionary = Combat._resolve(
			{
				"world": world,
				"round": 1,
				"hook": Timeline.COMBAT_RESOLUTION,
				"player_order": [0, 1],
				"combat_orders": [_hunt_order(world, cards), ward],
				"seed": "hunt-screen"
			},
			Callable(content, "react")
		)
		if not _check(result.action == "resolved", "hunt_screen_resolves_" + lane):
			continue
		var fact: Dictionary = result.events.back().event.data
		_check(
			fact.ward_screen == (0 if lane.is_empty() else (7 if lane == "Lord" else 3)),
			"hunt_ward_screen_" + lane
		)
		_check(fact.banished == lane.is_empty(), "hunt_strict_lord_threshold_" + lane)
		if lane.is_empty():
			_check(
				(
					not _lord(result.world, 1).attributes.alive
					and result.world.data.breach_lord == "Gremory"
				),
				"hunt_banishment_and_breach"
			)
			_check(
				(
					result.world.players[0].resources.souls == 2
					and result.world.data.neutral_tears == 1
				),
				"hunt_banishment_rewards"
			)
	# Lord Guards and Sigils occupy their own lane, never the Castle Guard pool.
	var world: Dictionary = Core.duplicate_world()
	world.data["hunt_profile"] = Combat.HUNT_VERSION
	var entities = Ids.new()
	entities.restore(world.entities)
	for row in world.entities.entities:
		if row.kind == "card" and row.owner == 1 and row.attributes.get("role") == "guard":
			row.attributes.lane = "Lord"
			entities.update(row.id, row.owner, row.attributes)
	world.entities = entities.snapshot()
	world.data.sigils[1].Lord = "fresh"
	var cards: Array = world.data.card_zones.hands[0].slice(0, 2)
	var result: Dictionary = Combat._resolve(
		{
			"world": world,
			"round": 1,
			"hook": Timeline.COMBAT_RESOLUTION,
			"player_order": [0, 1],
			"combat_orders": [_hunt_order(world, cards), {}],
			"seed": "hunt-guards"
		},
		Callable(content, "react")
	)
	if _check(result.action == "resolved", "hunt_guard_sigil_chain_resolves"):
		var fact: Dictionary = result.events.back().event.data
		_check(
			fact.guards_defeated == 2 and fact.sigil_broken and not fact.banished,
			"hunt_guard_sigil_then_lord"
		)


func _owner_replay() -> void:
	var a = Session.new()
	a.hunt_enabled = true
	if not _check(a.reset().action != "invalid", "hunt_owner_starts"):
		return
	var start: Dictionary = a.checkpoint()
	var order: Dictionary = _hunt_order(start.match.world, a.board_view().world.hand.slice(0, 2))
	var wrong: Dictionary = order.duplicate(true)
	wrong.target_id = _lord(start.match.world, 0).id
	_check(a.choose([], wrong).action == "invalid", "hunt_rejects_own_lord")
	wrong = order.duplicate(true)
	wrong["resolved_damage"] = 99
	_check(a.choose([], wrong).action == "invalid", "hunt_rejects_caller_damage")
	_check(a.checkpoint() == start, "hunt_rejections_are_atomic")
	var old = Session.new()
	old.reset()
	_check(old.choose([], order).action == "invalid", "hunt_not_silently_enabled_for_old_profiles")
	_check(a.choose([], order).action != "invalid", "hunt_submission_legal")
	a._opponent = {"powers": [], "order": {}}
	var b = Session.new()
	_check(b.restore_checkpoint(start).action != "invalid", "hunt_checkpoint_restores_policy")
	b.choose([], order)
	b._opponent = {"powers": [], "order": {}}
	for index in range(20):
		if a.next_hook().is_empty():
			break
		var left: Dictionary = a.step()
		var right: Dictionary = b.step()
		if not _check(
			left.action != "invalid" and right.action != "invalid", "hunt_hook_" + str(index)
		):
			return
		_check(a.checkpoint() == b.checkpoint(), "hunt_replay_" + str(index))
		var restored = Session.new()
		var raw: Dictionary = JSON.parse_string(JSON.stringify(a.checkpoint()))
		_check(
			restored.restore_checkpoint(raw).action != "invalid", "hunt_json_restore_" + str(index)
		)
	var final: Dictionary = a.checkpoint().match.world
	_check(not _lord(final, 1).attributes.alive, "hunt_full_owner_banishes")
	var spawned: int = 0
	for entity in final.entities.entities:
		if entity.kind == "marcher" and entity.owner == 0 and entity.attributes.lane == "Lord":
			spawned += 1
	_check(spawned == 2, "hunt_commitments_spawn_lord_lane_marchers")
