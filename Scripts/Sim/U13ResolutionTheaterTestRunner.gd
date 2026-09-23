extends SceneTree

const Tape = preload("res://Prototype/U13/U13ResolutionTape.gd")
const View = preload("res://Prototype/U13/U13ResolutionView.gd")
const Session = preload("res://Scripts/Sim/U13BoardSession.gd")
const Gem = preload("res://Prototype/U13/U13GemDaggerView.gd")
var failures: int = 0
var checks: int = 0

class Side:
	extends Control
	var lord_card: Control
	var lord_guard_box: Control
	var castle_guard_box: Control
	var castle_row: Control
	var ward_lord_overlay: Control
	var ward_castle_overlay: Control
	var target_controls: Dictionary = {}
	var updates: Array = []
	var states: Array = []
	func _init(pid: int) -> void:
		lord_card = Lord.new()
		lord_card.input_surface.set_meta("owner_id", pid)
		add_child(lord_card)
		lord_guard_box = Control.new(); add_child(lord_guard_box)
		castle_guard_box = Control.new(); add_child(castle_guard_box)
		for index in range(3):
			var slot := Control.new(); slot.size = Vector2(70, 90)
			slot.position = Vector2(300 + index * 80, 240 if pid == 1 else 640)
			castle_guard_box.add_child(slot)
		castle_row = Control.new(); add_child(castle_row)
		castle_row.position = Vector2(600, 160 if pid == 1 else 700)
		castle_row.size = Vector2(500, 120)
		ward_lord_overlay = Control.new(); add_child(ward_lord_overlay)
		ward_castle_overlay = Control.new(); add_child(ward_castle_overlay)
		for id in ["bastion", "keep"]:
			var card := Control.new(); card.size = Vector2(120, 180); castle_row.add_child(card)
			var overlay := Control.new(); card.add_child(overlay)
			var input := Control.new(); input.size = card.size; overlay.add_child(input)
			target_controls[id] = input
	func update_castle_presentation(id: String, a: Dictionary) -> void:
		updates.append({"id": id, "integrity": a.integrity})
	func bind_world(world: Dictionary, _pid: int, _planning: bool) -> void:
		states.append(world.duplicate(true))

class Lord:
	extends Control
	var input_surface: Control = Control.new()
	func _init() -> void: add_child(input_surface)

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func card(id: String, pid: int, slot: int = 0) -> Dictionary:
	return {"id": id, "kind": "card", "owner": pid, "attributes": {"suit": "Butcher", "value": 4, "role": "guard", "lane": "Castle", "slot": slot}}
func castle(id: String, type: String) -> Dictionary:
	return {"id": id, "kind": "castle", "owner": 1, "attributes": {"castle_type": type, "integrity": 17, "max_integrity": 17, "status": "standing", "construction_state": "active"}}
func event(type: String, data: Dictionary) -> Dictionary: return {"type": type, "data": data}

func fixture() -> Dictionary:
	var attack: Array = [card("a", 0), card("b", 0)]
	var guard: Dictionary = card("g", 1)
	return {"before": {"world": {"entities": [guard, castle("bastion", "Bastion"), castle("keep", "Keep")], "sigils": [{"Castle": "", "Lord": ""}, {"Castle": "fresh", "Lord": ""}]}}, "events": [
		event("COMBAT_ORDER_REVEALED", {"player_id": 0, "order": {"action": "Siege"}, "cards": attack}),
		event("COMBAT_ORDER_REVEALED", {"player_id": 1, "order": {"action": "Ward", "lane": "Castle"}, "cards": [card("w", 1)]}),
		event("SIEGE_STARTED", {"player_id": 0, "target_id": "keep"}),
		event("GUARD_DEFEATED", {"guard": guard}),
		event("BASTION_SCREENED", {"castle_id": "bastion", "damage": 17, "destroyed": true, "overflow": 14}),
		event("SIEGE_RESOLVED", {"player_id": 0, "target_id": "keep", "strength": 41, "ward_screen": 4, "guards_defeated": 1, "sigil_broken": true, "integrity_before": 17, "damage": 14, "destroyed": false})]}

