class_name PlayerState
extends RefCounted


var pid: int = 0
var lord: String = ""
var alive: bool = true

var souls: int = 0
var tears: int = 0
var threat: int = 0
var kroni_hunger: int = 0
var repair_token: int = 0

var repaired_this_round: bool = false
var repair_token_used_this_repair: bool = false

var first_summon_done: bool = false
var cataclysmic_used: bool = false
var vessel_used: bool = false
var vessel_offered_lord: String = ""
var kalligan_repair_used: bool = false
var kroni_ravenous_used: bool = false
var deimos_breach_claimed: bool = false

var action: String = ""
var tgt_pid: int = -1
var tgt_type: String = ""
var ward_target: String = ""
var prev_ward_target: String = ""

var was_hunted: bool = false
var was_sieged: bool = false
var was_lord_attacked_prev: bool = false
var was_castle_attacked_prev: bool = false
var last_sieged_castle: String = ""

var pending_profane: String = ""
var orias_snare_active: bool = false
var profane_ruins_used_this_round: bool = false
var profane_this_round: bool = false

var humbaba_patient: bool = false

var odradek_recoil_done: bool = false
var odradek_guards_defeated: int = 0

var gremory_ruin_done: bool = false
var gremory_inevitable_ruin_done: bool = false
var gremory_veil_draw_done: bool = false
var gremory_lord_guard_draw_done: bool = false

var kanifous_outside_draws: int = 0
var kanifous_invoked_suit: String = ""
var kanifous_invoked_high: bool = false
var kanifous_invokes_this_round: int = 0

var kroni_consume_done: bool = false
var kroni_personally_defeated_guard: bool = false
var kroni_enemy_destroyed: bool = false
var kroni_tear_milestone_fired: bool = false

var hand: Array = []
var garrison: Array = []
var castle_guards: Array = []
var lord_guards: Array = []
var committed: Array = []
var penitent_temp_guards: Array = []

var castles: Array[String] = []
var ruined_castles: Array[String] = []
var profaned_castles: Array[String] = []
var lord_pool: Array[String] = []

var sigils: Dictionary = {
	"Castle": "",
	"Lord": "",
}

var derived_lord_def: int = 0


func _init(
	p_pid: int = 0,
	p_lord_pool: Array[String] = []
) -> void:
	pid = p_pid
	lord_pool = p_lord_pool.duplicate()


func reset_round_state() -> void:
	was_lord_attacked_prev = was_hunted
	was_castle_attacked_prev = was_sieged

	action = ""
	tgt_pid = -1
	tgt_type = ""

	prev_ward_target = ward_target
	ward_target = ""

	was_hunted = false
	was_sieged = false
	last_sieged_castle = ""

	repaired_this_round = false
	repair_token_used_this_repair = false

	pending_profane = ""
	orias_snare_active = false
	profane_ruins_used_this_round = false
	profane_this_round = false

	odradek_recoil_done = false
	odradek_guards_defeated = 0

	gremory_ruin_done = false
	gremory_inevitable_ruin_done = false
	gremory_veil_draw_done = false
	gremory_lord_guard_draw_done = false

	kanifous_outside_draws = 0
	kanifous_invoked_suit = ""
	kanifous_invoked_high = false
	kanifous_invokes_this_round = 0

	kroni_consume_done = false
	kroni_personally_defeated_guard = false
	kroni_enemy_destroyed = false

	committed.clear()
	penitent_temp_guards.clear()


func duplicate_state() -> PlayerState:
	var copy := PlayerState.new(
		pid,
		lord_pool
	)

	copy.lord = lord
	copy.alive = alive

	copy.souls = souls
	copy.tears = tears
	copy.threat = threat
	copy.kroni_hunger = kroni_hunger
	copy.repair_token = repair_token

	copy.repaired_this_round = repaired_this_round
	copy.repair_token_used_this_repair = repair_token_used_this_repair

	copy.first_summon_done = first_summon_done
	copy.cataclysmic_used = cataclysmic_used
	copy.vessel_used = vessel_used
	copy.vessel_offered_lord = vessel_offered_lord
	copy.kalligan_repair_used = kalligan_repair_used
	copy.kroni_ravenous_used = kroni_ravenous_used
	copy.deimos_breach_claimed = deimos_breach_claimed

	copy.action = action
	copy.tgt_pid = tgt_pid
	copy.tgt_type = tgt_type
	copy.ward_target = ward_target
	copy.prev_ward_target = prev_ward_target

	copy.was_hunted = was_hunted
	copy.was_sieged = was_sieged
	copy.was_lord_attacked_prev = was_lord_attacked_prev
	copy.was_castle_attacked_prev = was_castle_attacked_prev
	copy.last_sieged_castle = last_sieged_castle

	copy.pending_profane = pending_profane
	copy.orias_snare_active = orias_snare_active
	copy.profane_ruins_used_this_round = profane_ruins_used_this_round
	copy.profane_this_round = profane_this_round

	copy.humbaba_patient = humbaba_patient

	copy.odradek_recoil_done = odradek_recoil_done
	copy.odradek_guards_defeated = odradek_guards_defeated

	copy.gremory_ruin_done = gremory_ruin_done
	copy.gremory_inevitable_ruin_done = gremory_inevitable_ruin_done
	copy.gremory_veil_draw_done = gremory_veil_draw_done
	copy.gremory_lord_guard_draw_done = gremory_lord_guard_draw_done

	copy.kanifous_outside_draws = kanifous_outside_draws
	copy.kanifous_invoked_suit = kanifous_invoked_suit
	copy.kanifous_invoked_high = kanifous_invoked_high
	copy.kanifous_invokes_this_round = kanifous_invokes_this_round

	copy.kroni_consume_done = kroni_consume_done
	copy.kroni_personally_defeated_guard = kroni_personally_defeated_guard
	copy.kroni_enemy_destroyed = kroni_enemy_destroyed
	copy.kroni_tear_milestone_fired = kroni_tear_milestone_fired

	copy.hand = _duplicate_cards(hand)
	copy.garrison = _duplicate_cards(garrison)
	copy.castle_guards = _duplicate_cards(castle_guards)
	copy.lord_guards = _duplicate_cards(lord_guards)
	copy.committed = _duplicate_cards(committed)
	copy.penitent_temp_guards = _duplicate_cards(
		penitent_temp_guards
	)

	copy.castles = castles.duplicate()
	copy.ruined_castles = ruined_castles.duplicate()
	copy.profaned_castles = profaned_castles.duplicate()
	copy.lord_pool = lord_pool.duplicate()

	copy.sigils = sigils.duplicate(true)
	copy.derived_lord_def = derived_lord_def

	return copy


func _duplicate_cards(
	cards: Array
) -> Array:
	var result: Array = []

	for card in cards:
		if (
			card != null
			and card.has_method(
				"duplicate_card"
			)
		):
			result.append(
				card.duplicate_card()
			)
		else:
			result.append(card)

	return result
