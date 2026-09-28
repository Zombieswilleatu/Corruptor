extends SceneTree

const Ruin = preload("res://Prototype/U13/U13RuinVisual.gd")
const Playable = preload("res://Prototype/U13/U13TutorialBoard.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + message)

func run() -> void:
	var tutorial := Control.new()
	tutorial.process_mode = Node.PROCESS_MODE_ALWAYS
	tutorial.z_index = 250
	root.add_child(tutorial)
	var decision := Control.new()
	root.add_child(decision)
	var initially_hidden := Control.new()
	root.add_child(initially_hidden)
	initially_hidden.hide()
	var visual = Ruin.new()
	root.add_child(visual)
	var event: Dictionary = {"type": "CASTLE_DAMAGED", "data": {"source": "InevitableRuin", "player_id": 0, "castle_id": "castle", "damage": 12, "integrity": 8}}
	var world: Dictionary = {"entities": [{"id": "castle", "kind": "castle", "attributes": {"castle_type": "SummoningCircle", "integrity": 8}}]}
	paused = true
	visual.play_events([event], [], world, [tutorial, decision, initially_hidden])
	check(not tutorial.visible and not decision.visible and visual.z_index > tutorial.z_index, "Ruin owns priority over an already-open tutorial and decision")
	print("Ruin geometry: banner=%s card=%s" % [visual._banner.size, visual._card.size])
	check(visual._banner.size.x <= 420.0 and is_equal_approx(visual._banner.size.y, 64.0) and visual._card.size == Vector2(146, 218), "compact callout retains original flying-card size")
	decision.show()
	check(not decision.visible, "deferred modal reopen waits for the strike")
	await process_frame
	await process_frame
	check(visual._elapsed > 0.0 and paused, "Ruin advances through tutorial pause without unpausing gameplay")
	visual.advance(1.01)
	await process_frame
	check(visual._banner.size.x <= 420.0 and is_equal_approx(visual._banner.size.y, 64.0) and visual._banner_detail.text.contains("20 → 8"), "long castle name and impact text cannot enlarge the banner after layout")
	visual.advance(4.0)
	check(not visual.active() and tutorial.visible and decision.visible and paused and not initially_hidden.visible, "completion restores waiting modals and preserves tutorial pause")
	paused = false
	visual.play_events([event], [], world, [tutorial, decision])
	visual.clear()
	check(tutorial.visible and decision.visible and not visual.is_processing(), "interruption releases modal priority and stops animation")
	visual.play_events([], [], world, [tutorial, decision])
	check(tutorial.visible and decision.visible and not visual.active(), "rounds without Ruin never hide other modals")
	visual.play_events([event], [], world, [tutorial])
	tutorial.free()
	visual.clear()
	check(not visual.active(), "cleanup tolerates a waiting modal being freed")
	visual.queue_free()
	decision.queue_free()
	initially_hidden.queue_free()
	await process_frame
	print("U13 Ruin Priority: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
