extends Control


const PlayableRoundControllerData = preload(
	"res://Prototype/PlayableRoundController.gd"
)

const SiegeResolutionEngineData = preload(
	"res://Scripts/Sim/SiegeResolutionEngine.gd"
)

const SummonEngineData = preload(
	"res://Scripts/Sim/SummonEngine.gd"
)

const DeployEngineData = preload(
	"res://Scripts/Sim/DeployEngine.gd"
)

const RoundEngineData = preload(
	"res://Scripts/Sim/RoundEngine.gd"
)

const PlayableMatchSnapshotData = preload(
	"res://Scripts/Sim/PlayableMatchSnapshot.gd"
)


const LORDS: Array[String] = [
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

const ACTIONS: Array[String] = [
	"Hunt",
	"Siege",
	"Ward",
	"Profane",
]

const DEFAULT_SEED: int = 20260724

const LORD_CARD_ABILITIES: Dictionary = {
	"Orias": [
		"[b]Snare[/b] — During Development, if Orias is living and below Threat 3, gain 1 Threat and restrict an opponent with 2+ Hand/Garrison cards to one Deploy move.",
		"[b]Relentless Pursuit[/b] — Hunts gain +1 strength, plus another +1 against a Lord at Threat 2+.",
		"[b]The Mark[/b] — Defeating a Lord Guard raises that Lord's Threat (2 at Threat 2+). Banishing a Lord at Threat 3+ grants +2 bonus Souls and marks it; it returns with +1 Threat. Orias bypasses that marked target's Recoil/Backwash.",
		"[b]Breach: Frenzy[/b] — Players at Threat 3+ cannot Deploy cards from Garrison to Guard zones.",
	],
	"Deimos": [
		"[b]War Machine[/b] — Sieges gain +2 strength, reduced by 1 for each of Deimos's Ruined or Profaned Castles (minimum +0).",
		"[b]Fear[/b] — Before a Siege against 2+ Castle Guards, return the lowest Guard to its owner's Hand.",
		"[b]Claim the Breach[/b] — The first Castle Deimos ruins each game gives Deimos the Tear instead of adding a Neutral Tear.",
		"[b]Breach[/b] — Every active Castle has 1 less structural DEF (minimum 0).",
	],
	"Valak": [
		"[b]Crushing Presence[/b] — On Hunt or Siege against 2+ Guards, the lowest Guard contributes no defense.",
		"[b]Siphon[/b] — After Valak defeats a Guard, discard the lowest Guard still protecting that same zone.",
		"[b]Breach: Gravitational Collapse[/b] — At Resolution Prelude, each previously attacked zone loses its lowest Guard.",
	],
	"Kroni": [
		"[b]Consume / Gorge[/b] — At End of Round, if any destruction occurred, gain 1 Hunger. If Kroni personally defeated a Guard that round, also gain 1 Soul.",
		"[b]Hunger[/b] — Lord DEF is 4 at 0 Hunger, 6 at 1–2, and 8 at 3+. Reaching 3 for the first time after a Summon grants a personal Tear.",
		"[b]Hungering Aura / Ravenous[/b] — At Hunger 3+, discard the opponent's lowest committed card. Kroni's next destroyed Lord/Castle grants +2 Souls and +1 Hunger.",
		"[b]Fallback / Decay / Breach[/b] — If Consume did not fire, remove the lowest Guard or Garrison card from play. Ward/Pass loses 1 Hunger. Kroni Breach destroys each player's lowest Guard.",
	],
	"Kalligan": [
		"[b]Forge-Repair[/b] — Kalligan's first Repair costs 7 less; later Repairs cost 5 less. Every living Kalligan Repair Scorches the enemy Lord zone.",
		"[b]Pyroclasm[/b] — Sieges gain +1 strength, or +2 if the defender already has a Ruined Castle.",
		"[b]Inferno / Wildfire[/b] — After ruining a Castle, Wildfire Scorches the enemy Castle zone (or Lord if none remain). Kalligan may gain 1 Threat to Defeat the highest enemy Lord Guard without response triggers; if none exists, Inferno replaces that token with Lord Scorch.",
		"[b]Breach[/b] — All Repairs cost 1 less.",
	],
	"Gremory": [
		"[b]Picking the Bones[/b] — During Development draw 1 extra card, +1 if either player has a Ruin, and +1 more if Gremory has a Ruin.",
		"[b]Ruinous Harvest[/b] — On the first Tear placed each round, search from the top of the discard for a value-4/5 card and take it. The attempt is spent even if no eligible card exists.",
		"[b]Predator of Ruin[/b] — The first Castle destroyed each round recovers the top discard. Independently, the first Lord Guard Defeated by any effect lets Gremory draw 1 outside the Draw step, then discard the lowest Hand card.",
		"[b]Inevitable Ruin / Breach[/b] — Once per round, after a Siege leaves its target standing, pay exactly 2 Hand/Garrison cards to ruin it. During Gremory Breach, players with a Ruin draw 1 extra.",
	],
	"Odradek": [
		"[b]Psychic Recoil / Interlock[/b] — Once each round when living Odradek is Hunted or Sieged, take the attacker's second-highest committed card and bank it face-up, gaining 1 Soul. A new card replaces the bank only if strictly larger; otherwise Recoil locks. Odradek automatically spends the bank on his next Hunt or Siege.",
		"[b]Reconfiguration[/b] — If fewer than 2 Odradek Guards were Defeated this round, gain 1 token. At 3 tokens, spend them to place 1 Neutral Tear. Banishment clears tokens.",
		"[b]Breach: Paradox Geometry[/b] — Predict the second-action winner's action; a correct guess discards their selected cards and lets Odradek execute it instead.",
	],
	"Kanifous": [
		"[b]Invoke[/b] — After Reveal, discard one Hand card as the toll, reveal 2 cards, choose one to bank in Garrison, and discard the other. With no Hand card, Invoke does not fire and the reveals return to the deck.",
		"[b]Suit Invocation[/b] — Vulture: draw 3 then discard the lowest Hand card. Wright: move up to 2 Lord Guards to Castle. Penitent: draw 2 temporary Guards. Butcher: treat the lowest target Guard as already Defeated this round, without triggering Defeat effects.",
		"[b]Resonance / Defiance[/b] — If the chosen card's value equals current Threat, gain 1 Soul. A value-4+ first reveal creates a Neutral Tear. When Kanifous is banished, gain 1 Soul and draw 2 if still behind the attacker.",
		"[b]Breach[/b] — Every draw outside the Draw step gives its recipient +1 Threat.",
	],
	"Humbaba": [
		"[b]Woven Into the Stones[/b] — Lord DEF equals 2 + active Castles; Bastion adds its usual +2, and Threat reductions still apply.",
		"[b]Toll[/b] — Once per round under severe Soul pressure, ruin one of Humbaba's own Castles to remove 1 enemy Soul and create 1 Neutral Tear.",
		"[b]Reactive Lane[/b] — Humbaba may hold a second marcher only as a response. An enemy marcher must already occupy the lane, and the new marcher is forced into it; Humbaba cannot open two attacks.",
		"[b]Breach: The Stones Forget[/b] — While Humbaba is Banished, every active Castle has 1 less structural DEF (minimum 1).",
	],
}


const UI_EXPLANATION_PATCH_VERSION: String = "ui-explanations-v1"

const VEIL_COLLAPSE_THRESHOLD: int = 7
const VEIL_WANING_THRESHOLD: int = 9

const SOULS_LABEL: String = (
	"[hint=SOULS — Ritual score. Reach the displayed target to win. "
	+ "Common gains include ruining enemy Castles, Banishing enemy Lords, "
	+ "destroying enemy marchers, surviving attacks behind a Ward, and Lord abilities.]"
	+ "Souls[/hint]"
)

const TEARS_LABEL: String = (
	"[hint=TEARS — Personal Dominion score. Common gains include Profane Ruins, "
	+ "Cataclysmic Invocation, Offer the Vessel, Consume the Hunt, marching a Guard "
	+ "through the enemy gate, and Lord abilities. Neutral Tears advance the Veil "
	+ "but belong to neither player.]Tears[/hint]"
)

const THREAT_LABEL: String = (
	"[hint=THREAT — Lord instability from 0 to 4. At Threat 2, 3, and 4, "
	+ "Lord DEF is reduced by 1, 2, and 3. Several Lord powers also check Threat, "
	+ "and game effects may raise or lower it.]Threat[/hint]"
)

const CASTLES_LABEL: String = (
	"[hint=CASTLES — Active Castles grant their printed abilities. Ruined Castles "
	+ "can be repaired. Profaned or permanently lost Castles cannot return. "
	+ "Repairing adds a scar that reduces future structural DEF by 2; destroying "
	+ "a scarred Castle can permanently lose it.]Castles[/hint]"
)

const CASTLE_HELP: Dictionary = {
	"Keep": (
		"KEEP — Base structural DEF 13. While active, your Ward and Sigil value "
		+ "is increased by 1."
	),
	"Bastion": (
		"BASTION — Base structural DEF 11. While active, your Lord gains 2 DEF."
	),
	"SummoningCircle": (
		"SUMMONING CIRCLE — Base structural DEF 9. While active, your Lord costs "
		+ "2 less total card value to Summon."
	),
	"Stockpile": (
		"STOCKPILE — Base structural DEF 8. While active, draw 1 additional card "
		+ "during the normal Draw step."
	),
	"SiegeEngine": (
		"SIEGE ENGINE — Base structural DEF 7. While active, your Sieges bypass "
		+ "the target Castle's structural DEF. It also enables Deimos's War Machine."
	),
}


const MARCH_TRACK_STEPS: int = 3
const MARCH_LANES: Array[String] = [
	"Lord",
	"Castle",
]


var controller = null

var human_lord_select: OptionButton = null
var bot_lord_select: OptionButton = null
var seed_edit: LineEdit = null
var new_match_button: Button = null

var round_label: Label = null
var phase_label: Label = null
var veil_label: Label = null
var breach_label: Label = null

var bot_state_label: RichTextLabel = null
var human_state_label: RichTextLabel = null
var bot_lord_card_label: RichTextLabel = null
var human_lord_card_label: RichTextLabel = null
var reveal_label: RichTextLabel = null
var event_log: RichTextLabel = null
var dominion_track_label: RichTextLabel = null
var dominion_progress: ProgressBar = null
var market_staging_labels: Array[RichTextLabel] = []
var market_staging_panels: Array[PanelContainer] = []
var human_staging_label: RichTextLabel = null
var bot_staging_label: RichTextLabel = null

var action_buttons: Dictionary = {}
var target_label: Label = null
var target_select: OptionButton = null
var secondary_target_label: Label = null
var secondary_target_select: OptionButton = null
var target_info_label: RichTextLabel = null
var hand_flow: HFlowContainer = null
var hand_caption_label: Label = null
var card_buttons: Array[Button] = []
var selection_label: Label = null

var confirm_button: Button = null
var summon_button: Button = null
var skip_summon_button: Button = null
var reveal_button: Button = null
var resolve_button: Button = null
var next_round_button: Button = null
var development_option_button: Button = null
var development_finish_button: Button = null
var debug_export_button: Button = null

var setup_row: Control = null
var board_row: Control = null
var marching_board_panel: Control = null
var interaction_panel: Control = null
var footer_row: Control = null

var march_status_label: Label = null
var march_lane_title_labels: Dictionary = {}
var march_gate_labels: Dictionary = {}
var march_slot_labels: Dictionary = {}
var march_slot_panels: Dictionary = {}

var selected_action: String = ""
var active_match_seed: int = -1
var log_entries: Array[String] = []
var reported_development_phases: Dictionary = {}
var queued_deploy_moves: Array[Dictionary] = []
var deploy_target_zone: String = "Lord"
var resolution_start_digest: Dictionary = {}


func _ready() -> void:
	controller = PlayableRoundControllerData.new()

	_build_interface()

	get_viewport().size_changed.connect(
		_on_viewport_size_changed
	)

	_start_new_match()


func _build_interface() -> void:
	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	var background := ColorRect.new()
	background.color = Color(
		0.035,
		0.027,
		0.045,
		1.0
	)
	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(
		background
	)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	margin.add_theme_constant_override(
		"margin_left",
		18
	)
	margin.add_theme_constant_override(
		"margin_top",
		14
	)
	margin.add_theme_constant_override(
		"margin_right",
		18
	)
	margin.add_theme_constant_override(
		"margin_bottom",
		14
	)
	add_child(
		margin
	)

	var page := VBoxContainer.new()
	page.add_theme_constant_override(
		"separation",
		10
	)
	margin.add_child(
		page
	)

	setup_row = _build_setup_row()
	page.add_child(
		setup_row
	)

	var clock_panel := _new_panel(
		Color(
			0.09,
			0.07,
			0.12,
			1.0
		)
	)
	page.add_child(
		clock_panel
	)

	var clock_row := HBoxContainer.new()
	clock_row.add_theme_constant_override(
		"separation",
		24
	)
	clock_panel.add_child(
		clock_row
	)

	round_label = _new_label(
		"Round —",
		18
	)
	phase_label = _new_label(
		"Awaiting match",
		18
	)
	phase_label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	veil_label = _new_label(
		"Veil —",
		18
	)
	breach_label = _new_label(
		"Breach —",
		18
	)

	clock_row.add_child(
		round_label
	)
	clock_row.add_child(
		phase_label
	)
	clock_row.add_child(
		veil_label
	)
	clock_row.add_child(
		breach_label
	)

	board_row = _build_board_row()
	board_row.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	page.add_child(
		board_row
	)

	marching_board_panel = _build_marching_board()
	page.add_child(
		marching_board_panel
	)

	interaction_panel = _build_interaction_panel()
	page.add_child(
		interaction_panel
	)

	footer_row = _build_footer_row()
	page.add_child(
		footer_row
	)


func _build_setup_row() -> Control:
	var panel := _new_panel(
		Color(
			0.12,
			0.08,
			0.15,
			1.0
		)
	)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(
		"separation",
		10
	)
	panel.add_child(
		row
	)

	var title := _new_label(
		"CORRUPTOR — PLAYABLE PROTOTYPE",
		22
	)
	title.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	row.add_child(
		title
	)

	row.add_child(
		_new_label(
			"You:",
			16
		)
	)

	human_lord_select = OptionButton.new()
	human_lord_select.custom_minimum_size = Vector2(
		145,
		40
	)
	row.add_child(
		human_lord_select
	)

	row.add_child(
		_new_label(
			"Bot:",
			16
		)
	)

	bot_lord_select = OptionButton.new()
	bot_lord_select.custom_minimum_size = Vector2(
		145,
		40
	)
	row.add_child(
		bot_lord_select
	)

	for lord_name: String in LORDS:
		human_lord_select.add_item(
			lord_name
		)
		bot_lord_select.add_item(
			lord_name
		)

	human_lord_select.select(
		LORDS.find(
			"Orias"
		)
	)
	bot_lord_select.select(
		LORDS.find(
			"Valak"
		)
	)

	row.add_child(
		_new_label(
			"Seed:",
			16
		)
	)

	seed_edit = LineEdit.new()
	seed_edit.custom_minimum_size = Vector2(
		125,
		40
	)
	seed_edit.text = str(
		DEFAULT_SEED
	)
	seed_edit.placeholder_text = "integer seed"
	row.add_child(
		seed_edit
	)

	new_match_button = _new_button(
		"New Match",
		130
	)
	new_match_button.pressed.connect(
		_start_new_match
	)
	row.add_child(
		new_match_button
	)

	return panel


func _build_board_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(
		"separation",
		10
	)

	var bot_panel := _new_panel(
		Color(
			0.16,
			0.07,
			0.09,
			1.0
		)
	)
	bot_panel.custom_minimum_size = Vector2(
		290,
		290
	)
	bot_panel.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	row.add_child(
		bot_panel
	)

	var bot_box := VBoxContainer.new()
	bot_panel.add_child(
		bot_box
	)
	bot_box.add_child(
		_new_label(
			"OPPONENT",
			19
		)
	)
	bot_state_label = _new_rich_text()
	bot_state_label.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	bot_box.add_child(
		bot_state_label
	)
	var bot_card_panel := _new_lord_card_panel()
	bot_lord_card_label = (
		bot_card_panel.get_meta(
			"card_label"
		) as RichTextLabel
	)
	bot_box.add_child(
		bot_card_panel
	)

	var center_panel := _new_panel(
		Color(
			0.075,
			0.06,
			0.095,
			1.0
		)
	)
	center_panel.custom_minimum_size = Vector2(
		480,
		330
	)
	center_panel.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	row.add_child(
		center_panel
	)

	var center_box := VBoxContainer.new()
	center_box.add_theme_constant_override(
		"separation",
		6
	)
	center_panel.add_child(
		center_box
	)

	var staging_header := _new_label(
		"STAGING AREA",
		19
	)
	center_box.add_child(
		staging_header
	)

	dominion_track_label = _new_rich_text()
	dominion_track_label.custom_minimum_size = Vector2(
		0,
		58
	)
	dominion_track_label.add_theme_font_size_override(
		"normal_font_size",
		13
	)
	dominion_track_label.add_theme_font_size_override(
		"bold_font_size",
		13
	)
	center_box.add_child(
		dominion_track_label
	)

	dominion_progress = ProgressBar.new()
	dominion_progress.custom_minimum_size = Vector2(
		0,
		18
	)
	dominion_progress.show_percentage = false
	center_box.add_child(
		dominion_progress
	)

	center_box.add_child(
		_new_label(
			"MARKET — PUBLIC OFFERS",
			14
		)
	)

	var market_row := HBoxContainer.new()
	market_row.add_theme_constant_override(
		"separation",
		6
	)
	center_box.add_child(
		market_row
	)

	for market_index: int in range(3):
		var market_panel := _new_panel(
			Color(
				0.08,
				0.09,
				0.13,
				1.0
			)
		)
		market_panel.custom_minimum_size = Vector2(
			0,
			46
		)
		market_panel.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)
		var market_label := _new_rich_text()
		market_label.custom_minimum_size = Vector2(
			0,
			34
		)
		market_label.add_theme_font_size_override(
			"normal_font_size",
			12
		)
		market_label.add_theme_font_size_override(
			"bold_font_size",
			12
		)
		market_label.scroll_active = false
		market_panel.add_child(
			market_label
		)
		market_staging_labels.append(
			market_label
		)
		market_staging_panels.append(
			market_panel
		)
		market_row.add_child(
			market_panel
		)

	center_box.add_child(
		_new_label(
			"ORDERS IN STAGING",
			14
		)
	)

	var orders_row := HBoxContainer.new()
	orders_row.add_theme_constant_override(
		"separation",
		6
	)
	center_box.add_child(
		orders_row
	)

	var human_order_panel := _new_panel(
		Color(
			0.055,
			0.12,
			0.095,
			1.0
		)
	)
	human_order_panel.custom_minimum_size = Vector2(
		0,
		50
	)
	human_order_panel.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	human_staging_label = _new_staging_order_label()
	human_order_panel.add_child(
		human_staging_label
	)
	orders_row.add_child(
		human_order_panel
	)

	var bot_order_panel := _new_panel(
		Color(
			0.14,
			0.06,
			0.08,
			1.0
		)
	)
	bot_order_panel.custom_minimum_size = Vector2(
		0,
		50
	)
	bot_order_panel.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	bot_staging_label = _new_staging_order_label()
	bot_order_panel.add_child(
		bot_staging_label
	)
	orders_row.add_child(
		bot_order_panel
	)

	reveal_label = _new_rich_text()
	reveal_label.custom_minimum_size = Vector2(
		0,
		54
	)
	reveal_label.add_theme_font_size_override(
		"normal_font_size",
		13
	)
	reveal_label.add_theme_font_size_override(
		"bold_font_size",
		13
	)
	center_box.add_child(
		reveal_label
	)

	center_box.add_child(
		_new_label(
			"MATCH LOG",
			16
		)
	)

	event_log = _new_rich_text()
	event_log.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	event_log.custom_minimum_size = Vector2(
		0,
		46
	)
	event_log.scroll_following = true
	center_box.add_child(
		event_log
	)

	var human_panel := _new_panel(
		Color(
			0.055,
			0.13,
			0.105,
			1.0
		)
	)
	human_panel.custom_minimum_size = Vector2(
		290,
		290
	)
	human_panel.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	row.add_child(
		human_panel
	)

	var human_box := VBoxContainer.new()
	human_panel.add_child(
		human_box
	)
	human_box.add_child(
		_new_label(
			"YOU",
			19
		)
	)
	human_state_label = _new_rich_text()
	human_state_label.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	human_box.add_child(
		human_state_label
	)
	var human_card_panel := _new_lord_card_panel()
	human_lord_card_label = (
		human_card_panel.get_meta(
			"card_label"
		) as RichTextLabel
	)
	human_box.add_child(
		human_card_panel
	)

	return row


func _build_marching_board() -> Control:
	var panel := _new_panel(
		Color(
			0.075,
			0.08,
			0.12,
			1.0
		)
	)
	panel.custom_minimum_size = Vector2(
		0,
		168
	)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(
		"separation",
		5
	)
	panel.add_child(
		box
	)

	var header := HBoxContainer.new()
	header.add_theme_constant_override(
		"separation",
		12
	)
	box.add_child(
		header
	)

	var title := _new_label(
		"MARCHING ORDERS — LIVE LANES",
		17
	)
	title.custom_minimum_size = Vector2(
		245,
		0
	)
	header.add_child(
		title
	)

	march_status_label = _new_label(
		"No marchers in flight.",
		13
	)
	march_status_label.modulate = Color(
		0.78,
		0.75,
		0.84,
		1.0
	)
	march_status_label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	march_status_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT
	)
	header.add_child(
		march_status_label
	)

	var legend := _new_label(
		"YOUR GUARDS → step 1 · step 2 · enemy gate (step 3)    •    OPPONENT GUARDS mirror ←\nRPS: Wright > Penitent > Vulture > Butcher > Wright    •    advantage +1 clash damage",
		12
	)
	legend.modulate = Color(
		0.68,
		0.67,
		0.76,
		1.0
	)
	box.add_child(
		legend
	)

	for lane: String in MARCH_LANES:
		var lane_row := HBoxContainer.new()
		lane_row.add_theme_constant_override(
			"separation",
			6
		)
		box.add_child(
			lane_row
		)

		var lane_title := _new_label(
			"%s LANE" % lane.to_upper(),
			14
		)
		lane_title.custom_minimum_size = Vector2(
			112,
			48
		)
		march_lane_title_labels[lane] = lane_title
		lane_row.add_child(
			lane_title
		)

		var human_gate := _new_march_board_label()
		human_gate.custom_minimum_size = Vector2(
			150,
			48
		)
		march_gate_labels[_march_gate_key(lane, true)] = human_gate
		lane_row.add_child(
			human_gate
		)

		for step: int in range(1, MARCH_TRACK_STEPS + 1):
			var slot_panel := _new_panel(
				Color(
					0.055,
					0.065,
					0.095,
					1.0
				)
			)
			slot_panel.custom_minimum_size = Vector2(
				100,
				48
			)
			slot_panel.size_flags_horizontal = (
				Control.SIZE_EXPAND_FILL
			)
			var slot_label := _new_march_board_label()
			slot_panel.add_child(
				slot_label
			)
			var slot_key: String = _march_slot_key(lane, step)
			march_slot_labels[slot_key] = slot_label
			march_slot_panels[slot_key] = slot_panel
			lane_row.add_child(
				slot_panel
			)

		var bot_gate := _new_march_board_label()
		bot_gate.custom_minimum_size = Vector2(
			150,
			48
		)
		march_gate_labels[_march_gate_key(lane, false)] = bot_gate
		lane_row.add_child(
			bot_gate
		)

	return panel


func _new_march_board_label() -> RichTextLabel:
	var label := _new_rich_text()
	label.custom_minimum_size = Vector2(
		0,
		42
	)
	label.add_theme_font_size_override(
		"normal_font_size",
		12
	)
	label.add_theme_font_size_override(
		"bold_font_size",
		12
	)
	label.scroll_active = false
	return label


func _new_staging_order_label() -> RichTextLabel:
	var label := _new_rich_text()
	label.custom_minimum_size = Vector2(
		0,
		38
	)
	label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	label.add_theme_font_size_override(
		"normal_font_size",
		12
	)
	label.add_theme_font_size_override(
		"bold_font_size",
		12
	)
	label.scroll_active = false
	return label


func _build_interaction_panel() -> Control:
	var panel := _new_panel(
		Color(
			0.105,
			0.085,
			0.13,
			1.0
		)
	)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(
		"separation",
		7
	)
	panel.add_child(
		box
	)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override(
		"separation",
		7
	)
	box.add_child(
		action_row
	)

	action_row.add_child(
		_new_label(
			"Order:",
			17
		)
	)

	for action_name: String in ACTIONS:
		var button := _new_button(
			action_name,
			105
		)
		button.toggle_mode = true
		button.pressed.connect(
			_on_action_selected.bind(
				action_name
			)
		)
		action_buttons[action_name] = button
		action_row.add_child(
			button
		)

	target_label = _new_label(
		"Target:",
		17
	)
	action_row.add_child(
		target_label
	)

	target_select = OptionButton.new()
	target_select.custom_minimum_size = Vector2(
		220,
		40
	)
	target_select.item_selected.connect(
		_on_target_selected
	)
	action_row.add_child(
		target_select
	)

	secondary_target_label = _new_label("", 17)
	secondary_target_label.visible = false
	action_row.add_child(secondary_target_label)

	secondary_target_select = OptionButton.new()
	secondary_target_select.custom_minimum_size = Vector2(190, 40)
	secondary_target_select.visible = false
	secondary_target_select.item_selected.connect(_on_secondary_target_selected)
	action_row.add_child(secondary_target_select)

	selection_label = _new_label(
		"Select an order.",
		16
	)
	selection_label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	selection_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT
	)
	action_row.add_child(
		selection_label
	)

	target_info_label = _new_rich_text()
	target_info_label.custom_minimum_size = Vector2(
		0,
		30
	)
	target_info_label.fit_content = true
	box.add_child(
		target_info_label
	)

	hand_caption_label = _new_label(
		"Commit cards (click to select):",
		16
	)
	box.add_child(
		hand_caption_label
	)

	var hand_scroll := ScrollContainer.new()
	hand_scroll.custom_minimum_size = Vector2(
		0,
		78
	)
	hand_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO
	)
	hand_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	box.add_child(
		hand_scroll
	)

	hand_flow = HFlowContainer.new()
	hand_flow.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	hand_flow.add_theme_constant_override(
		"h_separation",
		7
	)
	hand_flow.add_theme_constant_override(
		"v_separation",
		7
	)
	hand_scroll.add_child(
		hand_flow
	)

	return panel


