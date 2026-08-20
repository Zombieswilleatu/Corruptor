extends Control


const PlayableRoundControllerData = preload(
	"res://Prototype/PlayableRoundController.gd"
)

const SiegeResolutionEngineData = preload(
	"res://Scripts/Sim/SiegeResolutionEngine.gd"
)

const CastleIntegrityRulesData = preload(
	"res://Scripts/Sim/CastleIntegrityRules.gd"
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

const LordMathData = preload(
	"res://Scripts/Sim/LordMath.gd"
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

const ACTION_HELP: Dictionary = {
	"Hunt": (
		"HUNT — Attack the enemy Lord. Commit cards for attack strength; "
		+ "break through Guards, Sigils, and Lord DEF to Banishing the Lord "
		+ "and earn Souls."
	),
	"Siege": (
		"SIEGE — Attack one standing enemy Castle. Commit cards for attack "
		+ "strength; break its defenses and reduce Integrity. A Castle at "
		+ "0 Integrity becomes Ruined."
	),
	"Ward": (
		"WARD — Protect your Lord or Castle with a Sigil. Commit enough Ward "
		+ "strength to turn aside the opposing attack; a surviving Sigil "
		+ "continues to defend the zone."
	),
	"Profane": (
		"PROFANE — Sacrifice one of your own eligible full-Integrity Castles "
		+ "for Dominion progress. This is the sealed order, not the separate "
		+ "Profane the Ruins Dominion Rite."
	),
}

const CASTLE_ORDER: Array[String] = [
	"Keep",
	"Bastion",
	"SummoningCircle",
	"Stockpile",
	"SiegeEngine",
]

const DEFAULT_SEED: int = 20260724

const LORD_CARD_ABILITIES: Dictionary = {
	"Orias": [
		"[b]Snare[/b] — At the start of Development, if Orias is living and below Threat 3, gain 1 Threat to restrict the enemy Lord to one total Guard move this Development.",
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
		"[b]HUNGER[/b] — a counter that persists across rounds and resets when Kroni is resummoned. Lord DEF is 4 at 0, 6 at 1–2, and 8 at 3+. The first time he reaches 3 each game, gain 1 personal Tear. Warding or Passing loses 1 Hunger.",
		"[b]Consume[/b] — At End of Round, if any destruction occurred, gain 1 Hunger. If nothing was destroyed, discard your lowest Guard or Garrison card, gaining nothing.",
		"[b]Gorge[/b] — If Kroni personally defeated a Guard this round, gain 1 Soul.",
		"[b]Ravenous[/b] — At Hunger 3+, discard the opponent's lowest committed card. His next destroyed Lord or Castle grants +2 Souls and +1 Hunger.",
		"[b]Breach — Insatiable Hunger[/b] — While Kroni is Banished, both players lose their lowest Guard each round.",
	],
	"Kalligan": [
		"[b]SCORCH[/b] — A persistent fire starts at level 1, rises by 1 each round to 3, and defeats Guards at or below its level. It also burns matching-lane marchers at current value 2 or less. Each round it stands, gain Flame tokens equal to its level; 5 Flame becomes 1 Soul.",
		"[b]Forge-Repair[/b] — A living Kalligan restores +2 Integrity once per Repair action. Every such Repair Scorches the enemy Lord zone.",
		"[b]Pyroclasm[/b] — Sieges gain +1 strength, or +2 if the defender already has a Ruined Castle.",
		"[b]Wildfire / Inferno[/b] — After ruining a Castle, Scorch its Castle zone (or Lord if none remain). Inferno defeats the highest enemy Lord Guard without gaining Threat; if none exists, Scorch the Lord zone.",
		"[b]Breach[/b] — Every Repair restores +1 additional Integrity.",
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
		"[b]Woven Into the Stones[/b] — Lord DEF equals 2 + standing Castles; Threat reductions still apply. Bastion no longer adds Lord DEF.",
		"[b]Toll[/b] — Once per round under severe Soul pressure, ruin one of Humbaba's own Castles to remove 1 enemy Soul and create 1 Neutral Tear.",
		"[b]Reactive Lane[/b] — Humbaba may hold a second marcher only as a response. An enemy marcher must already occupy the lane, and the new marcher is forced into it; Humbaba cannot open two attacks.",
		"[b]Breach: The Stones Forget[/b] — While Humbaba is Banished, every active Castle has 1 less structural DEF (minimum 1).",
	],
}


const UI_EXPLANATION_PATCH_VERSION: String = "ui-explanations-v2-castles-v74"

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
	"[hint=CASTLES — Each Castle has 14 maximum Integrity. At 7+ Integrity it is Operational; at 1–6 it is Defunct and its printed power is off; at 0 it is permanently Ruined. "
	+ "Ruined Castles remain visible and may fuel Profane the Ruins; Profaned Castles remain as spent, inactive Dominion husks. "
	+ "Bastion's physical wall is the exception and keeps screening while it stands. Repair restores Integrity; Wrights pay full value and other suits pay 1 less (minimum 1). "
	+ "Construction can add at most 5 Integrity of progress per Castle action. Only a full-Integrity Operational Castle may be Profaned. "
	+ "Suit identities: Butcher attacks efficiently; Penitent Wards at full value while other suits lose 1 Ward Strength (minimum 1); Wright Repairs efficiently; committing a Vulture scouts one enemy Guard area.]Castles[/hint]"
)

const CASTLE_HELP: Dictionary = {
	"Keep": (
		"KEEP — 14 maximum Integrity. Sanctuary (Operational at 7+): when your Lord "
		+ "would be Banished by a Hunt, transfer the exact lethal excess to Keep. If Keep "
		+ "can absorb it without being Ruined, your Lord survives."
	),
	"Bastion": (
		"BASTION — 14 maximum Integrity. Bulwark: while Bastion stands at any Integrity, "
		+ "Siege damage aimed at another Castle hits Bastion first; excess carries through. "
		+ "Bastion may also be targeted directly."
	),
	"SummoningCircle": (
		"SUMMONING CIRCLE — 14 maximum Integrity. Operational at 7+. Blood Conduit: "
		+ "when Threat would rise through a Lord-DEF breakpoint (2/3/4), burn 3 Integrity "
		+ "to prevent 1 Threat. Blood Offering: when Summoning, burn 3 Integrity to reduce "
		+ "the Summon cost by 3."
	),
	"Stockpile": (
		"STOCKPILE — 14 maximum Integrity. Selective Stores (Operational at 7+): after "
		+ "the normal Draw step, draw 2 cards, keep 1, and discard the other."
	),
	"SiegeEngine": (
		"SIEGE ENGINE — 14 maximum Integrity. Forge Discipline (Operational at 7+): "
		+ "your Sieges ignore the non-Butcher attack penalty. Guards and Sigils otherwise "
		+ "resolve in the normal order."
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
var bot_castle_card_buttons: Dictionary = {}
var human_castle_card_buttons: Dictionary = {}
var reveal_label: RichTextLabel = null
var event_log: RichTextLabel = null
var dominion_track_label: RichTextLabel = null
var dominion_progress: ProgressBar = null
var dominion_warning_label: RichTextLabel = null
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

	# The Castle-card board is intentionally taller than the original prototype.
	# Keep all phase controls pinned on-screen and let only the playfield scroll.
	var playfield_scroll := ScrollContainer.new()
	playfield_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	playfield_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	playfield_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	playfield_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	page.add_child(playfield_scroll)

	var playfield := VBoxContainer.new()
	playfield.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	playfield.add_theme_constant_override("separation", 10)
	playfield_scroll.add_child(playfield)

	board_row = _build_board_row()
	board_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	playfield.add_child(board_row)

	marching_board_panel = _build_marching_board()
	playfield.add_child(marching_board_panel)

	interaction_panel = _build_interaction_panel()
	page.add_child(interaction_panel)

	footer_row = _build_footer_row()
	page.add_child(footer_row)


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
		350,
		480
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
	bot_state_label.custom_minimum_size = Vector2(0, 128)
	bot_state_label.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	bot_box.add_child(
		bot_state_label
	)
	bot_box.add_child(
		_build_castle_card_board(false)
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
		480
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
		68
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

	dominion_warning_label = _new_rich_text()
	dominion_warning_label.custom_minimum_size = Vector2(
		0,
		42
	)
	dominion_warning_label.add_theme_font_size_override(
		"normal_font_size",
		13
	)
	dominion_warning_label.add_theme_font_size_override(
		"bold_font_size",
		13
	)
	dominion_warning_label.scroll_active = false
	center_box.add_child(
		dominion_warning_label
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
		350,
		480
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
	human_state_label.custom_minimum_size = Vector2(0, 128)
	human_state_label.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	human_box.add_child(
		human_state_label
	)
	human_box.add_child(
		_build_castle_card_board(true)
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
		44
	)
	target_info_label.fit_content = false
	target_info_label.scroll_active = false
	target_info_label.add_theme_font_size_override(
		"normal_font_size",
		12
	)
	target_info_label.add_theme_font_size_override(
		"bold_font_size",
		12
	)
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
		72
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
		if development_option_button != null:
			development_option_button.set_pressed_no_signal(false)
		_enter_development_choice("Castle action — repair one damaged Castle or add progress to one unbuilt Castle.")
		return

	if controller.stage == PlayableRoundControllerData.Stage.DOMINION_RITES:
		_enter_development_choice(
			(
				"Dominion Rites — Invocation costs 11 Hand value. "
				+ "Profane Ruins requires %d Ruined Castles and %d Hand value. "
				+ "If both are selected, chosen cards pay Invocation first."
			) % [
				int(controller.rules.profane_ruins_req),
				int(controller.rules.profane_ruins_cost),
			]
		)
		return

	if controller.stage == PlayableRoundControllerData.Stage.DEPLOY:
		_begin_deploy_guard_picker()
		return

	if controller.stage == PlayableRoundControllerData.Stage.MARCH:
		_begin_march_picker()
		return

	if controller.stage == PlayableRoundControllerData.Stage.SUMMON:
		_log(
			"Round %d: your Lord is banished. Select any Hand cards; unpaid Summon cost becomes Threat if the return stays at or below %d."
			% [
				int(
					controller.game.round
				),
				int(controller.rules.max_threat),
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
	_refresh_castle_cards(controller.get_human_player(), true)
	_refresh_castle_cards(controller.get_bot_player(), false)
	_refresh_selection_text()
	_refresh_staging_area()
	_refresh_target_info()


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
	if controller != null and controller.stage == PlayableRoundControllerData.Stage.REPAIR:
		_refresh_target_info()


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
	_refresh_castle_cards(controller.get_human_player(), true)
	_refresh_castle_cards(controller.get_bot_player(), false)
	if controller.stage == PlayableRoundControllerData.Stage.REPAIR:
		_refresh_all()


func _on_secondary_target_selected(
	_index: int
) -> void:
	_refresh_selection_text()
	_refresh_target_info()
	_refresh_marching_board()
	_refresh_castle_cards(controller.get_human_player(), true)
	_refresh_castle_cards(controller.get_bot_player(), false)


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
			"Resummon rejected: the selected cards leave too much Threat shortfall."
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
	if controller.stage == PlayableRoundControllerData.Stage.VULTURE_RECON:
		var recon_result: Dictionary = controller.resolve_human_vulture_recon(_selected_target_id())
		if _show_failure_if_needed(recon_result, false):
			_set_phase_message("Reconnaissance rejected: %s" % String(recon_result.get("reason", "invalid_recon")))
			return
		_log_guard_reveals()
		_set_phase_message("Reconnaissance complete. Resolve the revealed clash.")
		_refresh_all()
		return

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
		var castle_action: String = _selected_castle_action()
		var castle_name: String = _selected_castle_name()
		if castle_action.is_empty() or castle_name.is_empty():
			_set_phase_message("Choose a damaged Castle to repair or an available type to construct.")
			return
		if _selected_card_ids().is_empty():
			_set_phase_message("Select at least one Hand or Garrison card as payment.")
			return
		var repair_result: Dictionary = controller.resolve_human_repair({
			"action": castle_action,
			"castle": castle_name,
			"payment": _selected_card_ids(),
			"use_token": (
				castle_action == "repair"
				and development_option_button.button_pressed
			),
		})
		if _show_failure_if_needed(repair_result, false):
			_set_phase_message("Castle action rejected: %s" % String(repair_result.get("reason", "invalid_castle_action")))
			return
		_after_development(repair_result)
		return

	if controller.stage == PlayableRoundControllerData.Stage.DOMINION_RITES:
		var rite_payments: Dictionary = _selected_rite_payments()
		var rite_decision: Dictionary = {
			"invocation": (
				{
					"payment": rite_payments.get(
						"invocation",
						[]
					),
				}
				if development_option_button.button_pressed
				else {"pass": true}
			),
			"profane_ruins": (
				{
					"castle": _selected_target_id(),
					"payment": rite_payments.get(
						"profane_ruins",
						[]
					),
				}
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
		"You sealed %s with %d committed attack value."
		% [
			selected_action,
			human_commit.attack_value(
				controller.rules,
				selected_action == "Siege"
			),
		]
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

	if controller.stage == PlayableRoundControllerData.Stage.VULTURE_RECON:
		_refresh_target_options()
		_set_phase_message("Vulture Reconnaissance — choose one enemy Guard area to reveal before Resolution.")

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

	_refresh_target_info()

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
	_refresh_castle_cards(human, true)
	_refresh_castle_cards(bot, false)
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
			PlayableRoundControllerData.Stage.VULTURE_RECON,
			PlayableRoundControllerData.Stage.COMMITMENT,
			PlayableRoundControllerData.Stage.RESOLUTION_HUMBABA_TOLL,
			PlayableRoundControllerData.Stage.RESOLUTION_ACTION,
			PlayableRoundControllerData.Stage.RESOLUTION_VESSEL,
			PlayableRoundControllerData.Stage.RESOLUTION_REFLEX,
			PlayableRoundControllerData.Stage.RESOLUTION_ODRADEK_BREACH,
		]
	)
	target_select.visible = target_label.visible
	target_info_label.visible = true
	secondary_target_label.visible = (
		controller.stage == PlayableRoundControllerData.Stage.RESOLUTION_ODRADEK_BREACH
		or controller.stage == PlayableRoundControllerData.Stage.MARCH
	)
	secondary_target_select.visible = secondary_target_label.visible
	development_option_button.visible = false
	development_finish_button.visible = false

	match controller.stage:
		PlayableRoundControllerData.Stage.VULTURE_RECON:
			phase_label.text = "Reveal — Vulture Reconnaissance"
			confirm_button.text = "Reveal Guard Area"
			confirm_button.visible = true
			summon_button.visible = false
			skip_summon_button.visible = false
			reveal_button.visible = false
			resolve_button.visible = false
			next_round_button.visible = false

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
			phase_label.text = "Development — Castle Action"
			var selected_castle_action: String = _selected_castle_action()
			confirm_button.text = (
				"Construct"
				if selected_castle_action == "construct"
				else "Repair"
			)
			confirm_button.visible = true
			development_option_button.text = "Use Repair Token"
			development_option_button.disabled = int(human.repair_token) <= 0
			development_option_button.visible = selected_castle_action == "repair"
			if selected_castle_action != "repair":
				development_option_button.set_pressed_no_signal(false)
			development_finish_button.text = "Pass Castle Action"
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
				"Summon — cards + Threat = %d"
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
	var dominion_requirement: int = _effective_dominion_requirement()
	var dominion_help: String = _dominion_help_text(veil_total)
	if dominion_track_label != null:
		dominion_track_label.text = (
			"[center][b]DOMINION / VEIL[/b]  [b]%d/%d[/b]\n"
			+ "[color=#78d9a1][b]YOU[/b][/color]  Souls [b]%d/%d[/b] · Tears [b]%d/%d[/b]"
			+ "    |    [color=#dc8d9d][b]%s[/b][/color]  Souls [b]%d/%d[/b] · Tears [b]%d/%d[/b]\n"
			+ "Collapse [b]%d[/b]  ·  Waning [b]%d[/b]  ·  "
			+ "Cataclysm [b]%d[/b]  ·  Final [b]%d[/b][/center]"
		) % [
			veil_total,
			int(controller.rules.final_collapse_threshold),
			int(human.souls),
			int(controller.rules.win_souls),
			int(human.tears),
			dominion_requirement,
			String(bot.lord),
			int(bot.souls),
			int(controller.rules.win_souls),
			int(bot.tears),
			dominion_requirement,
			VEIL_COLLAPSE_THRESHOLD,
			VEIL_WANING_THRESHOLD,
			int(controller.rules.dominion_track),
			int(controller.rules.final_collapse_threshold),
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

	if dominion_warning_label != null:
		dominion_warning_label.text = _dominion_warning_text(
			human,
			bot,
			veil_total,
			dominion_requirement
		)
		dominion_warning_label.tooltip_text = dominion_help

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
		bool(human.alive) and _has_profanable_castle(human)
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

		if controller.stage == PlayableRoundControllerData.Stage.VULTURE_RECON:
			target_label.text = "Scout enemy Guards:"
			var recon_bot = controller.get_bot_player()
			if recon_bot != null:
				var lord_unknown: int = 0
				var castle_unknown: int = 0
				for card in recon_bot.lord_guards:
					if not controller.is_guard_revealed(card):
						lord_unknown += 1
				for card in recon_bot.castle_guards:
					if not controller.is_guard_revealed(card):
						castle_unknown += 1
				if lord_unknown > 0:
					_add_target_option("Lord Guards — %d unknown" % lord_unknown, "Lord")
				if castle_unknown > 0:
					_add_target_option("Castle Guards — %d unknown" % castle_unknown, "Castle")
			target_select.disabled = target_select.item_count <= 1
			_refresh_target_info()
			return

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
			target_label.text = "Castle action:"
			for castle_name: String in CASTLE_ORDER:
				var maximum: int = _castle_max_integrity(castle_name)
				if development_human.castles.has(castle_name):
					var current: int = int(
						development_human.castle_integrity.get(castle_name, maximum)
					)
					if current > 0 and current < maximum:
						var repair_id: String = "repair|%s" % castle_name
						_add_target_option(
							"Repair %s — %d/%d" % [castle_name, current, maximum],
							repair_id
						)
						if repair_id == previous_target_id:
							target_select.select(target_select.item_count - 1)
				elif _castle_type_is_buildable(development_human, castle_name):
					var progress: int = int(
						development_human.castle_construction_progress.get(castle_name, 0)
					)
					var construct_id: String = "construct|%s" % castle_name
					_add_target_option(
						"Construct %s — %d/%d" % [castle_name, progress, maximum],
						construct_id
					)
					if construct_id == previous_target_id:
						target_select.select(target_select.item_count - 1)
			target_select.disabled = target_select.item_count <= 0
			_refresh_target_info()
			return

		if controller.stage == PlayableRoundControllerData.Stage.DOMINION_RITES:
			target_label.text = "Profane:"
			_add_target_option("No Profane Ruins", "")
			for castle_name: String in development_human.ruined_castles:
				_add_target_option(castle_name, castle_name)
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
				var allow_consume: bool = controller.rules.consume_the_siege
				var allow_inferno: bool = (
					development_human.alive
					and String(development_human.lord) == "Kalligan"
				)

				if not allow_consume and not allow_inferno:
					_add_target_option("Resolve Siege", "siege:0:0")
				elif allow_consume and not allow_inferno:
					_add_target_option("Do not Consume", "siege:0:0")
					_add_target_option("Consume the Siege", "siege:1:0")
				elif not allow_consume and allow_inferno:
					_add_target_option("Do not use Inferno", "siege:0:0")
					_add_target_option("Use Inferno", "siege:0:1")
				else:
					_add_target_option("No Consume · no Inferno", "siege:0:0")
					_add_target_option("No Consume · Inferno", "siege:0:1")
					_add_target_option("Consume · no Inferno", "siege:1:0")
					_add_target_option("Consume · Inferno", "siege:1:1")
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
					"%s — current DEF %d"
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
			target_label.text = "Sacrifice (full Integrity only):"

			for castle_name: String in human.castles:
				if not _castle_profane_eligible(human, castle_name):
					continue
				_add_target_option(
					"%s — 14/14 Integrity" % castle_name,
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
		target_label.text = "%s target:" % _second_action_name()

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
		var allow_consume: bool = controller.rules.consume_the_siege
		var allow_inferno: bool = (
			human.alive
			and String(human.lord) == "Kalligan"
		)
		var siege_options: Array[Dictionary] = []

		if not allow_consume and not allow_inferno:
			siege_options.append({"label": "", "id": "|0|0"})
		elif allow_consume and not allow_inferno:
			siege_options.append({"label": " · no Consume", "id": "|0|0"})
			siege_options.append({"label": " · Consume", "id": "|1|0"})
		elif not allow_consume and allow_inferno:
			siege_options.append({"label": " · no Inferno", "id": "|0|0"})
			siege_options.append({"label": " · Inferno", "id": "|0|1"})
		else:
			siege_options.append({"label": " · no Consume · no Inferno", "id": "|0|0"})
			siege_options.append({"label": " · no Consume · Inferno", "id": "|0|1"})
			siege_options.append({"label": " · Consume · no Inferno", "id": "|1|0"})
			siege_options.append({"label": " · Consume · Inferno", "id": "|1|1"})

		for castle_name: String in opponent.castles:
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


func _selected_castle_action() -> String:
	var raw_target: String = _selected_target_id()
	var parts: PackedStringArray = raw_target.split("|")
	return parts[0] if parts.size() >= 2 else ""


func _selected_castle_name() -> String:
	var raw_target: String = _selected_target_id()
	var parts: PackedStringArray = raw_target.split("|")
	return parts[1] if parts.size() >= 2 else ""


func _castle_target_name(raw_target: String) -> String:
	var parts: PackedStringArray = raw_target.split("|")
	if parts.size() >= 2 and parts[0] in ["repair", "construct"]:
		return parts[1]
	return parts[0] if not parts.is_empty() else ""


func _castle_max_integrity(castle_name: String) -> int:
	return int(CastleIntegrityRulesData.max_integrity(castle_name))


func _castle_profane_eligible(player, castle_name: String) -> bool:
	if player == null or not player.castles.has(castle_name):
		return false
	if not controller.rules.profane_requires_full_integrity:
		return true
	var maximum: int = _castle_max_integrity(castle_name)
	return int(player.castle_integrity.get(castle_name, maximum)) >= maximum


func _has_profanable_castle(player) -> bool:
	for castle_name_value in player.castles:
		if _castle_profane_eligible(player, String(castle_name_value)):
			return true
	return false


func _castle_type_is_buildable(player, castle_name: String) -> bool:
	return (
		not player.castles.has(castle_name)
		and not player.ruined_castles.has(castle_name)
		and not player.profaned_castles.has(castle_name)
		and not player.lost_castles.has(castle_name)
	)


func _set_context_help(
	detail: String = ""
) -> void:
	if target_info_label == null:
		return

	var phase_text: String = _phase_help_text()

	if detail.is_empty():
		target_info_label.text = phase_text
		return

	target_info_label.text = (
		phase_text
		+ "\n"
		+ detail
	)


func _refresh_target_info() -> void:
	if target_info_label == null:
		return

	if controller == null or controller.game == null:
		_set_context_help()
		return

	if controller.stage == PlayableRoundControllerData.Stage.MARKET:
		_set_context_help(
			_market_trade_info()
		)
		return

	if controller.stage == PlayableRoundControllerData.Stage.REPAIR:
		_set_context_help(
			_castle_action_info()
		)
		return

	if controller.stage == PlayableRoundControllerData.Stage.MARCH:
		_set_context_help(
			(
				"[color=#c8b36a]Current choice: source zone → one Guard → lane. "
				+ "Clash damage %d each; suit advantage adds +%d. "
				+ "Vulture:5 evades normal clashes; Butcher:1 destroys it with itself.[/color]"
			) % [
				controller.rules.march_damage,
				controller.rules.march_suit_bonus,
			]
		)
		return

	if selected_action.is_empty():
		_set_context_help(
			"[color=#a99eac]Choose an option above to see its target-specific rules and numbers.[/color]"
		)
		return

	var human = controller.get_human_player()
	var bot = controller.get_bot_player()
	var detail: String = ""

	match selected_action:
		"Hunt":
			detail = _combat_target_text(
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
			var raw_target_id: String = (
				_selected_secondary_target_id()
				if controller.stage == PlayableRoundControllerData.Stage.RESOLUTION_ODRADEK_BREACH
				else _selected_target_id()
			)
			var target_parts: PackedStringArray = (
				raw_target_id.split("|")
			)
			var castle_name: String = (
				target_parts[0]
				if not target_parts.is_empty()
				else ""
			)

			if castle_name.is_empty():
				detail = (
					"[color=#a99eac]Choose a Castle.[/color]"
				)
			else:
				detail = _combat_target_text(
					bot,
					"Castle",
					castle_name,
					_castle_defense(
						castle_name
					),
					bool(
						controller.rules.siege_engine_bypass
						and human.castles.has(
							"SiegeEngine"
						)
					)
				)

		"Ward":
			var zone: String = (
				_selected_target_id()
			)

			if controller.rules.sigil_flat:
				detail = (
					"[color=#91c7ff][b]Ward %s:[/b] commit any suits. "
					+ "If your total is at least the opposing %s, the attack is turned. "
					+ "The Ward starts at +2 DEF and ages to +1 next round.[/color]"
				) % [
					zone,
					(
						"Hunt"
						if zone == "Lord"
						else "Siege"
					),
				]
			else:
				var fresh_value: int = (
					_prospective_sigil_value(
						human,
						"fresh"
					)
				)
				var flipped_value: int = (
					_prospective_sigil_value(
						human,
						"flipped"
					)
				)

				detail = (
					"[color=#91c7ff][b]Ward %s:[/b] fresh sigil +%d DEF; "
					+ "if the opposing %s beats your commitment, "
					+ "it enters flipped at +%d DEF.[/color]"
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
			detail = (
				"[color=#d8a0c8]Profane sacrifices %s. "
				+ "Only a full-Integrity Castle is eligible%s.[/color]"
			) % [
				_selected_target_id(),
				(
					" and enemy Sigils do not deny it"
					if controller.rules.fix_b
					else ""
				),
			]

	_set_context_help(
		detail
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
		if controller.is_guard_revealed(guard):
			revealed_guards.append(guard)
		else:
			hidden_guard_count += 1

	var revealed_guard_total: int = _card_value_total(revealed_guards)
	var sigil_state: String = String(defender.sigils.get(zone, ""))
	var sigil_value: int = _current_sigil_value(defender, zone)
	var sigil_name: String = "none" if sigil_state.is_empty() else sigil_state
	var guard_text: String = _public_guard_summary(guards)

	if zone == "Lord":
		var known_minimum: int = structural_defense + sigil_value + revealed_guard_total + 1
		var caveat: String = "before Ward/reveal effects"
		if hidden_guard_count > 0:
			caveat = "plus %d face-down Guard%s of unknown value" % [
				hidden_guard_count,
				"" if hidden_guard_count == 1 else "s",
			]
		return (
			"[b]%s layers:[/b] Lord DEF %d  |  %s  |  %s sigil +%d  |  "
			+ "[color=#f2d477]visible minimum %d strength[/color] (%s)"
		) % [
			target_name,
			structural_defense,
			guard_text,
			sigil_name,
			sigil_value,
			known_minimum,
			caveat,
		]

	var current_integrity: int = int(
		defender.castle_integrity.get(target_name, _castle_max_integrity(target_name))
	)
	var damage_floor: int = sigil_value + 1
	var ruin_floor: int = sigil_value + max(1, structural_defense)
	var caveat: String = "before Ward/reveal effects"

	if siege_engine_bypass:
		guard_text += " — structure resolves first; spill reaches these Guards"
	else:
		damage_floor += revealed_guard_total
		ruin_floor += revealed_guard_total
		if hidden_guard_count > 0:
			caveat = "plus %d face-down Guard%s of unknown value" % [
				hidden_guard_count,
				"" if hidden_guard_count == 1 else "s",
			]

	return (
		"[b]%s layers:[/b] current DEF [b]%d[/b] · Integrity %d/%d  |  %s  |  "
		+ "%s sigil +%d  |  [color=#f2d477]damage begins at %d; visible ruin at %d[/color] (%s)"
	) % [
		target_name,
		structural_defense,
		current_integrity,
		_castle_max_integrity(target_name),
		guard_text,
		sigil_name,
		sigil_value,
		damage_floor,
		ruin_floor,
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
				and _is_deploy_card_reserved(
					"Hand",
					card_identifier,
					hand_index
				)
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
			card_button.set_meta("card_suit", String(card.suit))
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
				and _is_deploy_card_reserved(
					"Garrison",
					garrison_identifier,
					garrison_index
				)
			):
				continue
			var garrison_button := _new_button("Garrison · %s" % garrison_identifier, 142)
			garrison_button.toggle_mode = true
			garrison_button.set_meta("card_id", garrison_identifier)
			garrison_button.set_meta("card_value", int(garrison_card.value))
			garrison_button.set_meta("card_suit", String(garrison_card.suit))
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
		var consume_siege: bool = (
			controller.rules.consume_the_siege
			and parts.size() >= 3
			and parts[1] == "1"
		)
		var use_inferno: bool = (
			human.alive
			and String(human.lord) == "Kalligan"
			and parts.size() >= 3
			and parts[2] == "1"
		)
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
	var human = controller.get_human_player()
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
			decision["consume_siege"] = (
				controller.rules.consume_the_siege
				and siege_parts.size() >= 2
				and siege_parts[1] == "1"
			)
			decision["use_inferno"] = (
				human.alive
				and String(human.lord) == "Kalligan"
				and siege_parts.size() >= 3
				and siege_parts[2] == "1"
			)
		"Ward":
			decision["ward_target"] = target_id

	return decision


func _build_odradek_breach_decision() -> Dictionary:
	return {
		"guess": _selected_target_id(),
		"stolen_action": _build_reflex_decision(true),
	}


func _selected_rite_payments() -> Dictionary:
	var invocation_ids: Array[String] = []
	var profane_ids: Array[String] = []
	var invocation_value: int = 0
	var profane_value: int = 0

	var use_invocation: bool = (
		development_option_button != null
		and development_option_button.button_pressed
	)

	for button: Button in card_buttons:
		if not button.button_pressed:
			continue

		if String(
			button.get_meta(
				"card_source",
				"Hand"
			)
		) != "Hand":
			continue

		var card_id: String = String(
			button.get_meta(
				"card_id",
				""
			)
		)

		var card_value: int = int(
			button.get_meta(
				"card_value",
				0
			)
		)

		if (
			use_invocation
			and invocation_value < 11
		):
			invocation_ids.append(
				card_id
			)
			invocation_value += card_value
		else:
			profane_ids.append(
				card_id
			)
			profane_value += card_value

	return {
		"invocation": invocation_ids,
		"invocation_value": invocation_value,
		"profane_ruins": profane_ids,
		"profane_value": profane_value,
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
	if controller == null or controller.rules == null:
		return false

	var human = controller.get_human_player()
	return (
		human != null
		and (
			not bool(controller.rules.repair_blocks_hand_deploy)
			or not bool(human.repaired_this_round)
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
	card_identifier: String,
	source_index: int
) -> bool:
	# queued_deploy_moves stores card identity rather than an instance handle.
	# Several physical copies can share the same card_id (for example Wright:4).
	# Reserve only as many OCCURRENCES as were actually queued; the previous
	# boolean-by-id filter hid every duplicate and could leave an open Guard slot
	# with an empty picker.
	var reserved_count: int = 0
	for move: Dictionary in queued_deploy_moves:
		if (
			String(move.get("source", "")) == source
			and String(move.get("card", "")) == card_identifier
		):
			reserved_count += 1

	if reserved_count <= 0:
		return false

	var human = controller.get_human_player()
	if human == null:
		return false

	var source_cards: Array = (
		human.hand
		if source == "Hand"
		else human.garrison
	)

	var occurrence: int = 0
	var upper_bound: int = min(
		source_index + 1,
		source_cards.size()
	)

	for index: int in range(
		max(0, upper_bound)
	):
		if _card_id(
			source_cards[index]
		) == card_identifier:
			occurrence += 1

	return occurrence > 0 and occurrence <= reserved_count


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

func _phase_help_text() -> String:
	if (
		controller == null
		or controller.game == null
		or controller.rules == null
	):
		return "[color=#a99eac]Start a match to see step-by-step rules here.[/color]"

	var human = controller.get_human_player()
	var bot = controller.get_bot_player()
	var prefix: String = "[color=#82c9ff][b]HOW TO PLAY THIS STEP[/b][/color] — "

	match controller.stage:
		PlayableRoundControllerData.Stage.DEVELOPMENT_SNARE:
			return (
				prefix
				+ "[b]Orias Snare.[/b] This is optional. Gain 1 Threat now to "
				+ "restrict the opponent to one total Guard move during this "
				+ "Development, or pass and keep your Threat unchanged."
			)

		PlayableRoundControllerData.Stage.MARKET:
			return (
				prefix
				+ "[b]Market.[/b] Trade exactly one card from your Hand for one "
				+ "of the three public Market cards, or pass. Use this to improve "
				+ "raw value or get the suit you need; the card you give becomes "
				+ "a new public offer."
			)

		PlayableRoundControllerData.Stage.REPAIR:
			return (
				prefix
				+ "[b]Castle Action.[/b] Choose one damaged standing Castle to "
				+ "Repair, or one unbuilt Castle to Construct. Repair payment must "
				+ "use Wright cards from Hand/Garrison; card value restores Integrity. "
				+ "Construction uses card value as progress and is capped at %d per action."
			) % int(controller.rules.construction_action_cap)

		PlayableRoundControllerData.Stage.DOMINION_RITES:
			return (
				prefix
				+ "[b]Dominion Rites.[/b] This is an optional scoring step. "
				+ "Cataclysmic Invocation: pay 11 Hand value for +1 personal Tear. "
				+ "Profane the Ruins: if you have at least %d Ruined Castles, pay "
				+ "%d Hand value, convert one Ruin into a Profaned husk, and gain "
				+ "+1 personal Tear. You may perform both; Invocation is paid first."
			) % [
				int(controller.rules.profane_ruins_req),
				int(controller.rules.profane_ruins_cost),
			]

		PlayableRoundControllerData.Stage.DEPLOY:
			return (
				prefix
				+ "[b]Deploy Guards.[/b] Put cards from Hand (and Garrison when legal) "
				+ "face-down into Guard zones. [b]Lord Guards[/b] are the first line "
				+ "against Hunts; [b]Castle Guards[/b] protect your Castles from Sieges. "
				+ "You fill the Lord zone first, then the Castle zone. You may leave slots empty."
			)

		PlayableRoundControllerData.Stage.MARCH:
			return (
				prefix
				+ "[b]Marching Orders.[/b] Launch one existing Guard face-up from "
				+ "your Lord or Castle zone into a lane, or pass. Marchers advance "
				+ "toward the enemy gate each round. Opposing marchers clash with "
				+ "simultaneous damage; suit advantage is Wright > Penitent > Vulture "
				+ "> Butcher > Wright. A marcher worth %d+ that reaches the enemy gate "
				+ "scores +1 personal Tear."
			) % int(controller.rules.march_threshold)

		PlayableRoundControllerData.Stage.SUMMON:
			return (
				prefix
				+ "[b]Summon.[/b] Your Lord is Banished. Select Hand cards worth at "
				+ "least %d to return %s to play, or choose Remain Banished. A living "
				+ "Lord restores its normal abilities and ends its active Breach."
			) % [
				controller.human_summon_cost(),
				String(human.lord) if human != null else "your Lord",
			]

		PlayableRoundControllerData.Stage.REFLEX_BID:
			return (
				prefix
				+ "[b]Reflex Bid.[/b] Secretly choose any number of Hand cards as "
				+ "a bid for the round's extra action. Highest total wins the "
				+ "Reflex/Momentum action after the two sealed orders resolve; a tie "
				+ "means no extra action. Bid cards are a real resource commitment."
			)

		PlayableRoundControllerData.Stage.COMMITMENT:
			return (
				prefix
				+ "[b]Seal an Order.[/b] Choose one action, choose its target, select "
				+ "the cards you want to commit, then click Seal Order. "
				+ "[b]Hunt[/b] attacks the enemy Lord · [b]Siege[/b] damages an enemy "
				+ "Castle · [b]Ward[/b] defends your Lord or Castle with a Sigil · "
				+ "[b]Profane[/b] sacrifices one of your own eligible full Castles "
				+ "for Dominion progress. Both players reveal together."
			)

		PlayableRoundControllerData.Stage.SEALED:
			return (
				prefix
				+ "[b]Orders are sealed.[/b] Your choice is locked and the opponent "
				+ "is still hidden. Click Reveal Orders to expose both plans."
			)

		PlayableRoundControllerData.Stage.VULTURE_RECON:
			return (
				prefix
				+ "[b]Vulture Reconnaissance.[/b] Your committed Vulture lets you "
				+ "peek at one enemy Guard area before Resolution. Choose the area "
				+ "whose hidden defense matters most to your current attack."
			)

		PlayableRoundControllerData.Stage.KANIFOUS_INVOKE:
			return (
				prefix
				+ "[b]Kanifous Invoke.[/b] Pay exactly one Hand card as the toll. "
				+ "Then choose one of the two revealed cards to invoke and bank in "
				+ "Garrison; its suit triggers Kanifous's matching Invocation effect."
			)

		PlayableRoundControllerData.Stage.KANIFOUS_WRIGHT:
			return (
				prefix
				+ "[b]Kanifous — Wright.[/b] Move up to two of your face-down Lord "
				+ "Guards into the Castle Guard zone, or move none. This is the "
				+ "Wright Invocation effect before Resolution continues."
			)

		PlayableRoundControllerData.Stage.REVEALED:
			return (
				prefix
				+ "[b]Read the clash.[/b] Both sealed orders and committed cards are "
				+ "now public. Higher committed value normally acts first; ties use "
				+ "the round's first player. Inspect the target information, then "
				+ "click Resolve Round."
			)

		PlayableRoundControllerData.Stage.RESOLUTION_HUMBABA_TOLL:
			return (
				prefix
				+ "[b]Humbaba's Toll.[/b] You may deliberately Ruin one of your own "
				+ "Castles to remove 1 enemy Soul and create 1 Neutral Tear, or pass. "
				+ "A Neutral Tear advances the Veil but belongs to neither player."
			)

		PlayableRoundControllerData.Stage.RESOLUTION_ACTION:
			return (
				prefix
				+ "[b]Action Options.[/b] Your sealed Hunt/Siege is ready to resolve. "
				+ "Choose any optional action modifier shown here (such as Consume "
				+ "or Inferno), then confirm the action."
			)

		PlayableRoundControllerData.Stage.RESOLUTION_VESSEL:
			return (
				prefix
				+ "[b]Offer the Vessel.[/b] After your action, you may sacrifice your "
				+ "living Lord. This trades board presence for Dominion: you gain a "
				+ "personal Tear while the opponent gains Soul. Pass to keep your Lord."
			)

		PlayableRoundControllerData.Stage.RESOLUTION_REFLEX:
			return (
				prefix
				+ "[b]%s Action.[/b] The bid winner receives one extra action now. "
				+ "Choose Hunt, Siege, or Ward and commit Hand cards for it, or pass. "
				+ "This action resolves immediately after the two main orders."
			) % _second_action_name()

		PlayableRoundControllerData.Stage.RESOLUTION_ODRADEK_BREACH:
			return (
				prefix
				+ "[b]Odradek — Paradox Geometry.[/b] Predict the opponent's %s "
				+ "action. A correct prediction discards their selected cards and "
				+ "lets Odradek steal and execute the action instead; you may also "
				+ "choose not to interfere."
			) % _second_action_name()

		PlayableRoundControllerData.Stage.RESOLUTION_GREMORY:
			return (
				prefix
				+ "[b]Gremory — Inevitable Ruin.[/b] After a Siege leaves its target "
				+ "standing, you may pay exactly two Hand/Garrison cards to Ruin that "
				+ "Castle anyway. This opportunity is once per round; pass to decline."
			)

		PlayableRoundControllerData.Stage.TERMINAL:
			var winner_name: String = (
				"the winner"
				if int(controller.game.winner) < 0
				else _player_name(int(controller.game.winner))
			)
			return (
				prefix
				+ "[b]Match complete.[/b] %s won by %s. Start a New Match to play again."
			) % [
				winner_name,
				String(controller.game.win_by),
			]

		PlayableRoundControllerData.Stage.INVALID:
			return (
				prefix
				+ "[b]Prototype halted.[/b] An invalid state or rejected transition "
				+ "stopped play. Check the Match Log or exported snapshot for the cause."
			)

	var bot_name: String = String(bot.lord) if bot != null else "the opponent"
	return (
		prefix
			+ "Follow the highlighted controls for this phase. Your opponent (%s) "
			+ "uses bot doctrine; the Match Log records what each completed step did."
	) % bot_name


func _hand_caption_text() -> String:
	if controller == null or controller.game == null:
		return "Commit cards (click to select):"

	if controller.stage == PlayableRoundControllerData.Stage.KANIFOUS_INVOKE:
		return "Invoke toll — choose exactly one Hand card to discard:"

	if controller.stage == PlayableRoundControllerData.Stage.MARKET:
		return "Give one Hand card (★ marks the strongest raw-value trade):"

	if controller.stage == PlayableRoundControllerData.Stage.DOMINION_RITES:
		return (
			"Dominion Rite payment — Hand only. Invocation costs 11; "
			+ "Profane Ruins costs %d. If both are selected, chosen cards "
			+ "pay Invocation first, then Profane Ruins:"
		) % int(controller.rules.profane_ruins_cost)

	if controller.stage == PlayableRoundControllerData.Stage.REPAIR:
		var castle_action: String = _selected_castle_action()
		var castle_name: String = _selected_castle_name()
		if castle_name.is_empty():
			return "Choose a damaged Castle or an available type:"
		if castle_action == "construct":
			return "Add Construction progress to %s (Hand or Garrison):" % castle_name
		return "Restore Integrity to %s — Wright cards only (Hand or Garrison):" % castle_name

	if controller.stage == PlayableRoundControllerData.Stage.DEPLOY:
		if _deploy_selection_limit() <= 0:
			return "%s Guard zone is full or unavailable — continue when ready." % deploy_target_zone
		return "Select cards for %s Guards:" % deploy_target_zone

	if controller.stage == PlayableRoundControllerData.Stage.MARCH:
		return "2. Choose one face-up Guard from %s:" % _selected_target_id()

	return "Commit cards (click to select):"


func _repair_integrity_bonus(use_token: bool) -> int:
	if controller == null or controller.game == null:
		return 0
	var human = controller.get_human_player()
	if human == null:
		return 0
	var bonus: int = 0
	if use_token and int(human.repair_token) > 0:
		bonus += int(controller.rules.repair_token_integrity)
	if String(human.lord) == "Kalligan" and bool(human.alive):
		bonus += int(controller.rules.master_builder_integrity)
	if String(controller.game.breach) == "Kalligan":
		bonus += int(controller.rules.rapid_construction_integrity)
	return bonus


func _castle_action_info() -> String:
	var action: String = _selected_castle_action()
	var castle_name: String = _selected_castle_name()
	if action.is_empty() or castle_name.is_empty():
		return "[color=#a99eac]Choose a damaged Castle to repair or an available Castle to construct.[/color]"

	var human = controller.get_human_player()
	var maximum: int = _castle_max_integrity(castle_name)
	var selected_payment: int = _selected_card_value()
	if action == "construct":
		var before: int = int(human.castle_construction_progress.get(castle_name, 0))
		var gain: int = selected_payment
		if int(controller.rules.construction_action_cap) > 0:
			gain = mini(gain, int(controller.rules.construction_action_cap))
		var after: int = mini(maximum, before + gain)
		return (
			"[color=#82c9ff][b]Construct %s:[/b] progress %d/%d  |  "
			+ "selected payment %d, progress +%d → %d/%d (max %d/action)[/color]"
		) % [castle_name, before, maximum, selected_payment, gain, after, maximum, int(controller.rules.construction_action_cap)]

	var before: int = int(human.castle_integrity.get(castle_name, maximum))
	var use_token: bool = (
		development_option_button != null
		and development_option_button.button_pressed
	)
	var bonus: int = _repair_integrity_bonus(use_token)
	var restored: int = mini(maximum - before, selected_payment + bonus)
	var after: int = before + maxi(0, restored)
	var bonus_text: String = ""
	if bonus > 0:
		bonus_text = " + %d bonus" % bonus
	return (
		"[color=#82c9ff][b]Repair %s:[/b] Wright payment only · Integrity %d/%d  |  "
		+ "selected %d%s → %d/%d[/color]"
	) % [castle_name, before, maximum, selected_payment, bonus_text, after, maximum]


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
	var total: int = 0
	if controller == null or controller.game == null:
		return _selected_card_value()
	var human = controller.get_human_player()
	var siege: bool = selected_action == "Siege"
	for button: Button in card_buttons:
		if not button.button_pressed:
			continue
		var printed: int = int(button.get_meta("card_value", 0))
		var suit: String = String(button.get_meta("card_suit", ""))
		var exempt: bool = suit == String(controller.rules.attack_penalty_exempt_suit)
		var forge_scope: String = String(controller.rules.siege_engine_scope)
		var forge: bool = (
			human.castles.has("SiegeEngine")
			and (forge_scope == "all" or (forge_scope == "siege" and siege))
		)
		if selected_action in ["Hunt", "Siege"] and not exempt and not forge:
			total += maxi(
				int(controller.rules.attack_offsuit_floor),
				printed - int(controller.rules.attack_offsuit_penalty)
			)
		else:
			total += printed
	if (
		controller.rules.odr_recoil_bank
		and human.lord == "Odradek"
		and human.odradek_bank != null
		and selected_action in ["Hunt", "Siege"]
	):
		total += human.attack_card_value(human.odradek_bank, controller.rules, siege)
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
		var action: String = _selected_castle_action()
		var castle_name: String = _selected_castle_name()
		var payment: int = _selected_card_value()
		if action == "construct" and not castle_name.is_empty():
			var progress: int = int(
				controller.get_human_player().castle_construction_progress.get(castle_name, 0)
			)
			var gain: int = payment
			if int(controller.rules.construction_action_cap) > 0:
				gain = mini(gain, int(controller.rules.construction_action_cap))
			selection_label.text = "%d cards · build %d/%d +%d → %d/%d (cap %d)" % [
				count, progress, _castle_max_integrity(castle_name), gain,
				mini(_castle_max_integrity(castle_name), progress + gain),
				_castle_max_integrity(castle_name), int(controller.rules.construction_action_cap),
			]
		elif action == "repair" and not castle_name.is_empty():
			var human = controller.get_human_player()
			var maximum: int = _castle_max_integrity(castle_name)
			var before: int = int(human.castle_integrity.get(castle_name, maximum))
			var bonus: int = _repair_integrity_bonus(
				development_option_button != null and development_option_button.button_pressed
			)
			selection_label.text = "%d cards · repair %d/%d → %d/%d" % [
				count,
				before,
				maximum,
				mini(maximum, before + payment + bonus),
				maximum,
			]
		else:
			selection_label.text = "%d cards · choose a Castle action" % count
	elif (
		controller != null
		and controller.stage == PlayableRoundControllerData.Stage.DOMINION_RITES
	):
		var rite_payments: Dictionary = _selected_rite_payments()
		var invocation_selected: bool = (
			development_option_button != null
			and development_option_button.button_pressed
		)
		var profane_selected: bool = not _selected_target_id().is_empty()

		if invocation_selected and profane_selected:
			selection_label.text = (
				"%d cards · Invocation %d/11 · Profane Ruins %d/%d"
				% [
					count,
					int(rite_payments.get("invocation_value", 0)),
					int(rite_payments.get("profane_value", 0)),
					int(controller.rules.profane_ruins_cost),
				]
			)
		elif invocation_selected:
			selection_label.text = (
				"%d cards · Invocation payment %d/11"
				% [
					count,
					int(rite_payments.get("invocation_value", 0)),
				]
			)
		elif profane_selected:
			selection_label.text = (
				"%d cards · Profane Ruins payment %d/%d"
				% [
					count,
					int(rite_payments.get("profane_value", 0)),
					int(controller.rules.profane_ruins_cost),
				]
			)
		else:
			selection_label.text = "%d cards · choose a Dominion Rite" % count
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
		if (
			cards_enabled
			and controller.stage == PlayableRoundControllerData.Stage.REPAIR
			and _selected_castle_action() == "repair"
			and String(controller.rules.repair_wright_mode) == "strict"
			and String(button.get_meta("card_suit", "")) != "Wright"
		):
			button.disabled = true

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
			var damage_done: int = int(action_result.get("structure_damage", 0))
			if damage_done > 0:
				outcome = "the Castle remains standing"
			else:
				outcome = "the attack stopped at %s"
				outcome = outcome % String(
					action_result.get(
						"stopped_at",
						"the defenses"
					)
				)

		var integrity_before: int = int(action_result.get("integrity_before", 0))
		var integrity_after: int = int(action_result.get("integrity_after", integrity_before))
		var structure_damage: int = int(action_result.get("structure_damage", 0))
		var spill: int = int(action_result.get("structure_spill", 0))
		var damage_text: String = (
			"dealt %d Integrity damage (%d→%d)" % [
				structure_damage,
				integrity_before,
				integrity_after,
			]
			if structure_damage > 0
			else "dealt no Integrity damage"
		)
		if spill > 0:
			damage_text += "; %d strength spilled past the structure" % spill

		_log(
			"[color=#e8e2eb][b]%s Siege:[/b] %s attacked %s's %s with %d strength; %s; defeated %s; %s.[/color]"
			% [
				source_name,
				_player_name(int(action_result.get("attacker_id", -1))),
				_player_name(int(action_result.get("defender_id", -1))),
				String(action_result.get("target_castle", "Castle")),
				int(action_result.get("strength", 0)),
				damage_text,
				(
					_string_values_inline(defeated)
					if not defeated.is_empty()
					else "no Guards"
				),
				outcome,
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
			scorch.get("discarded_cards", [])
		)
		var lane_cards: Array = _array_from(
			scorch.get("lane_burned_cards", [])
		)
		var burn_text: String = (
			"discarded %s" % _string_values_inline(discarded_cards)
			if not discarded_cards.is_empty()
			else "found no Guard at or below its threshold"
		)

		if not lane_cards.is_empty():
			burn_text += (
				"; lane burned %s"
				% _string_values_inline(lane_cards)
			)

		_log(
			"[color=#d8b4fe][b]Kalligan — SCORCH:[/b] %s's %s zone at level %d (threshold %d) %s; level is now %d.[/color]"
			% [
				_player_name(int(scorch.get("player_id", -1))),
				String(scorch.get("zone", "?")),
				int(scorch.get("level_before", 1)),
				int(scorch.get("threshold", 0)),
				burn_text,
				int(scorch.get("level_after", 1)),
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
			var inferno_threat_text: String = (
				"Gained 1 Threat and "
				if int(action_result.get("inferno_threat_gain", 0)) > 0
				else ""
			)
			_log(
				"[color=#d8b4fe][b]Kalligan — Inferno:[/b] %sburned the highest Lord Guard, %s.[/color]"
				% [inferno_threat_text, inferno_card]
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

	var momentum_refunded: Array = _array_from(
		aftermath.get(
			"momentum_refunded",
			[]
		)
	)

	if not momentum_refunded.is_empty():
		_log(
			"[color=#f2d477][b]Momentum refund:[/b] %s returned %s to Hand.[/color]"
			% [
				_player_name(player_id),
				_string_values_inline(momentum_refunded),
			]
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
		var fallback_hunger_text: String = "gained no Hunger"

		if bool(
			event.get(
				"fed_hunger",
				false
			)
		):
			fallback_hunger_text = "Hunger %d→%d" % [
				int(event.get("hunger_before", 0)),
				int(event.get("hunger_after", 0)),
			]

		_log(
			"[color=#d8b4fe][b]Kroni — Fallback Consume:[/b] Removed %s from %s and from play; %s.[/color]"
			% [
				String(event.get("removed_card", "?")),
				String(event.get("zone", "?")),
				fallback_hunger_text,
			]
		)
		_log_harvest_event(
			event,
			"Fallback Consume"
		)

	for raw_event in _array_from(
		finale.get("veil_drift_events", [])
	):
		if typeof(raw_event) != TYPE_DICTIONARY:
			continue

		var drift_event: Dictionary = raw_event
		if int(drift_event.get("neutral_tear_gain", 0)) > 0:
			_log(
				"[color=#f2d477][b]Graduated Veil Drift:[/b] Round %d created %d Neutral Tear(s); carry %.2f.[/color]"
				% [
					int(drift_event.get("round", 0)),
					int(drift_event.get("neutral_tear_gain", 0)),
					float(drift_event.get("accumulator_after", 0.0)),
				]
			)

	for raw_event in _array_from(
		finale.get("kalligan_events", [])
	):
		if typeof(raw_event) != TYPE_DICTIONARY:
			continue

		var flame_event: Dictionary = raw_event
		var soul_text: String = ""
		if int(flame_event.get("soul_gain", 0)) > 0:
			soul_text = (
				"; converted to %d Soul(s)"
				% int(flame_event.get("soul_gain", 0))
			)

		_log(
			"[color=#d8b4fe][b]Kalligan — Flame:[/b] +%d token(s), now %d%s.[/color]"
			% [
				int(flame_event.get("token_gain", 0)),
				int(flame_event.get("tokens_after", 0)),
				soul_text,
			]
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

		var source: String = String(event.get("source", ""))
		var reveal_name: String = (
			"Vulture — Reconnaissance"
			if source == "vulture_recon"
			else "Guard reveal"
		)
		_log(
			"[color=#f2d477][b]%s:[/b] %s's %s zone turns face-up — %s.[/color]"
			% [
				reveal_name,
				_player_name(int(event.get("defender_id", -1))),
				String(event.get("zone", "Guard")),
				_string_values_inline(cards),
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
	for raw_result in _array_from(phase_data.get("results", [])):
		if typeof(raw_result) != TYPE_DICTIONARY:
			continue

		var result: Dictionary = raw_result
		var action: String = String(result.get("action", ""))
		if action == "repair":
			var bonus: int = int(result.get("bonus", 0))
			var token_text: String = (
				", Repair Token"
				if bool(result.get("used_token", false))
				else ""
			)
			_log(
				"[color=#82c9ff][b]Repair:[/b] %s restored %d Integrity to %s (%d→%d) with %d payment%s%s.[/color]"
				% [
					_player_name(int(result.get("player_id", -1))),
					int(result.get("restored", 0)),
					String(result.get("castle", "unknown castle")),
					int(result.get("integrity_before", 0)),
					int(result.get("integrity_after", 0)),
					int(result.get("paid_total", 0)),
					" + %d bonus" % bonus if bonus > 0 else "",
					token_text,
				]
			)

			var repair_player = controller.game.get_player(
				int(result.get("player_id", -1))
			)
			if (
				repair_player != null
				and String(repair_player.lord) == "Kalligan"
				and bool(repair_player.alive)
			):
				_log(
					"[color=#d8b4fe][b]Kalligan — Forge-Repair:[/b] The Repair gained bonus Integrity and armed Scorch against the enemy Lord zone.[/color]"
				)
		elif action == "construct":
			var completed: bool = bool(result.get("completed", false))
			_log(
				"[color=#82c9ff][b]Construction:[/b] %s added %d to %s (%d→%d/14)%s.[/color]"
				% [
					_player_name(int(result.get("player_id", -1))),
					int(result.get("paid_total", 0)),
					String(result.get("castle", "unknown castle")),
					int(result.get("progress_before", 0)),
					int(result.get("progress_after", 0)),
					" — completed and now active" if completed else "",
				]
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
					"[color=#c8b36a][b]Profane the Ruins:[/b] %s paid %d with %s, converted ruined %s into a Profaned Castle, and gained 1 personal Tear (Veil now %d).[/color]"
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
	for castle_name: String in CASTLE_ORDER:
		var maximum: int = _castle_max_integrity(castle_name)
		if player.castles.has(castle_name):
			var integrity: int = int(player.castle_integrity.get(castle_name, maximum))
			labels.append("%s (%d/%d)" % [castle_name, integrity, maximum])
		elif player.ruined_castles.has(castle_name):
			labels.append("%s (ruined)" % castle_name)
		elif player.profaned_castles.has(castle_name):
			labels.append("%s (profaned)" % castle_name)
		elif player.lost_castles.has(castle_name):
			labels.append("%s (lost)" % castle_name)
		else:
			var progress: int = int(player.castle_construction_progress.get(castle_name, 0))
			if progress > 0:
				labels.append("%s (build %d/%d)" % [castle_name, progress, maximum])
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
				"Forge-Repair adds +%d Integrity per Repair%s. Persistent Scorch: %s."
				% [
					int(controller.rules.master_builder_integrity),
					(
						"; Breach adds +%d" % int(controller.rules.rapid_construction_integrity)
						if String(controller.game.breach) == "Kalligan"
						else ""
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


func _effective_dominion_requirement() -> int:
	if (
		controller == null
		or controller.game == null
		or controller.rules == null
	):
		return 0

	var player_summaries: Array = []

	for player in controller.game.players:
		player_summaries.append({
			"lord": String(player.lord),
			"alive": bool(player.alive),
		})

	return int(
		LordMathData.dominion_requirement(
			player_summaries,
			controller.rules
		)
	)


func _veil_gap_phrase(
	gap: int
) -> String:
	if gap <= 0:
		return "Cataclysm is live"
	if gap == 1:
		return "1 more Veil point"
	return "%d more Veil points" % gap


func _dominion_warning_text(
	human,
	bot,
	veil_total: int,
	requirement: int
) -> String:
	if (
		controller == null
		or controller.rules == null
		or human == null
		or bot == null
	):
		return ""

	var cataclysm: int = int(
		controller.rules.dominion_track
	)
	var veil_gap: int = maxi(
		0,
		cataclysm - veil_total
	)

	var human_tears: int = int(human.tears)
	var bot_tears: int = int(bot.tears)
	var human_ready: bool = human_tears >= requirement
	var bot_ready: bool = bot_tears >= requirement
	var bot_name: String = String(bot.lord)

	if (
		human_ready
		and bot_ready
		and human_tears == bot_tears
	):
		if veil_gap <= 0:
			return (
				"[center][color=#f2d477][b]DOMINION STANDOFF[/b] — "
				+ "both players have %d Tears. Dominion is live, but neither "
				+ "player leads; the next personal-Tear swing can decide the game."
				+ "[/color][/center]"
			) % human_tears

		return (
			"[center][color=#f2d477][b]DOMINION STANDOFF[/b] — "
			+ "both players have %d/%d Tears; %s until Cataclysm."
			+ "[/color][/center]"
		) % [
			human_tears,
			requirement,
			_veil_gap_phrase(veil_gap),
		]

	if bot_ready and bot_tears > human_tears:
		if veil_gap <= 0:
			return (
				"[center][color=#ff748f][b]⚠ DOMINION LIVE[/b] — "
				+ "%s has %d/%d Tears and leads %d–%d. "
				+ "A Dominion check can end the match.[/color][/center]"
			) % [
				bot_name,
				bot_tears,
				requirement,
				bot_tears,
				human_tears,
			]

		if veil_gap <= 2:
			return (
				"[center][color=#ff748f][b]⚠ DOMINION THREAT[/b] — "
				+ "%s has %d/%d Tears and leads %d–%d. "
				+ "%s arms Dominion.[/color][/center]"
			) % [
				bot_name,
				bot_tears,
				requirement,
				bot_tears,
				human_tears,
				_veil_gap_phrase(veil_gap),
			]

		return (
			"[center][color=#e9b96e][b]DOMINION READY — %s[/b] has %d/%d Tears "
			+ "and currently leads. %s until Cataclysm.[/color][/center]"
		) % [
			bot_name,
			bot_tears,
			requirement,
			_veil_gap_phrase(veil_gap),
		]

	if (
		bot_tears == requirement - 1
		and veil_gap <= 2
	):
		return (
			"[center][color=#e9b96e][b]⚠ DOMINION PRESSURE[/b] — "
			+ "%s is one personal Tear from readiness; %s until Cataclysm."
			+ "[/color][/center]"
		) % [
			bot_name,
			_veil_gap_phrase(veil_gap),
		]

	if human_ready and human_tears > bot_tears:
		return (
			"[center][color=#8ee5a1][b]YOU ARE DOMINION-READY[/b] — "
			+ "%d/%d Tears and leading %d–%d. %s."
			+ "[/color][/center]"
		) % [
			human_tears,
			requirement,
			human_tears,
			bot_tears,
			_veil_gap_phrase(veil_gap),
		]

	if veil_gap <= 2:
		return (
			"[center][color=#f2d477][b]CATACLYSM APPROACHING[/b] — "
			+ "%s. Personal-Tear leadership will matter immediately."
			+ "[/color][/center]"
		) % _veil_gap_phrase(veil_gap)

	return (
		"[center][color=#8d8797]Dominion dormant — %s until Cataclysm. "
		+ "Personal Tears: you %d/%d · %s %d/%d.[/color][/center]"
	) % [
		_veil_gap_phrase(veil_gap),
		human_tears,
		requirement,
		bot_name,
		bot_tears,
		requirement,
	]


func _dominion_help_text(
	veil_total: int
) -> String:
	if controller == null or controller.rules == null:
		return "The Veil combines all personal and Neutral Tears."

	var requirement: int = _effective_dominion_requirement()

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
		requirement,
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

	return "%s %s · level %d" % [
		_player_name(player_id),
		zone,
		int(controller.game.persist_scorch_level),
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


func _build_castle_card_board(is_human: bool) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)

	var header := _new_label("CASTLE CARDS", 14)
	header.tooltip_text = "Castles have 14 maximum Integrity. Operational at 7+, Defunct at 1–6, Ruined at 0. Defunct printed powers are off; Bastion still screens while standing."
	box.add_child(header)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	box.add_child(grid)

	var card_map: Dictionary = (
		human_castle_card_buttons
		if is_human
		else bot_castle_card_buttons
	)

	for castle_name: String in CASTLE_ORDER:
		var card := Button.new()
		card.custom_minimum_size = Vector2(98, 72)
		card.add_theme_font_size_override("font_size", 12)
		card.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		card.focus_mode = Control.FOCUS_NONE
		card.set_meta("castle_name", castle_name)
		card.set_meta("is_human", is_human)
		card.pressed.connect(_on_castle_card_pressed.bind(is_human, castle_name))
		card_map[castle_name] = card
		grid.add_child(card)

	return box


func _on_castle_card_pressed(is_human: bool, castle_name: String) -> void:
	if controller == null or controller.game == null:
		return
	if not _castle_card_is_target_side(is_human):
		return

	var option_control: OptionButton = target_select
	var secondary: bool = false
	if (
		controller.stage == PlayableRoundControllerData.Stage.RESOLUTION_ODRADEK_BREACH
		and selected_action == "Siege"
	):
		option_control = secondary_target_select
		secondary = true

	for item_index: int in range(option_control.item_count):
		var raw_metadata = option_control.get_item_metadata(item_index)
		var raw_target: String = (
			String(raw_metadata)
			if raw_metadata != null
			else option_control.get_item_text(item_index)
		)
		if _castle_target_name(raw_target) != castle_name:
			continue
		option_control.select(item_index)
		if secondary:
			_on_secondary_target_selected(item_index)
		else:
			_on_target_selected(item_index)
		_refresh_castle_cards(controller.get_human_player(), true)
		_refresh_castle_cards(controller.get_bot_player(), false)
		return


func _castle_card_is_target_side(is_human: bool) -> bool:
	if controller == null or controller.game == null:
		return false
	if controller.stage in [
		PlayableRoundControllerData.Stage.REPAIR,
		PlayableRoundControllerData.Stage.DOMINION_RITES,
		PlayableRoundControllerData.Stage.RESOLUTION_HUMBABA_TOLL,
	]:
		return is_human
	if selected_action == "Profane":
		return is_human
	if selected_action == "Siege":
		return not is_human
	return false


func _refresh_castle_cards(player, is_human: bool) -> void:
	if player == null:
		return
	var card_map: Dictionary = (
		human_castle_card_buttons
		if is_human
		else bot_castle_card_buttons
	)
	var selected_raw: String = (
		_selected_secondary_target_id()
		if controller.stage == PlayableRoundControllerData.Stage.RESOLUTION_ODRADEK_BREACH
		and selected_action == "Siege"
		else _selected_target_id()
	)
	var selected_castle: String = _castle_target_name(selected_raw)
	var target_side: bool = _castle_card_is_target_side(is_human)

	for castle_name: String in CASTLE_ORDER:
		var card: Button = card_map.get(castle_name, null)
		if card == null:
			continue
		var maximum: int = _castle_max_integrity(castle_name)
		var state: String = "available"
		var detail: String = "AVAILABLE"
		var status: String = "Not built"

		if player.castles.has(castle_name):
			var integrity: int = int(player.castle_integrity.get(castle_name, maximum))
			var effective_defense: int = _castle_defense(castle_name, player)
			state = "full" if integrity >= maximum else "damaged"
			var castle_state: String = CastleIntegrityRulesData.state_for(
				player, castle_name, controller.rules
			)
			if state == "full":
				status = "Full"
			elif castle_state == CastleIntegrityRulesData.STATE_DEFUNCT:
				status = "Defunct"
			else:
				status = "Operational"
			detail = "INT %d / %d" % [integrity, maximum]
			if effective_defense != integrity:
				detail = "DEF %d · INT %d/%d" % [effective_defense, integrity, maximum]
		elif player.ruined_castles.has(castle_name):
			state = "ruined"
			detail = "RUINED · 0 INT"
			status = "Can fuel Profane Ruins"
		elif player.profaned_castles.has(castle_name):
			state = "profaned"
			detail = "PROFANED · +1 TEAR"
			status = "Spent Dominion husk"
		elif player.lost_castles.has(castle_name):
			state = "ruined"
			detail = "LOST"
			status = "Permanently unavailable"
		else:
			var progress: int = int(player.castle_construction_progress.get(castle_name, 0))
			if progress > 0:
				state = "building"
				detail = "BUILD %d / %d" % [progress, maximum]
				status = "Under construction"

		card.text = "%s\n%s\n%s" % [
			_castle_card_title(castle_name),
			detail,
			status.to_upper(),
		]
		var state_explanation: String = status
		if state == "ruined":
			state_explanation = (
				"RUINED — 0 Integrity and inactive. This Castle remains on the board "
				+ "as a ruin and can be converted by Profane the Ruins when its "
				+ "Castle-count and Hand-payment requirements are met."
			)
		elif state == "profaned":
			state_explanation = (
				"PROFANED — spent and inactive. This Castle has already been "
				+ "converted into Dominion progress (+1 personal Tear). It remains "
				+ "visible as a spent husk and cannot be rebuilt."
			)

		card.tooltip_text = "%s\n\n%s" % [
			String(CASTLE_HELP.get(castle_name, castle_name)),
			state_explanation,
		]
		var selectable: bool = target_side and _castle_option_exists(castle_name)
		card.disabled = not selectable
		_apply_castle_card_style(
			card,
			state,
			selectable and selected_castle == castle_name
		)


func _castle_option_exists(castle_name: String) -> bool:
	var option_control: OptionButton = target_select
	if (
		controller.stage == PlayableRoundControllerData.Stage.RESOLUTION_ODRADEK_BREACH
		and selected_action == "Siege"
	):
		option_control = secondary_target_select
	for item_index: int in range(option_control.item_count):
		var raw_metadata = option_control.get_item_metadata(item_index)
		var raw_target: String = (
			String(raw_metadata)
			if raw_metadata != null
			else option_control.get_item_text(item_index)
		)
		if _castle_target_name(raw_target) == castle_name:
			return true
	return false


func _castle_card_title(castle_name: String) -> String:
	match castle_name:
		"SummoningCircle":
			return "SUMMONING"
		"SiegeEngine":
			return "SIEGE ENGINE"
	return castle_name.to_upper()


func _apply_castle_card_style(card: Button, state: String, selected: bool) -> void:
	var background: Color = Color(0.09, 0.085, 0.12, 1.0)
	var border: Color = Color(0.29, 0.25, 0.34, 1.0)
	match state:
		"full":
			background = Color(0.07, 0.15, 0.12, 1.0)
			border = Color(0.28, 0.58, 0.45, 1.0)
		"damaged":
			background = Color(0.19, 0.12, 0.055, 1.0)
			border = Color(0.72, 0.47, 0.18, 1.0)
		"building":
			background = Color(0.06, 0.12, 0.18, 1.0)
			border = Color(0.25, 0.52, 0.72, 1.0)
		"ruined":
			background = Color(0.12, 0.045, 0.055, 1.0)
			border = Color(0.48, 0.16, 0.2, 1.0)
		"profaned":
			background = Color(0.13, 0.07, 0.16, 1.0)
			border = Color(0.78, 0.62, 0.24, 1.0)
	if selected:
		border = Color(0.95, 0.78, 0.3, 1.0)

	for style_name: String in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = background
		style.border_color = border
		style.set_border_width_all(3 if selected else 1)
		style.set_corner_radius_all(5)
		style.content_margin_left = 5.0
		style.content_margin_top = 5.0
		style.content_margin_right = 5.0
		style.content_margin_bottom = 5.0
		card.add_theme_stylebox_override(style_name, style)
	card.add_theme_color_override(
		"font_disabled_color",
		Color(0.86, 0.84, 0.9, 1.0)
	)


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
		175
	)
	panel.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)

	var card_label := _new_rich_text()
	card_label.custom_minimum_size = Vector2(
		0,
		155
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

	# Startup tests previously allowed a valid-size footer to sit below the
	# viewport. These two regions contain the controls required to advance play.
	for pinned_control: Control in [interaction_panel, footer_row]:
		if pinned_control == null:
			continue
		var pinned_rect: Rect2 = pinned_control.get_global_rect()
		if (
			pinned_rect.position.y < -1.0
			or pinned_rect.end.y > viewport_rect.size.y + 1.0
		):
			failures.append(
				"play controls outside viewport"
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
