extends SceneTree

const Session = preload("res://Scripts/Sim/U13LoadoutBoardSession.gd")
const Humbaba = preload("res://Scripts/Sim/U13Humbaba.gd")
const Candidates = preload("res://Scripts/Sim/U13HumbabaCandidates.gd")
const Slots = preload("res://Scripts/Sim/U13CastleSlots.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> bool:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1
	return ok


func _run() -> void:
	for lords in [["Humbaba", "Gremory"], ["Deimos", "Humbaba"], ["Humbaba", "Humbaba"]]:
		var session = Session.new()
		if not _check(
			session.configure(lords, [Slots.TYPES, Slots.TYPES], true).action != "invalid",
			"humbaba_loadout_" + str(lords)
		):
			continue
		var checkpoint: Dictionary = session.checkpoint()
		_check(
			session.hunt_enabled and session.next_hook() == Timeline.SUBMISSION_LOCK,
			"humbaba_loadout_hunt_and_planning"
		)
		for entity in checkpoint.match.world.entities.entities:
			if entity.kind == "lord" and lords[entity.owner] == "Humbaba":
				_check(
					entity.attributes.lord_id == "Humbaba" and not entity.attributes.has("threat"),
					"humbaba_loadout_owner_has_absent_threat"
				)
		var restored = Session.new()
		_check(
			(
				(
					(
						restored
						. restore_checkpoint(JSON.parse_string(JSON.stringify(checkpoint)))
						. action
					)
					!= "invalid"
				)
				and restored.checkpoint() == checkpoint
			),
			"humbaba_loadout_json_" + str(lords)
		)
		var fork = session._fork_for_job()
		_check(
			fork != null and fork.checkpoint() == checkpoint,
			"humbaba_loadout_worker_fork_preserves_policy"
		)
		if lords == ["Humbaba", "Humbaba"]:
			_two_auras(session)
		elif lords[1] == "Humbaba":
			var plan: Dictionary = session.random_opponent_plan()
			_check(
				(
					plan.action != "invalid"
					and plan.powers.size() == 1
					and plan.powers[0].power_id in [Humbaba.MUSTER, Humbaba.BREATH]
				),
				"humbaba_opponent_uses_own_legal_candidates"
			)
		_check(
			(
				(
					(
						restored
						. configure(["Humbaba", "Kalligan"], [Slots.TYPES, Slots.TYPES], false)
						. action
					)
					== "invalid"
				)
				and restored.checkpoint() == checkpoint
			),
			"humbaba_unimplemented_loadout_rejected_atomically"
		)
		var bad: Dictionary = checkpoint.duplicate(true)
		bad.board_setup.hunt = false
		_check(
			(
				restored.restore_checkpoint(bad).action == "invalid"
				and restored.checkpoint() == checkpoint
			),
			"humbaba_restore_rejects_wrong_hunt_policy"
		)
	print("U13 Humbaba board session failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _two_auras(session) -> void:
	var left: Dictionary = session.declaration(Humbaba.BREATH, 0, {"lane": "Lord"})
	session._opponent = {"powers": [Candidates.source(1, 1, "Castle", Humbaba.BREATH)], "order": {}}
	if not _check(
		session.choose([left], {}).action != "invalid", "two_humbabas_choose_independent_auras"
	):
		return
	while session.next_hook() != Timeline.MARCHING_START:
		if not _check(session.step().action != "invalid", "two_humbabas_hook"):
			return
	var view: Dictionary = session.board_view()
	_check(view.persistent.size() == 2, "two_humbabas_independent_active_instances")
	var lanes: Dictionary = {}
	for active in view.persistent:
		lanes[active.declaration.player_id] = active.target.lane
	_check(lanes == {0: "Lord", 1: "Castle"}, "two_humbabas_targets_and_owners_preserved")
	var checkpoint: Dictionary = session.checkpoint()
	var restored = Session.new()
	_check(
		(
			(
				restored.restore_checkpoint(JSON.parse_string(JSON.stringify(checkpoint))).action
				!= "invalid"
			)
			and restored.checkpoint() == checkpoint
		),
		"two_humbabas_active_auras_json"
	)
