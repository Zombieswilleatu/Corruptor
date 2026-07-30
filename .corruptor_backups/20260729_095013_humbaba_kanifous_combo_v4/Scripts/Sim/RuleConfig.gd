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

# Experimental 6.5 structural pass.  These are deliberately inert in DE v2;
# `lab_v6_5()` is the only profile that enables the measured system bundle.
# The canonical switches remain in trace identity.  Lab-only presentation and
# economy features are intentionally versioned by the lab profile instead, so
# an inert feature does not relabel the canonical DE v2 goldens.
@export var fix_a: bool = false
@export var fix_b: bool = false

@export var ward_threshold: bool = false
@export var ward_anti_repeat: bool = true
@export var ward_commit_any: bool = false
@export var ward_commit_defense: bool = false
@export var ward_read: bool = false
@export var ward_garrison_refund: bool = false
@export var sigil_flat: bool = false
@export var humbaba_sigil_commit: bool = false

@export var repair_escalation: int = 0
@export var castle_scarring: bool = false
@export var castle_scar_def: int = 2
@export var castle_permanent_loss: bool = false
@export var veil_on_permanent_loss: bool = false
@export var lord_threat_retention: bool = false

@export var reflex_bid: bool = true
@export var momentum: bool = false
@export var momentum_band: int = 3
@export var fog_of_war: bool = false

# Independent from Marching Orders: the lab Market refreshes before swaps from
# round two onward.  It must stay enabled when Marching is isolated for tests.
@export var market_refresh: bool = false

@export var marching: bool = false
@export var march_max_in_flight: int = 1
@export var march_threshold: int = 3
@export var march_damage: int = 2
@export var march_suit_bonus: int = 1
@export var march_steps: int = 3
@export var march_exception_pair: bool = true
@export var lane_kill_soul: bool = false

# These remain experimental but are deliberately OFF in the v6.5 measured
# profile.  They are configuration, not an accidental promise to ship them.
@export var adaptive_doctrine: bool = false
@export var castle_loadout: bool = false
@export var max_castles: int = 3
@export var profane_no_castle_gate: bool = false
@export var castleless_siege: bool = false
@export var castleless_tear_neutral: bool = true


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


static func lab_v6_5() -> RuleConfig:
	# The measured 6.5 lab profile.  It starts from canonical DE v2 so the
	# established lord-power corrections remain authoritative, then applies only
	# the systems included in LAB_MEASURED_CONFIG.  Loadouts and adaptive
	# doctrine intentionally stay off: neither was in the measured bundle.
	var config := RuleConfig.de_v2()

	# The lab was measured on the 12-step Cataclysm checkpoint.  Only its
	# Ritual, Dominion-requirement, and Collapse clocks were repriced by
	# apply_lab_clocks(); retaining DE v2's 11 here would be an unmeasured hybrid.
	config.dominion_track = 12
	config.win_souls = 11
	config.dominion_requirement = 7
	config.final_collapse_threshold = 22

	config.fix_a = true
	config.fix_b = true

	config.ward_threshold = true
	config.ward_anti_repeat = false
	config.ward_commit_any = true
	config.ward_commit_defense = true
	config.ward_read = true
	config.ward_garrison_refund = true
	config.sigil_flat = true
	config.humbaba_sigil_commit = true

	config.castle_scarring = true
	config.castle_permanent_loss = true
	config.veil_on_permanent_loss = true
	config.lord_threat_retention = true

	config.reflex_bid = false
	config.momentum = true
	config.momentum_band = 3
	config.fog_of_war = true
	config.market_refresh = true

	config.marching = true
	config.march_max_in_flight = 1
	config.march_threshold = 3
	config.march_damage = 2
	config.march_suit_bonus = 1
	config.march_steps = 3
	config.march_exception_pair = true
	config.lane_kill_soul = true

	return config


func get_cataclysm_threshold() -> int:
	return dominion_track
