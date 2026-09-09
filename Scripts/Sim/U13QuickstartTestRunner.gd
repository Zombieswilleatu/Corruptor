extends SceneTree

const Picker = preload("res://Prototype/U13/U13LoadoutPicker.gd")
var failures: int = 0


func _init() -> void:
	var lords: Dictionary = {}
	var compositions: Dictionary = {}
	for index in range(32):
		var seed_value: String = "quickstart-test:" + str(index)
		var draft: Dictionary = Picker.quickstart_selection(seed_value)
		_check(draft == Picker.quickstart_selection(seed_value), "quickstart_replays_" + str(index))
		for pid in [0, 1]:
			_check(
				(
					draft.lords[pid] in Picker.LORDS
					and draft.castles[pid][0] == "Keep"
					and Picker.Slots.selection_valid(draft.castles[pid])
				),
				"quickstart_valid_keep_first_%d_%d" % [index, pid]
			)
			lords[draft.lords[pid]] = true
			compositions[str(draft.castles[pid])] = true
	_check(
		lords.size() == Picker.LORDS.size() and compositions.size() > 1,
		"quickstart_varies_both_roster_and_loadouts"
	)
	_check(Picker.quickstart_selection("").is_empty(), "quickstart_requires_seed")
	print("U13 quickstart failures: %d" % failures)
	quit(0 if failures == 0 else 1)


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print(("PASS  " if ok else "FAIL  ") + label)