func _build_footer_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(
		"separation",
		8
	)

	summon_button = _new_button(
		"Resummon Lord",
		165
	)
	summon_button.pressed.connect(
		_on_summon_pressed
	)
	row.add_child(
		summon_button
	)

	skip_summon_button = _new_button(
		"Remain Banished",
		175
	)
	skip_summon_button.pressed.connect(
		_on_skip_summon_pressed
	)
	row.add_child(
		skip_summon_button
	)

	confirm_button = _new_button(
		"Seal Order",
		150
	)
	confirm_button.pressed.connect(
		_on_confirm_pressed
	)
	row.add_child(
		confirm_button
	)

	reveal_button = _new_button(
		"Reveal Orders",
		160
	)
	reveal_button.pressed.connect(
		_on_reveal_pressed
	)
	row.add_child(
		reveal_button
	)

	resolve_button = _new_button(
		"Resolve Round",
		160
	)
	resolve_button.pressed.connect(
		_on_resolve_pressed
	)
	row.add_child(
		resolve_button
	)

	next_round_button = _new_button(
		"Next Round",
		150
	)
	next_round_button.pressed.connect(
		_on_next_round_pressed
	)
	row.add_child(
		next_round_button
	)

	development_option_button = _new_button(
		"",
		170
	)
	development_option_button.toggle_mode = true
	development_option_button.pressed.connect(
		_on_development_option_pressed
	)
	row.add_child(
		development_option_button
	)

	development_finish_button = _new_button(
		"",
		170
	)
	development_finish_button.pressed.connect(
		_on_development_finish_pressed
	)
	row.add_child(
		development_finish_button
	)

	debug_export_button = _new_button(
		"Export Match Snapshot",
		185
	)
	debug_export_button.tooltip_text = (
		"Write the live game, staged decisions, resolution data, and RNG state to JSON."
	)
	debug_export_button.pressed.connect(
		_on_export_match_snapshot_pressed
	)
	row.add_child(
		debug_export_button
	)

	var note := _new_label(
		"Development decisions are yours; the opponent responds under bot doctrine.",
		15
	)
	note.modulate = Color(
		0.75,
		0.72,
		0.8,
		1.0
	)
	note.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT
	)
	note.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	row.add_child(
		note
	)

	return row


func _start_new_match() -> void:
	var seed_value: int = _validated_seed()
	active_match_seed = seed_value
	var human_lord: String = (
		human_lord_select.get_item_text(
			human_lord_select.selected
		)
	)
	var bot_lord: String = (
		bot_lord_select.get_item_text(
			bot_lord_select.selected
		)
	)

	log_entries.clear()
	reported_development_phases.clear()
	queued_deploy_moves.clear()
	event_log.clear()

	_log(
		"[b]New match[/b] — %s vs %s, seed %d."
		% [
			human_lord,
			bot_lord,
			seed_value,
		]
	)
	_log(
		"[color=#c8b36a][b]Experimental bot doctrine:[/b] FIX A is active — Hunt/Siege/Ward bases are equalized and Ward's unconditional Soul/Castle/Threat valuation is reduced.[/color]"
	)

	var result: Dictionary = controller.start_match(
		human_lord,
		bot_lord,
		seed_value
	)

	_after_development(
		result
	)


func _on_export_match_snapshot_pressed() -> void:
	var stage_name: String = _snapshot_stage_name()
	var result: Dictionary = PlayableMatchSnapshotData.export_current_match(
		controller,
		active_match_seed,
		stage_name,
		log_entries
	)

	if not bool(result.get("ok", false)):
		var reason: String = String(result.get("reason", "snapshot_export_failed"))
		_set_phase_message("Snapshot export failed: %s" % reason)
		_log("[color=#ff748f][b]Snapshot export failed:[/b] %s[/color]" % reason)
		return

	var path: String = String(result.get("path", ""))
	_set_phase_message("Snapshot exported — see Match Log for the file path.")
	_log("[color=#82c9ff][b]Snapshot exported:[/b] %s[/color]" % path)


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


func _on_next_round_pressed() -> void:
	var result: Dictionary = (
		controller.advance_to_commitment()
	)

	_after_development(
		result
	)


func _after_development(
	result: Dictionary
) -> void:
	selected_action = ""
	_clear_action_toggles()
	_clear_reveal()
	queued_deploy_moves.clear()
	_log_new_development_activity()

	if _show_failure_if_needed(
		result
	):
		return

	if bool(
		result.get(
			"terminal",
			false
		)
	):
		_show_terminal()
		return

	if controller.stage == PlayableRoundControllerData.Stage.DEVELOPMENT_SNARE:
		_enter_development_choice("Orias Snare — gain 1 Threat to limit the opponent to one Deploy move, or pass.")
		return

	if controller.stage == PlayableRoundControllerData.Stage.MARKET:
		_enter_development_choice("Market — trade one Hand card for one Market card, or pass.")
		return

	if controller.stage == PlayableRoundControllerData.Stage.REPAIR:
		_enter_development_choice("Repair — restore one Ruined Castle, or pass.")
		return

	if controller.stage == PlayableRoundControllerData.Stage.DOMINION_RITES:
		_enter_development_choice("Dominion Rites — Invocation and Profane Ruins may both be used when legal.")
		return

	if controller.stage == PlayableRoundControllerData.Stage.DEPLOY:
		_begin_deploy_guard_picker()
		return

	if controller.stage == PlayableRoundControllerData.Stage.MARCH:
		_begin_march_picker()
		return

	if controller.stage == PlayableRoundControllerData.Stage.SUMMON:
		_log(
			"Round %d: your Lord is banished. Select cards worth at least %d to resummon, or remain banished."
			% [
				int(
					controller.game.round
				),
				controller.human_summon_cost(),
			]
		)

		_build_hand_buttons(false)
		_refresh_target_options()
		_refresh_all()
		return

	if controller.stage == PlayableRoundControllerData.Stage.REFLEX_BID:
		_enter_development_choice("Reflex Bid — secretly select any Hand cards to bid, or bid zero.")
		return

	_show_commitment_prompt()
	_refresh_all()


func _enter_development_choice(
	prompt: String
) -> void:
	selected_action = ""
	_clear_action_toggles()
	_build_hand_buttons(
		controller.stage == PlayableRoundControllerData.Stage.REPAIR
		or controller.stage == PlayableRoundControllerData.Stage.DEPLOY
	)
	_refresh_target_options()
	_set_phase_message(prompt)
	_refresh_all()


func _begin_deploy_guard_picker() -> void:
	deploy_target_zone = "Lord"
	queued_deploy_moves.clear()
	_build_hand_buttons(true)
	_refresh_target_options()
	_set_phase_message(_deploy_picker_prompt())
	_refresh_all()


func _begin_march_picker() -> void:
	_clear_card_selection()
	_refresh_target_options()
	_build_march_guard_buttons()
	_set_phase_message(_march_picker_prompt())
	_refresh_all()


func _show_commitment_prompt() -> void:
	_log(
		"Round %d: Development completed. Choose a sealed order."
		% int(controller.game.round)
	)
	_log_reflex_bid_status()
	_build_hand_buttons(false)
	_refresh_action_legality()
	_refresh_target_options()
	_refresh_all()


func _on_action_selected(
	action_name: String
) -> void:
	selected_action = action_name

	for candidate_name: String in ACTIONS:
		var button: Button = action_buttons.get(
			candidate_name,
			null
		)

		if button != null:
			button.set_pressed_no_signal(
				candidate_name == action_name
			)

	if action_name in ["Profane", "Ward"]:
		_clear_card_selection()

	_refresh_target_options()
	_refresh_selection_text()
	_refresh_staging_area()


func _on_card_toggled(
	pressed: bool,
	_card_button: Button
) -> void:
	if controller != null:
		if controller.stage == PlayableRoundControllerData.Stage.MARKET:
			# Market is a one-for-one swap. Treat the Hand row as a radio
			# selection instead of letting an accidental second click create an
			# invalid trade.
			if pressed:
				for other_button: Button in card_buttons:
					if other_button != _card_button:
						other_button.set_pressed_no_signal(false)
			# Re-label the available offers against the card currently being given.
			_refresh_target_options()
		elif (
			controller.stage == PlayableRoundControllerData.Stage.DEPLOY
			and pressed
		):
			var deploy_limit: int = _deploy_selection_limit()
			var selected_entries: Array[Dictionary] = _selected_card_entries()

			if selected_entries.size() > deploy_limit:
				_card_button.set_pressed_no_signal(false)
				_set_phase_message(
					"%s Guard zone has room for %d card%s this step."
					% [
						deploy_target_zone,
						deploy_limit,
						"" if deploy_limit == 1 else "s",
					]
				)
			elif _selected_deploy_garrison_count() > _deploy_garrison_moves_remaining():
				_card_button.set_pressed_no_signal(false)
				_set_phase_message(
					"Only %d Garrison deployment%s remain this round."
					% [
						_deploy_garrison_moves_remaining(),
						"" if _deploy_garrison_moves_remaining() == 1 else "s",
					]
				)
		elif (
			controller.stage == PlayableRoundControllerData.Stage.KANIFOUS_INVOKE
			and pressed
		):
			for other_button: Button in card_buttons:
				if other_button != _card_button:
					other_button.set_pressed_no_signal(false)
		elif (
			controller.stage == PlayableRoundControllerData.Stage.MARCH
			and pressed
		):
			var selected_march_cards: Array[String] = _selected_card_ids()
			if selected_march_cards.size() > 1:
				_card_button.set_pressed_no_signal(false)
				_set_phase_message("Choose one Guard to launch, or pass Marching Orders.")

	_refresh_selection_text()
	_refresh_staging_area()


func _on_target_selected(
	_index: int
) -> void:
	if (
		controller != null
		and controller.stage == PlayableRoundControllerData.Stage.REPAIR
		and hand_caption_label != null
	):
		hand_caption_label.text = _hand_caption_text()
	if (
		controller != null
		and controller.stage == PlayableRoundControllerData.Stage.MARCH
	):
		_build_march_guard_buttons()
		_set_phase_message(_march_picker_prompt())
	_refresh_selection_text()
	_refresh_staging_area()
	_refresh_target_info()
	_refresh_marching_board()


func _on_secondary_target_selected(
	_index: int
) -> void:
	_refresh_selection_text()
	_refresh_target_info()
	_refresh_marching_board()


func _on_summon_pressed() -> void:
	var result: Dictionary = (
		controller.resolve_human_summon(
			_selected_card_ids(),
			false
		)
	)

	if _show_failure_if_needed(
		result,
		false
	):
		_set_phase_message(
			"Resummon rejected: select payment worth at least %d."
			% controller.human_summon_cost()
		)
		return

	_log(
		"You resummoned %s with %d payment."
		% [
			controller.human_summon_lord(),
			_selected_card_value(),
		]
	)

	_after_summon_choice(
		result
	)


func _on_skip_summon_pressed() -> void:
	var no_payment: Array[String] = []
	var result: Dictionary = (
		controller.resolve_human_summon(
			no_payment,
			true
		)
	)

	if _show_failure_if_needed(
		result
	):
		return

	_log(
		"You remained banished this round."
	)

	_after_summon_choice(
		result
	)


func _on_development_option_pressed() -> void:
	if controller != null and controller.stage == PlayableRoundControllerData.Stage.REPAIR:
		_refresh_target_options()
		if hand_caption_label != null:
			hand_caption_label.text = _hand_caption_text()
	_refresh_selection_text()
	_refresh_target_info()


func _on_development_finish_pressed() -> void:
	var result: Dictionary = {}
	var choice_stage = controller.stage

	match controller.stage:
		PlayableRoundControllerData.Stage.MARKET:
			result = controller.resolve_human_market({"pass": true})
		PlayableRoundControllerData.Stage.DEVELOPMENT_SNARE:
			result = controller.resolve_human_snare(false)
		PlayableRoundControllerData.Stage.REPAIR:
			result = controller.resolve_human_repair({"pass": true})
		PlayableRoundControllerData.Stage.DOMINION_RITES:
			result = controller.resolve_human_dominion_rites({"pass": true})
		PlayableRoundControllerData.Stage.DEPLOY:
			_finish_deploy_guard_picker()
			return
		PlayableRoundControllerData.Stage.MARCH:
			result = controller.resolve_human_march({"action": "pass"})
		PlayableRoundControllerData.Stage.REFLEX_BID:
			result = controller.resolve_human_reflex_bid({"pass": true})
		PlayableRoundControllerData.Stage.RESOLUTION_REFLEX:
			result = controller.resolve_human_reflex({"pass": true})
		PlayableRoundControllerData.Stage.RESOLUTION_ODRADEK_BREACH:
			result = controller.resolve_human_odradek_breach({"guess": ""})
		PlayableRoundControllerData.Stage.RESOLUTION_GREMORY:
			result = controller.resolve_human_gremory([])
		PlayableRoundControllerData.Stage.RESOLUTION_HUMBABA_TOLL:
			result = controller.resolve_human_humbaba_toll("")
		_:
			return

	if _show_failure_if_needed(result, false):
		_set_phase_message("Choice rejected: %s" % String(result.get("reason", "invalid_choice")))
		return

	if choice_stage in [
		PlayableRoundControllerData.Stage.RESOLUTION_REFLEX,
		PlayableRoundControllerData.Stage.RESOLUTION_ODRADEK_BREACH,
		PlayableRoundControllerData.Stage.RESOLUTION_GREMORY,
		PlayableRoundControllerData.Stage.RESOLUTION_ACTION,
		PlayableRoundControllerData.Stage.RESOLUTION_VESSEL,
		PlayableRoundControllerData.Stage.RESOLUTION_HUMBABA_TOLL,
	]:
		_after_resolution_progress(result)
	else:
		_after_development(result)


func _after_summon_choice(
	result: Dictionary
) -> void:
	_log_new_development_activity()

	if bool(
		result.get(
			"terminal",
			false
		)
	):
		_show_terminal()
		return

	if controller.stage == PlayableRoundControllerData.Stage.REFLEX_BID:
		_enter_development_choice("Reflex Bid — secretly select any Hand cards to bid, or bid zero.")
		return

	selected_action = ""
	_clear_action_toggles()
	_show_commitment_prompt()


func _on_confirm_pressed() -> void:
	if controller.stage == PlayableRoundControllerData.Stage.KANIFOUS_INVOKE:
		var selected_toll_cards: Array[String] = _selected_card_ids()
		if selected_toll_cards.size() != 1:
			_set_phase_message("Choose exactly one Hand card as the Invoke toll.")
			return
		var invoke_result: Dictionary = controller.resolve_human_kanifous_invoke(
			_selected_target_id(),
			selected_toll_cards[0]
		)
		if _show_failure_if_needed(invoke_result, false):
			_set_phase_message("Invoke choice rejected: %s" % String(invoke_result.get("reason", "invalid_invoke")))
			return
		_show_reveal_progress(invoke_result)
		return

	if controller.stage == PlayableRoundControllerData.Stage.MARCH:
		var selected_march_cards: Array[String] = _selected_card_ids()
		if selected_march_cards.is_empty():
			_set_phase_message("Select one Guard to launch, or use Pass Marching Orders.")
			return
		var march_result: Dictionary = controller.resolve_human_march({
			"action": "march",
			"source_zone": _selected_target_id(),
			"lane": _selected_secondary_target_id(),
			"card": selected_march_cards[0],
		})
		if _show_failure_if_needed(march_result, false):
			_set_phase_message("March rejected: %s" % String(march_result.get("reason", "invalid_march")))
			return
		_after_development(march_result)
		return

	if controller.stage == PlayableRoundControllerData.Stage.KANIFOUS_WRIGHT:
		var wright_result: Dictionary = controller.resolve_human_kanifous_wright(_selected_wright_guard_indices())
		if _show_failure_if_needed(wright_result, false):
			_set_phase_message("Wright choice rejected: %s" % String(wright_result.get("reason", "invalid_wright")))
			return
		_show_reveal_progress(wright_result)
		return

	if controller.stage == PlayableRoundControllerData.Stage.RESOLUTION_ACTION:
		var action_options: Dictionary = _build_resolution_action_options()
		var action_resolution_result: Dictionary = controller.resolve_human_resolution_action(action_options)
		if _show_failure_if_needed(action_resolution_result, false):
			_set_phase_message("Action option rejected: %s" % String(action_resolution_result.get("reason", "invalid_action")))
			return
		_after_resolution_progress(action_resolution_result)
		return

	if controller.stage == PlayableRoundControllerData.Stage.RESOLUTION_HUMBABA_TOLL:
		var toll_result: Dictionary = controller.resolve_human_humbaba_toll(_selected_target_id())
		if _show_failure_if_needed(toll_result, false):
			_set_phase_message("Toll rejected: %s" % String(toll_result.get("reason", "invalid_toll")))
			return
		_after_resolution_progress(toll_result)
		return

	if controller.stage == PlayableRoundControllerData.Stage.RESOLUTION_VESSEL:
		var vessel_result: Dictionary = controller.resolve_human_vessel({"offer": _selected_target_id() == "offer"})
		if _show_failure_if_needed(vessel_result, false):
			_set_phase_message("Vessel choice rejected: %s" % String(vessel_result.get("reason", "invalid_vessel")))
			return
		_after_resolution_progress(vessel_result)
		return

	if controller.stage == PlayableRoundControllerData.Stage.RESOLUTION_REFLEX:
		if selected_action.is_empty():
			_set_phase_message(
				"Choose Hunt, Siege, Ward, or use Pass %s."
				% (
					"Momentum"
					if controller.rules != null and controller.rules.momentum
					else "Reflex"
				)
			)
			return
		var reflex_result: Dictionary = controller.resolve_human_reflex(_build_reflex_decision())
		if _show_failure_if_needed(reflex_result, false):
			_set_phase_message("Reflex rejected: %s" % String(reflex_result.get("reason", "invalid_reflex")))
			return
		_after_resolution_progress(reflex_result)
		return

	if controller.stage == PlayableRoundControllerData.Stage.RESOLUTION_ODRADEK_BREACH:
		if selected_action.is_empty():
			_set_phase_message("Choose the stolen action, or do not interfere.")
			return
		var odradek_result: Dictionary = controller.resolve_human_odradek_breach(_build_odradek_breach_decision())
		if _show_failure_if_needed(odradek_result, false):
			_set_phase_message("Breach choice rejected: %s" % String(odradek_result.get("reason", "invalid_breach")))
			return
		_after_resolution_progress(odradek_result)
		return

	if controller.stage == PlayableRoundControllerData.Stage.RESOLUTION_GREMORY:
		var gremory_result: Dictionary = controller.resolve_human_gremory(_selected_card_ids())
		if _show_failure_if_needed(gremory_result, false):
			_set_phase_message("Inevitable Ruin rejected: %s" % String(gremory_result.get("reason", "invalid_gremory")))
			return
		_after_resolution_progress(gremory_result)
		return

	if controller.stage == PlayableRoundControllerData.Stage.MARKET:
		var market_take: String = _selected_target_id()
		var market_give: Array[String] = _selected_card_ids()
		if market_take.is_empty() or market_give.size() != 1:
			_set_phase_message("Choose exactly one Hand card to give and one Market card to take.")
			return
		var market_result: Dictionary = controller.resolve_human_market({"take": market_take, "give": market_give[0]})
		if _show_failure_if_needed(market_result, false):
			_set_phase_message("Market trade rejected: %s" % String(market_result.get("reason", "invalid_market")))
			return
		_after_development(market_result)
		return

	if controller.stage == PlayableRoundControllerData.Stage.DEVELOPMENT_SNARE:
		var snare_result: Dictionary = controller.resolve_human_snare(true)
		if _show_failure_if_needed(snare_result, false):
			_set_phase_message("Snare rejected: %s" % String(snare_result.get("reason", "invalid_snare")))
			return
		_after_development(snare_result)
		return

	if controller.stage == PlayableRoundControllerData.Stage.REPAIR:
		var repair_castle: String = _selected_target_id()
		if repair_castle.is_empty():
			_set_phase_message("Choose a Ruined Castle, or use Pass Repair.")
			return
		var repair_result: Dictionary = controller.resolve_human_repair({
			"castle": repair_castle,
			"payment": _selected_card_ids(),
			"use_token": development_option_button.button_pressed,
		})
		if _show_failure_if_needed(repair_result, false):
			_set_phase_message("Repair rejected: %s" % String(repair_result.get("reason", "invalid_repair")))
			return
		_after_development(repair_result)
		return

	if controller.stage == PlayableRoundControllerData.Stage.DOMINION_RITES:
		var rite_decision: Dictionary = {
			"invocation": (
				{"payment": _selected_card_ids()}
				if development_option_button.button_pressed
				else {"pass": true}
			),
			"profane_ruins": (
				{"castle": _selected_target_id()}
				if not _selected_target_id().is_empty()
				else {"pass": true}
			),
		}
		var rite_result: Dictionary = controller.resolve_human_dominion_rites(rite_decision)
		if _show_failure_if_needed(rite_result, false):
			_set_phase_message("Rite rejected: %s" % String(rite_result.get("reason", "invalid_rite")))
			return
		_after_development(rite_result)
		return

	if controller.stage == PlayableRoundControllerData.Stage.DEPLOY:
		_finish_deploy_guard_picker()
		return

	if controller.stage == PlayableRoundControllerData.Stage.REFLEX_BID:
		var bid_result: Dictionary = controller.resolve_human_reflex_bid({"bid": _selected_card_ids()})
		if _show_failure_if_needed(bid_result, false):
			_set_phase_message("Bid rejected: %s" % String(bid_result.get("reason", "invalid_reflex_bid")))
			return
		_after_development(bid_result)
		return

	if selected_action.is_empty():
		_set_phase_message(
			"Choose Hunt, Siege, Ward, or Profane."
		)
		return

	var human_decision: Dictionary = (
		_build_human_decision()
	)

	var result: Dictionary = (
		controller.seal_human_commitment(
			human_decision
		)
	)

	if _show_failure_if_needed(
		result,
		false
	):
		_set_phase_message(
			"Order rejected: %s"
			% String(
				result.get(
					"reason",
					"invalid_commitment"
				)
			)
		)
		return

	_set_commitment_controls_enabled(
		false
	)

	reveal_label.text = (
		"[center][b]Both orders are sealed.[/b]\n"
		+ "The opponent's choice remains hidden.[/center]"
	)

	var human_commit = controller.get_human_player()
	_log(
		"You sealed %s with %d committed strength."
		% [selected_action, _card_value_total(human_commit.committed)]
	)
	for player_result_raw in result.get("players", []):
		if typeof(player_result_raw) != TYPE_DICTIONARY:
			continue
		var player_result: Dictionary = player_result_raw
		if int(player_result.get("player_id", -1)) != int(human_commit.pid):
			continue
		var spent_bank: String = String(player_result.get("bank_spent_card", ""))
		if not spent_bank.is_empty():
			_log("[color=#d8b4fe][b]Odradek — Interlock spent:[/b] %s joined the %s; Recoil rearmed.[/color]" % [spent_bank, selected_action])

	_refresh_all()


func _on_reveal_pressed() -> void:
	var result: Dictionary = (
		controller.reveal_orders()
	)

	if _show_failure_if_needed(
		result
	):
		return
	_show_reveal_progress(result)


func _show_reveal_progress(
	result: Dictionary
) -> void:
	if controller.stage == PlayableRoundControllerData.Stage.KANIFOUS_INVOKE:
		_build_hand_buttons(false)
		_refresh_target_options()
		_set_phase_message("Kanifous Invoke — choose one Hand card to discard as the toll, then choose one revealed card to invoke and bank.")
		_refresh_all()
		return
	if controller.stage == PlayableRoundControllerData.Stage.KANIFOUS_WRIGHT:
		_build_wright_guard_buttons()
		_set_phase_message("Wright — move up to two face-down Lord Guards to the Castle zone, or move none.")
		_refresh_all()
		return

	var human = controller.get_human_player()
	var bot = controller.get_bot_player()

	reveal_label.text = (
		"[center][b]%s[/b]  %s\n"
		+ "[color=#b88f9d]VS[/color]\n"
		+ "[b]%s[/b]  %s\n"
		+ "[color=#c8b36a]%s[/color][/center]"
	) % [
		String(
			human.action
		),
		_cards_inline(
			human.committed
		),
		String(
			bot.action
		),
		_cards_inline(
			bot.committed
		),
		_reflex_holder_text(),
	]

	var reveal_values: Dictionary = {}

	for raw_reveal_player in _array_from(
		result.get(
			"players",
			[]
		)
	):
		if typeof(raw_reveal_player) != TYPE_DICTIONARY:
			continue

		var reveal_player: Dictionary = raw_reveal_player
		reveal_values[int(
			reveal_player.get(
				"player_id",
				-1
			)
		)] = int(
			reveal_player.get(
				"committed_value",
				0
			)
		)

	var human_reveal_value: int = int(
		reveal_values.get(
			int(human.pid),
			_card_value_total(
				human.committed
			)
		)
	)
	var bot_reveal_value: int = int(
		reveal_values.get(
			int(bot.pid),
			_card_value_total(
				bot.committed
			)
		)
	)

	_log(
		"Reveal: you chose %s (%d); %s chose %s (%d)."
		% [
			String(
				human.action
			),
			human_reveal_value,
			String(
				bot.lord
			),
			String(
				bot.action
			),
			bot_reveal_value,
		]
	)
	_log_reveal_sigils(
		result
	)
	_log_reveal_lord_powers(
		result
	)

	_refresh_all()


func _on_resolve_pressed() -> void:
	resolution_start_digest = _state_digest()
	var result: Dictionary = controller.begin_human_resolution()
	_after_resolution_progress(result)


func _after_resolution_progress(
	result: Dictionary
) -> void:
	if _show_failure_if_needed(result, false):
		_set_phase_message("Resolution choice rejected: %s" % String(result.get("reason", "invalid_resolution")))
		return

	_log_guard_reveals()

	if bool(result.get("completed", false)):
		_log_new_development_activity()
		_log_resolution_transcript(result)
		var resolution_end_digest: Dictionary = _state_digest()
		_log_resource_income_audit(resolution_start_digest, resolution_end_digest)
		_log_resolution_changes(resolution_start_digest, resolution_end_digest)
		_refresh_all()
		if bool(result.get("terminal", false)):
			_show_terminal()
			return
		phase_label.text = "Round resolved"
		next_round_button.visible = true
		confirm_button.visible = false
		reveal_button.visible = false
		resolve_button.visible = false
		return

	selected_action = ""
	_clear_action_toggles()
	if controller.stage == PlayableRoundControllerData.Stage.RESOLUTION_HUMBABA_TOLL:
		_build_hand_buttons(false)
		_refresh_target_options()
		_set_phase_message("Humbaba may ruin one Castle to take 1 enemy Soul and add a Neutral Tear.")
	elif controller.stage == PlayableRoundControllerData.Stage.RESOLUTION_ACTION:
		_build_hand_buttons(false)
		_refresh_target_options()
		_set_phase_message("Choose the optional Consume / Inferno setting for your sealed action.")
	elif controller.stage == PlayableRoundControllerData.Stage.RESOLUTION_VESSEL:
		_build_hand_buttons(false)
		_refresh_target_options()
		_set_phase_message("The action has resolved. Offer your Lord as the Vessel, or pass.")
	elif controller.stage == PlayableRoundControllerData.Stage.RESOLUTION_REFLEX:
		_build_hand_buttons(false)
		_refresh_reflex_action_legality()
		_refresh_target_options()
		_set_phase_message(
			"Choose a %s action and any Hand cards, or pass."
			% (
				"Momentum"
				if controller.rules != null and controller.rules.momentum
				else "Reflex"
			)
		)
	elif controller.stage == PlayableRoundControllerData.Stage.RESOLUTION_ODRADEK_BREACH:
		_build_hand_buttons(false)
		_refresh_reflex_action_legality()
		_refresh_target_options()
		_set_phase_message(
			"Predict the bot's %s action; on a correct read, execute your selected stolen action."
			% _second_action_name()
		)
	elif controller.stage == PlayableRoundControllerData.Stage.RESOLUTION_GREMORY:
		_build_hand_buttons(true)
		_refresh_target_options()
		_set_phase_message("Pay exactly two Hand/Garrison cards to ruin the surviving sieged Castle, or pass.")
	_refresh_all()


