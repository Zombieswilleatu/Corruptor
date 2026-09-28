extends SceneTree

const Tape = preload("res://Prototype/U13/U13ResolutionTape.gd")
const View = preload("res://Prototype/U13/U13ResolutionView.gd")

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

var completions: int = 0
var strikes: int = 0
var reveals: int = 0

func run() -> void:
	var image := Image.create(8, 12, false, Image.FORMAT_RGBA8)
	image.fill(Color("806444"))
	var texture := ImageTexture.create_from_image(image)
	View.Art._cache[View.Art.Subjects.path_for("Butcher", 4, false)] = texture
	for path in View.Castles.ART_PATHS.values(): View.Art._cache[path] = texture
	var sides: Array = [Side.new(1), Side.new(0)]
	for side in sides: root.add_child(side)
	var view = View.new()
	root.add_child(view)
	view.presentation_finished.connect(func():
		check(not view.active() and not view.visible, "finish callback observes completed theater")
		check(view._copies.is_empty() and view._attackers.is_empty(), "finish callback has no stale overlays")
		completions += 1)
	# These audio hooks are optional; the user's existing audio patch supplies them.
	if view.has_signal("strike_landed"):
		view.strike_landed.connect(func(_step): strikes += 1)
		view.attack_revealed.connect(func(): reveals += 1)
	for attack_kind in ["Siege", "Hunt"]:
		var lane: String = "Castle" if attack_kind == "Siege" else "Lord"
		var f: Dictionary = fixture()
		var dead: Dictionary = card("dead", 1, 0)
		var survivor: Dictionary = card("survivor", 1, 1)
		dead.attributes.lane = lane
		survivor.attributes.lane = lane
		f.before.world.entities = [dead, survivor, castle("keep", "Keep"), {"id": "lord", "kind": "lord", "owner": 1, "attributes": {"alive": true}}]
		var target: String = "keep" if lane == "Castle" else "lord"
		f.events = [
			event("COMBAT_ORDER_REVEALED", {"player_id": 0, "order": {"action": attack_kind}, "cards": [card("attack", 0)]}),
			event(attack_kind.to_upper()+"_STARTED", {"player_id": 0}),
			event("GUARD_DEFEATED", {"guard": dead}),
			event(attack_kind.to_upper()+"_RESOLVED", {"player_id": 0, "target_id": target, "strength": 7, "ward_screen": 0, "guards_defeated": 1, "sigil_broken": false, "integrity_before": 17, "damage": 0, "destroyed": false, "banished": false})]
		var before: Dictionary = f.duplicate(true)
		var previous: int = completions
		view.play(f, sides)
		view.advance(10.0) # attack advance
		view.advance(0.4) # halfway through guards
		var dying: Control = view._copies[0].node
		var surviving: Control = view._copies[1].node
		check(dying.has_node("CardBreak"), attack_kind+" defeated card has fracture")
		check(dying.get_node("CardBreak")._progress > 0.0 and dying.modulate.a == 1.0, "crack appears before fade")
		check(not surviving.has_node("CardBreak") and surviving.modulate.a == 1.0, "survivor stays intact")
		view.advance(0.24)
		check(dying.modulate.a > 0.0 and dying.modulate.a < 1.0, "defeated card fades after crack")
		view.advance(10.0)
		var displayed: Dictionary = sides[0].states.back()
		check(not displayed.entities.any(func(e): return e.id == "dead"), attack_kind+" casualty removed before target impact")
		check(displayed.entities.any(func(e): return e.id == "survivor"), "survivor remains")
		view.advance(10.0) # final impact; no extra frame allowed
		check(completions == previous + 1, attack_kind+" final board callback synchronous")
		view.advance(10.0)
		check(completions == previous + 1, "completion only once")
		check(f == before, "animation does not change supplied state")
		# Skip mid-fracture. The board's existing skip path does final-state sync.
		view.play(f, sides)
		view.advance(10.0)
		view.advance(0.5)
		view.clear()
		check(view._copies.is_empty() and not view.active(), "skip removes fracture and theater")
		check(completions == previous + 1, "clear does not duplicate normal completion")
	if view.has_signal("strike_landed"):
		check(strikes == 2 and reveals == 4, "existing reveal and impact audio signals preserved")
	view.queue_free()
	for side in sides: side.queue_free()
	await process_frame
	print("Theater casualties: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
