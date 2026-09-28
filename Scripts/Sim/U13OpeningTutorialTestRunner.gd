extends SceneTree

const Catalog = preload("res://Prototype/U13/U13TutorialCatalog.gd")
var checks: int = 0
var failures: int = 0

func check(c: Dictionary, expected: bool, label: String) -> void:
	var offered: bool = Catalog.candidates(c).any(func(row): return row.id == "opening")
	checks += 1
	if offered != expected: failures += 1
	print(("PASS " if offered == expected else "FAIL ") + label)

func _initialize() -> void:
	var unit: Dictionary = {"id": "m1", "kind": "marcher", "owner": 0, "attributes": {"suit": "Penitent", "lane": "Lord", "hp": 5, "waiting": false, "movement_ready_round": 2}}
	var c: Dictionary = {"world": {}, "round": 1, "opening": true, "visible_units": [unit]}
	check(c, false, "round one never offers opening-march lesson")
	c.round = 2
	c.visible_units = []
	check(c, false, "empty opening tape offers no marching lesson")
	c.world = {"game_staging": {"lanes": {"Lord": {"units": [unit]}}}}
	check(c, false, "staged reserves do not count as visible field activity")
	c.world = {}
	c.visible_units = [unit]
	unit.attributes.waiting = true
	check(c, false, "Supplicants alone do not trigger marching lesson")
	unit.attributes.waiting = false
	unit.attributes.movement_ready_round = 3
	check(c, false, "birth-held units do not trigger marching lesson")
	unit.attributes.movement_ready_round = 2
	unit.attributes.hp = 0
	check(c, false, "dead units do not trigger marching lesson")
	unit.attributes.hp = 5
	check(c, true, "round two visible active marcher allows the lesson")
	unit.owner = 1
	check(c, true, "enemy marching also makes the lesson relevant")
	c.opening = false
	check(c, false, "field units outside opening playback do not trigger it")
	print("U13 Opening Tutorial: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
