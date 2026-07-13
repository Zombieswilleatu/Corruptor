class_name CampaignRunState
extends RefCounted


# CampaignRunState is currently transient.
# When meta-progression/save/load arrives, either convert this to Resource
# or add explicit to_dict()/from_dict() serialization.


var boss_index: int = 0
var souls_banked_this_run: int = 0

var bosses: Array[BossProfile] = []
var defeated_bosses: Array[String] = []
var active_campaign_modifiers: Array[String] = []

var current_match: MatchState = null
var rules: RuleConfig = null

var run_over: bool = false
var victory: bool = false
var collapse_reason: String = ""

var run_seed: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(
	_rules: RuleConfig,
	_seed: int = 0
) -> void:
	rules = _rules

	if _seed == 0:
		run_seed = int(
			Time.get_unix_time_from_system()
		)
	else:
		run_seed = _seed

	rng.seed = run_seed

	_create_bosses()
	_start_current_match()


func _create_bosses() -> void:
	bosses = [
		_make_boss_profile(
			"valak",
			"Valak",
			"valak_gravitational_collapse",
			"Gravitational Collapse",
			"At the start of each Resolution phase, each player must discard one Guard from a zone they were attacked in last round, if able.",
			"Valak does not need to win the battle. Valak only needs to be present when blood is spilled.",
			5,
			2,
			1
		),
		_make_boss_profile(
			"kroni",
			"Kroni",
			"kroni_insatiable_hunger",
			"Insatiable Hunger",
			"At the end of each round, each player discards one Guard of their choice from any zone, if able.",
			"Kroni chokes the board by teaching every holding what scarcity means.",
			4,
			1,
			3
		),
		_make_boss_profile(
			"orias",
			"Orias",
			"orias_frenzy",
			"Frenzy",
			"During Development, players with 3 or more Threat may not move cards from Garrison to Guards.",
			"Orias selects. It waits until weakness stops pretending to be safety.",
			6,
			2,
			2
		),
		_make_boss_profile(
			"odradek",
			"Odradek",
			"odradek_paradox_geometry",
			"Paradox Geometry",
			"When the Reflex Bid winner plays their second action, the Odradek player may attempt to steal it by matching the action card.",
			"Odradek does not play the same game. The others have not yet realized this.",
			5,
			3,
			1
		),
		_make_boss_profile(
			"deimos",
			"Deimos",
			"deimos_cracked_foundations",
			"Cracked Foundations",
			"All Castles lose 1 Defense.",
			"Deimos considers fear a more reliable foundation than loyalty has ever been.",
			7,
			3,
			2
		)
	]


func _make_boss_profile(
	lord_id: String,
	display_name: String,
	breach_id: String,
	breach_name: String,
	breach_text: String,
	intent_text: String,
	campaign_soul_reward: int,
	fake_neutral_tears: int,
	fake_player_threat: int
) -> BossProfile:
	var profile := BossProfile.new()

	profile.lord_id = lord_id
	profile.display_name = display_name

	profile.breach_id = breach_id
	profile.breach_name = breach_name
	profile.breach_text = breach_text

	profile.intent_text = intent_text

	profile.campaign_soul_reward = (
		campaign_soul_reward
	)

	profile.fake_neutral_tears = (
		fake_neutral_tears
	)

	profile.fake_player_threat = (
		fake_player_threat
	)

	return profile


func get_current_boss() -> BossProfile:
	if (
		boss_index >= 0
		and boss_index < bosses.size()
	):
		return bosses[boss_index]

	return null


func get_current_boss_name() -> String:
	var boss: BossProfile = get_current_boss()

	if boss == null:
		return "None"

	return boss.display_name


func _start_current_match() -> void:
	var boss: BossProfile = get_current_boss()

	if boss == null:
		run_over = true
		victory = true
		current_match = null
		return

	current_match = MatchState.new()

	current_match.setup(
		boss,
		rules,
		rng.randi()
	)


func can_advance_to_next_boss() -> bool:
	if run_over:
		return false

	if current_match == null:
		return false

	return (
		current_match.match_over
		and current_match.player_won
	)


func advance_to_next_boss() -> Array[Dictionary]:
	var events: Array[Dictionary] = []

	if not can_advance_to_next_boss():
		events.append(
			Events.make(
				"INFO",
				"The contest is not yet settled. No tribute may be claimed."
			)
		)

		return events

	var defeated_boss: BossProfile = (
		current_match.boss
	)

	var reward: int = (
		current_match.souls_awarded_to_campaign
	)

	defeated_bosses.append(
		defeated_boss.display_name
	)

	if not active_campaign_modifiers.has(
		defeated_boss.breach_id
	):
		active_campaign_modifiers.append(
			defeated_boss.breach_id
		)

	souls_banked_this_run += reward

	events.append(
		Events.make(
			"MATCH_REWARD_CLAIMED",
			"%s is diminished."
			% defeated_boss.display_name
		)
	)

	events.append(
		Events.make(
			"SOULS_BANKED",
			"Tribute gathered: %d Souls."
			% reward,
			{
				"amount": reward
			}
		)
	)

	events.append(
		Events.make(
			"CAMPAIGN_MODIFIER_GAINED",
			"Breach carried forward: %s — %s"
			% [
				defeated_boss.breach_name,
				defeated_boss.breach_text
			],
			{
				"breach_id": defeated_boss.breach_id
			}
		)
	)

	boss_index += 1

	if boss_index >= bosses.size():
		run_over = true
		victory = true
		current_match = null

		events.append(
			Events.make(
				"RUN_COMPLETE",
				"Supremacy is recorded. No rival holds enough."
			)
		)

		return events

	_start_current_match()

	var next_boss: BossProfile = (
		get_current_boss()
	)

	events.append(
		Events.make(
			"NEXT_BOSS",
			"Another Lord answers the weakening border: %s."
			% next_boss.display_name
		)
	)

	events.append(
		Events.make(
			"BOSS_INTENT",
			next_boss.intent_text
		)
	)

	return events


func collapse_run(
	reason: String = ""
) -> Array[Dictionary]:
	run_over = true
	victory = false
	collapse_reason = reason

	return [
		Events.make(
			"RUN_COLLAPSED",
			"The claim fails: %s"
			% collapse_reason
		)
	]


func get_run_summary() -> String:
	if run_over:
		if victory:
			return (
				"Dominion recorded | Tribute: %d Souls | Lords diminished: %d/%d"
				% [
					souls_banked_this_run,
					defeated_bosses.size(),
					bosses.size()
				]
			)

		return (
			"Claim failed | Tribute: %d Souls | Lords diminished: %d/%d"
			% [
				souls_banked_this_run,
				defeated_bosses.size(),
				bosses.size()
			]
		)

	return (
		"Claim %d/%d: %s | Tribute: %d Souls"
		% [
			boss_index + 1,
			bosses.size(),
			get_current_boss_name(),
			souls_banked_this_run
		]
	)


func get_modifier_summary() -> String:
	if active_campaign_modifiers.is_empty():
		return "None"

	var names: Array[String] = []

	for breach_id: String in active_campaign_modifiers:
		names.append(
			_get_modifier_display_name(
				breach_id
			)
		)

	return ", ".join(names)


func _get_modifier_display_name(
	breach_id: String
) -> String:
	for boss: BossProfile in bosses:
		if boss.breach_id == breach_id:
			return boss.breach_name

	return breach_id