func _refresh_all() -> void:
	if debug_export_button != null:
		debug_export_button.disabled = controller == null or controller.game == null

	if controller == null or controller.game == null:
		return

	var game = controller.game
	var human = controller.get_human_player()
	var bot = controller.get_bot_player()

	round_label.text = "Round %d" % int(
		game.round
	)

	veil_label.text = "Veil %d/%d" % [
		int(
			game.calculate_veil_total()
		),
		int(
			controller.rules.final_collapse_threshold
		),
	]
	veil_label.tooltip_text = _dominion_help_text(
		int(game.calculate_veil_total())
	)

	breach_label.text = (
		"Breach: none"
		if String(
			game.breach
		).is_empty()
		else "Breach: %s" % String(
			game.breach
		)
	)

	human_state_label.text = _player_state_text(
		human,
		false
	)
	bot_state_label.text = _player_state_text(
		bot,
		true
	)
	human_lord_card_label.text = _lord_card_text(
		human
	)
	bot_lord_card_label.text = _lord_card_text(
		bot
	)
	_refresh_staging_area()
	_refresh_marching_board()

	var commitment_controls_visible: bool = (
		controller.stage in [
			PlayableRoundControllerData.Stage.COMMITMENT,
			PlayableRoundControllerData.Stage.RESOLUTION_REFLEX,
			PlayableRoundControllerData.Stage.RESOLUTION_ODRADEK_BREACH,
		]
	)
	for action_name: String in ACTIONS:
		var action_button: Button = action_buttons.get(action_name, null)
		if action_button != null:
			action_button.visible = commitment_controls_visible

	target_label.visible = (
		controller.stage in [
			PlayableRoundControllerData.Stage.MARKET,
			PlayableRoundControllerData.Stage.DEVELOPMENT_SNARE,
			PlayableRoundControllerData.Stage.REPAIR,
			PlayableRoundControllerData.Stage.DOMINION_RITES,
			PlayableRoundControllerData.Stage.MARCH,
			PlayableRoundControllerData.Stage.KANIFOUS_INVOKE,
			PlayableRoundControllerData.Stage.COMMITMENT,
			PlayableRoundControllerData.Stage.RESOLUTION_HUMBABA_TOLL,
			PlayableRoundControllerData.Stage.RESOLUTION_ACTION,
			PlayableRoundControllerData.Stage.RESOLUTION_VESSEL,
			PlayableRoundControllerData.Stage.RESOLUTION_REFLEX,
			PlayableRoundControllerData.Stage.RESOLUTION_ODRADEK_BREACH,
		]
	)
	target_select.visible = target_label.visible
	target_info_label.visible = target_label.visible
	secondary_target_label.visible = (
		controller.stage == PlayableRoundControllerData.Stage.RESOLUTION_ODRADEK_BREACH
		or controller.stage == PlayableRoundControllerData.Stage.MARCH
	)
	secondary_target_select.visible = secondary_target_label.visible
	development_option_button.visible = false
	development_finish_button.visible = false

	match controller.stage:
		PlayableRoundControllerData.Stage.KANIFOUS_INVOKE:
			phase_label.text = "Reveal — Kanifous Invoke"
			confirm_button.text = "Choose Invoke Card"
			confirm_button.visible = true
			summon_button.visible = false
			skip_summon_button.visible = false
			reveal_button.visible = false
			resolve_button.visible = false
			next_round_button.visible = false

		PlayableRoundControllerData.Stage.KANIFOUS_WRIGHT:
			phase_label.text = "Reveal — Kanifous Wright"
			confirm_button.text = "Move Selected Guards"
			confirm_button.visible = true
			summon_button.visible = false
			skip_summon_button.visible = false
			reveal_button.visible = false
			resolve_button.visible = false
			next_round_button.visible = false

		PlayableRoundControllerData.Stage.DEVELOPMENT_SNARE:
			phase_label.text = "Development — Orias Snare"
			confirm_button.text = "Set Snare"
			confirm_button.visible = true
			development_finish_button.text = "Pass Snare"
			development_finish_button.visible = true
			summon_button.visible = false
			skip_summon_button.visible = false
			reveal_button.visible = false
			resolve_button.visible = false
			next_round_button.visible = false

		PlayableRoundControllerData.Stage.MARKET:
			phase_label.text = "Development — Market"
			confirm_button.text = "Trade"
			confirm_button.visible = true
			development_finish_button.text = "Pass Market"
			development_finish_button.visible = true
			summon_button.visible = false
			skip_summon_button.visible = false
			reveal_button.visible = false
			resolve_button.visible = false
			next_round_button.visible = false

		PlayableRoundControllerData.Stage.REPAIR:
			phase_label.text = "Development — Repair"
			confirm_button.text = "Repair"
			confirm_button.visible = true
			development_option_button.text = "Use Repair Token"
			development_option_button.set_pressed_no_signal(false)
			development_option_button.disabled = int(human.repair_token) <= 0
			development_option_button.visible = true
			development_finish_button.text = "Pass Repair"
			development_finish_button.visible = true
			summon_button.visible = false
			skip_summon_button.visible = false
			reveal_button.visible = false
			resolve_button.visible = false
			next_round_button.visible = false

		PlayableRoundControllerData.Stage.DOMINION_RITES:
			phase_label.text = "Development — Dominion Rites"
			confirm_button.text = "Resolve Rites"
			confirm_button.visible = true
			development_option_button.text = "Use Invocation"
			development_option_button.set_pressed_no_signal(false)
			development_option_button.disabled = false
			development_option_button.visible = true
			development_finish_button.text = "Pass Rites"
			development_finish_button.visible = true
			summon_button.visible = false
			skip_summon_button.visible = false
			reveal_button.visible = false
			resolve_button.visible = false
			next_round_button.visible = false

		PlayableRoundControllerData.Stage.DEPLOY:
			phase_label.text = "Development — Deploy %s Guards" % deploy_target_zone
			confirm_button.text = (
				"Next: Castle Guards"
				if deploy_target_zone == "Lord"
				else "Finish Deploy"
			)
			confirm_button.visible = true
			development_finish_button.visible = false
			summon_button.visible = false
			skip_summon_button.visible = false
			reveal_button.visible = false
			resolve_button.visible = false
			next_round_button.visible = false

		PlayableRoundControllerData.Stage.MARCH:
			phase_label.text = "Development — Marching Orders"
			confirm_button.text = "4. Launch Face-Up Guard"
			confirm_button.visible = true
			development_finish_button.text = "Pass Marching Orders"
			development_finish_button.visible = true
			summon_button.visible = false
			skip_summon_button.visible = false
			reveal_button.visible = false
			resolve_button.visible = false
			next_round_button.visible = false

		PlayableRoundControllerData.Stage.SUMMON:
			phase_label.text = (
				"Summon — pay %d to return"
				% controller.human_summon_cost()
			)
			summon_button.visible = true
			skip_summon_button.visible = true
			confirm_button.visible = false
			reveal_button.visible = false
			resolve_button.visible = false
			next_round_button.visible = false

		PlayableRoundControllerData.Stage.REFLEX_BID:
			phase_label.text = "Reflex Bid — simultaneous"
			confirm_button.text = "Submit Bid"
			confirm_button.visible = true
			development_finish_button.text = "Bid 0"
			development_finish_button.visible = true
			summon_button.visible = false
			skip_summon_button.visible = false
			reveal_button.visible = false
			resolve_button.visible = false
			next_round_button.visible = false

		PlayableRoundControllerData.Stage.RESOLUTION_HUMBABA_TOLL:
			phase_label.text = "Prelude — Humbaba's Toll"
			confirm_button.text = "Pay the Toll"
			confirm_button.visible = true
			development_finish_button.text = "Pass Toll"
			development_finish_button.visible = true
			summon_button.visible = false
			skip_summon_button.visible = false
			reveal_button.visible = false
			resolve_button.visible = false
			next_round_button.visible = false

		PlayableRoundControllerData.Stage.RESOLUTION_ACTION:
			phase_label.text = "Resolution — choose action options"
			confirm_button.text = "Resolve Action"
			confirm_button.visible = true
			summon_button.visible = false
			skip_summon_button.visible = false
			reveal_button.visible = false
			resolve_button.visible = false
			next_round_button.visible = false

		PlayableRoundControllerData.Stage.RESOLUTION_VESSEL:
			phase_label.text = "Aftermath — offer the Vessel?"
			confirm_button.text = "Confirm Vessel"
			confirm_button.visible = true
			summon_button.visible = false
			skip_summon_button.visible = false
			reveal_button.visible = false
			resolve_button.visible = false
			next_round_button.visible = false

		PlayableRoundControllerData.Stage.RESOLUTION_REFLEX:
			var second_action_name: String = _second_action_name()
			phase_label.text = "%s — take a second action or pass" % second_action_name
			confirm_button.text = "Execute %s" % second_action_name
			confirm_button.visible = true
			development_finish_button.text = "Pass %s" % second_action_name
			development_finish_button.visible = true
			summon_button.visible = false
			skip_summon_button.visible = false
			reveal_button.visible = false
			resolve_button.visible = false
			next_round_button.visible = false

		PlayableRoundControllerData.Stage.RESOLUTION_ODRADEK_BREACH:
			phase_label.text = "Odradek Breach — predict the %s" % _second_action_name()
			confirm_button.text = "Predict & Steal"
			confirm_button.visible = true
			development_finish_button.text = "Do Not Interfere"
			development_finish_button.visible = true
			summon_button.visible = false
			skip_summon_button.visible = false
			reveal_button.visible = false
			resolve_button.visible = false
			next_round_button.visible = false

		PlayableRoundControllerData.Stage.RESOLUTION_GREMORY:
			phase_label.text = "Cleanup — Inevitable Ruin"
			confirm_button.text = "Ruin Sieged Castle"
			confirm_button.visible = true
			development_finish_button.text = "Pass Inevitable Ruin"
			development_finish_button.visible = true
			summon_button.visible = false
			skip_summon_button.visible = false
			reveal_button.visible = false
			resolve_button.visible = false
			next_round_button.visible = false

		PlayableRoundControllerData.Stage.COMMITMENT:
			phase_label.text = "Commitment — choose secretly"
			summon_button.visible = false
			skip_summon_button.visible = false
			confirm_button.text = "Seal Order"
			confirm_button.visible = true
			reveal_button.visible = false
			resolve_button.visible = false
			next_round_button.visible = false

		PlayableRoundControllerData.Stage.SEALED:
			phase_label.text = "Orders sealed"
			summon_button.visible = false
			skip_summon_button.visible = false
			confirm_button.visible = false
			reveal_button.visible = true
			resolve_button.visible = false
			next_round_button.visible = false

		PlayableRoundControllerData.Stage.REVEALED:
			phase_label.text = "Reveal — read the clash"
			summon_button.visible = false
			skip_summon_button.visible = false
			confirm_button.visible = false
			reveal_button.visible = false
			resolve_button.visible = true
			next_round_button.visible = false

		PlayableRoundControllerData.Stage.TERMINAL:
			phase_label.text = "Match complete"
			summon_button.visible = false
			skip_summon_button.visible = false
			confirm_button.visible = false
			reveal_button.visible = false
			resolve_button.visible = false
			next_round_button.visible = false

		PlayableRoundControllerData.Stage.INVALID:
			phase_label.text = "Prototype halted"
			summon_button.visible = false
			skip_summon_button.visible = false
			confirm_button.visible = false
			reveal_button.visible = false
			resolve_button.visible = false
			next_round_button.visible = false

	call_deferred(
		"_validate_layout_invariants"
	)


func _refresh_staging_area() -> void:
	if controller == null or controller.game == null or controller.rules == null:
		return

	var game = controller.game
	var human = controller.get_human_player()
	var bot = controller.get_bot_player()
	if human == null or bot == null:
		return

	var veil_total: int = int(game.calculate_veil_total())
	var dominion_help: String = _dominion_help_text(veil_total)
	if dominion_track_label != null:
		dominion_track_label.text = (
			"[center][b]DOMINION / VEIL[/b]  [b]%d/%d[/b]\n"
			+ "Collapse [b]%d[/b]  ·  Waning [b]%d[/b]  ·  "
			+ "Cataclysm [b]%d[/b]  ·  Final [b]%d[/b]\n"
			+ "Your Tears [b]%d/%d[/b]  ·  Opponent [b]%d/%d[/b][/center]"
		) % [
			veil_total,
			int(controller.rules.final_collapse_threshold),
			VEIL_COLLAPSE_THRESHOLD,
			VEIL_WANING_THRESHOLD,
			int(controller.rules.dominion_track),
			int(controller.rules.final_collapse_threshold),
			int(human.tears),
			int(controller.rules.dominion_requirement),
			int(bot.tears),
			int(controller.rules.dominion_requirement),
		]
		dominion_track_label.tooltip_text = dominion_help

	if dominion_progress != null:
		dominion_progress.min_value = 0.0
		dominion_progress.max_value = float(
			max(1, int(controller.rules.final_collapse_threshold))
		)
		dominion_progress.value = float(
			min(veil_total, int(dominion_progress.max_value))
		)
		dominion_progress.tooltip_text = dominion_help

	var selected_market_id: String = ""
	var suggested_market_id: String = ""
	if controller.stage == PlayableRoundControllerData.Stage.MARKET:
		selected_market_id = _selected_target_id()
		suggested_market_id = _best_market_take_card_id()

	for market_index: int in range(market_staging_labels.size()):
		var market_label: RichTextLabel = market_staging_labels[market_index]
		var market_panel: PanelContainer = market_staging_panels[market_index]
		if market_index >= game.market.size():
			market_label.text = "[center][color=#78758a]EMPTY OFFER[/color]\n—[/center]"
			market_panel.self_modulate = Color.WHITE
			continue

		var market_card = game.market[market_index]
		var market_card_id: String = _card_id(market_card)
		var marker: String = ""
		if market_card_id == selected_market_id:
			marker = "\n[color=#f2d477][b]SELECTED[/b][/color]"
			market_panel.self_modulate = Color(1.0, 0.92, 0.64, 1.0)
		elif market_card_id == suggested_market_id:
			marker = "\n[color=#8ee5a1]BEST VALUE[/color]"
			market_panel.self_modulate = Color(0.82, 1.0, 0.86, 1.0)
		else:
			market_panel.self_modulate = Color.WHITE

		market_label.text = "[center][b]%s[/b]\nValue %d%s[/center]" % [
			market_card_id,
			int(market_card.value),
			marker,
		]

	if human_staging_label != null:
		human_staging_label.text = _staging_order_text(human, true)
	if bot_staging_label != null:
		bot_staging_label.text = _staging_order_text(bot, false)


func _staging_order_text(
	player,
	is_human: bool
) -> String:
	var owner_name: String = "YOU" if is_human else "OPPONENT"
	var owner_color: String = "#78d9a1" if is_human else "#dc8d9d"
	var action_name: String = String(player.action)

	if (
		is_human
		and controller.stage == PlayableRoundControllerData.Stage.COMMITMENT
		and not selected_action.is_empty()
	):
		return "[center][color=%s][b]%s — DRAFT[/b][/color]\n%s · %s[/center]" % [
			owner_color,
			owner_name,
			selected_action,
			_cards_inline(_selected_cards_for_staging()),
		]

	# The bot decides its order while the human is choosing, but that decision
	# must remain sealed until Reveal.  Before Commitment resolves, its cards
	# live in the controller's decision; afterwards they live in committed.
	if not is_human and not _staged_orders_are_public():
		var sealed_card_count: int = player.committed.size()
		if sealed_card_count == 0:
			var bot_plan: Dictionary = controller.get_bot_commitment()
			var planned_cards: Array = bot_plan.get("cards", [])
			sealed_card_count = planned_cards.size()

		return "[center][color=%s][b]%s — SEALED[/b][/color]\n%d card%s face-down[/center]" % [
			owner_color,
			owner_name,
			sealed_card_count,
			"" if sealed_card_count == 1 else "s",
		]

	if action_name.is_empty():
		return "[center][color=%s][b]%s[/b][/color]\n[color=#78758a]No order staged[/color][/center]" % [
			owner_color,
			owner_name,
		]

	var cards_text: String = _cards_inline(player.committed)

	return "[center][color=%s][b]%s — %s[/b][/color]\n%s[/center]" % [
		owner_color,
		owner_name,
		action_name,
		cards_text,
	]


func _selected_cards_for_staging() -> Array:
	var selected_cards: Array = []
	if controller == null or controller.game == null:
		return selected_cards

	var human = controller.get_human_player()
	if human == null:
		return selected_cards

	var selected_ids: Array[String] = _selected_card_ids()
	for card_id: String in selected_ids:
		for card in human.hand:
			if _card_id(card) == card_id:
				selected_cards.append(card)
				break

	return selected_cards


func _staged_orders_are_public() -> bool:
	if controller == null:
		return false

	return controller.stage >= PlayableRoundControllerData.Stage.REVEALED


func _refresh_marching_board() -> void:
	if marching_board_panel == null:
		return

	var marching_enabled: bool = (
		controller != null
		and controller.game != null
		and controller.rules != null
		and controller.rules.marching
	)
	marching_board_panel.visible = marching_enabled
	if not marching_enabled:
		return

	var human = controller.get_human_player()
	var bot = controller.get_bot_player()
	if human == null or bot == null:
		return

	var slot_texts: Dictionary = {}
	var gate_texts: Dictionary = {}
	var selected_lane: String = ""
	if controller.stage == PlayableRoundControllerData.Stage.MARCH:
		selected_lane = _selected_secondary_target_id()

	for lane: String in MARCH_LANES:
		gate_texts[_march_gate_key(lane, true)] = (
			"[color=#78d9a1][b]YOUR %s GUARDS[/b][/color]\nReady to launch"
			% lane.to_upper()
		)
		gate_texts[_march_gate_key(lane, false)] = (
			"[color=#dc8d9d][b]OPPONENT GUARDS[/b][/color]\nReady to launch"
		)

		var lane_title = march_lane_title_labels.get(lane, null)
		if lane_title != null:
			lane_title.text = "%s LANE" % lane.to_upper()
			lane_title.modulate = (
				Color(1.0, 0.84, 0.43, 1.0)
				if lane == selected_lane
				else Color(0.9, 0.88, 0.94, 1.0)
			)

		for step: int in range(1, MARCH_TRACK_STEPS + 1):
			var slot_key: String = _march_slot_key(lane, step)
			slot_texts[slot_key] = _march_slot_placeholder(step)
			var slot_panel = march_slot_panels.get(slot_key, null)
			if slot_panel != null:
				slot_panel.self_modulate = (
					Color(1.0, 0.94, 0.74, 1.0)
					if lane == selected_lane
					else Color.WHITE
				)

	_add_marchers_to_board(human, true, slot_texts, gate_texts)
	_add_marchers_to_board(bot, false, slot_texts, gate_texts)

	for lane: String in MARCH_LANES:
		var human_gate_label = march_gate_labels.get(_march_gate_key(lane, true), null)
		if human_gate_label != null:
			human_gate_label.text = String(gate_texts.get(_march_gate_key(lane, true), ""))
		var bot_gate_label = march_gate_labels.get(_march_gate_key(lane, false), null)
		if bot_gate_label != null:
			bot_gate_label.text = String(gate_texts.get(_march_gate_key(lane, false), ""))

		for step: int in range(1, MARCH_TRACK_STEPS + 1):
			var slot_key: String = _march_slot_key(lane, step)
			var slot_label = march_slot_labels.get(slot_key, null)
			if slot_label != null:
				slot_label.text = String(slot_texts.get(slot_key, ""))

	if march_status_label != null:
		if controller.stage == PlayableRoundControllerData.Stage.MARCH:
			march_status_label.text = "1. Choose Guard zone   2. Select one Guard   3. Choose lane   4. Launch or pass   •   RPS: Wright > Penitent > Vulture > Butcher > Wright"
		elif human.marchers.is_empty() and bot.marchers.is_empty():
			march_status_label.text = "No marchers in flight. Marching Orders opens during Development."
		else:
			march_status_label.text = "Face-up marchers advance after Resolution. A value %d+ Guard at the enemy gate gains a Tear." % controller.rules.march_threshold


func _add_marchers_to_board(
	player,
	is_human: bool,
	slot_texts: Dictionary,
	gate_texts: Dictionary
) -> void:
	if player == null:
		return

	for marcher_value in player.marchers:
		var marcher: Dictionary = marcher_value
		var lane: String = String(marcher.get("lane", ""))
		if not MARCH_LANES.has(lane):
			continue

		var march_position: int = int(marcher.get("pos", 0))
		var display_text: String = _marcher_board_text(marcher, is_human)
		if march_position <= 0:
			var gate_key: String = _march_gate_key(lane, is_human)
			gate_texts[gate_key] = display_text
			continue

		var step: int = min(march_position, MARCH_TRACK_STEPS)
		if not is_human:
			step = MARCH_TRACK_STEPS - step + 1
		var slot_key: String = _march_slot_key(lane, step)
		var existing_text: String = String(slot_texts.get(slot_key, ""))
		if existing_text.contains("[color=#78758a]"):
			existing_text = ""
		slot_texts[slot_key] = (
			existing_text + ("\n" if not existing_text.is_empty() else "") + display_text
		)


func _marcher_board_text(
	marcher: Dictionary,
	is_human: bool
) -> String:
	var card = marcher.get("card", null)
	var color_code: String = "#78d9a1" if is_human else "#dc8d9d"
	var direction: String = "→" if is_human else "←"
	var owner_label: String = "YOU" if is_human else "BOT"
	return "[center][color=%s][b]%s %s[/b][/color]\n%s  ·  v%d[/center]" % [
		color_code,
		owner_label,
		direction,
		_card_id(card),
		int(marcher.get("value", 0)),
	]


func _march_slot_placeholder(
	step: int
) -> String:
	if step == 1:
		return "[center][color=#78d9a1]YOU 1[/color]  ·  [color=#dc8d9d]BOT 3[/color]\n[color=#78758a]—[/color][/center]"
	if step == MARCH_TRACK_STEPS:
		return "[center][color=#78d9a1]YOU 3[/color]  ·  [color=#dc8d9d]BOT 1[/color]\n[color=#78758a]—[/color][/center]"
	return "[center][color=#78758a]MIDFIELD · STEP %d[/color]\n—[/center]" % step


func _march_gate_key(
	lane: String,
	is_human: bool
) -> String:
	return "%s:%s" % [lane, "human" if is_human else "bot"]


func _march_slot_key(
	lane: String,
	step: int
) -> String:
	return "%s:%d" % [lane, step]


func _refresh_action_legality() -> void:
	var human = controller.get_human_player()
	var bot = controller.get_bot_player()

	_set_action_enabled(
		"Hunt",
		bool(
			human.alive
		)
		and bool(
			bot.alive
		)
	)

	_set_action_enabled(
		"Siege",
		bool(
			human.alive
		)
		and not bot.castles.is_empty()
	)

	_set_action_enabled(
		"Ward",
		true
	)

	_set_action_enabled(
		"Profane",
		bool(
			human.alive
		)
		and not human.castles.is_empty()
	)

	if not human.alive:
		_on_action_selected(
			"Ward"
		)


func _refresh_reflex_action_legality() -> void:
	var human = controller.get_human_player()
	var bot = controller.get_bot_player()
	_set_action_enabled("Hunt", human.alive and bot.alive and human.threat < controller.rules.max_threat)
	_set_action_enabled("Siege", not bot.castles.is_empty())
	_set_action_enabled("Ward", true)
	_set_action_enabled("Profane", false)


func _refresh_target_options() -> void:
	var previous_target_id: String = _selected_target_id()
	target_select.clear()
	secondary_target_select.clear()
	secondary_target_label.text = ""

	if controller != null and controller.game != null:
		var development_human = controller.get_human_player()

		if controller.stage == PlayableRoundControllerData.Stage.KANIFOUS_INVOKE:
			target_label.text = "Revealed card:"
			for card_id: String in controller.kanifous_preview_cards:
				_add_target_option(card_id, card_id)
			target_select.disabled = target_select.item_count <= 1
			_refresh_target_info()
			return

		if controller.stage == PlayableRoundControllerData.Stage.MARKET:
			target_label.text = "Trade for:"
			var suggested_take_id: String = _best_market_take_card_id()
			var selected_hand_value: int = _market_selected_hand_value()
			for market_card in controller.game.market:
				var market_card_id: String = _card_id(market_card)
				_add_target_option(
					_market_trade_label(
						market_card,
						selected_hand_value,
						market_card_id == suggested_take_id
					),
					market_card_id
				)
				if market_card_id == suggested_take_id:
					target_select.select(target_select.item_count - 1)
			target_select.disabled = controller.game.market.is_empty()
			_refresh_target_info()
			return

		if controller.stage == PlayableRoundControllerData.Stage.REPAIR:
			target_label.text = "Repair:"
			for ruined_castle: String in development_human.ruined_castles:
				var normal_cost: int = _repair_cost(ruined_castle, false)
				var display_text: String = "%s — cost %d" % [ruined_castle, normal_cost]
				if int(development_human.repair_token) > 0:
					display_text += "  ·  %d with token" % _repair_cost(ruined_castle, true)
				_add_target_option(display_text, ruined_castle)
				if ruined_castle == previous_target_id:
					target_select.select(target_select.item_count - 1)
			target_select.disabled = development_human.ruined_castles.is_empty()
			_refresh_target_info()
			return

		if controller.stage == PlayableRoundControllerData.Stage.DOMINION_RITES:
			target_label.text = "Profane:"
			_add_target_option("No Profane Ruins", "")
			for ruined_castle: String in development_human.ruined_castles:
				_add_target_option(ruined_castle, ruined_castle)
			target_select.disabled = false
			_refresh_target_info()
			return

		if controller.stage == PlayableRoundControllerData.Stage.DEPLOY:
			# The two-stage Guard picker names its destination in the phase and
			# needs no competing target dropdown.
			target_select.disabled = true
			return

		if controller.stage == PlayableRoundControllerData.Stage.MARCH:
			target_label.text = "1. Guard zone:"
			_add_target_option(
				"Lord Guards (%d)" % development_human.lord_guards.size(),
				"Lord"
			)
			_add_target_option(
				"Castle Guards (%d)" % development_human.castle_guards.size(),
				"Castle"
			)
			target_select.disabled = false
			secondary_target_label.text = "3. March lane:"
			var reactive_lane: String = controller.human_reactive_march_lane()
			if not reactive_lane.is_empty():
				_add_secondary_target_option(
					"%s lane — Reactive response" % reactive_lane,
					reactive_lane
				)
			else:
				_add_secondary_target_option("Lord lane", "Lord")
				_add_secondary_target_option("Castle lane", "Castle")
			secondary_target_select.disabled = false
			_refresh_target_info()
			return

		if controller.stage == PlayableRoundControllerData.Stage.REFLEX_BID:
			target_label.text = "Bid:"
			_add_target_option("Select Hand cards or bid zero", "")
			target_select.disabled = true
			_refresh_target_info()
			return

		if controller.stage == PlayableRoundControllerData.Stage.RESOLUTION_HUMBABA_TOLL:
			target_label.text = "Ruin:"
			for castle_name: String in development_human.castles:
				_add_target_option(castle_name, castle_name)
			target_select.disabled = development_human.castles.is_empty()
			_refresh_target_info()
			return

		if controller.stage == PlayableRoundControllerData.Stage.RESOLUTION_ACTION:
			var action_name: String = String(development_human.action)
			target_label.text = "Option:"
			if action_name == "Hunt":
				_add_target_option("Do not Consume", "hunt:pass")
				_add_target_option("Consume the Hunt", "hunt:consume")
			elif action_name == "Siege":
				_add_target_option("No Consume · use Inferno", "siege:0:1")
				_add_target_option("Consume · use Inferno", "siege:1:1")
				_add_target_option("No Consume · no Inferno", "siege:0:0")
				_add_target_option("Consume · no Inferno", "siege:1:0")
			else:
				_add_target_option("Resolve sealed action", "default")
			target_select.disabled = target_select.item_count <= 1
			_refresh_target_info()
			return

		if controller.stage == PlayableRoundControllerData.Stage.RESOLUTION_VESSEL:
			target_label.text = "Vessel:"
			_add_target_option("Pass", "pass")
			_add_target_option("Offer your Lord", "offer")
			target_select.disabled = false
			_refresh_target_info()
			return

		if controller.stage == PlayableRoundControllerData.Stage.RESOLUTION_REFLEX:
			_refresh_reflex_target_options(development_human, false)
			_refresh_target_info()
			return

		if controller.stage == PlayableRoundControllerData.Stage.RESOLUTION_ODRADEK_BREACH:
			target_label.text = "Predict:"
			_add_target_option("Hunt", "Hunt")
			_add_target_option("Siege", "Siege")
			_add_target_option("Ward", "Ward")
			_add_target_option("Pass", "Pass")
			target_select.disabled = false
			secondary_target_label.text = "Steal target:"
			_refresh_reflex_target_options(development_human, true)
			_refresh_target_info()
			return

	if (
		controller != null
		and controller.game != null
		and controller.stage
			== PlayableRoundControllerData.Stage.SUMMON
	):
		target_label.text = "Return:"
		_add_target_option(
			controller.human_summon_lord(),
			controller.human_summon_lord()
		)
		target_select.disabled = true
		_refresh_target_info()
		return

	if (
		controller == null
		or controller.game == null
		or selected_action.is_empty()
	):
		target_label.text = "Target:"
		_add_target_option(
			"Choose an order first",
			"Choose an order first"
		)
		target_select.disabled = true
		_refresh_target_info()
		return

	var human = controller.get_human_player()
	var bot = controller.get_bot_player()

	target_select.disabled = false

	match selected_action:
		"Hunt":
			target_label.text = "Target:"
			_add_target_option(
				"%s's Lord — DEF %d"
				% [
					String(
						bot.lord
					),
					int(
						bot.derived_lord_def
					),
				],
				"Lord"
			)
			target_select.disabled = true

		"Siege":
			target_label.text = "Castle:"

			for castle_name: String in bot.castles:
				_add_target_option(
					"%s — DEF %d"
					% [
						castle_name,
						_castle_defense(
							castle_name
						),
					],
					castle_name
				)

		"Ward":
			target_label.text = "Zone:"

			if (
				human.alive
				and (
					not controller.rules.ward_anti_repeat
					or human.prev_ward_target != "Lord"
				)
			):
				_add_target_option(
					"Lord",
					"Lord"
				)

			if (
				not controller.rules.ward_anti_repeat
				or human.prev_ward_target != "Castle"
			):
				_add_target_option(
					"Castle",
					"Castle"
				)

			if not human.alive:
				target_select.clear()
				_add_target_option(
					"Castle",
					"Castle"
				)

		"Profane":
			target_label.text = "Sacrifice:"

			for castle_name: String in human.castles:
				_add_target_option(
					"%s — DEF %d"
					% [
						castle_name,
						_castle_defense(
							castle_name
						),
					],
					castle_name
				)

	if target_select.item_count <= 1:
		target_select.disabled = true

	_refresh_target_info()