func run() -> void:
	var f: Dictionary = fixture()
	var original: Dictionary = f.duplicate(true)
	var tape: Array = Tape.build(f)
	check(tape.map(func(s): return s.kind) == ["advance", "ward", "guards", "sigil", "intercept", "impact"], "recorded defense order")
	check(tape[0].cards.size() == 2, "one grouped commitment")
	check(Tape.build({}).is_empty(), "empty and legacy jobs remain valid")
	# Rendering without external art assets: real Controls, deterministic textures.
	var image := Image.create(8, 12, false, Image.FORMAT_RGBA8)
	image.fill(Color("806444"))
	var texture := ImageTexture.create_from_image(image)
	View.Art._cache[View.Art.Subjects.path_for("Butcher", 4, false)] = texture
	View.Art._cache[View.Art.Subjects.path_for("Butcher", 4, true)] = texture
	for path in View.Castles.ART_PATHS.values(): View.Art._cache[path] = texture
	var sides: Array = [Side.new(1), Side.new(0)]
	for side in sides: root.add_child(side)
	var view = View.new(); root.add_child(view)
	root.size = Vector2i(1920, 1080)
	view.play(f, sides)
	var frames: int = 0
	while view.active() and frames < 600:
		view.advance(1.0 / 60.0)
		frames += 1
	check(not view.active() and frames < 600, "presentation completes")
	check(f == original, "tape and animation never mutate inputs")
	var values: Array = sides[0].updates.filter(func(u): return u.id == "keep").map(func(u): return u.integrity)
	check(values.has(17) and values.has(3) and values.size() >= 10, "17 to 3 has readable intermediate integrity")
	var final: Dictionary = sides[0].states.back()
	check(final.entities.filter(func(e): return e.id == "g").is_empty(), "defeated guard removed")
	check(final.entities.filter(func(e): return e.id == "bastion")[0].attributes.status == "ruined", "interceptor final state")
	check(final.entities.filter(func(e): return e.id == "keep")[0].attributes.integrity == 3, "target final state")
	for stop in range(tape.size()):
		view.play(f, sides)
		for index in range(stop): view.advance(10.0)
		view.advance(0.1)
		view.clear()
		check(not view.active() and not view.visible and view._copies.is_empty() and view._attackers.is_empty(), "skip clears step %d" % stop)
		for node in sides[0].castle_guard_box.get_children(): check(node.modulate.a == 1.0, "skip restores source card")
	# Keep/Hunt and no-damage attacks rely on resolved outcome, not a UI formula.
	var hunt: Dictionary = fixture()
	hunt.events = [event("HUNT_STARTED", {"player_id": 0}), event("KEEP_INTERPOSED", {"castle_id": "keep", "integrity_before": 17, "damage": 0, "reduction": 3}), event("HUNT_RESOLVED", {"player_id": 0, "target_id": "lord", "strength": 3, "ward_screen": 0, "banished": false})]
	var hunt_tape: Array = Tape.build(hunt)
	check(hunt_tape.map(func(s): return s.kind) == ["advance", "intercept", "impact"], "Keep precedes Lord outcome")
	check(not hunt_tape.back().result.banished, "stopped Hunt never invents banishment")
	var gem = Gem.new()
	gem.play_events([event("GUARD_DEFEATED", {"event_id": "g1", "guard": card("g", 1)}), event("GEM_DAGGER", {"drawn": false})], [])
	var after: Dictionary = {"world": {"entities": [], "hand": [], "opponent_hand_count": 0}}
	check(gem.mask_view(after, false).world.entities.is_empty(), "Gem does not resurrect theater casualties")
	gem.free()
	# Actual owner path: public capture, no hidden-hand reconstruction, deterministic result.
	var session = Session.new()
	check(session.reset().action != "invalid", "real session initializes")
	var order: Dictionary = {"action": "Siege", "lane": "Castle", "target_id": Session._castle_id(1), "card_ids": session.board_view().world.hand.slice(0, 2)}
	check(session.choose([], order).action != "invalid", "real commitment accepted")
	check(session.run_to_marching().action != "invalid", "real round resolves")
	var checkpoint: Dictionary = session.checkpoint()
	var real_tape: Array = Tape.build(session.resolution_presentation)
	check(not real_tape.is_empty(), "real resolved events build theater")
	check(session.checkpoint() == checkpoint, "building theater leaves owner unchanged")
	check(session.resolution_presentation.before.world.opponent_hand_count >= 0, "capture uses player projection")
	view.queue_free()
	for side in sides: side.queue_free()
	await process_frame
	print("Resolution theater: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
