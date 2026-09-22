extends SceneTree
const Flight = preload("res://Scripts/Sim/U13GuardConsume.gd")
const Scenario = preload("res://Scripts/Sim/U13KroniScenario.gd")
const Content = preload("res://Scripts/Sim/U13Kroni.gd")
var failed: int = 0
var checks: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		print("FAIL ",label)
func _initialize() -> void:
	var rows: Array = []
	for owner in [0,1]:
		for lane in ["Lord","Castle"]:
			for slot in range(3): rows.append({"id":"%d:%s:%d" % [owner,lane,slot],"kind":"card","owner":owner,"attributes":{"role":"guard","lane":lane,"slot":slot}})
	var exports: Array = []
	for index in range(100):
		for owner in [0,1]:
			var world: Dictionary = {"entities":{"entities":rows}}
			var seed_value: String = "guard-bias:%d" % index
			var result: Dictionary = Flight.choose(world,owner,seed_value,"probe")
			check(not result.victim_id.is_empty(),"full layout finds a guard")
			check(result == Flight.choose(world,owner,seed_value,"probe"),"keyed repeat exact")
			exports.append({"world":world,"owner":owner,"seed":seed_value,"key":"probe","result":result})
	for row in rows:
		for velocity in Flight.VELOCITIES:
			for sx in [-1,1]:
				for sy in [-1,1]: check(Flight.route([row],sx*velocity[0],sy*velocity[1]).victim_id == row.id,"single slot reached")
	var resolves: Array = []
	for index in range(24):
		var world: Dictionary = Scenario.world()
		var source: Dictionary = Scenario.source(0,1,{"mode":Flight.MODE},0,"Consume")
		var record: Dictionary = {"declaration":source,"fire_hook":source.fire_hook}
		var seed_value: String = "guard-resolve:%d" % index
		var context: Dictionary = {"world":world,"round":2,"hook":record.fire_hook,"seed":seed_value,"player_order":[0,1]}
		var result: Dictionary = Content.new().resolve(record,context)
		check(result.action == "resolved","bounce resolves")
		var meals: Array = result.events.filter(func(e):return e.event.type == "GUARD_DEVOURED")
		check(meals.size() == 1,"exactly one meal")
		check(result.world.data.kroni_fed[0] == 2,"either allegiance satisfies upkeep")
		var enemy: bool = meals[0].event.data.before.owner == 1
		check(Content.Hunger.hunger(result.world,0) == int(enemy),"only enemy grants Hunger")
		resolves.append({"world":world,"record":record,"seed":seed_value,"result":result})
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		var file = FileAccess.open(args[0],FileAccess.WRITE)
		file.store_string(JSON.stringify({"routes":exports,"resolves":resolves}))
	print("Guard Consume checks: %d; failures: %d" % [checks,failed])
	quit(1 if failed else 0)