func _add_target_option(
	display_text: String,
	target_id: String
) -> void:
	var item_index: int = target_select.item_count
	target_select.add_item(
		display_text
	)
	target_select.set_item_metadata(
		item_index,
		target_id
	)


func _add_secondary_target_option(
	display_text: String,
	target_id: String
) -> void:
	var item_index: int = secondary_target_select.item_count
	secondary_target_select.add_item(display_text)
	secondary_target_select.set_item_metadata(item_index, target_id)


func _refresh_reflex_target_options(
	human,
	use_secondary_target: bool
) -> void:
	var target_control: OptionButton = secondary_target_select if use_secondary_target else target_select
	if not use_secondary_target:
		target_select.clear()

	if selected_action.is_empty():
		if use_secondary_target:
			_add_secondary_target_option("Choose stolen action", "")
		else:
			_add_target_option("Choose a %s action" % _second_action_name(), "")
		target_control.disabled = true
		return

	var opponent = controller.get_bot_player()
	if selected_action == "Hunt":
		if use_secondary_target:
			_add_secondary_target_option("Opponent Lord · no Consume", "Lord|0")
			_add_secondary_target_option("Opponent Lord · Consume", "Lord|1")
		else:
			_add_target_option("Opponent Lord · no Consume", "Lord|0")
			_add_target_option("Opponent Lord · Consume", "Lord|1")
	elif selected_action == "Siege":
		for castle_name: String in opponent.castles:
			var siege_options: Array[Dictionary] = [
				{"label": " · no Consume · Inferno", "id": "|0|1"},
				{"label": " · Consume · Inferno", "id": "|1|1"},
				{"label": " · no Consume · no Inferno", "id": "|0|0"},
				{"label": " · Consume · no Inferno", "id": "|1|0"},
			]
			for siege_option in siege_options:
				var display_text: String = castle_name + String(siege_option["label"])
				var option_id: String = castle_name + String(siege_option["id"])
				if use_secondary_target:
					_add_secondary_target_option(display_text, option_id)
				else:
					_add_target_option(display_text, option_id)
	elif selected_action == "Ward":
		if human.alive:
			if use_secondary_target:
				_add_secondary_target_option("Lord", "Lord")
			else:
				_add_target_option("Lord", "Lord")
		if use_secondary_target:
			_add_secondary_target_option("Castle", "Castle")
		else:
			_add_target_option("Castle", "Castle")

	target_control.disabled = target_control.item_count <= 1


func _selected_target_id() -> String:
	if (
		target_select == null
		or target_select.item_count <= 0
		or target_select.selected < 0
	):
		return ""

	var raw_target = target_select.get_item_metadata(
		target_select.selected
	)

	if raw_target == null:
		return target_select.get_item_text(
			target_select.selected
		)

	return String(
		raw_target
	)


func _selected_secondary_target_id() -> String:
	if secondary_target_select == null or secondary_target_select.item_count <= 0 or secondary_target_select.selected < 0:
		return ""
	var raw_target = secondary_target_select.get_item_metadata(secondary_target_select.selected)
	if raw_target == null:
		return secondary_target_select.get_item_text(secondary_target_select.selected)
	return String(raw_target)


func _refresh_target_info() -> void:
	if target_info_label == null:
		return

	if controller != null and controller.game != null:
		if controller.stage == PlayableRoundControllerData.Stage.MARKET:
			target_info_label.text = _market_trade_info()
			return
		if controller.stage == PlayableRoundControllerData.Stage.REPAIR:
			target_info_label.text = _repair_cost_info()
			return
		if controller.stage == PlayableRoundControllerData.Stage.MARCH:
			target_info_label.text = (
				"[color=#c8b36a]Choose a source zone, then one Guard, then a lane. "
				+ "RPS: Wright > Penitent > Vulture > Butcher > Wright. "
				+ "A clash deals %d to each marcher; suit advantage adds +%d damage. "
				+ "Vulture:5 evades; Butcher:1 destroys it with itself.[/color]"
			) % [
				controller.rules.march_damage,
				controller.rules.march_suit_bonus,
			]
			return

	if (
		controller == null
		or controller.game == null
		or selected_action.is_empty()
	):
		target_info_label.text = (
			"[color=#a99eac]Choose an order to inspect its target layers.[/color]"
		)
		return

	var human = controller.get_human_player()
	var bot = controller.get_bot_player()

	match selected_action:
		"Hunt":
			target_info_label.text = _combat_target_text(
				bot,
				"Lord",
				String(
					bot.lord
				),
				int(
					bot.derived_lord_def
				),
				false
			)

		"Siege":
			var castle_name: String = _selected_target_id()

			if castle_name.is_empty():
				target_info_label.text = (
					"[color=#a99eac]Choose a castle.[/color]"
				)
				return

			target_info_label.text = _combat_target_text(
				bot,
				"Castle",
				castle_name,
				_castle_defense(
					castle_name
				),
				bool(
					human.castles.has(
						"SiegeEngine"
					)
				)
			)

		"Ward":
			var zone: String = _selected_target_id()
			if controller.rules.sigil_flat:
				target_info_label.text = (
					"[color=#91c7ff][b]Ward %s:[/b] commit any suits. If your total is at least the opposing %s, the attack is turned. The Ward then starts at +2 DEF and ages to +1 next round.[/color]"
				) % [
					zone,
					(
						"Hunt"
						if zone == "Lord"
						else "Siege"
					),
				]
				return

			var fresh_value: int = _prospective_sigil_value(
				human,
				"fresh"
			)
			var flipped_value: int = _prospective_sigil_value(
				human,
				"flipped"
			)

			target_info_label.text = (
				"[color=#91c7ff][b]Ward %s:[/b] fresh sigil +%d DEF; "
				+ "if the opposing %s beats your commitment, it enters flipped at +%d DEF.[/color]"
			) % [
				zone,
				fresh_value,
				(
					"Hunt"
					if zone == "Lord"
					else "Siege"
				),
				flipped_value,
			]

		"Profane":
			target_info_label.text = (
				"[color=#d8a0c8]Profane sacrifices %s; its structural DEF does not resist the action%s.[/color]"
				% [
					_selected_target_id(),
					(
						" and enemy Sigils do not deny it"
						if controller.rules.fix_b
						else ""
					),
				]
			)


func _combat_target_text(
	defender,
	zone: String,
	target_name: String,
	structural_defense: int,
	siege_engine_bypass: bool
) -> String:
	var guards: Array = (
		defender.lord_guards
		if zone == "Lord"
		else defender.castle_guards
	)
	var revealed_guards: Array = []
	var hidden_guard_count: int = 0

	for guard in guards:
		if controller.is_guard_revealed(
			guard
		):
			revealed_guards.append(
				guard
			)
		else:
			hidden_guard_count += 1

	var revealed_guard_total: int = _card_value_total(
		revealed_guards
	)
	var sigil_state: String = String(
		defender.sigils.get(
			zone,
			""
		)
	)
	var sigil_value: int = _current_sigil_value(
		defender,
		zone
	)
	var sigil_name: String = (
		"none"
		if sigil_state.is_empty()
		else sigil_state
	)
	var known_minimum: int = (
		structural_defense
		+ sigil_value
		+ 1
	)
	var guard_text: String = _public_guard_summary(
		guards
	)
	var caveat: String = "before Ward/reveal effects"

	if not siege_engine_bypass:
		known_minimum += revealed_guard_total

		if hidden_guard_count > 0:
			caveat = (
				"plus %d face-down Guard%s of unknown value"
				% [
					hidden_guard_count,
					(
						""
						if hidden_guard_count == 1
						else "s"
					),
				]
			)
	else:
		guard_text += " — bypassed until after the castle falls"

	return (
		"[b]%s layers:[/b] base DEF %d  |  %s  |  %s sigil +%d  |  "
		+ "[color=#f2d477]%s %d strength[/color] (%s)"
	) % [
		target_name,
		structural_defense,
		guard_text,
		sigil_name,
		sigil_value,
		(
			"known floor"
			if hidden_guard_count > 0
			and not siege_engine_bypass
			else "visible minimum"
		),
		known_minimum,
		caveat,
	]


func _castle_defense(
	castle_name: String,
	defender = null
) -> int:
	if defender == null and controller != null:
		defender = controller.get_bot_player()

	return int(
		SiegeResolutionEngineData._castle_defense(
			controller.game,
			castle_name,
			defender,
			controller.rules
		)
	)


func _current_sigil_value(
	player,
	zone: String
) -> int:
	return int(
		SiegeResolutionEngineData._sigil_value(
			controller.game,
			player,
			String(
				player.sigils.get(
					zone,
					""
				)
			),
			controller.rules
		)
	)


func _prospective_sigil_value(
	player,
	state: String
) -> int:
	return int(
		SiegeResolutionEngineData._sigil_value(
			controller.game,
			player,
			state,
			controller.rules
		)
	)


func _build_hand_buttons(
	include_garrison: bool = false
) -> void:
	for child in hand_flow.get_children():
		child.queue_free()

	card_buttons.clear()

	var human = controller.get_human_player()
	var is_deploy_picker: bool = (
		controller.stage == PlayableRoundControllerData.Stage.DEPLOY
	)
	var show_deploy_cards: bool = (
		not is_deploy_picker
		or _deploy_selection_limit() > 0
	)
	var best_market_give_id: String = _best_market_give_card_id()

	if hand_caption_label != null:
		hand_caption_label.text = _hand_caption_text()

	if (
		show_deploy_cards
		and (
			not is_deploy_picker
			or _deploy_hand_allowed()
		)
	):
		for hand_index: int in range(human.hand.size()):
			var card = human.hand[hand_index]
			var card_identifier: String = _card_id(
				card
			)

			if (
				is_deploy_picker
				and _is_deploy_card_reserved("Hand", card_identifier)
			):
				continue

			var card_label: String = card_identifier
			if is_deploy_picker:
				card_label = "Hand · %s" % card_identifier
			elif (
				controller.stage == PlayableRoundControllerData.Stage.MARKET
				and card_identifier == best_market_give_id
			):
				card_label = "%s  ★ BEST GIVE" % card_identifier

			var card_button := _new_button(
				card_label,
				142 if is_deploy_picker else 112
			)
			card_button.toggle_mode = true
			card_button.set_meta(
				"card_id",
				card_identifier
			)
			card_button.set_meta(
				"card_value",
				int(
					card.value
				)
			)
			card_button.set_meta("card_source", "Hand")
			card_button.set_meta("source_index", hand_index)
			if (
				controller.stage == PlayableRoundControllerData.Stage.MARKET
				and card_identifier == best_market_give_id
			):
				card_button.modulate = Color(1.0, 0.86, 0.46, 1.0)
				card_button.tooltip_text = "Best raw-value card to trade away."
			card_button.toggled.connect(
				_on_card_toggled.bind(
					card_button
				)
			)
			card_buttons.append(
				card_button
			)
			hand_flow.add_child(
				card_button
			)

	if (
		include_garrison
		and show_deploy_cards
		and (
			not is_deploy_picker
			or _deploy_garrison_allowed()
		)
	):
		var garrison_divider := _new_label(
			"GARRISON — voluntary; cards stay here until clicked in a legal phase",
			13
		)
		garrison_divider.tooltip_text = (
			"Garrison cards do not return to Hand automatically. "
			+ "Select them only during phases that permit Garrison deployment or payment."
		)
		hand_flow.add_child(garrison_divider)

		for garrison_index: int in range(human.garrison.size()):
			var garrison_card = human.garrison[garrison_index]
			var garrison_identifier: String = _card_id(garrison_card)
			if (
				is_deploy_picker
				and _is_deploy_card_reserved("Garrison", garrison_identifier)
			):
				continue
			var garrison_button := _new_button("Garrison · %s" % garrison_identifier, 142)
			garrison_button.toggle_mode = true
			garrison_button.set_meta("card_id", garrison_identifier)
			garrison_button.set_meta("card_value", int(garrison_card.value))
			garrison_button.set_meta("card_source", "Garrison")
			garrison_button.tooltip_text = (
				"Garrison card — remains here until voluntarily selected "
				+ "for a legal deployment or payment."
			)
			garrison_button.set_meta("source_index", garrison_index)
			garrison_button.toggled.connect(_on_card_toggled.bind(garrison_button))
			card_buttons.append(garrison_button)
			hand_flow.add_child(garrison_button)

	_refresh_selection_text()


func _build_wright_guard_buttons() -> void:
	for child in hand_flow.get_children():
		child.queue_free()

	card_buttons.clear()

	var human = controller.get_human_player()
	for guard_index: int in range(human.lord_guards.size()):
		var guard_button := _new_button(
			"Lord Guard %d" % (guard_index + 1),
			112
		)
		guard_button.toggle_mode = true
		# Guards remain hidden while in a zone, including from their owner.
		# Store the index only as the physical selection handle for Wright.
		guard_button.set_meta("card_id", "LordGuard:%d" % guard_index)
		guard_button.set_meta("card_value", 0)
		guard_button.set_meta("card_source", "LordGuard")
		guard_button.set_meta("source_index", guard_index)
		guard_button.toggled.connect(_on_card_toggled.bind(guard_button))
		card_buttons.append(guard_button)
		hand_flow.add_child(guard_button)

	_refresh_selection_text()


func _build_march_guard_buttons() -> void:
	for child in hand_flow.get_children():
		child.queue_free()

	card_buttons.clear()

	if controller == null or controller.game == null:
		return

	var human = controller.get_human_player()
	if human == null:
		return

	var source_zone: String = _selected_target_id()
	var guards: Array = (
		human.lord_guards
		if source_zone == "Lord"
		else human.castle_guards
	)

	if human.marchers.size() >= controller.rules.march_max_in_flight:
		if hand_caption_label != null:
			hand_caption_label.text = "A marcher is already in flight; pass this step."
		_refresh_selection_text()
		return

	if guards.is_empty():
		if hand_caption_label != null:
			hand_caption_label.text = "No %s Guards are available to march." % source_zone
		_refresh_selection_text()
		return

	if hand_caption_label != null:
		hand_caption_label.text = "Select one %s Guard to launch face-up:" % source_zone

	for guard_index: int in range(guards.size()):
		var guard = guards[guard_index]
		var guard_button := _new_button(
			"%s Guard · %s" % [source_zone, _card_id(guard)],
			142
		)
		guard_button.toggle_mode = true
		guard_button.set_meta("card_id", _card_id(guard))
		guard_button.set_meta("card_value", int(guard.value))
		guard_button.set_meta("card_source", source_zone)
		guard_button.set_meta("source_index", guard_index)
		guard_button.toggled.connect(_on_card_toggled.bind(guard_button))
		card_buttons.append(guard_button)
		hand_flow.add_child(guard_button)

	_refresh_selection_text()


func _build_human_decision() -> Dictionary:
	var human = controller.get_human_player()
	var bot = controller.get_bot_player()

	var decision: Dictionary = {
		"action": selected_action,
		"cards": _selected_card_ids(),
	}

	match selected_action:
		"Hunt":
			decision["target_pid"] = int(
				bot.pid
			)

		"Siege":
			decision["target_pid"] = int(
				bot.pid
			)
			decision["target_castle"] = _selected_target_id()

		"Ward":
			decision["target_pid"] = int(
				human.pid
			)
			decision["target_type"] = _selected_target_id()

		"Profane":
			decision["target_pid"] = int(
				human.pid
			)
			decision["target_castle"] = _selected_target_id()
			decision["cards"] = []

	return decision


func _build_resolution_action_options() -> Dictionary:
	var human = controller.get_human_player()
	var option_id: String = _selected_target_id()

	if human.action == "Hunt":
		return {"consume_hunt": option_id == "hunt:consume"}

	if human.action == "Siege":
		var parts: PackedStringArray = option_id.split(":")
		var consume_siege: bool = parts.size() >= 3 and parts[1] == "1"
		var use_inferno: bool = not (parts.size() >= 3 and parts[2] == "0")
		var committed_choice: Dictionary = controller.commitment_choices.get(0, {})
		return {
			"target_castle": String(committed_choice.get("target_castle", "")),
			"consume_siege": consume_siege,
			"use_inferno": use_inferno,
		}

	if human.action == "Profane":
		var profane_choice: Dictionary = controller.commitment_choices.get(0, {})
		return {"target_castle": String(profane_choice.get("target_castle", ""))}

	return {}


func _build_reflex_decision(
	use_secondary_target: bool = false
) -> Dictionary:
	var target_id: String = (
		_selected_secondary_target_id()
		if use_secondary_target
		else _selected_target_id()
	)
	var decision: Dictionary = {
		"action": selected_action,
		"cards": _selected_card_ids(),
	}

	match selected_action:
		"Hunt":
			var hunt_parts: PackedStringArray = target_id.split("|")
			decision["consume_hunt"] = hunt_parts.size() >= 2 and hunt_parts[1] == "1"
		"Siege":
			var siege_parts: PackedStringArray = target_id.split("|")
			decision["target_castle"] = siege_parts[0] if not siege_parts.is_empty() else ""
			decision["consume_siege"] = siege_parts.size() >= 2 and siege_parts[1] == "1"
			decision["use_inferno"] = not (siege_parts.size() >= 3 and siege_parts[2] == "0")
		"Ward":
			decision["ward_target"] = target_id

	return decision


func _build_odradek_breach_decision() -> Dictionary:
	return {
		"guess": _selected_target_id(),
		"stolen_action": _build_reflex_decision(true),
	}


func _selected_card_ids() -> Array[String]:
	var result: Array[String] = []

	for button: Button in card_buttons:
		if button.button_pressed:
			result.append(
				String(
					button.get_meta(
						"card_id",
						""
					)
				)
			)

	return result


func _selected_card_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for button: Button in card_buttons:
		if not button.button_pressed:
			continue
		result.append({
			"card_id": String(button.get_meta("card_id", "")),
			"source": String(button.get_meta("card_source", "Hand")),
			"source_index": int(button.get_meta("source_index", -1)),
		})

	return result


func _finish_deploy_guard_picker() -> void:
	if (
		controller == null
		or controller.stage != PlayableRoundControllerData.Stage.DEPLOY
	):
		return

	if not _queue_current_deploy_selection():
		return

	if deploy_target_zone == "Lord":
		deploy_target_zone = "Castle"
		_build_hand_buttons(true)
		_refresh_target_options()
		_set_phase_message(_deploy_picker_prompt())
		_refresh_all()
		return

	var deploy_decision: Dictionary = (
		{"pass": true}
		if queued_deploy_moves.is_empty()
		else {"moves": queued_deploy_moves.duplicate(true)}
	)
	var deploy_result: Dictionary = controller.resolve_human_deploy(
		deploy_decision
	)

	if _show_failure_if_needed(deploy_result, false):
		_set_phase_message(
			"Deploy rejected: %s"
			% String(deploy_result.get("reason", "invalid_deploy"))
		)
		return

	_after_development(deploy_result)


func _queue_current_deploy_selection() -> bool:
	var entries: Array[Dictionary] = _selected_card_entries()
	var limit: int = _deploy_selection_limit()

	if entries.size() > limit:
		_set_phase_message(
			"%s Guard zone has room for only %d more card%s."
			% [
				deploy_target_zone,
				limit,
				"" if limit == 1 else "s",
			]
		)
		return false

	if _selected_deploy_garrison_count() > _deploy_garrison_moves_remaining():
		_set_phase_message(
			"Only %d Garrison deployment%s remain this round."
			% [
				_deploy_garrison_moves_remaining(),
				"" if _deploy_garrison_moves_remaining() == 1 else "s",
			]
		)
		return false

	for entry: Dictionary in entries:
		queued_deploy_moves.append({
			"source": String(entry.get("source", "Hand")),
			"target": deploy_target_zone,
			"card": String(entry.get("card_id", "")),
			# Re-resolve by card identity after each move so an earlier removal
			# never leaves a later source index stale.
			"source_index": -1,
		})

	return true


func _deploy_selection_limit() -> int:
	if controller == null or controller.game == null:
		return 0

	var human = controller.get_human_player()
	if human == null:
		return 0

	var target_key: String = deploy_target_zone.to_lower()
	var guard_count: int = (
		human.lord_guards.size()
		if target_key == "lord"
		else human.castle_guards.size()
	)

	for move: Dictionary in queued_deploy_moves:
		if String(move.get("target", "")).to_lower() == target_key:
			guard_count += 1

	var open_slots: int = max(
		0,
		int(
			DeployEngineData._target_limit(
				human,
				controller.rules,
				target_key
			)
		) - guard_count
	)

	if bool(human.orias_snare_active):
		open_slots = min(
			open_slots,
			max(0, 1 - queued_deploy_moves.size())
		)

	return open_slots


func _deploy_zone_limit() -> int:
	if controller == null or controller.game == null:
		return 0

	var human = controller.get_human_player()
	if human == null:
		return 0

	return int(
		DeployEngineData._target_limit(
			human,
			controller.rules,
			deploy_target_zone.to_lower()
		)
	)


func _deploy_current_guard_count() -> int:
	if controller == null or controller.game == null:
		return 0

	var human = controller.get_human_player()
	if human == null:
		return 0

	return (
		human.lord_guards.size()
		if deploy_target_zone == "Lord"
		else human.castle_guards.size()
	)


func _deploy_hand_allowed() -> bool:
	var human = controller.get_human_player()
	return (
		human != null
		and (
			not bool(human.repaired_this_round)
			or bool(human.repair_token_used_this_repair)
		)
	)


func _deploy_garrison_allowed() -> bool:
	var human = controller.get_human_player()
	return (
		human != null
		and _deploy_garrison_moves_remaining() > 0
		and not DeployEngineData._frenzy_blocks_garrison(
			controller.game,
			human
		)
	)


func _deploy_garrison_moves_remaining() -> int:
	if controller == null or controller.rules == null:
		return 0

	var queued_garrison_moves: int = 0
	for move: Dictionary in queued_deploy_moves:
		if String(move.get("source", "")) == "Garrison":
			queued_garrison_moves += 1

	return max(
		0,
		int(controller.rules.garrison_max) - queued_garrison_moves
	)


func _selected_deploy_garrison_count() -> int:
	var selected_garrison_cards: int = 0
	for entry: Dictionary in _selected_card_entries():
		if String(entry.get("source", "")) == "Garrison":
			selected_garrison_cards += 1

	return selected_garrison_cards


func _is_deploy_card_reserved(
	source: String,
	card_identifier: String
) -> bool:
	for move: Dictionary in queued_deploy_moves:
		if (
			String(move.get("source", "")) == source
			and String(move.get("card", "")) == card_identifier
		):
			return true

	return false


func _deploy_picker_prompt() -> String:
	var open_slots: int = _deploy_selection_limit()
	var current_guards: int = _deploy_current_guard_count()
	var zone_limit: int = _deploy_zone_limit()
	var next_text: String = (
		"Next: Castle Guards"
		if deploy_target_zone == "Lord"
		else "Finish Deploy"
	)

	var prompt: String = (
		"%s Guards — select up to %d card%s (currently %d/%d deployed), then %s."
		% [
			deploy_target_zone,
			open_slots,
			"" if open_slots == 1 else "s",
			current_guards,
			zone_limit,
			next_text,
		]
	)

	var human = controller.get_human_player()
	if human != null and bool(human.orias_snare_active):
		prompt += " Orias Snare allows only one total deployment."
	elif not _deploy_hand_allowed():
		prompt += " Hand deployment is blocked by this round's Repair."
	elif (
		human != null
		and not _deploy_garrison_allowed()
		and not human.garrison.is_empty()
	):
		prompt += " Garrison deployment is unavailable this step."

	return prompt


