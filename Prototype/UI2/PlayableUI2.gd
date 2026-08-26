# UI2_PREVIEW_STACK_COMPACTION_V1
# UI2_CARD_INTERACTION_STAGING_V2
extends Control
# FRACTURE_MARCHERS_AFTERMATH_V1
# UI2_HUNT_AFTERMATH_TRUTH_FIX_V1
# UI2_SIEGE_SUMMARY_OPTION_COPY_FIX_V2


const PlayableRoundControllerData = preload(
	"res://Prototype/PlayableRoundController.gd"
)


const SeededGameSetupData = preload(
	"res://Scripts/Sim/SeededGameSetup.gd"
)

const BotRoundEngineData = preload(
	"res://Scripts/Sim/BotRoundEngine.gd"
)

const RoundEngineData = preload(
	"res://Scripts/Sim/RoundEngine.gd"
)

const DevelopmentStartEngineData = preload(
	"res://Scripts/Sim/DevelopmentStartEngine.gd"
)

const DominionRiteEngineData = preload(
	"res://Scripts/Sim/DominionRiteEngine.gd"
)

const DeployEngineData = preload(
	"res://Scripts/Sim/DeployEngine.gd"
)

const SummonEngineData = preload(
	"res://Scripts/Sim/SummonEngine.gd"
)

const ReflexBidEngineData = preload(
	"res://Scripts/Sim/ReflexBidEngine.gd"
)

const BotDoctrineData = preload(
	"res://Scripts/Sim/BotDoctrine.gd"
)

const BotDevelopmentDoctrineData = preload(
	"res://Scripts/Sim/BotDevelopmentDoctrine.gd"
)

const BotDominionRiteDoctrineData = preload(
	"res://Scripts/Sim/BotDominionRiteDoctrine.gd"
)

const BotDeployDoctrineData = preload(
	"res://Scripts/Sim/BotDeployDoctrine.gd"
)

const BotMarchingDoctrineData = preload(
	"res://Scripts/Sim/BotMarchingDoctrine.gd"
)

const MarchingEngineData = preload(
	"res://Scripts/Sim/MarchingEngine.gd"
)

const PlayerPuckData = preload(
	"res://Prototype/UI2/PlayerPuck.gd"
)

const ZoneRowData = preload(
	"res://Prototype/UI2/ZoneRow.gd"
)

const PlayerBoardData = preload(
	"res://Prototype/UI2/PlayerBoard.gd"
)

const MarchingLaneViewData = preload(
	"res://Prototype/UI2/MarchingLaneView.gd"
)

const ActionZoneData = preload(
	"res://Prototype/UI2/ActionZone.gd"
)

const ConsoleOverlayData = preload(
	"res://Prototype/UI2/ConsoleOverlay.gd"
)

const DevPanelData = preload(
	"res://Prototype/UI2/DevPanel.gd"
)

const PlayableMatchSnapshotData = preload(
	"res://Scripts/Sim/PlayableMatchSnapshot.gd"
)


const ActivityRailData = preload(
	"res://Prototype/UI2/ActivityRail.gd"
)

const HandViewData = preload(
	"res://Prototype/UI2/HandView.gd"
)

const VeilTrackData = preload(
	"res://Prototype/UI2/VeilTrack.gd"
)

const ResolutionTheaterData = preload(
	"res://Prototype/UI2/ResolutionTheater.gd"
)


const DEFAULT_HUMAN_LORD: String = "Orias"
const DEFAULT_BOT_LORD: String = "Valak"
const DEFAULT_SEED: int = 20260724
const RANDOM_START_LORDS: Array[String] = [
	"Orias",
	"Deimos",
	"Valak",
	"Kroni",
	"Kalligan",
	"Gremory",
	"Odradek",
	"Kanifous",
	"Humbaba",
]
const TUTORIAL_ENABLED: bool = true
const RESOLUTION_PRESENTATION_ENABLED: bool = true


# Zero = normal playable UI2.
# Positive = debug-only authentic bot-vs-bot board frozen after N completed rounds.
@export var showcase_rounds: int = 0
var showcase_invalid_reason: String = ""


var controller = null

var header_label: Label = null
var enemy_puck = null
var human_puck = null

var enemy_lord_zone = null
var enemy_player_board = null
var human_player_board = null
var enemy_castle_zone = null
var human_castle_zone = null
var human_lord_zone = null

var marching_view = null
var action_zone = null
var console_overlay = null
var activity_rail = null
var hand_view = null
var veil_track = null
var dev_panel = null
var resolution_theater = null
var _ui2_aftermath_human_souls_before: int = 0
var _ui2_aftermath_bot_souls_before: int = 0
var _ui2_aftermath_baseline_ready: bool = false
var _ui2_aftermath_showing: bool = false
# UI2_COMMITMENT_DOUBLE_CLICK_ALL_IN_V1
var tutorial_panel: PanelContainer = null
var tutorial_label: Label = null
var active_match_seed: int = DEFAULT_SEED
var active_human_lord: String = DEFAULT_HUMAN_LORD
var active_bot_lord: String = DEFAULT_BOT_LORD
var queued_deploy_moves: Array[Dictionary] = []


func _ready() -> void:
	custom_minimum_size = Vector2(1280, 720)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	custom_minimum_size = Vector2(
		1280,
		720
	)

	_build_shell()

	controller = PlayableRoundControllerData.new()

	var starting_human_lord: String = DEFAULT_HUMAN_LORD
	var starting_bot_lord: String = DEFAULT_BOT_LORD
	var starting_seed: int = DEFAULT_SEED

	# Normal launches always open on a fresh random Round 1 matchup.
	# Nonzero showcase_rounds deliberately keeps the deterministic defaults
	# so automated/showcase fixtures remain reproducible.
	if showcase_rounds <= 0:
		var random_start: Dictionary = _random_round_one_start()
		starting_human_lord = String(
			random_start.get("human_lord", DEFAULT_HUMAN_LORD)
		)
		starting_bot_lord = String(
			random_start.get("bot_lord", DEFAULT_BOT_LORD)
		)
		starting_seed = int(
			random_start.get("seed", DEFAULT_SEED)
		)

	controller.start_match(
		starting_human_lord,
		starting_bot_lord,
		starting_seed
	)
	active_human_lord = starting_human_lord
	active_bot_lord = starting_bot_lord
	active_match_seed = starting_seed

	if showcase_rounds > 0:
		_load_midgame_showcase(
			showcase_rounds
		)

	refresh_from_game()


func _random_round_one_start() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var human_index: int = rng.randi_range(
		0,
		RANDOM_START_LORDS.size() - 1
	)

	# Choose from N-1 positions, then hop over the human index so the
	# opening matchup always contains two different Lords.
	var bot_index: int = rng.randi_range(
		0,
		RANDOM_START_LORDS.size() - 2
	)
	if bot_index >= human_index:
		bot_index += 1

	return {
		"human_lord": RANDOM_START_LORDS[human_index],
		"bot_lord": RANDOM_START_LORDS[bot_index],
		"seed": rng.randi_range(1, 2147483646),
	}


func _load_midgame_showcase(
	target_round: int
) -> void:
	showcase_invalid_reason = ""

	if controller == null or controller.rules == null:
		return

	var setup: Dictionary = SeededGameSetupData.setup_locked_game(
		DEFAULT_HUMAN_LORD,
		DEFAULT_BOT_LORD,
		DEFAULT_SEED,
		controller.rules
	)

	var showcase_game = setup.get(
		"game",
		null
	)

	var showcase_rng = setup.get(
		"rng",
		null
	)

	if showcase_game == null or showcase_rng == null:
		showcase_invalid_reason = "setup_failed"
		push_error(
			"UI2 showcase setup failed."
		)
		return

	var showcase_events: Array[Dictionary] = []

	for round_number: int in range(
		1,
		target_round
	):
		if int(showcase_game.winner) >= 0:
			showcase_invalid_reason = "terminal_before_target_round"
			break

		var round_result: Dictionary = BotRoundEngineData.resolve_round(
			showcase_game,
			controller.rules,
			showcase_rng,
			round_number,
			controller.policy
		)

		_append_showcase_events(
			showcase_events,
			round_result.get(
				"events",
				[]
			)
		)

		if String(
			round_result.get(
				"action",
				""
			)
		) == "invalid":
			showcase_invalid_reason = String(
				round_result.get(
					"reason",
					"unknown"
				)
			)
			break

	if showcase_invalid_reason.is_empty():
		showcase_invalid_reason = _advance_showcase_to_commitment(
			showcase_game,
			showcase_rng,
			target_round,
			showcase_events
		)

	controller.game = showcase_game
	controller.random_source = showcase_rng
	controller.events = showcase_events
	controller.phase_results = {}

	if showcase_invalid_reason.is_empty():
		var prepare_result: Dictionary = controller._prepare_commitment()

		if String(
			prepare_result.get(
				"action",
				""
			)
		) == "invalid":
			showcase_invalid_reason = String(
				prepare_result.get(
					"reason",
					"prepare_commitment_failed"
				)
			)

	controller.revealed_guard_ids.clear()
	controller.guard_locations.clear()
	controller.guard_reveal_events.clear()
	controller._sync_guard_visibility()

	showcase_game.refresh_derived_values()


