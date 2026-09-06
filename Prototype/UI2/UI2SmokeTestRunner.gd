extends SceneTree


var failures: int = 0


func _initialize() -> void:
	call_deferred(
		"_run"
	)


func _run() -> void:
	var packed = load(
		"res://Prototype/UI2/PlayableUI2.tscn"
	)

	if packed == null:
		_fail("scene_load")
		_finish()
		return

	var screen = packed.instantiate()

	if screen == null:
		_fail("scene_instantiate")
		_finish()
		return

	root.add_child(screen)

	await process_frame

	if screen.controller == null:
		_fail("controller_created")
	else:
		_pass("controller_created")

	if (
		screen.controller == null
		or screen.controller.game == null
	):
		_fail("live_game_started")
	else:
		_pass("live_game_started")

	var board = screen.get_node_or_null(
		"Frame/Main/Body/Center/BoardSurface/BoardStack"
	)

	if board == null:
		_fail("board_shell_present")
	else:
		_pass("board_shell_present")

	# UI2_SMOKE_CURRENT_OVERLAY_PATHS_V1
	# ActionZone is now hosted/reparented by PhasePrompt, so its old Body
	# path is intentionally obsolete. Test the live screen reference instead.
	var action = screen.action_zone

	if action == null or not is_instance_valid(action):
		_fail("action_zone_present")
	else:
		_pass("action_zone_present")

	# Activity is now the root HistoryOverlay, while Hand/Veil remain live
	# screen-owned production regions. Use the screen references so this
	# contract follows intentional reparenting instead of stale node paths.
	var activity = screen.activity_rail
	var hand = screen.hand_view
	var veil = screen.veil_track

	if (
		activity == null
		or not is_instance_valid(activity)
		or hand == null
		or not is_instance_valid(hand)
		or veil == null
		or not is_instance_valid(veil)
	):
		_fail("production_shell_regions_present")
	else:
		_pass("production_shell_regions_present")

	var lord_card = screen.get_node_or_null(
		"Frame/Main/Body/Center/BoardSurface/BoardStack/EnemyField/EnemyZones/EnemyLordZone"
	)
	var hand_strip = screen.get_node_or_null(
		"Frame/Main/Body/Center/HandView"
	)

	if lord_card == null or hand_strip == null:
		_fail("visual_hierarchy_regions_present")
	else:
		_pass("visual_hierarchy_regions_present")

	var distribution_board = screen.get_node_or_null(
		"Frame/Main/Body/Center/BoardSurface"
	)
	var distribution_hand = screen.get_node_or_null(
		"Frame/Main/Body/Center/HandView"
	)

	if distribution_board == null or distribution_hand == null:
		_fail("content_distribution_regions_present")
	else:
		_pass("content_distribution_regions_present")

	var vertical_battlefield = screen.get_node_or_null(
		"Frame/Main/Body/MarchingBattlefield"
	)

	if vertical_battlefield == null:
		_fail("vertical_marching_battlefield_present")
	else:
		_pass("vertical_marching_battlefield_present")

	var console = screen.get_node_or_null(
		"ConsoleOverlay"
	)

	if console == null:
		_fail("console_overlay_present")
	else:
		_pass("console_overlay_present")

	var required_size: Vector2 = screen.get_combined_minimum_size()
	if (
		required_size.x > 1280.0
		or required_size.y > 720.0
	):
		_fail(
			"fits_1280x720 (%s)"
			% str(required_size)
		)
	else:
		_pass("fits_1280x720")

	_finish()


func _pass(
	name: String
) -> void:
	print(
		"PASS  %s" % name
	)


func _fail(
	name: String
) -> void:
	failures += 1
	print(
		"FAIL  %s" % name
	)


func _finish() -> void:
	print(
		"UI2 shell failures: %d"
		% failures
	)
	quit(
		0 if failures == 0 else 1
	)