func _march_picker_prompt() -> String:
	if controller == null or controller.game == null:
		return "Marching Orders"

	var human = controller.get_human_player()
	if human == null:
		return "Marching Orders"

	var reactive_lane: String = controller.human_reactive_march_lane()
	if not controller.human_can_launch_marcher():
		return "You already have a marcher in flight and no Reactive Lane is available. Pass this step."

	var source_zone: String = _selected_target_id()
	var guards: Array = (
		human.lord_guards
		if source_zone == "Lord"
		else human.castle_guards
	)
	if guards.is_empty():
		return "No %s Guards are available to march. Choose the other zone or pass." % source_zone

	var lane_instruction: String = (
		"Reactive Lane is active: your marcher is forced into the occupied %s lane. "
		% reactive_lane
		if not reactive_lane.is_empty()
		else "Choose either lane. "
	)
	return (
		"1. Choose a Guard zone.  2. Select one %s Guard.  "
		+ "3. %s4. Launch it face-up. "
		+ "Value %d+ at the enemy gate gains a personal Tear. "
		+ "RPS: Wright > Penitent > Vulture > Butcher > Wright; advantage adds +%d clash damage."
	) % [
		source_zone,
		lane_instruction,
		controller.rules.march_threshold,
		controller.rules.march_suit_bonus,
	]

func _hand_caption_text() -> String:
	if controller == null or controller.game == null:
		return "Commit cards (click to select):"

	if controller.stage == PlayableRoundControllerData.Stage.KANIFOUS_INVOKE:
		return "Invoke toll — choose exactly one Hand card to discard:"

	if controller.stage == PlayableRoundControllerData.Stage.MARKET:
		return "Give one Hand card (★ marks the strongest raw-value trade):"

	if controller.stage == PlayableRoundControllerData.Stage.REPAIR:
		var castle_name: String = _selected_target_id()
		if castle_name.is_empty():
			return "Choose a Ruined Castle to see its payment requirement:"
		return "Pay %d to repair %s (Hand or Garrison):" % [
			_selected_repair_cost(),
			castle_name,
		]

	if controller.stage == PlayableRoundControllerData.Stage.DEPLOY:
		if _deploy_selection_limit() <= 0:
			return "%s Guard zone is full or unavailable — continue when ready." % deploy_target_zone
		return "Select cards for %s Guards:" % deploy_target_zone

	if controller.stage == PlayableRoundControllerData.Stage.MARCH:
		return "2. Choose one face-up Guard from %s:" % _selected_target_id()

	return "Commit cards (click to select):"


func _repair_cost(
	castle_name: String,
	use_token: bool
) -> int:
	if controller == null or controller.game == null or castle_name.is_empty():
		return 0

	var human = controller.get_human_player()
	if human == null:
		return 0

	return RoundEngineData.repair_cost_for(
		controller.game,
		human,
		castle_name,
		use_token,
		controller.rules
	)


func _selected_repair_cost() -> int:
	return _repair_cost(
		_selected_target_id(),
		development_option_button != null and development_option_button.button_pressed
	)


func _repair_cost_info() -> String:
	var castle_name: String = _selected_target_id()
	if castle_name.is_empty():
		return "[color=#a99eac]Choose a Ruined Castle to see its exact Repair cost.[/color]"

	var normal_cost: int = _repair_cost(castle_name, false)
	var active_cost: int = _selected_repair_cost()
	var selected_payment: int = _selected_card_value()
	var human = controller.get_human_player()
	var token_text: String = ""

	if human != null and int(human.repair_token) > 0:
		token_text = "  ·  %d with Repair Token" % _repair_cost(castle_name, true)

	return (
		"[color=#82c9ff][b]%s Repair:[/b] cost %d%s  |  "
		+ "selected payment %d/%d[/color]"
	) % [
		castle_name,
		normal_cost,
		token_text,
		selected_payment,
		active_cost,
	]


func _best_market_give_card_id() -> String:
	if controller == null or controller.game == null:
		return ""

	var human = controller.get_human_player()
	if human == null or human.hand.is_empty() or controller.game.market.is_empty():
		return ""

	var lowest_hand_card = human.hand[0]
	var highest_market_card = controller.game.market[0]

	for hand_card in human.hand:
		if int(hand_card.value) < int(lowest_hand_card.value):
			lowest_hand_card = hand_card

	for market_card in controller.game.market:
		if int(market_card.value) > int(highest_market_card.value):
			highest_market_card = market_card

	if int(highest_market_card.value) <= int(lowest_hand_card.value):
		return ""

	return _card_id(lowest_hand_card)


func _best_market_take_card_id() -> String:
	if _best_market_give_card_id().is_empty():
		return ""

	var highest_market_card = controller.game.market[0]
	for market_card in controller.game.market:
		if int(market_card.value) > int(highest_market_card.value):
			highest_market_card = market_card

	return _card_id(highest_market_card)


func _market_selected_hand_value() -> int:
	var selected_cards: Array[String] = _selected_card_ids()
	if selected_cards.size() != 1:
		return -1

	for button: Button in card_buttons:
		if button.button_pressed:
			return int(button.get_meta("card_value", -1))

	return -1


func _market_trade_label(
	market_card,
	give_value: int,
	is_best_take: bool
) -> String:
	var label: String = _card_id(market_card)
	if give_value >= 0:
		var delta: int = int(market_card.value) - give_value
		if delta > 0:
			return "%s  ★ +%d" % [label, delta]
		if delta == 0:
			return "%s  = even" % label
		return "%s  −%d" % [label, -delta]

	if is_best_take:
		return "%s  ★ BEST TAKE" % label

	return label


func _market_trade_info() -> String:
	var suggested_give: String = _best_market_give_card_id()
	var suggested_take: String = _best_market_take_card_id()
	var give_value: int = _market_selected_hand_value()
	var take_id: String = _selected_target_id()

	if give_value < 0:
		if suggested_give.is_empty() or suggested_take.is_empty():
			return "[color=#a99eac]No raw-value upgrade is available; trade for suit or tactical value, or pass.[/color]"
		return (
			"[color=#f2d477][b]Suggested trade:[/b] give %s for %s. "
			+ "That is the largest raw-value upgrade.[/color]"
		) % [suggested_give, suggested_take]

	var taken_card = null
	for market_card in controller.game.market:
		if _card_id(market_card) == take_id:
			taken_card = market_card
			break

	if taken_card == null:
		return "[color=#a99eac]Choose a Market card to complete the trade.[/color]"

	var delta: int = int(taken_card.value) - give_value
	if delta > 0:
		return "[color=#8ee5a1][b]Beneficial trade:[/b] +%d raw card value.[/color]" % delta
	if delta == 0:
		return "[color=#f2d477]Even raw-value trade — choose it for suit or timing value.[/color]"
	return "[color=#e69a9a]This trade loses %d raw card value.[/color]" % -delta


func _selected_wright_guard_indices() -> Array[int]:
	var result: Array[int] = []
	for button: Button in card_buttons:
		if not button.button_pressed:
			continue
		if String(button.get_meta("card_source", "")) != "LordGuard":
			continue
		result.append(int(button.get_meta("source_index", -1)))
	return result


func _selected_card_value() -> int:
	var total: int = 0

	for button: Button in card_buttons:
		if button.button_pressed:
			total += int(
				button.get_meta(
					"card_value",
					0
				)
			)

	return total


func _projected_attack_strength() -> int:
	var total: int = _selected_card_value()
	if (
		controller != null
		and controller.game != null
		and selected_action in ["Hunt", "Siege"]
	):
		var human = controller.get_human_player()
		if (
			controller.rules.odr_recoil_bank
			and human.lord == "Odradek"
			and human.odradek_bank != null
		):
			total += int(human.odradek_bank.value)
	return total


func _refresh_selection_text() -> void:
	var count: int = _selected_card_ids().size()

	if (
		controller != null
		and controller.stage
			== PlayableRoundControllerData.Stage.SUMMON
	):
		selection_label.text = (
			"%d cards · payment %d/%d"
			% [
				count,
				_selected_card_value(),
				controller.human_summon_cost(),
			]
		)
	elif (
		controller != null
		and controller.stage == PlayableRoundControllerData.Stage.REPAIR
	):
		var repair_cost: int = _selected_repair_cost()
		selection_label.text = (
			"%d cards · payment %d/%d"
			% [
				count,
				_selected_card_value(),
				repair_cost,
			]
		)
	elif (
		controller != null
		and controller.stage == PlayableRoundControllerData.Stage.DOMINION_RITES
	):
		selection_label.text = "%d cards · Invocation payment %d/11" % [count, _selected_card_value()]
	elif (
		controller != null
		and controller.stage == PlayableRoundControllerData.Stage.REFLEX_BID
	):
		selection_label.text = "%d cards · bid %d" % [count, _selected_card_value()]
	elif (
		controller != null
		and controller.stage == PlayableRoundControllerData.Stage.DEPLOY
	):
		selection_label.text = (
			"%s Guards: %d/%d selected · %d move%s reserved"
			% [
				deploy_target_zone,
				count,
				_deploy_selection_limit(),
				queued_deploy_moves.size(),
				"" if queued_deploy_moves.size() == 1 else "s",
			]
		)
	elif (
		controller != null
		and controller.stage == PlayableRoundControllerData.Stage.MARCH
	):
		selection_label.text = "Step 2: %d/1 Guard · Step 3: %s lane" % [
			count,
			_selected_secondary_target_id(),
		]
	elif (
		controller != null
		and controller.stage == PlayableRoundControllerData.Stage.KANIFOUS_WRIGHT
	):
		selection_label.text = "%d Lord Guards selected · move up to 2" % count
	else:
		var projected_strength: int = _projected_attack_strength()
		var bank_suffix: String = (
			" + Interlock bank"
			if projected_strength > _selected_card_value()
			else ""
		)
		selection_label.text = "%d selected%s · strength %d" % [
			count,
			bank_suffix,
			projected_strength,
		]

	var cards_enabled: bool = (
		controller != null
		and (
			controller.stage
				== PlayableRoundControllerData.Stage.SUMMON
			or controller.stage == PlayableRoundControllerData.Stage.MARKET
			or controller.stage == PlayableRoundControllerData.Stage.REPAIR
			or controller.stage == PlayableRoundControllerData.Stage.DOMINION_RITES
			or controller.stage == PlayableRoundControllerData.Stage.DEPLOY
			or controller.stage == PlayableRoundControllerData.Stage.MARCH
			or controller.stage == PlayableRoundControllerData.Stage.REFLEX_BID
			or controller.stage == PlayableRoundControllerData.Stage.RESOLUTION_REFLEX
			or controller.stage == PlayableRoundControllerData.Stage.RESOLUTION_ODRADEK_BREACH
			or controller.stage == PlayableRoundControllerData.Stage.RESOLUTION_GREMORY
			or controller.stage == PlayableRoundControllerData.Stage.KANIFOUS_WRIGHT
			or (
				controller.stage
					== PlayableRoundControllerData.Stage.COMMITMENT
				and selected_action != "Profane"
			)
		)
	)

	for button: Button in card_buttons:
		button.disabled = not cards_enabled

	_refresh_target_info()


func _set_commitment_controls_enabled(
	enabled: bool
) -> void:
	for action_name: String in ACTIONS:
		var button: Button = action_buttons.get(
			action_name,
			null
		)

		if button != null:
			button.disabled = not enabled

	for card_button: Button in card_buttons:
		card_button.disabled = not enabled

	target_select.disabled = not enabled


func _clear_action_toggles() -> void:
	for action_name: String in ACTIONS:
		var button: Button = action_buttons.get(
			action_name,
			null
		)

		if button != null:
			button.set_pressed_no_signal(
				false
			)


func _clear_card_selection() -> void:
	for button: Button in card_buttons:
		button.set_pressed_no_signal(
			false
		)

	_refresh_selection_text()
	_refresh_staging_area()


func _clear_reveal() -> void:
	reveal_label.text = (
		"[center][color=#948b9e]"
		+ "Orders remain hidden until both sides seal."
		+ "[/color][/center]"
	)


func _show_terminal() -> void:
	var game = controller.game
	var winner = game.get_player(
		int(
			game.winner
		)
	)
	var winner_name: String = (
		"Unknown"
		if winner == null
		else String(
			winner.lord
		)
	)

	reveal_label.text = (
		"[center][font_size=24][b]%s wins[/b][/font_size]\n"
		+ "%s · round %d[/center]"
	) % [
		winner_name,
		String(
			game.win_by
		),
		int(
			game.round
		),
	]

	_log(
		"[b]%s wins by %s in round %d.[/b]"
		% [
			winner_name,
			String(
				game.win_by
			),
			int(
				game.round
			),
		]
	)

	_refresh_all()


func _show_failure_if_needed(
	result: Dictionary,
	lock_interface: bool = true
) -> bool:
	if String(
		result.get(
			"action",
			""
		)
	) != "invalid":
		return false

	var reason: String = String(
		result.get(
			"reason",
			"unknown_failure"
		)
	)

	_log(
		"[color=#ff748f][b]HALTED[/b] %s: %s[/color]"
		% [
			String(
				result.get(
					"stopped_phase",
					"unknown"
				)
			),
			reason,
		]
	)

	if lock_interface:
		controller.stage = (
			PlayableRoundControllerData.Stage.INVALID
		)
		_refresh_all()

	return true


func _set_phase_message(
	message: String
) -> void:
	phase_label.text = message


func _state_digest() -> Dictionary:
	var game = controller.game
	var players: Array = []

	for player in game.players:
		players.append({
			"lord": String(
				player.lord
			),
			"souls": int(
				player.souls
			),
			"tears": int(
				player.tears
			),
			"threat": int(
				player.threat
			),
			"alive": bool(
				player.alive
			),
			"castles": player.castles.size(),
			"lord_guards": player.lord_guards.size(),
			"castle_guards": player.castle_guards.size(),
		})

	return {
		"veil": int(
			game.calculate_veil_total()
		),
		"breach": String(
			game.breach
		),
		"players": players,
	}


func _log_resolution_transcript(
	round_result: Dictionary
) -> void:
	var resolution_result: Dictionary = (
		_resolution_result_from(
			round_result
		)
	)

	if resolution_result.is_empty():
		return

	var prelude_raw = resolution_result.get(
		"prelude_result",
		{}
	)

	if typeof(
		prelude_raw
	) == TYPE_DICTIONARY:
		var prelude: Dictionary = prelude_raw
		_log_resolution_order(
			prelude
		)
		_log_prelude_lord_powers(
			prelude
		)
		_log_prelude_global_events(
			prelude
		)

	for raw_event in _array_from(
		resolution_result.get(
			"action_events",
			[]
		)
	):
		if typeof(
			raw_event
		) != TYPE_DICTIONARY:
			continue

		var event: Dictionary = raw_event
		var action_result_raw = event.get(
			"action_result",
			{}
		)
		var aftermath_result_raw = event.get(
			"aftermath_result",
			{}
		)
		var action_result_for_cause: Dictionary = {}
		var aftermath_for_cause: Dictionary = {}

		if typeof(
			action_result_raw
		) == TYPE_DICTIONARY:
			var action_result: Dictionary = (
				action_result_raw
			)
			action_result_for_cause = action_result
			_log_action_outcome(
				action_result,
				"Primary",
				String(
					event.get(
						"committed_action",
						""
					)
				)
			)
			_log_combat_sigil_result(
				action_result
			)
			_log_action_lord_powers(
				action_result
			)

		if typeof(
			aftermath_result_raw
		) == TYPE_DICTIONARY:
			var aftermath_result: Dictionary = (
				aftermath_result_raw
			)
			aftermath_for_cause = aftermath_result
			_log_aftermath_lord_powers(
				aftermath_result
			)

		if (
			bool(
				action_result_for_cause.get(
					"won",
					false
				)
			)
			and bool(
				aftermath_for_cause.get(
					"stopped_on_win",
					false
				)
			)
			and not _aftermath_offered_vessel(
				aftermath_for_cause
			)
		):
			_log_victory_cause(
				"%s's %s"
				% [
					_player_name(
						int(
							event.get(
								"player_id",
								-1
							)
						)
					),
					String(
						event.get(
							"committed_action",
							"action"
						)
					),
				]
			)
		elif (
			not bool(
				action_result_for_cause.get(
					"won",
					false
				)
			)
			and bool(
				aftermath_for_cause.get(
					"stopped_on_win",
					false
				)
			)
			and not _aftermath_offered_vessel(
				aftermath_for_cause
			)
		):
			_log_victory_cause(
				"the action aftermath"
			)

	var reflex_raw = resolution_result.get(
		"reflex_result",
		{}
	)

	if typeof(
		reflex_raw
	) == TYPE_DICTIONARY:
		var reflex: Dictionary = reflex_raw

		if String(
			reflex.get(
				"action",
				""
			)
		) == "reflex_action":
			_log_reflex_resolution(
				round_result
			)

			var reflex_action_raw = reflex.get(
				"action_result",
				{}
			)

			if typeof(
				reflex_action_raw
			) == TYPE_DICTIONARY:
				var reflex_action: Dictionary = (
					reflex_action_raw
				)
				_log_action_outcome(
					reflex_action,
					_second_action_name(),
					String(
						reflex.get(
							"executed_action",
							""
						)
					)
				)
				_log_combat_sigil_result(
					reflex_action
				)
				_log_action_lord_powers(
					reflex_action
				)

			if bool(
				reflex.get(
					"won",
					false
				)
			):
				_log_victory_cause(
					"%s's %s %s"
					% [
						_player_name(
							int(
								reflex.get(
									"executed_by",
									-1
								)
							)
						),
						_second_action_name(),
						String(
							reflex.get(
								"executed_action",
								"action"
							)
						),
					]
				)

	_log_finale_lord_powers(
		resolution_result.get(
			"finale_result",
			{}
		)
	)
	_log_cleanup_lord_powers(
		resolution_result.get(
			"cleanup_result",
			{}
		)
	)

	var stopped_stage: String = String(
		resolution_result.get(
			"stopped_stage",
			""
		)
	)

	if (
		not stopped_stage.is_empty()
		and int(
			resolution_result.get(
				"winner",
				-1
			)
		) >= 0
	):
		_log(
			"[color=#f2d477][b]Victory checkpoint:[/b] Resolution stopped after %s because %s had been achieved.[/color]"
			% [
				stopped_stage.capitalize(),
				String(
					resolution_result.get(
						"win_by",
						"victory"
					)
				),
			]
		)


func _resolution_result_from(
	round_result: Dictionary
) -> Dictionary:
	var phases_raw = round_result.get(
		"phases",
		{}
	)

	if typeof(
		phases_raw
	) != TYPE_DICTIONARY:
		return {}

	var phases: Dictionary = phases_raw
	var resolution_phase_raw = phases.get(
		"resolution",
		{}
	)

	if typeof(
		resolution_phase_raw
	) != TYPE_DICTIONARY:
		return {}

	var resolution_phase: Dictionary = (
		resolution_phase_raw
	)
	var result_raw = resolution_phase.get(
		"result",
		{}
	)

	if typeof(
		result_raw
	) != TYPE_DICTIONARY:
		return {}

	var result: Dictionary = result_raw

	return result


func _aftermath_offered_vessel(
	aftermath: Dictionary
) -> bool:
	var vessel_raw = aftermath.get(
		"vessel_event",
		{}
	)

	if typeof(
		vessel_raw
	) != TYPE_DICTIONARY:
		return false

	var vessel: Dictionary = vessel_raw

	return String(
		vessel.get(
			"action",
			""
		)
	) == "offer_vessel"


func _log_resolution_order(
	prelude: Dictionary
) -> void:
	var order: Array = _array_from(
		prelude.get(
			"order",
			[]
		)
	)

	if order.size() < 2:
		return

	var committed: Array = _array_from(
		prelude.get(
			"committed_values",
			[]
		)
	)
	var totals: String = ""

	if committed.size() >= 2:
		totals = " (%d–%d)" % [
			int(
				committed[0]
			),
			int(
				committed[1]
			),
		]

	var tie_text: String = ""

	if bool(
		prelude.get(
			"tied",
			false
		)
	):
		tie_text = (
			"; tied commitments use the round's first player"
		)

	_log(
		"[color=#c8b36a][b]Resolution order:[/b] %s acts before %s%s%s.[/color]"
		% [
			_player_name(
				int(
					order[0]
				)
			),
			_player_name(
				int(
					order[1]
				)
			),
			totals,
			tie_text,
		]
	)


func _log_prelude_global_events(
	prelude: Dictionary
) -> void:
	for raw_event in _array_from(
		prelude.get(
			"collapse_events",
			[]
		)
	):
		if typeof(
			raw_event
		) != TYPE_DICTIONARY:
			continue

		var event: Dictionary = raw_event
		var discarded_card: String = String(
			event.get(
				"discarded_card",
				""
			)
		)

		if discarded_card.is_empty():
			continue

		_log(
			"[color=#f2d477][b]Veil Collapse:[/b] %s's previously attacked %s zone lost its lowest Guard, %s.[/color]"
			% [
				_player_name(
					int(
						event.get(
							"player_id",
							-1
						)
					)
				),
				String(
					event.get(
						"zone",
						"?"
					)
				),
				discarded_card,
			]
		)

	for raw_event in _array_from(
		prelude.get(
			"waning_events",
			[]
		)
	):
		if typeof(
			raw_event
		) != TYPE_DICTIONARY:
			continue

		var event: Dictionary = raw_event

		if String(
			event.get(
				"source",
				""
			)
		) != "veil_waning":
			continue

		var discarded_card: String = String(
			event.get(
				"discarded_card",
				""
			)
		)

		if discarded_card.is_empty():
			continue

		_log(
			"[color=#f2d477][b]Veil Waning:[/b] %s's previously attacked %s zone lost %s.[/color]"
			% [
				_player_name(
					int(
						event.get(
							"player_id",
							-1
						)
					)
				),
				String(
					event.get(
						"zone",
						"?"
					)
				),
				discarded_card,
			]
		)


func _log_action_outcome(
	action_result: Dictionary,
	source_name: String,
	requested_action: String
) -> void:
	var action_name: String = String(
		action_result.get(
			"action",
			""
		)
	)

	if action_name == "pass":
		if requested_action == "Pass":
			return

		_log(
			"[color=#a9a1b0][b]%s %s skipped:[/b] %s.[/color]"
			% [
				source_name,
				requested_action,
				String(
					action_result.get(
						"reason",
						"no legal target"
					)
				).replace(
					"_",
					" "
				),
			]
		)
		return

	if action_name == "hunt":
		var defeated: Array = _array_from(
			action_result.get(
				"guards_defeated",
				[]
			)
		)
		var outcome: String = ""

		if bool(
			action_result.get(
				"banished",
				false
			)
		):
			outcome = "the Lord was banished"
		else:
			outcome = "the attack stopped at %s"
			outcome = outcome % String(
				action_result.get(
					"stopped_at",
					"the defenses"
				)
			)

		_log(
			"[color=#e8e2eb][b]%s Hunt:[/b] %s attacked %s's Lord with %d strength against Lord DEF %d; defeated %s; %s%s.[/color]"
			% [
				source_name,
				_player_name(
					int(
						action_result.get(
							"attacker_id",
							-1
						)
					)
				),
				_player_name(
					int(
						action_result.get(
							"defender_id",
							-1
						)
					)
				),
				int(
					action_result.get(
						"strength",
						0
					)
				),
				int(
					action_result.get(
						"lord_defense",
						0
					)
				),
				(
					_string_values_inline(
						defeated
					)
					if not defeated.is_empty()
					else "no Guards"
				),
				outcome,
				(
					"; excess %d"
					% int(
						action_result.get(
							"excess",
							0
						)
					)
					if bool(
						action_result.get(
							"banished",
							false
						)
					)
					else ""
				),
			]
		)

		return

	if action_name == "siege":
		var defeated: Array = _array_from(
			action_result.get(
				"guards_defeated",
				[]
			)
		)
		var outcome: String = ""

		if bool(
			action_result.get(
				"destroyed",
				false
			)
		):
			outcome = "the Castle was ruined"
		else:
			outcome = "the attack stopped at %s"
			outcome = outcome % String(
				action_result.get(
					"stopped_at",
					"the defenses"
				)
			)

		_log(
			"[color=#e8e2eb][b]%s Siege:[/b] %s attacked %s's %s with %d strength against structural DEF %d; defeated %s; %s%s.[/color]"
			% [
				source_name,
				_player_name(
					int(
						action_result.get(
							"attacker_id",
							-1
						)
					)
				),
				_player_name(
					int(
						action_result.get(
							"defender_id",
							-1
						)
					)
				),
				String(
					action_result.get(
						"target_castle",
						"Castle"
					)
				),
				int(
					action_result.get(
						"strength",
						0
					)
				),
				int(
					action_result.get(
						"structural_defense",
						0
					)
				),
				(
					_string_values_inline(
						defeated
					)
					if not defeated.is_empty()
					else "no Guards"
				),
				outcome,
				(
					"; excess %d"
					% int(
						action_result.get(
							"excess",
							0
						)
					)
					if bool(
						action_result.get(
							"destroyed",
							false
						)
					)
					else ""
				),
			]
		)

		return

	if action_name == "ward":
		_log(
			"[color=#91c7ff][b]%s Ward:[/b] %s protected the %s zone; its sigil is %s.[/color]"
			% [
				source_name,
				_player_name(
					int(
						action_result.get(
							"player_id",
							-1
						)
					)
				),
				String(
					action_result.get(
						"ward_target",
						"?"
					)
				),
				String(
					action_result.get(
						"sigil_state",
						"none"
					)
				),
			]
		)
		return

	if action_name == "profane":
		var player_name: String = _player_name(
			int(
				action_result.get(
					"player_id",
					-1
				)
			)
		)

		if bool(
			action_result.get(
				"blocked",
				false
			)
		):
			_log(
				"[color=#91c7ff][b]%s Profane blocked:[/b] %s's fresh %s sigil denied the corruption of %s.[/color]"
				% [
					source_name,
					_player_name(
						int(
							action_result.get(
								"opponent_id",
								-1
							)
						)
					),
					String(
						action_result.get(
							"blocking_zone",
							"?"
						)
					),
					String(
						action_result.get(
							"target_castle",
							"Castle"
						)
					),
				]
			)
		else:
			_log(
				"[color=#c8b36a][b]%s Profane:[/b] %s profaned %s; its personal Tear will be awarded during Cleanup.[/color]"
				% [
					source_name,
					player_name,
					String(
						action_result.get(
							"target_castle",
							"Castle"
						)
					),
				]
			)


func _log_victory_cause(
	cause: String
) -> void:
	if (
		controller == null
		or controller.game == null
		or int(
			controller.game.winner
		) < 0
	):
		return

	_log(
		"[color=#f2d477][b]VICTORY TRIGGER — %s:[/b] %s is now the winner by %s.[/color]"
		% [
			cause,
			_player_name(
				int(
					controller.game.winner
				)
			),
			String(
				controller.game.win_by
			),
		]
	)


