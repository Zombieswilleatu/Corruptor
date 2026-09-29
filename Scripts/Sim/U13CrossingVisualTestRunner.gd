extends SceneTree
const Field = preload("res://Prototype/U13/Encounters/U13EncounterField.gd")
const Model = preload("res://Prototype/U13/Encounters/U13EncounterModel.gd")
const Lab = preload("res://Prototype/U13/Encounters/U13EncounterLab.gd")
var checks := 0
var failed := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failed += 1
	print(("PASS " if value else "FAIL ") + message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440,810)
	var field := Field.new()
	root.add_child(field)
	field.size = Vector2(1400,350)
	field.set_process(false)
	await process_frame
	check(field.domain != null and field.domain.get_size().x > 1000, "real domain texture loaded")
	for monster in Model.Monsters.NAMES:
		var data: Dictionary = field.sprites.Catalog.assets(monster)
		check(not data.frames.is_empty(), monster + " uses the game's sprite assets")
	var state := Model.new("visuals", "lamp")
	state.arena.spawn("Wright",0)
	state.arena.spawn("Lemek",1)
	var units: Array = state.arena.units()
	var snapshot := {"units":units,"monster_fields":[{"id":"portal","kind":"portal","lane":"Lord","x_fp":1200,"y_fp":300}],"field_structures":[]}
	var before: Dictionary = snapshot.duplicate(true)
	field.show_state(snapshot,state.arena.world.data.encounter,1,true)
	var road := field.field()
	check(field.point(0,0).is_equal_approx(road.position) and field.point(2400,600).is_equal_approx(road.end), "world endpoints map to horizontal road")
	var pulse: PackedVector2Array = field.kopita_pulse_outline({"source":{"x_fp":1200,"y_fp":300},"range_fp":100})
	var extent := Rect2(pulse[0],Vector2.ZERO)
	for p in pulse: extent = extent.expand(p)
	check(is_equal_approx(extent.size.x, road.size.x / 12.0) and is_equal_approx(extent.size.y, road.size.y / 3.0), "pulse footprint uses horizontal world axes")
	var portal = field.horizontal_portals.portals.portal
	check(portal.circle.size.is_equal_approx(Vector2(road.size.x / 12.0, road.size.y / 3.0)), "Odradek portal has correct horizontal radius")
	field.size = Vector2(1000,300)
	field.horizontal_portals._update_geometry()
	check(portal.circle.get_center().is_equal_approx(field.get_global_transform_with_canvas() * field.point(1200,300)), "portal follows resized road")
	check(snapshot == before, "visual synchronization leaves recorded world unchanged")
	var clock := Lab.MarchClock.new(15.0)
	var elapsed: float = field.hourglass.advance_tape(clock,0.0,0.31)
	check(elapsed == 0.0 and field.hourglass.is_turning(), "hourglass spins without spending march time")
	elapsed = field.hourglass.advance_tape(clock,elapsed,0.31)
	check(elapsed == 0.0 and not field.hourglass.is_turning(), "hourglass lands before sand starts")
	elapsed = field.hourglass.advance_tape(clock,elapsed,3.0)
	check(is_equal_approx(elapsed,3.0) and is_equal_approx(field.hourglass._progress,0.2), "sand follows replay progress")
	field.hourglass.finish_tape(clock)
	check(field.hourglass._progress == 1.0, "completed phase empties top chamber")
	var empty_clock := Lab.MarchClock.new(15.0)
	elapsed = field.hourglass.advance_tape(empty_clock,0.0,0.62)
	check(elapsed == 0.0 and not field.hourglass._empty, "empty Crossing still preserves objective time")
	field.hourglass.reset()
	check(not field.hourglass.is_turning() and field.hourglass._active_tape == null, "restart clears old phase identity")
	field.queue_free()
	await process_frame
	print("Crossing visual checks complete: %d passed, %d failed." % [checks-failed,failed])
	quit(1 if failed else 0)
