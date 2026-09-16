extends SceneTree

# Focused presentation regression; no runtime gate or altered game rules.
const Lanes = preload("res://Prototype/U13/U13BoardLanes.gd")
const Visuals = preload("res://Prototype/U13/U13MarcherSpriteVisuals.gd")
const Catalog = preload("res://Prototype/U13/U13MarcherSpriteCatalog.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("run_checks")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + label)

func unit(id: String, suit: String = "Penitent", owner: int = 0) -> Dictionary:
	return {"id": id, "kind": "marcher", "owner": owner, "attributes": {
		"suit": suit, "lane": "Lord", "x_fp": 300, "y_fp": 300,
		"hp": 5, "max_hp": 5, "armor": 2, "waiting": false, "movement_ready_round": 1}}

func run_checks() -> void:
	for name in ["Butcher", "Penitent", "Vulture", "Wright"]:
		var right := Catalog.pose_frame(name, false)
		var left := Catalog.pose_frame(name, true)
		check(not right.frame.is_empty() and not left.frame.is_empty(), name + " has both facing poses")
		check(right.frame.texture == Catalog.pose_frame(name, false).frame.texture, name + " reuses cached texture")
	check(Catalog.pose_frame("Sinodek", false).frame.texture.get_size() == Vector2(1586, 992), "Sinodek uses approved transparent still")
	for name in Catalog.MONSTERS:
		var monster := unit(name)
		monster.attributes.monster_id = name.to_lower()
		check(not Catalog.pose_frame(Catalog.character_for(monster), false).frame.is_empty(), name + " future monster hook loads")
	check(Catalog.resolve_name("Dotra") == "Batboy" and Catalog.resolve_name("Tumler") == "Dogger", "recipe names resolve to approved creature art")
	var unknown := unit("unknown")
	unknown.attributes.monster_id = "Unannounced"
	check(Catalog.character_for(unknown).is_empty(), "unknown monster is not disguised as a subject")
	var visual := Visuals.new()
	var actor := unit("human")
	var enemy := unit("enemy", "Wright", 1)
	var units: Array = [actor, enemy]
	var original := units.duplicate(true)
	visual.sync(units, [], 1, false)
	check(visual.presentation(actor).motion == "Idle", "world snapshot idles")
	check(not visual.presentation(actor).face_left and visual.presentation(enemy).face_left, "default facing separates owners")
	visual.advance(0.05)
	actor.attributes.visual_x = 350.25
	var moving_input := units.duplicate(true)
	visual.sync(units, [], 1, true)
	check(visual.presentation(actor).motion == "March", "recorded movement drives marching gesture")
	check(visual.subjects.human.position == Vector2(350.25, 300), "fractional world anchor is preserved")
	check(units == moving_input, "sprite sync never mutates playback input")
	actor.attributes.visual_y = 297
	visual.sync(units, [], 1, true)
	check(not visual.presentation(actor).face_left, "tiny lateral jitter does not reverse facing")
	actor.attributes.visual_y = 280
	visual.sync(units, [], 1, true)
	check(visual.presentation(actor).face_left, "sustained lateral travel turns sprite")
	visual.advance(0.3)
	check(visual.presentation(actor).motion == "Idle", "stale playback does not march forever")
	actor.attributes.waiting = true
	actor.attributes.visual_x += 30
	visual.sync(units, [], 1, true)
	check(visual.presentation(actor).motion == "Idle", "supplicant remains idle")
	actor.attributes.waiting = false
	actor.attributes.movement_ready_round = 2
	actor.attributes.visual_x += 30
	visual.sync(units, [], 1, true)
	check(visual.presentation(actor).motion == "Idle", "birth hold remains idle")
	actor.attributes.movement_ready_round = 1
	visual.sync(units, [actor.id, enemy.id], 1, true)
	check(visual.presentation(actor).motion == "Attack", "recorded clash drives attack")
	visual.hit([{"id": actor.id, "hp": -1, "armor": -1}])
	check(visual.presentation(actor).flash == 1.0, "hit flashes during attack without suppressing its pose")
	visual.sync(units, [], 1, false)
	check(visual.presentation(actor).motion == "Hit", "outside-marching damage recoils")
	visual.advance(0.5)
	visual.hit([{"id": actor.id, "hp": 1, "armor": 0}])
	check(visual.presentation(actor).motion == "Idle", "healing does not play a damage reaction")
	var bird := unit("bird", "Vulture")
	visual.sync([bird], [], 1, false)
	bird.attributes.ranged_next_tick = 208
	visual.sync([bird], [], 1, true)
	check(visual.presentation(bird).motion == "Attack", "ranged shot cooldown triggers casting gesture")
	check(visual.presentation(actor, 0.48).motion == "Death" and visual.presentation(actor, 0.48).time == 1.25, "death fade fits existing ghost lifetime")
	visual.sync([], [], 1, false)
	visual.advance(1.0)
	check(visual.subjects.is_empty(), "departed sprite state is retired")
	var sooge := unit("sooge")
	sooge.attributes.monster_id = "Sooge"
	visual.sync([sooge], [], 1, false)
	sooge.attributes.sprite_form = "turret"
	visual.sync([sooge], [], 1, true)
	var start: Texture2D = visual.presentation(sooge).frame.texture
	visual.advance(0.3)
	check(start != visual.presentation(sooge).frame.texture, "future Sooge form transition plays frames")
	visual.advance(1.0)
	var final_pose := visual.presentation(sooge)
	check(final_pose.rooted and final_pose.frame.texture == Catalog.assets("Sooge").transform.back().texture, "Sooge holds final turret pose")
	sooge.attributes.sprite_form = ""
	visual.sync([sooge], [], 1, true)
	check(visual.presentation(sooge).rooted, "Sooge never transforms back during its lifetime")
	visual.clear()
	sooge.attributes.sprite_form = "turret"
	visual.sync([sooge], [], 2, false)
	check(visual.presentation(sooge).frame.texture == final_pose.frame.texture, "loading an existing turret does not replay its transformation")
	var lanes := Lanes.new()
	lanes.size = Vector2(360, 900)
	root.add_child(lanes)
	lanes.show_world(original, 1)
	check(lanes.sprite_visuals.subjects.size() == 2 and lanes.is_processing(), "live board enables sprite animation")
	var board_input := original.duplicate(true)
	board_input[0].attributes.visual_x = 500
	lanes.show_frame({"units": board_input, "clash": ["human", "enemy"]}, 1)
	lanes.paradox_glitches.human = {"amount": 1.0, "tick": 7}
	lanes.void_active = true
	lanes.show_feedback([{"id": "human", "hp": -1, "armor": -1, "x": 500, "y": 300, "lane": "Lord", "source": "HIT"}])
	await process_frame
	await process_frame
	check(lanes._units == board_input and lanes.paradox_glitches.human.amount == 1.0, "rendering preserves tape, clash and paradox inputs")
	lanes.show_deaths([{"unit": board_input[0]}])
	lanes.show_frame({"units": [board_input[1]], "clash": []}, 1)
	await process_frame
	check(lanes.deaths.visible.size() == 1 and lanes.deaths.seen.has("human"), "sprite casualty and ghost play once")
	lanes.reset_effects()
	check(lanes.sprite_visuals.subjects.is_empty() and lanes._clash.is_empty() and lanes.deaths.visible.is_empty(), "restart clears sprite, combat and death state")
	var dense: Array = []
	for i in range(48):
		var marcher := unit("dense-%d" % i, ["Penitent", "Butcher", "Vulture", "Wright"][i % 4], i % 2)
		marcher.attributes.x_fp = 200 + i * 40
		marcher.attributes.y_fp = 100 + (i % 4) * 120
		marcher.attributes.lane = "Lord" if i % 2 == 0 else "Castle"
		dense.append(marcher)
	lanes.show_frame({"units": dense, "clash": []}, 1)
	await process_frame
	await process_frame
	check(lanes.sprite_visuals.subjects.size() == 48 and lanes._units == dense, "dense field retains every identity and recorded position")
	lanes.reset_effects()
	lanes.free()
	print("U13 Marcher sprites failures: %d" % failures)
	quit(1 if failures else 0)