func _log_resolution_lord_powers(
	round_result: Dictionary
) -> void:
	var phases = round_result.get(
		"phases",
		{}
	)

	if typeof(
		phases
	) != TYPE_DICTIONARY:
		return

	var resolution_phase = phases.get(
		"resolution",
		{}
	)

	if typeof(
		resolution_phase
	) != TYPE_DICTIONARY:
		return

	var resolution_result = resolution_phase.get(
		"result",
		{}
	)

	if typeof(
		resolution_result
	) != TYPE_DICTIONARY:
		return

	_log_prelude_lord_powers(
		resolution_result.get(
			"prelude_result",
			{}
		)
	)

	for raw_event in _array_from(
		resolution_result.get(
			"action_events",
			[]
		)
	):
		if typeof(
			raw_event
		) != TYPE_DICTIONARY:
			continue

		var event: Dictionary = raw_event
		var action_result = event.get(
			"action_result",
			{}
		)
		var aftermath_result = event.get(
			"aftermath_result",
			{}
		)

		if typeof(
			action_result
		) == TYPE_DICTIONARY:
			_log_action_lord_powers(
				action_result
			)

		if typeof(
			aftermath_result
		) == TYPE_DICTIONARY:
			_log_aftermath_lord_powers(
				aftermath_result
			)

	var reflex = resolution_result.get(
		"reflex_result",
		{}
	)

	if typeof(
		reflex
	) == TYPE_DICTIONARY:
		var reflex_action_result = reflex.get(
			"action_result",
			{}
		)

		if typeof(
			reflex_action_result
		) == TYPE_DICTIONARY:
			_log_action_lord_powers(
				reflex_action_result
			)

	_log_finale_lord_powers(
		resolution_result.get(
			"finale_result",
			{}
		)
	)
	_log_cleanup_lord_powers(
		resolution_result.get(
			"cleanup_result",
			{}
		)
	)


func _log_prelude_lord_powers(
	raw_prelude
) -> void:
	if typeof(
		raw_prelude
	) != TYPE_DICTIONARY:
		return

	var prelude: Dictionary = raw_prelude
	var scorch = prelude.get(
		"persistent_scorch",
		{}
	)

	if (
		typeof(
			scorch
		) == TYPE_DICTIONARY
		and bool(
			scorch.get(
				"applied",
				false
			)
		)
	):
		var discarded_cards: Array = _array_from(
			scorch.get(
				"discarded_cards",
				[]
			)
		)
		_log(
			"[color=#d8b4fe][b]Kalligan — Scorch:[/b] %s's %s zone %s.[/color]"
			% [
				_player_name(
					int(
						scorch.get(
							"player_id",
							-1
						)
					)
				),
				String(
					scorch.get(
						"zone",
						"?"
					)
				),
				(
					"discarded low Guards %s"
					% _string_values_inline(
						discarded_cards
					)
					if not discarded_cards.is_empty()
					else "had no value-1 or value-2 Guards to burn"
				),
			]
		)
		_log_gremory_guard_trigger(
			scorch.get(
				"gremory_trigger",
				{}
			),
			"Scorch"
		)

	for raw_event in _array_from(
		prelude.get(
			"waning_events",
			[]
		)
	):
		if typeof(
			raw_event
		) != TYPE_DICTIONARY:
			continue

		var event: Dictionary = raw_event

		if (
			String(
				event.get(
					"source",
					""
				)
			) != "valak_breach"
			or String(
				event.get(
					"discarded_card",
					""
				)
			).is_empty()
		):
			continue

		_log(
			"[color=#d8b4fe][b]Valak Breach — Gravitational Collapse:[/b] %s lost %s from the previously attacked %s zone.[/color]"
			% [
				_player_name(
					int(
						event.get(
							"player_id",
							-1
						)
					)
				),
				String(
					event.get(
						"discarded_card",
						"?"
					)
				),
				String(
					event.get(
						"zone",
						"?"
					)
				),
			]
		)

	for raw_event in _array_from(
		prelude.get(
			"humbaba_toll_events",
			[]
		)
	):
		if typeof(
			raw_event
		) != TYPE_DICTIONARY:
			continue

		var event: Dictionary = raw_event
		_log(
			"[color=#d8b4fe][b]Humbaba — Toll:[/b] %s ruined its own %s, removed 1 Soul from %s, and created 1 Neutral Tear.[/color]"
			% [
				_player_name(
					int(
						event.get(
							"player_id",
							-1
						)
					)
				),
				String(
					event.get(
						"ruined_castle",
						"Castle"
					)
				),
				_player_name(
					int(
						event.get(
							"opponent_id",
							-1
						)
					)
				),
			]
		)
		_log_harvest_event(
			event,
			"Toll"
		)

		var moved_guards: Array = _array_from(
			event.get(
				"moved_guards",
				[]
			)
		)
		var discarded_guards: Array = _array_from(
			event.get(
				"discarded_guards",
				[]
			)
		)

		if not moved_guards.is_empty():
			_log(
				"[color=#d8b4fe][b]Humbaba — Living Fortress:[/b] The lost fourth Castle-Guard slot moved %s to Garrison.[/color]"
				% _string_values_inline(
					moved_guards
				)
			)

		if not discarded_guards.is_empty():
			_log(
				"[color=#d8b4fe][b]Humbaba — Living Fortress:[/b] With Garrison full, the lost fourth slot discarded %s.[/color]"
				% _string_values_inline(
					discarded_guards
				)
			)

		if bool(
			event.get(
				"won",
				false
			)
		):
			_log_victory_cause(
				"Humbaba's Toll"
			)

	for raw_event in _array_from(
		prelude.get(
			"kroni_events",
			[]
		)
	):
		if typeof(
			raw_event
		) != TYPE_DICTIONARY:
			continue

		var event: Dictionary = raw_event
		var discarded_card: String = String(
			event.get(
				"discarded_card",
				""
			)
		)
		_log(
			"[color=#d8b4fe][b]Kroni — Hungering Aura:[/b] %s %s.[/color]"
			% [
				_player_name(
					int(
						event.get(
							"target_player_id",
							-1
						)
					)
				),
				(
					"discarded its lowest commitment, %s"
					% discarded_card
					if not discarded_card.is_empty()
					else "had no committed card to consume"
				),
			]
		)


func _log_action_lord_powers(
	action_result: Dictionary
) -> void:
	var action_name: String = String(
		action_result.get(
			"action",
			""
		)
	)

	if not [
		"hunt",
		"siege",
	].has(
		action_name
	):
		return

	var attacker_id: int = int(
		action_result.get(
			"attacker_id",
			-1
		)
	)
	var defender_id: int = int(
		action_result.get(
			"defender_id",
			-1
		)
	)
	var attacker = controller.game.get_player(
		attacker_id
	)
	var attacker_lord: String = (
		""
		if attacker == null
		else String(
			attacker.lord
		)
	)

	if (
		action_name == "hunt"
		and attacker_lord == "Orias"
		and String(
			action_result.get(
				"stopped_at",
				""
			)
		) != "ward_turned"
	):
		_log(
			"[color=#d8b4fe][b]Orias — Relentless Pursuit:[/b] Hunt strength bonuses applied; final strength %d.[/color]"
			% int(
				action_result.get(
					"strength",
					0
				)
			)
		)

		if not _array_from(
			action_result.get(
				"guards_defeated",
				[]
			)
		).is_empty():
			var defender = controller.game.get_player(
				defender_id
			)
			_log(
				"[color=#d8b4fe][b]Orias — The Mark:[/b] A Lord Guard fell; %s's Threat is now %d.[/color]"
				% [
					_player_name(
						defender_id
					),
					(
						0
						if defender == null
						else int(
							defender.threat
						)
					),
				]
			)

		var orias_banishment = action_result.get(
			"banishment",
			{}
		)

		if (
			typeof(
				orias_banishment
			) == TYPE_DICTIONARY
			and bool(
				action_result.get(
					"banished",
					false
				)
			)
		):
			_log(
				"[color=#d8b4fe][b]Orias — The Mark:[/b] %s was marked on banishment%s and will return with +1 Threat.[/color]"
				% [
					_player_name(
						defender_id
					),
					(
						"; Orias gained 2 bonus Souls"
						if int(
							orias_banishment.get(
								"orias_bonus",
								0
							)
						) > 0
						else ""
					),
				]
			)

	if action_name == "siege":
		var war_machine_bonus: int = int(
			action_result.get(
				"war_machine_bonus",
				0
			)
		)

		if attacker_lord == "Deimos":
			_log(
				"[color=#d8b4fe][b]Deimos — War Machine:[/b] Siege gained +%d strength.[/color]"
				% war_machine_bonus
			)

		var fear_card: String = String(
			action_result.get(
				"fear_returned_card",
				""
			)
		)

		if not fear_card.is_empty():
			_log(
				"[color=#d8b4fe][b]Deimos — Fear:[/b] Returned %s from %s's Castle Guards to Hand before combat.[/color]"
				% [
					fear_card,
					_player_name(
						defender_id
					),
				]
			)

		if String(
			action_result.get(
				"tear_source",
				""
			)
		) == "deimos_claim":
			_log(
				"[color=#d8b4fe][b]Deimos — Claim the Breach:[/b] The ruined Castle gave Deimos a personal Tear instead of a Neutral Tear.[/color]"
			)

		var pyroclasm_bonus: int = int(
			action_result.get(
				"pyroclasm_bonus",
				0
			)
		)

		if pyroclasm_bonus > 0:
			_log(
				"[color=#d8b4fe][b]Kalligan — Pyroclasm:[/b] Siege gained +%d strength.[/color]"
				% pyroclasm_bonus
			)

		var inferno_card: String = String(
			action_result.get(
				"inferno_card",
				""
			)
		)

		if not inferno_card.is_empty():
			_log(
				"[color=#d8b4fe][b]Kalligan — Inferno:[/b] Gained 1 Threat and burned the highest Lord Guard, %s.[/color]"
				% inferno_card
			)

		var wildfire_zone: String = String(
			action_result.get(
				"wildfire_zone",
				""
			)
		)

		if not wildfire_zone.is_empty():
			_log(
				"[color=#d8b4fe][b]Kalligan — Wildfire:[/b] Persistent Scorch now targets %s's %s zone.[/color]"
				% [
					_player_name(
						defender_id
					),
					wildfire_zone,
				]
			)

		_log_gremory_ruin_trigger(
			action_result.get(
				"gremory_ruin_trigger",
				{}
			),
			"the Castle ruin"
		)

		if bool(
			action_result.get(
				"ignore_lowest_guard",
				false
			)
		):
			var power_name: String = (
				"Valak — Crushing Presence"
				if attacker_lord == "Valak"
				else "Kanifous — Butcher Invocation"
			)
			_log(
				"[color=#d8b4fe][b]%s:[/b] The lowest target Guard contributed no defense.[/color]"
				% power_name
			)

	var siphoned_card: String = String(
		action_result.get(
			"siphoned_card",
			""
		)
	)

	if not siphoned_card.is_empty():
		_log(
			"[color=#d8b4fe][b]Valak — Siphon:[/b] After combat, discarded the lowest surviving Guard, %s.[/color]"
			% siphoned_card
		)

	var recoil_result_raw = action_result.get("recoil_result", {})
	if typeof(recoil_result_raw) == TYPE_DICTIONARY:
		_log_odradek_recoil_event(
			recoil_result_raw,
			attacker_id
		)

	if int(
		action_result.get(
			"ravenous_soul_gain",
			0
		)
	) > 0:
		_log(
			"[color=#d8b4fe][b]Kroni — Ravenous:[/b] The destruction granted +2 Souls and +1 Hunger; Ravenous is now spent.[/color]"
		)

	_log_gremory_guard_trigger(
		action_result.get(
			"gremory_guard_trigger",
			{}
		),
		"the defeated Lord Guard"
	)
	_log_gremory_guard_trigger(
		action_result.get(
			"siphon_gremory_trigger",
			{}
		),
		"Valak's Siphon"
	)

	var banishment = action_result.get(
		"banishment",
		{}
	)
	if typeof(banishment) == TYPE_DICTIONARY:
		var discarded_bank: String = String(banishment.get("discarded_bank", ""))
		if not discarded_bank.is_empty():
			_log("[color=#d8b4fe][b]Odradek was Banished:[/b] The banked %s was discarded.[/color]" % discarded_bank)

	if typeof(
		banishment
	) == TYPE_DICTIONARY:
		var kanifous_gain: int = int(
			banishment.get(
				"kanifous_soul_gain",
				0
			)
		)

		if kanifous_gain > 0:
			_log(
				"[color=#d8b4fe][b]Kanifous — Defiance:[/b] Banishment granted 1 Soul%s.[/color]"
				% (
					" and 2 cards"
					if not _array_from(
						banishment.get(
							"kanifous_draws",
							[]
						)
					).is_empty()
					else ""
				)
			)

	var butcher_suppressed_card: String = String(
		action_result.get(
			"butcher_suppressed_card",
			""
		)
	)

	if not butcher_suppressed_card.is_empty():
		_log(
			"[color=#d8b4fe][b]Kanifous — Butcher Invocation:[/b] Treated %s as already Defeated without triggering Defeat effects.[/color]"
			% butcher_suppressed_card
		)

		_log_gremory_ruin_trigger(
			banishment.get(
				"gremory_trigger",
				{}
			),
			"the Lord banishment"
		)

	_log_harvest_event(
		action_result,
		action_name.capitalize()
	)


func _log_aftermath_lord_powers(
	aftermath: Dictionary
) -> void:
	var player_id: int = int(
		aftermath.get(
			"player_id",
			-1
		)
	)

	for raw_event in _array_from(
		aftermath.get(
			"kroni_events",
			[]
		)
	):
		if typeof(
			raw_event
		) != TYPE_DICTIONARY:
			continue

		var event: Dictionary = raw_event
		_log(
			"[color=#d8b4fe][b]Kroni — Consume%s:[/b] Hunger %d→%d%s.[/color]"
			% [
				(
					" / Gorge"
					if int(
						event.get(
							"gorge_soul_gain",
							0
						)
					) > 0
					else ""
				),
				int(
					event.get(
						"hunger_before",
						0
					)
				),
				int(
					event.get(
						"hunger_after",
						0
					)
				),
				(
					"; personally defeating a Guard added 1 Soul"
					if int(
						event.get(
							"gorge_soul_gain",
							0
						)
					) > 0
					else ""
				),
			]
		)
		_log_harvest_event(
			event,
			"Kroni's Hunger"
		)

	var vessel_raw = aftermath.get(
		"vessel_event",
		{}
	)

	if typeof(
		vessel_raw
	) == TYPE_DICTIONARY:
		var vessel: Dictionary = vessel_raw

		if String(
			vessel.get(
				"action",
				""
			)
		) == "offer_vessel":
			var discarded_guards: Array = _array_from(
				vessel.get(
					"discarded_lord_guards",
					[]
				)
			)
			_log(
				"[color=#f2d477][b]VESSEL OFFERED — %s:[/b] %s sacrificed the living Lord and discarded %s; %s gained %d Soul and %s gained %d personal Tear.[/color]"
				% [
					String(
						vessel.get(
							"offered_lord",
							"Lord"
						)
					),
					_player_name(
						int(
							vessel.get(
								"player_id",
								player_id
							)
						)
					),
					(
						_string_values_inline(
							discarded_guards
						)
						if not discarded_guards.is_empty()
						else "no Lord Guards"
					),
					_player_name(
						int(
							vessel.get(
								"opponent_id",
								-1
							)
						)
					),
					int(
						vessel.get(
							"opponent_soul_gain",
							0
						)
					),
					_player_name(
						int(
							vessel.get(
								"player_id",
								player_id
							)
						)
					),
					int(
						vessel.get(
							"personal_tear_gain",
							0
						)
					),
				]
			)
			_log_harvest_event(
				vessel,
				"Vessel"
			)
			_log_gremory_guard_trigger(
				vessel.get(
					"gremory_guard_trigger",
					{}
				),
				"the Lord Guards Defeated by Offer the Vessel"
			)

			if bool(
				aftermath.get(
					"stopped_on_win",
					false
				)
			):
				_log_victory_cause(
					"the Vessel offering"
				)

	var vulture_draw: String = String(
		aftermath.get(
			"vulture_draw",
			""
		)
	)

	if not vulture_draw.is_empty():
		_log(
			"[color=#d8b4fe][b]Vulture pair:[/b] %s drew %s outside the Draw step.[/color]"
			% [
				_player_name(
					player_id
				),
				(
					vulture_draw
					if player_id == 0
					else "a hidden card"
				),
			]
		)

	if bool(
		aftermath.get(
			"wright_token_gained",
			false
		)
	):
		_log(
			"[color=#d8b4fe][b]Wright pair:[/b] %s gained a Repair token.[/color]"
			% _player_name(
				player_id
			)
		)

	var discarded_committed: Array = _array_from(
		aftermath.get(
			"discarded_committed",
			[]
		)
	)

	if not discarded_committed.is_empty():
		_log(
			"[color=#a9a1b0]Commitment spent: %s discarded %s.[/color]"
			% [
				_player_name(
					player_id
				),
				_string_values_inline(
					discarded_committed
				),
			]
		)


func _log_finale_lord_powers(
	raw_finale
) -> void:
	if typeof(
		raw_finale
	) != TYPE_DICTIONARY:
		return

	var finale: Dictionary = raw_finale

	for raw_event in _array_from(
		finale.get(
			"consume_events",
			[]
		)
	):
		if typeof(
			raw_event
		) != TYPE_DICTIONARY:
			continue

		var event: Dictionary = raw_event
		_log(
			"[color=#d8b4fe][b]Kroni — Consume:[/b] Hunger %d→%d at End of Round%s.[/color]"
			% [
				int(
					event.get(
						"hunger_before",
						0
					)
				),
				int(
					event.get(
						"hunger_after",
						0
					)
				),
				(
					"; Gorge granted 1 Soul"
					if int(
						event.get(
							"gorge_soul_gain",
							0
						)
					) > 0
					else ""
				),
			]
		)
		_log_harvest_event(
			event,
			"Consume"
		)

	for raw_event in _array_from(
		finale.get(
			"decay_events",
			[]
		)
	):
		if typeof(
			raw_event
		) != TYPE_DICTIONARY:
			continue

		var event: Dictionary = raw_event
		_log(
			"[color=#d8b4fe][b]Kroni — Hunger Decay:[/b] Hunger %d→%d after not choosing Hunt or Siege.[/color]"
			% [
				int(
					event.get(
						"hunger_before",
						0
					)
				),
				int(
					event.get(
						"hunger_after",
						0
					)
				),
			]
		)

	for raw_event in _array_from(
		finale.get(
			"fallback_events",
			[]
		)
	):
		if typeof(
			raw_event
		) != TYPE_DICTIONARY:
			continue

		var event: Dictionary = raw_event
		_log(
			"[color=#d8b4fe][b]Kroni — Fallback Consume:[/b] Removed %s from %s and from play; Hunger %d→%d.[/color]"
			% [
				String(
					event.get(
						"removed_card",
						"?"
					)
				),
				String(
					event.get(
						"zone",
						"?"
					)
				),
				int(
					event.get(
						"hunger_before",
						0
					)
				),
				int(
					event.get(
						"hunger_after",
						0
					)
				),
			]
		)
		_log_harvest_event(
			event,
			"Fallback Consume"
		)

	for raw_event in _array_from(
		finale.get(
			"breach_events",
			[]
		)
	):
		if typeof(
			raw_event
		) != TYPE_DICTIONARY:
			continue

		var event: Dictionary = raw_event
		_log(
			"[color=#d8b4fe][b]Kroni Breach:[/b] %s lost its lowest Guard, %s, from %s.[/color]"
			% [
				_player_name(
					int(
						event.get(
							"player_id",
							-1
						)
					)
				),
				String(
					event.get(
						"discarded_card",
						"?"
					)
				),
				String(
					event.get(
						"zone",
						"?"
					)
				),
			]
		)

	for raw_event in _array_from(
		finale.get(
			"reconfiguration_events",
			[]
		)
	):
		if typeof(
			raw_event
		) != TYPE_DICTIONARY:
			continue

		var event: Dictionary = raw_event

		if bool(
			event.get(
				"blocked",
				false
			)
		):
			_log(
				"[color=#d8b4fe][b]Odradek — Reconfiguration:[/b] Blocked because %d Guard(s) were defeated; tokens remain %d.[/color]"
				% [
					int(
						event.get(
							"guards_defeated",
							0
						)
					),
					int(
						event.get(
							"tokens_after",
							0
						)
					),
				]
			)
		else:
			_log(
				"[color=#d8b4fe][b]Odradek — Reconfiguration:[/b] Tokens %d→%d%s.[/color]"
				% [
					int(
						event.get(
							"tokens_before",
							0
						)
					),
					int(
						event.get(
							"tokens_after",
							0
						)
					),
					(
						"; spent 5 to gain a personal Tear"
						if int(
							event.get(
								"personal_tear_gain",
								0
							)
						) > 0
						else ""
					),
				]
			)
			_log_harvest_event(
				event,
				"Reconfiguration"
			)

			if bool(
				event.get(
					"won",
					false
				)
			):
				_log_victory_cause(
					"Odradek's Reconfiguration"
				)

	for raw_event in _array_from(
		finale.get(
			"state_events",
			[]
		)
	):
		if typeof(
			raw_event
		) != TYPE_DICTIONARY:
			continue

		var event: Dictionary = raw_event

		if (
			not bool(
				event.get(
					"patient_before",
					false
				)
			)
			and bool(
				event.get(
					"patient_after",
					false
				)
			)
		):
			_log(
				"[color=#d8b4fe][b]Humbaba — Patient:[/b] %s did not Hunt or Siege; one Sigil will be preserved through next upkeep.[/color]"
				% _player_name(
					int(
						event.get(
							"player_id",
							-1
						)
					)
				)
			)


func _log_cleanup_lord_powers(
	raw_cleanup
) -> void:
	if typeof(
		raw_cleanup
	) != TYPE_DICTIONARY:
		return

	var cleanup: Dictionary = raw_cleanup

	for raw_event in _array_from(
		cleanup.get(
			"gremory_events",
			[]
		)
	):
		if typeof(
			raw_event
		) != TYPE_DICTIONARY:
			continue

		var event: Dictionary = raw_event

		if String(
			event.get(
				"action",
				""
			)
		) != "inevitable_ruin":
			continue

		_log(
			"[color=#d8b4fe][b]Gremory — Inevitable Ruin:[/b] %s paid %s to ruin %s after it survived a Siege%s.[/color]"
			% [
				_player_name(
					int(
						event.get(
							"player_id",
							-1
						)
					)
				),
				_string_values_inline(
					event.get(
						"paid_cards",
						[]
					)
				),
				String(
					event.get(
						"target_castle",
						"Castle"
					)
				),
				(
					" and created a Neutral Tear"
					if int(
						event.get(
							"neutral_tear_gain",
							0
						)
					) > 0
					else ""
				),
			]
		)
		_log_harvest_event(
			event,
			"Inevitable Ruin"
		)

		if bool(
			event.get(
				"won",
				false
			)
		):
			_log_victory_cause(
				"Gremory's Inevitable Ruin"
			)

	for raw_event in _array_from(
		cleanup.get(
			"penitent_events",
			[]
		)
	):
		if typeof(
			raw_event
		) != TYPE_DICTIONARY:
			continue

		var event: Dictionary = raw_event
		var cards: Array = _array_from(
			event.get(
				"cards",
				[]
			)
		)

		if cards.is_empty():
			continue

		_log(
			"[color=#d8b4fe][b]Penitent Invocation cleanup:[/b] %s's temporary Guards left play — %s.[/color]"
			% [
				_player_name(
					int(
						event.get(
							"player_id",
							-1
						)
					)
				),
				_string_values_inline(
					cards
				),
			]
		)

	for raw_event in _array_from(
		cleanup.get(
			"profane_events",
			[]
		)
	):
		if typeof(
			raw_event
		) != TYPE_DICTIONARY:
			continue

		var event: Dictionary = raw_event
		_log(
			"[color=#c8b36a][b]Profane resolved:[/b] %s gained 1 personal Tear from %s.[/color]"
			% [
				_player_name(
					int(
						event.get(
							"player_id",
							-1
						)
					)
				),
				String(
					event.get(
						"castle",
						"the Profaned Castle"
					)
				),
			]
		)
		_log_harvest_event(
			event,
			"Profane"
		)

		if bool(
			event.get(
				"won",
				false
			)
		):
			_log_victory_cause(
				"Profane"
			)


func _log_gremory_guard_trigger(
	raw_trigger,
	source_name: String
) -> void:
	if (
		typeof(
			raw_trigger
		) != TYPE_DICTIONARY
		or not bool(
			raw_trigger.get(
				"triggered",
				false
			)
		)
	):
		return

	var trigger: Dictionary = raw_trigger
	var player_id: int = int(
		trigger.get(
			"player_id",
			-1
		)
	)
	_log(
		"[color=#d8b4fe][b]Gremory — Predator of Ruin:[/b] %s triggered it for %s; drew %s and discarded lowest %s.[/color]"
		% [
			source_name,
			_player_name(
				player_id
			),
			(
				"a hidden card"
				if player_id != 0
				else String(
					trigger.get(
						"drawn_card",
						"no card"
					)
				)
			),
			String(
				trigger.get(
					"discarded_card",
					"no card"
				)
			),
		]
	)


func _log_gremory_ruin_trigger(
	raw_trigger,
	source_name: String
) -> void:
	if (
		typeof(
			raw_trigger
		) != TYPE_DICTIONARY
		or not bool(
			raw_trigger.get(
				"triggered",
				false
			)
		)
	):
		return

	var trigger: Dictionary = raw_trigger
	_log(
		"[color=#d8b4fe][b]Gremory — Ruin Recovery:[/b] %s let %s recover %s from the discard.[/color]"
		% [
			source_name,
			_player_name(
				int(
					trigger.get(
						"player_id",
						-1
					)
				)
			),
			String(
				trigger.get(
					"recovered_card",
					"no card"
				)
			),
		]
	)


func _log_harvest_event(
	source: Dictionary,
	source_name: String
) -> void:
	var harvested_card: String = String(
		source.get(
			"harvested_card",
			""
		)
	)

	if harvested_card.is_empty():
		return

	_log(
		"[color=#d8b4fe][b]Gremory — Ruinous Harvest:[/b] %s's Tear let %s recover %s from the discard.[/color]"
		% [
			source_name,
			_player_name(
				int(
					source.get(
						"harvested_by",
						-1
					)
				)
			),
			harvested_card,
		]
	)


func _log_resource_income_audit(
	before: Dictionary,
	after: Dictionary
) -> void:
	var old_players: Array = _array_from(before.get("players", []))
	var new_players: Array = _array_from(after.get("players", []))
	for player_index: int in range(min(old_players.size(), new_players.size())):
		if (
			typeof(old_players[player_index]) != TYPE_DICTIONARY
			or typeof(new_players[player_index]) != TYPE_DICTIONARY
		):
			continue
		var old_player: Dictionary = old_players[player_index]
		var new_player: Dictionary = new_players[player_index]
		var owner_label: String = String(new_player.get("lord", "Player"))
		var soul_delta: int = int(new_player.get("souls", 0)) - int(old_player.get("souls", 0))
		var tear_delta: int = int(new_player.get("tears", 0)) - int(old_player.get("tears", 0))
		if soul_delta != 0:
			_log(
				"[color=#f2d477][b]Soul audit:[/b] %s %s %d Soul%s this Resolution.[/color]"
				% [
					owner_label,
					("gained" if soul_delta > 0 else "lost"),
					abs(soul_delta),
					("" if abs(soul_delta) == 1 else "s"),
				]
			)
		if tear_delta != 0:
			_log(
				"[color=#d8b4fe][b]Tear audit:[/b] %s %s %d personal Tear%s this Resolution.[/color]"
				% [
					owner_label,
					("gained" if tear_delta > 0 else "lost"),
					abs(tear_delta),
					("" if abs(tear_delta) == 1 else "s"),
				]
			)

	var veil_delta: int = int(after.get("veil", 0)) - int(before.get("veil", 0))
	var personal_delta: int = 0
	for player_index: int in range(min(old_players.size(), new_players.size())):
		if (
			typeof(old_players[player_index]) == TYPE_DICTIONARY
			and typeof(new_players[player_index]) == TYPE_DICTIONARY
		):
			personal_delta += (
				int(new_players[player_index].get("tears", 0))
				- int(old_players[player_index].get("tears", 0))
			)
	var neutral_delta: int = veil_delta - personal_delta
	if neutral_delta != 0:
		_log(
			"[color=#c8b36a][b]Neutral Tear audit:[/b] The Veil %s by %d Neutral Tear%s this Resolution.[/color]"
			% [
				("increased" if neutral_delta > 0 else "decreased"),
				abs(neutral_delta),
				("" if abs(neutral_delta) == 1 else "s"),
			]
		)

