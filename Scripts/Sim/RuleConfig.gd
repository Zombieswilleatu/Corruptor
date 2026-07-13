class_name RuleConfig
extends Resource

# RuleConfig is a published snapshot of what the Python balance lab concluded.
# Do not hand-balance this file independently of the Python oracle.
#
# Workflow:
# tune in Python → run grids → transcribe winning VARIANT/constants here
# → golden-master diff Python vs Godot.
#
# Default instance = DE v2 / current canonical tuned config.
# Use RuleConfig.base_v5_29() only for raw rulebook/baseline tests.
#
# RuleConfig is the tuning bridge.
# Card distributions, castle stats, lord stats, and other content tables
# should live in separate content resources transcribed from the Python sim.

# Core clocks.
@export var win_souls: int = 7

# IMPORTANT:
# This is the Cataclysm checkpoint and Python's DOMINION_TRACK.
# Do not create a separate cataclysm_threshold field unless it is a true
# different mechanic. Dominion timing and Cataclysm timing are the same seam.
@export var dominion_track: int = 11

@export var dominion_requirement: int = 2
@export var final_collapse_threshold: int = 15

# Hand / board limits.
@export var hand_limit: int = 10
@export var garrison_max: int = 5
@export var max_threat: int = 4
@export var market_size: int = 3
@export var max_rounds: int = 60

# DE v2 variant dials.
@export var recoil_hunts_only: bool = true
@export var sigil_soul_fresh_only: bool = false
@export var invocation_gate: int = 5
@export var profane_ruins_req: int = 1
@export var ai_dominion_drive: bool = true
@export var no_backwash: bool = false
@export var reconfig_strict: bool = true
@export var kroni_def_soft: bool = false
@export var kroni_hunger_decay: bool = true
@export var deimos_war_machine_free: bool = true
@export var deimos_summon_cost: int = 7
@export var recoil_lowest: bool = true
@export var neutral_tear_on_banish: bool = true
@export var castle_tear_uncapped: bool = false
@export var veil_drift: int = 0
@export var invocation_repeatable: bool = false
@export var reconfig_tokens_needed: int = 5
@export var reconfig_neutral: bool = false
@export var deimos_claims_breach: int = 1
@export var consume_the_siege: bool = false
@export var war_machine_ignores_profaned: bool = false
@export var gremory_summon_cost: int = 6

# Humbaba / ninth-lord variants.
@export var humbaba_seal: bool = true
@export var humbaba_toll: bool = true
@export var humbaba_gate4: bool = true
@export var humbaba_patient: bool = true


static func de_v2() -> RuleConfig:
	# DE v2 is the default state of this resource.
	return RuleConfig.new()


static func base_v5_29() -> RuleConfig:
	var config := RuleConfig.new()

	# Historical/raw v5.29 baseline overrides.
	config.dominion_track = 12
	config.dominion_requirement = 3

	config.recoil_hunts_only = false
	config.invocation_gate = 7
	config.profane_ruins_req = 2
	config.ai_dominion_drive = false
	config.reconfig_strict = false
	config.kroni_hunger_decay = false
	config.deimos_war_machine_free = false
	config.deimos_summon_cost = 0
	config.recoil_lowest = false
	config.neutral_tear_on_banish = false
	config.reconfig_tokens_needed = 3
	config.deimos_claims_breach = 0
	config.gremory_summon_cost = 0

	return config


func get_cataclysm_threshold() -> int:
	return dominion_track
