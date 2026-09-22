extends SceneTree

const Trace = preload("res://Scripts/Sim/U13ParityTrace.gd")
const Codec = preload("res://Scripts/Sim/U13ExactData.gd")

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var file = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.READ)
	var first: Dictionary = Codec.decode(file.get_line()).value
	var session: Dictionary = Trace.begin(first.setup, "focused", "focused")
	if session.action == "invalid": print(session); quit(1); return
	var game = session.game
	var delta: String = Codec.difference(first.world, game.snapshot().world)
	if not delta.is_empty(): print("FAIL opening ", delta); quit(1); return
	var prefix: int = 0
	var index: int = 0
	while file.get_position() < file.get_length():
		var expected: Dictionary = Codec.decode(file.get_line()).value
		if expected.has("component"):
			var component_delta: String = component(expected)
			if not component_delta.is_empty(): print("FAIL ", expected.component, " ", component_delta); quit(1); return
			continue
		var result: Dictionary = Trace.apply(game, expected.operation)
		if result.action == "invalid": print("FAIL operation ", index, " ", expected.operation, " ", result); quit(1); return
		var state: Dictionary = game.snapshot()
		delta = Codec.difference(expected.world, state.world)
		if delta.is_empty(): delta = Codec.difference(expected.events, state.events.rows.slice(prefix))
		if not delta.is_empty(): print("FAIL operation ", index, " ", expected.operation, " ", delta); quit(1); return
		var restored = Trace.Game.new()
		result = restored.restore(state)
		if result.action == "invalid": print("FAIL restore ", index, " ", result); quit(1); return
		if not Codec.difference(state, restored.snapshot()).is_empty(): print("FAIL restored state"); quit(1); return
		prefix = state.events.rows.size()
		index += 1
	print("PASS ", index, " exact operations and snapshot restorations")
	quit(0)

func component(spec: Dictionary) -> String:
	var rules = preload("res://Scripts/Sim/U13SplitWard.gd")
	if spec.component == "victory":
		return Codec.difference(spec.expected, Trace.Game.Content.Victory.evaluate(spec.world_before, spec.round))
	var result: Dictionary
	if spec.component == "combat":
		var content = Trace.Game.Content.new()
		result = preload("res://Scripts/Sim/U13Combat.gd")._resolve(spec.context, Callable(content, "react"))
		if result.action == "invalid": return str(result)
	else:
		result = {"world": spec.world_before.duplicate(true), "events": spec.events_before.duplicate(true)}
		# Ward reward bookkeeping is handled by real combat; isolate attack payout here.
		result.world.data["ward_reward_rounds"] = [0, 0]
		rules.reward(result.world, result.events, 0, spec.round, {}, false, false)
		rules.reward(result.world, result.events, 0, spec.round, {}, false, false)
		if not spec.world.data.has("ward_reward_rounds"): result.world.data.erase("ward_reward_rounds")
	var delta: String = Codec.difference(spec.world, result.world)
	if delta.is_empty(): delta = Codec.difference(spec.events, result.events)
	return delta