func _log_resolution_changes(
	before: Dictionary,
	after: Dictionary
) -> void:
	var before_players: Array = before.get(
		"players",
		[]
	)
	var after_players: Array = after.get(
		"players",
		[]
	)

	var fragments: Array[String] = []

	for player_index: int in range(
		min(
			before_players.size(),
			after_players.size()
		)
	):
		var old_player: Dictionary = (
			before_players[player_index]
		)
		var new_player: Dictionary = (
			after_players[player_index]
		)
		var changes: Array[String] = []

		for field_name: String in [
			"souls",
			"tears",
			"threat",
			"castles",
			"lord_guards",
			"castle_guards",
		]:
			var old_value: int = int(
				old_player.get(
					field_name,
					0
				)
			)
			var new_value: int = int(
				new_player.get(
					field_name,
					0
				)
			)

			if old_value != new_value:
				changes.append(
					"%s %d→%d"
					% [
						field_name,
						old_value,
						new_value,
					]
				)

		if bool(
			old_player.get(
				"alive",
				true
			)
		) != bool(
			new_player.get(
				"alive",
				true
			)
		):
			changes.append(
				"Lord %s"
				% (
					"returned"
					if bool(
						new_player.get(
							"alive",
							true
						)
					)
					else "banished"
				)
			)

		if not changes.is_empty():
			fragments.append(
				"%s: %s"
				% [
					String(
						new_player.get(
							"lord",
							"Player"
						)
					),
					", ".join(
						changes
					),
				]
			)

	if int(
		before.get(
			"veil",
			0
		)
	) != int(
		after.get(
			"veil",
			0
		)
	):
		fragments.append(
			"Veil %d→%d"
			% [
				int(
					before.get(
						"veil",
						0
					)
				),
				int(
					after.get(
						"veil",
						0
					)
				),
			]
		)

	if fragments.is_empty():
		_log(
			"Resolution: no tracked board clocks changed."
		)
	else:
		_log(
			"Resolution: %s."
			% " | ".join(
				fragments
			)
		)


func _log_guard_reveals() -> void:
	for event: Dictionary in (
		controller.consume_guard_reveal_events()
	):
		var cards: Array = _array_from(
			event.get(
				"cards",
				[]
			)
		)

		if cards.is_empty():
			continue

		_log(
			"[color=#f2d477][b]Guard reveal:[/b] %s's %s zone turns face-up — %s.[/color]"
			% [
				_player_name(
					int(
						event.get(
							"defender_id",
							-1
						)
					)
				),
				String(
					event.get(
						"zone",
						"Guard"
					)
				),
				_string_values_inline(
					cards
				),
			]
		)


func _log_reveal_sigils(
	round_result: Dictionary
) -> void:
	var phases = round_result.get(
		"phases",
		{}
	)

	if typeof(
		phases
	) != TYPE_DICTIONARY:
		return

	var reveal = phases.get(
		"reveal",
		{}
	)

	if typeof(
		reveal
	) != TYPE_DICTIONARY:
		return

	for raw_player in _array_from(
		reveal.get(
			"players",
			[]
		)
	):
		if typeof(
			raw_player
		) != TYPE_DICTIONARY:
			continue

		var player_result: Dictionary = raw_player
		var ward = player_result.get(
			"ward",
			{}
		)

		if (
			typeof(
				ward
			) != TYPE_DICTIONARY
			or not bool(
				ward.get(
					"warded",
					false
				)
			)
		):
			continue

		var player_id: int = int(
			player_result.get(
				"player_id",
				-1
			)
		)
		var player = controller.game.get_player(
			player_id
		)
		var zone: String = String(
			ward.get(
				"zone",
				""
			)
		)
		var state: String = String(
			ward.get(
				"sigil_state",
				""
			)
		)
		var value: int = (
			0
			if player == null
			else _current_sigil_value(
				player,
				zone
			)
		)

		_log(
			"[color=#91c7ff][b]Sigil formed:[/b] %s Ward placed a %s %s sigil (+%d DEF)%s.[/color]"
			% [
				_player_name(
					player_id
				),
				state,
				zone,
				value,
				(
					" after losing the contested commitment"
					if bool(
						ward.get(
							"contested",
							false
						)
					)
					and state == "flipped"
					else ""
				),
			]
		)


func _log_reveal_lord_powers(
	round_result: Dictionary
) -> void:
	var phases = round_result.get(
		"phases",
		{}
	)

	if typeof(
		phases
	) != TYPE_DICTIONARY:
		return

	var reveal = phases.get(
		"reveal",
		{}
	)

	if typeof(
		reveal
	) != TYPE_DICTIONARY:
		return

	for raw_player in _array_from(
		reveal.get(
			"players",
			[]
		)
	):
		if typeof(
			raw_player
		) != TYPE_DICTIONARY:
			continue

		var player_result: Dictionary = raw_player
		var aura = player_result.get(
			"kroni",
			{}
		)

		if (
			typeof(
				aura
			) == TYPE_DICTIONARY
			and bool(
				aura.get(
					"triggered",
					false
				)
			)
		):
			var aura_card: String = String(
				aura.get(
					"discarded_card",
					""
				)
			)

			_log(
				"[color=#d8b4fe][b]Kroni — Hungering Aura:[/b] %s %s during the committed-value trigger queue.[/color]"
				% [
					_player_name(
						int(
							aura.get(
								"target_player_id",
								-1
							)
						)
					),
					(
						"discarded its lowest commitment, %s"
						% aura_card
						if not aura_card.is_empty()
						else "had no committed card to consume"
					),
				]
			)

		var recoil = player_result.get(
			"odradek_recoil",
			{}
		)

		if typeof(recoil) == TYPE_DICTIONARY:
			_log_odradek_recoil_event(
				recoil,
				int(recoil.get("attacker_id", -1))
			)

		var invoke = player_result.get(
			"kanifous",
			{}
		)

		if typeof(invoke) != TYPE_DICTIONARY:
			continue

		if not bool(invoke.get("invoked", false)):
			var invoke_reason: String = String(invoke.get("reason", ""))
			if invoke_reason in ["hand_toll_unpaid", "hand_toll_invalid"]:
				_log(
					"[color=#a99eac][b]Kanifous — Invoke unpaid:[/b] %s had no valid Hand card for the toll; revealed %s and returned those cards to the deck.[/color]"
					% [
						_player_name(int(player_result.get("player_id", -1))),
						_string_values_inline(invoke.get("revealed_cards", [])),
					]
				)
			continue

		var player_id: int = int(
			player_result.get(
				"player_id",
				-1
			)
		)
		var chosen_card: String = String(
			invoke.get(
				"chosen_card",
				"?"
			)
		)
		var suit: String = (
			chosen_card.split(
				":"
			)[0]
			if chosen_card.contains(
				":"
			)
			else chosen_card
		)
		var effect_text: String = (
			_kanifous_invoke_effect_text(
				invoke,
				suit,
				player_id
			)
		)

		var invoke_cost_text: String = (
			"paid %s from Hand" % String(invoke.get("toll_card", "?"))
			if bool(invoke.get("toll_paid", false))
			else (
				"gained 1 Threat"
				if int(invoke.get("threat_after", 0)) > int(invoke.get("threat_before", 0))
				else "paid no additional cost"
			)
		)
		_log(
			"[color=#d8b4fe][b]Kanifous — Invoke:[/b] %s %s, revealed %s, chose %s, and %s%s[/color]"
			% [
				_player_name(
					player_id
				),
				invoke_cost_text,
				_string_values_inline(
					invoke.get(
						"revealed_cards",
						[]
					)
				),
				chosen_card,
				effect_text,
				(
					" A value-4+ reveal created a Neutral Tear."
					if int(
						invoke.get(
							"neutral_tear_gain",
							0
						)
					) > 0
					else ""
				),
			]
		)


func _kanifous_invoke_effect_text(
	invoke: Dictionary,
	suit: String,
	player_id: int
) -> String:
	var banked_card: String = String(
		invoke.get(
			"banked_card",
			""
		)
	)
	var bank_text: String = (
		"banked %s in Garrison."
		% banked_card
		if not banked_card.is_empty()
		else "discarded the chosen card because Garrison was full."
	)

	match suit:
		"Vulture":
			return (
				"drew %s outside the Draw step, discarded %s, then %s"
				% [
					(
						"%d hidden card(s)"
						% _array_from(
							invoke.get(
								"drawn_cards",
								[]
							)
						).size()
						if player_id != 0
						else _string_values_inline(
							invoke.get(
								"drawn_cards",
								[]
							)
						)
					),
					String(
						invoke.get(
							"hand_discarded",
							"no card"
						)
					),
					bank_text,
				]
			)
		"Wright":
			return (
				"moved %s from Lord Guard to Castle Guard, then %s"
				% [
					(
						"%d face-down Guard(s)"
						% _array_from(
							invoke.get(
								"moved_guards",
								[]
							)
						).size()
						if player_id != 0
						else _string_values_inline(
							invoke.get(
								"moved_guards",
								[]
							)
						)
					),
					bank_text,
				]
			)
		"Penitent":
			return (
				"created temporary Guards %s, then %s"
				% [
					(
						"(%d face-down)"
						% _array_from(
							invoke.get(
								"temporary_guards",
								[]
							)
						).size()
						if player_id != 0
						else _string_values_inline(
							invoke.get(
								"temporary_guards",
								[]
							)
						)
					),
					bank_text,
				]
			)
		"Butcher":
			return (
				"armed Crushing Presence for the lowest target Guard this round, then %s"
				% bank_text
			)

	return bank_text


func _log_resolution_sigils(
	round_result: Dictionary
) -> void:
	var phases = round_result.get(
		"phases",
		{}
	)

	if typeof(
		phases
	) != TYPE_DICTIONARY:
		return

	var resolution_phase = phases.get(
		"resolution",
		{}
	)

	if typeof(
		resolution_phase
	) != TYPE_DICTIONARY:
		return

	var resolution_result = resolution_phase.get(
		"result",
		{}
	)

	if typeof(
		resolution_result
	) != TYPE_DICTIONARY:
		return

	for raw_event in _array_from(
		resolution_result.get(
			"action_events",
			[]
		)
	):
		if typeof(
			raw_event
		) != TYPE_DICTIONARY:
			continue

		var event: Dictionary = raw_event
		var action_result = event.get(
			"action_result",
			{}
		)

		if typeof(
			action_result
		) == TYPE_DICTIONARY:
			_log_combat_sigil_result(
				action_result
			)

	var reflex = resolution_result.get(
		"reflex_result",
		{}
	)

	if typeof(
		reflex
	) == TYPE_DICTIONARY:
		var reflex_action_result = reflex.get(
			"action_result",
			{}
		)

		if typeof(
			reflex_action_result
		) == TYPE_DICTIONARY:
			_log_combat_sigil_result(
				reflex_action_result
			)


func _log_combat_sigil_result(
	action_result: Dictionary
) -> void:
	var action_name: String = String(
		action_result.get(
			"action",
			""
		)
	)

	if not [
		"hunt",
		"siege",
	].has(
		action_name
	):
		return

	var state: String = String(
		action_result.get(
			"sigil_state",
			""
		)
	)

	if state.is_empty():
		return

	var attacker_id: int = int(
		action_result.get(
			"attacker_id",
			-1
		)
	)
	var defender_id: int = int(
		action_result.get(
			"defender_id",
			-1
		)
	)
	var zone: String = (
		"Lord"
		if action_name == "hunt"
		else "Castle"
	)
	var value: int = int(
		action_result.get(
			"sigil_value",
			0
		)
	)

	if bool(
		action_result.get(
			"sigil_broken",
			false
		)
	):
		_log(
			"[color=#91c7ff][b]Sigil broken:[/b] %s's %s broke %s's %s %s sigil (+%d DEF).[/color]"
			% [
				_player_name(
					attacker_id
				),
				action_name.capitalize(),
				_player_name(
					defender_id
				),
				state,
				zone,
				value,
			]
		)
	elif String(
		action_result.get(
			"stopped_at",
			""
		)
	) == "Sigil":
		_log(
			"[color=#91c7ff][b]Sigil held:[/b] %s's %s %s sigil (+%d DEF) stopped %s's %s.[/color]"
			% [
				_player_name(
					defender_id
				),
				state,
				zone,
				value,
				_player_name(
					attacker_id
				),
				action_name.capitalize(),
			]
		)


func _log_reflex_bid_status() -> void:
	var bid_phase_raw = controller.phase_results.get(
		"reflex_bid",
		{}
	)

	if typeof(
		bid_phase_raw
	) != TYPE_DICTIONARY:
		return

	var bid_phase: Dictionary = bid_phase_raw
	var bid_result_raw = bid_phase.get(
		"result",
		{}
	)

	if typeof(
		bid_result_raw
	) != TYPE_DICTIONARY:
		return

	var bid_result: Dictionary = bid_result_raw
	var action_name: String = String(
		bid_result.get(
			"action",
			""
		)
	)

	if action_name in [
		"skip",
		"round_one_skip",
	]:
		return

	var raw_totals = bid_result.get(
		"bid_totals",
		[]
	)
	var totals_text: String = ""

	if (
		typeof(
			raw_totals
		) == TYPE_ARRAY
		and raw_totals.size() >= 2
	):
		totals_text = " (%d–%d)" % [
			int(
				raw_totals[0]
			),
			int(
				raw_totals[1]
			),
		]

	var winner_id: int = int(
		bid_result.get(
			"winner",
			-1
		)
	)

	if winner_id < 0:
		if bool(
			bid_result.get(
				"tie",
				false
			)
		):
			_log(
				"Reflex bid tied%s; no second action."
				% totals_text
			)
		return

	var winner = controller.game.get_player(
		winner_id
	)

	if winner == null:
		return

	_log(
		"[color=#c8b36a]Reflex bid: %s wins%s and holds a second action.[/color]"
		% [
			String(
				winner.lord
			),
			totals_text,
		]
	)


func _log_new_development_activity() -> void:
	if (
		controller == null
		or controller.game == null
	):
		return

	for phase_name: String in [
		"sigil_update",
		"veil_drift",
		"development_start",
		"draw",
		"market_rollover",
		"market",
		"repair",
		"dominion_rites",
		"deploy",
		"march",
		"march_advance",
		"summon",
	]:
		if not controller.phase_results.has(
			phase_name
		):
			continue

		var report_key: String = "%d:%s" % [
			int(
				controller.game.round
			),
			phase_name,
		]

		if bool(
			reported_development_phases.get(
				report_key,
				false
			)
		):
			continue

		reported_development_phases[
			report_key
		] = true

		var phase_data = controller.phase_results.get(
			phase_name,
			{}
		)

		if typeof(
			phase_data
		) != TYPE_DICTIONARY:
			continue

		match phase_name:
			"sigil_update":
				_log_sigil_update_events(
					phase_data
				)
			"veil_drift":
				_log_veil_drift_events(
					phase_data
				)
			"development_start":
				_log_development_start_events(
					phase_data
				)
			"draw":
				_log_draw_events(
					phase_data
				)
			"market_rollover":
				_log_market_rollover(
					phase_data
				)
			"market":
				_log_market_events(
					phase_data
				)
			"repair":
				_log_repair_events(
					phase_data
				)
			"dominion_rites":
				_log_rite_events(
					phase_data
				)
			"deploy":
				_log_deploy_events(
					phase_data
				)
			"march":
				_log_march_launch_events(phase_data)
			"march_advance":
				_log_march_advance_events(phase_data)
			"summon":
				_log_summon_events(
					phase_data
				)


func _log_veil_drift_events(
	phase_data: Dictionary
) -> void:
	if not bool(
		phase_data.get(
			"applied",
			false
		)
	):
		return

	_log(
		"[color=#f2d477][b]Veil Drift:[/b] The advancing Veil created 1 Neutral Tear (Veil %d→%d).[/color]"
		% [
			int(
				phase_data.get(
					"veil_before",
					0
				)
			),
			int(
				phase_data.get(
					"veil_after",
					0
				)
			),
		]
	)
	_log_harvest_event(
		phase_data,
		"Veil Drift"
	)

	if bool(
		phase_data.get(
			"won",
			false
		)
	):
		_log_victory_cause(
			"Veil Drift"
		)


func _log_sigil_update_events(
	phase_data: Dictionary
) -> void:
	for raw_event in _array_from(
		phase_data.get(
			"events",
			[]
		)
	):
		if typeof(
			raw_event
		) != TYPE_DICTIONARY:
			continue

		var event: Dictionary = raw_event
		var state_before: String = String(
			event.get(
				"state_before",
				""
			)
		)
		var state_after: String = String(
			event.get(
				"state_after",
				""
			)
		)

		if (
			state_before.is_empty()
			or state_before == state_after
		):
			continue

		_log(
			"[color=#91c7ff]Sigil upkeep: %s's %s sigil %s → %s.[/color]"
			% [
				_player_name(
					int(
						event.get(
							"player_id",
							-1
						)
					)
				),
				String(
					event.get(
						"zone",
						"zone"
					)
				),
				state_before,
				(
					"gone"
					if state_after.is_empty()
					else state_after
				),
			]
		)


func _log_development_start_events(
	phase_data: Dictionary
) -> void:
	for raw_event in _array_from(
		phase_data.get(
			"snare_events",
			[]
		)
	):
		if (
			typeof(
				raw_event
			) != TYPE_DICTIONARY
			or not bool(
				raw_event.get(
					"applied",
					false
				)
			)
		):
			continue

		var event: Dictionary = raw_event
		_log(
			"[color=#d8b4fe][b]Orias — Snare:[/b] %s gained 1 Threat and restricted %s to one Deploy move this round.[/color]"
			% [
				_player_name(
					int(
						event.get(
							"player_id",
							-1
						)
					)
				),
				_player_name(
					int(
						event.get(
							"target_player_id",
							-1
						)
					)
				),
			]
		)

	for raw_event in _array_from(
		phase_data.get(
			"gremory_draw_events",
			[]
		)
	):
		if typeof(
			raw_event
		) != TYPE_DICTIONARY:
			continue

		var event: Dictionary = raw_event
		var player_id: int = int(
			event.get(
				"player_id",
				-1
			)
		)
		var drawn_cards: Array = _array_from(
			event.get(
				"drawn_cards",
				[]
			)
		)
		var card_text: String = (
			"%d hidden card(s)"
			% drawn_cards.size()
			if player_id != 0
			else _string_values_inline(
				drawn_cards
			)
		)

		_log(
			"[color=#d8b4fe][b]Gremory — Picking the Bones:[/b] %s drew %s (%d requested from current Ruins).[/color]"
			% [
				_player_name(
					player_id
				),
				card_text,
				int(
					event.get(
						"requested_draws",
						0
					)
				),
			]
		)
		_log_draw_side_effects(
			event.get(
				"draw_results",
				[]
			),
			"Picking the Bones"
		)

	for raw_event in _array_from(
		phase_data.get(
			"breach_draw_events",
			[]
		)
	):
		if typeof(
			raw_event
		) != TYPE_DICTIONARY:
			continue

		var event: Dictionary = raw_event
		var player_id: int = int(
			event.get(
				"player_id",
				-1
			)
		)
		var draw_result = event.get(
			"draw_result",
			{}
		)

		if (
			typeof(
				draw_result
			) != TYPE_DICTIONARY
			or not bool(
				draw_result.get(
					"drawn",
					false
				)
			)
		):
			continue

		_log(
			"[color=#d8b4fe][b]Gremory Breach:[/b] %s had a Ruin and drew %s.[/color]"
			% [
				_player_name(
					player_id
				),
				(
					"a hidden card"
					if player_id != 0
					else String(
						draw_result.get(
							"card",
							"a card"
						)
					)
				),
			]
		)
		_log_draw_side_effects(
			[
				draw_result,
			],
			"Gremory Breach"
		)


func _log_draw_events(
	phase_data: Dictionary
) -> void:
	for raw_event in _array_from(
		phase_data.get(
			"players",
			[]
		)
	):
		if typeof(
			raw_event
		) != TYPE_DICTIONARY:
			continue

		var event: Dictionary = raw_event
		var player_id: int = int(
			event.get(
				"player_id",
				-1
			)
		)
		var drawn_cards = event.get(
			"drawn_cards",
			[]
		)
		var drawn_count: int = (
			_array_from(
				drawn_cards
			).size()
		)

		if player_id == 0:
			_log(
				"Draw: you received %d/%d cards — %s."
				% [
					drawn_count,
					int(
						event.get(
							"requested_draws",
							0
						)
					),
					_string_values_inline(
						drawn_cards
					),
				]
			)
		else:
			_log(
				"Draw: %s received %d/%d hidden cards."
				% [
					_player_name(
						player_id
					),
					drawn_count,
					int(
						event.get(
							"requested_draws",
							0
						)
					),
				]
			)

		_log_draw_side_effects(
			event.get(
				"draw_results",
				[]
			),
			"normal draw"
		)


func _log_draw_side_effects(
	raw_results,
	source_name: String
) -> void:
	var recycled: bool = false

	for raw_result in _array_from(
		raw_results
	):
		if typeof(
			raw_result
		) != TYPE_DICTIONARY:
			continue

		var result: Dictionary = raw_result

		if bool(
			result.get(
				"recycled",
				false
			)
		):
			recycled = true

		if bool(
			result.get(
				"kanifous_breach_triggered",
				false
			)
		):
			_log(
				"[color=#d8b4fe][b]Kanifous Breach:[/b] %s's draw outside the Draw step raised Threat %d→%d during %s.[/color]"
				% [
					_player_name(
						int(
							result.get(
								"player_id",
								-1
							)
						)
					),
					int(
						result.get(
							"threat_before",
							0
						)
					),
					int(
						result.get(
							"threat_after",
							0
						)
					),
					source_name,
				]
			)

	if recycled:
		_log(
			"[color=#a9a1b0]Deck recycle: the discard pile was shuffled into a new deck during %s.[/color]"
			% source_name
		)


func _log_market_rollover(
	phase_data: Dictionary
) -> void:
	if not bool(phase_data.get("enabled", false)):
		return

	_log(
		"[color=#82c9ff][b]Market rollover:[/b] %s rotated beneath the deck; fresh offers are on display.[/color]"
		% _string_values_inline(
			phase_data.get("rolled_cards", [])
		)
	)


func _log_market_events(
	phase_data: Dictionary
) -> void:
	for raw_result in _array_from(
		phase_data.get(
			"results",
			[]
		)
	):
		if typeof(
			raw_result
		) != TYPE_DICTIONARY:
			continue

		var result: Dictionary = raw_result

		if String(
			result.get(
				"action",
				""
			)
		) != "swap":
			continue

		_log(
			"Market: %s took %s and offered %s."
			% [
				_player_name(
					int(
						result.get(
							"player_id",
							-1
						)
					)
				),
				String(
					result.get(
						"take",
						"?"
					)
				),
				String(
					result.get(
						"give",
						"?"
					)
				),
			]
		)


func _log_repair_events(
	phase_data: Dictionary
) -> void:
	for raw_result in _array_from(
		phase_data.get(
			"results",
			[]
		)
	):
		if typeof(
			raw_result
		) != TYPE_DICTIONARY:
			continue

		var result: Dictionary = raw_result

		if String(
			result.get(
				"action",
				""
			)
		) != "repair":
			continue

		_log(
			"[color=#82c9ff][b]Repair:[/b] %s restored %s for %d (%s%s).[/color]"
			% [
				_player_name(
					int(
						result.get(
							"player_id",
							-1
						)
					)
				),
				String(
					result.get(
						"castle",
						"unknown castle"
					)
				),
				int(
					result.get(
						"paid_total",
						0
					)
				),
				_string_values_inline(
					result.get(
						"paid_cards",
						[]
					)
				),
				(
					", repair token"
					if bool(
						result.get(
							"used_token",
							false
						)
					)
					else ""
				),
			]
		)

		var repair_player = controller.game.get_player(
			int(
				result.get(
					"player_id",
					-1
				)
			)
		)

		if (
			repair_player != null
			and String(
				repair_player.lord
			) == "Kalligan"
			and bool(
				repair_player.alive
			)
		):
			_log(
				"[color=#d8b4fe][b]Kalligan — Forge-Repair:[/b] The discount reduced this Repair and armed Scorch against the enemy Lord zone.[/color]"
			)


func _log_rite_events(
	phase_data: Dictionary
) -> void:
	for raw_player_result in _array_from(
		phase_data.get(
			"results",
			[]
		)
	):
		if typeof(
			raw_player_result
		) != TYPE_DICTIONARY:
			continue

		var player_result: Dictionary = (
			raw_player_result
		)
		var player_id: int = int(
			player_result.get(
				"player_id",
				-1
			)
		)

		for raw_action in _array_from(
			player_result.get(
				"actions",
				[]
			)
		):
			if typeof(
				raw_action
			) != TYPE_DICTIONARY:
				continue

			var rite: Dictionary = raw_action
			var action_name: String = String(
				rite.get(
					"action",
					"rite"
				)
			)

			if action_name == "cataclysmic_invocation":
				_log(
					"[color=#f2d477][b]CATACLYSMIC INVOCATION:[/b] %s paid %d with %s, gained 1 personal Tear, and moved the Veil %d→%d.[/color]"
					% [
						_player_name(
							player_id
						),
						int(
							rite.get(
								"paid_total",
								0
							)
						),
						_string_values_inline(
							rite.get(
								"paid_cards",
								[]
							)
						),
						int(
							rite.get(
								"veil_before",
								0
							)
						),
						int(
							rite.get(
								"veil_after",
								0
							)
						),
					]
				)
				_log_harvest_event(
					rite,
					"Cataclysmic Invocation"
				)

				if bool(
					rite.get(
						"won",
						false
					)
				):
					_log_victory_cause(
						"Cataclysmic Invocation"
					)
			elif action_name == "profane_ruins":
				_log(
					"[color=#c8b36a][b]Profane the Ruins:[/b] %s converted ruined %s into a Profaned Castle and gained 1 personal Tear (Veil now %d).[/color]"
					% [
						_player_name(
							player_id
						),
						String(
							rite.get(
								"castle",
								"castle"
							)
						),
						int(
							rite.get(
								"veil_after",
								0
							)
						),
					]
				)
				_log_harvest_event(
					rite,
					"Profane the Ruins"
				)

				if bool(
					rite.get(
						"won",
						false
					)
				):
					_log_victory_cause(
						"Profane the Ruins"
					)


