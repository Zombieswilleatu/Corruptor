class_name MatchState
extends RefCounted

enum Phase {
	DEVELOPMENT,
	COMMITMENT,
	REVEAL,
	RESOLUTION
}

var boss: BossProfile = null
var rules: RuleConfig = null

# Seeded RNG discipline. No global randi_range() in the sim layer.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var match_seed: int = 0

# Match-level Corruptor clocks.
var player_souls: int = 0
var boss_souls: int = 0

var player_tears: int = 0
var boss_tears: int = 0
var neutral_tears: int = 0

# Match-level pressure/state.
var player_threat: int = 0
var boss_threat: int = 0

var current_round: int = 1
var phase: Phase = Phase.DEVELOPMENT

var match_over: bool = false
var player_won: bool = false

# Campaign reward hook.
# CampaignRunState banks this only after the match is won and claimed.
var souls_awarded_to_campaign: int = 0


func setup(_boss: BossProfile, _rules: RuleConfig, _match_seed: int) -> void:
	boss = _boss
	rules = _rules
	match_seed = _match_seed
	rng.seed = match_seed


func get_veil() -> int:
	return player_tears + boss_tears + neutral_tears


func get_phase_name() -> String:
	match phase:
		Phase.DEVELOPMENT:
			return "Development"
		Phase.COMMITMENT:
			return "Commitment"
		Phase.REVEAL:
			return "Reveal"
		Phase.RESOLUTION:
			return "Resolution"
		_:
			return "Unknown"


func get_match_summary() -> String:
	if boss == null:
		return "No contest recorded."

	if rules == null:
		return "Contest against %s | No RuleConfig loaded." % boss.display_name

	return "Contest against %s | Breach: %d/%d | Your Souls: %d/%d | Rival Souls: %d/%d | Round: %d | Phase: %s" % [
		boss.display_name,
		get_veil(),
		rules.final_collapse_threshold,
		player_souls,
		rules.win_souls,
		boss_souls,
		rules.win_souls,
		current_round,
		get_phase_name()
	]


func advance_fake_phase() -> Array[Dictionary]:
	var events: Array[Dictionary] = []

	if match_over:
		events.append(Events.make("INFO", "This contest is already settled."))
		return events

	match phase:
		Phase.DEVELOPMENT:
			events.append(Events.make("PHASE", "Development"))
			events.append(Events.make("MATCH_TEXT", "Subjects are counted. Holdings are repaired. Weakness is measured."))
			events.append(Events.make("MATCH_TEXT", "%s extends its attention across the board." % boss.display_name))
			phase = Phase.COMMITMENT

		Phase.COMMITMENT:
			events.append(Events.make("PHASE", "Commitment"))
			events.append(Events.make("MATCH_TEXT", "Orders are sealed. Every Subject committed elsewhere leaves a wall less certain."))
			phase = Phase.REVEAL

		Phase.REVEAL:
			events.append(Events.make("PHASE", "Reveal"))
			events.append(Events.make("MATCH_TEXT", "The seals break. Intent becomes territory."))
			events.append(Events.make("MATCH_TEXT", "What was hidden is now owed."))
			phase = Phase.RESOLUTION

		Phase.RESOLUTION:
			events.append_array(_resolve_fake_resolution())
			current_round += 1
			phase = Phase.DEVELOPMENT

	return events


func _resolve_fake_resolution() -> Array[Dictionary]:
	var events: Array[Dictionary] = []

	events.append(Events.make("PHASE", "Resolution"))
	events.append(Events.make("MATCH_TEXT", "The commitments are weighed. Loss finds the exposed."))

	if rules == null:
		events.append(Events.make("ERROR", "No RuleConfig loaded."))
		return events

	# Temporary fake resolver.
	# Later this is replaced by the real action resolver returning EventList.
	var player_gain: int = boss.campaign_soul_reward
	var boss_gain: int = rng.randi_range(0, 4)
	var neutral_tear_gain: int = boss.fake_neutral_tears
	var threat_gain: int = boss.fake_player_threat

	player_souls += player_gain
	boss_souls += boss_gain
	neutral_tears += neutral_tear_gain
	player_threat += threat_gain

	events.append(Events.make("SOULS_GAINED", "You take %d Souls from the contest." % player_gain, {
		"who": "player",
		"amount": player_gain
	}))

	events.append(Events.make("SOULS_GAINED", "%s claims %d Souls before it is driven back." % [boss.display_name, boss_gain], {
		"who": "boss",
		"amount": boss_gain
	}))

	events.append(Events.make("VEIL_CHANGED", "The Breach widens by %d." % neutral_tear_gain, {
		"amount": neutral_tear_gain
	}))

	events.append(Events.make("THREAT_CHANGED", "Your position draws %d Threat." % threat_gain, {
		"amount": threat_gain
	}))

	if is_cataclysm_active():
		events.append(Events.make("CATACLYSM", "The Cataclysm threshold is crossed. Dominion will be counted in ruin."))

	if is_final_collapse():
		events.append(Events.make("FINAL_COLLAPSE", "Final Collapse arrives. What remains is measured."))
		match_over = true
		player_won = player_souls > boss_souls
	else:
		# Fake rule for scaffold: one full fake resolution ends the match in a player win.
		match_over = true
		player_won = true

	if player_won:
		souls_awarded_to_campaign = boss.campaign_soul_reward

		events.append(Events.make("MATCH_WON", "%s is diminished. Its hold loosens." % boss.display_name))

		events.append(Events.make("CAMPAIGN_REWARD_PENDING", "Tribute pending: %d Souls." % souls_awarded_to_campaign, {
			"amount": souls_awarded_to_campaign
		}))
	else:
		events.append(Events.make("MATCH_LOST", "Your claim fails. The rival endures."))

	return events


func is_cataclysm_active() -> bool:
	if rules == null:
		return false

	return get_veil() >= rules.get_cataclysm_threshold()


func is_final_collapse() -> bool:
	if rules == null:
		return false

	return get_veil() >= rules.final_collapse_threshold
