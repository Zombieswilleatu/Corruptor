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
@export var odr_recoil: bool = true
@export var odr_recoil_strip: bool = true
@export var odr_recoil_soul: bool = true
@export var odr_recoil_bank: bool = false
@export var sigil_soul_fresh_only: bool = false
@export var invocation_gate: int = 5
@export var profane_ruins_req: int = 1
# Hand-value cost for Profane the Ruins. Historical profiles remain free;
# the current lab/playable rules opt into the priced rite.
@export var profane_ruins_cost: int = 0
@export var ai_dominion_drive: bool = true
@export var no_backwash: bool = false
@export var reconfig_strict: bool = true
@export var kroni_def_soft: bool = false
@export var kroni_hunger_decay: bool = true
@export var kro_fallback_feeds: bool = true
@export var kro_milestone_once: bool = false
@export var deimos_war_machine_free: bool = true
@export var deimos_summon_cost: int = 7
@export var recoil_lowest: bool = true
@export var neutral_tear_on_banish: bool = true
@export var castle_tear_uncapped: bool = false
@export var veil_drift: int = 0
@export var veil_drift_rate: float = 0.0
@export var veil_drift_after: int = 0
@export var veil_drift_growth: float = 0.0
@export var invocation_repeatable: bool = false
@export var reconfig_tokens_needed: int = 5
@export var reconfig_neutral: bool = false
@export var deimos_claims_breach: int = 1
@export var consume_the_siege: bool = false
@export var war_machine_ignores_profaned: bool = false
@export var gremory_summon_cost: int = 6

# Kalligan SCORCH keyword. Canonical DE v2 keeps the printed legacy behavior;
# the measured lab enables escalation, lane burn, and Flame income.
@export var kal_inferno_threat: bool = true
@export var kal_flame_tokens: bool = false
@export var kal_flame_per_soul: int = 5
@export var kal_scorch_escalate: bool = false
@export var kal_scorch_cap: int = 3
@export var kal_lane_scorch: bool = false
@export var kal_lane_scorch_thresh: int = 2

# Kanifous Invoke switches. DE v2 preserves the printed Threat-cost version;
# the measured lab swaps only that cost for a one-card Hand toll.
@export var kani_invoke: bool = true
@export var kani_threat_cost: bool = true
@export var kani_hand_cost: bool = false
@export var kani_neutral_tear: bool = true
@export var kani_soul_trigger: bool = true
@export var kani_garrison_bank: bool = true
@export var kani_suit_effects: bool = true

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

# Lab-only identity and doctrine. Canonical DE v2 leaves these inert.
@export var lab_profile_version: String = ""
@export var doctrine_ward_threat: float = 0.0
@export var doctrine_ward_stagnation: float = 0.0
@export var doctrine_bank_urgency: float = 0.0

@export var ward_threshold: bool = false
@export var ward_anti_repeat: bool = true
@export var ward_commit_any: bool = false
@export var ward_commit_defense: bool = false
@export var ward_read: bool = false
@export var ward_garrison_refund: bool = false
# v7.4: Ward commitments are temporary front-line reinforcements. Historical
# profiles leave this off so the old threshold-turn semantics remain inspectable.
@export var ward_frontline: bool = false
@export var sigil_flat: bool = false
@export var humbaba_sigil_commit: bool = false
@export var humbaba_reactive_lane: bool = false

@export var repair_escalation: int = 0
@export var castle_scarring: bool = false
@export var castle_scar_def: int = 2
@export var castle_permanent_loss: bool = false
@export var veil_on_permanent_loss: bool = false
@export var lord_threat_retention: bool = false

