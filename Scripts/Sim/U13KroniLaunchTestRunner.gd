extends SceneTree

const Actors = preload("res://Scripts/Sim/U13KroniActors.gd")
const Visual = preload("res://Prototype/U13/U13KroniVisual.gd")
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var visual = Visual.new()
	var actor: Dictionary = Actors.create("size", 0, 1, 0)
	for row in range(4):
		for frame in range(6):
			visual.field_rect = Rect2(0, 0, 600, 900)
			var narrow: Vector2 = visual.sprite_extent(actor, row, frame)
			var footprint: Vector2 = visual.extent(actor)
			visual.field_rect.size.x = 1400
			var wide: Vector2 = visual.sprite_extent(actor, row, frame)
			var source: Vector2 = Visual.ROWS[row][frame].size
			check(narrow.is_equal_approx(wide), "lane widening preserves sprite size")
			check(is_equal_approx(wide.x / wide.y, source.x / source.y), "atlas frame aspect preserved")
			check(visual.extent(actor).x > footprint.x, "collision projection still follows lanes")
	var hungry: Dictionary = Actors.create("size", 0, 1, 3)
	check(visual.sprite_extent(hungry, 0, 0).x > visual.sprite_extent(actor, 0, 0).x, "Hunger still grows artwork")
	visual.free()
	var output: Array = []
	for owner in [0, 1]:
		for hunger in [0, 3]:
			for scenario in ["group", "single", "allies", "breach"]:
				var units: Array = []
				for i in range(1 if scenario == "single" else 3):
					units.append({"id": "unit-%d" % i, "kind": "marcher", "owner": owner if scenario == "allies" else 1-owner,
						"attributes": {"x_fp": 800+i*100 if owner == 0 else 1600-i*100, "y_fp": 100+i*50, "lane": "Castle"}})
				var start: Dictionary = {"lane": "Lord", "field_position": {"x_fp": 0 if owner == 0 else 2400, "y_fp": 450}}
				var seed_value: String = "launch:%d:%d:%s" % [owner, hunger, scenario]
				var result: Dictionary = Actors.create("cross-runtime", owner, 2, hunger, scenario == "breach", seed_value, start, units)
				check(result.launch_mode == ("breach" if scenario == "breach" else "favored" if scenario == "group" else "fallback"), "launch mode " + scenario)
				output.append({"owner": owner, "hunger": hunger, "breach": scenario == "breach", "seed": seed_value, "start": start, "units": units, "actor": result})
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		var file = FileAccess.open(args[0], FileAccess.WRITE)
		file.store_string(JSON.stringify(output, "\t"))
	print("Kroni launch/visual checks: ", checks, "; failures: ", failures)
	quit(1 if failures else 0)
