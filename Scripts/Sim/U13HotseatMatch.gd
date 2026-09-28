extends "res://Scripts/Sim/U13Match.gd"

# Only economy choices are accepted during the second seat's planning pause.
# No combat submission is installed until BOTH full turns have been sealed.
func submit_choice(player_id: int, choice: Dictionary) -> Dictionary:
	if _submissions != [null, null]: return Data.invalid("hotseat_choices_after_commit")
	var result: Dictionary = super.submit_choice(player_id, choice)
	if result.action != "invalid" and next_hook() == Timeline.SUBMISSION_LOCK:
		_presentation_world = _world.duplicate(true)
	return result

func submit(player_id: int, powers: Array, order: Dictionary = {}) -> Dictionary:
	if _world.data.hotseat_economy.stage != "complete": return Data.invalid("hotseat_economy_incomplete")
	return super.submit(player_id, powers, order)

func run_next_hook(timings: Dictionary = {}) -> Dictionary:
	if next_hook() == Timeline.SUBMISSION_LOCK and _world.data.hotseat_economy.stage != "complete": return Data.invalid("hotseat_economy_incomplete")
	return super.run_next_hook(timings)
