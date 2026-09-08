# UI2_SLAVER_THEME_V1_1
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

# SIEGE_ENGINE_BOMBARDMENT_V1
const SiegeEngineFireEngineData = preload(
	"res://Scripts/Sim/SiegeEngineFireEngine.gd"
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

# UI2_LORD_PANEL_SKIN_V1_2
const UI2_LORD_PANEL_PATH: String = (
	"res://ConceptImages/Menus/LordPanel.png"
)
var _ui2_lord_panel_texture_v1_2: Texture2D = null

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

const PhasePromptData = preload(
	"res://Prototype/UI2/PhasePrompt.gd"
)

const BreachSlotData = preload(
	"res://Prototype/UI2/BreachSlot.gd"
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


# UI2_SIEGE_ENGINE_BOMBARDMENT_FX_V1
const SiegeEngineBombardmentViewData = preload(
	"res://Prototype/UI2/SiegeEngineBombardmentView.gd"
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
const TUTORIAL_ENABLED: bool = false
const RESOLUTION_PRESENTATION_ENABLED: bool = true

# UI2_DIALOGUE_BREACH_OVERHAUL_V1
@export var show_dev_controls: bool = false


# Zero = normal playable UI2.
# Positive = debug-only authentic bot-vs-bot board frozen after N completed rounds.
@export var showcase_rounds: int = 0
var showcase_invalid_reason: String = ""


# UI2_SIEGE_ENGINE_BOMBARDMENT_FX_V1
var siege_engine_bombardment_view = null
var _ui2_siege_engine_fx_played_keys: Dictionary = {}


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
var phase_prompt = null
var breach_slot = null
var history_button: Button = null
var console_overlay = null
var activity_rail = null
var hand_view = null
var veil_track = null
var dev_panel = null
var resolution_theater = null
# UI2_SCRUM_THEATER_PRODUCTION_WIRING_V1
var _ui2_scrum_theater_demo_shown: bool = false
var _ui2_aftermath_human_souls_before: int = 0
var _ui2_aftermath_bot_souls_before: int = 0
var _ui2_aftermath_baseline_ready: bool = false
var _snapshot_round_recaps: Array[Dictionary] = []
var _ui2_aftermath_showing: bool = false
# BATTLEFIELD_PLAYBACK_V1
var _ui2_battlefield_playback_active: bool = false
var _ui2_battlefield_stage_override: String = ""
var _ui2_battlefield_input_blocker: Control = null
# BATTLEFIELD_PLAYBACK_NONBLOCKING_ONCE_V1
# Playback is presentation only and never gates decisions.
var _ui2_battlefield_played_half_keys: Dictionary = {}
var _ui2_battlefield_pending_halves: Array[Dictionary] = []
# UI2_COMMITMENT_DOUBLE_CLICK_ALL_IN_V1
var tutorial_panel: PanelContainer = null
var tutorial_label: Label = null
var active_match_seed: int = DEFAULT_SEED
var active_human_lord: String = DEFAULT_HUMAN_LORD
var active_bot_lord: String = DEFAULT_BOT_LORD
var queued_deploy_moves: Array[Dictionary] = []
# UI2_CASTLE_CARDS_AND_RITE_DISCOVERY_V1
# Hide Dominion Rites until one is genuinely actionable; once discovered,
# keep showing the phase for the rest of that match.
var _dominion_rites_prompt_unlocked: bool = false
var _dominion_rites_auto_pass_pending: bool = false


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

	_install_ui2_black_gap_backdrop()
	_build_shell()

	# UI2_SIEGE_ENGINE_BOMBARDMENT_FX_V1
	siege_engine_bombardment_view = SiegeEngineBombardmentViewData.new()
	siege_engine_bombardment_view.name = "SiegeEngineBombardmentView"
	add_child(siege_engine_bombardment_view)
	siege_engine_bombardment_view.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

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
	_dominion_rites_prompt_unlocked = false
	_dominion_rites_auto_pass_pending = false
	active_human_lord = starting_human_lord
	active_bot_lord = starting_bot_lord
	active_match_seed = starting_seed

	if showcase_rounds > 0:
		_load_midgame_showcase(
			showcase_rounds
		)

	refresh_from_game()


# UI2_BLACK_GAP_BACKDROP_V1
# Fill every part of the UI2 viewport that is not explicitly painted by
# another control. This replaces the remaining default gray gutters/gaps
# without changing any panel/button/card styling.
func _install_ui2_black_gap_backdrop() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "UI2BlackGapBackdrop"
	backdrop.color = Color.BLACK
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.z_index = -100
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)


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

	# SIEGE_ENGINE_BOMBARDMENT_V1
	var siege_engine_fire_result: Dictionary = (
		SiegeEngineFireEngineData.resolve(
			showcase_game,
			controller.rules,
			showcase_rng
		)
	)
	_append_showcase_event(
		showcase_events,
		showcase_game,
		"siege_engine_fire",
		siege_engine_fire_result
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
	_install_lord_panel_skin_v1_2(
		enemy_summary,
		Color(1.0, 0.72, 0.72, 1.0),
		"EnemyLordPanelArtV1"
	)

	enemy_puck = PlayerPuckData.new()
	enemy_puck.name = "EnemyPuck"
	enemy_summary.add_child(enemy_puck)

	# UI2_DEV_RESTORE_INVOKE_GUIDANCE_V1
	# Keep the setup/reproduction panel reachable while UI2 is under active
	# development. This is intentionally beside the enemy summary rather than
	# buried in the normal player decision interface.
	var dev_button := Button.new()
	dev_button.name = "DevButton"
	dev_button.text = "DEV"
	dev_button.tooltip_text = "Developer match setup / reproduction tools"
	dev_button.custom_minimum_size = Vector2(52, 32)
	dev_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	dev_button.pressed.connect(
		_on_dev_pressed
	)
	top.add_child(dev_button)

	veil_track = VeilTrackData.new()
	veil_track.name = "VeilTrack"
	veil_track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(veil_track)

	# UI2_TOP_BANNER_CHILD_SKIN_V3
	# Decorative background only; VeilTrack remains the live owner of all text/pips.
	var veil_banner_art := TextureRect.new()
	veil_banner_art.name = "TopBannerArt"
	veil_banner_art.texture = load(
		"res://ConceptImages/Menus/TopBanner.png"
	) as Texture2D
	veil_banner_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil_banner_art.stretch_mode = TextureRect.STRETCH_SCALE
	veil_banner_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil_banner_art.modulate = Color(1.0, 1.0, 1.0, 0.92)
	veil_track.add_child(veil_banner_art)
	veil_track.move_child(veil_banner_art, 0)

	breach_slot = BreachSlotData.new()
	breach_slot.name = "BreachSlot"
	top.add_child(breach_slot)

	var human_summary := PanelContainer.new()
	human_summary.custom_minimum_size = Vector2(205, 92)
	human_summary.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color(0.055, 0.105, 0.17, 1.0)
		)
	)
	top.add_child(human_summary)
	_install_lord_panel_skin_v1_2(
		human_summary,
		Color(0.72, 0.84, 1.0, 1.0),
		"HumanLordPanelArtV1"
	)

	human_puck = PlayerPuckData.new()
	human_puck.name = "HumanPuck"
	human_summary.add_child(human_puck)

	history_button = Button.new()
	history_button.text = "HISTORY"
	history_button.pressed.connect(
		_on_history_pressed
	)
	top.add_child(history_button)

	if show_dev_controls:
		var console_button := Button.new()
		console_button.text = "CONSOLE"
		console_button.pressed.connect(
			_on_console_pressed
		)
		top.add_child(console_button)


	var body := HBoxContainer.new()
	body.name = "Body"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	main.add_child(body)

	# Activity is now a collapsible History overlay rather than permanent board chrome.
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
	# UI2_BOARD_SURFACE_BLACK_V2
	var board_surface := PanelContainer.new()
	board_surface.name = "BoardSurface"
	board_surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_surface.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color.BLACK
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
	# UI2_HUMAN_CASTLE_GUARDS_ABOVE_CASTLES_V1
	human_player_board.castle_guards_above_castles = true
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
	action_zone.set_dialog_mode(true)
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
	phase_prompt = PhasePromptData.new()
	phase_prompt.name = "PhasePrompt"
	add_child(phase_prompt)
	phase_prompt.attach_action_zone(action_zone)
	phase_prompt.confirm_requested.connect(
		_on_ui2_confirm_requested
	)
	phase_prompt.pass_requested.connect(
		_on_ui2_pass_requested
	)

	activity_rail = ActivityRailData.new()
	activity_rail.name = "HistoryOverlay"
	activity_rail.visible = false
	activity_rail.z_index = 75
	activity_rail.anchor_left = 0.0
	activity_rail.anchor_top = 0.0
	activity_rail.anchor_right = 0.0
	activity_rail.anchor_bottom = 1.0
	activity_rail.offset_left = 10.0
	activity_rail.offset_top = 126.0
	activity_rail.offset_right = 330.0
	activity_rail.offset_bottom = -10.0
	add_child(activity_rail)

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

	if _queue_hidden_dominion_rites_pass_if_needed(human, rules):
		if phase_prompt != null:
			phase_prompt.visible = false
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

	phase_prompt.bind_state(
		human,
		bot,
		rules,
		controller,
		_stage_text()
	)

	breach_slot.bind_state(
		game,
		PlayableRoundControllerData.HUMAN_PLAYER_ID
	)

	_sync_ui2_ward_preview()
	_sync_ui2_attack_preview()
	_sync_ui2_castle_payment_preview()

	activity_rail.bind_controller(
		controller,
		_stage_text()
	)

	_refresh_tutorial_panel()

	var veil_stage_text: String = _public_phase_text()

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

	# UI2_SIEGE_ENGINE_BOMBARDMENT_FX_V1
	_queue_ui2_siege_engine_bombardment_if_needed()

# UI2_SIEGE_ENGINE_BOMBARDMENT_FX_V1
func _queue_ui2_siege_engine_bombardment_if_needed() -> void:
	if (
		controller == null
		or controller.game == null
		or siege_engine_bombardment_view == null
	):
		return

	var raw_phase = controller.phase_results.get(
		"siege_engine_fire",
		null
	)

	if typeof(raw_phase) != TYPE_DICTIONARY:
		if int(controller.game.round) <= 1:
			_ui2_siege_engine_fx_played_keys.clear()
		return

	var phase: Dictionary = raw_phase
	var fired_events: Array = []

	for raw_event in phase.get("events", []):
		if (
			typeof(raw_event) == TYPE_DICTIONARY
			and bool(raw_event.get("fired", false))
			and not String(
				raw_event.get("target_castle", "")
			).is_empty()
		):
			fired_events.append(
				raw_event.duplicate(true)
			)

	if fired_events.is_empty():
		return

	var key: String = "%d|%d" % [
		active_match_seed,
		int(controller.game.round),
	]

	if _ui2_siege_engine_fx_played_keys.has(key):
		return

	_ui2_siege_engine_fx_played_keys[key] = true

	call_deferred(
		"_play_ui2_siege_engine_bombardment",
		fired_events
	)


func _play_ui2_siege_engine_bombardment(
	fired_events: Array
) -> void:
	if (
		siege_engine_bombardment_view == null
		or not is_instance_valid(siege_engine_bombardment_view)
		or human_player_board == null
		or enemy_player_board == null
	):
		return

	# Let HBox/VBox layout settle after the just-completed refresh.
	await get_tree().process_frame

	siege_engine_bombardment_view.play_bombardment(
		fired_events,
		human_player_board,
		enemy_player_board
	)


func _queue_hidden_dominion_rites_pass_if_needed(
	human,
	rules
) -> bool:
	if (
		controller == null
		or controller.game == null
		or controller.stage
		!= PlayableRoundControllerData.Stage.DOMINION_RITES
	):
		_dominion_rites_auto_pass_pending = false
		return false

	if _human_has_actionable_dominion_rite(human, rules):
		_dominion_rites_prompt_unlocked = true
		_dominion_rites_auto_pass_pending = false
		return false

	if _dominion_rites_prompt_unlocked:
		return false

	if not _dominion_rites_auto_pass_pending:
		_dominion_rites_auto_pass_pending = true
		call_deferred("_auto_pass_hidden_dominion_rites")

	return true


func _human_has_actionable_dominion_rite(
	human,
	rules
) -> bool:
	if (
		human == null
		or rules == null
		or controller == null
		or controller.game == null
	):
		return false

	var hand_total: int = 0
	for card in human.hand:
		hand_total += int(card.value)

	var invocation_available: bool = (
		(bool(rules.invocation_repeatable) or not bool(human.cataclysmic_used))
		and int(controller.game.calculate_veil_total()) >= int(rules.invocation_gate)
		and hand_total >= int(DominionRiteEngineData.INVOCATION_PAYMENT_THRESHOLD)
	)

	var profane_available: bool = (
		not bool(human.profane_ruins_used_this_round)
		and int(human.ruined_castles.size()) >= int(rules.profane_ruins_req)
	)

	if profane_available:
		var legacy_hand_cost: int = maxi(0, int(rules.profane_ruins_card_cost))
		if legacy_hand_cost > 0:
			profane_available = hand_total >= legacy_hand_cost
		else:
			profane_available = int(human.souls) >= maxi(0, int(rules.profane_ruins_cost))

	return invocation_available or profane_available


func _auto_pass_hidden_dominion_rites() -> void:
	if not _dominion_rites_auto_pass_pending:
		return

	_dominion_rites_auto_pass_pending = false

	if (
		controller == null
		or controller.game == null
		or controller.stage != PlayableRoundControllerData.Stage.DOMINION_RITES
	):
		return

	var human = controller.get_human_player()
	if _human_has_actionable_dominion_rite(human, controller.rules):
		_dominion_rites_prompt_unlocked = true
		refresh_from_game()
		return

	var result: Dictionary = controller.resolve_human_dominion_rites({"pass": true})
	_finish_ui2_controller_step(result)


func _public_phase_text() -> String:
	if controller == null:
		return ""

	var current_stage = controller.stage

	# VALAK_PROJECTION_UI2_DEAD_END_FIX_V1_1
	if current_stage == PlayableRoundControllerData.Stage.RESOLUTION_VALAK_PROJECTION:
		return "RESOLUTION"

	if current_stage in [
		PlayableRoundControllerData.Stage.DEVELOPMENT_SNARE,
		PlayableRoundControllerData.Stage.MARKET,
		PlayableRoundControllerData.Stage.REPAIR,
		PlayableRoundControllerData.Stage.DOMINION_RITES,
		PlayableRoundControllerData.Stage.DEPLOY,
		PlayableRoundControllerData.Stage.MARCH,
		PlayableRoundControllerData.Stage.SUMMON,
	]:
		return "DEVELOPMENT"

	if current_stage in [
		PlayableRoundControllerData.Stage.COMMITMENT,
		PlayableRoundControllerData.Stage.SEALED,
	]:
		return "COMMITMENT"

	if current_stage in [
		PlayableRoundControllerData.Stage.KANIFOUS_INVOKE,
		PlayableRoundControllerData.Stage.KANIFOUS_WRIGHT,
		PlayableRoundControllerData.Stage.VULTURE_RECON,
		PlayableRoundControllerData.Stage.REVEALED,
	]:
		return "REVEAL"

	if current_stage in [
		PlayableRoundControllerData.Stage.RESOLUTION_HUMBABA_TOLL,
		PlayableRoundControllerData.Stage.RESOLUTION_ACTION,
		PlayableRoundControllerData.Stage.RESOLUTION_VESSEL,
		PlayableRoundControllerData.Stage.RESOLUTION_REFLEX,
		PlayableRoundControllerData.Stage.RESOLUTION_ODRADEK_BREACH,
		PlayableRoundControllerData.Stage.RESOLUTION_GREMORY,
	]:
		return "RESOLUTION"

	if current_stage == PlayableRoundControllerData.Stage.TERMINAL:
		return "MATCH COMPLETE"
	if current_stage == PlayableRoundControllerData.Stage.INVALID:
		return "MATCH HALTED"
	return "BETWEEN ROUNDS"


func _on_history_pressed() -> void:
	if activity_rail == null:
		return
	activity_rail.visible = not activity_rail.visible
	if history_button != null:
		history_button.text = (
			"CLOSE HISTORY"
			if activity_rail.visible
			else "HISTORY"
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

	# UI2_THEATER_PROMPT_VESSEL_TRUTH_V1
	# The phase prompt is useful while choosing an action, but it becomes visual
	# noise once ResolutionTheater takes over. Hide it for reveal/clash/impact
	# presentation; _finish_ui2_controller_step() refreshes the correct prompt.
	if (
		RESOLUTION_PRESENTATION_ENABLED
		and stage_before
		in [
			PlayableRoundControllerData.Stage.REVEALED,
			PlayableRoundControllerData.Stage.RESOLUTION_ACTION,
		]
		and phase_prompt != null
	):
		phase_prompt.visible = false

	match controller.stage:
		PlayableRoundControllerData.Stage.NO_GAME:
			queued_deploy_moves.clear()
			result = controller.advance_to_commitment()

		PlayableRoundControllerData.Stage.DEVELOPMENT_SNARE:
			result = controller.resolve_human_snare(true)

		PlayableRoundControllerData.Stage.MARKET:
			var give_cards: Array[String] = hand_view.selected_card_ids()
			if give_cards.size() != 1 or action_zone.get_primary_value().is_empty():
				action_zone.set_status("Choose exactly one Subject card from your Hand and one Slaver offer.")
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

		PlayableRoundControllerData.Stage.KALLIGAN_SCORCH:
			result = controller.resolve_human_kalligan_scorch(
				action_zone.get_primary_value()
			)

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

		PlayableRoundControllerData.Stage.RESOLUTION_VALAK_PROJECTION:
			# VALAK_PROJECTION_UI2_DEAD_END_FIX_V1_1
			var projection_value: String = action_zone.get_primary_value()
			var projection_parts: PackedStringArray = projection_value.split("|")

			if (
				projection_parts.size() != 3
				or String(projection_parts[0]) != "projection"
			):
				action_zone.set_status(
					"Choose a Projection zone and Essence spend."
				)
				return

			var projection_zone: String = String(projection_parts[1])
			var projection_spend: int = int(projection_parts[2])

			if (
				projection_zone not in ["Lord", "Castle"]
				or projection_spend <= 0
			):
				action_zone.set_status("Choose a valid Projection option.")
				return

			result = controller.resolve_human_valak_projection(
				projection_zone,
				projection_spend
			)

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

	_finish_ui2_controller_step(
		result,
		stage_before == PlayableRoundControllerData.Stage.SEALED
	)

	if (
		RESOLUTION_PRESENTATION_ENABLED
		and stage_before
		== PlayableRoundControllerData.Stage.SEALED
		and String(result.get("action", "")) == "revealed"
	):
		await _play_ui2_reveal_presentation()
		var revealed_second_half: Dictionary = (
			_ui2_battlefield_half_result(
				result,
				"march_second_half"
			)
		)
		_queue_ui2_battlefield_half(revealed_second_half)


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

	# UI2_THEATER_PROMPT_VESSEL_TRUTH_V1
	# reveal_orders() refreshes UI2 before the theater animation starts, which
	# would otherwise put the next action prompt underneath the reveal window.
	if phase_prompt != null:
		phase_prompt.visible = false

	# UI2_AFTERMATH_WARD_REVEAL_CLEANUP_V1
	# Ward/Ward has no combat collision, but the commitments are still important
	# public information. Let ResolutionTheater show both revealed orders/cards;
	# it will label the pair as defensive and omit any fake clash language.
	await resolution_theater.play_reveal(
		human,
		bot
	)

	if phase_prompt != null:
		# UI2_CONTROLLER_RULES_SCOPE_HOTFIX_V1
		phase_prompt.bind_state(
			human,
			bot,
			controller.rules,
			controller,
			_stage_text()
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
		PlayableRoundControllerData.Stage.RESOLUTION_VALAK_PROJECTION:
			result = controller.resolve_human_valak_projection(
				"",
				0
			)
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
			return "TUTORIAL · DOMINION RITES — These are optional pre-combat rites. Cataclysmic Invocation costs 11 selected Hand value. Defile the Ruins separately exchanges 2 Souls for 1 Tear and Profanes one Ruin. Passing keeps those cards for later phases."
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
		"RESOLUTION_VALAK_PROJECTION":
			return (
				"TUTORIAL · VALAK · PROJECTION — Once after primary and Reflex "
				+ "combat, spend 1–5 stored Life Essence on the enemy Lord or "
				+ "Castle Guard zone, or HOLD ESSENCE for defense. Projection "
				+ "defeats the highest Guard whose printed value is at or below "
				+ "the amount spent. Equality defeats; a miss still spends the "
				+ "Essence. Projection kills do not generate Life Essence."
			)
		"RESOLUTION_GREMORY":
			return "TUTORIAL · GREMORY · INEVITABLE RUIN — At End of Round, after Gremory's Siege deals Integrity damage to an Operational Castle and leaves it standing, discard exactly two Hand/Garrison cards totaling face value 5+ to set it to Defunct (6 Integrity). It is not Ruined. Pass to keep the cards."
		"TERMINAL":
			return "TUTORIAL · MATCH COMPLETE — A win condition has been reached. The Activity rail preserves the final sequence; use DEV / restart when you want another seed or matchup."
		"INVALID":
			return "TUTORIAL · MATCH HALTED — The controller rejected the current state or decision. Check the right-panel status and DEV snapshot if you need to diagnose the failure."
		_:
			return "TUTORIAL · CURRENT PHASE — Follow the decision on the right. This phase has no special tutorial entry yet."



# BATTLEFIELD_PLAYBACK_V1
func _ui2_battlefield_half_result(
	result: Dictionary,
	phase_name: String
) -> Dictionary:
	var raw_phases = result.get("phases", {})
	if typeof(raw_phases) != TYPE_DICTIONARY:
		return {}
	var raw_half = raw_phases.get(phase_name, {})
	return (
		raw_half
		if typeof(raw_half) == TYPE_DICTIONARY
		else {}
	)


func _ui2_battlefield_half_has_motion(
	half_result: Dictionary
) -> bool:
	if half_result.is_empty():
		return false

	var raw_events = half_result.get("events", [])
	if typeof(raw_events) == TYPE_ARRAY:
		for raw_event in raw_events:
			if typeof(raw_event) != TYPE_DICTIONARY:
				continue
			if String(raw_event.get("type", "")) in [
				"march_clash",
				"march_destroyed",
				"march_arrival",
			]:
				return true

	var raw_start = half_result.get("start_state", [])
	var raw_end = half_result.get("end_state", [])
	if typeof(raw_start) != TYPE_ARRAY or typeof(raw_end) != TYPE_ARRAY:
		return false

	var end_progress: Dictionary = {}
	for raw_row in raw_end:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue
		var unit_id: String = String(raw_row.get("id", ""))
		if not unit_id.is_empty():
			end_progress[unit_id] = float(raw_row.get("progress", 0.0))

	for raw_row in raw_start:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue
		var unit_id: String = String(raw_row.get("id", ""))
		if unit_id.is_empty() or not end_progress.has(unit_id):
			continue
		if absf(
			float(raw_row.get("progress", 0.0))
			- float(end_progress[unit_id])
		) > 0.0001:
			return true

	return false


func _ui2_battlefield_half_key(
	half_result: Dictionary
) -> String:
	if (
		controller == null
		or controller.game == null
		or half_result.is_empty()
	):
		return ""

	var half_name: String = String(
		half_result.get("half", "")
	).to_lower()
	if half_name.is_empty():
		return ""

	return "%d|%d|%s" % [
		active_match_seed,
		int(controller.game.round),
		half_name,
	]


func _queue_ui2_battlefield_half(
	half_result: Dictionary
) -> void:
	if not _ui2_battlefield_half_has_motion(half_result):
		return

	var half_key: String = _ui2_battlefield_half_key(half_result)
	if half_key.is_empty():
		return
	if _ui2_battlefield_played_half_keys.has(half_key):
		return

	# Claim immediately so later results carrying the same phase cannot replay it.
	_ui2_battlefield_played_half_keys[half_key] = true

	if _ui2_battlefield_playback_active:
		_ui2_battlefield_pending_halves.append(
			half_result.duplicate(true)
		)
		return

	# Fire-and-forget. This runs until its first await, then returns control.
	_play_ui2_battlefield_half(
		half_result.duplicate(true)
	)


func _play_next_ui2_battlefield_half_if_any() -> void:
	if (
		_ui2_battlefield_playback_active
		or _ui2_battlefield_pending_halves.is_empty()
	):
		return

	var next_half: Dictionary = (
		_ui2_battlefield_pending_halves.pop_front()
	)
	call_deferred(
		"_play_ui2_battlefield_half",
		next_half
	)


func _play_ui2_battlefield_half(
	half_result: Dictionary
) -> void:
	if (
		_ui2_battlefield_playback_active
		or marching_view == null
		or controller == null
		or controller.game == null
		or not _ui2_battlefield_half_has_motion(half_result)
	):
		return

	_ui2_battlefield_playback_active = true
	var half_name: String = String(
		half_result.get("half", "")
	).to_upper()
	_ui2_battlefield_stage_override = (
		"BATTLEFIELD · %s HALF"
		% half_name
	)

	# No modal blocker: battlefield motion is ambient presentation.
	if header_label != null:
		header_label.text = _header_text(
			controller.game,
			controller.rules
		)

	var started: bool = marching_view.begin_battlefield_playback(
		half_result
	)
	if not started:
		_ui2_battlefield_playback_active = false
		_ui2_battlefield_stage_override = ""
		_play_next_ui2_battlefield_half_if_any()
		return

	await marching_view.battlefield_playback_finished

	_ui2_battlefield_playback_active = false
	_ui2_battlefield_stage_override = ""

	# Never full-refresh when background playback ends; the player may be
	# midway through selecting cards or targets.
	_schedule_ui2_aftermath_if_needed()
	_play_next_ui2_battlefield_half_if_any()


func _set_ui2_battlefield_input_blocked(
	blocked: bool
) -> void:
	if _ui2_battlefield_input_blocker == null:
		_ui2_battlefield_input_blocker = Control.new()
		_ui2_battlefield_input_blocker.name = "BattlefieldPlaybackInputBlocker"
		_ui2_battlefield_input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
		_ui2_battlefield_input_blocker.z_index = 74
		add_child(_ui2_battlefield_input_blocker)
		_ui2_battlefield_input_blocker.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)

	_ui2_battlefield_input_blocker.visible = blocked


func _schedule_ui2_aftermath_if_needed() -> void:
	if (
		RESOLUTION_PRESENTATION_ENABLED
		and _ui2_aftermath_baseline_ready
		and controller != null
		and controller.stage
		in [
			PlayableRoundControllerData.Stage.NO_GAME,
			PlayableRoundControllerData.Stage.TERMINAL,
		]
	):
		call_deferred("_play_ui2_completed_aftermath")


func _finish_ui2_controller_step(
	result: Dictionary,
	defer_second_half_playback: bool = false
) -> void:
	var action_name: String = String(result.get("action", ""))
	if action_name == "invalid":
		action_zone.set_status(
			"Choice rejected: %s" % String(result.get("reason", "invalid_choice"))
		)
		if phase_prompt != null:
			phase_prompt.bind_state(
				controller.get_human_player(),
				controller.get_bot_player(),
				controller.rules,
				controller,
				_stage_text()
			)
		return

	if controller.stage != PlayableRoundControllerData.Stage.DEPLOY:
		queued_deploy_moves.clear()

	if phase_prompt != null:
		phase_prompt.note_controller_result(
			result
		)

	var first_half: Dictionary = _ui2_battlefield_half_result(
		result,
		"march_first_half"
	)
	_queue_ui2_battlefield_half(first_half)

	var second_half: Dictionary = _ui2_battlefield_half_result(
		result,
		"march_second_half"
	)
	if not defer_second_half_playback:
		_queue_ui2_battlefield_half(second_half)

	# Playback is background presentation. Keep the actual phase UI live.
	refresh_from_game()

	if (
		not defer_second_half_playback
		and RESOLUTION_PRESENTATION_ENABLED
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

	return {
		"invocation": (
			{"payment": invocation_ids}
			if use_invocation
			else {"pass": true}
		),
		"profane_ruins": (
			{
				"castle": action_zone.get_primary_value(),
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


func _sync_ui2_prompt_after_direct_manipulation(
	action_name: String = ""
) -> void:
	# UI2_DIRECT_MANIPULATION_SYNC_V1
	if phase_prompt == null:
		return
	if phase_prompt.has_method("sync_direct_manipulation"):
		phase_prompt.sync_direct_manipulation(action_name)

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
		_sync_ui2_prompt_after_direct_manipulation(action_name)
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
		_sync_ui2_prompt_after_direct_manipulation("Ward")
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

		var target_player = controller.game.get_player(
			1 if attacker_id == 0 else 0
		)
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
			destroyed,
			target_player
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
	var target_player = controller.game.get_player(
		1 if attacker_id == 0 else 0
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
			detail,
			target_player
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
		detail,
		target_player
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
	_record_snapshot_round_recap(context)
	resolution_theater.set_aftermath_context(context)

	# UI2_THEATER_PROMPT_VESSEL_TRUTH_V1
	if phase_prompt != null:
		phase_prompt.visible = false

	await resolution_theater.play_result("")

	# UI2_AFTERMATH_WARD_REVEAL_CLEANUP_V1
	# NO_GAME used to expose a second "THE ROUND IS SPENT" prompt after this.
	# AFTERMATH is now the single round-complete surface, so its button advances
	# directly into the next Development sequence. Match-complete Aftermath still
	# returns to the final board/terminal prompt instead.
	if controller.stage == PlayableRoundControllerData.Stage.NO_GAME:
		_ui2_aftermath_baseline_ready = false
		_ui2_aftermath_showing = false
		var next_round_result: Dictionary = controller.advance_to_commitment()
		_finish_ui2_controller_step(next_round_result)
		return

	_ui2_aftermath_baseline_ready = false
	_ui2_aftermath_showing = false

	# Terminal Aftermath returns to the final board rather than refreshing via a
	# next-round transition, so explicitly restore the terminal prompt here.
	if (
		controller.stage == PlayableRoundControllerData.Stage.TERMINAL
		and phase_prompt != null
	):
		phase_prompt.bind_state(
			controller.get_human_player(),
			controller.get_bot_player(),
			controller.rules,
			controller,
			_stage_text()
		)

# PLAYABLE_SNAPSHOT_COMPACT_ROUND_RECAP_V1
# PLAYABLE_SNAPSHOT_DEFENSE_AUDIT_V2
func _record_snapshot_round_recap(
	context: Dictionary
) -> void:
	if controller == null or controller.game == null:
		return

	var round_number: int = int(controller.game.round)

	for raw_existing in _snapshot_round_recaps:
		if (
			typeof(raw_existing) == TYPE_DICTIONARY
			and int(raw_existing.get("round", -1)) == round_number
		):
			return

	var human = controller.get_human_player()
	var bot = controller.get_bot_player()

	if human == null or bot == null:
		return

	var human_commitment: int = _snapshot_round_commitment(0)
	var bot_commitment: int = _snapshot_round_commitment(1)

	var human_before: int = int(
		context.get("human_souls_before", int(human.souls))
	)
	var human_after: int = int(
		context.get("human_souls_after", int(human.souls))
	)
	var bot_before: int = int(
		context.get("bot_souls_before", int(bot.souls))
	)
	var bot_after: int = int(
		context.get("bot_souls_after", int(bot.souls))
	)

	var human_row: Dictionary = {
		"lord": String(context.get("player_lord", human.lord)),
		"action": String(context.get("player_action", human.action)),
		"target": String(context.get("player_target", "")),
		"commitment": human_commitment,
		"outcome": String(context.get("player_outcome", "")),
	}

	var bot_row: Dictionary = {
		"lord": String(context.get("enemy_lord", bot.lord)),
		"action": String(context.get("enemy_action", bot.action)),
		"target": String(context.get("enemy_target", "")),
		"commitment": bot_commitment,
		"outcome": String(context.get("enemy_outcome", "")),
	}

	var human_state: Dictionary = _snapshot_round_player_state(human)
	var bot_state: Dictionary = _snapshot_round_player_state(bot)

	var previous_human: Dictionary = {}
	var previous_bot: Dictionary = {}

	if not _snapshot_round_recaps.is_empty():
		var previous_raw = _snapshot_round_recaps[
			_snapshot_round_recaps.size() - 1
		]

		if typeof(previous_raw) == TYPE_DICTIONARY:
			var previous: Dictionary = previous_raw
			var previous_end_raw = previous.get("end_state", {})

			if typeof(previous_end_raw) == TYPE_DICTIONARY:
				var previous_end: Dictionary = previous_end_raw
				var old_human = previous_end.get("human", {})
				var old_bot = previous_end.get("bot", {})

				if typeof(old_human) == TYPE_DICTIONARY:
					previous_human = old_human

				if typeof(old_bot) == TYPE_DICTIONARY:
					previous_bot = old_bot

	var recap: Dictionary = {
		"round": round_number,
		"human": human_row,
		"bot": bot_row,
		"souls": {
			"human_before": human_before,
			"human_after": human_after,
			"human_delta": human_after - human_before,
			"bot_before": bot_before,
			"bot_after": bot_after,
			"bot_delta": bot_after - bot_before,
		},
		"defense_audit": {
			"human": _snapshot_round_defense_audit(
				0,
				String(human_row.get("action", "")),
				human_commitment,
				previous_human,
				human_state
			),
			"bot": _snapshot_round_defense_audit(
				1,
				String(bot_row.get("action", "")),
				bot_commitment,
				previous_bot,
				bot_state
			),
		},
		"notable": _snapshot_round_notables(human, bot),
		"end_state": {
			"human": human_state,
			"bot": bot_state,
		},
	}

	recap["summary"] = _snapshot_round_summary(
		human_row,
		bot_row,
		human_before,
		human_after,
		bot_before,
		bot_after
	)

	_snapshot_round_recaps.append(recap)


func _snapshot_round_commitment(
	player_id: int
) -> int:
	if controller == null:
		return 0

	var commitment_raw = controller.phase_results.get(
		"commitment",
		{}
	)

	if typeof(commitment_raw) != TYPE_DICTIONARY:
		return 0

	var commitment: Dictionary = commitment_raw
	var result_raw = commitment.get("result", {})

	if typeof(result_raw) != TYPE_DICTIONARY:
		return 0

	var result: Dictionary = result_raw
	var players = result.get("players", [])

	if typeof(players) != TYPE_ARRAY:
		return 0

	for raw_player in players:
		if typeof(raw_player) != TYPE_DICTIONARY:
			continue

		var player_row: Dictionary = raw_player

		if int(player_row.get("player_id", -1)) == player_id:
			return int(player_row.get("committed_value", 0))

	return 0


# PLAYABLE_SNAPSHOT_DEFENSE_AUDIT_V2
func _snapshot_round_defense_audit(
	player_id: int,
	action_name: String,
	commitment_value: int,
	previous_state: Dictionary,
	current_state: Dictionary
) -> Dictionary:
	var committed_cards: int = 0
	var lord_guard_cards: int = 0
	var lord_guard_value: int = 0
	var castle_guard_cards: int = 0
	var castle_guard_value: int = 0
	var repair_cards: int = 0
	var repair_value: int = 0
	var construction_cards: int = 0
	var construction_value: int = 0

	var commitment_raw = controller.phase_results.get("commitment", {})

	if typeof(commitment_raw) == TYPE_DICTIONARY:
		var commitment: Dictionary = commitment_raw
		var result_raw = commitment.get("result", {})

		if typeof(result_raw) == TYPE_DICTIONARY:
			var result: Dictionary = result_raw
			var players = result.get("players", [])

			if typeof(players) == TYPE_ARRAY:
				for raw_player in players:
					if typeof(raw_player) != TYPE_DICTIONARY:
						continue

					var player_row: Dictionary = raw_player

					if int(
						player_row.get("player_id", -1)
					) != player_id:
						continue

					var cards = player_row.get("committed_cards", [])

					if typeof(cards) == TYPE_ARRAY:
						committed_cards = cards.size()

					break

	var deploy_raw = controller.phase_results.get("deploy", {})

	if typeof(deploy_raw) == TYPE_DICTIONARY:
		var deploy: Dictionary = deploy_raw
		var results = deploy.get("results", [])

		if typeof(results) == TYPE_ARRAY:
			for raw_result in results:
				if typeof(raw_result) != TYPE_DICTIONARY:
					continue

				var deploy_result: Dictionary = raw_result

				if int(
					deploy_result.get("player_id", -1)
				) != player_id:
					continue

				var moves = deploy_result.get("moves", [])

				if typeof(moves) != TYPE_ARRAY:
					continue

				for raw_move in moves:
					if typeof(raw_move) != TYPE_DICTIONARY:
						continue

					var move: Dictionary = raw_move
					var face_value: int = _snapshot_card_face_value(
						String(move.get("card", ""))
					)
					var target: String = String(
						move.get("target", "")
					)

					if target == "Lord":
						lord_guard_cards += 1
						lord_guard_value += face_value
					elif target == "Castle":
						castle_guard_cards += 1
						castle_guard_value += face_value

	var repair_raw = controller.phase_results.get("repair", {})

	if typeof(repair_raw) == TYPE_DICTIONARY:
		var repair: Dictionary = repair_raw
		var results = repair.get("results", [])

		if typeof(results) == TYPE_ARRAY:
			for raw_result in results:
				if typeof(raw_result) != TYPE_DICTIONARY:
					continue

				var dev_result: Dictionary = raw_result

				if int(
					dev_result.get("player_id", -1)
				) != player_id:
					continue

				var paid_cards = dev_result.get("paid_cards", [])
				var paid_count: int = 0

				if typeof(paid_cards) == TYPE_ARRAY:
					paid_count = paid_cards.size()

				var paid_value: int = int(
					dev_result.get("paid_total", 0)
				)
				var dev_action: String = String(
					dev_result.get("action", "")
				)

				if dev_action == "repair":
					repair_cards += paid_count
					repair_value += paid_value
				elif dev_action == "construct":
					construction_cards += paid_count
					construction_value += paid_value

	var ward: Dictionary = {
		"attempted": action_name == "Ward",
		"warded": false,
		"turned": false,
		"zone": "",
		"own_commitment": 0,
		"opposing_commitment": 0,
		"refunded_card": "",
	}

	var reveal_raw = controller.phase_results.get("reveal", {})

	if typeof(reveal_raw) == TYPE_DICTIONARY:
		var reveal: Dictionary = reveal_raw
		var reveal_players = reveal.get("players", [])

		if typeof(reveal_players) == TYPE_ARRAY:
			for raw_player in reveal_players:
				if typeof(raw_player) != TYPE_DICTIONARY:
					continue

				var reveal_player: Dictionary = raw_player

				if int(
					reveal_player.get("player_id", -1)
				) != player_id:
					continue

				var ward_raw = reveal_player.get("ward", {})

				if typeof(ward_raw) == TYPE_DICTIONARY:
					var ward_result: Dictionary = ward_raw
					ward["warded"] = bool(
						ward_result.get("warded", false)
					)
					ward["turned"] = bool(
						ward_result.get("turned", false)
					)
					ward["zone"] = String(
						ward_result.get("zone", "")
					)
					ward["own_commitment"] = int(
						ward_result.get(
							"own_committed_value",
							0
						)
					)
					ward["opposing_commitment"] = int(
						ward_result.get(
							"opposing_committed_value",
							0
						)
					)
					ward["refunded_card"] = String(
						ward_result.get("refunded_card", "")
					)

				break

	var generated: Dictionary = _snapshot_round_pressure_summary(
		player_id,
		true
	)
	var received: Dictionary = _snapshot_round_pressure_summary(
		player_id,
		false
	)

	var board_delta: Dictionary = {
		"available": not previous_state.is_empty(),
	}

	if not previous_state.is_empty():
		board_delta["hand_count"] = int(
			current_state.get("hand_count", 0)
		) - int(previous_state.get("hand_count", 0))
		board_delta["garrison_count"] = int(
			current_state.get("garrison_count", 0)
		) - int(previous_state.get("garrison_count", 0))
		board_delta["lord_guard_count"] = int(
			current_state.get("lord_guard_count", 0)
		) - int(previous_state.get("lord_guard_count", 0))
		board_delta["castle_guard_count"] = int(
			current_state.get("castle_guard_count", 0)
		) - int(previous_state.get("castle_guard_count", 0))
		board_delta["active_castles"] = int(
			current_state.get("active_castle_count", 0)
		) - int(previous_state.get("active_castle_count", 0))
		board_delta["castle_integrity_total"] = int(
			current_state.get("castle_integrity_total", 0)
		) - int(
			previous_state.get("castle_integrity_total", 0)
		)
		board_delta["alive_changed"] = (
			bool(current_state.get("alive", false))
			!= bool(previous_state.get("alive", false))
		)

	var ward_commitment: int = 0
	var offensive_commitment: int = 0

	if action_name == "Ward":
		ward_commitment = commitment_value
	elif action_name in ["Hunt", "Siege", "Profane"]:
		offensive_commitment = commitment_value

	return {
		"action_commitment": commitment_value,
		"committed_card_count": committed_cards,
		"offensive_commitment": offensive_commitment,
		"ward_commitment": ward_commitment,
		"guard_deploy": {
			"lord_cards": lord_guard_cards,
			"lord_face_value": lord_guard_value,
			"castle_cards": castle_guard_cards,
			"castle_face_value": castle_guard_value,
			"total_cards": lord_guard_cards + castle_guard_cards,
			"total_face_value": lord_guard_value + castle_guard_value,
		},
		"repair": {
			"cards_paid": repair_cards,
			"value_paid": repair_value,
		},
		"construction": {
			"cards_paid": construction_cards,
			"value_paid": construction_value,
		},
		# A diagnostic comparison number only, not a rules currency.
		"defense_proxy_value": (
			ward_commitment
			+ lord_guard_value
			+ castle_guard_value
			+ repair_value
		),
		"ward": ward,
		"pressure_generated": generated,
		"pressure_received": received,
		"board_delta": board_delta,
	}


func _snapshot_round_pressure_summary(
	player_id: int,
	as_attacker: bool
) -> Dictionary:
	var summary: Dictionary = {
		"resolved_actions": 0,
		"successful_actions": 0,
		"guards_defeated": 0,
		"castle_integrity_damage": 0,
		"castles_destroyed": 0,
		"lord_banished": false,
		"reported_soul_gain": 0,
	}

	var phase_raw = controller.phase_results.get("resolution", {})

	if typeof(phase_raw) != TYPE_DICTIONARY:
		return summary

	var phase: Dictionary = phase_raw
	var result_raw = phase.get("result", {})

	if typeof(result_raw) != TYPE_DICTIONARY:
		return summary

	var result: Dictionary = result_raw
	var action_events = result.get("action_events", [])

	if typeof(action_events) != TYPE_ARRAY:
		return summary

	for raw_event in action_events:
		if typeof(raw_event) != TYPE_DICTIONARY:
			continue

		var event: Dictionary = raw_event
		var action_raw = event.get("action_result", {})

		if typeof(action_raw) != TYPE_DICTIONARY:
			continue

		var action_result: Dictionary = action_raw
		var matched: bool = false

		if as_attacker:
			matched = (
				int(action_result.get("attacker_id", -1))
				== player_id
			)
		else:
			matched = (
				int(action_result.get("defender_id", -1))
				== player_id
			)

		if not matched:
			continue

		summary["resolved_actions"] = (
			int(summary["resolved_actions"]) + 1
		)

		if bool(action_result.get("won", false)):
			summary["successful_actions"] = (
				int(summary["successful_actions"]) + 1
			)

		var guards = action_result.get("guards_defeated", [])

		if typeof(guards) == TYPE_ARRAY:
			summary["guards_defeated"] = (
				int(summary["guards_defeated"]) + guards.size()
			)

		var resolved_action: String = String(
			action_result.get("action", "")
		)

		if resolved_action == "siege":
			summary["castle_integrity_damage"] = (
				int(summary["castle_integrity_damage"])
				+ int(action_result.get("structure_damage", 0))
			)

			if bool(
				action_result.get("target_destroyed", false)
			):
				summary["castles_destroyed"] = (
					int(summary["castles_destroyed"]) + 1
				)

		elif resolved_action == "hunt":
			summary["castle_integrity_damage"] = (
				int(summary["castle_integrity_damage"])
				+ int(action_result.get("keep_damage", 0))
			)

			if bool(action_result.get("banished", false)):
				summary["lord_banished"] = true

		summary["reported_soul_gain"] = (
			int(summary["reported_soul_gain"])
			+ int(action_result.get("soul_gain", 0))
		)

	return summary


func _snapshot_card_face_value(
	card_id: String
) -> int:
	if card_id.is_empty():
		return 0

	var parts: PackedStringArray = card_id.split(":")

	if parts.size() < 2:
		return 0

	return int(parts[parts.size() - 1])


func _snapshot_round_player_state(
	player
) -> Dictionary:
	var integrity_total: int = 0

	for raw_value in player.castle_integrity.values():
		integrity_total += int(raw_value)

	return {
		"lord": String(player.lord),
		"alive": bool(player.alive),
		"souls": int(player.souls),
		"tears": int(player.tears),
		"threat": int(player.threat),
		"hand_count": player.hand.size(),
		"garrison_count": player.garrison.size(),
		"lord_guard_count": player.lord_guards.size(),
		"castle_guard_count": player.castle_guards.size(),
		"active_castle_count": player.castles.size(),
		"castle_integrity_total": integrity_total,
		"castles": _snapshot_round_string_array(player.castles),
		"ruined_castles": _snapshot_round_string_array(
			player.ruined_castles
		),
		"profaned_castles": _snapshot_round_string_array(
			player.profaned_castles
		),
		"castle_integrity": player.castle_integrity.duplicate(true),
		"vacant_throne_rounds": int(player.vacant_throne_rounds),
	}


func _snapshot_round_string_array(
	values
) -> Array[String]:
	var result: Array[String] = []

	if typeof(
		values
	) != TYPE_ARRAY:
		return result

	for raw_value in values:
		result.append(
			String(
				raw_value
			)
		)

	result.sort()

	return result


func _snapshot_round_notables(
	human,
	bot
) -> Array[String]:
	var result: Array[String] = []

	for player in [
		human,
		bot,
	]:
		var lord_name: String = String(
			player.lord
		)

		if not bool(
			player.alive
		):
			result.append(
				"%s has no living Lord."
				% lord_name
			)

		if (
			player.castles.is_empty()
			and not player.castle_guards.is_empty()
		):
			result.append(
				(
					"%s ended with 0 Castles but %d Castle Guard(s)."
					% [
						lord_name,
						player.castle_guards.size(),
					]
				)
			)

		if int(
			player.vacant_throne_rounds
		) > 0:
			result.append(
				(
					"%s Vacant Throne count: %d."
					% [
						lord_name,
						int(
							player.vacant_throne_rounds
						),
					]
				)
			)

	if (
		controller != null
		and controller.game != null
		and int(
			controller.game.winner
		) >= 0
	):
		var winner = controller.game.get_player(
			int(
				controller.game.winner
			)
		)

		result.append(
			(
				"Match ended: %s by %s."
				% [
					String(
						winner.lord
					)
					if winner != null
					else "unknown",
					String(
						controller.game.win_by
					),
				]
			)
		)

	return result


func _snapshot_round_summary(
	human_row: Dictionary,
	bot_row: Dictionary,
	human_before: int,
	human_after: int,
	bot_before: int,
	bot_after: int
) -> String:
	return (
		"%s %s %d → %s — %s | %s %s %d → %s — %s | Souls %d→%d / %d→%d"
		% [
			String(
				human_row.get(
					"lord",
					"Human"
				)
			),
			String(
				human_row.get(
					"action",
					""
				)
			),
			int(
				human_row.get(
					"commitment",
					0
				)
			),
			String(
				human_row.get(
					"target",
					""
				)
			),
			String(
				human_row.get(
					"outcome",
					""
				)
			),
			String(
				bot_row.get(
					"lord",
					"Bot"
				)
			),
			String(
				bot_row.get(
					"action",
					""
				)
			),
			int(
				bot_row.get(
					"commitment",
					0
				)
			),
			String(
				bot_row.get(
					"target",
					""
				)
			),
			String(
				bot_row.get(
					"outcome",
					""
				)
			),
			human_before,
			human_after,
			bot_before,
			bot_after,
		]
	)


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
	context["match_complete"] = (
		controller.stage
		== PlayableRoundControllerData.Stage.TERMINAL
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
			if bool(action_result.get("pillage", false)):
				if bool(action_result.get("pillage_success", false)):
					summary = "PILLAGE RESOLVES · +1 SOUL"
				else:
					summary = "PILLAGE REPELLED"
			else:
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
			# PROFANE_RESOLUTION_FIZZLE_V1_7
			summary = (
				"PROFANE FIZZLES · TARGET NO LONGER FULL INTEGRITY"
				if bool(action_result.get("fizzled", false))
				else "PROFANE RESOLVES"
			)
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
						if bool(fracture_event.get("newly_revealed", false)):
							summary += " · REVEALED"
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
		_sync_ui2_prompt_after_direct_manipulation(action_name)
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

	_sync_ui2_prompt_after_direct_manipulation("deploy")

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



# UI2_SCRUM_THEATER_PRODUCTION_WIRING_V1
func _play_ui2_scrum_theater_demo() -> void:
	if (
		_ui2_scrum_theater_demo_shown
		or not RESOLUTION_PRESENTATION_ENABLED
		or resolution_theater == null
		or controller == null
		or controller.game == null
		or DisplayServer.get_name() == "headless"
	):
		return

	var vulture_texture := load(
		"res://ConceptImages/Sprites/VultureSpriteConcept.png"
	) as Texture2D
	var penitent_texture := load(
		"res://ConceptImages/Sprites/PenitentSpriteConcept.png"
	) as Texture2D
	var wright_texture := load(
		"res://ConceptImages/Sprites/WrightSpriteConcept.png"
	) as Texture2D
	var butcher_texture := load(
		"res://ConceptImages/Sprites/ButcherSpriteConcept.png"
	) as Texture2D

	if (
		vulture_texture == null
		or penitent_texture == null
		or wright_texture == null
		or butcher_texture == null
	):
		return

	var enemy_specs: Array = [
		{
			"name": "Vulture",
			"texture": vulture_texture,
			"mode": "lpc",
			"depth": 0,
			"survives": false,
		},
		{
			"name": "Butcher",
			"texture": butcher_texture,
			"mode": "standin",
			"depth": 2,
			"survives": true,
		},
		{
			"name": "Vulture",
			"texture": vulture_texture,
			"mode": "lpc",
			"depth": 4,
			"survives": false,
		},
		{
			"name": "Wright",
			"texture": wright_texture,
			"mode": "standin",
			"depth": 1,
			"survives": false,
		},
		{
			"name": "Butcher",
			"texture": butcher_texture,
			"mode": "standin",
			"depth": 3,
			"survives": true,
		},
	]

	var player_specs: Array = [
		{
			"name": "Penitent",
			"texture": penitent_texture,
			"mode": "lpc",
			"depth": 1,
			"survives": true,
		},
		{
			"name": "Wright",
			"texture": wright_texture,
			"mode": "standin",
			"depth": 3,
			"survives": false,
		},
		{
			"name": "Penitent",
			"texture": penitent_texture,
			"mode": "lpc",
			"depth": 0,
			"survives": false,
		},
		{
			"name": "Butcher",
			"texture": butcher_texture,
			"mode": "standin",
			"depth": 4,
			"survives": true,
		},
		{
			"name": "Wright",
			"texture": wright_texture,
			"mode": "standin",
			"depth": 2,
			"survives": false,
		},
	]

	_ui2_scrum_theater_demo_shown = true

	if phase_prompt != null:
		phase_prompt.visible = false

	await resolution_theater.play_scrum(
		enemy_specs,
		player_specs,
		3,
		"THE BATTLEFIELD",
		"MARCHING CLASH"
	)

	if (
		phase_prompt != null
		and controller != null
		and controller.game != null
	):
		var human = controller.get_human_player()
		var bot = controller.get_bot_player()

		if human != null and bot != null:
			phase_prompt.bind_state(
				human,
				bot,
				controller.rules,
				controller,
				_stage_text()
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
	# UI2_SCRUM_THEATER_PRODUCTION_WIRING_V1
	# Temporary one-shot stand-in presentation after a real March resolve.
	if RESOLUTION_PRESENTATION_ENABLED:
		call_deferred("_play_ui2_scrum_theater_demo")

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
			_snapshot_ui_context(),
			_snapshot_round_recaps
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
	_snapshot_round_recaps.clear()
	_ui2_battlefield_played_half_keys.clear()
	_ui2_battlefield_pending_halves.clear()
	_ui2_battlefield_playback_active = false

	active_human_lord = human_lord
	active_bot_lord = bot_lord
	active_match_seed = seed_value
	showcase_rounds = 0
	showcase_invalid_reason = ""
	queued_deploy_moves.clear()
	_dominion_rites_prompt_unlocked = false
	_dominion_rites_auto_pass_pending = false

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


# UI2_LORD_PANEL_SKIN_V1_2
func _lord_panel_texture_v1_2() -> Texture2D:
	if _ui2_lord_panel_texture_v1_2 != null:
		return _ui2_lord_panel_texture_v1_2

	var image := Image.new()
	var load_error: Error = image.load(
		UI2_LORD_PANEL_PATH
	)

	if load_error != OK:
		push_warning(
			"LordPanel v1.2: could not load %s (error %d)"
			% [
				UI2_LORD_PANEL_PATH,
				int(load_error),
			]
		)
		return null

	if image.is_empty():
		push_warning(
			"LordPanel v1.2: loaded image is empty: %s"
			% UI2_LORD_PANEL_PATH
		)
		return null

	_ui2_lord_panel_texture_v1_2 = (
		ImageTexture.create_from_image(image)
	)

	return _ui2_lord_panel_texture_v1_2


func _install_lord_panel_skin_v1_2(
	panel: PanelContainer,
	tint: Color,
	art_name: String
) -> void:
	if panel == null:
		return

	var panel_texture := _lord_panel_texture_v1_2()
	if panel_texture == null:
		return

	# LordPanel art supplies the visible frame.
	var transparent := StyleBoxFlat.new()
	transparent.bg_color = Color(
		0.0,
		0.0,
		0.0,
		0.0
	)
	transparent.border_color = Color(
		0.0,
		0.0,
		0.0,
		0.0
	)
	transparent.set_border_width_all(0)

	# Keep live PlayerPuck text safely inside the ornamental edge.
	transparent.content_margin_left = 8.0
	transparent.content_margin_right = 8.0
	transparent.content_margin_top = 6.0
	transparent.content_margin_bottom = 6.0

	panel.add_theme_stylebox_override(
		"panel",
		transparent
	)

	var art := panel.get_node_or_null(
		art_name
	) as TextureRect

	if art == null:
		art = TextureRect.new()
		art.name = art_name
		art.texture = panel_texture
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_SCALE
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.self_modulate = tint

		panel.add_child(art)
		panel.move_child(
			art,
			0
		)

	art.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	art.offset_left = 0.0
	art.offset_top = 0.0
	art.offset_right = 0.0
	art.offset_bottom = 0.0
	art.self_modulate = tint
