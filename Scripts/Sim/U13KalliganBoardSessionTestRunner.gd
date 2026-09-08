extends SceneTree

const Session = preload("res://Scripts/Sim/U13LoadoutBoardSession.gd")
const Kalligan = preload("res://Scripts/Sim/U13Kalligan.gd")
const Candidates = preload("res://Scripts/Sim/U13KalliganCandidates.gd")
const Slots = preload("res://Scripts/Sim/U13CastleSlots.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const Scorch = preload("res://Prototype/U13/U13ScorchPresentation.gd")
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> bool:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1
	return ok


func _run() -> void:
	for lords in [
		["Kalligan", "Gremory"],
		["Deimos", "Kalligan"],
		["Kalligan", "Humbaba"],
		["Kalligan", "Kalligan"]
	]:
		var session = Session.new()
		if not _check(
			session.configure(lords, [Slots.TYPES, Slots.TYPES], true).action != "invalid",
			"kalligan_loadout_" + str(lords)
		):
			continue
		var saved: Dictionary = session.checkpoint()
		_check(
			session.hunt_enabled and session.next_hook() == Timeline.SUBMISSION_LOCK,
			"kalligan_board_uses_hunt_owner"
		)
		var restored = Session.new()
		_check(
			(
				(
					restored.restore_checkpoint(JSON.parse_string(JSON.stringify(saved))).action
					!= "invalid"
				)
				and restored.checkpoint() == saved
			),
			"kalligan_loadout_json"
		)
		var fork = session._fork_for_job()
		_check(fork != null and fork.checkpoint() == saved, "kalligan_board_worker_fork")
		var bad: Dictionary = saved.duplicate(true)
		bad.board_setup.hunt = false
		_check(
			restored.restore_checkpoint(bad).action == "invalid" and restored.checkpoint() == saved,
			"kalligan_wrong_policy_restore_atomic"
		)
		_check(
			(
				(
					(
						restored
						. configure(["Kalligan", "Orias"], [Slots.TYPES, Slots.TYPES], true)
						. action
					)
					== "invalid"
				)
				and restored.checkpoint() == saved
			),
			"unsupported_loadout_still_atomic"
		)
		if lords == ["Deimos", "Kalligan"]:
			var plan: Dictionary = session.random_opponent_plan()
			_check(
				(
					plan.action != "invalid"
					and plan.powers.size() == 1
					and plan.powers[0].power_id == Kalligan.INFERNO
				),
				"kalligan_opponent_uses_legal_inferno"
			)
		if lords == ["Kalligan", "Kalligan"]:
			_mirror(session)
	print("U13 Kalligan board session failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _mirror(session) -> void:
	var source: Dictionary = session.declaration(
		Kalligan.INFERNO, 0, {"kind": "lane", "lane": "Lord"}
	)
	session._opponent = {
		"powers":
		[
			Candidates.source(
				1, 1, Kalligan.INFERNO, {"kind": "guard", "lane": "Castle", "player_id": 0}
			)
		],
		"order": {}
	}
	if not _check(session.choose([source], {}).action != "invalid", "mirror_inferno_plans_legal"):
		return
	for _hook in range(24):
		if session.next_hook().is_empty():
			break
		if not _check(session.step().action != "invalid", "mirror_board_hook"):
			return
	var pending_view: Dictionary = session.board_view()
	var pending: Array = Scorch.records(pending_view.persistent, pending_view.pending, 1)
	_check(
		pending.size() == 2 and pending[0].fire_round == 2 and pending[1].fire_round == 2,
		"both_infernos_telegraphed"
	)
	if not _check(session.next_round().action != "invalid", "mirror_prepared_fire_activates"):
		return
	var view: Dictionary = session.board_view()
	var rows: Array = Scorch.records(view.persistent, view.pending, 2)
	_check(
		(
			rows.size() == 2
			and Scorch.active_for(rows, 0).target.kind == "lane"
			and Scorch.active_for(rows, 1).target.player_id == 0
		),
		"mirror_scorch_locations_and_owners"
	)
	var saved: Dictionary = session.checkpoint()
	_check(
		(
			session.power_status(Kalligan.INFERNO).awaiting_expiration
			and (
				(
					session
					. preview_power(Kalligan.INFERNO, {"kind": "lane", "lane": "Castle"}, [], {})
					. action
				)
				!= "invalid"
			)
		),
		"relocation_available_while_expiration_clock_waits"
	)
	_check(
		(
			session.preview_power(Kalligan.PYROCLASM, {}, [], {}).action != "invalid"
			and session.checkpoint() == saved
		),
		"pyroclasm_readiness_is_pure"
	)
	var restored = Session.new()
	_check(
		(
			(
				restored.restore_checkpoint(JSON.parse_string(JSON.stringify(saved))).action
				!= "invalid"
			)
			and restored.checkpoint() == saved
		),
		"active_mirror_scorch_board_json"
	)
	rows[0].target.lane = "modified"
	_check(session.checkpoint() == saved, "scorch_presentation_isolated_from_owner")
