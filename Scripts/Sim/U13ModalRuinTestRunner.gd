extends SceneTree

const Prompt = preload("res://Prototype/U13/U13PhasePrompt.gd")
const Zone = preload("res://Prototype/U13/U13ActionZone.gd")
const Ruin = preload("res://Prototype/U13/U13RuinVisual.gd")
# Compile the real runner's inheritance chain as well as the isolated controls.
const Playable = preload("res://Prototype/U13/U13TutorialBoard.gd")
var checks: int = 0
var failures: int = 0
var impacts: int = 0

class FakeLord extends Control:
	var input_surface := Button.new()
	func _init(pid: int) -> void:
		add_child(input_surface)
		input_surface.set_meta("owner_id", pid)

class FakeSide extends Control:
	var lord_card
	var target_controls: Dictionary = {}
	var shown: Dictionary = {}
	func _init(pid: int, target: String) -> void:
		lord_card = FakeLord.new(pid)
		add_child(lord_card)
		var castle := Control.new()
		castle.position = Vector2(400, 250)
		castle.size = Vector2(124, 180)
		add_child(castle)
		target_controls[target] = castle
	func update_castle_presentation(id: String, attributes: Dictionary) -> void:
		if target_controls.has(id): shown[id] = attributes.duplicate(true)

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + message)

func settle() -> void:
	for frame in range(4): await process_frame

func run() -> void:
	var host := Control.new()
	root.add_child(host)
	host.size = Vector2(1400, 900)
	var prompt = Prompt.new()
	host.add_child(prompt)
	var zone = Zone.new()
	host.add_child(zone)
	prompt.attach_action_zone(zone)
	var long_copy := Label.new()
	long_copy.text = "Scroll content\n".repeat(100)
	zone.get_node("ActionScroll/ActionContents").add_child(long_copy)
	prompt.bind_decision("FLOW_Combat", "COMBAT", "", "ROUND 2")
	await settle()
	var scroll: ScrollContainer = zone.get_node("ActionScroll")
	check(is_equal_approx(prompt.size.y, 662.5), "expanded modal is 25 percent taller")
	check(scroll.scroll_vertical == 0, "first decision opens at the top")
	scroll.scroll_vertical = 180
	prompt.bind_decision("FLOW_Lord Powers", "LORD POWERS", "", "ROUND 2")
	await settle()
	check(scroll.scroll_vertical == 0, "new decision does not inherit combat scroll")
	scroll.scroll_vertical = 80
	prompt.bind_decision("COMMITMENT", "COMBAT", "", "ROUND 2")
	prompt.bind_decision("FLOW_Combat", "COMBAT", "", "ROUND 2")
	await settle()
	check(scroll.scroll_vertical == 180, "return restores scroll and ignores intermediate base binding")
	prompt._on_view_board_pressed()
	await settle()
	prompt._on_view_board_pressed()
	await settle()
	check(scroll.scroll_vertical == 180, "View Board and return preserve scroll")
	prompt.bind_decision("FLOW_Combat", "COMBAT", "", "ROUND 3")
	await settle()
	check(scroll.scroll_vertical == 0, "first appearance next round starts at the top")
	host.size.y = 560
	prompt._apply_gutter_footprint()
	check(is_equal_approx(prompt.size.y, 528.0), "modal fits a shorter window with margins")
	prompt.reset_scroll_memory()
	check(prompt._scroll_positions.is_empty() and scroll.scroll_vertical == 0, "new match clears remembered positions")
	host.queue_free()
	await process_frame

	var event: Dictionary = {"type": "CASTLE_DAMAGED", "data": {"source": "InevitableRuin", "player_id": 0, "castle_id": "enemy", "damage": 12, "integrity": 8}}
	var world: Dictionary = {"entities": [{"id": "enemy", "kind": "castle", "attributes": {"castle_type": "Keep", "integrity": 8}}]}
	var original: Dictionary = world.duplicate(true)
	var unrelated: Dictionary = event.duplicate(true)
	unrelated.data.source = "Siege"
	var hits: Array = Ruin.collect([unrelated, event], world)
	check(hits.size() == 1 and hits[0].before == 20, "only actual Ruin damage creates a strike")
	check(Ruin.description(hits[0], true).contains("12 Integrity (20 → 8)"), "named callout reports recorded damage")
	var visual = Ruin.new()
	root.add_child(visual)
	visual.impact.connect(func(_hit): impacts += 1)
	var own = FakeSide.new(0, "own")
	var enemy = FakeSide.new(1, "enemy")
	root.add_child(own)
	root.add_child(enemy)
	visual.play_events([event], [enemy, own], world)
	check(visual.active() and enemy.shown.enemy.integrity == 20 and own.shown.is_empty(), "correct defender holds original displayed Integrity before impact")
	visual.advance(0.99)
	check(impacts == 0 and enemy.shown.enemy.integrity == 20, "damage waits for the strike")
	visual.advance(0.02)
	check(impacts == 1 and enemy.shown.enemy.integrity == 8, "impact changes displayed Integrity once")
	visual.advance(5.0)
	check(not visual.active() and not visual.visible and impacts == 1, "large frame completes without duplicate impact")
	check(world == original, "animation never mutates authoritative world")
	visual.play_events([event], [enemy, own], world)
	visual.clear()
	check(not visual.active() and enemy.shown.enemy.integrity == 8, "interrupted presentation restores final castle state")
	visual.queue_free()
	own.queue_free()
	enemy.queue_free()
	await process_frame
	print("U13 Modal Ruin: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
