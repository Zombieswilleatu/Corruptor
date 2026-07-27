class_name PlayableRoundController
extends RefCounted


const SeededGameSetupData = preload(
	"res://Scripts/Sim/SeededGameSetup.gd"
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

const CommitmentEngineData = preload(
	"res://Scripts/Sim/CommitmentEngine.gd"
)

const RevealEngineData = preload(
	"res://Scripts/Sim/RevealEngine.gd"
)

const ResolutionEngineData = preload(
	"res://Scripts/Sim/ResolutionEngine.gd"
)

const ResolutionPreludeEngineData = preload(
	"res://Scripts/Sim/ResolutionPreludeEngine.gd"
)

const ResolutionActionAftermathEngineData = preload(
	"res://Scripts/Sim/ResolutionActionAftermathEngine.gd"
)

const ReflexActionEngineData = preload(
	"res://Scripts/Sim/ReflexActionEngine.gd"
)

const ResolutionFinaleEngineData = preload(
	"res://Scripts/Sim/ResolutionFinaleEngine.gd"
)

const ResolutionCleanupEngineData = preload(
	"res://Scripts/Sim/ResolutionCleanupEngine.gd"
)

const BotRoundEngineData = preload(
	"res://Scripts/Sim/BotRoundEngine.gd"
)

const BotDoctrineData = preload(
	"res://Scripts/Sim/BotDoctrine.gd"
)

const PlayableBotDoctrineData = preload(
	"res://Prototype/PlayableBotDoctrine.gd"
)

const BotPolicyData = preload(
	"res://Scripts/Sim/BotPolicy.gd"
)

const BotSelectorData = preload(
	"res://Scripts/Sim/BotSelector.gd"
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

const BotResolutionDoctrineData = preload(
	"res://Scripts/Sim/BotResolutionDoctrine.gd"
)

const BotReflexDoctrineData = preload(
	"res://Scripts/Sim/BotReflexDoctrine.gd"
)

const CardData = preload(
	"res://Scripts/Sim/Card.gd"
)


enum Stage {
	NO_GAME,
	DEVELOPMENT_SNARE,
	MARKET,
	REPAIR,
	DOMINION_RITES,
	DEPLOY,
	SUMMON,
	REFLEX_BID,
	COMMITMENT,
	SEALED,
	REVEALED,
	KANIFOUS_INVOKE,
	KANIFOUS_WRIGHT,
	RESOLUTION_HUMBABA_TOLL,
	RESOLUTION_ACTION,
	RESOLUTION_VESSEL,
	RESOLUTION_REFLEX,
	RESOLUTION_ODRADEK_BREACH,
	RESOLUTION_GREMORY,
	TERMINAL,
	INVALID,
}


const HUMAN_PLAYER_ID: int = 0
const BOT_PLAYER_ID: int = 1
const UNKNOWN_GUARD_EXPECTED_VALUE: int = 3


var game = null
var rules: RuleConfig = null
var random_source = null
var policy = null

var stage: Stage = Stage.NO_GAME
var phase_results: Dictionary = {}
var events: Array[Dictionary] = []
var summon_choices: Dictionary = {}
var commitment_choices: Dictionary = {}
var revealed_guard_ids: Dictionary = {}
var guard_locations: Dictionary = {}
var guard_reveal_events: Array[Dictionary] = []
var resolution_state: Dictionary = {}
var kanifous_preview_cards: Array[String] = []
var kanifous_choice: Dictionary = {}
var pending_market_choices: Dictionary = {}
var pending_market_results: Array[Dictionary] = []

var last_result: Dictionary = {}


func start_match(
	human_lord: String,
	bot_lord: String,
	seed_value: int
) -> Dictionary:
	rules = RuleConfig.de_v2()
	policy = BotPolicyData.standard()

	var setup: Dictionary = (
		SeededGameSetupData.setup_locked_game(
			human_lord,
			bot_lord,
			seed_value,
			rules
		)
	)

	game = setup.get(
		"game",
		null
	)

	random_source = setup.get(
		"rng",
		null
	)

	assert(
		game != null,
		"Playable prototype setup did not return a GameState."
	)

	assert(
		random_source != null,
		"Playable prototype setup did not return an RNG."
	)

	stage = Stage.NO_GAME
	phase_results.clear()
	events.clear()
	summon_choices.clear()
	commitment_choices.clear()
	revealed_guard_ids.clear()
	guard_locations.clear()
	guard_reveal_events.clear()
	resolution_state.clear()
	kanifous_preview_cards.clear()
	kanifous_choice.clear()
	pending_market_choices.clear()
	pending_market_results.clear()
	last_result.clear()

	_sync_guard_visibility()

	return advance_to_commitment()


func advance_to_commitment() -> Dictionary:
	if game == null:
		return _invalid(
			"pre_round",
			"game_not_started"
		)

	if int(
		game.winner
	) >= 0:
		stage = Stage.TERMINAL
		last_result = _round_result(
			true,
			"pre_round"
		)
		return last_result

	var round_number: int = int(
		game.round
	) + 1

	phase_results = {}
	events = []
	summon_choices = {}
	commitment_choices = {}
	pending_market_choices.clear()
	pending_market_results.clear()

	RoundEngineData.begin_round(
		game,
		round_number
	)

	_record_phase(
		"begin_round",
		{
			"round": round_number,
		}
	)

	var sigil_result: Dictionary = (
		BotRoundEngineData._update_sigils(
			game,
			rules
		)
	)

	_record_phase(
		"sigil_update",
		sigil_result
	)

	var veil_result: Dictionary = (
		BotRoundEngineData._apply_veil_drift(
			game,
			rules
		)
	)

	_record_phase(
		"veil_drift",
		veil_result
	)

	if int(
		game.winner
	) >= 0:
		stage = Stage.TERMINAL
		last_result = _round_result(
			false,
			"veil_drift"
		)
		return last_result

	if _human_snare_available():
		stage = Stage.DEVELOPMENT_SNARE
		return _awaiting("orias_snare")

	return _resolve_development_start({})


func resolve_human_snare(
	activate: bool
) -> Dictionary:
	if stage != Stage.DEVELOPMENT_SNARE:
		return _rejected("orias_snare", "not_awaiting_orias_snare")

	return _resolve_development_start(
		({} if activate else {HUMAN_PLAYER_ID: {"pass": true}})
	)


func _resolve_development_start(
	snare_choices: Dictionary
) -> Dictionary:
	var development_start_result: Dictionary = DevelopmentStartEngineData.resolve(
		game,
		rules,
		random_source,
		snare_choices
	)
	_record_phase("development_start", development_start_result)

	var draw_result: Dictionary = BotRoundEngineData._resolve_normal_draws(
		game,
		rules,
		random_source
	)
	_record_phase("draw", draw_result)

	return _open_human_market()


func _human_snare_available() -> bool:
	var human = get_human_player()
	var bot = get_bot_player()
	return (
		human != null
		and bot != null
		and human.lord == "Orias"
		and human.alive
		and human.threat < 3
		and bot.hand.size() + bot.garrison.size() >= 2
	)


func resolve_human_market(
	decision: Dictionary
) -> Dictionary:
	if stage != Stage.MARKET:
		return _rejected(
			"market",
			"not_awaiting_market"
		)

	pending_market_choices[HUMAN_PLAYER_ID] = decision.duplicate(true)
	pending_market_results.append(RoundEngineData.resolve_market_player(
		game,
		HUMAN_PLAYER_ID,
		decision
	))

	if game.first_player == HUMAN_PLAYER_ID:
		_resolve_bot_market_turn()

	_record_phase("market", {
		"choices": pending_market_choices.duplicate(true),
		"results": pending_market_results.duplicate(true),
	})
	pending_market_choices.clear()
	pending_market_results.clear()

	# There is no decision to make if neither side has a Ruined Castle.
	# Skip the empty Repair prompt and move directly to Dominion Rites.
	if not _repair_phase_has_choices():
		stage = Stage.DOMINION_RITES
		return _awaiting("dominion_rites")

	stage = Stage.REPAIR
	return _awaiting("repair")


func _open_human_market() -> Dictionary:
	pending_market_choices.clear()
	pending_market_results.clear()
	# Market is sequential.  If the bot has priority, resolve that known turn
	# before showing the human a live Market selection.
	if game.first_player == BOT_PLAYER_ID:
		_resolve_bot_market_turn()
	stage = Stage.MARKET
	return _awaiting("market")


func _resolve_bot_market_turn() -> void:
	# The doctrine plans a complete shadow round.  Giving it the current board
	# with the bot as first player makes its first choice exactly the live turn
	# we are about to resolve, without inventing a human trade.
	var bot_market_view = _information_view(game, BOT_PLAYER_ID)
	bot_market_view.first_player = BOT_PLAYER_ID
	var bot_choices: Dictionary = BotDoctrineData.market_choices(
		bot_market_view,
		random_source
	)
	var bot_decision: Dictionary = _decision_for_player(
		bot_choices,
		BOT_PLAYER_ID
	)
	pending_market_choices[BOT_PLAYER_ID] = bot_decision.duplicate(true)
	pending_market_results.append(RoundEngineData.resolve_market_player(
		game,
		BOT_PLAYER_ID,
		bot_decision
	))


func resolve_human_repair(
	decision: Dictionary
) -> Dictionary:
	if stage != Stage.REPAIR:
		return _rejected("repair", "not_awaiting_repair")

	var human_result: Dictionary = RoundEngineData.resolve_repair_player(
		game,
		HUMAN_PLAYER_ID,
		rules,
		decision
	)

	if String(human_result.get("action", "")) == "invalid":
		return _rejected("repair", String(human_result.get("reason", "invalid_repair")))

	var bot_decision: Dictionary = _bot_repair_decision()
	var bot_result: Dictionary = RoundEngineData.resolve_repair_player(
		game,
		BOT_PLAYER_ID,
		rules,
		bot_decision
	)

	_record_phase("repair", {
		"choices": {HUMAN_PLAYER_ID: decision.duplicate(true), BOT_PLAYER_ID: bot_decision.duplicate(true)},
		"results": [human_result, bot_result],
	})
	stage = Stage.DOMINION_RITES
	return _awaiting("dominion_rites")


func _repair_phase_has_choices() -> bool:
	for player in game.players:
		if not player.ruined_castles.is_empty():
			return true

	return false


func resolve_human_dominion_rites(
	decision: Dictionary
) -> Dictionary:
	if stage != Stage.DOMINION_RITES:
		return _rejected("dominion_rites", "not_awaiting_dominion_rites")

	var human_result: Dictionary = DominionRiteEngineData.resolve_player(
		game,
		HUMAN_PLAYER_ID,
		rules,
		decision
	)

	if _rite_result_invalid(human_result):
		return _rejected("dominion_rites", _rite_invalid_reason(human_result))

	if int(game.winner) >= 0:
		_record_phase("dominion_rites", {
			"choices": {HUMAN_PLAYER_ID: decision.duplicate(true)},
			"results": [human_result],
		})
		stage = Stage.TERMINAL
		return _round_result(false, "dominion_rites")

	var bot_decision: Dictionary = _bot_rite_decision()
	var bot_result: Dictionary = DominionRiteEngineData.resolve_player(
		game,
		BOT_PLAYER_ID,
		rules,
		bot_decision
	)

	_record_phase("dominion_rites", {
		"choices": {HUMAN_PLAYER_ID: decision.duplicate(true), BOT_PLAYER_ID: bot_decision.duplicate(true)},
		"results": [human_result, bot_result],
	})

	if int(game.winner) >= 0:
		stage = Stage.TERMINAL
		return _round_result(false, "dominion_rites")

	stage = Stage.DEPLOY
	return _awaiting("deploy")


func resolve_human_deploy(
	decision: Dictionary
) -> Dictionary:
	if stage != Stage.DEPLOY:
		return _rejected("deploy", "not_awaiting_deploy")

	var human_result: Dictionary = DeployEngineData.resolve_player(
		game,
		HUMAN_PLAYER_ID,
		rules,
		decision
	)

	if String(human_result.get("action", "")) == "invalid":
		return _rejected("deploy", String(human_result.get("reason", "invalid_deploy")))

	var bot_decision: Dictionary = BotDeployDoctrineData.deploy_choice(
		_information_view(game, BOT_PLAYER_ID),
		BOT_PLAYER_ID,
		rules
	)
	var bot_result: Dictionary = DeployEngineData.resolve_player(
		game,
		BOT_PLAYER_ID,
		rules,
		bot_decision
	)

	_record_phase("deploy", {
		"choices": {HUMAN_PLAYER_ID: decision.duplicate(true), BOT_PLAYER_ID: bot_decision.duplicate(true)},
		"results": [human_result, bot_result],
	})

	_sync_guard_visibility()
	summon_choices = {BOT_PLAYER_ID: _bot_summon_decision()}

	var human = get_human_player()
	if human != null and not human.alive:
		stage = Stage.SUMMON
		return _awaiting("summon")

	return _resolve_summon_and_prepare_commitment(summon_choices)


func resolve_human_summon(
	payment_ids: Array[String],
	pass_summon: bool = false
) -> Dictionary:
	if stage != Stage.SUMMON:
		return _invalid(
			"summon",
			"not_awaiting_summon"
		)

	var human = get_human_player()

	if human == null:
		return _invalid(
			"summon",
			"human_player_missing"
		)

	var human_decision: Dictionary = {
		"pass": true,
	}

	if not pass_summon:
		var validation: Dictionary = (
			SummonEngineData._select_hand_payment(
				human,
				payment_ids,
				human_summon_cost()
			)
		)

		if not bool(
			validation.get(
				"valid",
				false
			)
		):
			return {
				"action": "invalid",
				"reason": String(
					validation.get(
						"reason",
						"invalid_summon_payment"
					)
				),
				"round": int(
					game.round
				),
				"completed": false,
				"terminal": false,
				"stopped_phase": "summon",
				"winner": -1,
				"win_by": "",
				"phases": phase_results,
				"events": events,
			}

		human_decision = {
			"lord": human_summon_lord(),
			"payment": payment_ids.duplicate(),
		}

	summon_choices[HUMAN_PLAYER_ID] = human_decision

	return _resolve_summon_and_prepare_commitment(
		summon_choices
	)


func human_summon_lord() -> String:
	var human = get_human_player()

	if human == null:
		return ""

	if not String(
		human.lord
	).is_empty():
		return String(
			human.lord
		)

	if not human.lord_pool.is_empty():
		return String(
			human.lord_pool[0]
		)

	return ""


func human_summon_cost() -> int:
	var human = get_human_player()

	if human == null:
		return 0

	return BotDevelopmentDoctrineData.summon_cost(
		game,
		human,
		rules,
		human_summon_lord()
	)


func _resolve_summon_and_prepare_commitment(
	decisions: Dictionary
) -> Dictionary:
	var breach_before: String = String(
		game.breach
	)
	var breach_owner_before: int = int(
		game.breach_owner
	)
	var summon_results: Array[Dictionary] = (
		SummonEngineData.resolve(
			game,
			rules,
			decisions
		)
	)

	var breach_closed: Dictionary = {}

	if not _contains_invalid(
		summon_results
	):
		breach_closed = _close_returned_breach(
			breach_before,
			breach_owner_before
		)

	var summon_phase: Dictionary = {
		"choices": decisions,
		"results": summon_results,
	}

	if not breach_closed.is_empty():
		summon_phase["breach_closed"] = breach_closed

	_record_phase(
		"summon",
		summon_phase
	)

	if _contains_invalid(
		summon_results
	):
		return _invalid(
			"summon",
			"invalid_summon"
		)

	if int(
		game.winner
	) >= 0:
		stage = Stage.TERMINAL
		last_result = _round_result(
			false,
			"summon"
		)
		return last_result

	if int(game.round) > 1:
		stage = Stage.REFLEX_BID
		return _awaiting("reflex_bid")

	var skipped_bid: Dictionary = ReflexBidEngineData.resolve(game, rules, {})
	_record_phase("reflex_bid", {"choices": {}, "result": skipped_bid})
	return _prepare_commitment()


func resolve_human_reflex_bid(
	decision: Dictionary
) -> Dictionary:
	if stage != Stage.REFLEX_BID:
		return _rejected("reflex_bid", "not_awaiting_reflex_bid")

	var bid_choices: Dictionary = {
		HUMAN_PLAYER_ID: decision.duplicate(true),
		BOT_PLAYER_ID: _bot_bid_decision(),
	}
	var bid_result: Dictionary = ReflexBidEngineData.resolve(game, rules, bid_choices)

	if String(bid_result.get("action", "")) == "invalid":
		return _rejected("reflex_bid", String(bid_result.get("reason", "invalid_reflex_bid")))

	_record_phase("reflex_bid", {"choices": bid_choices, "result": bid_result})
	return _prepare_commitment()


func _prepare_commitment() -> Dictionary:
	# The bot receives its masked information view and only its own sealed
	# order is generated.  Seat zero is left intentionally undecided until the
	# player seals an order in the interface.
	commitment_choices = {
		BOT_PLAYER_ID: PlayableBotDoctrineData.commitment_choice(
			_information_view(game, BOT_PLAYER_ID),
			BOT_PLAYER_ID,
			random_source,
			rules,
			policy
		),
	}

	stage = Stage.COMMITMENT
	return _awaiting("commitment")


func seal_human_commitment(
	human_decision: Dictionary
) -> Dictionary:
	if stage != Stage.COMMITMENT:
		return _invalid(
			"commitment",
			"not_awaiting_commitment"
		)

	commitment_choices[HUMAN_PLAYER_ID] = (
		human_decision.duplicate(
			true
		)
	)

	var commitment_result: Dictionary = (
		CommitmentEngineData.resolve(
			game,
			commitment_choices
		)
	)

	if String(
		commitment_result.get(
			"action",
			""
		)
	) == "invalid":
		# Commitment validates both sealed orders before changing the game.
		return {
			"action": "invalid",
			"reason": String(
				commitment_result.get(
					"reason",
					"invalid_commitment"
				)
			),
			"round": int(
				game.round
			),
			"completed": false,
			"terminal": false,
			"stopped_phase": "commitment",
			"winner": -1,
			"win_by": "",
			"phases": phase_results,
			"events": events,
		}

	_record_phase(
		"commitment",
		{
			"choices": commitment_choices,
			"result": commitment_result,
		}
	)

	stage = Stage.SEALED
	last_result = {
		"action": "sealed",
		"reason": "",
		"round": int(
			game.round
		),
		"completed": false,
		"terminal": false,
		"stopped_phase": "reveal",
		"winner": -1,
		"win_by": "",
		"phases": phase_results,
		"events": events,
	}

	return last_result


func reveal_orders() -> Dictionary:
	if stage != Stage.SEALED:
		return _invalid(
			"reveal",
			"orders_not_sealed"
		)

	var human = get_human_player()
	if human != null and human.lord == "Kanifous" and human.alive:
		var preview_result: Dictionary = RevealEngineData.resolve(
			_duplicate_game_with_metadata(),
			rules,
			_duplicate_random_source()
		)
		kanifous_preview_cards = _kanifous_revealed_cards(preview_result, HUMAN_PLAYER_ID)
		if not kanifous_preview_cards.is_empty():
			stage = Stage.KANIFOUS_INVOKE
			return _awaiting("kanifous_invoke")

	return _resolve_revealed_orders({})


func resolve_human_kanifous_invoke(
	chosen_card: String
) -> Dictionary:
	if stage != Stage.KANIFOUS_INVOKE:
		return _rejected("reveal", "not_awaiting_kanifous_invoke")
	if not kanifous_preview_cards.has(chosen_card):
		return _rejected("reveal", "kanifous_card_not_revealed")
	if _kanifous_suit(chosen_card) == "Wright":
		kanifous_choice = {"chosen_card": chosen_card}
		stage = Stage.KANIFOUS_WRIGHT
		return _awaiting("kanifous_wright")
	return _resolve_revealed_orders({HUMAN_PLAYER_ID: {"chosen_card": chosen_card}})


func resolve_human_kanifous_wright(
	guard_indices: Array[int]
) -> Dictionary:
	if stage != Stage.KANIFOUS_WRIGHT:
		return _rejected("reveal", "not_awaiting_kanifous_wright")

	var human = get_human_player()
	if human == null:
		return _invalid("reveal", "human_player_missing")
	if guard_indices.size() > 2:
		return _rejected("reveal", "wright_may_move_at_most_two_guards")

	var unique_indices: Array[int] = []
	for guard_index: int in guard_indices:
		if guard_index < 0 or guard_index >= human.lord_guards.size():
			return _rejected("reveal", "wright_guard_not_in_lord_zone")
		if unique_indices.has(guard_index):
			return _rejected("reveal", "wright_guard_selected_twice")
		unique_indices.append(guard_index)

	var remaining_capacity: int = max(
		0,
		RevealEngineData._max_castle_guards(human, rules) - human.castle_guards.size()
	)
	if unique_indices.size() > remaining_capacity:
		return _rejected("reveal", "wright_castle_guard_limit")

	var choice: Dictionary = kanifous_choice.duplicate(true)
	choice["wright_guard_indices"] = unique_indices
	var result: Dictionary = _resolve_revealed_orders({HUMAN_PLAYER_ID: choice})
	if String(result.get("action", "")) != "invalid":
		kanifous_choice.clear()
	return result


func _resolve_revealed_orders(
	kanifous_choices: Dictionary
) -> Dictionary:
	var reveal_result: Dictionary = RevealEngineData.resolve(
		game,
		rules,
		random_source,
		kanifous_choices
	)

	# Reveal effects can move Guards between zones. A Guard entering a new
	# zone starts hidden there, even if that physical card was seen before.
	_sync_guard_visibility()

	if String(
		reveal_result.get(
			"action",
			""
		)
	) == "invalid":
		return _invalid(
			"reveal",
			String(
				reveal_result.get(
					"reason",
					"invalid_reveal"
				)
			)
		)

	_record_phase(
		"reveal",
		reveal_result
	)
	kanifous_preview_cards.clear()

	stage = Stage.REVEALED
	last_result = {
		"action": "revealed",
		"reason": "",
		"round": int(
			game.round
		),
		"completed": false,
		"terminal": false,
		"stopped_phase": "resolution",
		"winner": -1,
		"win_by": "",
		"phases": phase_results,
		"events": events,
	}

	return last_result


func _kanifous_revealed_cards(
	reveal_result: Dictionary,
	player_id: int
) -> Array[String]:
	var result: Array[String] = []
	var raw_players = reveal_result.get("players", [])
	if typeof(raw_players) != TYPE_ARRAY:
		return result
	for raw_player in raw_players:
		if typeof(raw_player) != TYPE_DICTIONARY or int(raw_player.get("player_id", -1)) != player_id:
			continue
		var kanifous_event = raw_player.get("kanifous", {})
		if typeof(kanifous_event) != TYPE_DICTIONARY:
			return result
		var raw_cards = kanifous_event.get("revealed_cards", [])
		if typeof(raw_cards) != TYPE_ARRAY:
			return result
		for raw_card in raw_cards:
			result.append(String(raw_card))
		return result
	return result


func _kanifous_suit(
	card_identifier: String
) -> String:
	var split_identifier: PackedStringArray = card_identifier.split(":", false, 1)
	return String(split_identifier[0]) if not split_identifier.is_empty() else ""


func resolve_revealed_round() -> Dictionary:
	if stage != Stage.REVEALED:
		return _invalid(
			"resolution",
			"orders_not_revealed"
		)

	_reveal_primary_attack_guards()

	var resolution_choices: Dictionary = (
		BotResolutionDoctrineData.build_decisions(
			_information_view(
				game,
				BOT_PLAYER_ID
			),
			rules,
			commitment_choices,
			random_source,
			policy
		)
	)

	resolution_choices["reflex_provider"] = Callable(
		self,
		"_private_reflex_provider"
	)

	var resolution_result: Dictionary = (
		ResolutionEngineData.resolve(
			game,
			rules,
			resolution_choices,
			random_source
		)
	)

	if String(
		resolution_result.get(
			"action",
			""
		)
	) == "invalid":
		return _invalid(
			"resolution",
			String(
				resolution_result.get(
					"reason",
					"invalid_resolution"
				)
			)
		)

	_record_phase(
		"resolution",
		{
			"choices": resolution_choices,
			"result": resolution_result,
		}
	)

	# Remove revelation from defeated/removed Guards while preserving it for
	# survivors that remained in the same zone.
	_sync_guard_visibility()

	if int(
		game.winner
	) >= 0:
		stage = Stage.TERMINAL
	else:
		stage = Stage.NO_GAME

	last_result = _round_result(
		true,
		(
			"resolution"
			if stage == Stage.TERMINAL
			else ""
		)
	)

	return last_result


func begin_human_resolution() -> Dictionary:
	if stage != Stage.REVEALED:
		return _rejected("resolution", "orders_not_revealed")

	if _human_humbaba_toll_available():
		stage = Stage.RESOLUTION_HUMBABA_TOLL
		return _awaiting("humbaba_toll")

	return _begin_human_resolution_with_toll({})


func resolve_human_humbaba_toll(
	castle_name: String
) -> Dictionary:
	if stage != Stage.RESOLUTION_HUMBABA_TOLL:
		return _rejected("humbaba_toll", "not_awaiting_humbaba_toll")

	var choices: Dictionary = {HUMAN_PLAYER_ID: {"pass": true}}
	if not castle_name.is_empty():
		choices[HUMAN_PLAYER_ID] = {"castle": castle_name}
	return _begin_human_resolution_with_toll(choices)


func _begin_human_resolution_with_toll(
	toll_choices: Dictionary
) -> Dictionary:

	_reveal_primary_attack_guards()

	var action_choices: Dictionary = BotResolutionDoctrineData.action_choices(
		_information_view(game, BOT_PLAYER_ID),
		rules,
		commitment_choices
	)
	var prelude_result: Dictionary = ResolutionPreludeEngineData.resolve(
		game,
		rules,
		int(game.first_player),
		random_source,
		toll_choices
	)

	if String(prelude_result.get("action", "")) == "invalid":
		return _invalid("resolution", String(prelude_result.get("reason", "invalid_resolution_prelude")))

	resolution_state = {
		"action_choices": action_choices,
		"prelude_result": prelude_result,
		"order": prelude_result.get("order", []),
		"next_action_index": 0,
		"action_events": [],
		"reflex_result": {},
		"finale_result": {},
		"cleanup_result": {},
		"stopped_stage": "",
	}

	if int(game.winner) >= 0:
		resolution_state["stopped_stage"] = "prelude"
		return _finish_human_resolution()

	return _advance_human_resolution()


func _human_humbaba_toll_available() -> bool:
	var human = get_human_player()
	var bot = get_bot_player()
	if (
		human == null
		or bot == null
		or human.lord != "Humbaba"
		or not human.alive
		or human.castles.size() < 2
		or bot.souls <= 0
	):
		return false

	var total_after: int = int(game.calculate_veil_total()) + 1
	var feeds_racer: bool = bot.tears > human.tears and total_after >= rules.dominion_track - 3
	var emergency: bool = bot.souls >= rules.win_souls - 2
	var pressure: bool = bot.souls - human.souls >= 3 and bot.souls >= 4
	return (emergency or pressure) and not feeds_racer


func resolve_human_resolution_action(
	options: Dictionary
) -> Dictionary:
	if stage != Stage.RESOLUTION_ACTION:
		return _rejected("resolution_action", "not_awaiting_resolution_action")

	var player = get_human_player()
	if player == null:
		return _invalid("resolution_action", "human_player_missing")

	var action_result: Dictionary = ResolutionEngineData._resolve_committed_action(
		game,
		rules,
		player,
		options
	)

	if String(action_result.get("action", "")) == "invalid":
		return _rejected("resolution_action", String(action_result.get("reason", "invalid_committed_action")))

	resolution_state["pending_player_id"] = HUMAN_PLAYER_ID
	resolution_state["pending_committed_action"] = String(player.action)
	resolution_state["pending_action_result"] = action_result
	resolution_state["pending_action_options"] = options.duplicate(true)
	stage = Stage.RESOLUTION_VESSEL
	return _awaiting("resolution_vessel")


func resolve_human_vessel(
	decision: Dictionary
) -> Dictionary:
	if stage != Stage.RESOLUTION_VESSEL:
		return _rejected("resolution_vessel", "not_awaiting_resolution_vessel")

	var player_id: int = int(resolution_state.get("pending_player_id", -1))
	var action_result: Dictionary = resolution_state.get("pending_action_result", {})
	if player_id != HUMAN_PLAYER_ID or action_result.is_empty():
		return _invalid("resolution_vessel", "resolution_action_missing")

	var post_action_decision: Dictionary = decision.duplicate(true)
	post_action_decision["post_action"] = true
	var aftermath_preview: Dictionary = ResolutionActionAftermathEngineData.resolve(
		_duplicate_game_with_metadata(),
		rules,
		player_id,
		action_result,
		post_action_decision,
		_duplicate_random_source()
	)

	if String(aftermath_preview.get("action", "")) == "invalid":
		return _rejected("resolution_vessel", String(aftermath_preview.get("reason", "invalid_action_aftermath")))

	var aftermath_result: Dictionary = ResolutionActionAftermathEngineData.resolve(
		game,
		rules,
		player_id,
		action_result,
		post_action_decision,
		random_source
	)

	_append_resolution_action_event(
		player_id,
		String(resolution_state.get("pending_committed_action", "")),
		action_result,
		aftermath_result
	)
	resolution_state.erase("pending_player_id")
	resolution_state.erase("pending_committed_action")
	resolution_state.erase("pending_action_result")
	resolution_state.erase("pending_action_options")
	resolution_state["next_action_index"] = int(resolution_state.get("next_action_index", 0)) + 1

	if int(game.winner) >= 0 or bool(aftermath_result.get("stopped_on_win", false)):
		resolution_state["stopped_stage"] = "actions"
		return _finish_human_resolution()

	return _advance_human_resolution()


func resolve_human_reflex(
	decision: Dictionary
) -> Dictionary:
	if stage != Stage.RESOLUTION_REFLEX:
		return _rejected("reflex", "not_awaiting_human_reflex")

	var bot_breach_decision: Dictionary = {}
	if game.breach == "Odradek" and int(game.breach_owner) == BOT_PLAYER_ID:
		bot_breach_decision = _bot_odradek_breach_decision(HUMAN_PLAYER_ID)

	var reflex_result: Dictionary = ReflexActionEngineData.resolve(
		game,
		rules,
		decision,
		bot_breach_decision
	)
	if String(reflex_result.get("action", "")) == "invalid":
		return _rejected("reflex", String(reflex_result.get("reason", "invalid_reflex_action")))

	_record_reflex_guard_reveal(reflex_result)
	resolution_state["reflex_result"] = reflex_result
	return _after_human_reflex()


func resolve_human_odradek_breach(
	breach_decision: Dictionary
) -> Dictionary:
	if stage != Stage.RESOLUTION_ODRADEK_BREACH:
		return _rejected("reflex", "not_awaiting_odradek_breach")

	var winner_decision: Dictionary = _bot_reflex_decision(BOT_PLAYER_ID)
	var reflex_result: Dictionary = ReflexActionEngineData.resolve(
		game,
		rules,
		winner_decision,
		breach_decision
	)

	if String(reflex_result.get("action", "")) == "invalid":
		return _rejected("reflex", String(reflex_result.get("reason", "invalid_reflex_action")))

	_record_reflex_guard_reveal(reflex_result)
	resolution_state["reflex_result"] = reflex_result
	return _after_human_reflex()


func resolve_human_gremory(
	payment_ids: Array[String]
) -> Dictionary:
	if stage != Stage.RESOLUTION_GREMORY:
		return _rejected("cleanup", "not_awaiting_gremory")

	var human_choice: Dictionary = {"pass": true}
	if not payment_ids.is_empty():
		human_choice = {"payment": payment_ids.duplicate()}

	return _resolve_human_cleanup(human_choice)


func _advance_human_resolution() -> Dictionary:
	var raw_order = resolution_state.get("order", [])
	if typeof(raw_order) != TYPE_ARRAY:
		return _invalid("resolution", "resolution_order_not_array")
	var order: Array = raw_order

	while int(resolution_state.get("next_action_index", 0)) < order.size():
		var next_index: int = int(resolution_state.get("next_action_index", 0))
		var player_id: int = int(order[next_index])

		if player_id == HUMAN_PLAYER_ID:
			stage = Stage.RESOLUTION_ACTION
			return _awaiting("resolution_action")

		var player = game.get_player(player_id)
		if player == null:
			return _invalid("resolution", "resolution_player_missing_%d" % player_id)

		var action_choices: Dictionary = resolution_state.get("action_choices", {})
		var options: Dictionary = _decision_for_player(action_choices, player_id)
		var action_result: Dictionary = ResolutionEngineData._resolve_committed_action(game, rules, player, options)
		if String(action_result.get("action", "")) == "invalid":
			return _invalid("resolution", String(action_result.get("reason", "invalid_committed_action")))

		var aftermath_result: Dictionary = ResolutionActionAftermathEngineData.resolve(
			game,
			rules,
			player_id,
			action_result,
			{"reevaluate_after_action": true},
			random_source
		)
		if String(aftermath_result.get("action", "")) == "invalid":
			return _invalid("resolution", String(aftermath_result.get("reason", "invalid_action_aftermath")))

		_append_resolution_action_event(player_id, String(player.action), action_result, aftermath_result)
		resolution_state["next_action_index"] = next_index + 1

		if int(game.winner) >= 0 or bool(aftermath_result.get("stopped_on_win", false)):
			resolution_state["stopped_stage"] = "actions"
			return _finish_human_resolution()

	return _begin_human_reflex()


func _begin_human_reflex() -> Dictionary:
	var winner_id: int = int(game.reflex_winner)
	if winner_id == HUMAN_PLAYER_ID:
		stage = Stage.RESOLUTION_REFLEX
		return _awaiting("reflex")

	if game.breach == "Odradek" and int(game.breach_owner) == HUMAN_PLAYER_ID and winner_id == BOT_PLAYER_ID:
		stage = Stage.RESOLUTION_ODRADEK_BREACH
		return _awaiting("odradek_breach")

	var reflex_result: Dictionary = ReflexActionEngineData.resolve(
		game,
		rules,
		_bot_reflex_decision(BOT_PLAYER_ID),
		{}
	)
	if String(reflex_result.get("action", "")) == "invalid":
		return _invalid("reflex", String(reflex_result.get("reason", "invalid_reflex_action")))

	_record_reflex_guard_reveal(reflex_result)
	resolution_state["reflex_result"] = reflex_result
	return _after_human_reflex()


func _after_human_reflex() -> Dictionary:
	if int(game.winner) >= 0:
		resolution_state["stopped_stage"] = "reflex"
		return _finish_human_resolution()

	var finale_result: Dictionary = ResolutionFinaleEngineData.resolve(
		game,
		rules,
		resolution_state.get("order", [])
	)
	resolution_state["finale_result"] = finale_result
	if bool(finale_result.get("stopped_on_win", false)):
		resolution_state["stopped_stage"] = "finale"
		return _finish_human_resolution()

	var human = get_human_player()
	if _human_gremory_choice_available(human):
		stage = Stage.RESOLUTION_GREMORY
		return _awaiting("gremory")

	return _resolve_human_cleanup({"pass": true})


func _resolve_human_cleanup(
	human_choice: Dictionary
) -> Dictionary:
	var bot_choices: Dictionary = BotResolutionDoctrineData.current_gremory_choices(game, rules)
	var cleanup_choices: Dictionary = {
		HUMAN_PLAYER_ID: human_choice.duplicate(true),
		BOT_PLAYER_ID: _decision_for_player(bot_choices, BOT_PLAYER_ID),
	}
	# Cleanup can be destructive after Inevitable Ruin validates. Check the
	# complete choice bundle on a clone first so a rejected human payment never
	# advances the live game.
	var cleanup_preview: Dictionary = ResolutionCleanupEngineData.resolve(
		game.duplicate_state(),
		rules,
		cleanup_choices
	)

	if _contains_invalid(cleanup_preview):
		return _rejected("cleanup", "invalid_gremory_choice")

	var cleanup_result: Dictionary = ResolutionCleanupEngineData.resolve(
		game,
		rules,
		cleanup_choices
	)

	resolution_state["cleanup_result"] = cleanup_result
	if bool(cleanup_result.get("stopped_on_win", false)):
		resolution_state["stopped_stage"] = "cleanup"
	return _finish_human_resolution()


func _append_resolution_action_event(
	player_id: int,
	committed_action: String,
	action_result: Dictionary,
	aftermath_result: Dictionary
) -> void:
	var action_events: Array = resolution_state.get("action_events", [])
	action_events.append({
		"player_id": player_id,
		"committed_action": committed_action,
		"action_result": action_result,
		"aftermath_result": aftermath_result,
	})
	resolution_state["action_events"] = action_events


func _record_reflex_guard_reveal(
	reflex_result: Dictionary
) -> void:
	var action_name: String = String(reflex_result.get("executed_action", "Pass"))
	if action_name not in ["Hunt", "Siege"]:
		return
	_reveal_reflex_attack_guards(
		game,
		int(reflex_result.get("executed_by", -1)),
		{"action": action_name}
	)


func _human_gremory_choice_available(
	human
) -> bool:
	if human == null or human.lord != "Gremory" or not human.alive or human.gremory_inevitable_ruin_done:
		return false
	var opponent = game.get_opponent(HUMAN_PLAYER_ID)
	return (
		opponent != null
		and opponent.was_sieged
		and not String(opponent.last_sieged_castle).is_empty()
		and opponent.castles.has(String(opponent.last_sieged_castle))
		and human.hand.size() + human.garrison.size() >= 4
	)


func _finish_human_resolution() -> Dictionary:
	var resolution_result: Dictionary = {
		"action": "resolution",
		"reason": "",
		"prelude_result": resolution_state.get("prelude_result", {}),
		"action_events": resolution_state.get("action_events", []),
		"reflex_result": resolution_state.get("reflex_result", {}),
		"finale_result": resolution_state.get("finale_result", {}),
		"cleanup_result": resolution_state.get("cleanup_result", {}),
		"stopped_stage": String(resolution_state.get("stopped_stage", "")),
		"winner": int(game.winner),
		"win_by": String(game.win_by),
		"veil_total": int(game.calculate_veil_total()),
	}

	_record_phase("resolution", {"choices": resolution_state.get("action_choices", {}), "result": resolution_result})
	_sync_guard_visibility()
	stage = Stage.TERMINAL if int(game.winner) >= 0 else Stage.NO_GAME
	return _round_result(true, "resolution" if stage == Stage.TERMINAL else "")


func _nested_dictionary(
	source: Dictionary,
	key: String
) -> Dictionary:
	var raw_value = source.get(key, {})
	return raw_value if typeof(raw_value) == TYPE_DICTIONARY else {}


func _duplicate_game_with_metadata():
	var copy = game.duplicate_state()
	for metadata_name in game.get_meta_list():
		copy.set_meta(metadata_name, game.get_meta(metadata_name))
	return copy


func _duplicate_random_source():
	if random_source != null and random_source.has_method("duplicate_state"):
		return random_source.duplicate_state()
	return random_source


func get_human_player():
	if game == null:
		return null

	return game.get_player(
		HUMAN_PLAYER_ID
	)


func get_bot_player():
	if game == null:
		return null

	return game.get_player(
		BOT_PLAYER_ID
	)


func get_bot_commitment() -> Dictionary:
	var raw = commitment_choices.get(
		BOT_PLAYER_ID,
		{}
	)

	if typeof(
		raw
	) != TYPE_DICTIONARY:
		return {}

	return raw


func is_guard_revealed(
	card
) -> bool:
	if card == null:
		return false

	return bool(
		revealed_guard_ids.get(
			int(
				card.get_instance_id()
			),
			false
		)
	)


func consume_guard_reveal_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = (
		guard_reveal_events.duplicate(
			true
		)
	)

	guard_reveal_events.clear()

	return result


func _close_returned_breach(
	breach_name: String,
	breach_owner_id: int
) -> Dictionary:
	if (
		breach_name.is_empty()
		or breach_owner_id < 0
	):
		return {}

	var breach_owner = game.get_player(
		breach_owner_id
	)

	if (
		breach_owner == null
		or not breach_owner.alive
		or String(
			breach_owner.lord
		) != breach_name
	):
		return {}

	game.breach = ""
	game.breach_owner = -1
	game.refresh_derived_values()

	return {
		"player_id": breach_owner_id,
		"lord": breach_name,
	}


func _sync_guard_visibility() -> void:
	if game == null:
		revealed_guard_ids.clear()
		guard_locations.clear()
		return

	var current_locations: Dictionary = {}

	for player in game.players:
		var player_id: int = int(
			player.pid
		)

		for card in player.lord_guards:
			current_locations[
				int(
					card.get_instance_id()
				)
			] = "%d:Lord" % player_id

		for card in player.castle_guards:
			current_locations[
				int(
					card.get_instance_id()
				)
			] = "%d:Castle" % player_id

	for raw_instance_id in revealed_guard_ids.keys():
		var instance_id: int = int(
			raw_instance_id
		)

		if (
			not current_locations.has(
				instance_id
			)
			or String(
				guard_locations.get(
					instance_id,
					""
				)
			) != String(
				current_locations.get(
					instance_id,
					""
				)
			)
		):
			revealed_guard_ids.erase(
				instance_id
			)

	guard_locations = current_locations


func _private_deploy_choices() -> Dictionary:
	var human_choices: Dictionary = (
		BotDeployDoctrineData.deploy_choices(
			_information_view(
				game,
				HUMAN_PLAYER_ID
			),
			rules
		)
	)
	var bot_choices: Dictionary = (
		BotDeployDoctrineData.deploy_choices(
			_information_view(
				game,
				BOT_PLAYER_ID
			),
			rules
		)
	)

	return {
		HUMAN_PLAYER_ID: human_choices.get(
			HUMAN_PLAYER_ID,
			{
				"pass": true,
			}
		),
		BOT_PLAYER_ID: bot_choices.get(
			BOT_PLAYER_ID,
			{
				"pass": true,
			}
		),
	}


func _information_view(
	source_game,
	viewer_id: int
):
	var view = source_game.duplicate_state()

	for metadata_name in source_game.get_meta_list():
		view.set_meta(
			metadata_name,
			source_game.get_meta(
				metadata_name
			)
		)

	var source_opponent = source_game.get_opponent(
		viewer_id
	)
	var view_opponent = view.get_opponent(
		viewer_id
	)

	if (
		source_opponent == null
		or view_opponent == null
	):
		return view

	_mask_guard_array(
		source_opponent.lord_guards,
		view_opponent.lord_guards
	)
	_mask_guard_array(
		source_opponent.castle_guards,
		view_opponent.castle_guards
	)

	view.refresh_derived_values()

	return view


func _mask_guard_array(
	source_guards: Array,
	view_guards: Array
) -> void:
	for index: int in range(
		min(
			source_guards.size(),
			view_guards.size()
		)
	):
		if is_guard_revealed(
			source_guards[index]
		):
			continue

		# Guard count is public. Identity and value are not, so doctrine
		# receives the neutral deck expectation instead of the real card.
		view_guards[index] = CardData.new(
			"Wright",
			UNKNOWN_GUARD_EXPECTED_VALUE
		)


func _reveal_primary_attack_guards() -> void:
	for attacker in game.players:
		var action_name: String = String(
			attacker.action
		)

		if action_name not in [
			"Hunt",
			"Siege",
		]:
			continue

		var defender = game.get_player(
			int(
				attacker.tgt_pid
			)
		)

		if defender == null:
			defender = game.get_opponent(
				int(
					attacker.pid
				)
			)

		_reveal_guard_zone(
			int(
				attacker.pid
			),
			defender,
			(
				"Lord"
				if action_name == "Hunt"
				else "Castle"
			),
			"committed"
		)


func _private_reflex_provider(
	current_game,
	current_rules: RuleConfig
) -> Dictionary:
	var winner_id: int = int(
		current_game.reflex_winner
	)
	var random_state_before = null

	if (
		random_source != null
		and random_source.has_method(
			"duplicate_state"
		)
	):
		random_state_before = (
			random_source.duplicate_state()
		)

	var winner_view = _information_view(
		current_game,
		winner_id
	)
	var bundle: Dictionary = (
		BotReflexDoctrineData.build_decisions(
			winner_view,
			current_rules,
			random_source,
			policy
		)
	)
	var actor_id: int = winner_id
	var action_decision = bundle.get(
		"winner_decision",
		{}
	)
	var breach_decision = bundle.get(
		"breach_decision",
		{}
	)
	var breach_owner_id: int = int(
		current_game.breach_owner
	)

	if (
		current_game.breach == "Odradek"
		and breach_owner_id >= 0
		and breach_owner_id != winner_id
	):
		var breach_bundle: Dictionary = (
			BotReflexDoctrineData.build_decisions(
				_information_view(
					current_game,
					breach_owner_id
				),
				current_rules,
				random_state_before,
				policy
			)
		)

		breach_decision = breach_bundle.get(
			"breach_decision",
			{}
		)
		bundle["breach_decision"] = breach_decision

	if (
		typeof(
			breach_decision
		) == TYPE_DICTIONARY
		and not breach_decision.is_empty()
		and String(
			breach_decision.get(
				"guess",
				""
			)
		) == String(
			action_decision.get(
				"action",
				"Pass"
			)
		)
	):
		actor_id = breach_owner_id
		action_decision = breach_decision.get(
			"stolen_action",
			{}
		)

	if typeof(
		action_decision
	) == TYPE_DICTIONARY:
		_reveal_reflex_attack_guards(
			current_game,
			actor_id,
			action_decision
		)

	return bundle


func _reveal_reflex_attack_guards(
	current_game,
	actor_id: int,
	action_decision: Dictionary
) -> void:
	var action_name: String = String(
		action_decision.get(
			"action",
			"Pass"
		)
	)

	if action_name not in [
		"Hunt",
		"Siege",
	]:
		return

	_reveal_guard_zone(
		actor_id,
		current_game.get_opponent(
			actor_id
		),
		(
			"Lord"
			if action_name == "Hunt"
			else "Castle"
		),
		"reflex"
	)


func _reveal_guard_zone(
	attacker_id: int,
	defender,
	zone: String,
	source: String
) -> void:
	if defender == null:
		return

	var guards: Array = (
		defender.lord_guards
		if zone == "Lord"
		else defender.castle_guards
	)
	var newly_revealed: Array[String] = []

	for card in guards:
		var instance_id: int = int(
			card.get_instance_id()
		)

		if bool(
			revealed_guard_ids.get(
				instance_id,
				false
			)
		):
			continue

		revealed_guard_ids[instance_id] = true
		newly_revealed.append(
			String(
				card.card_id()
			)
		)

	if newly_revealed.is_empty():
		return

	guard_reveal_events.append({
		"attacker_id": attacker_id,
		"defender_id": int(
			defender.pid
		),
		"zone": zone,
		"source": source,
		"cards": newly_revealed,
	})


func _record_phase(
	phase_name: String,
	data
) -> void:
	phase_results[phase_name] = data

	events.append({
		"round": int(
			game.round
		),
		"phase": phase_name,
		"data": data,
	})


func _awaiting(
	phase_name: String
) -> Dictionary:
	last_result = {
		"action": "await_%s" % phase_name,
		"reason": "",
		"round": int(game.round),
		"completed": false,
		"terminal": false,
		"stopped_phase": phase_name,
		"winner": -1,
		"win_by": "",
		"phases": phase_results,
		"events": events,
	}
	return last_result


func _rejected(
	phase_name: String,
	reason: String
) -> Dictionary:
	return {
		"action": "invalid",
		"reason": reason,
		"round": int(game.round),
		"completed": false,
		"terminal": false,
		"stopped_phase": phase_name,
		"winner": -1,
		"win_by": "",
		"phases": phase_results,
		"events": events,
	}


func _decision_for_player(
	choices: Dictionary,
	player_id: int
) -> Dictionary:
	var raw_decision = choices.get(player_id, choices.get(str(player_id), {}))
	if typeof(raw_decision) != TYPE_DICTIONARY:
		return {}
	return raw_decision


func _bot_repair_decision() -> Dictionary:
	var bot_view = _information_view(game, BOT_PLAYER_ID)
	var selection: Dictionary = BotSelectorData.choose(
		BotDevelopmentDoctrineData.evaluate_repair_candidates(
			bot_view,
			BOT_PLAYER_ID,
			rules
		),
		random_source,
		policy
	)
	var payload = selection.get("payload", {"pass": true})
	return payload if typeof(payload) == TYPE_DICTIONARY else {"pass": true}


func _bot_summon_decision() -> Dictionary:
	var bot_view = _information_view(game, BOT_PLAYER_ID)
	var selection: Dictionary = BotSelectorData.choose(
		BotDevelopmentDoctrineData.evaluate_summon_candidates(
			bot_view,
			BOT_PLAYER_ID,
			rules
		),
		random_source,
		policy
	)
	var payload = selection.get("payload", {"pass": true})
	return payload if typeof(payload) == TYPE_DICTIONARY else {"pass": true}


func _bot_bid_decision() -> Dictionary:
	var bot_view = _information_view(game, BOT_PLAYER_ID)
	var selection: Dictionary = BotSelectorData.choose(
		BotDoctrineData.evaluate_bid_candidates(
			bot_view,
			BOT_PLAYER_ID,
			rules
		),
		random_source,
		policy
	)
	var payload = selection.get("payload", {"pass": true})
	return payload if typeof(payload) == TYPE_DICTIONARY else {"pass": true}


func _bot_reflex_decision(
	actor_id: int
) -> Dictionary:
	return BotReflexDoctrineData.decision_for_actor(
		_information_view(game, BOT_PLAYER_ID),
		actor_id,
		rules,
		random_source,
		policy
	)


func _bot_odradek_breach_decision(
	winner_id: int
) -> Dictionary:
	var bot_view = _information_view(game, BOT_PLAYER_ID)
	var bot = bot_view.get_player(BOT_PLAYER_ID)
	if bot == null or bot.lord != "Odradek" or bot.hand.is_empty():
		return {}
	return {
		"guess": BotReflexDoctrineData.predict_reflex_action(
			bot_view,
			winner_id,
			rules,
			random_source,
			policy
		),
		"stolen_action": BotReflexDoctrineData.decision_for_actor(
			bot_view,
			BOT_PLAYER_ID,
			rules,
			random_source,
			policy
		),
	}


func _bot_rite_decision() -> Dictionary:
	var bot_view = _information_view(game, BOT_PLAYER_ID)
	var decision: Dictionary = {}
	var invocation_selection: Dictionary = BotSelectorData.choose(
		BotDominionRiteDoctrineData.evaluate_invocation_candidates(
			bot_view,
			BOT_PLAYER_ID,
			rules
		),
		random_source,
		policy
	)
	var invocation_payload = invocation_selection.get("payload", {"pass": true})

	if typeof(invocation_payload) == TYPE_DICTIONARY and not bool(invocation_payload.get("pass", false)):
		decision["invocation"] = invocation_payload.duplicate(true)
		var invocation_result: Dictionary = DominionRiteEngineData.resolve_player(
			bot_view,
			BOT_PLAYER_ID,
			rules,
			{"invocation": invocation_payload.duplicate(true)}
		)
		if _rite_result_won(invocation_result):
			return decision

	var profane_selection: Dictionary = BotSelectorData.choose(
		BotDominionRiteDoctrineData.evaluate_profane_candidates(
			bot_view,
			BOT_PLAYER_ID,
			rules
		),
		random_source,
		policy
	)
	var profane_payload = profane_selection.get("payload", {"pass": true})
	if typeof(profane_payload) == TYPE_DICTIONARY and not bool(profane_payload.get("pass", false)):
		decision["profane_ruins"] = profane_payload.duplicate(true)

	return decision if not decision.is_empty() else {"pass": true}


func _rite_result_won(
	result: Dictionary
) -> bool:
	var raw_actions = result.get("actions", [])
	if typeof(raw_actions) != TYPE_ARRAY:
		return false
	for raw_action in raw_actions:
		if typeof(raw_action) == TYPE_DICTIONARY and bool(raw_action.get("won", false)):
			return true
	return false


func _rite_result_invalid(
	result: Dictionary
) -> bool:
	var raw_actions = result.get("actions", [])
	if typeof(raw_actions) != TYPE_ARRAY:
		return false
	for raw_action in raw_actions:
		if typeof(raw_action) == TYPE_DICTIONARY and String(raw_action.get("action", "")) == "invalid":
			return true
	return false


func _rite_invalid_reason(
	result: Dictionary
) -> String:
	var raw_actions = result.get("actions", [])
	if typeof(raw_actions) == TYPE_ARRAY:
		for raw_action in raw_actions:
			if typeof(raw_action) == TYPE_DICTIONARY and String(raw_action.get("action", "")) == "invalid":
				return String(raw_action.get("reason", "invalid_dominion_rite"))
	return "invalid_dominion_rite"


func _round_result(
	completed: bool,
	stopped_phase: String
) -> Dictionary:
	return {
		"action": "round",
		"reason": "",
		"round": int(
			game.round
		),
		"completed": completed,
		"terminal": (
			int(
				game.winner
			) >= 0
		),
		"stopped_phase": stopped_phase,
		"winner": int(
			game.winner
		),
		"win_by": String(
			game.win_by
		),
		"phases": phase_results,
		"events": events,
	}


func _invalid(
	phase_name: String,
	reason: String
) -> Dictionary:
	stage = Stage.INVALID

	last_result = {
		"action": "invalid",
		"reason": reason,
		"round": (
			int(
				game.round
			)
			if game != null
			else 0
		),
		"completed": false,
		"terminal": (
			game != null
			and int(
				game.winner
			) >= 0
		),
		"stopped_phase": phase_name,
		"winner": (
			int(
				game.winner
			)
			if game != null
			else -1
		),
		"win_by": (
			String(
				game.win_by
			)
			if game != null
			else ""
		),
		"phases": phase_results,
		"events": events,
	}

	return last_result


func _contains_invalid(
	value
) -> bool:
	if typeof(
		value
	) == TYPE_DICTIONARY:
		var dictionary: Dictionary = value

		if String(
			dictionary.get(
				"action",
				""
			)
		) == "invalid":
			return true

		for nested_value in dictionary.values():
			if _contains_invalid(
				nested_value
			):
				return true

		return false

	if typeof(
		value
	) == TYPE_ARRAY:
		var array: Array = value

		for nested_value in array:
			if _contains_invalid(
				nested_value
			):
				return true

	return false