func _advance_showcase_to_commitment(
	showcase_game,
	showcase_rng,
	target_round: int,
	showcase_events: Array[Dictionary]
) -> String:
	if int(showcase_game.winner) >= 0:
		return "terminal_before_commitment"

	RoundEngineData.begin_round(
		showcase_game,
		target_round
	)

	_append_showcase_event(
		showcase_events,
		showcase_game,
		"begin_round",
		{
			"round": target_round,
		}
	)

	var sigil_result: Dictionary = BotRoundEngineData._update_sigils(
		showcase_game,
		controller.rules
	)
	_append_showcase_event(
		showcase_events,
		showcase_game,
		"sigil_update",
		sigil_result
	)

	var veil_result: Dictionary = BotRoundEngineData._apply_veil_drift(
		showcase_game,
		controller.rules
	)
	_append_showcase_event(
		showcase_events,
		showcase_game,
		"veil_drift",
		veil_result
	)

	if int(showcase_game.winner) >= 0:
		return "terminal_at_veil_drift"

	var development_start_result: Dictionary = DevelopmentStartEngineData.resolve(
		showcase_game,
		controller.rules,
		showcase_rng
	)
	_append_showcase_event(
		showcase_events,
		showcase_game,
		"development_start",
		development_start_result
	)

	var draw_result: Dictionary = BotRoundEngineData._resolve_normal_draws(
		showcase_game,
		controller.rules,
		showcase_rng
	)
	_append_showcase_event(
		showcase_events,
		showcase_game,
		"draw",
		draw_result
	)

	var market_rollover_result: Dictionary = RoundEngineData.refresh_market_offers(
		showcase_game,
		controller.rules,
		showcase_rng
	)

	if bool(
		market_rollover_result.get(
			"enabled",
			false
		)
	):
		_append_showcase_event(
			showcase_events,
			showcase_game,
			"market_rollover",
			market_rollover_result
		)

	var market_choices: Dictionary = BotDoctrineData.market_choices(
		showcase_game,
		showcase_rng
	)
	var market_results: Array[Dictionary] = RoundEngineData.resolve_market(
		showcase_game,
		market_choices
	)

	if BotRoundEngineData._contains_invalid(
		market_results
	):
		return "invalid_market"

	_append_showcase_event(
		showcase_events,
		showcase_game,
		"market",
		{
			"choices": market_choices,
			"results": market_results,
		}
	)

	var repair_choices: Dictionary = BotDevelopmentDoctrineData.repair_choices(
		showcase_game,
		controller.rules,
		showcase_rng,
		controller.policy
	)
	var repair_results: Array[Dictionary] = RoundEngineData.resolve_repairs(
		showcase_game,
		controller.rules,
		repair_choices
	)

	if BotRoundEngineData._contains_invalid(
		repair_results
	):
		return "invalid_repair"

	_append_showcase_event(
		showcase_events,
		showcase_game,
		"repair",
		{
			"choices": repair_choices,
			"results": repair_results,
		}
	)

	var rite_choices: Dictionary = BotDominionRiteDoctrineData.rite_choices(
		showcase_game,
		controller.rules,
		showcase_rng,
		controller.policy
	)
	var rite_results: Array[Dictionary] = DominionRiteEngineData.resolve(
		showcase_game,
		controller.rules,
		rite_choices
	)

	if BotRoundEngineData._contains_invalid(
		rite_results
	):
		return "invalid_dominion_rites"

	_append_showcase_event(
		showcase_events,
		showcase_game,
		"dominion_rites",
		{
			"choices": rite_choices,
			"results": rite_results,
		}
	)

	if int(showcase_game.winner) >= 0:
		return "terminal_at_dominion_rites"

	var deploy_choices: Dictionary = BotDeployDoctrineData.deploy_choices(
		showcase_game,
		controller.rules
	)
	var deploy_results: Array[Dictionary] = DeployEngineData.resolve(
		showcase_game,
		controller.rules,
		deploy_choices
	)

	if BotRoundEngineData._contains_invalid(
		deploy_results
	):
		return "invalid_deploy"

	_append_showcase_event(
		showcase_events,
		showcase_game,
		"deploy",
		{
			"choices": deploy_choices,
			"results": deploy_results,
		}
	)

	if controller.rules.marching:
		var march_results: Array[Dictionary] = []

		for player in showcase_game.players:
			var player_id: int = int(
				player.pid
			)

			var march_choice: Dictionary = BotMarchingDoctrineData.march_choice(
				showcase_game,
				player_id,
				controller.rules
			)

			march_results.append(
				MarchingEngineData.launch(
					showcase_game,
					controller.rules,
					player_id,
					march_choice
				)
			)

		if BotRoundEngineData._contains_invalid(
			march_results
		):
			return "invalid_march"

		_append_showcase_event(
			showcase_events,
			showcase_game,
			"march",
			{
				"results": march_results,
			}
		)

	var summon_choices: Dictionary = BotDevelopmentDoctrineData.summon_choices(
		showcase_game,
		controller.rules,
		showcase_rng,
		controller.policy
	)
	var summon_results: Array[Dictionary] = SummonEngineData.resolve(
		showcase_game,
		controller.rules,
		summon_choices
	)

	if BotRoundEngineData._contains_invalid(
		summon_results
	):
		return "invalid_summon"

	_append_showcase_event(
		showcase_events,
		showcase_game,
		"summon",
		{
			"choices": summon_choices,
			"results": summon_results,
		}
	)

	if int(showcase_game.winner) >= 0:
		return "terminal_at_summon"

	# Reflex Bid is no longer a player-facing Corruptor phase.
	# Stop after Summon and prepare Commitment directly.
	return ""


func _append_showcase_events(
	showcase_events: Array[Dictionary],
	raw_events
) -> void:
	if typeof(raw_events) != TYPE_ARRAY:
		return

	for raw_event in raw_events:
		if typeof(raw_event) != TYPE_DICTIONARY:
			continue

		showcase_events.append(
			raw_event.duplicate(
				true
			)
		)


func _append_showcase_event(
	showcase_events: Array[Dictionary],
	showcase_game,
	phase_name: String,
	data
) -> void:
	showcase_events.append({
		"round": int(
			showcase_game.round
		),
		"phase": phase_name,
		"data": data,
	})


func _build_shell() -> void:
	var frame := MarginContainer.new()
	frame.name = "Frame"
	frame.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	frame.add_theme_constant_override("margin_left", 10)
	frame.add_theme_constant_override("margin_top", 8)
	frame.add_theme_constant_override("margin_right", 10)
	frame.add_theme_constant_override("margin_bottom", 8)
	add_child(frame)

	var main := VBoxContainer.new()
	main.name = "Main"
	main.add_theme_constant_override("separation", 6)
	frame.add_child(main)

	var top := HBoxContainer.new()
	top.name = "Top"
	top.add_theme_constant_override("separation", 8)
	main.add_child(top)

	var enemy_summary := PanelContainer.new()
	enemy_summary.custom_minimum_size = Vector2(205, 92)
	enemy_summary.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color(0.17, 0.075, 0.075, 1.0)
		)
	)
	top.add_child(enemy_summary)

	enemy_puck = PlayerPuckData.new()
	enemy_puck.name = "EnemyPuck"
	enemy_summary.add_child(enemy_puck)

	veil_track = VeilTrackData.new()
	veil_track.name = "VeilTrack"
	veil_track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(veil_track)

	var human_summary := PanelContainer.new()
	human_summary.custom_minimum_size = Vector2(205, 92)
	human_summary.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color(0.055, 0.105, 0.17, 1.0)
		)
	)
	top.add_child(human_summary)

	human_puck = PlayerPuckData.new()
	human_puck.name = "HumanPuck"
	human_summary.add_child(human_puck)

	var console_button := Button.new()
	console_button.text = "CONSOLE"
	console_button.pressed.connect(
		_on_console_pressed
	)
	top.add_child(console_button)

	var dev_button := Button.new()
	dev_button.text = "DEV"
	dev_button.pressed.connect(
		_on_dev_pressed
	)
	top.add_child(dev_button)

	var body := HBoxContainer.new()
	body.name = "Body"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	main.add_child(body)

	activity_rail = ActivityRailData.new()
	activity_rail.name = "ActivityRail"
	body.add_child(activity_rail)
	activity_rail.custom_minimum_size = Vector2(200, 0)
	activity_rail.size_flags_horizontal = Control.SIZE_FILL
	activity_rail.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var center := VBoxContainer.new()
	center.name = "Center"
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.size_flags_stretch_ratio = 1.0
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override(
		"separation",
		5
	)
	body.add_child(center)

	# Flexible height belongs to the board surface, not the Hand.
	# Reveal/results can later overlay this surface without reserving a fifth row.
	var board_surface := PanelContainer.new()
	board_surface.name = "BoardSurface"
	board_surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_surface.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color(
				0.055,
				0.055,
				0.06,
				1.0
			)
		)
	)
	center.add_child(
		board_surface
	)

	var board_stack := VBoxContainer.new()
	board_stack.name = "BoardStack"
	board_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_stack.add_theme_constant_override(
		"separation",
		5
	)
	board_surface.add_child(
		board_stack
	)

	var enemy_field := PanelContainer.new()
	enemy_field.name = "EnemyField"
	enemy_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	enemy_field.size_flags_stretch_ratio = 1.0
	enemy_field.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color(
				0.12,
				0.05,
				0.055,
				1.0
			)
		)
	)
	board_stack.add_child(
		enemy_field
	)

	var enemy_zones := VBoxContainer.new()
	enemy_zones.name = "EnemyZones"
	enemy_zones.size_flags_vertical = Control.SIZE_EXPAND_FILL
	enemy_zones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_zones.add_theme_constant_override(
		"separation",
		4
	)
	enemy_field.add_child(
		enemy_zones
	)

	enemy_lord_zone = ZoneRowData.new()
	enemy_lord_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_lord_zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	enemy_lord_zone.size_flags_stretch_ratio = 1.0
	enemy_lord_zone.name = "EnemyLordZone"
	enemy_zones.add_child(
		enemy_lord_zone
	)
	enemy_lord_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_lord_zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	enemy_lord_zone.size_flags_stretch_ratio = 1.0

	enemy_castle_zone = ZoneRowData.new()
	enemy_castle_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_castle_zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	enemy_castle_zone.size_flags_stretch_ratio = 1.0
	enemy_castle_zone.name = "EnemyCastleZone"
	enemy_zones.add_child(
		enemy_castle_zone
	)

	enemy_lord_zone.visible = false
	enemy_castle_zone.visible = false
	enemy_player_board = PlayerBoardData.new()
	enemy_player_board.name = "EnemyPlayerBoard"
	enemy_player_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_player_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	enemy_zones.add_child(enemy_player_board)
	enemy_player_board.attack_card_dropped.connect(
		_on_ui2_attack_card_dropped
	)
	enemy_player_board.attack_preview_card_clicked.connect(
		_on_ui2_attack_preview_card_clicked
	)
	enemy_player_board.attack_preview_all_requested.connect(
		_on_ui2_commitment_preview_all_requested.bind("COMMITMENT")
	)
	enemy_castle_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_castle_zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	enemy_castle_zone.size_flags_stretch_ratio = 1.0

	var strategic_gap := Control.new()
	strategic_gap.name = "StrategicGap"
	strategic_gap.custom_minimum_size.y = 12
	strategic_gap.size_flags_vertical = Control.SIZE_FILL
	board_stack.add_child(strategic_gap)

	var human_field := PanelContainer.new()
	human_field.name = "HumanField"
	human_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	human_field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	human_field.size_flags_stretch_ratio = 1.0
	human_field.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color(
				0.04,
				0.07,
				0.115,
				1.0
			)
		)
	)
	board_stack.add_child(
		human_field
	)

	var human_zones := VBoxContainer.new()
	human_zones.name = "HumanZones"
	human_zones.size_flags_vertical = Control.SIZE_EXPAND_FILL
	human_zones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	human_zones.add_theme_constant_override(
		"separation",
		4
	)
	human_field.add_child(
		human_zones
	)

	human_castle_zone = ZoneRowData.new()
	human_castle_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	human_castle_zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	human_castle_zone.size_flags_stretch_ratio = 1.0
	human_castle_zone.name = "HumanCastleZone"
	human_zones.add_child(
		human_castle_zone
	)
	human_castle_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	human_castle_zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	human_castle_zone.size_flags_stretch_ratio = 1.0

	human_lord_zone = ZoneRowData.new()
	human_lord_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	human_lord_zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	human_lord_zone.size_flags_stretch_ratio = 1.0
	human_lord_zone.name = "HumanLordZone"
	human_zones.add_child(
		human_lord_zone
	)

	human_castle_zone.visible = false
	human_lord_zone.visible = false
	human_player_board = PlayerBoardData.new()
	human_player_board.name = "HumanPlayerBoard"
	human_player_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	human_player_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	human_zones.add_child(human_player_board)
	human_player_board.staged_guard_clicked.connect(
		_on_ui2_deploy_unstage_requested
	)
	human_player_board.deploy_card_dropped.connect(
		_on_ui2_deploy_card_dropped
	)
	human_player_board.castle_payment_card_dropped.connect(
		_on_ui2_castle_payment_card_dropped
	)
	human_player_board.castle_payment_preview_card_clicked.connect(
		_on_ui2_castle_payment_preview_card_clicked
	)
	human_player_board.castle_payment_preview_all_requested.connect(
		_on_ui2_castle_payment_preview_all_requested
	)
	human_player_board.ward_card_dropped.connect(
		_on_ui2_ward_card_dropped
	)
	human_player_board.ward_preview_card_clicked.connect(
		_on_ui2_ward_preview_card_clicked
	)
	human_player_board.ward_preview_all_requested.connect(
		_on_ui2_commitment_preview_all_requested.bind("WARD")
	)
	human_lord_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	human_lord_zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	human_lord_zone.size_flags_stretch_ratio = 1.0

	hand_view = HandViewData.new()
	hand_view.name = "HandView"
	hand_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_view.size_flags_vertical = Control.SIZE_FILL
	center.add_child(
		hand_view
	)

	tutorial_panel = PanelContainer.new()
	tutorial_panel.name = "TutorialPanel"
	tutorial_panel.visible = TUTORIAL_ENABLED
	tutorial_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tutorial_panel.size_flags_vertical = Control.SIZE_FILL
	tutorial_panel.add_theme_stylebox_override(
		"panel",
		_panel_style(Color(0.035, 0.035, 0.042, 0.98))
	)
	center.add_child(tutorial_panel)

	tutorial_label = Label.new()
	tutorial_label.name = "TutorialText"
	tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_label.add_theme_font_size_override("font_size", 11)
	tutorial_panel.add_child(tutorial_label)


	action_zone = ActionZoneData.new()
	action_zone.name = "ActionZone"
	action_zone.custom_minimum_size.x = 300
	action_zone.size_flags_horizontal = Control.SIZE_FILL
	action_zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(action_zone)
	action_zone.action_selected.connect(
		_on_ui2_action_selected
	)
	action_zone.target_changed.connect(
		_on_ui2_target_changed
	)
	action_zone.confirm_requested.connect(
		_on_ui2_confirm_requested
	)
	action_zone.pass_requested.connect(
		_on_ui2_pass_requested
	)
	action_zone.deploy_unstage_requested.connect(
		_on_ui2_deploy_unstage_requested
	)
	hand_view.selection_changed.connect(
		_on_ui2_hand_selection_changed
	)

	marching_view = MarchingLaneViewData.new()
	marching_view.name = "MarchingBattlefield"
	marching_view.custom_minimum_size = Vector2(290, 0)
	marching_view.size_flags_horizontal = Control.SIZE_FILL
	marching_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(marching_view)
	marching_view.march_guard_dropped.connect(
		_on_ui2_march_guard_dropped
	)
	body.move_child(
		action_zone,
		body.get_child_count() - 1
	)

	console_overlay = ConsoleOverlayData.new()
	console_overlay.name = "ConsoleOverlay"
	console_overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	console_overlay.offset_left = 160
	console_overlay.offset_top = 70
	console_overlay.offset_right = -160
	console_overlay.offset_bottom = -70
	add_child(console_overlay)

	resolution_theater = ResolutionTheaterData.new()
	resolution_theater.name = "ResolutionTheater"
	resolution_theater.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	add_child(resolution_theater)


	dev_panel = DevPanelData.new()
	dev_panel.name = "DevPanel"
	dev_panel.start_requested.connect(
		_on_dev_start_requested
	)
	dev_panel.export_snapshot_requested.connect(
		_on_dev_export_snapshot_requested
	)
	add_child(dev_panel)


