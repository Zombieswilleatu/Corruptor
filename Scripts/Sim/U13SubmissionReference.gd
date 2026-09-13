# Frozen e680d28 joint-submission transaction for differential checks.
# Rules, plans and resolution remain current; only transaction setup differs.
extends "res://Scripts/Sim/U13GameConductor.gd"

func submit(plans: Array) -> Dictionary:
	if _owner == null or plans.size() != 2 or _owner.next_hook() != Timeline.SUBMISSION_LOCK:
		return Data.invalid("game_submissions_invalid")
	# Both plans use one public snapshot. An invalid second submission must not
	# leave the first committed, paid, or queued in the live owner.
	var candidate = Content.new().create_combat_match(_owner._content_owner.batch_events)
	var restored: Dictionary = candidate.restore(_owner.snapshot())
	if restored.action == "invalid":
		return restored
	for pid in [0, 1]:
		var choice = plans[pid]
		if typeof(choice) != TYPE_DICTIONARY or typeof(choice.get("powers")) != TYPE_ARRAY or typeof(choice.get("order")) != TYPE_DICTIONARY:
			return Data.invalid("game_plan_invalid")
		var accepted: Dictionary = candidate.submit(pid, choice.powers, choice.order)
		if accepted.action == "invalid":
			return accepted
	_owner = candidate
	return {"action": "game_submitted"}
