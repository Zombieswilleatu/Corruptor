extends SceneTree
const Model = preload("res://Prototype/U13/Encounters/U13EncounterModel.gd")
const Policy = preload("res://Scripts/Sim/U13CrossingTacticalPolicy.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var jobs_file := FileAccess.open(OS.get_environment("CROSSING_JOBS"),FileAccess.READ)
	var jobs: Array = JSON.parse_string(jobs_file.get_as_text());jobs_file.close()
	var output := FileAccess.open(OS.get_environment("CROSSING_RESULTS"),FileAccess.WRITE)
	for job in jobs:
		var script = Model if not job.has("model") else load(str(job.model))
		var m = script.new("crossing-%d" % int(job.seed),job.mode,2,int(job.level))
		var retinue: String = str(job.get("retinue",Policy.pick_retinue(m)))
		m.leader=retinue
		for suit in Model.SUITS:m.ordinary[suit]=3+(2 if suit==retinue else 0)
		m._sync_objective_inputs();m.start_metrics=m.planning_metrics()
		var decisions: Array = []
		var timeline: Array = []
		var started: int = Time.get_ticks_msec()
		while m.phase=="planning":
			var choice: Dictionary = Policy.choose(m,str(job.get("policy","counter")))
			choice["round"]=m.arena.round_number
			decisions.append(choice)
			var request: Dictionary = m.begin()
			if request.has("error"):push_error(str(request));quit(2);return
			var result: Dictionary = script.resolve(request.world,request.seed,request.round)
			if not m.accept(result):push_error(str(result));quit(2);return
			timeline.append({"round":request.round,"own":m.arena.units().filter(func(u):return u.owner==0).size(),"enemy":m.arena.units().filter(func(u):return u.owner==1).size(),"gate":m.arena.world.data.encounter.gate_hp.duplicate(),"carrier":m.arena.world.data.encounter.carrier_owner})
		var record: Dictionary = job.duplicate(true)
		record.merge({"retinue":retinue,"outcome":m.aftermath.outcome,"round":m.arena.round_number,"reason":m.aftermath.reason,"plan":m.enemy_plan,"metrics":m.metrics,"decisions":decisions,"timeline":timeline,"milliseconds":Time.get_ticks_msec()-started})
		output.store_line(JSON.stringify(record));output.flush()
		print(JSON.stringify({"seed":job.seed,"mode":job.mode,"level":job.level,"policy":job.get("policy","counter"),"outcome":m.aftermath.outcome,"round":m.arena.round_number}))
	output.close();quit()