@export var reflex_bid: bool = true
@export var momentum: bool = false
@export var momentum_band: int = 3
@export var momentum_refund: int = 0
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
# Historical identity field. New code uses starting_castles; this stays only so
# old DE v2 traces can still be inspected before the canonical golden reset.
@export var max_castles: int = 3
@export var starting_castles: int = 5
@export var castle_type_count: int = 5
@export var castle_unique_types: bool = true
@export var castle_doctrine_denominator: int = 5
@export var castle_integrity: bool = false
@export var castle_granular_repair: bool = false
@export var castle_construction: bool = false
@export var castle_irreparable: bool = false
@export var castle_damage_mode: String = ""
@export var castle_construction_mode: String = ""
@export var castle_action_limit: int = 0
# v7.4 Castle identity lock. Defaults preserve historical profiles; lab_v6_5
# opts into the current measured rules.
@export var castle_power_gate_mode: String = "owned"
@export var castle_operational_floor: int = 7
@export var keep_sanctuary: bool = false
@export var bastion_wall: bool = false
@export var bastion_lord_def_bonus: int = 2
@export var stockpile_filter: bool = false
@export var circle_blood_conduit: bool = false
@export var circle_conduit_cost: int = 3
@export var circle_blood_summon: bool = false
@export var circle_blood_summon_cost: int = 3
@export var circle_blood_summon_discount: int = 3
@export var resummon_tear_mode: String = "neutral"
# 6.10 suit economy. Defaults preserve DE v2; the measured lab enables them.
@export var siege_engine_bypass: bool = true
@export var siege_engine_scope: String = "none"
@export var attack_offsuit_penalty: int = 0
@export var attack_penalty_exempt_suit: String = "Butcher"
@export var attack_offsuit_floor: int = 1
@export var ward_offsuit_penalty: int = 0
@export var ward_penalty_exempt_suit: String = "Penitent"
@export var ward_offsuit_floor: int = 1
@export var keep_ignores_ward_tax: bool = false
@export var vulture_recon: bool = false
@export var construction_action_cap: int = 0
@export var repair_wright_mode: String = "off"
@export var profane_requires_full_integrity: bool = false
@export var ruination_soul_bonus: int = 0
@export var ruination_soul_source: String = ""
@export var repair_token_integrity: int = 0
@export var master_builder_integrity: int = 0
@export var rapid_construction_integrity: int = 0
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
	# The measured lab starts from canonical DE v2, then explicitly restores
	# every inherited baseline value used by the 6.8.6 measurements. This prevents
	# later canonical changes from silently altering the lab profile. Loadouts and
	# adaptive doctrine remain off because neither was in the measured bundle.
	var config := RuleConfig.de_v2()

	# The lab was measured on the 12-step Cataclysm checkpoint.  Only its
	# Ritual, Dominion-requirement, and Collapse clocks were repriced by
	# apply_lab_clocks(); retaining DE v2's 11 here would be an unmeasured hybrid.
	config.dominion_track = 12
	config.win_souls = 12
	config.dominion_requirement = 5
	config.final_collapse_threshold = 26

	# Measured baseline inheritance. These are deliberate lab values, not
	# canonical DE v2 defaults.
	config.invocation_gate = 7
	config.profane_ruins_req = 2
	config.profane_ruins_cost = 5
	config.ai_dominion_drive = false
	config.kroni_hunger_decay = false
	config.neutral_tear_on_banish = false
	config.gremory_summon_cost = 0

	config.fix_a = true
	config.fix_b = true

	config.ward_threshold = true
	config.ward_anti_repeat = false
	config.ward_commit_any = true
	config.ward_commit_defense = true
	config.ward_read = true
	config.ward_garrison_refund = true
	config.ward_frontline = true
	config.sigil_flat = true
	# Humbaba v0.2 keeps Woven Into the Stones, Toll, and Breach. The
	# measured lab removes the older turtle stack and replaces it with H5.
	config.humbaba_seal = false
	config.humbaba_gate4 = true
	config.humbaba_patient = false
	config.humbaba_sigil_commit = false
	config.humbaba_reactive_lane = true

	# Kanifous pays one Hand card instead of gaining one Threat on Invoke.
	config.kani_threat_cost = false
	config.kani_hand_cost = true

	# Odradek Interlock, Kroni revision, and roster-wide Ward doctrine corrections.
	config.lab_profile_version = "7.5.0-suit-identities"
	config.odr_recoil_bank = true
	config.reconfig_neutral = true
	config.reconfig_tokens_needed = 3
	config.reconfig_strict = false
	config.recoil_hunts_only = false
	config.recoil_lowest = false
	config.doctrine_ward_threat = 0.20
	config.doctrine_ward_stagnation = 0.30
	config.doctrine_bank_urgency = 0.35

	# Kroni still pays the fallback card, but only real destruction feeds
	# Hunger. The Hunger-3 milestone is awarded once per game.
	config.kro_fallback_feeds = false
	config.kro_milestone_once = true

	# 6.8.6 measured bundle: Momentum funds its second action, the Veil
	# closes on late slogs, and Kalligan's SCORCH becomes a denial/income ramp.
	config.momentum_refund = 1
	config.veil_drift_after = 15
	config.veil_drift_growth = 0.25
	config.kal_inferno_threat = false
	config.kal_flame_tokens = true
	config.kal_flame_per_soul = 5
	config.kal_scorch_escalate = true
	config.kal_scorch_cap = 3
	config.kal_lane_scorch = true
	config.kal_lane_scorch_thresh = 2

	config.castle_scarring = false
	config.castle_permanent_loss = false
	config.veil_on_permanent_loss = false
	config.lord_threat_retention = true

	config.reflex_bid = false
	config.momentum = true
	config.momentum_band = 3
	config.fog_of_war = true
	config.market_refresh = true

	# Castle Integrity 6.9.0 canonical migration. Any three Castle types open;
	# granular construction may later expand the board to all five unique types.
	config.castle_loadout = true
	config.starting_castles = 3
	config.castle_type_count = 5
	config.castle_unique_types = true
	config.castle_doctrine_denominator = 5
	config.castle_integrity = true
	config.castle_granular_repair = true
	config.castle_construction = true
	config.castle_irreparable = true
	config.castle_damage_mode = "arriving_strength"
	config.castle_construction_mode = "granular"
	config.castle_action_limit = 1
	# v7.4 locked Castle powers. Defunct (<7 Integrity) shuts printed powers off;
	# Bastion's physical wall is the one exception and persists while it stands.
	config.castle_power_gate_mode = "operational"
	config.castle_operational_floor = 7
	config.keep_sanctuary = true
	config.bastion_wall = true
	config.bastion_lord_def_bonus = 0
	config.stockpile_filter = true
	config.circle_blood_conduit = true
	config.circle_conduit_cost = 3
	config.circle_blood_summon = true
	config.circle_blood_summon_cost = 3
	config.circle_blood_summon_discount = 3
	config.resummon_tear_mode = "none"
	# 6.10 suit economy: Butchers attack at print; off-suits lose 1 (floor 1).
	# Wrights alone pay Repair. Siege Engine grants Forge Discipline on Sieges
	# instead of reordering the combat layers. Construction gains at most 5/action.
	config.siege_engine_bypass = false
	config.siege_engine_scope = "siege"
	config.attack_offsuit_penalty = 1
	config.attack_penalty_exempt_suit = "Butcher"
	config.attack_offsuit_floor = 1
	# v7.5 suit identities: Penitent wards at print; other suits lose 1 (floor 1).
	# One or more committed Vultures reveal one entire enemy Guard area.
	config.ward_offsuit_penalty = 1
	config.ward_penalty_exempt_suit = "Penitent"
	config.ward_offsuit_floor = 1
	config.keep_ignores_ward_tax = false
	config.vulture_recon = true
	config.construction_action_cap = 5
	config.repair_wright_mode = "strict"
	config.profane_requires_full_integrity = true
	config.ruination_soul_bonus = 1
	config.ruination_soul_source = "enemy_siege"
	config.repair_token_integrity = 3
	config.master_builder_integrity = 2
	config.rapid_construction_integrity = 1
	config.profane_no_castle_gate = true

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