func _log_deploy_events(
	phase_data: Dictionary
) -> void:
	for raw_player_result in _array_from(
		phase_data.get(
			"results",
			[]
		)
	):
		if typeof(
			raw_player_result
		) != TYPE_DICTIONARY:
			continue

		var player_result: Dictionary = (
			raw_player_result
		)
		var moves: Array = _array_from(
			player_result.get(
				"moves",
				[]
			)
		)
		var player_id: int = int(
			player_result.get(
				"player_id",
				-1
			)
		)

		if moves.is_empty():
			continue

		var move_texts: Array[String] = []

		for raw_move in moves:
			if (
				typeof(
					raw_move
				) != TYPE_DICTIONARY
				or String(
					raw_move.get(
						"action",
						""
					)
				) != "move"
			):
				continue

			var move: Dictionary = raw_move
			var target_name: String = String(
				move.get(
					"target",
					"?"
				)
			)

			if (
				player_id != 0
				and target_name in [
					"Lord",
					"Castle",
				]
			):
				move_texts.append(
					"a face-down Guard → %s"
					% target_name
				)
			else:
				move_texts.append(
					"%s %s→%s"
					% [
						String(
							move.get(
								"card",
								"?"
							)
						),
						String(
							move.get(
								"source",
								"?"
							)
						),
						target_name,
					]
				)

		if not move_texts.is_empty():
			_log(
				"Deploy: %s moved %s."
				% [
					_player_name(
						player_id
					),
					"; ".join(
						move_texts
					),
				]
			)


func _log_march_launch_events(
	phase_data: Dictionary
) -> void:
	for raw_result in _array_from(phase_data.get("results", [])):
		if typeof(raw_result) != TYPE_DICTIONARY:
			continue
		var result: Dictionary = raw_result
		if String(result.get("action", "")) != "march":
			continue
		var reactive_text: String = (
			" through Reactive Lane"
			if bool(result.get("reactive", false))
			else ""
		)
		_log(
			"[color=#c8b36a][b]Marching Orders:[/b] %s launched %s from %s into the %s lane%s.[/color]"
			% [
				_player_name(int(result.get("player_id", -1))),
				String(result.get("card", "a Guard")),
				String(result.get("source_zone", "a Guard zone")),
				String(result.get("lane", "?")),
				reactive_text,
			]
		)


func _log_march_advance_events(
	phase_data: Dictionary
) -> void:
	for raw_event in _array_from(phase_data.get("events", [])):
		if typeof(raw_event) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = raw_event
		match String(event.get("type", "")):
			"march_clash":
				var first_damage: int = int(event.get("first_damage", 0))
				var second_damage: int = int(event.get("second_damage", 0))
				var advantage_text: String = (
					" Suit advantage applied."
					if first_damage != second_damage
					else ""
				)
				_log(
					("[color=#c8b36a][b]Lane clash — %s:[/b] simultaneous damage %d–%d.%s "
					+ "RPS: Wright > Penitent > Vulture > Butcher > Wright.[/color]")
					% [
						String(event.get("lane", "?")),
						first_damage,
						second_damage,
						advantage_text,
					]
				)

			"march_spy":
				_log(
					"[color=#ff9a7a][b]Lane clash — %s:[/b] Butcher:1 intercepted Vulture:5; both marchers were destroyed.[/color]"
					% String(event.get("lane", "?"))
				)

			"march_evade":
				_log(
					"[color=#82c9ff][b]Lane evasion:[/b] Vulture:5 passed through the clash; only Butcher:1 can destroy it.[/color]"
				)

			"march_destroyed":
				var destroyed_id: int = int(event.get("player_id", -1))
				var killer_id: int = 1 - destroyed_id
				var income_text: String = (
					" %s gained 1 Soul." % _player_name(killer_id)
					if controller.rules.lane_kill_soul
					else ""
				)
				_log(
					"[color=#ff9a7a][b]Marcher destroyed:[/b] %s lost %s.%s[/color]"
					% [
						_player_name(destroyed_id),
						String(event.get("card", "a marcher")),
						income_text,
					]
				)

			"march_arrival":
				if bool(event.get("scored", false)):
					_log(
						"[color=#f2d477][b]Marcher arrived:[/b] %s's %s reached the enemy gate and gained 1 personal Tear.[/color]"
						% [
							_player_name(int(event.get("player_id", -1))),
							String(event.get("card", "marcher")),
						]
					)
				else:
					_log(
						"[color=#a99eac][b]Marcher arrived short:[/b] %s's %s reached the gate below value %d and gained no Tear.[/color]"
						% [
							_player_name(int(event.get("player_id", -1))),
							String(event.get("card", "marcher")),
							controller.rules.march_threshold,
						]
					)

func _log_summon_events(
	phase_data: Dictionary
) -> void:
	for raw_result in _array_from(
		phase_data.get(
			"results",
			[]
		)
	):
		if typeof(
			raw_result
		) != TYPE_DICTIONARY:
			continue

		var result: Dictionary = raw_result

		if String(
			result.get(
				"action",
				""
			)
		) != "summon":
			continue

		_log(
			"[color=#8fdda9]Summon: %s returned %s, paying %d with %s.[/color]"
			% [
				_player_name(
					int(
						result.get(
							"player_id",
							-1
						)
					)
				),
				String(
					result.get(
						"lord",
						"Lord"
					)
				),
				int(
					result.get(
						"paid_total",
						0
					)
				),
				_string_values_inline(
					result.get(
						"paid_cards",
						[]
					)
				),
			]
		)

		if (
			String(
				result.get(
					"lord",
					""
				)
			) == String(
				controller.game.get_meta(
					"orias_marked_lord",
					""
				)
			)
		):
			_log(
				"[color=#d8b4fe][b]Orias — The Mark:[/b] The marked Lord returned at +1 Threat (now %d).[/color]"
				% int(
					result.get(
						"threat",
						0
					)
				)
			)

	var raw_breach_closed = phase_data.get(
		"breach_closed",
		{}
	)

	if typeof(
		raw_breach_closed
	) != TYPE_DICTIONARY:
		return

	var breach_closed: Dictionary = raw_breach_closed

	if breach_closed.is_empty():
		return

	_log(
		"[color=#8fdda9][b]Breach closed:[/b] %s returned; that Lord's Breach ability is no longer active.[/color]"
		% String(
			breach_closed.get(
				"lord",
				"Lord"
			)
		)
	)


func _player_name(
	player_id: int
) -> String:
	var player = controller.game.get_player(
		player_id
	)

	if player == null:
		return "Player %d" % player_id

	if player_id == 0:
		return "You (%s)" % String(
			player.lord
		)

	return String(
		player.lord
	)


func _array_from(
	value
) -> Array:
	if typeof(
		value
	) != TYPE_ARRAY:
		return []

	return value


func _second_action_name() -> String:
	if controller != null and controller.rules != null and controller.rules.momentum:
		return "Momentum"

	return "Reflex"


func _reflex_holder_text() -> String:
	if int(
		controller.game.reflex_winner
	) < 0:
		return "No %s action" % _second_action_name()

	var holder = controller.game.get_player(
		int(
			controller.game.reflex_winner
		)
	)

	if holder == null:
		return "No %s action" % _second_action_name()

	return (
		"%s held by %s"
		% [
			_second_action_name(),
			String(holder.lord),
		]
	)


func _log_odradek_recoil_event(
	recoil: Dictionary,
	attacker_id: int
) -> void:
	if not bool(recoil.get("triggered", false)):
		return

	var attempted: String = String(recoil.get("attempted_card", ""))
	var taken: String = String(recoil.get("taken_card", ""))
	var discarded: String = String(recoil.get("discarded_card", ""))
	var bank_before: String = String(recoil.get("bank_before", ""))
	var bank_after: String = String(recoil.get("bank_after", ""))
	var replaced: String = String(recoil.get("replaced_card", ""))
	var soul_text: String = (
		"; gained 1 Soul"
		if int(recoil.get("soul_gain", 0)) > 0
		else ""
	)

	if bool(recoil.get("locked", false)):
		_log(
			"[color=#d8b4fe][b]Odradek — Interlock:[/b] %s could not exceed banked %s; Recoil locked.[/color]"
			% [attempted, bank_before]
		)
		return

	if not taken.is_empty() and not bank_after.is_empty():
		if not replaced.is_empty():
			_log(
				"[color=#d8b4fe][b]Odradek — Interlock:[/b] Discarded banked %s and replaced it with %s from %s%s.[/color]"
				% [replaced, taken, _player_name(attacker_id), soul_text]
			)
		else:
			_log(
				"[color=#d8b4fe][b]Odradek — Psychic Recoil:[/b] Banked %s from %s's attack%s.[/color]"
				% [taken, _player_name(attacker_id), soul_text]
			)
		return

	if not discarded.is_empty():
		_log(
			"[color=#d8b4fe][b]Odradek — Recoil:[/b] %s lost committed %s before combat%s.[/color]"
			% [_player_name(attacker_id), discarded, soul_text]
		)


func _log_reflex_resolution(
	round_result: Dictionary
) -> void:
	var phases_raw = round_result.get(
		"phases",
		{}
	)

	if typeof(
		phases_raw
	) != TYPE_DICTIONARY:
		return

	var phases: Dictionary = phases_raw
	var resolution_phase_raw = phases.get(
		"resolution",
		{}
	)

	if typeof(
		resolution_phase_raw
	) != TYPE_DICTIONARY:
		return

	var resolution_phase: Dictionary = resolution_phase_raw
	var resolution_result_raw = resolution_phase.get(
		"result",
		{}
	)

	if typeof(
		resolution_result_raw
	) != TYPE_DICTIONARY:
		return

	var resolution_result: Dictionary = (
		resolution_result_raw
	)
	var reflex_raw = resolution_result.get(
		"reflex_result",
		{}
	)

	if typeof(
		reflex_raw
	) != TYPE_DICTIONARY:
		return

	var reflex: Dictionary = reflex_raw

	if String(
		reflex.get(
			"action",
			""
		)
	) != "reflex_action":
		return

	var executed_action: String = String(
		reflex.get(
			"executed_action",
			"Pass"
		)
	)
	var executed_by: int = int(
		reflex.get(
			"executed_by",
			-1
		)
	)
	var actor = controller.game.get_player(
		executed_by
	)
	var actor_name: String = (
		"Unknown"
		if actor == null
		else String(
			actor.lord
		)
	)
	var cards_text: String = _string_values_inline(
		reflex.get(
			"executed_cards",
			[]
		)
	)
	var stolen_text: String = (
		" (stolen through Paradox Geometry)"
		if bool(
			reflex.get(
				"stolen",
				false
			)
		)
		else ""
	)

	var spent_bank: String = String(reflex.get("bank_spent_card", ""))
	if not spent_bank.is_empty():
		_log("[color=#d8b4fe][b]Odradek — Interlock spent:[/b] %s joined the %s; Recoil rearmed.[/color]" % [spent_bank, executed_action])

	_log(
		"[color=#c8b36a][b]%s second action:[/b] %s executed %s with %s%s.[/color]"
		% [
			_second_action_name(),
			actor_name,
			executed_action,
			cards_text,
			stolen_text,
		]
	)

	if bool(
		reflex.get(
			"stolen",
			false
		)
	):
		_log(
			"[color=#d8b4fe][b]Odradek Breach — Paradox Geometry:[/b] Correctly guessed %s, discarded the original winner's %s, and stole the %s action.[/color]"
			% [
				String(
					reflex.get(
						"breach_guess",
						"action"
					)
				),
				_string_values_inline(
					reflex.get(
						"winner_discarded_cards",
						[]
					)
				),
				_second_action_name(),
			]
		)

	reveal_label.text += (
		"\n[center][color=#c8b36a]"
		+ "%s: %s → %s (%s)%s"
		+ "[/color][/center]"
	) % [
		_second_action_name(),
		actor_name,
		executed_action,
		cards_text,
		stolen_text,
	]


func _player_state_text(
	player,
	hide_hand: bool
) -> String:
	var lord_state: String = (
		"standing"
		if bool(
			player.alive
		)
		else "BANISHED"
	)

	var hand_text: String = (
		"%d hidden cards"
		% player.hand.size()
		if hide_hand
		else _cards_inline(
			player.hand
		)
	)

	return (
		"[b]%s[/b] · %s\n"
		+ SOULS_LABEL
		+ " [b]%d/%d[/b]   "
		+ TEARS_LABEL
		+ " [b]%d[/b]   "
		+ THREAT_LABEL
		+ " [b]%d[/b]\n"
		+ "Lord defense %d   Sigil %s\n"
		+ "Lord guards: %s\n"
		+ CASTLES_LABEL
		+ " (%d): %s\n"
		+ "Castle guards: %s\n"
		+ "Marchers: %s\n"
		+ "Garrison: %s\n"
		+ "Hand: %s"
	) % [
		String(
			player.lord
		),
		lord_state,
		int(
			player.souls
		),
		int(
			controller.rules.win_souls
		),
		int(
			player.tears
		),
		int(
			player.threat
		),
		int(
			player.derived_lord_def
		),
		_sigil_text(
			player
		),
		(
			_public_guard_summary(
				player.lord_guards
			)
			if hide_hand
			else _cards_inline(
				player.lord_guards
			)
		),
		player.castles.size(),
		_castle_status_inline_with_help(player),
		(
			_public_guard_summary(
				player.castle_guards
			)
			if hide_hand
			else _cards_inline(
				player.castle_guards
			)
		),
		_marchers_inline(player.marchers),
		_cards_inline(
			player.garrison
		),
		hand_text,
	]


func _castle_status_inline(player) -> String:
	var labels: Array[String] = []

	for castle_name_value in player.castles:
		var castle_name: String = String(castle_name_value)
		var scars: int = int(player.castle_scars.get(castle_name, 0))
		labels.append(
			"%s%s" % [
				castle_name,
				(" (scar %d)" % scars) if scars > 0 else "",
			]
		)

	for castle_name_value in player.ruined_castles:
		labels.append("%s (ruined)" % String(castle_name_value))

	for castle_name_value in player.lost_castles:
		labels.append("%s (lost)" % String(castle_name_value))

	return "—" if labels.is_empty() else ", ".join(labels)


func _marchers_inline(marchers: Array) -> String:
	if marchers.is_empty():
		return "—"

	var labels: Array[String] = []
	for marcher in marchers:
		var card = marcher.get("card", null)
		labels.append("%s %d/%d → %s" % [
			_card_id(card),
			int(marcher.get("value", 0)),
			int(marcher.get("pos", 0)),
			String(marcher.get("lane", "")),
		])
	return ", ".join(labels)


func _lord_card_text(
	player
) -> String:
	var lord_name: String = String(
		player.lord
	)
	var ability_lines: Array = LORD_CARD_ABILITIES.get(
		lord_name,
		[]
	)
	var current_cost: int = (
		SummonEngineData._summon_cost(
			controller.game,
			player,
			controller.rules,
			lord_name
		)
	)
	var card_lines: Array[String] = [
		"[center][font_size=17][b]%s — LORD CARD[/b][/font_size][/center]"
		% lord_name,
		"[center]Current DEF [b]%d[/b]  •  Summon [b]%d[/b]  •  Return Threat [b]%d[/b][/center]"
		% [
			int(
				player.derived_lord_def
			),
			current_cost,
			_lord_return_threat(
				lord_name
			),
		],
		"",
	]

	for raw_line in ability_lines:
		card_lines.append(
			"• %s" % String(
				raw_line
			)
		)

	card_lines.append(
		""
	)
	card_lines.append(
		"[color=#c8b36a][b]LIVE:[/b] %s[/color]"
		% _lord_live_state(
			player
		)
	)

	return "\n".join(
		card_lines
	)


func _lord_return_threat(
	lord_name: String
) -> int:
	var return_threats: Dictionary = {
		"Orias": 0,
		"Deimos": 0,
		"Valak": 1,
		"Kroni": 1,
		"Kalligan": 1,
		"Gremory": 2,
		"Odradek": 2,
		"Kanifous": 1,
		"Humbaba": 2,
	}

	return int(
		return_threats.get(
			lord_name,
			0
		)
	)


func _lord_live_state(
	player
) -> String:
	if not bool(
		player.alive
	):
		return (
			"Banished. Passive text requiring a living Lord is inactive."
		)

	match String(
		player.lord
	):
		"Orias":
			return (
				"Threat %d; Snare %s. Marked Lord: %s."
				% [
					int(
						player.threat
					),
					(
						"eligible"
						if int(
							player.threat
						) < 3
						else "locked at Threat 3+"
					),
					String(
						controller.game.get_meta(
							"orias_marked_lord",
							"none"
						)
					),
				]
			)
		"Deimos":
			return (
				"Claim the Breach: %s. War Machine bonus now +%d."
				% [
					(
						"used"
						if bool(
							player.deimos_breach_claimed
						)
						else "ready"
					),
					max(
						0,
						2
						- player.ruined_castles.size()
						- player.profaned_castles.size()
					),
				]
			)
		"Valak":
			return (
				"Crushing Presence is ready on zones with 2+ Guards; Siphon requires Valak to defeat a Guard."
			)
		"Kroni":
			return (
				"Hunger %d; Consume this round %s; Ravenous %s; milestone Tear %s."
				% [
					int(
						player.kroni_hunger
					),
					(
						"used"
						if bool(
							player.kroni_consume_done
						)
						else "ready"
					),
					(
						"used"
						if bool(
							player.kroni_ravenous_used
						)
						else (
							"armed"
							if int(
								player.kroni_hunger
							) >= 3
							else "not armed"
						)
					),
					(
						"claimed"
						if bool(
							player.kroni_tear_milestone_fired
						)
						else "available at Hunger 3"
					),
				]
			)
		"Kalligan":
			return (
				"Repair discount: %s. Persistent Scorch: %s."
				% [
					(
						"later repair (−5)"
						if bool(
							player.kalligan_repair_used
						)
						else "first repair (−7)"
					),
					_persistent_scorch_text(),
				]
			)
		"Gremory":
			return (
				"This round — Ruin recovery %s; Guard insight %s; Harvest %s; Inevitable Ruin %s."
				% [
					_used_ready(
						bool(
							player.gremory_ruin_done
						)
					),
					_used_ready(
						bool(
							player.gremory_lord_guard_draw_done
						)
					),
					_used_ready(
						bool(
							player.gremory_veil_draw_done
						)
					),
					_used_ready(
						bool(
							player.gremory_inevitable_ruin_done
						)
					),
				]
			)
		"Odradek":
			return (
				"Recoil this round %s; Interlock bank %s; Reconfiguration %d/%d tokens; Guards defeated this round %d."
				% [
					_used_ready(
						bool(
							player.odradek_recoil_done
						)
					),
					("empty" if player.odradek_bank == null else _card_id(player.odradek_bank)),
					int(
						player.odradek_reconfig_tokens
					),
					int(
						controller.rules.reconfig_tokens_needed
					),
					int(
						player.odradek_guards_defeated
					),
				]
			)
		"Kanifous":
			return (
				"Invoked this round %d time(s); suit %s; high Invoke %s; outside draws %d; Invoke cost %s."
				% [
					int(
						player.kanifous_invokes_this_round
					),
					(
						"none"
						if String(
							player.kanifous_invoked_suit
						).is_empty()
						else String(
							player.kanifous_invoked_suit
						)
					),
					(
						"yes"
						if bool(
							player.kanifous_invoked_high
						)
						else "no"
					),
					int(
						player.kanifous_outside_draws
					),
					(
						"one Hand card"
						if controller.rules.kani_hand_cost
						else "one Threat"
					),
				]
			)

		"Humbaba":
			return (
				"Woven Into the Stones DEF %d with %d active Castles; Toll once per round when legal; Reactive Lane %s."
				% [
					int(player.derived_lord_def),
					player.castles.size(),
					(
						"available into %s" % controller.human_reactive_march_lane()
						if int(player.pid) == 0 and not controller.human_reactive_march_lane().is_empty()
						else "response-only"
					),
				]
			)

	return "No live ability state."


func _dominion_help_text(
	veil_total: int
) -> String:
	if controller == null or controller.rules == null:
		return "The Veil combines all personal and Neutral Tears."

	return (
		"DOMINION / VEIL — The Veil combines every personal and Neutral Tear. "
		+ "Collapse at %d and Waning at %d each strip the lowest Guard from a zone "
		+ "attacked last round during Resolution Prelude; both effects stack at %d+. "
		+ "At Cataclysm %d, and after each later Tear, Dominion is checked. A player "
		+ "must lead in personal Tears and hold at least %d; Lord effects can raise "
		+ "that requirement. Final Collapse at %d ends the game and Souls decide "
		+ "the winner. Current Veil: %d."
	) % [
		VEIL_COLLAPSE_THRESHOLD,
		VEIL_WANING_THRESHOLD,
		VEIL_WANING_THRESHOLD,
		int(controller.rules.dominion_track),
		int(controller.rules.dominion_requirement),
		int(controller.rules.final_collapse_threshold),
		veil_total,
	]


func _castle_status_inline_with_help(
	player
) -> String:
	var castle_text: String = _castle_status_inline(player)

	for castle_name_value in CASTLE_HELP.keys():
		var castle_name: String = String(castle_name_value)
		var help_text: String = String(
			CASTLE_HELP.get(castle_name, "")
		)
		castle_text = castle_text.replace(
			castle_name,
			"[hint=%s]%s[/hint]" % [
				help_text,
				castle_name,
			]
		)

	return castle_text


func _persistent_scorch_text() -> String:
	var player_id: int = int(
		controller.game.persist_scorch_pid
	)
	var zone: String = String(
		controller.game.persist_scorch_type
	)

	if (
		player_id < 0
		or zone.is_empty()
	):
		return "none"

	return "%s %s" % [
		_player_name(
			player_id
		),
		zone,
	]


func _used_ready(
	used: bool
) -> String:
	return (
		"used"
		if used
		else "ready"
	)


func _sigil_text(
	player
) -> String:
	var parts: Array[String] = []

	for zone: String in [
		"Lord",
		"Castle",
	]:
		var state: String = String(
			player.sigils.get(
				zone,
				""
			)
		)

		if not state.is_empty():
			parts.append(
				"%s:%s (+%d)"
				% [
					zone,
					state,
					_current_sigil_value(
						player,
						zone
					),
				]
			)

	return (
		"none"
		if parts.is_empty()
		else ", ".join(
			parts
		)
	)


func _cards_inline(
	cards: Array
) -> String:
	if cards.is_empty():
		return "—"

	var identifiers: Array[String] = []

	for card in cards:
		identifiers.append(
			_card_id(
				card
			)
		)

	return ", ".join(
		identifiers
	)


func _public_guard_summary(
	guards: Array
) -> String:
	if guards.is_empty():
		return "—"

	var visible_parts: Array[String] = []
	var hidden_count: int = 0

	for guard in guards:
		if controller.is_guard_revealed(
			guard
		):
			visible_parts.append(
				"%s (revealed)"
				% _card_id(
					guard
				)
			)
		else:
			hidden_count += 1

	if hidden_count > 0:
		visible_parts.append(
			"%d face-down Guard%s"
			% [
				hidden_count,
				(
					""
					if hidden_count == 1
					else "s"
				),
			]
		)

	return ", ".join(
		visible_parts
	)


func _strings_inline(
	values: Array
) -> String:
	if values.is_empty():
		return "—"

	var result: Array[String] = []

	for value in values:
		result.append(
			String(
				value
			)
		)

	return ", ".join(
		result
	)


func _string_values_inline(
	values
) -> String:
	if typeof(
		values
	) != TYPE_ARRAY:
		return "no cards"

	var raw_values: Array = values

	if raw_values.is_empty():
		return "no cards"

	var result: Array[String] = []

	for value in raw_values:
		result.append(
			String(
				value
			)
		)

	return ", ".join(
		result
	)


func _card_value_total(
	cards: Array
) -> int:
	var total: int = 0

	for card in cards:
		total += int(
			card.value
		)

	return total


func _card_id(
	card
) -> String:
	if card == null:
		return ""

	return "%s:%d" % [
		String(
			card.suit
		),
		int(
			card.value
		),
	]


func _validated_seed() -> int:
	var stripped: String = (
		seed_edit.text.strip_edges()
	)

	if not stripped.is_valid_int():
		seed_edit.text = str(
			DEFAULT_SEED
		)
		return DEFAULT_SEED

	var seed_value: int = int(
		stripped
	)

	if seed_value < 0:
		seed_value = abs(
			seed_value
		)

	seed_edit.text = str(
		seed_value
	)

	return seed_value


func _log(
	message: String
) -> void:
	log_entries.append(
		message
	)

	if log_entries.size() > 100:
		log_entries.pop_front()

	event_log.text = "\n".join(
		log_entries
	)


func _set_action_enabled(
	action_name: String,
	enabled: bool
) -> void:
	var button: Button = action_buttons.get(
		action_name,
		null
	)

	if button != null:
		button.disabled = not enabled


func _new_panel(
	color: Color
) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(
		0.27,
		0.21,
		0.32,
		1.0
	)
	style.set_border_width_all(
		1
	)
	style.set_corner_radius_all(
		5
	)
	style.content_margin_left = 12.0
	style.content_margin_top = 9.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 9.0
	panel.add_theme_stylebox_override(
		"panel",
		style
	)
	return panel


func _new_lord_card_panel() -> PanelContainer:
	var panel := _new_panel(
		Color(
			0.045,
			0.035,
			0.06,
			0.92
		)
	)
	panel.custom_minimum_size = Vector2(
		0,
		225
	)
	panel.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)

	var card_label := _new_rich_text()
	card_label.custom_minimum_size = Vector2(
		0,
		205
	)
	card_label.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	card_label.add_theme_font_size_override(
		"normal_font_size",
		13
	)
	card_label.add_theme_font_size_override(
		"bold_font_size",
		13
	)
	panel.add_child(
		card_label
	)
	panel.set_meta(
		"card_label",
		card_label
	)

	return panel


func _new_label(
	text_value: String,
	font_size: int
) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override(
		"font_size",
		font_size
	)
	label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	return label


func _new_button(
	text_value: String,
	minimum_width: float
) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(
		minimum_width,
		40
	)
	button.add_theme_font_size_override(
		"font_size",
		16
	)
	return button


func _new_rich_text() -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = false
	label.add_theme_font_size_override(
		"normal_font_size",
		15
	)
	label.add_theme_font_size_override(
		"bold_font_size",
		15
	)
	return label


func _on_viewport_size_changed() -> void:
	call_deferred(
		"_validate_layout_invariants"
	)


func _validate_layout_invariants() -> void:
	if not is_inside_tree():
		return

	var failures: Array[String] = []
	var viewport_rect: Rect2 = get_viewport_rect()
	var root_rect := Rect2(
		Vector2.ZERO,
		size
	)

	if (
		abs(
			root_rect.size.x
			- viewport_rect.size.x
		) > 1.0
		or abs(
			root_rect.size.y
			- viewport_rect.size.y
		) > 1.0
	):
		failures.append(
			"root does not match viewport"
		)

	for named_control: Control in [
		setup_row,
		board_row,
		marching_board_panel,
		interaction_panel,
		footer_row,
	]:
		if (
			named_control == null
			or named_control.size.x <= 0.0
			or named_control.size.y <= 0.0
		):
			failures.append(
				"major layout region has no area"
			)

	var visible_cards: Array[Button] = []

	for card_button: Button in card_buttons:
		if card_button.visible:
			visible_cards.append(
				card_button
			)

	for first_index: int in range(
		visible_cards.size()
	):
		for second_index: int in range(
			first_index + 1,
			visible_cards.size()
		):
			var first_rect: Rect2 = (
				visible_cards[first_index]
				.get_global_rect()
			)
			var second_rect: Rect2 = (
				visible_cards[second_index]
				.get_global_rect()
			)

			if first_rect.intersects(
				second_rect
			):
				failures.append(
					"hand card controls overlap"
				)
				break

	assert(
		failures.is_empty(),
		"Playable prototype layout invariant failed: %s"
		% "; ".join(
			failures
		)
	)
