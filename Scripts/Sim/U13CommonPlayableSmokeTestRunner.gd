extends SceneTree

const Play = preload("res://Scripts/Sim/U13PlayableSession.gd")
const HumanDriver = preload("res://Scripts/Sim/U13BasicDoctrine.gd")
const Job = preload("res://Prototype/U13/U13BoardJob.gd")
var failures: int = 0
var checks: int = 0

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
	var castles: Array = ["Keep", "Stockpile", "SummoningCircle", "Bastion", "SiegeEngine"]
	if not check(play.configure_seed("shared-playable-smoke:" + ":".join(lords), lords, [castles, castles]).action != "invalid", "configure"): return
	for round_index in range(2):
		for attempt in range(12):
			if play.pending_choice.is_empty(): break
			var choice: Dictionary = {"market": "Pass"}
			if play.pending_choice.action == "game_draw_choice":
				choice = {"keep_id": play.board_view().world.game_economy.stockpile_pending.card_ids[0]}
			if not check(play.choose_economy(choice).action != "invalid", "human economy choice"): return
		if not check(play.pending_choice.is_empty(), "bounded economy decisions"): return
		var human: Dictionary = HumanDriver.plan(play._owner, 0)
		var before: Dictionary = play.checkpoint()
		var marching: Dictionary = Job.new()._run(play._fork_for_job(), "marching", human.powers, human.order)
		if not check(marching.action != "invalid", "playable Marching with shared opponent"): return
		check(before == play.checkpoint(), "live pause unchanged until worker adoption")
		var aftermath: Dictionary = Job.new()._run(marching.session, "aftermath", [], {})
		if not check(aftermath.action != "invalid", "playable Aftermath"): return
		play = aftermath.session
		var restored = Play.new()
		if not check(restored.restore_checkpoint(play.checkpoint()).action != "invalid", "shared-bot save restores"): return
		check(restored._owner.snapshot() == play._owner.snapshot(), "restored authority is exact")
		print("PASS playable ", lords, " round ", play.round_number(), " opponent powers ", play._opponent.powers.map(func(p): return p.power_id))
		if play.is_finished(): break
		if round_index == 0 and not check(play.next_round().action != "invalid", "next playable round"): return

func run() -> void:
	var started: int = Time.get_ticks_msec()
	for lords in [["Kroni", "Odradek"], ["Kanifous", "Valak"]]:
		trial(lords)
	print("U13 shared playable smoke: %d checks, %.2f seconds; failures: %d" % [checks, (Time.get_ticks_msec() - started) / 1000.0, failures])
	quit(failures)
