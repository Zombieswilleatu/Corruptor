extends SceneTree

const Play = preload("res://Scripts/Sim/U13PlayableSession.gd")
const HumanDriver = preload("res://Scripts/Sim/U13BasicDoctrine.gd")
const Job = preload("res://Prototype/U13/U13BoardJob.gd")
var failures: int = 0
var checks: int = 0
var observation_output
const Observation = preload("res://Scripts/Sim/U13CommonObservation.gd")
const Codec = preload("res://Scripts/Sim/U13ExactData.gd")

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", label)
	return ok

func trial(lords: Array) -> void:
	var play = Play.new()
	var commands: int = 0
	var released: int = 0
	var castles: Array = ["Keep", "Stockpile", "SummoningCircle", "Bastion", "SiegeEngine"]
	if not check(play.configure_seed("shared-playable-smoke:" + ":".join(lords), lords, [castles, castles]).action != "invalid", "configure"): return
	for round_index in range(4):
		for attempt in range(12):
			if play.pending_choice.is_empty(): break
			var choice: Dictionary = {"market": "Pass"}
			if play.pending_choice.action == "game_draw_choice":
				choice = {"keep_id": play.board_view().world.game_economy.stockpile_pending.card_ids[0]}
			if not check(play.choose_economy(choice).action != "invalid", "human economy choice"): return
		if not check(play.pending_choice.is_empty(), "bounded economy decisions"): return
		for pid in [0, 1]:
			var frozen: Dictionary = play._owner.snapshot()
			var view: Dictionary = Observation.read(play._owner, pid)
			check(view.data.has("game_staging"), "native opponent observation includes staging")
			for lane in ["Lord", "Castle"]:
				var expected: Array = frozen.presentation_world.data.game_staging.lanes[lane].units.filter(func(u): return u.owner == pid)
				check(Codec.difference(expected, view.data.game_staging.lanes[lane].units).is_empty(), "only own protected reserves cross planner boundary")
			if observation_output != null:
				var packet: Dictionary = Codec.encode({"state": frozen, "round": play.round_number(), "hook": play.next_hook(), "seat": pid, "view": view})
				if check(packet.action == "encoded", "observation packet encodes"):
					observation_output.store_line(packet.text)
					observation_output.flush()
			view.data.game_staging.lanes.Lord.units.clear()
			check(Codec.difference(frozen, play._owner.snapshot()).is_empty(), "planner observation owns its staging copies")
		var human: Dictionary = HumanDriver.plan(play._owner, 0)
		var before: Dictionary = play.checkpoint()
		var marching: Dictionary = Job.new()._run(play._fork_for_job(), "marching", human.powers, human.order)
		if not check(marching.action != "invalid", "playable Marching with shared opponent"): return
		check(before == play.checkpoint(), "live pause unchanged until worker adoption")
		var aftermath: Dictionary = Job.new()._run(marching.session, "aftermath", [], {})
		if not check(aftermath.action != "invalid", "playable Aftermath"): return
		play = aftermath.session
		commands += play._opponent.order.get("staging", {}).values().count("March")
		for tray in play._owner._world.data.game_staging.lanes.values():
			released += int(tray.decisions[1].released)
		var restored = Play.new()
		if not check(restored.restore_checkpoint(play.checkpoint()).action != "invalid", "shared-bot save restores"): return
		check(restored._owner.snapshot() == play._owner.snapshot(), "restored authority is exact")
		print("PASS playable ", lords, " round ", play.round_number(), " opponent powers ", play._opponent.powers.map(func(p): return p.power_id), " staging ", play._opponent.order.get("staging", {}))
		if play.is_finished(): break
		if round_index < 3 and not check(play.next_round().action != "invalid", "next playable round"): return

	check(commands > 0, "V26 bot issues MARCH for " + lords[1])
	check(released > 0, "V26 bot actually deploys reserves for " + lords[1])
	print("STAGING ", lords[1], " commands=", commands, " released=", released)

func run() -> void:
	var args = OS.get_cmdline_user_args()
	if args.size() >= 1:
		observation_output = FileAccess.open(args[0], FileAccess.WRITE)
		if not check(observation_output != null, "observation export opens"): quit(1); return
	var started: int = Time.get_ticks_msec()
	var lords: Array = ["Kroni"] if "--quick" in args else preload("res://Scripts/Sim/U13GameConductor.gd").LORDS
	for lord in lords:
		trial(["Gremory", lord])
	print("U13 synchronized playable: %d checks, %.2f seconds; failures: %d" % [checks, (Time.get_ticks_msec() - started) / 1000.0, failures])
	if observation_output != null: observation_output.close()
	quit(failures)