func _panel_style(
	background: Color
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 7
	style.content_margin_top = 6
	style.content_margin_right = 7
	style.content_margin_bottom = 6
	return style


func refresh_from_game() -> void:
	if (
		controller == null
		or controller.game == null
	):
		return

	var game = controller.game
	var rules = controller.rules
	var human = controller.get_human_player()
	var bot = controller.get_bot_player()

	if human == null or bot == null:
		return

	enemy_puck.bind_player(
		bot,
		rules,
		false
	)

	human_puck.bind_player(
		human,
		rules,
		true
	)

	enemy_lord_zone.bind_zone(
		bot,
		"Lord",
		false
	)

	enemy_castle_zone.bind_zone(
		bot,
		"Castle",
		false
	)

	enemy_player_board.set_deploy_drop_enabled(
		false
	)
	enemy_player_board.set_castle_payment_drop_enabled(
		false
	)
	enemy_player_board.set_march_drag_enabled(
		false
	)
	enemy_player_board.set_attack_drop_enabled(
		controller.stage
		== PlayableRoundControllerData.Stage.COMMITMENT
	)
	enemy_player_board.bind_player(
		bot,
		false
	)

	human_castle_zone.bind_zone(
		human,
		"Castle",
		true
	)

	human_lord_zone.bind_zone(
		human,
		"Lord",
		true
	)

	var deploy_stage: bool = (
		controller.stage
		== PlayableRoundControllerData.Stage.DEPLOY
	)
	var repair_stage: bool = (
		controller.stage
		== PlayableRoundControllerData.Stage.REPAIR
	)
	var march_stage: bool = (
		controller.stage
		== PlayableRoundControllerData.Stage.MARCH
	)
	var commitment_stage: bool = (
		controller.stage
		== PlayableRoundControllerData.Stage.COMMITMENT
	)
	var march_drag_enabled: bool = (
		march_stage
		and controller.human_can_launch_marcher()
	)

	human_player_board.set_deploy_drop_enabled(
		deploy_stage
	)
	human_player_board.set_castle_payment_drop_enabled(
		repair_stage
	)
	human_player_board.set_march_drag_enabled(
		march_drag_enabled
	)
	human_player_board.set_ward_drop_enabled(
		commitment_stage
	)
	human_player_board.set_attack_drop_enabled(
		false
	)
	human_player_board.set_staged_deploy_moves(
		queued_deploy_moves
		if deploy_stage
		else []
	)
	human_player_board.bind_player(
		human,
		true
	)

	marching_view.set_march_drop_enabled(
		march_drag_enabled,
		(
			controller.human_reactive_march_lane()
			if march_stage
			else ""
		)
	)
	marching_view.bind_players(
		human,
		bot
	)

	var hand_interactive: bool = _stage_uses_hand_selection()

	hand_view.set_deploy_drag_enabled(
		deploy_stage
	)
	hand_view.set_repair_drag_enabled(
		repair_stage
	)
	hand_view.set_ward_drag_enabled(
		commitment_stage
	)
	hand_view.set_attack_drag_enabled(
		commitment_stage
	)
	hand_view.set_staged_deploy_moves(
		queued_deploy_moves
		if deploy_stage
		else []
	)
	hand_view.bind_player(
		human,
		hand_interactive
	)

	action_zone.set_deploy_staged_moves(
		queued_deploy_moves
		if controller.stage == PlayableRoundControllerData.Stage.DEPLOY
		else []
	)
	action_zone.bind_state(
		human,
		bot,
		rules,
		controller,
		_stage_text()
	)
	action_zone.set_deploy_staged_moves(
		queued_deploy_moves
		if controller.stage == PlayableRoundControllerData.Stage.DEPLOY
		else []
	)

	var selected_hand_ids: Array[String] = (
		hand_view.selected_card_ids()
	)

	action_zone.set_selected_card_count(
		selected_hand_ids.size()
	)
	action_zone.set_selected_hand_cards(
		selected_hand_ids
	)
	_sync_ui2_ward_preview()
	_sync_ui2_attack_preview()
	_sync_ui2_castle_payment_preview()

	activity_rail.bind_controller(
		controller,
		_stage_text()
	)

	_refresh_tutorial_panel()

	var veil_stage_text: String = _stage_text()

	if showcase_rounds > 0:
		veil_stage_text = (
			"MIDGAME SHOWCASE · R%d COMMITMENT"
			% int(game.round)
		)

	veil_track.bind_state(
		game,
		rules,
		veil_stage_text
	)


func _header_text(
	game,
	rules
) -> String:
	var veil_total: int = int(
		game.calculate_veil_total()
	)

	var dominion_track: int = (
		int(rules.dominion_track)
		if rules != null
		else 0
	)

	var final_collapse: int = (
		int(rules.final_collapse_threshold)
		if rules != null
		else 0
	)

	return (
		"R%d · %s     VEIL %d / CAT %d / FINAL %d     BREACH %s"
		% [
			int(game.round),
			_stage_text(),
			veil_total,
			dominion_track,
			final_collapse,
			_breach_text(game),
		]
	)


func _stage_text() -> String:
	if controller == null:
		return "NO GAME"

	var stage_index: int = int(
		controller.stage
	)

	var keys: Array = PlayableRoundControllerData.Stage.keys()

	if (
		stage_index < 0
		or stage_index >= keys.size()
	):
		return "UNKNOWN"

	return String(
		keys[stage_index]
	).replace(
		"_",
		" "
	)


func _breach_text(
	game
) -> String:
	var owner_id: int = int(
		game.breach_owner
	)

	if owner_id < 0:
		return "—"

	var owner = game.get_player(
		owner_id
	)

	if owner == null:
		return str(owner_id)

	return String(
		owner.lord
	).to_upper()


func _on_ui2_action_selected(
	_action_name: String
) -> void:
	if action_zone == null or hand_view == null:
		return

	var selected_hand_ids: Array[String] = (
		hand_view.selected_card_ids()
	)

	action_zone.set_selected_card_count(
		selected_hand_ids.size()
	)
	action_zone.set_selected_hand_cards(
		selected_hand_ids
	)
	_sync_ui2_ward_preview()
	_sync_ui2_attack_preview()


func _on_ui2_target_changed(
	_target_name: String
) -> void:
	_sync_ui2_ward_preview()
	_sync_ui2_attack_preview()
	_sync_ui2_castle_payment_preview()


func _on_ui2_hand_selection_changed(
	card_ids
) -> void:
	if action_zone == null:
		return

	if (
		controller != null
		and controller.stage == PlayableRoundControllerData.Stage.DEPLOY
		and not card_ids.is_empty()
	):
		_stage_ui2_hand_cards_immediately(card_ids)
		return

	action_zone.set_selected_card_count(
		card_ids.size()
	)
	action_zone.set_selected_hand_cards(
		card_ids
	)
	_sync_ui2_ward_preview()
	_sync_ui2_attack_preview()
	_sync_ui2_castle_payment_preview()


func _on_ui2_confirm_requested() -> void:
	if controller == null or controller.game == null:
		return

	var result: Dictionary = {}
	var stage_before = controller.stage
	var resolution_event_count_before: int = (
		_ui2_resolution_action_event_count()
	)
	var human_action_preanimated: bool = false

	match controller.stage:
		PlayableRoundControllerData.Stage.NO_GAME:
			queued_deploy_moves.clear()
			result = controller.advance_to_commitment()

		PlayableRoundControllerData.Stage.DEVELOPMENT_SNARE:
			result = controller.resolve_human_snare(true)

		PlayableRoundControllerData.Stage.MARKET:
			var give_cards: Array[String] = hand_view.selected_card_ids()
			if give_cards.size() != 1 or action_zone.get_primary_value().is_empty():
				action_zone.set_status("Choose exactly one Hand card and one Market offer.")
				return
			result = controller.resolve_human_market({
				"take": action_zone.get_primary_value(),
				"give": give_cards[0],
			})

		PlayableRoundControllerData.Stage.REPAIR:
			result = _resolve_ui2_repair()

		PlayableRoundControllerData.Stage.DOMINION_RITES:
			result = controller.resolve_human_dominion_rites(
				_build_ui2_rite_decision()
			)

		PlayableRoundControllerData.Stage.DEPLOY:
			_queue_ui2_deploy_selection()
			return

		PlayableRoundControllerData.Stage.MARCH:
			result = _resolve_ui2_march()

		PlayableRoundControllerData.Stage.SUMMON:
			result = controller.resolve_human_summon(
				hand_view.selected_card_ids(),
				false
			)

		PlayableRoundControllerData.Stage.REFLEX_BID:
			result = controller.resolve_human_reflex_bid({
				"bid": hand_view.selected_card_ids(),
			})

		PlayableRoundControllerData.Stage.COMMITMENT:
			result = controller.seal_human_commitment(
				_build_ui2_commitment_decision()
			)

		PlayableRoundControllerData.Stage.SEALED:
			_capture_ui2_aftermath_baseline()
			result = controller.reveal_orders()

		PlayableRoundControllerData.Stage.KANIFOUS_INVOKE:
			var toll_cards: Array[String] = hand_view.selected_card_ids()
			if toll_cards.size() != 1:
				action_zone.set_status("Choose exactly one Hand card as the Invoke toll.")
				return
			result = controller.resolve_human_kanifous_invoke(
				action_zone.get_primary_value(),
				toll_cards[0]
			)

		PlayableRoundControllerData.Stage.KANIFOUS_WRIGHT:
			var guard_indices: Array[int] = []
			for raw_index in action_zone.get_aux_selected_values():
				guard_indices.append(int(raw_index))
			if guard_indices.size() > 2:
				action_zone.set_status("Wright may move at most two Lord Guards.")
				return
			result = controller.resolve_human_kanifous_wright(guard_indices)

		PlayableRoundControllerData.Stage.VULTURE_RECON:
			result = controller.resolve_human_vulture_recon(
				action_zone.get_primary_value()
			)

		PlayableRoundControllerData.Stage.REVEALED:
			result = controller.begin_human_resolution()

		PlayableRoundControllerData.Stage.RESOLUTION_HUMBABA_TOLL:
			result = controller.resolve_human_humbaba_toll(
				action_zone.get_primary_value()
			)

		PlayableRoundControllerData.Stage.RESOLUTION_ACTION:
			var human_resolution_action: String = String(
				controller.get_human_player().action
			)
			if (
				RESOLUTION_PRESENTATION_ENABLED
				and human_resolution_action != "Ward"
			):
				await _play_ui2_resolution_action_for_player(
					0
				)
				human_action_preanimated = true
			result = controller.resolve_human_resolution_action(
				_build_ui2_resolution_action_options()
			)

		PlayableRoundControllerData.Stage.RESOLUTION_VESSEL:
			result = controller.resolve_human_vessel({
				"offer": action_zone.get_primary_value() == "offer",
			})

		PlayableRoundControllerData.Stage.RESOLUTION_REFLEX:
			result = controller.resolve_human_reflex(
				_build_ui2_reflex_decision(false)
			)

		PlayableRoundControllerData.Stage.RESOLUTION_ODRADEK_BREACH:
			result = controller.resolve_human_odradek_breach({
				"guess": action_zone.get_primary_value(),
				"stolen_action": _build_ui2_reflex_decision(true),
			})

		PlayableRoundControllerData.Stage.RESOLUTION_GREMORY:
			result = controller.resolve_human_gremory(
				_combined_payment_ids()
			)

		_:
			action_zone.set_status("This stage has no confirm action in UI2.")
			return

	if (
		RESOLUTION_PRESENTATION_ENABLED
		and String(result.get("action", "")) != "invalid"
	):
		if stage_before in [
			PlayableRoundControllerData.Stage.REVEALED,
			PlayableRoundControllerData.Stage.RESOLUTION_ACTION,
		]:
			var new_events: Array = (
				_ui2_resolution_action_events_since(
					resolution_event_count_before
				)
			)

			for event in new_events:
				var event_player_id: int = int(
					event.get(
						"player_id",
						-1
					)
				)
				var event_action: String = String(
					event.get(
						"committed_action",
						""
					)
				)

				# Ward establishes a Sigil during Reveal. It is not a combat
				# collision, so do not manufacture a modal clash/result for it.
				if event_action == "Ward":
					continue

				if not (
					human_action_preanimated
					and event_player_id == 0
				):
					await _play_ui2_resolution_event_action(
						event
					)

				var event_action_result = event.get(
					"action_result",
					{}
				)
				if typeof(event_action_result) == TYPE_DICTIONARY:
					await _play_ui2_interposition_if_needed(
						event_player_id,
						event_action_result
					)
					await _play_ui2_target_impact_if_needed(
						event_player_id,
						event_action_result
					)

				resolution_theater.set_aftermath_context(
					_ui2_aftermath_context()
				)
				await resolution_theater.play_result(
					_ui2_resolution_event_summary(
						event
					)
				)

			if (
				stage_before
				== PlayableRoundControllerData.Stage.RESOLUTION_ACTION
				and new_events.is_empty()
			):
				var pending_result: Dictionary = (
					controller.resolution_state.get(
						"pending_action_result",
						{}
					)
				)
				var pending_action_name: String = String(
					controller.get_human_player().action
				)
				if (
					not pending_result.is_empty()
					and pending_action_name != "Ward"
				):
					await _play_ui2_interposition_if_needed(
						0,
						pending_result
					)
					await _play_ui2_target_impact_if_needed(
						0,
						pending_result
					)
					resolution_theater.set_aftermath_context(
						_ui2_aftermath_context()
					)
					await resolution_theater.play_result(
						_ui2_action_result_summary(
							pending_action_name,
							pending_result
						)
					)

	_finish_ui2_controller_step(result)

	if (
		RESOLUTION_PRESENTATION_ENABLED
		and stage_before
		== PlayableRoundControllerData.Stage.SEALED
		and String(result.get("action", "")) == "revealed"
	):
		await _play_ui2_reveal_presentation()


func _play_ui2_reveal_presentation() -> void:
	if not _ui2_aftermath_baseline_ready:
		_capture_ui2_aftermath_baseline()
	if (
		controller == null
		or controller.game == null
		or resolution_theater == null
	):
		return

	var human = controller.get_human_player()
	var bot = controller.get_bot_player()
	if human == null or bot == null:
		return

	_flash_ui2_revealed_ward(
		human_player_board,
		human
	)
	_flash_ui2_revealed_ward(
		enemy_player_board,
		bot
	)

	# Two defensive orders did not collide. The board itself is the reveal:
	# flash the newly raised Sigils and move on without a modal fake clash.
	if (
		String(human.action) == "Ward"
		and String(bot.action) == "Ward"
	):
		await get_tree().create_timer(0.46).timeout
		return

	await resolution_theater.play_reveal(
		human,
		bot
	)


func _flash_ui2_revealed_ward(
	board,
	player
) -> void:
	if (
		board == null
		or player == null
		or String(player.action) != "Ward"
	):
		return

	var raw_choice = controller.commitment_choices.get(
		int(player.pid),
		{}
	)
	if typeof(raw_choice) != TYPE_DICTIONARY:
		return

	var choice: Dictionary = raw_choice
	var zone_name: String = String(
		choice.get(
			"target_type",
			choice.get(
				"ward_target",
				""
			)
		)
	)
	if zone_name not in ["Lord", "Castle"]:
		return

	board.flash_sigil(
		zone_name
	)


func _on_ui2_pass_requested() -> void:
	if controller == null or controller.game == null:
		return

	var result: Dictionary = {}

	match controller.stage:
		PlayableRoundControllerData.Stage.DEVELOPMENT_SNARE:
			result = controller.resolve_human_snare(false)
		PlayableRoundControllerData.Stage.MARKET:
			result = controller.resolve_human_market({"pass": true})
		PlayableRoundControllerData.Stage.REPAIR:
			result = controller.resolve_human_repair({"pass": true})
		PlayableRoundControllerData.Stage.DOMINION_RITES:
			result = controller.resolve_human_dominion_rites({"pass": true})
		PlayableRoundControllerData.Stage.DEPLOY:
			var deploy_decision: Dictionary = (
				{"pass": true}
				if queued_deploy_moves.is_empty()
				else {"moves": queued_deploy_moves.duplicate(true)}
			)
			result = controller.resolve_human_deploy(deploy_decision)
			if String(result.get("action", "")) != "invalid":
				queued_deploy_moves.clear()
		PlayableRoundControllerData.Stage.MARCH:
			result = controller.resolve_human_march({"action": "pass"})
		PlayableRoundControllerData.Stage.SUMMON:
			var no_payment: Array[String] = []
			result = controller.resolve_human_summon(no_payment, true)
		PlayableRoundControllerData.Stage.REFLEX_BID:
			result = controller.resolve_human_reflex_bid({"pass": true})
		PlayableRoundControllerData.Stage.KANIFOUS_WRIGHT:
			var none: Array[int] = []
			result = controller.resolve_human_kanifous_wright(none)
		PlayableRoundControllerData.Stage.RESOLUTION_HUMBABA_TOLL:
			result = controller.resolve_human_humbaba_toll("")
		PlayableRoundControllerData.Stage.RESOLUTION_REFLEX:
			result = controller.resolve_human_reflex({"pass": true})
		PlayableRoundControllerData.Stage.RESOLUTION_ODRADEK_BREACH:
			result = controller.resolve_human_odradek_breach({"guess": ""})
		PlayableRoundControllerData.Stage.RESOLUTION_GREMORY:
			var no_cards: Array[String] = []
			result = controller.resolve_human_gremory(no_cards)
		_:
			action_zone.set_status("This stage cannot be passed.")
			return

	_finish_ui2_controller_step(result)


func _refresh_tutorial_panel() -> void:
	if tutorial_panel == null or tutorial_label == null:
		return

	tutorial_panel.visible = TUTORIAL_ENABLED
	if not TUTORIAL_ENABLED:
		return

	tutorial_label.text = _tutorial_text(
		_stage_text().replace(" ", "_").to_upper()
	)
	tutorial_panel.tooltip_text = tutorial_label.text


func _tutorial_text(stage_name: String) -> String:
	match stage_name:
		"NO_GAME":
			return "TUTORIAL · ROUND COMPLETE — This round is finished. Review the Activity rail if you want, then NEXT ROUND begins the next Development sequence."
		"DEVELOPMENT_SNARE":
			return "TUTORIAL · SNARE — Orias may activate Snare during Development. Activating it costs the shown Threat and restricts the enemy's Guard movement this Development; passing preserves Threat."
		"MARKET":
			return "TUTORIAL · MARKET — Trade exactly one Hand card for one Market card, or pass. The Market changes your Hand without consuming your later combat order."
		"REPAIR":
			return "TUTORIAL · REPAIR vs CONSTRUCTION — REPAIR restores an already-built damaged Castle: WRIGHT cards pay full printed value; every other suit pays 1 less (minimum 1). CONSTRUCTION builds an unbuilt Castle: suit does not matter and every card pays printed value; only 5 progress can be added in one Castle action. Drag a Hand card onto a Castle to choose the correct mode/target and add that card to payment."
		"DOMINION_RITES":
			return "TUTORIAL · DOMINION RITES — These are optional pre-combat rites. Cataclysmic Invocation takes the first 11 selected Hand value; if Profane Ruins is also chosen, later selected cards become its payment. Passing keeps those cards for later phases."
		"DEPLOY":
			return "TUTORIAL · DEPLOY — Move cards into Lord or Castle Guard zones before combat. Click uses the destination on the right; drag goes directly to the final Guard zone. STAGED Guards are reversible until FINISH DEPLOY."
		"MARCH":
			return "TUTORIAL · MARCH — Drag a Guard directly from your Lord Guards or Castle Guards into the Lord Lane or Castle Lane. You can still use the controls on the right. The Guard leaves defense and becomes a marcher; later rounds advance it toward the enemy gate, while opposing marchers can clash."
		"SUMMON":
			return "TUTORIAL · SUMMON — If your Lord is Banished, pay the displayed Summon cost from Hand to return it. Passing leaves the Lord Banished and preserves the cards."
		"REFLEX_BID":
			return "TUTORIAL · REFLEX BID — Select any Hand cards as your Reflex bid when this rules profile calls for one, or BID ZERO. This decides Reflex priority separately from your sealed combat order."
		"COMMITMENT":
			return "TUTORIAL · COMMITMENT — Drag Hand cards spatially: enemy Lord = HUNT; a specific enemy Castle = SIEGE; your Lord/Castle area = WARD. Provisional commitment cards rest over the chosen target. Single-click returns one card; double-click a Hand card goes ALL IN, and double-click a provisional card returns the entire commitment. FORECAST always evaluates your WHOLE HAND. In its branch display, ◇ means the target does not Ward and ◈ means the target raises a Ward/Sigil; a ◈ range means different possible enemy Ward strengths."
		"SEALED":
			return "TUTORIAL · SEALED — Your order is locked but still hidden. The opponent's sealed choice is also hidden. REVEAL ORDERS makes both public and begins reveal reactions."
		"REVEALED":
			return "TUTORIAL · REVEALED — Both sealed orders and their committed cards are now public. Resolution is intentionally paced: the acting commitment is shown, it slams into the opposing Ward or target defense, then the result is shown before play continues."
		"KANIFOUS_INVOKE":
			return "TUTORIAL · KANIFOUS · INVOKE — Pay exactly one Hand card as the toll, then choose one of the revealed cards to bank in Garrison; the other reveal is discarded."
		"KANIFOUS_WRIGHT":
			return "TUTORIAL · KANIFOUS · WRIGHT — Wright Invocation may move up to two of your Lord Guards into the Castle Guard zone. Choose zero, one, or two depending on where you want the defense."
		"VULTURE_RECON":
			return "TUTORIAL · VULTURE RECON — A committed Vulture lets you scout one enemy Guard area. Choose Lord or Castle to reveal information before Resolution."
		"RESOLUTION_HUMBABA_TOLL":
			return "TUTORIAL · HUMBABA · TOLL — Humbaba may ruin one of his own standing Castles to pay Toll. The right panel shows the legal Castle choices; pass if preserving the structure is worth more."
		"RESOLUTION_ACTION":
			return "TUTORIAL · ACTION RESOLUTION — Your revealed Hunt, Siege, Ward, or Profane is ready to resolve. The right panel only shows legal modifiers or follow-up choices still needed for that action."
		"RESOLUTION_VESSEL":
			return "TUTORIAL · OFFER THE VESSEL — Choose whether to offer your Lord for the available Dominion effect or keep the Lord in play. This is a follow-up choice, not a new sealed order."
		"RESOLUTION_REFLEX":
			return "TUTORIAL · MOMENTUM / REFLEX — The extra-action winner may take a Hunt, Siege, or Ward using a fresh Hand commitment, or pass. This action happens after the primary sealed orders."
		"RESOLUTION_ODRADEK_BREACH":
			return "TUTORIAL · ODRADEK BREACH — Predict the opponent's extra action, then choose the action Odradek would steal if the prediction is correct. Passing declines the interference."
		"RESOLUTION_GREMORY":
			return "TUTORIAL · GREMORY · INEVITABLE RUIN — After a qualifying Siege leaves a Castle standing, Gremory may pay exactly two Hand/Garrison cards to finish the ruin. Pass to keep the cards."
		"TERMINAL":
			return "TUTORIAL · MATCH COMPLETE — A win condition has been reached. The Activity rail preserves the final sequence; use DEV / restart when you want another seed or matchup."
		"INVALID":
			return "TUTORIAL · MATCH HALTED — The controller rejected the current state or decision. Check the right-panel status and DEV snapshot if you need to diagnose the failure."
		_:
			return "TUTORIAL · CURRENT PHASE — Follow the decision on the right. This phase has no special tutorial entry yet."


func _finish_ui2_controller_step(result: Dictionary) -> void:
	var action_name: String = String(result.get("action", ""))
	if action_name == "invalid":
		action_zone.set_status(
			"Choice rejected: %s" % String(result.get("reason", "invalid_choice"))
		)
		return

	if controller.stage != PlayableRoundControllerData.Stage.DEPLOY:
		queued_deploy_moves.clear()

	refresh_from_game()

	if (
		RESOLUTION_PRESENTATION_ENABLED
		and _ui2_aftermath_baseline_ready
		and controller.stage
		in [
			PlayableRoundControllerData.Stage.NO_GAME,
			PlayableRoundControllerData.Stage.TERMINAL,
		]
	):
		call_deferred("_play_ui2_completed_aftermath")


func _resolve_ui2_repair() -> Dictionary:
	var action_name: String = action_zone.get_primary_value()
	var castle_name: String = action_zone.get_secondary_value()
	if action_name.is_empty() or castle_name.is_empty():
		return {"action": "invalid", "reason": "choose_castle_action"}

	var payment: Array[String] = _combined_payment_ids()
	if payment.is_empty():
		return {"action": "invalid", "reason": "select_payment"}

	return controller.resolve_human_repair({
		"action": action_name,
		"castle": castle_name,
		"payment": payment,
		"use_token": action_zone.get_option_enabled() and action_name == "repair",
	})


func _build_ui2_rite_decision() -> Dictionary:
	var selected_ids: Array[String] = hand_view.selected_card_ids()
	var invocation_ids: Array[String] = []
	var profane_ids: Array[String] = []
	var invocation_value: int = 0
	var use_invocation: bool = action_zone.get_option_enabled()

	var value_by_id: Dictionary = {}
	var human = controller.get_human_player()
	for card in human.hand:
		value_by_id[String(card.card_id())] = int(card.value)

	for card_id in selected_ids:
		if use_invocation and invocation_value < 11:
			invocation_ids.append(card_id)
			invocation_value += int(value_by_id.get(card_id, 0))
		else:
			profane_ids.append(card_id)

	return {
		"invocation": (
			{"payment": invocation_ids}
			if use_invocation
			else {"pass": true}
		),
		"profane_ruins": (
			{
				"castle": action_zone.get_primary_value(),
				"payment": profane_ids,
			}
			if not action_zone.get_primary_value().is_empty()
			else {"pass": true}
		),
	}


func _stage_ui2_hand_cards_immediately(card_ids) -> void:
	var requested: Array[Dictionary] = []
	for raw_id in card_ids:
		requested.append({
			"source": "Hand",
			"card": String(raw_id),
		})

	_stage_ui2_deploy_requests(requested)


func _sync_ui2_attack_preview() -> void:
	if (
		enemy_player_board == null
		or hand_view == null
		or action_zone == null
	):
		return

	var card_ids: Array[String] = []
	var action_name: String = ""
	var target_name: String = ""

	if (
		controller != null
		and controller.game != null
		and controller.stage
		== PlayableRoundControllerData.Stage.COMMITMENT
	):
		action_name = action_zone.get_selected_action()
		if action_name in ["Hunt", "Siege"]:
			card_ids = hand_view.selected_card_ids()
			target_name = (
				"Lord"
				if action_name == "Hunt"
				else action_zone.get_primary_value()
			)

	enemy_player_board.set_attack_preview_cards(
		controller.get_human_player()
		if controller != null
		else null,
		card_ids,
		action_name,
		target_name,
		action_zone.rules_ref
	)


func _on_ui2_attack_card_dropped(
	card_id: String,
	action_name: String,
	target_name: String
) -> void:
	if (
		controller == null
		or controller.stage
		!= PlayableRoundControllerData.Stage.COMMITMENT
		or card_id.is_empty()
		or action_name not in ["Hunt", "Siege"]
	):
		return

	action_zone.set_commitment_action_target(
		action_name,
		target_name
	)

	var legal_target: bool = (
		action_zone.get_selected_action() == action_name
		and (
			action_name == "Hunt"
			or action_zone.get_primary_value() == target_name
		)
	)
	if not legal_target:
		action_zone.set_status(
			"%s · %s is not a legal target this round."
			% [action_name.to_upper(), target_name]
		)
		_sync_ui2_attack_preview()
		return

	var already_selected: bool = hand_view.selected_card_ids().has(card_id)
	if hand_view.select_card_id(card_id, true) or already_selected:
		enemy_player_board.flash_attack_target(
			action_name,
			target_name
		)
		action_zone.set_status(
			"%s · %s staged against %s. Drag more cards here or click a provisional attack card to return it."
			% [
				action_name.to_upper(),
				card_id,
				target_name,
			]
		)
		_sync_ui2_ward_preview()
		_sync_ui2_attack_preview()


func _on_ui2_attack_preview_card_clicked(
	card_id: String
) -> void:
	if (
		controller == null
		or controller.stage
		!= PlayableRoundControllerData.Stage.COMMITMENT
	):
		return

	if hand_view.deselect_card_id(card_id):
		action_zone.set_status(
			"COMMITMENT · %s returned to Hand selection."
			% card_id
		)
		_sync_ui2_attack_preview()



func _on_ui2_commitment_preview_all_requested(
	label: String
) -> void:
	if (
		controller == null
		or controller.stage
		!= PlayableRoundControllerData.Stage.COMMITMENT
		or hand_view == null
	):
		return

	hand_view.clear_selection()
	action_zone.set_status(
		"%s · entire commitment returned to Hand."
		% label
	)
	_sync_ui2_ward_preview()
	_sync_ui2_attack_preview()

func _sync_ui2_ward_preview() -> void:
	if (
		human_player_board == null
		or hand_view == null
		or action_zone == null
	):
		return

	var card_ids: Array[String] = []
	var target_zone: String = ""

	if (
		controller != null
		and controller.game != null
		and controller.stage
		== PlayableRoundControllerData.Stage.COMMITMENT
		and action_zone.get_selected_action() == "Ward"
	):
		card_ids = hand_view.selected_card_ids()
		target_zone = action_zone.get_primary_value()

	human_player_board.set_ward_preview_cards(
		controller.get_human_player()
		if controller != null
		else null,
		card_ids,
		target_zone,
		action_zone.rules_ref
	)


func _on_ui2_ward_card_dropped(
	card_id: String,
	target_zone: String
) -> void:
	if (
		controller == null
		or controller.stage
		!= PlayableRoundControllerData.Stage.COMMITMENT
		or card_id.is_empty()
		or target_zone not in [
			"Lord",
			"Castle",
		]
	):
		return

	action_zone.set_commitment_action_target(
		"Ward",
		target_zone
	)

	if (
		action_zone.get_selected_action() != "Ward"
		or action_zone.get_primary_value() != target_zone
	):
		action_zone.set_status(
			"WARD · %s is not a legal Ward target this round."
			% target_zone
		)
		return

	if hand_view.select_card_id(
		card_id,
		true
	):
		human_player_board.flash_ward_target(
			target_zone
		)
		action_zone.set_status(
			"WARD · %s staged over %s. Drag more cards here or click a Ward card on the zone to return it."
			% [
				card_id,
				target_zone,
			]
		)
		_sync_ui2_ward_preview()


func _on_ui2_ward_preview_card_clicked(
	card_id: String
) -> void:
	if (
		controller == null
		or controller.stage
		!= PlayableRoundControllerData.Stage.COMMITMENT
	):
		return

	if hand_view.deselect_card_id(
		card_id
	):
		action_zone.set_status(
			"WARD · %s returned to Hand selection."
			% card_id
		)
		_sync_ui2_ward_preview()


func _ui2_resolution_action_event_count() -> int:
	if controller == null:
		return 0

	var events = controller.resolution_state.get(
		"action_events",
		[]
	)
	return (
		events.size()
		if typeof(events) == TYPE_ARRAY
		else 0
	)


func _ui2_resolution_action_events_since(
	start_index: int
) -> Array:
	var result: Array = []
	if controller == null:
		return result

	var raw_events = controller.resolution_state.get(
		"action_events",
		[]
	)
	if typeof(raw_events) != TYPE_ARRAY:
		return result

	var events: Array = raw_events
	for index: int in range(
		maxi(0, start_index),
		events.size()
	):
		if typeof(events[index]) == TYPE_DICTIONARY:
			result.append(
				events[index]
			)

	return result


func _play_ui2_resolution_action_for_player(
	player_id: int
) -> void:
	if (
		resolution_theater == null
		or controller == null
		or controller.game == null
	):
		return

	var attacker = controller.game.get_player(
		player_id
	)
	var defender = controller.game.get_opponent(
		player_id
	)
	if attacker == null or defender == null:
		return

	var action_name: String = String(
		attacker.action
	)
	var target_name: String = _ui2_action_target_for_player(
		player_id,
		action_name
	)
	await resolution_theater.play_action(
		attacker,
		defender,
		action_name,
		target_name,
		_ui2_defender_ward_applies(
			player_id,
			action_name
		)
	)


func _play_ui2_resolution_event_action(
	event: Dictionary
) -> void:
	var player_id: int = int(
		event.get(
			"player_id",
			-1
		)
	)
	if player_id < 0:
		return

	await _play_ui2_resolution_action_for_player(
		player_id
	)


func _ui2_defender_ward_applies(
	attacker_id: int,
	action_name: String
) -> bool:
	if (
		controller == null
		or action_name not in [
			"Hunt",
			"Siege",
		]
	):
		return false

	var defender_id: int = (
		1
		if attacker_id == 0
		else 0
	)
	var defender = controller.game.get_player(
		defender_id
	)
	if defender == null or String(defender.action) != "Ward":
		return false

	var choice = controller.commitment_choices.get(
		defender_id,
		{}
	)
	if typeof(choice) != TYPE_DICTIONARY:
		return false

	var ward_target: String = String(
		choice.get(
			"target_type",
			choice.get(
				"ward_target",
				""
			)
		)
	)

	return ward_target == (
		"Lord"
		if action_name == "Hunt"
		else "Castle"
	)


func _ui2_action_target_for_player(
	player_id: int,
	action_name: String
) -> String:
	if controller == null:
		return "TARGET"

	var choice = controller.commitment_choices.get(
		player_id,
		{}
	)
	if typeof(choice) != TYPE_DICTIONARY:
		choice = {}

	match action_name:
		"Hunt":
			return "Enemy Lord"
		"Siege":
			return String(
				choice.get(
					"target_castle",
					"Castle"
				)
			)
		"Ward":
			return String(
				choice.get(
					"target_type",
					choice.get(
						"ward_target",
						"Zone"
					)
				)
			)
		"Profane":
			return String(
				choice.get(
					"target_castle",
					"Castle"
				)
			)
		_:
			return "Target"


func _play_ui2_target_impact_if_needed(
	attacker_id: int,
	action_result: Dictionary
) -> void:
	if (
		not RESOLUTION_PRESENTATION_ENABLED
		or resolution_theater == null
		or action_result.is_empty()
	):
		return

	var action_name: String = String(
		action_result.get(
			"action",
			""
		)
	).to_lower()

	var defender_role: String = (
		"ENEMY"
		if attacker_id == 0
		else "PLAYER"
	)

	if action_name == "siege":
		var before: int = int(
			action_result.get(
				"integrity_before",
				0
			)
		)
		var after: int = int(
			action_result.get(
				"integrity_after",
				before
			)
		)
		var damage: int = int(
			action_result.get(
				"structure_damage",
				maxi(0, before - after)
			)
		)
		var destroyed: bool = bool(
			action_result.get(
				"target_destroyed",
				false
			)
		)

		if before == after and not destroyed:
			return

		await resolution_theater.play_target_impact(
			String(
				action_result.get(
					"target_castle",
					"Castle"
				)
			),
			defender_role,
			"Integrity",
			before,
			after,
			damage,
			destroyed
		)
		return

	if action_name != "hunt":
		return

	if bool(action_result.get("keep_interposed", false)):
		return

	var destroyed: bool = bool(
		action_result.get(
			"destroyed",
			false
		)
	)
	if not destroyed:
		return

	var lord_defense: int = int(
		action_result.get(
			"lord_defense",
			0
		)
	)

	await resolution_theater.play_target_impact(
		"Lord",
		defender_role,
		"Defense",
		lord_defense,
		0,
		maxi(0, int(action_result.get("excess", 0))),
		true
	)


func _play_ui2_interposition_if_needed(
	attacker_id: int,
	action_result: Dictionary
) -> void:
	if (
		not RESOLUTION_PRESENTATION_ENABLED
		or resolution_theater == null
		or action_result.is_empty()
	):
		return

	var defender_role: String = (
		"ENEMY"
		if attacker_id == 0
		else "PLAYER"
	)

	if bool(action_result.get("keep_interposed", false)):
		var keep_before: int = int(action_result.get("keep_integrity_before", 0))
		var keep_after: int = int(action_result.get("keep_integrity_after", keep_before))
		var fortification: int = int(action_result.get("keep_fortification", 0))
		var keep_damage: int = int(
			action_result.get(
				"keep_damage",
				maxi(0, keep_before - keep_after)
			)
		)

		var detail: String = "KEEP %d → %d" % [keep_before, keep_after]
		if fortification > 0:
			detail += " · FORTIFICATION %d" % fortification
		if keep_damage > 0:
			detail += " · %d DAMAGE" % keep_damage
		if String(action_result.get("stopped_at", "")) == "Keep":
			detail += " · ATTACK STOPPED"

		await resolution_theater.play_interposition(
			"Keep",
			defender_role,
			detail
		)
		return

	var bastion_screened: bool = bool(
		action_result.get(
			"bastion_screened",
			action_result.get("bastion_interposed", false)
		)
	)
	if not bastion_screened:
		return

	var bastion_before: int = int(action_result.get("bastion_integrity_before", 0))
	var bastion_after: int = int(
		action_result.get("bastion_integrity_after", bastion_before)
	)

	if bastion_before <= bastion_after:
		return

	var bastion_damage: int = maxi(0, bastion_before - bastion_after)
	var detail: String = "BASTION %d → %d · ABSORBS %d" % [
		bastion_before,
		bastion_after,
		bastion_damage,
	]
	if bastion_after <= 0:
		detail += " · BASTION RUINED"

	await resolution_theater.play_interposition(
		"Bastion",
		defender_role,
		detail
	)



func _play_ui2_completed_aftermath() -> void:
	if (
		_ui2_aftermath_showing
		or not _ui2_aftermath_baseline_ready
		or resolution_theater == null
		or controller == null
		or controller.stage
		not in [
			PlayableRoundControllerData.Stage.NO_GAME,
			PlayableRoundControllerData.Stage.TERMINAL,
		]
	):
		return

	_ui2_aftermath_showing = true

	var context: Dictionary = _ui2_aftermath_context()
	context["round_complete"] = true
	resolution_theater.set_aftermath_context(context)

	await resolution_theater.play_result("")

	_ui2_aftermath_baseline_ready = false
	_ui2_aftermath_showing = false

func _capture_ui2_aftermath_baseline() -> void:
	if controller == null or controller.game == null:
		return

	var human = controller.get_human_player()
	var bot = controller.get_bot_player()
	if human == null or bot == null:
		return

	_ui2_aftermath_human_souls_before = int(human.souls)
	_ui2_aftermath_bot_souls_before = int(bot.souls)
	_ui2_aftermath_baseline_ready = true


func _ui2_aftermath_context() -> Dictionary:
	var context: Dictionary = {}

	if controller == null or controller.game == null:
		return context

	var human = controller.get_human_player()
	var bot = controller.get_bot_player()
	if human == null or bot == null:
		return context

	if not _ui2_aftermath_baseline_ready:
		_ui2_aftermath_human_souls_before = int(human.souls)
		_ui2_aftermath_bot_souls_before = int(bot.souls)
		_ui2_aftermath_baseline_ready = true

	var human_action: String = String(human.action)
	var bot_action: String = String(bot.action)

	context["player_lord"] = String(human.lord)
	context["player_action"] = human_action
	context["player_target"] = _ui2_action_target_for_player(
		0,
		human_action
	)
	context["player_outcome"] = _ui2_aftermath_outcome_for_player(0)

	context["enemy_lord"] = String(bot.lord)
	context["enemy_action"] = bot_action
	context["enemy_target"] = _ui2_action_target_for_player(
		1,
		bot_action
	)
	context["enemy_outcome"] = _ui2_aftermath_outcome_for_player(1)

	context["human_souls_before"] = _ui2_aftermath_human_souls_before
	context["human_souls_after"] = int(human.souls)
	context["bot_souls_before"] = _ui2_aftermath_bot_souls_before
	context["bot_souls_after"] = int(bot.souls)
	context["round_complete"] = (
		controller.stage
		in [
			PlayableRoundControllerData.Stage.NO_GAME,
			PlayableRoundControllerData.Stage.TERMINAL,
		]
	)

	return context


func _ui2_aftermath_outcome_for_player(
	player_id: int
) -> String:
	if controller == null:
		return "AWAITING RESOLUTION"

	var state = controller.resolution_state
	if typeof(state) != TYPE_DICTIONARY:
		return "AWAITING RESOLUTION"

	var raw_events = state.get("action_events", [])
	if typeof(raw_events) == TYPE_ARRAY:
		for raw_event in raw_events:
			if typeof(raw_event) != TYPE_DICTIONARY:
				continue
			var event: Dictionary = raw_event
			if int(event.get("player_id", -1)) != player_id:
				continue
			return _ui2_resolution_event_summary(event)

	if int(state.get("pending_player_id", -1)) == player_id:
		var pending_raw = state.get(
			"pending_action_result",
			{}
		)
		if typeof(pending_raw) == TYPE_DICTIONARY:
			var pending: Dictionary = pending_raw
			if not pending.is_empty():
				return _ui2_action_result_summary(
					String(
						state.get(
							"pending_committed_action",
							"Action"
						)
					),
					pending
				)

	if controller.stage in [
		PlayableRoundControllerData.Stage.NO_GAME,
		PlayableRoundControllerData.Stage.TERMINAL,
	]:
		return "DID NOT RESOLVE"

	return "AWAITING RESOLUTION"


func _ui2_resolution_event_summary(
	event: Dictionary
) -> String:
	var action_name: String = String(
		event.get(
			"committed_action",
			"Action"
		)
	)
	var action_result = event.get(
		"action_result",
		{}
	)
	if typeof(action_result) != TYPE_DICTIONARY:
		action_result = {}

	return _ui2_action_result_summary(
		action_name,
		action_result
	)


func _ui2_action_result_summary(
	action_name: String,
	action_result: Dictionary
) -> String:
	var won: bool = bool(action_result.get("won", false))
	var summary: String = ""

	match action_name:
		"Siege":
			var integrity_before: int = int(action_result.get("integrity_before", -1))
			var integrity_after: int = int(action_result.get("integrity_after", integrity_before))
			var castle_ruined: bool = (
				bool(action_result.get("destroyed", false))
				or bool(action_result.get("target_destroyed", false))
				or (integrity_before > 0 and integrity_after <= 0)
			)
			var castle_damaged: bool = (
				integrity_before >= 0
				and integrity_after >= 0
				and integrity_after < integrity_before
			)

			if castle_ruined:
				summary = "SIEGE RESOLVES · CASTLE RUINED"
			elif castle_damaged:
				summary = "SIEGE RESOLVES · CASTLE DAMAGED"
			elif won:
				summary = "SIEGE BREAKS THROUGH"
			else:
				summary = "SIEGE RESOLVES · CASTLE HOLDS"
		"Hunt":
			var lord_banished: bool = bool(
				action_result.get("banished", false)
			)
			var lord_destroyed: bool = bool(
				action_result.get("destroyed", false)
			)

			if lord_banished:
				summary = "HUNT RESOLVES · LORD BANISHED"
			elif lord_destroyed:
				summary = "HUNT BREAKS THROUGH"
			elif won:
				summary = "HUNT BREAKS THROUGH"
			else:
				summary = "HUNT RESOLVES · LORD HOLDS"
		"Ward":
			summary = "WARD RESOLVES"
		"Profane":
			summary = "PROFANE RESOLVES"
		_:
			summary = "%s RESOLVES" % action_name.to_upper()

	var raw_guards = action_result.get("guards_defeated", [])
	if typeof(raw_guards) == TYPE_ARRAY:
		var guard_count: int = raw_guards.size()
		if guard_count > 0:
			summary += " · %d GUARD%s DEFEATED" % [
				guard_count,
				"" if guard_count == 1 else "S",
			]

	if bool(action_result.get("keep_interposed", false)):
		var keep_before: int = int(action_result.get("keep_integrity_before", 0))
		var keep_after: int = int(action_result.get("keep_integrity_after", keep_before))
		summary += " · KEEP %d→%d" % [keep_before, keep_after]
		if String(action_result.get("stopped_at", "")) == "Keep":
			summary += " · ATTACK STOPPED"

	var bastion_screened: bool = bool(
		action_result.get(
			"bastion_screened",
			action_result.get("bastion_interposed", false)
		)
	)
	if bastion_screened:
		var bastion_before: int = int(action_result.get("bastion_integrity_before", 0))
		var bastion_after: int = int(
			action_result.get("bastion_integrity_after", bastion_before)
		)
		if bastion_before > bastion_after:
			summary += " · BASTION %d→%d" % [bastion_before, bastion_after]

	if action_result.has("integrity_before") and action_result.has("integrity_after"):
		var integrity_before: int = int(action_result.get("integrity_before", 0))
		var integrity_after: int = int(
			action_result.get("integrity_after", integrity_before)
		)
		if integrity_before != integrity_after:
			summary += " · TARGET %d→%d" % [integrity_before, integrity_after]

	if bool(action_result.get("sigil_broken", false)):
		summary += " · SIGIL BROKEN"


	# FRACTURE_MARCHERS_AFTERMATH_V1 — Fracture is part of the completed
	# action outcome, so true-round AFTERMATH narrates the chosen category and
	# every board deterioration event instead of making the player infer it.
	var raw_fracture = action_result.get("fracture", {})
	if typeof(raw_fracture) == TYPE_DICTIONARY:
		var fracture: Dictionary = raw_fracture
		if bool(fracture.get("triggered", false)):
			summary += "\nFRACTURE %d · %s" % [
				int(fracture.get("fracture", 0)),
				String(fracture.get("category", "")).to_upper(),
			]
			var raw_events = fracture.get("events", [])
			if typeof(raw_events) == TYPE_ARRAY:
				for raw_event in raw_events:
					if typeof(raw_event) != TYPE_DICTIONARY:
						continue
					var fracture_event: Dictionary = raw_event
					var kind: String = String(fracture_event.get("kind", ""))
					if kind == "subject":
						var zone: String = String(fracture_event.get("zone", ""))
						var target_label: String = zone.to_upper()
						match zone:
							"Lord":
								target_label = "LORD GUARD"
							"Castle":
								target_label = "CASTLE GUARD"
							"Garrison":
								target_label = "GARRISON"
							"Marcher":
								var lane: String = String(fracture_event.get("lane", ""))
								target_label = "MARCHER"
								if not lane.is_empty():
									target_label += " · %s LANE" % lane.to_upper()
						var card_before: String = String(
							fracture_event.get("card_before", "SUBJECT")
						)
						var subject_name: String = card_before.get_slice(":", 0).to_upper()
						summary += "\n%s · %s %d→%d" % [
							target_label,
							subject_name,
							int(fracture_event.get("before", 0)),
							int(fracture_event.get("after", 0)),
						]
						if (
							zone == "Marcher"
							and fracture_event.has("march_before")
						):
							summary += " · FORCE %d→%d" % [
								int(fracture_event.get("march_before", 0)),
								int(fracture_event.get("march_after", 0)),
							]
					elif kind == "infrastructure":
						var line: String = "\n%s · INTEGRITY %d→%d" % [
							String(fracture_event.get("castle", "DEFENSE")).to_upper(),
							int(fracture_event.get("before", 0)),
							int(fracture_event.get("after", 0)),
						]
						if bool(fracture_event.get("ruined", false)):
							line += " · RUINED"
						summary += line

	return summary


func _sync_ui2_castle_payment_preview() -> void:
	if (
		human_player_board == null
		or hand_view == null
		or action_zone == null
	):
		return

	var card_ids: Array[String] = []
	var action_name: String = ""
	var castle_name: String = ""

	if (
		controller != null
		and controller.game != null
		and controller.stage
		== PlayableRoundControllerData.Stage.REPAIR
	):
		action_name = action_zone.get_primary_value()
		castle_name = action_zone.get_secondary_value()

		if action_name in ["repair", "construct"]:
			card_ids = hand_view.selected_card_ids()

	human_player_board.set_castle_payment_preview_cards(
		controller.get_human_player()
		if controller != null
		else null,
		card_ids,
		action_name,
		castle_name,
		action_zone.rules_ref
	)


func _on_ui2_castle_payment_preview_card_clicked(
	card_id: String
) -> void:
	if (
		controller == null
		or controller.stage
		!= PlayableRoundControllerData.Stage.REPAIR
	):
		return

	if hand_view.deselect_card_id(card_id):
		action_zone.set_status(
			"PAYMENT · %s returned to Hand."
			% card_id
		)
		_sync_ui2_castle_payment_preview()


func _on_ui2_castle_payment_preview_all_requested() -> void:
	if (
		controller == null
		or controller.stage
		!= PlayableRoundControllerData.Stage.REPAIR
	):
		return

	hand_view.clear_selection()
	action_zone.set_status(
		"PAYMENT · entire staged Hand payment returned."
	)
	_sync_ui2_castle_payment_preview()

func _on_ui2_castle_payment_card_dropped(
	card_id: String,
	castle_name: String,
	action_name: String
) -> void:
	if (
		controller == null
		or controller.stage != PlayableRoundControllerData.Stage.REPAIR
		or card_id.is_empty()
		or castle_name.is_empty()
		or action_name not in ["repair", "construct"]
	):
		return

	action_zone.set_castle_action_target(
		action_name,
		castle_name
	)

	if hand_view.select_card_id(card_id, true):
		human_player_board.flash_castle_action_target(castle_name)
		action_zone.set_status(
			"%s %s targeted · %s added to payment. Drag more cards or click selected cards to remove them."
			% [
				action_name.to_upper(),
				castle_name,
				card_id,
			]
		)
	_sync_ui2_castle_payment_preview()


func _on_ui2_deploy_card_dropped(
	source: String,
	card_id: String,
	target_zone: String
) -> void:
	if (
		controller == null
		or controller.stage
		!= PlayableRoundControllerData.Stage.DEPLOY
		or source != "Hand"
		or card_id.is_empty()
		or target_zone not in [
			"Lord",
			"Castle",
		]
	):
		return

	action_zone.set_deploy_target(
		target_zone
	)

	_stage_ui2_deploy_requests(
		[
			{
				"source": source,
				"card": card_id,
			},
		],
		target_zone
	)


func _queue_ui2_deploy_selection() -> void:
	var requested: Array[Dictionary] = []

	for raw_value in action_zone.get_aux_selected_values():
		var parts: PackedStringArray = String(raw_value).split("|", false, 1)
		if parts.size() == 2 and parts[0] == "Garrison":
			requested.append({
				"source": "Garrison",
				"card": parts[1],
			})

	if requested.is_empty():
		action_zone.set_status(
			"Click a Hand card to stage it, or select Garrison cards here."
		)
		return

	_stage_ui2_deploy_requests(requested)


func _stage_ui2_deploy_requests(
	requested: Array[Dictionary],
	target_override: String = ""
) -> void:
	var human = controller.get_human_player()
	if human == null or requested.is_empty():
		return

	var target_zone: String = (
		target_override
		if target_override in [
			"Lord",
			"Castle",
		]
		else action_zone.get_primary_value()
	)
	if target_zone not in ["Lord", "Castle"]:
		action_zone.set_status("Choose Lord or Castle Guards first.")
		hand_view.clear_selection()
		return

	var target_key: String = target_zone.to_lower()
	var current_count: int = (
		human.lord_guards.size()
		if target_zone == "Lord"
		else human.castle_guards.size()
	)
	for move in queued_deploy_moves:
		if String(move.get("target", "")).to_lower() == target_key:
			current_count += 1

	var zone_limit: int = int(
		DeployEngineData._target_limit(human, controller.rules, target_key)
	)
	var open_slots: int = maxi(0, zone_limit - current_count)
	if requested.size() > open_slots:
		action_zone.set_status(
			"%s Guards have room for %d more card%s." % [
				target_zone,
				open_slots,
				"" if open_slots == 1 else "s",
			]
		)
		hand_view.clear_selection()
		return

	if bool(human.orias_snare_active) and queued_deploy_moves.size() + requested.size() > 1:
		action_zone.set_status("Snare allows only one total Guard move this Development.")
		hand_view.clear_selection()
		return

	var queued_source_counts: Dictionary = {}
	for move in queued_deploy_moves:
		var queued_key: String = "%s|%s" % [move.get("source", ""), move.get("card", "")]
		queued_source_counts[queued_key] = int(queued_source_counts.get(queued_key, 0)) + 1

	var pool_counts: Dictionary = {}
	for card in human.hand:
		var hand_key: String = "Hand|%s" % String(card.card_id())
		pool_counts[hand_key] = int(pool_counts.get(hand_key, 0)) + 1
	for card in human.garrison:
		var garrison_key: String = "Garrison|%s" % String(card.card_id())
		pool_counts[garrison_key] = int(pool_counts.get(garrison_key, 0)) + 1

	var request_counts: Dictionary = {}
	for entry in requested:
		var request_key: String = "%s|%s" % [entry.get("source", ""), entry.get("card", "")]
		request_counts[request_key] = int(request_counts.get(request_key, 0)) + 1
		if int(request_counts[request_key]) + int(queued_source_counts.get(request_key, 0)) > int(pool_counts.get(request_key, 0)):
			action_zone.set_status("That card occurrence is already staged for Deploy.")
			hand_view.clear_selection()
			return

	if (
		bool(controller.rules.repair_blocks_hand_deploy)
		and bool(human.repaired_this_round)
		and not bool(human.repair_token_used_this_repair)
	):
		for entry in requested:
			if String(entry.get("source", "")) == "Hand":
				action_zone.set_status("Repair blocks Hand deployment this round.")
				hand_view.clear_selection()
				return

	if DeployEngineData._frenzy_blocks_garrison(controller.game, human):
		for entry in requested:
			if String(entry.get("source", "")) == "Garrison":
				action_zone.set_status("Frenzy blocks Garrison deployment.")
				hand_view.clear_selection()
				return

	for entry in requested:
		queued_deploy_moves.append({
			"source": String(entry.get("source", "")),
			"target": target_zone,
			"card": String(entry.get("card", "")),
			"source_index": -1,
		})

	action_zone.clear_aux_selection()
	call_deferred(
		"_refresh_ui2_deploy_surfaces",
		_deploy_staging_status()
	)


func _on_ui2_deploy_unstage_requested(queue_index: int) -> void:
	if (
		controller == null
		or controller.stage != PlayableRoundControllerData.Stage.DEPLOY
		or queue_index < 0
		or queue_index >= queued_deploy_moves.size()
	):
		return

	var returned_move: Dictionary = queued_deploy_moves[queue_index]
	queued_deploy_moves.remove_at(queue_index)

	call_deferred(
		"_refresh_ui2_deploy_surfaces",
		"RETURNED · %s %s to %s" % [
			String(returned_move.get("source", "")),
			String(returned_move.get("card", "")),
			(
				"Hand"
				if String(returned_move.get("source", "")) == "Hand"
				else "Garrison"
			),
		]
	)


func _refresh_ui2_deploy_surfaces(
	status_text: String
) -> void:
	if (
		controller == null
		or controller.game == null
		or controller.stage
		!= PlayableRoundControllerData.Stage.DEPLOY
	):
		return

	var human = controller.get_human_player()
	if human == null:
		return

	hand_view.set_deploy_drag_enabled(
		true
	)
	hand_view.set_staged_deploy_moves(
		queued_deploy_moves
	)
	hand_view.bind_player(
		human,
		true
	)

	human_player_board.set_deploy_drop_enabled(
		true
	)
	human_player_board.set_staged_deploy_moves(
		queued_deploy_moves
	)
	human_player_board.bind_player(
		human,
		true
	)

	action_zone.set_deploy_staged_moves(
		queued_deploy_moves
	)
	action_zone.set_selected_card_count(
		0
	)
	action_zone.set_selected_hand_cards(
		[]
	)
	action_zone.set_status(
		status_text
	)


func _deploy_staging_status() -> String:
	if queued_deploy_moves.is_empty():
		return "No Guard moves staged."

	var parts: Array[String] = []
	for move in queued_deploy_moves:
		parts.append(
			"%s %s → %s Guards"
			% [
				String(move.get("source", "")),
				String(move.get("card", "")),
				String(move.get("target", "")),
			]
		)

	return (
		"STAGED · "
		+ " | ".join(parts)
		+ " · FINISH DEPLOY to resolve"
	)


func _on_ui2_march_guard_dropped(
	source_zone: String,
	card_id: String,
	lane_name: String
) -> void:
	if (
		controller == null
		or controller.stage != PlayableRoundControllerData.Stage.MARCH
		or source_zone not in ["Lord", "Castle"]
		or lane_name not in ["Lord", "Castle"]
		or card_id.is_empty()
	):
		return

	action_zone.set_status(
		"MARCH · %s Guard %s → %s lane"
		% [
			source_zone,
			card_id,
			lane_name,
		]
	)

	# The drop originates inside MarchingLaneView. Resolve next frame so
	# refresh_from_game can rebuild the lane safely after the drop signal ends.
	call_deferred(
		"_resolve_ui2_dragged_march",
		source_zone,
		card_id,
		lane_name
	)


func _resolve_ui2_dragged_march(
	source_zone: String,
	card_id: String,
	lane_name: String
) -> void:
	if (
		controller == null
		or controller.stage != PlayableRoundControllerData.Stage.MARCH
	):
		return

	var result: Dictionary = controller.resolve_human_march({
		"action": "march",
		"source_zone": source_zone,
		"lane": lane_name,
		"card": card_id,
	})
	_finish_ui2_controller_step(result)


func _resolve_ui2_march() -> Dictionary:
	var selected_guards: Array[String] = action_zone.get_aux_selected_values()
	if selected_guards.size() != 1:
		return {"action": "invalid", "reason": "choose_one_guard"}
	return controller.resolve_human_march({
		"action": "march",
		"source_zone": action_zone.get_primary_value(),
		"lane": action_zone.get_secondary_value(),
		"card": selected_guards[0],
	})


func _build_ui2_resolution_action_options() -> Dictionary:
	var human = controller.get_human_player()
	var option_id: String = action_zone.get_primary_value()

	if human.action == "Hunt":
		var hunt_parts: PackedStringArray = option_id.split(":")
		return {
			"consume_hunt": (
				hunt_parts.size() >= 2
				and hunt_parts[1] == "1"
			),
			"fracture_target": (
				String(hunt_parts[2])
				if hunt_parts.size() >= 3
				else "subjects"
			),
		}

	if human.action == "Siege":
		var parts: PackedStringArray = option_id.split(":")
		var committed_choice: Dictionary = controller.commitment_choices.get(0, {})
		return {
			"target_castle": String(committed_choice.get("target_castle", "")),
			"consume_siege": (
				controller.rules.consume_the_siege
				and parts.size() >= 3
				and parts[1] == "1"
			),
			"use_inferno": (
				human.alive
				and String(human.lord) == "Kalligan"
				and parts.size() >= 3
				and parts[2] == "1"
			),
		}

	if human.action == "Profane":
		var profane_choice: Dictionary = controller.commitment_choices.get(0, {})
		return {"target_castle": String(profane_choice.get("target_castle", ""))}

	return {}


func _build_ui2_reflex_decision(use_secondary_target: bool) -> Dictionary:
	var target_id: String = (
		action_zone.get_secondary_value()
		if use_secondary_target
		else action_zone.get_primary_value()
	)
	var decision: Dictionary = {
		"action": action_zone.get_selected_action(),
		"cards": hand_view.selected_card_ids(),
	}

	match action_zone.get_selected_action():
		"Hunt":
			var hunt_parts: PackedStringArray = target_id.split("|")
			decision["consume_hunt"] = hunt_parts.size() >= 2 and hunt_parts[1] == "1"
			decision["fracture_target"] = (
				String(hunt_parts[2])
				if hunt_parts.size() >= 3
				else "subjects"
			)
		"Siege":
			var siege_parts: PackedStringArray = target_id.split("|")
			decision["target_castle"] = siege_parts[0] if not siege_parts.is_empty() else ""
			decision["consume_siege"] = (
				controller.rules.consume_the_siege
				and siege_parts.size() >= 2
				and siege_parts[1] == "1"
			)
			decision["use_inferno"] = (
				controller.get_human_player().alive
				and String(controller.get_human_player().lord) == "Kalligan"
				and siege_parts.size() >= 3
				and siege_parts[2] == "1"
			)
		"Ward":
			decision["ward_target"] = target_id

	return decision


func _combined_payment_ids() -> Array[String]:
	var result: Array[String] = hand_view.selected_card_ids().duplicate()
	for raw_value in action_zone.get_aux_selected_values():
		var parts: PackedStringArray = raw_value.split("|", false, 1)
		result.append(parts[1] if parts.size() == 2 else raw_value)
	return result


func _stage_uses_hand_selection() -> bool:
	if controller == null:
		return false
	return controller.stage in [
		PlayableRoundControllerData.Stage.MARKET,
		PlayableRoundControllerData.Stage.REPAIR,
		PlayableRoundControllerData.Stage.DOMINION_RITES,
		PlayableRoundControllerData.Stage.DEPLOY,
		PlayableRoundControllerData.Stage.SUMMON,
		PlayableRoundControllerData.Stage.REFLEX_BID,
		PlayableRoundControllerData.Stage.COMMITMENT,
		PlayableRoundControllerData.Stage.KANIFOUS_INVOKE,
		PlayableRoundControllerData.Stage.RESOLUTION_REFLEX,
		PlayableRoundControllerData.Stage.RESOLUTION_GREMORY,
	]


func _on_dev_pressed() -> void:
	if dev_panel != null:
		dev_panel.open_panel(
			active_human_lord,
			active_bot_lord,
			active_match_seed
		)


func _snapshot_stage_name() -> String:
	if controller == null:
		return "NO_GAME"

	var stage_key = PlayableRoundControllerData.Stage.find_key(
		controller.stage
	)

	return (
		String(stage_key)
		if stage_key != null
		else "UNKNOWN_%d" % int(controller.stage)
	)


func _snapshot_ui_context() -> Array:
	var entry: Dictionary = {
		"surface": "UI2",
		"stage": _snapshot_stage_name(),
	}

	if controller != null and controller.game != null:
		entry["round"] = int(controller.game.round)

	if hand_view != null:
		entry["selected_hand_cards"] = hand_view.selected_card_ids()

	if action_zone != null:
		entry["selected_action"] = action_zone.get_selected_action()
		entry["selected_target"] = action_zone.get_selected_target()
		entry["primary_value"] = action_zone.get_primary_value()
		entry["secondary_value"] = action_zone.get_secondary_value()
		entry["option_enabled"] = action_zone.get_option_enabled()
		entry["aux_selected_values"] = action_zone.get_aux_selected_values()

	return [entry]


func _on_dev_export_snapshot_requested() -> void:
	if dev_panel == null:
		return

	var export_result: Dictionary = (
		PlayableMatchSnapshotData.export_current_match(
			controller,
			active_match_seed,
			_snapshot_stage_name(),
			_snapshot_ui_context()
		)
	)

	if bool(export_result.get("ok", false)):
		dev_panel.set_status_message(
			"Snapshot exported:\n%s"
			% String(export_result.get("path", ""))
		)
		return

	dev_panel.set_status_message(
		"Snapshot export failed: %s"
		% String(
			export_result.get(
				"reason",
				"unknown_error"
			)
		)
	)


func _on_dev_start_requested(
	human_lord: String,
	bot_lord: String,
	seed_value: int
) -> void:
	active_human_lord = human_lord
	active_bot_lord = bot_lord
	active_match_seed = seed_value
	showcase_rounds = 0
	showcase_invalid_reason = ""
	queued_deploy_moves.clear()

	controller = PlayableRoundControllerData.new()
	var result: Dictionary = controller.start_match(
		human_lord,
		bot_lord,
		seed_value
	)

	if dev_panel != null:
		dev_panel.hide_panel()

	if String(result.get("action", "")) == "invalid":
		push_error("UI2 DEV start failed: %s" % String(result.get("reason", "invalid_start")))

	refresh_from_game()

func _build_ui2_commitment_decision() -> Dictionary:
	var human = controller.get_human_player()
	var bot = controller.get_bot_player()

	if human == null or bot == null:
		return {}

	var action_name: String = action_zone.get_selected_action()
	var target_id: String = action_zone.get_selected_target()

	var decision: Dictionary = {
		"action": action_name,
		"cards": hand_view.selected_card_ids(),
	}

	match action_name:
		"Hunt":
			decision["target_pid"] = int(
				bot.pid
			)

		"Siege":
			decision["target_pid"] = int(
				bot.pid
			)
			decision["target_castle"] = target_id

		"Ward":
			decision["target_pid"] = int(
				human.pid
			)
			decision["target_type"] = target_id

		"Profane":
			decision["target_pid"] = int(
				human.pid
			)
			decision["target_castle"] = target_id
			decision["cards"] = []

	return decision


func _on_console_pressed() -> void:
	if console_overlay != null:
		console_overlay.show_console()
