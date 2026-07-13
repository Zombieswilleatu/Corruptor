class_name GameDealFixture
extends RefCounted


const CardData = preload("res://Scripts/Sim/Card.gd")
const GameStateData = preload("res://Scripts/Sim/GameState.gd")


const ALL_CASTLES: Array[String] = [
	"Keep",
	"Bastion",
	"SummoningCircle",
	"Stockpile",
	"SiegeEngine",
]


static func build_game_deimos_valak_s1():
	var game = GameStateData.new(
		["Deimos"],
		["Valak"]
	)

	game.round = 0
	game.first_player = 1

	game.breach = ""
	game.breach_owner = -1
	game.reflex_winner = -1

	game.neutral_tears = 0
	game.veil_total = 0

	game.winner = -1
	game.win_by = ""

	game.deck = _cards_from_ids([
		"Wright:2",
		"Vulture:3",
		"Vulture:4",
		"Vulture:1",
		"Wright:3",
		"Penitent:4",
		"Wright:5",
		"Butcher:2",
		"Penitent:1",
		"Penitent:1",
		"Vulture:3",
		"Vulture:1",
		"Wright:1",
		"Penitent:3",
		"Penitent:4",
		"Butcher:5",
		"Wright:1",
		"Butcher:2",
		"Butcher:1",
		"Butcher:3",
		"Butcher:1",
		"Butcher:3",
		"Vulture:3",
		"Penitent:2",
		"Vulture:4",
		"Wright:1",
		"Vulture:2",
		"Wright:2",
		"Butcher:3",
		"Vulture:5",
		"Penitent:5",
		"Wright:2",
		"Penitent:4",
		"Butcher:5",
		"Butcher:4",
		"Wright:3",
		"Vulture:5",
		"Vulture:4",
		"Wright:3",
		"Butcher:3",
		"Butcher:2",
		"Penitent:1",
		"Penitent:5",
		"Penitent:2",
		"Butcher:1",
		"Vulture:1",
		"Penitent:3",
	])

	game.discard = _cards_from_ids([
		"Vulture:2",
		"Penitent:3",
		"Wright:2",
		"Vulture:2",
	])

	game.market = _cards_from_ids([
		"Penitent:1",
		"Wright:1",
		"Wright:5",
	])

	_setup_deimos(game.players[0])
	_setup_valak(game.players[1])

	game.refresh_derived_values()

	return game


static func _setup_deimos(player) -> void:
	player.pid = 0
	player.lord = "Deimos"
	player.alive = true

	player.souls = 0
	player.tears = 0
	player.threat = 0
	player.kroni_hunger = 0
	player.repair_token = 0

	player.first_summon_done = true
	player.cataclysmic_used = false
	player.vessel_used = false
	player.vessel_offered_lord = ""
	player.kalligan_repair_used = false
	player.kroni_ravenous_used = false
	player.deimos_breach_claimed = false

	_reset_action_state(player)
	_reset_round_flags(player)

	player.hand = _cards_from_ids([
		"Butcher:4",
		"Penitent:3",
		"Wright:4",
	])

	player.garrison = []
	player.castle_guards = []
	player.lord_guards = []
	player.committed = []
	player.penitent_temp_guards = []

	_set_string_array(player.castles, ALL_CASTLES)
	player.ruined_castles.clear()
	player.profaned_castles.clear()

	player.sigils = {
		"Castle": "",
		"Lord": "",
	}

	player.derived_lord_def = 6


static func _setup_valak(player) -> void:
	player.pid = 1
	player.lord = "Valak"
	player.alive = true

	player.souls = 0
	player.tears = 0
	player.threat = 1
	player.kroni_hunger = 0
	player.repair_token = 0

	player.first_summon_done = true
	player.cataclysmic_used = false
	player.vessel_used = false
	player.vessel_offered_lord = ""
	player.kalligan_repair_used = false
	player.kroni_ravenous_used = false
	player.deimos_breach_claimed = false

	_reset_action_state(player)
	_reset_round_flags(player)

	player.hand = _cards_from_ids([
		"Butcher:4",
		"Vulture:2",
		"Wright:3",
	])

	player.garrison = []
	player.castle_guards = []
	player.lord_guards = []
	player.committed = []
	player.penitent_temp_guards = []

	_set_string_array(player.castles, ALL_CASTLES)
	player.ruined_castles.clear()
	player.profaned_castles.clear()

	player.sigils = {
		"Castle": "",
		"Lord": "",
	}

	player.derived_lord_def = 7


static func _set_string_array(
	target: Array[String],
	values: Array[String]
) -> void:
	target.clear()

	for value: String in values:
		target.append(value)


static func _reset_action_state(player) -> void:
	player.action = ""
	player.tgt_pid = -1
	player.tgt_type = ""
	player.ward_target = ""
	player.prev_ward_target = ""

	player.was_hunted = false
	player.was_sieged = false
	player.was_lord_attacked_prev = false
	player.was_castle_attacked_prev = false
	player.last_sieged_castle = ""

	player.pending_profane = ""
	player.orias_snare_active = false
	player.profane_ruins_used_this_round = false
	player.profane_this_round = false


static func _reset_round_flags(player) -> void:
	player.humbaba_patient = false

	player.odradek_recoil_done = false
	player.odradek_guards_defeated = 0

	player.gremory_ruin_done = false
	player.gremory_inevitable_ruin_done = false
	player.gremory_veil_draw_done = false
	player.gremory_lord_guard_draw_done = false

	player.kanifous_outside_draws = 0
	player.kanifous_invoked_suit = ""
	player.kanifous_invoked_high = false
	player.kanifous_invokes_this_round = 0

	player.kroni_consume_done = false
	player.kroni_personally_defeated_guard = false
	player.kroni_enemy_destroyed = false
	player.kroni_tear_milestone_fired = false


static func _cards_from_ids(card_ids: Array) -> Array:
	var cards: Array = []

	for card_identifier in card_ids:
		cards.append(
			_card_from_id(
				str(card_identifier)
			)
		)

	return cards


static func _card_from_id(card_identifier: String):
	var separator_index := card_identifier.rfind(":")

	assert(
		separator_index > 0,
		"Invalid Corruptor card identifier: %s"
		% card_identifier
	)

	var suit := card_identifier.substr(
		0,
		separator_index
	)

	var value_text := card_identifier.substr(
		separator_index + 1
	)

	assert(
		value_text.is_valid_int(),
		"Invalid Corruptor card value: %s"
		% card_identifier
	)

	return CardData.new(
		suit,
		int(value_text)
	)
