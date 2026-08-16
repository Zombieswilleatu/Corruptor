#!/usr/bin/env python3
"""
╔══════════════════════════════════════════════════════════════════════════════╗
║          CORRUPTOR — Simulation / Castle Instrument Rewrite               ║
║          SIM_VERSION 7.5.0-suit-identities                          ║
║          AI_POLICY heuristic-2026.08-castle-contextual-v3             ║
║                                                                            ║
║  v7 separates three things the older harness allowed to blur together:    ║
║    1. rules resolution, 2. bot doctrine, 3. experimental measurement.      ║
║                                                                            ║
║  The historical DE-v2 / v5.29 / lab-v6.5 presets remain selectable.       ║
║  v7 is an instrumentation/policy layer over those presets, not a claim     ║
║  that every unresolved Castle-design choice has become canonical.          ║
║                                                                            ║
║  Normal roster usage:                                                      ║
║    python corruptor_sim.py --lock --games 500 --seed 43        ║
║                                                                            ║
║  Castle causal experiments:                                                ║
║    python corruptor_sim.py --castle-experiment all --games 200 ║
║    python corruptor_sim.py --castle-experiment Keep            ║
║        --experiment-mode remove --castle-gate operational --games 500     ║
║                                                                            ║
║  ADD experiment    = enable one power on an otherwise inert Castle board. ║
║  REMOVE experiment = ablate one power from the full live Castle ecosystem.║
║  Both are paired on identical deterministic game streams and crossed over ║
║  physical seats; neither question is substituted for the other.            ║
║                                                                            ║
║  Castle power-gate modes are deliberately explicit:                        ║
║    owned       — legacy 6.10 behavior: any standing Castle (1+ Integrity)  ║
║                  retains its power.                                        ║
║    operational — Integrity < 7 is Defunct and suppresses the power.        ║
║  The experiment CLI defaults to sweeping BOTH rather than silently         ║
║  deciding which design is correct.                                         ║
║                                                                            ║
║  Measurement safety: mechanic/regression failures abort simulations by     ║
║  default. --allow-failed-tests exists only as an explicit dangerous escape.║
╚══════════════════════════════════════════════════════════════════════════════╝

SIM_VERSION history
───────────────────
  1.0        Original 8-lord sim (Humbaba present, pre-Kroni). Archived.
  5.29-sync  Rebuilt to Rulebook v5.29 (Reflex Bid, sigils, veil, rites).
  5.29+DEv2  Dominion Edition tuning and errata pass.
  6.0–6.1.2  Ninth Lord, oracle/parity corrections, Lord-power correctness.
  6.5.x-lab  Measured systems: Ward, Momentum, Castle Integrity experiments,
             Threat retention, Fog, Marching Orders, Market refresh.
  6.10.x     Suit economy / Castle-kit laboratory represented by the source
             from which this rewrite was made.
  7.0.0      Instrument rewrite: deterministic named RNG streams; simultaneous
             commitment snapshots; contextual attack/defense valuation;
             strategy-aware Castle targeting/maintenance; unified Ruination;
             source-attributed Neutral Tears; corrected pool-starter semantics;
             logical-seat metric attribution; paired crossed-seat Castle ADD /
             REMOVE experiments over every opening loadout containing the
             tested Castle; explicit owned-vs-Defunct power gates; fail-closed
             regression suite.
  7.1.0      Root candidate: Lord resummons no longer advance the Neutral-Tear
             Veil clock in the working lab profile.
  7.3.0      Canonical Ward combat order: committed Ward cards are temporary
             front-line reinforcements; commitment cleanup is deferred until
             both primary actions resolve; legacy ward_turned cancellation is
             bypassed in the current lab; Keep Sanctuary transfers exact excess.
  7.5.0      Canonical suit identities: Penitent Wards at full value while
             non-Penitent Ward cards lose 1 Strength (floor 1); committing one
             or more Vultures reveals one entire enemy Guard area after Reveal.

Rulebook-alignment changelog from the historical sim is intentionally retained
in the implementation below where it documents inherited mechanics.  v7's new
code is concentrated around measurement, doctrine synchronization, Castle
power gating/targeting, Ruination resolution, reproducibility, and reporting.
"""

SIM_VERSION = "7.5.0-suit-identities"
SIM_CODENAME = "Castle rules lock + canonical suit identities"
AI_POLICY = "heuristic-2026.08-castle-contextual-v3"
LAB_PROFILE_VERSION = "7.5.0-suit-identities"

# v7 does not silently decide unresolved castle-design questions.  The active
# power gate (owned vs operational) and targeting doctrine are explicit dials,
# and the castle experiment runner can sweep both.  The legacy rulesets remain
# available for regression comparisons.

import random
import argparse
import time
import hashlib
import statistics
from collections import defaultdict
from typing import List, Set, Optional, Tuple, Dict, Iterable
import itertools

# ═══════════════════════════════════════════════════════════════════════
#  CONSTANTS
# ═══════════════════════════════════════════════════════════════════════
SUITS = ['Butcher', 'Penitent', 'Vulture', 'Wright']

# Marching Orders uses a single denial cycle.  It does not alter the ordinary
# suit bonuses used by Orders.
SUIT_BEATS = {
    'Butcher': 'Wright',
    'Wright': 'Penitent',
    'Penitent': 'Vulture',
    'Vulture': 'Butcher',
}
CARD_DIST = {1: 4, 2: 4, 3: 4, 4: 3, 5: 3}

DECK_MEAN_VALUE = 2.83
FOG_NOISE = 0.9
ADAPT_DECAY = 0.65
ADAPT_CAP = 2.0
ADAPT_RATE = {
    'Orias': 1.0, 'Deimos': 0.7, 'Valak': 1.0, 'Kroni': 0.8,
    'Kalligan': 1.1, 'Gremory': 0.9, 'Odradek': 1.4,
    'Kanifous': 1.2, 'Humbaba': 1.5,
}
HUNT_BASE = 0.90
HUNT_W1_PENALTY = 0.40
WARD_READ_FRACTION = 0.60
WARD_MAX_HAND_FRACTION = 0.70
WARD_READ_CONFIDENCE = 0.70
WARD_READ_PREF = 0.90
WARD_INCOMING_WEIGHT = 0.30
KALLIGAN_PICK_BASE = 0.70

HAND_LIMIT   = 10
GARRISON_MAX = 5
WIN_SOULS    = 7
MAX_THREAT   = 4
MARKET_SIZE  = 3
MAX_ROUNDS   = 60

# Dominion / Veil track (canonical DE v2).
DOMINION_TRACK      = 11
DOMINION_REQUIREMENT = 2
FINAL_COLLAPSE_TRACK = 15

# Canonical DE v2 defaults. The superseded v5.29 configuration remains
# available under explicit BASE_V5_29_* names for historical comparisons.
DE_V2_CONSTANTS = dict(
    WIN_SOULS=7,
    DOMINION_TRACK=11,
    DOMINION_REQUIREMENT=2,
    FINAL_COLLAPSE_TRACK=15,
    HAND_LIMIT=10,
    GARRISON_MAX=5,
    MAX_THREAT=4,
    MARKET_SIZE=3,
    MAX_ROUNDS=60,
)

BASE_V5_29_CONSTANTS = dict(
    DE_V2_CONSTANTS,
    DOMINION_TRACK=12,
    DOMINION_REQUIREMENT=3,
)

DE_V2_VARIANT = dict(
    # ══ LAB_ODRADEK_INTERLOCK_PORT ══════════════════════════════════════════════
    # Odradek Interlock. All default OFF so canonical DE v2 is untouched and a
    # flags-off run remains byte-identical to the pre-patch engine.
    odr_recoil_bank=False,           # Recoil BANKS the stolen card face-up rather
                                     # than discarding it. A banked card locks
                                     # Recoil until spent on an attack, or until a
                                     # strictly larger card is stolen.
    fix_breach_discard_alias=False,  # BUG FIX. Paradox Geometry discarded the
                                     # reflex winner's selected cards without
                                     # removing them from hand, so the same Card
                                     # object occupied two zones. Root cause of the
                                     # card-duplication / 57-vs-60 census anomaly.
                                     # Defaults OFF only to preserve byte-identity;
                                     # the lab profile MUST enable it.
    # Doctrine corrections (AI_POLICY axis — bump the policy id with these).
    doctrine_ward_threat=0.0,        # Ward penalty per Threat point. Attacks already
                                     # take -0.9 / -0.5 per Threat and Ward took
                                     # none, so rising Threat ratcheted the bot into
                                     # turtling exactly when turtling loses.
    doctrine_ward_stagnation=0.0,    # penalty per CONSECUTIVE Ward.
    doctrine_bank_urgency=0.0,       # the bot reads its own banked card: attacking
                                     # is the only way to unlock Recoil. Without
                                     # this the bot banks once and never unlocks,
                                     # switching Recoil off for the rest of the game.
    recoil_hunts_only=True,       # O1: Psychic Recoil (strip + Soul) fires on Hunts only
    sigil_soul_fresh_only=False,  # S1: sigil-break Soul only if the Sigil was Fresh
    invocation_gate=5,            # D1: Veil threshold to unlock Cataclysmic Invocation
    profane_ruins_req=1,          # D2: Ruined Castles needed for Profane the Ruins
    ai_dominion_drive=True,       # A1: AI actively pursues the Dominion race
    no_backwash=False,            # O3: remove Psychic Backwash (Threat on hunters)
    reconfig_strict=True,         # O4: ANY Guard defeat in Odradek zones denies the token
    kroni_def_soft=False,         # K3: Hunger defense curve 4/5/7 instead of 4/6/8
    kroni_hunger_decay=True,      # K1: Hunger -1 any round Kroni initiates no attack
    deimos_war_machine_free=True, # E1: War Machine no longer requires Siege Engine
    deimos_summon_cost=7,         # E2/E3: override Deimos Summon cost (0 = printed 9)
    recoil_lowest=True,           # O5: Recoil strips the LOWEST committed card
    neutral_tear_on_banish=True,  # D3: Banishing a Lord tears the Veil (1 Neutral Tear)
    castle_tear_uncapped=False,   # D4: EVERY Castle destroyed places a Neutral Tear
    veil_drift=0,                 # D5: every N rounds the Veil frays (+1 Neutral), 0=off
    invocation_repeatable=False,  # D6: Cataclysmic Invocation once per ROUND, not per game
    reconfig_tokens_needed=5,     # O6: Reconfiguration tokens per Tear
    reconfig_neutral=False,       # O7: Reconfiguration places NEUTRAL Tears (not personal)
    deimos_claims_breach=1,       # E4: 0=off, 1=first castle kill per GAME is personal, 2=every
    consume_the_siege=False,      # D7: any lord may forgo Siege Souls -> personal Tear
    war_machine_ignores_profaned=False,  # E5: self-Profaned castles don't reduce War Machine
    gremory_summon_cost=6,        # G1: override Gremory Summon cost (0 = printed 5)
    # ── Humbaba, Ancient Guardian (ninth lord) ──
    humbaba_seal=True,            # H1: Dominion needs +1 personal Tear while he stands
    humbaba_toll=True,            # H2: once/round ruin own castle -> opp -1 Soul, +1 Neutral Tear
    humbaba_gate4=True,           # H3: 4th castle guard slot while no Ruined castles
    humbaba_patient=True,         # H4: passive round preserves one Sigil from decay
    # Experimental 6.5 structural switches. DE v2 keeps all new mechanics
    # inert, but their explicit defaults belong in trace identity.
    fix_a=False,
    fix_b=False,
    ward_threshold=False,
    ward_anti_repeat=True,
    ward_commit_any=False,
    ward_read=False,
    ward_garrison_refund=False,
    sigil_flat=False,
    humbaba_sigil_commit=False,
    repair_escalation=0,
    castle_scarring=False,
    castle_scar_def=2,
    castle_permanent_loss=False,
    veil_on_permanent_loss=False,
    lord_threat_retention=False,
    reflex_bid=True,
    momentum=False,
    momentum_band=3,
    fog_of_war=False,
    marching=False,
    march_max_in_flight=1,
    march_threshold=3,
    march_damage=2,
    march_suit_bonus=1,
    march_steps=3,
    march_exception_pair=True,
    lane_kill_soul=False,
    adaptive_doctrine=False,
    castle_loadout=False,
    max_castles=3,
    profane_no_castle_gate=False,
    castleless_siege=False,
    castleless_tear_neutral=True,
)

LAB_V6_5_CONSTANTS = dict(
    DE_V2_CONSTANTS,
    WIN_SOULS=12,
    DOMINION_TRACK=12,
    DOMINION_REQUIREMENT=5,
    FINAL_COLLAPSE_TRACK=26,
)

# Experimental v6.5 structural profile. It begins with canonical DE v2, then
# explicitly restores every inherited baseline value used by the measured 6.8.6
# lab. The explicit overrides prevent future canonical changes from silently
# altering the measured profile.
LAB_V6_5_VARIANT = dict(
    DE_V2_VARIANT,
    # The measured 6.8.6 lab inherited these values from the original 6.1
    # baseline. Spell them out here so canonical DE v2 defaults cannot leak
    # into the lab profile again.
    invocation_gate=7,
    profane_ruins_req=2,
    profane_ruins_cost=5,
    ai_dominion_drive=False,
    kroni_hunger_decay=False,
    neutral_tear_on_banish=False,
    gremory_summon_cost=0,
    fix_a=True,
    fix_b=True,
    # Finish the Odradek port in the actual Python lab preset. The engine and
    # tests landed previously, but the measured profile never enabled them.
    odr_recoil_bank=True,
    fix_breach_discard_alias=True,
    reconfig_neutral=True,
    reconfig_tokens_needed=3,
    reconfig_strict=False,
    recoil_hunts_only=False,
    recoil_lowest=False,
    doctrine_ward_threat=0.20,
    doctrine_ward_stagnation=0.30,
    doctrine_bank_urgency=0.35,
    ward_threshold=True,
    ward_frontline=True,
    ward_anti_repeat=False,
    ward_commit_any=True,
    ward_read=True,
    ward_garrison_refund=True,
    sigil_flat=True,
    humbaba_seal=False,
    humbaba_gate4=True,
    humbaba_patient=False,
    humbaba_sigil_commit=False,
    repair_escalation=0,
    # Castle Integrity supersedes scarring and repeatable rebuilding.
    castle_scarring=False,
    castle_scar_def=2,
    castle_permanent_loss=False,
    veil_on_permanent_loss=False,
    lord_threat_retention=True,
    reflex_bid=False,
    momentum=True,
    momentum_band=3,
    marching=True,
    march_max_in_flight=1,
    march_threshold=3,
    march_damage=2,
    march_suit_bonus=1,
    march_steps=3,
    march_exception_pair=True,
    lane_kill_soul=True,
    fog_of_war=True,
    adaptive_doctrine=False,
    castle_loadout=True,
    starting_castles=3,
    castle_type_count=5,
    castle_unique_types=True,
    castle_doctrine_denominator=5,
    castle_damage_mode='arriving_strength',
    castle_construction_mode='granular',
    castle_action_limit=1,
    castle_power_gate_mode='operational', # locked: powers switch off below 7 Integrity
    castle_operational_floor=7,
    castle_targeting_mode='strategic',   # replaces identity-coded fixed target ladder
    castle_owner_doctrine='strategic',   # repair/build/profane evaluate current castle utility
    # ── Castle kit 6.11 — each independently ablatable ──────────────
    keep_sanctuary=True,          # Keep absorbs Hunt excess to prevent banishment
    bastion_fortified=True,       # Bastion physically screens rear Castles while it stands
    bastion_wall=True,            # canonical alias used by live Godot/Python parity tests
    bastion_forced_wall=False,    # historical compatibility
    bastion_direct_targetable=True,# test axis: may Siege Bastion directly while it screens
    bastion_lord_def_bonus=0,     # wall identity replaces the old passive +2 Lord DEF
    bastion_screen_while_defunct=True, # physical screen persists below 7 until Bastion is Ruined
    bastion_overflow_mitigation=0,# no extra mitigation: Bastion HP itself is the screen
    bastion_wall_chip_target=4,   # doctrine: structural chip against the wall is meaningful progress
    stockpile_filter=True,        # Stockpile: draw 2 keep 1 instead of flat +1 card
    stockpile_depot=False,        # Stockpile: Exert 2 for a SECOND Castle action
    stockpile_depot_cost=2,
    circle_blood_conduit=True,    # SummoningCircle: Exert to prevent 1 Threat
    circle_conduit_cost=3,        # Integrity per Threat prevented
    resummon_tear_mode='none',    # ROOT CANDIDATE: resummoning no longer advances the shared Veil
    castle_ruination_tear_mode='neutral',  # Castle Ruination still advances the shared Veil
    profane_action_enabled=True,
    profane_soul_deficit_bonus=1.6,
    resummon_delay_rounds=0,      # locked v7.4: no global resummon delay
    circle_ignores_delay=False,   # trimmed Circle: no free delay exemption
    stockpile_tokens=0,           # trimmed Stockpile: selection only
    reinforce_cap=0,              # trimmed Stockpile: no Reinforce rider
    stockpile_token_cap=0,        # trimmed Stockpile: no token bank
    circle_discount=0,            # retired unconditional discount
    circle_opening_summon=False,  # retained only for historical compatibility
    circle_blood_summon=True,     # Blood Offering: Exert Integrity to reduce Summon cost
    circle_blood_summon_cost=3,
    circle_blood_summon_discount=3,
    siege_engine_bypass=False,       # retired: SE no longer reorders combat
    siege_engine_scope='siege',      # 'siege' | 'all'
    # ── Castle riders keyed to measured currencies ──────────────────
    se_breach_the_gate=False,        # SiegeEngine: your Hunts cannot be turned by a Ward
    stockpile_muster=False,          # Stockpile: banishment does not clear your Lord Guards
    circle_swift_return=False,       # SummoningCircle: return at Threat 0
    guard_offsuit_penalty=0,         # non-Vulture Guards defend at -this, floor 1
    guard_penalty_exempt_suit='Vulture',
    guard_offsuit_floor=1,
    circle_ignores_guard_tax=False,  # SummoningCircle: your Guards ignore the Vulture tax
    stockpile_ignores_wright=False,  # Stockpile: Repairs ignore the Wright requirement
    ward_offsuit_penalty=1,          # canonical: non-Penitent Ward cards lose 1 Strength
    ward_penalty_exempt_suit='Penitent',
    ward_offsuit_floor=1,
    keep_ignores_ward_tax=False,     # Keep: your Wards ignore the Penitent tax
    vulture_recon=True,               # >=1 committed Vulture reveals one enemy Guard area
    attack_offsuit_penalty=1,        # non-exempt suits lose this when attacking
    attack_penalty_exempt_suit='Butcher',
    attack_offsuit_floor=1,
    construction_action_cap=5,   # max Integrity of progress per construction action; 0 = uncapped
    # Repair is paid in Wright cards. Suit supply IS the cap; no numeric cap.
    #   'off'    legacy — any card pays
    #   'strict' every payment card must be Wright
    #   'gate'   at least one Wright, remainder any suit
    repair_wright_mode='strict',
    ruination_soul_bonus=1,
    ruination_soul_source='enemy_siege',
    castle_ruination_irreparable=True,
    repair_token_integrity=3,
    master_builder_integrity=2,
    rapid_construction_integrity=1,
    profane_no_castle_gate=True,
    profane_requires_full_integrity=True,
    castleless_siege=False,
    castleless_tear_neutral=True,
)

# Keep measured-lab features separate from DE v2's serialized variant identity.
# A canonical trace must not gain a new identity key for a feature that is off
# and never runs under the canonical ruleset.  Direct indexing below makes a
# missing feature declaration fail loudly instead of silently disabling it.
DE_V2_FEATURES = dict(
    market_refresh=False,
    ward_commit_defense=False,
    humbaba_reactive_lane=False,
    # Kroni v0.1 remains legacy in canonical DE v2. The lab flips both dials.
    kro_fallback_feeds=True,
    kro_milestone_once=False,
    momentum_refund=0,
    veil_drift_rate=0.0,
    veil_drift_after=0,
    veil_drift_growth=0.0,
    kal_inferno_threat=True,
    kal_flame_tokens=False,
    kal_flame_per_soul=5,
    kal_scorch_escalate=False,
    kal_scorch_cap=3,
    kal_lane_scorch=False,
    kal_lane_scorch_thresh=2,
    # Historical DE v2 compatibility. The current gameplay profile enables all four.
    castle_integrity=False,
    castle_identity=True,
    castle_granular_repair=False,
    castle_construction=False,
    castle_irreparable=False,
    kani_invoke=True,
    kani_threat_cost=True,
    kani_hand_cost=False,
    kani_neutral_tear=True,
    kani_soul_trigger=True,
    kani_garrison_bank=True,
    kani_suit_effects=True,
)

BASE_V5_29_FEATURES = dict(
    DE_V2_FEATURES,
)

LAB_V6_5_FEATURES = dict(
    DE_V2_FEATURES,
    market_refresh=True,
    ward_commit_defense=True,
    humbaba_reactive_lane=True,
    kro_fallback_feeds=False,
    kro_milestone_once=True,
    momentum_refund=1,
    veil_drift_after=15,
    veil_drift_growth=0.25,
    kal_inferno_threat=False,
    kal_flame_tokens=True,
    kal_flame_per_soul=5,
    kal_scorch_escalate=True,
    kal_scorch_cap=3,
    kal_lane_scorch=True,
    kal_lane_scorch_thresh=2,
    # Current canonical Castle Integrity rules; historical DE v2 remains
    # available only for trace comparison and golden-oracle continuity.
    castle_integrity=True,
    castle_identity=True,    # locked v7.4: Defunct suppresses printed powers
    castle_granular_repair=True,
    castle_construction=True,
    castle_irreparable=True,
    kani_threat_cost=False,
    kani_hand_cost=True,
)

BASE_V5_29_VARIANT = dict(
    DE_V2_VARIANT,
    recoil_hunts_only=False,
    invocation_gate=7,
    profane_ruins_req=2,
    ai_dominion_drive=False,
    reconfig_strict=False,
    kroni_hunger_decay=False,
    deimos_war_machine_free=False,
    deimos_summon_cost=0,
    recoil_lowest=False,
    neutral_tear_on_banish=False,
    reconfig_tokens_needed=3,
    deimos_claims_breach=0,
    gremory_summon_cost=0,
)

VARIANT = dict(DE_V2_VARIANT)
ACTIVE_FEATURES = dict(DE_V2_FEATURES)
ACTIVE_RULESET = "de-v2"


def activate_ruleset(ruleset: str) -> None:
    """Activate one named ruleset without silently mixing its constants.

    The laboratory clock bundle was measured as a unit.  In particular,
    `DOMINION_TRACK=12` is deliberate; using DE v2's 11 here would create an
    unmeasured hybrid even if every structural switch were otherwise correct.
    """
    presets = {
        'de-v2': (DE_V2_VARIANT, DE_V2_CONSTANTS, DE_V2_FEATURES),
        'v5.29': (BASE_V5_29_VARIANT, BASE_V5_29_CONSTANTS, BASE_V5_29_FEATURES),
        'lab-v6.5': (LAB_V6_5_VARIANT, LAB_V6_5_CONSTANTS, LAB_V6_5_FEATURES),
    }
    if ruleset not in presets:
        raise ValueError('Unknown ruleset: %s' % ruleset)

    variant, constants, features = presets[ruleset]
    VARIANT.clear()
    VARIANT.update(variant)
    ACTIVE_FEATURES.clear()
    ACTIVE_FEATURES.update(features)

    global WIN_SOULS, DOMINION_TRACK, DOMINION_REQUIREMENT
    global FINAL_COLLAPSE_TRACK, HAND_LIMIT, GARRISON_MAX, MAX_THREAT
    global MARKET_SIZE, MAX_ROUNDS, ACTIVE_RULESET

    WIN_SOULS = constants['WIN_SOULS']
    DOMINION_TRACK = constants['DOMINION_TRACK']
    DOMINION_REQUIREMENT = constants['DOMINION_REQUIREMENT']
    FINAL_COLLAPSE_TRACK = constants['FINAL_COLLAPSE_TRACK']
    HAND_LIMIT = constants['HAND_LIMIT']
    GARRISON_MAX = constants['GARRISON_MAX']
    MAX_THREAT = constants['MAX_THREAT']
    MARKET_SIZE = constants['MARKET_SIZE']
    MAX_ROUNDS = constants['MAX_ROUNDS']
    ACTIVE_RULESET = ruleset

# ── Simulation mode ──────────────────────────────────────────────────
# LOCK_LORDS = True:  each player is locked to exactly one lord for the
#   entire game. Pool size is 1. No switching. True head-to-head data.
# LOCK_LORDS = False: standard pool of 3 with AI-driven lord switching.
LOCK_LORDS = False

CASTLE_DEF = {
    'Keep':            13,
    'Bastion':         11,
    'SummoningCircle':  9,
    'Stockpile':        8,
    'SiegeEngine':      7,
}
CASTLE_COST = dict(CASTLE_DEF)   # legacy binary rebuild cost (own dict: see Law 5 notes)
CASTLES = list(CASTLE_DEF.keys())
CASTLE_MAX_INTEGRITY = 14

# ── Castle Identity tiers ────────────────────────────────────────────────
#   Operational  OPERATIONAL_FLOOR .. MAX   printed/identity power is live
#   Defunct      1 .. OPERATIONAL_FLOOR-1   power inactive, stones still stand
#   Ruined       0                          removed from play, irreparable
CASTLE_OPERATIONAL_FLOOR = 7

# Lab probe: the OPPORTUNITY denominator. Counts every power-gate query and
# how many were denied by Defunct. Without this we cannot tell "bot chose
# badly" from "the window never opened" (§3 blindness vs §2 magnitude).
CASTLE_STATE_OPERATIONAL = 'operational'
CASTLE_STATE_DEFUNCT     = 'defunct'
CASTLE_STATE_RUINED      = 'ruined'


def castle_max_integrity(castle: str) -> int:
    """Current canonical wall size; legacy profiles retain printed DEF."""
    if ACTIVE_FEATURES.get('castle_integrity', False):
        return CASTLE_MAX_INTEGRITY
    return CASTLE_DEF[castle]


def castle_state_for(integrity: int) -> str:
    """Pure tier lookup. Integrity in, tier out — no Player, no VARIANT."""
    if integrity <= 0:
        return CASTLE_STATE_RUINED
    if integrity >= CASTLE_OPERATIONAL_FLOOR:
        return CASTLE_STATE_OPERATIONAL
    return CASTLE_STATE_DEFUNCT


KIT_PROBE: dict = {}


def _kit(tag: str, n: int = 1) -> None:
    """Opportunity/activation counters. Per §3 the DENOMINATOR is the point:
    it separates 'the bot chose badly' from 'the window never opened'."""
    KIT_PROBE[tag] = KIT_PROBE.get(tag, 0) + n


def effective_ward_value(pl, card: 'Card') -> int:
    """What one card is WORTH on a Ward. Doctrine must size in the same
    currency the resolver spends, or it undercommits by exactly the tax and the
    rule measures larger than it is (§3)."""
    pen = int(VARIANT.get('ward_offsuit_penalty', 0) or 0)
    if pen <= 0:
        return card.value
    if (VARIANT.get('keep_ignores_ward_tax', False)
            and pl.castle_power_active('Keep')):
        return card.value
    if card.suit == VARIANT.get('ward_penalty_exempt_suit', 'Penitent'):
        return card.value
    return max(int(VARIANT.get('ward_offsuit_floor', 1)), card.value - pen)


def effective_guard_value(card: 'Card', exempt: bool = False) -> int:
    """Defensive worth of one Guard under the Vulture tax. Estimators and
    Deploy doctrine must use this, or attackers overestimate walls and
    defenders garrison the wrong suits (§3)."""
    pen = int(VARIANT.get('guard_offsuit_penalty', 0) or 0)
    if pen <= 0 or exempt:
        return card.value
    if card.suit == VARIANT.get('guard_penalty_exempt_suit', 'Vulture'):
        return card.value
    return max(int(VARIANT.get('guard_offsuit_floor', 1)), card.value - pen)


def attack_tax_exempt(pl: 'Player', target_type: str) -> bool:
    """Whether *this player, on this attack type* ignores the Butcher tax.

    v6.10 had three different answers to this question: the resolver knew the
    Siege-only scope, action scoring treated the Engine as exempting both Hunt
    and Siege, and commitment sizing ignored the Engine entirely.  v7 makes
    this the single source of truth used by all three doctrine layers.
    """
    if not pl.castle_power_active('SiegeEngine'):
        return False
    scope = VARIANT.get('siege_engine_scope', 'siege')
    return scope == 'all' or (scope == 'siege' and target_type == 'Castle')


def effective_attack_value(pl: 'Player', card: 'Card', target_type: str) -> int:
    """Contextual attack value shared by resolver, sizing and scoring."""
    pen = int(VARIANT.get('attack_offsuit_penalty', 0) or 0)
    if pen <= 0 or attack_tax_exempt(pl, target_type):
        return card.value
    if card.suit == VARIANT.get('attack_penalty_exempt_suit', 'Butcher'):
        return card.value
    return max(int(VARIANT.get('attack_offsuit_floor', 1)), card.value - pen)


def repair_payment_pool(cards: List['Card'], pl=None) -> List['Card']:
    """Cards legally usable to pay a Repair, under the Wright requirement.

    Returns [] when the Wright requirement cannot be met at all — callers MUST
    treat that as "Repair is not a legal action this round", not as "pay zero".
    """
    mode = VARIANT.get('repair_wright_mode', 'off')
    if mode == 'off':
        return list(cards)
    if pl is not None and VARIANT.get('stockpile_ignores_wright', False) \
            and pl.castle_power_active('Stockpile'):
        return list(cards)          # Stockpile — the Yard: any suit pays
    wrights = [c for c in cards if c.suit == 'Wright']
    if not wrights:
        return []
    if mode == 'strict':
        return wrights
    return list(cards)          # 'gate': one Wright exists, all cards spendable


def profane_eligible(pl, castle: str) -> bool:
    """Only a Castle at FULL Integrity may be Profaned. One point of chip
    damage denies eligibility — this is what gives a scratch tactical value."""
    if castle not in pl.castles:
        return False
    if not VARIANT.get('profane_requires_full_integrity', False):
        return True
    return (pl.castle_integrity.get(castle, castle_max_integrity(castle))
            >= castle_max_integrity(castle))


def castle_board_fraction(count: int) -> float:
    """Normalize against all five buildable Castle types, never the opening three."""
    denominator = max(1, int(VARIANT.get('castle_doctrine_denominator', len(CASTLES))))
    return max(0.0, min(1.0, count / float(denominator)))


def choose_payment_cards(cards: List['Card'], target: int) -> List['Card']:
    """Meet a value target with least overshoot, then fewest physical cards.

    If the pool cannot reach the target, return the highest-value reachable subset.
    This supports granular construction without duplicating or inventing cards.
    """
    if not cards or target <= 0:
        return []
    dp = {0: ()}
    for idx, card in enumerate(cards):
        for total, indices in list(dp.items())[::-1]:
            new_total = total + card.value
            candidate = indices + (idx,)
            if new_total not in dp or len(candidate) < len(dp[new_total]):
                dp[new_total] = candidate
    positive = [total for total in dp if total > 0]
    if not positive:
        return []
    meeting = [total for total in positive if total >= target]
    if meeting:
        chosen_total = min(meeting, key=lambda total: (total - target, len(dp[total]), total))
    else:
        chosen_total = max(positive, key=lambda total: (total, -len(dp[total])))
    return [cards[idx] for idx in dp[chosen_total]]

LORD_STATS = {
    'Orias':    {'s': 6, 'd': 6, 'r': 0},
    'Deimos':   {'s': 9, 'd': 4, 'r': 0},
    'Valak':    {'s': 6, 'd': 5, 'r': 1},
    'Kroni':    {'s': 5, 'd': 5, 'r': 1},
    'Kalligan': {'s': 4, 'd': 4, 'r': 1},
    'Gremory':  {'s': 5, 'd': 4, 'r': 2},
    'Odradek':  {'s': 8, 'd': 5, 'r': 2},
    'Kanifous': {'s': 4, 'd': 5, 'r': 1},
    'Humbaba':  {'s': 6, 'd': 2, 'r': 2},   # base d; true defense = 2 + intact castles
    # Vanilla — no kit. Every ability in this sim is gated on a lord-name
    # check, so a Lord matching none of them is automatically kitless. Used
    # for STRUCTURAL questions (§6): what does a Castle do, absent nine kits.
    'Vanilla':  {'s': 6, 'd': 5, 'r': 1},
}
ALL_LORDS = [l for l in LORD_STATS if l != 'Vanilla']
ROSTER_LORDS = ALL_LORDS

CASTLE_PRIORITIES = {
    'Orias':    ['SiegeEngine', 'Bastion',   'Stockpile',       'SummoningCircle', 'Keep'],
    'Deimos':   ['SiegeEngine', 'Bastion',   'Stockpile',       'Keep',            'SummoningCircle'],
    'Valak':    ['SiegeEngine', 'Keep',      'Bastion',         'Stockpile',       'SummoningCircle'],
    'Kroni':    ['Keep',        'Bastion',   'Stockpile',       'SummoningCircle', 'SiegeEngine'],
    'Kalligan': ['SiegeEngine', 'Stockpile', 'SummoningCircle', 'Bastion',         'Keep'],
    'Gremory':  ['SiegeEngine', 'Stockpile', 'SummoningCircle', 'Bastion',         'Keep'],
    'Odradek':  ['Keep',        'Bastion',   'SummoningCircle', 'Stockpile',       'SiegeEngine'],
    'Kanifous': ['Keep',        'Bastion',   'SummoningCircle', 'Stockpile',       'SiegeEngine'],
    'Humbaba':  ['Keep',        'Bastion',   'Stockpile',       'SummoningCircle', 'SiegeEngine'],
    'Vanilla':  ['Keep',        'Bastion',   'Stockpile',       'SummoningCircle', 'SiegeEngine'],
}

# Opening loadouts use each Lord's existing five-Castle priority and take
# the first three. No Castle is mandatory and construction can later reach all five.

LORD_AI = {
    'Orias':    dict(aggro=1.30, control=0.65, risk=1.20, prefer='Hunt'),
    'Deimos':   dict(aggro=1.15, control=0.85, risk=1.00, prefer='Siege'),
    'Valak':    dict(aggro=1.15, control=0.85, risk=0.85, prefer='Hunt'),
    'Kroni':    dict(aggro=0.95, control=1.00, risk=0.75, prefer='Hunt'),  # fights to feed Hunger->Tear at 3+
    'Kalligan': dict(aggro=0.95, control=1.25, risk=0.95, prefer='Siege'),
    'Gremory':  dict(aggro=1.20, control=0.85, risk=1.05, prefer='Siege'),  # Siege feeds Inevitable Ruin
    'Odradek':  dict(aggro=0.75, control=1.25, risk=0.65, prefer='Ward'),  # Dominion racer; Ward to avoid stripping 2+ guards
    'Kanifous': dict(aggro=1.00, control=1.10, risk=1.25, prefer='Ward'),
    'Humbaba':  dict(aggro=0.65, control=1.35, risk=0.60, prefer='Ward'),
    'Vanilla':  dict(aggro=1.00, control=1.00, risk=1.00, prefer='Siege'),
}


# ═══════════════════════════════════════════════════════════════════════
#  RANDOMNESS / COMMON-RANDOM-NUMBER INSTRUMENTATION
# ═══════════════════════════════════════════════════════════════════════
def stable_seed(base_seed: int, *parts) -> int:
    payload = ':'.join([str(int(base_seed))] + [str(p) for p in parts]).encode('utf-8')
    return int.from_bytes(hashlib.blake2b(payload, digest_size=8).digest(), 'big')


class RNGStreams:
    """Deterministic named pseudo-random streams derived from one game seed.

    A treatment changing one policy branch should not silently perturb deck order,
    first-player selection, fog noise, and every later coin flip.  Named streams
    are not perfect counterfactual coupling, but they preserve far more common
    randomness than the old single global generator.
    """
    def __init__(self, seed: Optional[int] = None):
        if seed is None:
            seed = random.SystemRandom().randrange(1 << 63)
        self.seed = int(seed)
        self._streams: Dict[str, random.Random] = {}

    def stream(self, name: str) -> random.Random:
        if name not in self._streams:
            payload = f"{self.seed}:{name}".encode('utf-8')
            derived = int.from_bytes(hashlib.blake2b(payload, digest_size=8).digest(), 'big')
            self._streams[name] = random.Random(derived)
        return self._streams[name]


# ═══════════════════════════════════════════════════════════════════════
#  CARD & DECK
# ═══════════════════════════════════════════════════════════════════════
class Card:
    __slots__ = ('suit', 'value', 'guard_revealed')
    def __init__(self, suit: str, value: int):
        self.suit  = suit
        self.value = value
        # Reconnaissance is public information in 1v1. The flag follows this
        # physical Guard only while it remains on the board; deployment code
        # resets newly placed Guards face-down.
        self.guard_revealed = False
    def __repr__(self): return f"{self.suit[0]}{self.value}"


def summon_base_cost(lord: str) -> int:
    if lord == 'Deimos' and VARIANT['deimos_summon_cost']:
        return VARIANT['deimos_summon_cost']
    if lord == 'Gremory' and VARIANT['gremory_summon_cost']:
        return VARIANT['gremory_summon_cost']
    return LORD_STATS[lord]['s']


def make_deck_2p(rng: Optional[random.Random] = None) -> List[Card]:
    rng = rng or random.Random()
    # Every physical card must have its own object identity.
    #
    # Do not use `[Card(suit, value)] * count` here. That repeats references
    # to one Card instance and makes distinct physical cards alias each other.
    cards = [
        Card(suit, value)
        for suit in SUITS
        for value, count in CARD_DIST.items()
        for _ in range(count)
    ]

    rng.shuffle(cards)
    removed = defaultdict(int)
    deck = []
    for c in cards:
        if removed[c.suit] < 3:
            removed[c.suit] += 1
        else:
            deck.append(c)
    rng.shuffle(deck)
    return deck


# ═══════════════════════════════════════════════════════════════════════
#  PLAYER STATE
# ═══════════════════════════════════════════════════════════════════════
class Player:
    def __init__(self, pid: int, lord_pool: list):
        self.pid        = pid
        self.lord_pool  = lord_pool
        self.lord       = lord_pool[0]
        self.alive      = False

        self.hand:           List[Card] = []
        self.garrison:       List[Card] = []
        self.castle_guards:  List[Card] = []
        self.lord_guards:    List[Card] = []
        self.castles:        Set[str]   = set()
        self.ruined_castles: Set[str]   = set()
        self.profaned_castles: Set[str] = set()

        # Instrument layer: asymmetric castle experiments must be able to blank
        # a power for one player without changing the global rules for the other.
        # Membership/Integrity stay untouched; only the printed/identity power is
        # suppressed.  This is the basis of crossed-seat add/remove ablations.
        self.disabled_castle_powers: Set[str] = set()

        self.souls   = 0
        self.tears   = 0   # personal tears only — Attunement = self.tears
        self.threat  = 0

        # Per-game flags
        self.cataclysmic_used     = False
        self.vessel_used          = False
        self.vessel_offered_lord  = ''    # that lord resummons at Threat 2
        self.repair_token         = 0     # max 1; earned via Wright suit bonus; persists across rounds
        self.kalligan_repair_used = False
        self.kalligan_flame_tokens = 0
        self.repair_token_used_this_repair = False
        self.repaired_this_round = False
        # v6.5 Lord decay records a scarred return value at Banishment and
        # consumes it when the same Lord is next summoned.
        self.return_threat_override: Optional[int] = None
        self.kroni_ravenous_used  = False
        self.deimos_breach_claimed = False
        self.humbaba_patient = False   # set at end of round, consumed at Sigil Update
        self.first_summon_done    = False   # first summon doesn't trigger Neutral Tear

        # Kroni Hunger
        self.kroni_hunger = 0
        self.momentum_refund_due = 0

        # Round-scoped state
        self.committed:        List[Card] = []
        self.action:           str  = ''
        self.tgt_pid:          int  = -1
        self.tgt_type:         str  = ''
        self.ward_target:      str  = ''
        self.prev_ward_target: str  = ''

        # Sigils — one per zone, own zones only (v5.29)
        # state: '' (none) / 'fresh' / 'flipped'
        self.sigils = {'Lord': '', 'Castle': ''}

        self.was_hunted:               bool = False
        self.was_sieged:               bool = False
        self.was_lord_attacked_prev:   bool = False
        self.was_castle_attacked_prev: bool = False
        self.last_sieged_castle:       str  = ''   # for Gremory Inevitable Ruin
        self.pending_profane:          str  = ''   # castle named for Profane action

        self.orias_snare_active: bool = False
        self.cornered:           bool = False
        self.cornered_next_round: bool = False

        self.profane_ruins_used_this_round: bool = False

        self.profane_this_round: bool = False

        # ── INTERLOCK: persistent, survives round reset, cleared only by
        # explicit bank transitions. MUST be copied by state duplication,
        # exposed to the bot view, serialised in snapshots, and counted as
        # a physical-card zone in conservation censuses.
        self.odradek_bank                = None   # Optional[Card], face up
        self.consecutive_wards           = 0      # doctrine stagnation

        self.odradek_recoil_done         = False
        self.odradek_guards_defeated     = 0   # guards defeated from Odradek zones this round
        self.odradek_reconfig_tokens     = 0   # persists across rounds, resets on summon
        self.gremory_ruin_done           = False
        self.gremory_breach_soul_given   = False
        self.gremory_inevitable_ruin_done = False
        self.gremory_veil_draw_done      = False  # Ruinous Harvest: once per round
        self.gremory_lord_guard_draw_done = False  # Predator of Ruin: lord guard trigger
        self.kanifous_outside_draws      = 0
        self.kanifous_invoked_suit       = ''
        self.kanifous_invoked_high       = False
        self.kanifous_invokes_this_round = 0

        self.kroni_consume_done              = False
        self.kroni_personally_defeated_guard = False
        self.kroni_enemy_destroyed           = False
        self.kroni_tear_milestone_fired      = False  # resets each summon

        self.penitent_temp_guards: List[Card] = []

        # v6.5 structural state.  Scars and permanent loss are board facts;
        # marchers retain their physical card while their lane value changes.
        self.castle_repairs: dict[str, int] = {}
        self.castle_integrity: dict[str, int] = {}
        self.castle_construction_progress: dict[str, int] = {}
        self.banished_on_round: int = -99   # for the resummon delay
        self.construction_tokens: int = 0   # Stockpile bank
        self.castle_action_used_this_round: bool = False
        self.castle_scars: dict[str, int] = {}
        self.lost_castles: Set[str] = set()
        self.ward_turned: Set[str] = set()
        self.marchers: List[dict] = []

    def reset_round(self):
        self.was_lord_attacked_prev   = self.was_hunted
        self.was_castle_attacked_prev = self.was_sieged

        self.committed      = []
        self.action         = ''
        self.tgt_pid        = -1
        self.tgt_type       = ''
        self.ward_target    = ''
        self.was_sieged     = False
        self.was_hunted     = False
        self.last_sieged_castle  = ''
        self.pending_profane     = ''
        self.cornered            = self.cornered_next_round
        self.cornered_next_round = False
        self.profane_this_round  = False
        self.profane_ruins_used_this_round = False
        self.repaired_this_round = False
        self.repair_token_used_this_repair = False
        self.castle_action_used_this_round = False
        self.orias_snare_active  = False

        self.odradek_recoil_done         = False
        self.odradek_guards_defeated     = 0   # guards defeated from Odradek zones this round
        self.gremory_ruin_done           = False
        self.gremory_breach_soul_given   = False
        self.gremory_inevitable_ruin_done = False
        self.gremory_veil_draw_done      = False
        self.gremory_lord_guard_draw_done = False
        self.kanifous_outside_draws      = 0
        self.kanifous_invoked_suit       = ''
        self.kanifous_invoked_high       = False
        self.kanifous_invokes_this_round = 0
        self.kroni_consume_done              = False
        self.kroni_personally_defeated_guard = False
        self.kroni_enemy_destroyed           = False
        self.momentum_refund_due             = 0
        self.ward_turned = set()

    def committed_value(self) -> int:
        return sum(c.value for c in self.committed)

    def ward_value(self) -> int:
        """Strength of the cards committed to WARD.

        This is the reinforcement line's card value after the Penitent/off-suit
        tax. Initiative still uses raw ``committed_value()``; combat does not.
        """
        pen = int(VARIANT.get('ward_offsuit_penalty', 0) or 0)
        if pen <= 0:
            return self.committed_value()
        # Keep — Sanctuary of the Rite: your Wards are not suit-taxed.
        if (VARIANT.get('keep_ignores_ward_tax', False)
                and self.castle_power_active('Keep')):
            return self.committed_value()
        suit  = VARIANT.get('ward_penalty_exempt_suit', 'Penitent')
        floor = int(VARIANT.get('ward_offsuit_floor', 1))
        return sum(c.value if c.suit == suit else max(floor, c.value - pen)
                   for c in self.committed)

    def ward_reinforcement_value(self) -> int:
        """Temporary front-line defense supplied by a Ward commitment.

        Ward cards arrive for this battle, protect every permanent layer behind
        them, and leave after primary Resolution. Two committed Penitent cards
        retain the ordinary +1 suit bonus.
        """
        if self.action != 'Ward':
            return 0
        value = self.ward_value() + self.suit_bonus('Penitent')
        if (VARIANT.get('humbaba_sigil_commit', False)
                and self.lord == 'Humbaba'):
            value += 2 + (1 if self.castle_power_active('Keep') else 0)
        return value

    def attack_value(self, siege: bool = False) -> int:
        """Strength when ATTACKING (Hunt or Siege). Distinct from
        committed_value, which also drives Ward strength, initiative order and
        defensive screens — those must stay unpenalised."""
        pen = int(VARIANT.get('attack_offsuit_penalty', 0) or 0)
        if pen <= 0:
            return self.committed_value()
        target_type = 'Castle' if siege else 'Lord'
        return sum(effective_attack_value(self, c, target_type)
                   for c in self.committed)

    def suit_count(self, suit: str) -> int:
        return sum(1 for c in self.committed if c.suit == suit)

    def suit_bonus(self, suit: str) -> int:
        return 1 if self.suit_count(suit) >= 2 else 0

    def lord_base_def(self, breach: Optional[str] = None) -> int:
        if self.lord == 'Humbaba':
            # Woven into the stones: Defense = 2 + intact castles (Bastion adds
            # its usual +2 below like any lord's, so a full board peaks at 9;
            # a stripped board bottoms at 2 before Threat).
            d = 2 + len(self.castles)
            if   self.threat >= 4: d -= 3
            elif self.threat >= 3: d -= 2
            elif self.threat >= 2: d -= 1
            if self.castle_power_active('Bastion'):
                d += int(VARIANT.get('bastion_lord_def_bonus', 2) or 0)
            return max(0, d)
        if self.lord == 'Kroni':
            hi = 7 if VARIANT['kroni_def_soft'] else 8
            mid = 5 if VARIANT['kroni_def_soft'] else 6
            if self.kroni_hunger >= 3:   d = hi
            elif self.kroni_hunger >= 1: d = mid
            else:                        d = 4
        else:
            d = LORD_STATS[self.lord]['d']

        if   self.threat >= 4: d -= 3
        elif self.threat >= 3: d -= 2
        elif self.threat >= 2: d -= 1

        if self.castle_power_active('Bastion'):
            d += int(VARIANT.get('bastion_lord_def_bonus', 2) or 0)

        return max(0, d)

    # ── Castle Identity ──────────────────────────────────────────────
    def castle_state(self, castle: str) -> str:
        """Physical state of a Castle. Not-owned reads as Ruined.

        ``castle_power_gate_mode='owned'`` preserves the v6.10 experiment in
        which every standing Castle remained fully powered down to 1 Integrity.
        ``'operational'`` restores the 7+ Integrity Defunct tier.  The choice is
        explicit because it is a *design hypothesis*, not an implementation
        detail that the harness is allowed to hide.
        """
        if castle not in self.castles:
            return CASTLE_STATE_RUINED
        mode = VARIANT.get('castle_power_gate_mode')
        if mode is None:
            mode = 'operational' if ACTIVE_FEATURES.get('castle_identity', False) else 'owned'
        if mode == 'owned':
            return CASTLE_STATE_OPERATIONAL
        if mode != 'operational':
            raise ValueError(f"unknown castle_power_gate_mode: {mode}")
        return castle_state_for(
            self.castle_integrity.get(castle, castle_max_integrity(castle)))

    def castle_operational(self, castle: str) -> bool:
        return self.castle_state(castle) == CASTLE_STATE_OPERATIONAL

    def castle_power_active(self, castle: str) -> bool:
        """Single gate for every Castle power, including ablation masks."""
        return castle not in self.disabled_castle_powers and self.castle_operational(castle)

    def operational_castles(self) -> List[str]:
        return [c for c in self.castles if self.castle_operational(c)]

    def can_exert(self, castle: str, amount: int) -> bool:
        """Exertion may drive a Castle Defunct but may never self-Ruin it."""
        if amount <= 0 or not self.castle_operational(castle):
            return False
        cur = self.castle_integrity.get(castle, castle_max_integrity(castle))
        return (cur - amount) >= 1

    def exert(self, castle: str, amount: int, game=None, reason: str = '') -> int:
        """Single chokepoint for every Integrity self-spend. Returns amount paid
        (0 = refused). Callers MUST treat 0 as "the power did not happen"."""
        if not self.can_exert(castle, amount):
            if game is not None:
                game.stat_exert_refused += 1
            return 0
        self.castle_integrity[castle] = (
            self.castle_integrity.get(castle, castle_max_integrity(castle)) - amount)
        if game is not None:
            game.stat_exert_paid += amount
            game.stat_exert_activations += 1
            game.stat_exert_by_castle[castle] = (
                game.stat_exert_by_castle.get(castle, 0) + amount)
            if not self.castle_operational(castle):
                game.stat_exert_self_defunct += 1
                game.stat_exert_defunct_by_castle[castle] = (
                    game.stat_exert_defunct_by_castle.get(castle, 0) + 1)
        return amount

    def castle_def(self, target: str, breach: Optional[str] = None, game=None) -> int:
        d = (
            self.castle_integrity.get(target, castle_max_integrity(target))
            if ACTIVE_FEATURES['castle_integrity']
            else CASTLE_DEF.get(target, 0)
        )
        if breach == 'Deimos':
            d = max(0, d - 1)
        # Humbaba Breach — The Stones Forget: all structures soften
        if breach == 'Humbaba':
            d = max(1, d - 1)
        if VARIANT.get('castle_scarring', False):
            d = max(
                1,
                d - self.castle_scars.get(target, 0)
                * VARIANT.get('castle_scar_def', 2),
            )
        return d

    def max_castle_guards(self) -> int:
        # Humbaba — Gate Guard: a 4th slot while the stones are unbroken
        if (self.lord == 'Humbaba' and VARIANT['humbaba_gate4']
                and not self.ruined_castles):
            return 4
        return 3

    def max_lord_guards(self) -> int:
        return 3

    def all_castles_count(self) -> int:
        return len(self.castles) + len(self.ruined_castles) + len(self.profaned_castles)

    @property
    def attunement(self) -> int:
        """Attunement = personal tears. Immune to threshold N if attunement >= N."""
        return self.tears


# ═══════════════════════════════════════════════════════════════════════
#  GAME ENGINE
# ═══════════════════════════════════════════════════════════════════════
class Game:
    def __init__(self, pool0: list, pool1: list, *, seed: Optional[int] = None,
                 disabled_castle_powers: Optional[Dict[int, Iterable[str]]] = None,
                 opening_castles: Optional[Dict[int, Iterable[str]]] = None):
        self.rng = RNGStreams(seed)
        self.players = [Player(0, pool0), Player(1, pool1)]
        disabled_castle_powers = disabled_castle_powers or {}
        for _pl in self.players:
            _pl.disabled_castle_powers = set(disabled_castle_powers.get(_pl.pid, ()))
        self.opening_castles = {
            int(pid): list(castles) for pid, castles in (opening_castles or {}).items()
        }
        self.deck:    List[Card] = []
        self.discard: List[Card] = []
        self.market:  List[Card] = []
        # Physical cards consumed by effects such as Kroni's fallback remain tracked here.
        # Godot already exposes the same zone on GameState.
        self.removed_from_play: List[Card] = []
        self.breach:  Optional[str] = None
        self.breach_owner: int = -1          # pid whose banished lord fuels the Breach
        # In DE v2 this is the Reflex Bid winner; in v6.5 it is the player who
        # earned Momentum.  Both grant the same after-Resolution action.
        self.reflex_winner: Optional[int] = None

        # Optional adaptive doctrine reads its opponent's action history.  The
        # measured v6.5 bundle leaves it disabled, but its state belongs here so
        # enabling it later cannot create invisible trace drift.
        self.action_memory = [defaultdict(float), defaultdict(float)]

        # Simultaneous commitment instrument.  The old sequential mutation meant
        # p1's Ward budget could see cards already removed from p0's hand.
        self._precommit_pool_value: Optional[List[int]] = None

        self.orias_marked_lord: Optional[str] = None

        # Veil track — neutral + personal tears
        self.neutral_tears = 0
        self.first_castle_neutral_done = False  # reset each round

        # Persistent Scorch token (Kalligan Wildfire/Inferno)
        # Survives across rounds until replaced. Defeats all Guards ≤2 in
        # the affected zone at the start of each Resolution.
        self.persist_scorch_pid:  int = -1   # which player's zone
        self.persist_scorch_type: str = ''   # 'Lord' or 'Castle'
        self.persist_scorch_level: int = 1
        self._veil_drift_acc: float = 0.0

        # Kroni — destruction tracking
        self.any_destruction_this_round = False

        self.round  = 0
        self.fp     = 0
        self.winner: Optional[int] = None
        self.win_by: str = ''

        # ── Tension tracking ──────────────────────────────────────────
        self.midpoint_leader: Optional[int] = None  # pid leading at midpoint
        self.final_margin_souls: int = 0            # |winner_souls - loser_souls| at end
        self.was_comeback: bool = False             # winner was trailing at midpoint
        self.was_dominant: bool = False             # winner led from round 3 onward
        self.was_close: bool = False                # loser within 2 Souls or 1 Tear at end
        self._leader_since: int = 0                 # round winner first took lead they kept
        self.aha_moments: int = 0             # count of razor-margin plays per game
        self.aha_pre_cataclysm: int = 0       # aha moments before Cataclysm fires
        self.cataclysm_round: int = 0         # round Cataclysm threshold was crossed (0=never)

        # ── Telegraphing / fairness tracking ──────────────────────────
        # Snapshots captured at the START of each full round (before any changes).
        # Each entry: {'round': int, 'veil': int, 'souls': [p0,p1], 'tears': [p0,p1]}
        self._round_snapshots: list = []
        self.telegraphed:    bool = False  # winner was visibly threatening at final round start
        self.sudden_win:     bool = False  # winner was NOT visibly threatening
        self.path_surprise:  bool = False  # winner was behind on their eventual win-path metric
        self.warning_rounds: int  = 0      # rounds between first visible threat and win

        # Stats
        self.stat_combats           = 0
        self.stat_lords_killed      = 0
        # ── Vulture Reconnaissance telemetry ─────────────────────────
        self.stat_vulture_recon_zones = 0
        self.stat_vulture_recon_guards = 0

        # ── Castle Identity telemetry ────────────────────────────────
        # OPPORTUNITY counters are the denominator §2/§3 was missing: they
        # separate "bot chose badly" from "the window never opened".
        self.stat_exert_paid            = 0
        self.stat_exert_activations     = 0
        self.stat_exert_refused         = 0
        self.stat_exert_self_defunct    = 0
        self.stat_exert_by_castle: dict[str, int] = {}
        self.stat_exert_defunct_by_castle: dict[str, int] = {}
        self.stat_power_opportunities: dict[str, int] = {}
        self.stat_power_activations:   dict[str, int] = {}
        self.stat_power_changed_outcome: dict[str, int] = {}
        self.stat_defunct_rounds        = 0
        self.stat_power_suppressed_defunct = 0

        self.stat_castles_destroyed = 0
        self.stat_castle_damage     = 0
        self.stat_castle_repaired   = 0
        self.stat_castle_repair_actions = 0
        self.stat_repair_cards      = 0
        self.stat_repair_value      = 0
        self.stat_castles_built     = 0
        self.stat_construction_actions = 0
        self.stat_construction_value = 0
        self.stat_first_construction_round = 0
        self.stat_sieges            = 0
        self.stat_structure_first_bypasses = 0
        self.stat_momentum_triggers = 0
        self.stat_ruination_soul_bonus = 0
        self._structure_hit         = 0
        self._structure_damage      = 0
        self._structure_spill       = 0
        self.stat_ward_souls        = 0
        self.stat_ritual_souls      = 0
        self.stat_hunt_souls        = 0
        self.stat_personal_tears    = 0
        self.stat_personal_tear_sources = [defaultdict(int), defaultdict(int)]
        self.stat_neutral_tears     = 0
        self.stat_neutral_tear_sources = defaultdict(int)
        self.stat_resummons_by_player = [0, 0]  # root-economy instrumentation
        self.stat_breach_triggers   = 0
        self.stat_humbaba_tolls     = 0
        self.stat_momentum_refunded = 0
        self.stat_veil_drift = 0
        self.stat_flame_souls = 0
        self.stat_lane_scorched = 0

        # Castle instrument telemetry by physical player / castle.  These are
        # secondary outcomes: they explain *how* a power changed the game even
        # when the terminal win-rate effect is small.
        self.stat_castle_standing_rounds = [defaultdict(int), defaultdict(int)]
        self.stat_castle_power_rounds = [defaultdict(int), defaultdict(int)]
        self.stat_castle_integrity_sum = [defaultdict(int), defaultdict(int)]
        self.stat_castle_targeted = [defaultdict(int), defaultdict(int)]
        self.stat_castle_ruined_by_owner = [defaultdict(int), defaultdict(int)]

    def p(self,   pid: int) -> Player: return self.players[pid]
    def opp(self, pid: int) -> Player: return self.players[1 - pid]

    # ─────────────────────────────────────────────────────────────────
    #  VEIL TRACK
    # ─────────────────────────────────────────────────────────────────
    def _total_tears(self) -> int:
        """Full track position: neutral + all personal tears."""
        return self.neutral_tears + sum(p.tears for p in self.players)

    def _personal_tears(self) -> dict:
        return {p.pid: p.tears for p in self.players}

    def _gremory_ruinous_harvest(self):
        """Move the most-recent eligible discard card into Gremory's hand.

        Ruinous Harvest searches from the top of the discard pile toward the
        bottom and takes the first value-4-or-5 card it encounters. Removal is
        performed by index so the selected physical card and removed physical
        card are guaranteed to be the same object.
        """
        for pl in self.players:
            if (
                pl.lord != 'Gremory'
                or not pl.alive
                or pl.gremory_veil_draw_done
            ):
                continue

            # The once-per-round power is spent by the attempt, even when
            # there is no eligible value-4-or-5 card to recover.
            pl.gremory_veil_draw_done = True

            for index in range(
                len(self.discard) - 1,
                -1,
                -1,
            ):
                if self.discard[index].value < 4:
                    continue

                harvested = self.discard.pop(index)
                pl.hand.append(harvested)
                break

            # Only one Gremory can be active in a two-player game.
            break

    def _gain_tear(self, pl: Player, source: str = 'other'):
        """Place a personal Tear. Advances track and Attunement."""
        pl.tears += 1
        self.stat_personal_tears += 1
        self.stat_personal_tear_sources[pl.pid][source] += 1
        self._gremory_ruinous_harvest()

    def _gain_neutral_tear(self, source: str = 'other'):
        """Place a Neutral Tear and preserve causal source attribution."""
        self.neutral_tears += 1
        self.stat_neutral_tears += 1
        self.stat_neutral_tear_sources[source] += 1
        self._gremory_ruinous_harvest()

    def _dominion_req(self) -> int:
        """H1 — The Seal: while Humbaba stands, Dominion demands one more
        personal Tear from everyone. Suspended while he is banished."""
        req = DOMINION_REQUIREMENT
        if VARIANT['humbaba_seal'] and any(
                p.alive and p.lord == 'Humbaba' for p in self.players):
            req += 1
        return req

    def _threshold_active(self, level: int) -> bool:
        """Track has reached this threshold."""
        return self._total_tears() >= level

    def _immune_to_threshold(self, pl: Player, level: int) -> bool:
        """v5.29: Attunement grants immunity ONLY to Omen (3) and Frenzy (6).
        Collapse, The Waning, and Cataclysm affect all players."""
        if level == 3: return pl.attunement >= 3
        if level == 6: return pl.attunement >= 6
        return False

    # ─────────────────────────────────────────────────────────────────
    #  PLAN DETECTOR
    # ─────────────────────────────────────────────────────────────────
    def _plan(self, pl: Player, op: Player) -> str:
        ritual_gap_op = WIN_SOULS - op.souls
        track_total   = self._total_tears()

        if op.alive and ritual_gap_op <= 1:    return 'deny_ritual'
        if track_total >= DOMINION_TRACK - 1 and op.tears > pl.tears:
            return 'deny_dominion'
        if pl.souls > op.souls:                return 'protect_souls'
        if pl.souls < op.souls:                return 'pressure_souls'
        # Kroni at Hunger 3+ and Odradek actively race Dominion
        if pl.lord == 'Kroni' and pl.kroni_hunger >= 3 and pl.tears >= 1:
            return 'race_dominion'
        if pl.lord == 'Kroni' and op.lord == 'Humbaba' and pl.tears >= 1:
            return 'race_dominion'   # the wall cannot be eaten — outrace it
        # A1: anyone with a tear foothold races once the track is moving
        if (VARIANT['ai_dominion_drive'] and pl.tears >= 1
                and self._total_tears() >= 5 and pl.tears >= op.tears):
            return 'race_dominion'
        if pl.lord == 'Odradek' and pl.alive and pl.tears >= 1:
            return 'race_dominion'
        if pl.tears >= 2 and pl.tears > op.tears:
            return 'race_dominion'
        return 'neutral'

    # ─────────────────────────────────────────────────────────────────
    #  SIEGE TARGET
    # ─────────────────────────────────────────────────────────────────
    def _castle_strategic_value(self, owner: Player, castle: str,
                                assume_standing: bool = False) -> float:
        """Estimate how much current game leverage a Castle power supplies.

        This is intentionally rule-derived rather than a table of measured win-rate
        deltas.  The old fixed identity ladder gave Keep and Stockpile radically
        different uptime independent of board state; v7 lets both the attacker and
        owner react to what the Castle actually does *now*.
        """
        if castle in owner.disabled_castle_powers:
            return 0.0
        active = assume_standing or owner.castle_power_active(castle)
        if not active:
            return 0.0

        value = 0.25  # any live engine has some denial / future-option value
        if castle == 'Keep':
            if VARIANT.get('keep_sanctuary', False) and owner.alive:
                value += 1.00 + owner.souls / max(1.0, WIN_SOULS) * 0.35
            if VARIANT.get('keep_ignores_ward_tax', False):
                value += 0.85
        elif castle == 'Bastion':
            # Passive Lord DEF and the wall are separately testable.
            if owner.alive and int(VARIANT.get('bastion_lord_def_bonus', 2) or 0) > 0:
                value += 0.75
            if VARIANT.get('bastion_fortified', False) and len(owner.castles) > 1:
                value += 1.00
            if (VARIANT.get('bastion_fortified', False) and len(owner.castles) > 1
                    and 'Bastion' in owner.castles and 'Bastion' not in owner.disabled_castle_powers):
                value += 0.75
        elif castle == 'Stockpile':
            if VARIANT.get('stockpile_filter', False):
                value += 0.55
            if int(VARIANT.get('stockpile_tokens', 0) or 0) > 0:
                value += 0.45
            if VARIANT.get('stockpile_ignores_wright', False):
                value += 0.55
            if VARIANT.get('stockpile_depot', False):
                value += 0.30
            value += min(0.35, owner.construction_tokens * 0.05)
        elif castle == 'SummoningCircle':
            if (VARIANT.get('circle_blood_summon', False) and not owner.alive
                    and owner.can_exert('SummoningCircle', int(VARIANT.get('circle_blood_summon_cost', 3)))):
                value += 0.75
            elif int(VARIANT.get('circle_discount', 0) or 0) > 0:
                value += 0.45 if owner.alive else 0.75
            if VARIANT.get('circle_ignores_delay', False) and not owner.alive:
                value += 0.70
            if VARIANT.get('circle_blood_conduit', False) and owner.threat >= 1:
                value += 0.35
            if VARIANT.get('circle_ignores_guard_tax', False):
                value += 0.35
        elif castle == 'SiegeEngine':
            if int(VARIANT.get('attack_offsuit_penalty', 0) or 0) > 0:
                value += 0.85
            if VARIANT.get('se_breach_the_gate', False):
                value += 0.35
            if owner.lord == 'Deimos' and owner.alive:
                value += 0.75
        return value

    def _pick_siege_target(self, atk: Player, dfn: Player, *, record: bool = False) -> str:
        """Choose the intended target; Bastion interposition resolves later.

        Crucially, Fortified Bastion no longer rewrites the intended target to
        Bastion.  Doing so made the actual interposition branch unreachable and
        measured 'focus-fire this wall' rather than 'protect another engine'.
        """
        if not dfn.castles:
            raise ValueError('cannot pick Siege target from empty castle set')
        candidates = list(dfn.castles)
        # A standing Bastion physically screens rear Castles regardless of Defunct.
        # Whether it may ALSO be chosen directly is an explicit design axis. If
        # direct targeting is off, attackers choose the rear Castle they intend to
        # breach; Bastion still takes the structural damage first and can Ruin.
        _standing_bastion_screen = (
            VARIANT.get('bastion_fortified', False)
            and 'Bastion' in candidates
            and 'Bastion' not in dfn.disabled_castle_powers
            and dfn.castle_integrity.get('Bastion', 0) > 0
            and len(candidates) > 1
        )
        if _standing_bastion_screen:
            # Rules legality: Bastion MAY be targeted directly. Doctrine: with
            # shared Castle Guards/Sigil, a rear-target Siege deals the same
            # structural damage to Bastion first and preserves possible overflow,
            # so direct Bastion targeting is dominated. A human/UI may still force it.
            candidates.remove('Bastion')
        if VARIANT.get('castle_targeting_mode', 'strategic') == 'legacy':
            order = ['Stockpile', 'SummoningCircle', 'SiegeEngine', 'Bastion', 'Keep']
            chosen = next((c for c in order if c in candidates), sorted(candidates)[0])
            if record:
                self.stat_castle_targeted[dfn.pid][chosen] += 1
            return chosen

        scored = []
        for castle in sorted(candidates):
            mx = max(1, castle_max_integrity(castle))
            cur = dfn.castle_integrity.get(castle, mx)
            wounded = max(0.0, min(1.0, (mx - cur) / float(mx)))
            score = self._castle_strategic_value(dfn, castle)
            score += wounded * 1.30                 # finish a wounded engine
            if cur == mx and profane_eligible(dfn, castle):
                score += 0.20                      # a scratch can deny Profane
            if dfn.lord == 'Deimos' and dfn.alive and castle == 'SiegeEngine':
                score += 0.60                      # turn off War Machine synergy
            scored.append((score, castle))
        chosen = max(scored)[1]
        if record:
            self.stat_castle_targeted[dfn.pid][chosen] += 1
        return chosen

    # ─────────────────────────────────────────────────────────────────
    #  DRAW
    # ─────────────────────────────────────────────────────────────────
    def _draw(self, pl: Player, outside_draw: bool = False) -> bool:
        card = self._take_top_card()
        if card is None:
            return False
        if len(pl.hand) >= HAND_LIMIT:
            # Preserve the established draw ordering: recycling happens before
            # the hand-limit check, but an undrawn card stays on top.
            self.deck.append(card)
            return False
        pl.hand.append(card)

        if outside_draw:
            pl.kanifous_outside_draws += 1
            if self.breach == 'Kanifous':
                self._gain_threat(pl, 1)
                self.stat_breach_triggers += 1
        return True

    def _take_top_card(self) -> Optional[Card]:
        """Take one top-deck card through the shared recycle path.

        Development draws and the rotating Market must obey the same deck
        exhaustion rule.  Keeping it here prevents the Market from silently
        shrinking when the deck is empty but the discard pile is available.
        """
        if not self.deck:
            if not self.discard:
                return None
            self.deck = self.discard[:]
            self.discard = []
            self.rng.stream('deck').shuffle(self.deck)
        return self.deck.pop()

    def _gain_soul(self, pl: Player, n: int = 1): pl.souls += n
    def _lose_soul(self, pl: Player, n: int = 1): pl.souls = max(0, pl.souls - n)
    def _discard(self, cards: List[Card]):          self.discard.extend(cards)

    # ─────────────────────────────────────────────────────────────────
    #  VICTORY CHECK
    # ─────────────────────────────────────────────────────────────────
    def _check_win(self) -> bool:
        # Ritual victory
        for pl in self.players:
            if pl.alive and pl.souls >= WIN_SOULS:
                self.winner = pl.pid; self.win_by = 'Ritual'; return True

        track = self._total_tears()

        # Final Collapse: most Souls wins at the active profile threshold.
        if track >= FINAL_COLLAPSE_TRACK:
            best  = max(self.players, key=lambda p: p.souls)
            other = self.opp(best.pid)
            self.winner = best.pid if best.souls >= other.souls else other.pid
            self.win_by = 'FinalCollapse'
            return True

        # Dominion victory (track >= DOMINION_TRACK):
        # most personal tears AND meets requirement
        if track >= DOMINION_TRACK:
            if not self.cataclysm_round:
                self.cataclysm_round = self.round
            best  = max(self.players, key=lambda p: p.tears)
            other = self.opp(best.pid)
            if best.tears > other.tears and best.tears >= self._dominion_req():
                self.winner = best.pid; self.win_by = 'Dominion'; return True
            # No winner yet — game continues into Extended track

        return False

    # ─────────────────────────────────────────────────────────────────
    #  MAIN LOOP
    # ─────────────────────────────────────────────────────────────────
    def run(self) -> Tuple[int, str]:
        self._setup()
        self.round = 1
        self._round1()
        if self._check_win():
            self._analyse_tension()
            return self.winner, self.win_by

        # Track soul lead changes from round 3 onward
        lead_switches = 0
        last_leader: Optional[int] = None
        dominant_candidate: Optional[int] = None
        dominant_since: int = 0

        # Track midpoint snapshot — use soul snapshots each round, evaluate at end
        # Store souls at each round; midpoint = round total_rounds / 2
        soul_snapshots: list = []  # (round, souls_p0, souls_p1)

        for self.round in range(2, MAX_ROUNDS + 1):
            self._full_round()

            # Snapshot souls this round
            p0s, p1s = self.players[0].souls, self.players[1].souls
            soul_snapshots.append((self.round, p0s, p1s))

            # Track dominant lead — who leads after round 3, do they keep it?
            if self.round >= 3:
                p0, p1 = self.players
                cur_leader = 0 if p0.souls > p1.souls else (1 if p1.souls > p0.souls else None)
                if cur_leader != last_leader:
                    if cur_leader is not None:
                        dominant_candidate = cur_leader
                        dominant_since = self.round
                    lead_switches += 1
                    last_leader = cur_leader

            if self.winner is not None:
                # Determine midpoint leader from snapshots
                if soul_snapshots:
                    mid_idx = len(soul_snapshots) // 2
                    _, m0, m1 = soul_snapshots[mid_idx]
                    self.midpoint_leader = 0 if m0 > m1 else (1 if m1 > m0 else None)
                self._analyse_tension(lead_switches, dominant_candidate, dominant_since)
                return self.winner, self.win_by

        p0, p1 = self.players
        if   p0.souls != p1.souls:               w = 0 if p0.souls > p1.souls else 1
        elif len(p0.castles) != len(p1.castles): w = 0 if len(p0.castles) > len(p1.castles) else 1
        elif p0.threat != p1.threat:             w = 0 if p0.threat < p1.threat else 1
        else:                                    w = self.rng.stream('tiebreak').randint(0, 1)
        self.winner = w
        self.win_by = 'Timeout'
        if soul_snapshots:
            mid_idx = len(soul_snapshots) // 2
            _, m0, m1 = soul_snapshots[mid_idx]
            self.midpoint_leader = 0 if m0 > m1 else (1 if m1 > m0 else None)
        self._analyse_tension(lead_switches, dominant_candidate, dominant_since)
        return self.winner, self.win_by

    def _aha(self, margin: int, threshold: int = 2):
        """Register an aha moment if a play was decided by ≤threshold points."""
        if 0 < margin <= threshold:
            self.aha_moments += 1
            if not self.cataclysm_round:
                self.aha_pre_cataclysm += 1

    def _analyse_tension(self, lead_switches: int = 0,
                         dominant_candidate: Optional[int] = None,
                         dominant_since: int = 0):
        """Post-game: classify the game as comeback, dominant, or close."""
        if self.winner is None: return
        p0, p1 = self.players
        winner_pl = self.players[self.winner]
        loser_pl  = self.players[1 - self.winner]

        # Final Soul margin
        self.final_margin_souls = winner_pl.souls - loser_pl.souls

        # Aha moment: game decided by exactly 1 Soul
        if self.final_margin_souls == 1:
            self.aha_moments += 1

        # Close finish: loser within 2 Souls of winner, OR Dominion win with loser
        # holding at least 2 personal Tears
        if self.win_by == 'Ritual':
            self.was_close = self.final_margin_souls <= 2
        elif self.win_by == 'Dominion':
            self.was_close = loser_pl.tears >= 2
        else:
            self.was_close = self.final_margin_souls <= 2

        # Comeback: winner was trailing at midpoint
        if self.midpoint_leader is not None and self.midpoint_leader != self.winner:
            self.was_comeback = True

        # Dominant: winner led from round 3 or earlier and never lost lead
        if (dominant_candidate == self.winner
                and dominant_since <= 3
                and lead_switches <= 1):
            self.was_dominant = True

        # ── Telegraphing / fairness ────────────────────────────────────
        # Uses per-round snapshots taken at the START of each full round.
        if not self._round_snapshots:
            return  # round-1 insta-win — no snapshot data

        final_snap = self._round_snapshots[-1]
        w = self.winner
        l = 1 - self.winner
        w_souls = final_snap['souls'][w]
        l_souls = final_snap['souls'][l]
        w_tears = final_snap['tears'][w]
        l_tears = final_snap['tears'][l]
        veil    = final_snap['veil']

        # Was the winner visibly threatening a win at the START of the final round?
        if self.win_by == 'Ritual':
            threatening = w_souls >= WIN_SOULS - 2
            led_path    = w_souls >= l_souls
        elif self.win_by == 'Dominion':
            threatening = (w_tears >= DOMINION_REQUIREMENT - 1
                           and veil >= DOMINION_TRACK - 2)
            led_path    = w_tears >= l_tears
        else:   # FinalCollapse, Timeout — Soul majority decides
            threatening = veil >= FINAL_COLLAPSE_TRACK - 2
            led_path    = w_souls >= l_souls

        self.telegraphed   = threatening
        self.sudden_win    = not threatening
        self.path_surprise = not led_path

        # Warning rounds: how many rounds had the winner been visibly threatening?
        first_threat_round = None
        for snap in self._round_snapshots:
            sw = snap['souls'][w]
            tw = snap['tears'][w]
            v  = snap['veil']
            if self.win_by == 'Ritual':
                threat = sw >= WIN_SOULS - 2
            elif self.win_by == 'Dominion':
                threat = tw >= DOMINION_REQUIREMENT - 1 and v >= DOMINION_TRACK - 2
            else:
                threat = v >= FINAL_COLLAPSE_TRACK - 2
            if threat:
                first_threat_round = snap['round']
                break

        self.warning_rounds = (self.round - first_threat_round
                               if first_threat_round is not None else 0)

    # ─────────────────────────────────────────────────────────────────
    #  SETUP
    # ─────────────────────────────────────────────────────────────────
    def _setup(self):
        self.deck   = make_deck_2p(self.rng.stream('deck'))
        self.market = [self.deck.pop() for _ in range(MARKET_SIZE)]
        self.fp     = self.rng.stream('setup').randint(0, 1)
        for pl in self.players:
            if pl.pid in self.opening_castles:
                selected = list(self.opening_castles[pl.pid])
            elif ACTIVE_FEATURES['castle_integrity'] and VARIANT.get('castle_loadout', False):
                opening_count = int(VARIANT.get('starting_castles', 3))
                selected = CASTLE_PRIORITIES.get(pl.lord, CASTLES)[:opening_count]
            else:
                selected = list(CASTLES)
            for c in selected:
                pl.castles.add(c)
                if ACTIVE_FEATURES['castle_integrity']:
                    pl.castle_integrity[c] = castle_max_integrity(c)
            for _ in range(5):
                self._draw(pl)
        # Pre-game: both players summon their opening Lord
        for pl in self.players:
            self._ai_summon(pl, forced=True)

    def _round1(self):
        # Round 1 is a full round with the Reflex Bid skipped (v5.29).
        self._full_round(allow_reflex=False)

    # ─────────────────────────────────────────────────────────────────
    #  FULL ROUND
    # ─────────────────────────────────────────────────────────────────
    def _record_castle_round_telemetry(self):
        for pl in self.players:
            for castle in CASTLES:
                if castle not in pl.castles:
                    continue
                self.stat_castle_standing_rounds[pl.pid][castle] += 1
                self.stat_castle_integrity_sum[pl.pid][castle] += pl.castle_integrity.get(
                    castle, castle_max_integrity(castle))
                if pl.castle_power_active(castle):
                    self.stat_castle_power_rounds[pl.pid][castle] += 1

    def _full_round(self, allow_reflex: bool = True):
        self._record_castle_round_telemetry()
        # Snapshot board state BEFORE anything changes this round.
        # Used by _analyse_tension for telegraphing/fairness metrics.
        self._round_snapshots.append({
            'round': self.round,
            'veil':  self._total_tears(),
            'souls': [pl.souls for pl in self.players],
            'tears': [pl.tears for pl in self.players],
        })

        self.any_destruction_this_round  = False
        self.first_castle_neutral_done   = False   # reset per-round Neutral Tear gate
        self.reflex_winner = None
        for pl in self.players:
            pl.reset_round()

        self._phase_development()
        if self._check_win(): return

        if allow_reflex and VARIANT.get('reflex_bid', True):
            self._phase_reflex_bid()

        self._phase_commitment()
        order = self._resolve_order()
        self._phase_reveal(order)
        self._phase_resolution(order)
        self._march_advance()

        if VARIANT.get('adaptive_doctrine', False):
            for pid, player in enumerate(self.players):
                memory = self.action_memory[pid]
                for action in list(memory):
                    memory[action] *= ADAPT_DECAY
                if player.action in ('Hunt', 'Siege'):
                    memory[player.action] = min(
                        ADAPT_CAP,
                        memory[player.action] + 1.0,
                    )

    # ─────────────────────────────────────────────────────────────────
    #  PHASE: DEVELOPMENT  (v5.29 order: Sigil Update → Veil → Draw →
    #  Market → Repair → Dominion Rites → Deploy → Summon)
    # ─────────────────────────────────────────────────────────────────
    def _phase_development(self):
        # Sigil Update — per zone: Flipped → Removed, Fresh → Flipped
        # (Humbaba H4 — Patient Hunger: a passive round preserves his best
        #  Sigil from decay this update.)
        for pl in self.players:
            preserve = ''
            if pl.humbaba_patient:
                pl.humbaba_patient = False
                if   pl.sigils['Lord'] == 'fresh':     preserve = 'Lord'
                elif pl.sigils['Castle'] == 'fresh':   preserve = 'Castle'
                elif pl.sigils['Lord'] == 'flipped':   preserve = 'Lord'
                elif pl.sigils['Castle'] == 'flipped': preserve = 'Castle'
            for zone in ('Lord', 'Castle'):
                if zone == preserve: continue
                if   pl.sigils[zone] == 'flipped': pl.sigils[zone] = ''
                elif pl.sigils[zone] == 'fresh':   pl.sigils[zone] = 'flipped'

        # (Veil Check is passive — thresholds are queried live.)

        # D5: the Veil frays on its own every N rounds
        if VARIANT['veil_drift'] and self.round > 1 and \
                self.round % VARIANT['veil_drift'] == 0:
            self._gain_neutral_tear('veil_drift_fixed')
            if self._check_win(): return

        # Start-of-Development abilities
        for pl in self.players:
            if pl.lord == 'Orias' and pl.alive:
                self._ai_orias_snare(pl)

        # Gremory — Picking the Bones
        for pl in self.players:
            if pl.lord == 'Gremory' and pl.alive:
                op = self.opp(pl.pid)
                draw_count = 1                              # always draw 1
                if pl.ruined_castles or op.ruined_castles:  # +1 if any ruins on board
                    draw_count += 1
                if pl.ruined_castles:                       # +1 if Gremory herself has ruins
                    draw_count += 1
                for _ in range(draw_count):
                    self._draw(pl, outside_draw=True)

        # Gremory Breach — Sifting the Ruins
        if self.breach == 'Gremory':
            for pl in self.players:
                if pl.ruined_castles:
                    self._draw(pl, outside_draw=True)
                    self.stat_breach_triggers += 1

        # Draw Step
        for pl in self.players:
            self._run_draw_step(pl)

        # Market
        self._refresh_market_offers()
        for offset in range(2):
            self._ai_market(self.players[(self.fp + offset) % 2])

        # Repair (before Deploy — the no-token repair restriction now bites)
        for pl in self.players:
            # Stockpile — the Yard: generates Construction tokens each round.
            # Bankable, spent IN ADDITION to a normal Castle action — they add
            # value, they do not grant an extra action. They are not cards, so
            # they never satisfy the Wright requirement on their own.
            if pl.castle_power_active('Stockpile'):
                _t = int(VARIANT.get('stockpile_tokens', 0) or 0)
                if _t > 0:
                    _cap = int(VARIANT.get('stockpile_token_cap', 0) or 0)
                    pl.construction_tokens += _t
                    if _cap > 0:
                        pl.construction_tokens = min(pl.construction_tokens, _cap)
                    _kit('tokens_generated', _t)
            self._ai_repair_only(pl)

            # Stockpile — Reinforce: a material with nothing to build becomes
            # temporary wall. Integrity above the printed max is NOT restored by
            # Repair (which heals only to max), so reinforcement is spent once
            # and gone. It keeps the token from ever being wasted.
            if (pl.construction_tokens > 0 and pl.castle_power_active('Stockpile')):
                _rc = int(VARIANT.get('reinforce_cap', 0) or 0)
                if _rc > 0:
                    for _c in sorted(
                            pl.castles,
                            key=lambda c: -pl.castle_integrity.get(
                                c, castle_max_integrity(c))):
                        if pl.construction_tokens <= 0:
                            break
                        _mx = castle_max_integrity(_c) + _rc
                        _cur = pl.castle_integrity.get(_c, castle_max_integrity(_c))
                        _room = _mx - _cur
                        if _room <= 0:
                            continue
                        _add = min(pl.construction_tokens, _room)
                        pl.castle_integrity[_c] = _cur + _add
                        pl.construction_tokens -= _add
                        _kit('tokens_spent_reinforce', _add)

            # Stockpile — Depot: Exert for a SECOND Repair/Construct action.
            if (VARIANT.get('stockpile_depot', False)
                    and pl.castle_action_used_this_round
                    and pl.castle_power_active('Stockpile')):
                _kit('depot_opportunity')
                _c = int(VARIANT.get('stockpile_depot_cost', 2))
                if pl.can_exert('Stockpile', _c):
                    pl.exert('Stockpile', _c, game=self, reason='depot')
                    _kit('depot_activation'); _kit('depot_integrity_spent', _c)
                    pl.castle_action_used_this_round = False
                    self._ai_repair_only(pl)
                else:
                    _kit('depot_short')

        # Dominion Rites (Development-phase rites)
        for pl in self.players:
            self._ai_dominion_rites(pl)
        if self._check_win(): return

        # Deploy
        for pl in self.players:
            self._deploy_guards(pl)

        # Summon
        for pl in self.players:
            if not pl.alive:
                self._ai_summon(pl, forced=False)

    def _ai_orias_snare(self, pl: Player):
        if pl.threat >= 3: return
        op = self.opp(pl.pid)
        if len(op.garrison) + len(op.hand) < 2: return
        self._gain_threat(pl, 1)
        op.orias_snare_active = True

    # ─────────────────────────────────────────────────────────────────
    #  DOMINION RITES (Development)
    # ─────────────────────────────────────────────────────────────────
    def _ai_dominion_rites(self, pl: Player):
        op = self.opp(pl.pid)
        plan = self._plan(pl, op)

        # Cataclysmic Invocation — once per game; Veil must ALREADY be ≥7;
        # discard cards totalling ≥11 from hand.
        if ((VARIANT['invocation_repeatable'] or not pl.cataclysmic_used)
                and self._total_tears() >= VARIANT['invocation_gate']
                and sum(c.value for c in pl.hand) >= 11):
            soul_deficit = op.souls - pl.souls
            wants = (plan in ('race_dominion', 'deny_dominion')
                     or (soul_deficit >= 3 and pl.tears + 1 >= DOMINION_REQUIREMENT - 1))
            if wants:
                # Pay with largest cards first to minimise count
                pay = []
                total = 0
                for c in sorted(pl.hand, key=lambda c: c.value, reverse=True):
                    if total >= 11: break
                    pay.append(c); total += c.value
                # Only fire if a usable hand remains afterwards (or we win the race)
                if total >= 11 and (len(pl.hand) - len(pay) >= 2
                                    or pl.tears + 1 >= DOMINION_REQUIREMENT):
                    for c in pay: pl.hand.remove(c)
                    self._discard(pay)
                    pl.cataclysmic_used = True
                    self._gain_tear(pl, 'cataclysmic_invocation')
                    if self._check_win(): return

        # Profane the Ruins — once per round; requires the configured Ruined
        # Castle count and, in the current lab, discards >=5 Hand value.
        profane_cost = int(VARIANT.get('profane_ruins_cost', 0))
        if (not pl.profane_ruins_used_this_round
                and len(pl.ruined_castles) >= VARIANT['profane_ruins_req']
                and sum(c.value for c in pl.hand) >= profane_cost
                and (plan in ('race_dominion', 'deny_dominion') or pl.tears >= 1)):
            priority = CASTLE_PRIORITIES.get(pl.lord, CASTLES)
            target = next((c for c in reversed(priority) if c in pl.ruined_castles), None)
            if target:
                pay = []
                total = 0
                for c in sorted(pl.hand, key=lambda c: c.value, reverse=True):
                    if total >= profane_cost:
                        break
                    pay.append(c)
                    total += c.value

                if total >= profane_cost:
                    for c in pay:
                        pl.hand.remove(c)
                    self._discard(pay)
                    pl.ruined_castles.discard(target)
                    pl.profaned_castles.add(target)
                    pl.profane_ruins_used_this_round = True
                    self._gain_tear(pl, 'profane_the_ruins')
                    if self._check_win(): return

    # ─────────────────────────────────────────────────────────────────
    #  REFLEX BID (v5.29)
    #  Tie → all bid cards return to hand, no Reflex action.
    #  Winner → each player retrieves their single lowest bid card;
    #  winner discards the rest; loser sends the rest to Garrison.
    #  Winner gains an optional second action after Resolution.
    # ─────────────────────────────────────────────────────────────────
    def _phase_reflex_bid(self):
        bids = [self._ai_bid(pl) for pl in self.players]
        vals = [sum(c.value for c in b) for b in bids]

        if vals[0] == vals[1]:
            # Tie (including both passing): everything returns to hand
            for i, pl in enumerate(self.players):
                pl.hand.extend(bids[i])
            self.reflex_winner = None
            return

        winner = 0 if vals[0] > vals[1] else 1
        self.reflex_winner = winner

        # Aha moment: bid margin ≤ 2 (one card decided tempo)
        self._aha(abs(vals[0] - vals[1]), threshold=2)

        for i, pl in enumerate(self.players):
            bid = bids[i]
            if not bid:
                continue
            # Retrieve the single lowest bid card
            lowest = min(bid, key=lambda c: c.value)
            bid.remove(lowest)
            pl.hand.append(lowest)
            if i == winner:
                self._discard(bid)
            else:
                space = GARRISON_MAX - len(pl.garrison)
                pl.garrison.extend(bid[:space])
                self._discard(bid[space:])

    # ─────────────────────────────────────────────────────────────────
    #  COMMITMENT / REVEAL / ORDER
    # ─────────────────────────────────────────────────────────────────
    def _phase_commitment(self):
        # Decisions are still applied one player at a time, but every doctrine
        # read of the opponent's hidden card pool uses this immutable precommit
        # snapshot.  Per-player RNG streams additionally prevent p0's branch
        # count from changing p1's policy noise.
        self._precommit_pool_value = [
            sum(card.value for card in pl.hand + pl.garrison)
            for pl in self.players
        ]
        try:
            for pl in self.players:
                self._ai_choose_action(pl)
        finally:
            self._precommit_pool_value = None

    @staticmethod
    def _unknown_guard_count(guards: List[Card]) -> int:
        return sum(1 for card in guards if not getattr(card, 'guard_revealed', False))

    def _choose_vulture_recon_zone(self, pl: Player, op: Player) -> Optional[str]:
        """Choose the most useful enemy Guard area to scout.

        Hunt naturally reveals Lord Guards and Siege naturally reveals Castle
        Guards, so Reconnaissance prefers the other area. Ward/Profane scout
        whichever zone still contains more unknown cards.
        """
        unknown = {
            'Lord': self._unknown_guard_count(op.lord_guards),
            'Castle': self._unknown_guard_count(op.castle_guards),
        }
        if unknown['Lord'] <= 0 and unknown['Castle'] <= 0:
            return None

        if pl.action == 'Hunt':
            preferred, fallback = 'Castle', 'Lord'
        elif pl.action == 'Siege':
            preferred, fallback = 'Lord', 'Castle'
        else:
            if unknown['Castle'] > unknown['Lord']:
                preferred, fallback = 'Castle', 'Lord'
            else:
                preferred, fallback = 'Lord', 'Castle'

        if unknown[preferred] > 0:
            return preferred
        if unknown[fallback] > 0:
            return fallback
        return None

    def _reveal_guard_zone(self, defender: Player, zone: str) -> int:
        guards = defender.lord_guards if zone == 'Lord' else defender.castle_guards
        newly = 0
        for card in guards:
            if not getattr(card, 'guard_revealed', False):
                card.guard_revealed = True
                newly += 1
        if newly:
            self.stat_vulture_recon_zones += 1
            self.stat_vulture_recon_guards += newly
        return newly

    def _resolve_vulture_recon(self, pl: Player) -> Optional[str]:
        if not any(card.suit == 'Vulture' for card in pl.committed):
            return None
        op = self.opp(pl.pid)
        zone = self._choose_vulture_recon_zone(pl, op)
        if zone is None:
            return None
        self._reveal_guard_zone(op, zone)
        return zone

    def _phase_reveal(self, trigger_order: Optional[List[int]] = None):
        for pl in self.players:
            if pl.action == 'Hunt':
                self._gain_threat(pl, 1)

        # Register Wards.  DE v2 uses the Sigil Contest; v6.5 keeps the same
        # short-lived visual marker but makes a correctly-funded Ward turn the
        # matching attack instead of merely adding a thin defensive layer.
        for pl in self.players:
            if pl.action == 'Ward':
                zone = pl.ward_target
                op   = self.opp(pl.pid)
                contested = ((op.action == 'Hunt'  and zone == 'Lord') or
                             (op.action == 'Siege' and zone == 'Castle'))

                # The same value is used by the reveal contest and by the actual
                # front-line reinforcement layer in combat.
                ward_strength = pl.ward_reinforcement_value()

                if VARIANT.get('sigil_flat', False):
                    pl.sigils[zone] = 'fresh'
                elif contested and op.committed_value() > ward_strength:
                    pl.sigils[zone] = 'flipped'
                else:
                    pl.sigils[zone] = 'fresh'

                if (VARIANT.get('ward_threshold', False)
                        and not VARIANT.get('ward_frontline', False)
                        and contested
                        and ward_strength >= op.committed_value()):
                    pl.ward_turned.add(zone)

                # With Reflex retired, an uncontested ward is the renewable
                # universal feed into Garrison.  Only the lowest committed card
                # returns; the rest remains spent in normal aftermath.
                if (VARIANT.get('ward_garrison_refund', False)
                        and not contested
                        and pl.committed
                        and len(pl.garrison) < GARRISON_MAX):
                    lowest = min(pl.committed, key=lambda card: card.value)
                    pl.committed.remove(lowest)
                    pl.garrison.append(lowest)

                # Sigil Lord on own zone: reduce Threat by 1 (min 0)
                if zone == 'Lord':
                    pl.threat = max(0, pl.threat - 1)

        # Vulture — Reconnaissance. One or more committed Vultures reveal
        # one entire enemy Guard area after Reveal. Attacks prefer scouting the
        # opposite area because the attacked Guard area will reveal in combat.
        if VARIANT.get('vulture_recon', False):
            for pl in self.players:
                self._resolve_vulture_recon(pl)

        # After-Reveal Lord powers resolve in the committed-value order
        # locked before any of them can strip committed cards.
        if trigger_order is None:
            trigger_order = self._resolve_order()

        for pid in trigger_order:
            pl = self.players[pid]
            op = self.opp(pid)

            if pl.lord == 'Kanifous' and pl.alive:
                self._kanifous_invoke(pl)

            if pl.lord == 'Kroni' and pl.alive and pl.kroni_hunger >= 3:
                if op.committed:
                    victim = min(op.committed, key=lambda c: c.value)
                    op.committed.remove(victim)
                    self._discard([victim])

            # Psychic Recoil belongs to the defending Odradek, so its place
            # in the trigger queue is determined by Odradek's committed value.
            attacked_by_hunt = (
                op.action == 'Hunt'
                and op.tgt_pid == pl.pid
            )
            attacked_by_siege = (
                op.action == 'Siege'
                and op.tgt_pid == pl.pid
                and not VARIANT['recoil_hunts_only']
            )
            orias_clean_hunt = (
                attacked_by_hunt
                and op.lord == 'Orias'
                and self.orias_marked_lord == pl.lord
            )

            if (
                pl.lord == 'Odradek'
                and pl.alive
                and not pl.odradek_recoil_done
                and (attacked_by_hunt or attacked_by_siege)
                and not orias_clean_hunt
            ):
                self._odradek_recoil(op, pl)

    # ═══════════════════════════════════════════════════════════════════
    #  ODRADEK INTERLOCK — the ONLY Psychic Recoil implementation.
    #
    #  Pre-patch there were three copies: the after-Reveal path plus separate
    #  remove-and-discard copies inside the Hunt and Siege resolvers. Because
    #  `odradek_recoil_done` is shared and per-round, the resolver copies fired
    #  only when the primary action did not attack Odradek but a Momentum second
    #  action did. Low frequency, two different mechanics, one build.
    #
    #  Callers are responsible for confirming: Odradek is the defender, is alive,
    #  was targeted by this Hunt/Siege, and that Orias's clean Marked Prey Hunt
    #  does not suppress it. The helper owns everything else.
    # ═══════════════════════════════════════════════════════════════════
    def _odradek_recoil(self, atk, dfn) -> dict:
        """Resolve one Psychic Recoil. Returns a result dict for narration."""
        res = dict(fired=False, taken_card=None, bank_before=None, bank_after=None,
                   replaced_card=None, locked=False, soul_gain=0)
        if not VARIANT.get('odr_recoil', True):        return res
        if dfn.odradek_recoil_done:                    return res

        # Recoil is SPENT for the round even if the Interlock blocks the steal.
        dfn.odradek_recoil_done = True
        res['fired'] = True
        bank = getattr(dfn, 'odradek_bank', None)
        res['bank_before'] = bank
        res['bank_after'] = bank
        if not atk.committed:                          return res

        # Selection: second-highest committed card. One card -> that card.
        # sorted() is stable, so equal values resolve by committed order.
        if VARIANT['recoil_lowest']:
            victim = min(atk.committed, key=lambda c: c.value)
        else:
            ordered = sorted(atk.committed, key=lambda c: c.value, reverse=True)
            victim = ordered[1] if len(ordered) > 1 else ordered[0]

        if not VARIANT.get('odr_recoil_strip', True):
            if VARIANT.get('odr_recoil_soul', True):
                self._gain_soul(dfn, 1); res['soul_gain'] = 1
            return res

        if VARIANT['odr_recoil_bank']:
            if bank is not None:
                if victim.value <= bank.value:
                    res['locked'] = True               # no card moves, no Soul
                    return res
                self._discard([bank])
                res['replaced_card'] = bank
                dfn.odradek_bank = None
            atk.committed.remove(victim)
            dfn.odradek_bank = victim
            res['bank_after'] = victim
        else:
            atk.committed.remove(victim)
            self._discard([victim])

        res['taken_card'] = victim
        if VARIANT.get('odr_recoil_soul', True):
            self._gain_soul(dfn, 1); res['soul_gain'] = 1
        return res

    def _odradek_spend_bank(self, pl, committed: list):
        """Attacking spends the bank: the physical card joins the commitment.

        The banked card becomes an ordinary committed card — its value counts
        toward strength and resolution order, its suit toward suit bonuses, it
        can be stripped or returned, and it goes through normal cleanup.
        Ward and Profane do NOT spend it. Primary and Momentum attacks both do.
        """
        if not VARIANT['odr_recoil_bank']: return None
        if pl.lord != 'Odradek':           return None
        bank = getattr(pl, 'odradek_bank', None)
        if bank is None:                   return None
        committed.append(bank)
        pl.odradek_bank = None
        self.stat_bank_spent = getattr(self, 'stat_bank_spent', 0) + 1
        return bank

    def _odradek_discard_bank(self, pl, reason: str = ''):
        """Leaving play discards the bank. Reconfiguration tokens are unaffected."""
        if not VARIANT['odr_recoil_bank']: return None
        bank = getattr(pl, 'odradek_bank', None)
        if bank is None:                   return None
        self._discard([bank])
        pl.odradek_bank = None
        return bank

    def _apply_momentum_refund(self, pl: Player) -> List[Card]:
        due = min(pl.momentum_refund_due, len(pl.committed))
        refunded = sorted(pl.committed, key=lambda c: c.value, reverse=True)[:due]
        for card in refunded:
            pl.committed.remove(card)
            if len(pl.hand) < HAND_LIMIT:
                pl.hand.append(card)
            else:
                self._discard([card])
        pl.momentum_refund_due = 0
        self.stat_momentum_refunded += len(refunded)
        return refunded

    def _apply_graduated_veil_drift(self) -> int:
        if not (ACTIVE_FEATURES['veil_drift_rate']
                or ACTIVE_FEATURES['veil_drift_growth']):
            return 0
        after = ACTIVE_FEATURES['veil_drift_after']
        if self.round <= after:
            return 0
        rate = ACTIVE_FEATURES['veil_drift_rate']
        rate += ACTIVE_FEATURES['veil_drift_growth'] * (self.round - after - 1)
        self._veil_drift_acc += rate
        tears = 0
        while self._veil_drift_acc >= 1.0:
            self._veil_drift_acc -= 1.0
            self._gain_neutral_tear('veil_drift_growth')
            tears += 1
        self.stat_veil_drift += tears
        return tears

    def _apply_kalligan_flame_income(self) -> int:
        if (not ACTIVE_FEATURES['kal_flame_tokens']
                or self.persist_scorch_pid < 0
                or not self.persist_scorch_type):
            return 0
        rate = (self.persist_scorch_level
                if ACTIVE_FEATURES['kal_scorch_escalate'] else 1)
        souls = 0
        for pl in self.players:
            if (pl.lord != 'Kalligan' or not pl.alive
                    or pl.pid == self.persist_scorch_pid):
                continue
            pl.kalligan_flame_tokens += rate
            per_soul = max(1, ACTIVE_FEATURES['kal_flame_per_soul'])
            while pl.kalligan_flame_tokens >= per_soul:
                pl.kalligan_flame_tokens -= per_soul
                self._gain_soul(pl, 1)
                souls += 1
        self.stat_flame_souls += souls
        return souls

    def _resolve_order(self) -> List[int]:
        """v5.29: higher committed Subject value resolves first.
        Equal values resolve simultaneously (approximated sequentially;
        both actions still fully resolve)."""
        v0 = self.players[0].committed_value()
        v1 = self.players[1].committed_value()
        if v0 > v1: return [0, 1]
        if v1 > v0: return [1, 0]
        first = self.rng.stream('resolution').randint(0, 1)
        return [first, 1 - first]

    # ─────────────────────────────────────────────────────────────────
    #  PHASE: RESOLUTION
    # ─────────────────────────────────────────────────────────────────
    def _phase_resolution(self, order: List[int]):
        # ── Kalligan — Persistent Scorch Token (Wildfire/Inferno)
        # Defeats all Guards ≤2 in the affected zone at start of each Resolution.
        if self.persist_scorch_pid >= 0 and self.persist_scorch_type:
            target_pl = self.players[self.persist_scorch_pid]
            threshold = (self.persist_scorch_level
                         if ACTIVE_FEATURES['kal_scorch_escalate'] else 2)
            if self.persist_scorch_type == 'Lord':
                victims = [g for g in target_pl.lord_guards if g.value <= threshold]
                for v in victims:
                    target_pl.lord_guards.remove(v)
                self._discard(victims)
                if victims:
                    if target_pl.lord == 'Odradek':
                        target_pl.odradek_guards_defeated += len(victims)
                    self._gremory_lord_guard_trigger()  # Predator of Ruin
            elif self.persist_scorch_type == 'Castle':
                victims = [g for g in target_pl.castle_guards if g.value <= threshold]
                for v in victims:
                    target_pl.castle_guards.remove(v)
                self._discard(victims)
                if victims and target_pl.lord == 'Odradek':
                    target_pl.odradek_guards_defeated += len(victims)

            if ACTIVE_FEATURES['kal_scorch_escalate']:
                self.persist_scorch_level = min(
                    ACTIVE_FEATURES['kal_scorch_cap'],
                    self.persist_scorch_level + 1,
                )

            if ACTIVE_FEATURES['kal_lane_scorch']:
                burned = [
                    marcher for marcher in target_pl.marchers
                    if marcher['lane'] == self.persist_scorch_type
                    and marcher['value'] <= ACTIVE_FEATURES['kal_lane_scorch_thresh']
                ]
                for marcher in burned:
                    target_pl.marchers.remove(marcher)
                    self._discard([marcher['card']])
                    self.stat_lane_scorched += 1
        # ── Veil Tear 7 — Collapse: discard 1 Guard from attacked zone last round
        # No Attunement immunity — affects all players
        if self._threshold_active(7):
            for pl in self.players:
                if pl.was_lord_attacked_prev and pl.lord_guards:
                    victim = min(pl.lord_guards, key=lambda g: g.value)
                    pl.lord_guards.remove(victim)
                    self._discard([victim])
                elif pl.was_castle_attacked_prev and pl.castle_guards:
                    victim = min(pl.castle_guards, key=lambda g: g.value)
                    pl.castle_guards.remove(victim)
                    self._discard([victim])

        # ── Valak Breach OR Veil 9 (The Waning — stacks with Collapse):
        # discard Guard from attacked zone. Both may apply (2 discards).
        for pl in self.players:
            self._apply_collapse_effect(pl, from_breach=(self.breach == 'Valak'),
                                         from_veil=self._threshold_active(9))

        # ── Humbaba — The Toll (H2): once per round, ruin one of his own
        # castles -> opponent loses 1 Soul, place 1 Neutral Tear.
        # Fires pre-combat so it can brake a lethal Ritual turn. Self-punishing:
        # the ruin drops his castle-tied defense and breaks the Gate Guard NOW.
        if VARIANT['humbaba_toll']:
            for pl in self.players:
                if pl.lord != 'Humbaba' or not pl.alive or not pl.castles:
                    continue
                if len(pl.castles) < 2:
                    continue    # never burn the last stone
                op = self.opp(pl.pid)
                total_after = self._total_tears() + 1
                # Don't hand a tear-racer the Cataclysm
                feeds_racer = (op.tears > pl.tears
                               and total_after >= DOMINION_TRACK - 3)
                emergency = op.souls >= WIN_SOULS - 2
                pressure  = (op.souls - pl.souls >= 3 and op.souls >= 4)
                if (emergency or pressure) and not feeds_racer and op.souls > 0:
                    priority = CASTLE_PRIORITIES.get('Humbaba', CASTLES)
                    target = next((c for c in reversed(priority) if c in pl.castles),
                                  next(iter(pl.castles)))
                    pl.castles.discard(target)
                    pl.ruined_castles.add(target)
                    if ACTIVE_FEATURES['castle_integrity']:
                        pl.castle_integrity[target] = 0
                    self._lose_soul(op, 1)
                    self._gain_neutral_tear('humbaba_toll')
                    self.stat_humbaba_tolls += 1
                    # Gate Guard broke — trim the 4th slot immediately
                    while len(pl.castle_guards) > pl.max_castle_guards():
                        victim = min(pl.castle_guards, key=lambda g: g.value)
                        pl.castle_guards.remove(victim)
                        space = GARRISON_MAX - len(pl.garrison)
                        if space > 0: pl.garrison.append(victim)
                        else: self._discard([victim])
                    if self._check_win(): return

        for pid in order:
            if self.winner is not None: return
            pl = self.players[pid]
            op = self.opp(pid)

            if   pl.action == 'Ward':    pass
            elif pl.action == 'Hunt':    self._resolve_hunt(pl, op)
            elif pl.action == 'Siege':   self._resolve_siege(pl, op)
            elif pl.action == 'Profane': self._resolve_profane(pl, op)

            # Offer the Vessel — once per game, during Resolution
            self._ai_offer_vessel(pl)
            if self._check_win(): return

            # Vulture suit bonus
            if pl.suit_count('Vulture') >= 2:
                self._draw(pl, outside_draw=True)

            # Wright suit bonus: gain 1 Repair token (max 1, persists to next Development)
            if pl.suit_count('Wright') >= 2:
                pl.repair_token = 1  # capped at 1 — no stockpiling

            self._apply_momentum_refund(pl)

            # DO NOT clean committed cards here. A Ward may resolve earlier in
            # initiative order than the attack it reinforces; its cards must stay
            # on the battlefield until both primary actions have resolved.
            if self._check_win(): return

        # Ward reinforcements (and every other primary commitment) leave only
        # after the primary battle phase is complete.
        for pl in self.players:
            self._discard(pl.committed)
            pl.committed = []

        # ── REFLEX ACTION — bid winner's optional second action (v5.29).
        # Resolves after all committed actions, before End-of-Round effects.
        if self.reflex_winner is not None and self.winner is None:
            self._resolve_reflex_action(self.reflex_winner)
            if self.winner is not None: return

        # Consume evaluates once, after every primary and Reflex action, so
        # Gorge sees the complete round and no later destruction is missed.
        for pid in order:
            self._try_kroni_consume(self.players[pid])

        # K1: Hunger decays when Kroni initiates no attack this round
        if VARIANT['kroni_hunger_decay']:
            for pl in self.players:
                if (pl.lord == 'Kroni' and pl.alive
                        and pl.action not in ('Hunt', 'Siege')):
                    pl.kroni_hunger = max(0, pl.kroni_hunger - 1)

        # Kroni end-of-round fallback Consume. The lab keeps the compulsory
        # self-consumption but removes its free Hunger payout.
        for pl in self.players:
            self._try_kroni_fallback(pl)

        self._apply_graduated_veil_drift()
        self._apply_kalligan_flame_income()

        # Kroni Breach — Insatiable Hunger
        if self.breach == 'Kroni':
            for pl in self.players:
                all_guards = pl.lord_guards + pl.castle_guards
                if all_guards:
                    victim = min(all_guards, key=lambda g: g.value)
                    if victim in pl.lord_guards:     pl.lord_guards.remove(victim)
                    elif victim in pl.castle_guards:
                        pl.castle_guards.remove(victim)
                    self._discard([victim])
                    self.stat_breach_triggers += 1

        # Odradek — Reconfiguration (Passive)
        # If fewer than 2 Guards were defeated from Odradek's zones this round,
        # gain 1 token. At 3 tokens → 1 personal Tear.
        # Opponent must defeat 2+ guards (any zones, Hunt or Siege) to block the token.
        # One guard strip is no longer enough — sustained pressure required.
        for pl in self.players:
            if pl.lord == 'Odradek' and pl.alive:
                if pl.odradek_guards_defeated < (1 if VARIANT['reconfig_strict'] else 2):
                    pl.odradek_reconfig_tokens += 1
                    if pl.odradek_reconfig_tokens >= VARIANT['reconfig_tokens_needed']:
                        pl.odradek_reconfig_tokens -= VARIANT['reconfig_tokens_needed']
                        if VARIANT['reconfig_neutral']:
                            self._gain_neutral_tear('odradek_reconfiguration')
                        else:
                            self._gain_tear(pl)
                        if self._check_win(): return

        for pl in self.players:
            pl.prev_ward_target = pl.ward_target if pl.action == 'Ward' else ''
            pl.consecutive_wards = (pl.consecutive_wards + 1
                                    if pl.action == 'Ward' else 0)
            if pl.lord == 'Humbaba' and pl.alive and VARIANT['humbaba_patient']:
                pl.humbaba_patient = pl.action not in ('Hunt', 'Siege')

        # Gremory — Inevitable Ruin (Active, once per round, after Resolution)
        # Discard 2 cards → the Castle that was attacked (Sieged) this round
        # becomes Ruined. No Souls awarded. Neutral Tear and Predator of Ruin
        # fire normally.
        for pl in self.players:
            if pl.lord == 'Gremory' and pl.alive and not pl.gremory_inevitable_ruin_done:
                op = self.opp(pl.pid)
                # Gate: the castle Sieged this round must have survived
                target = op.last_sieged_castle
                if not (op.was_sieged and target and target in op.castles):
                    continue
                # Cost: 2 cards from hand + garrison combined
                cost = 2
                available = sorted(pl.hand + pl.garrison, key=lambda c: c.value)
                if len(available) < cost:
                    continue
                # AI judgment: only fire if hand is healthy enough (keep at least 2 after)
                if len(pl.hand) + len(pl.garrison) < cost + 2:
                    continue
                # Pay 2 lowest cards
                to_discard = available[:cost]
                for c in to_discard:
                    if c in pl.hand:       pl.hand.remove(c)
                    elif c in pl.garrison: pl.garrison.remove(c)
                self._discard(to_discard)
                pl.gremory_inevitable_ruin_done = True
                op.castles.discard(target)
                op.ruined_castles.add(target)
                if ACTIVE_FEATURES['castle_integrity']:
                    op.castle_integrity[target] = 0
                self.stat_castles_destroyed += 1
                self.any_destruction_this_round = True
                # Neutral Tear: first castle destroyed this round (D4: every)
                if VARIANT['castle_tear_uncapped'] or not self.first_castle_neutral_done:
                    self._gain_neutral_tear('castle_inevitable_ruin')
                    self.first_castle_neutral_done = True
                # Predator of Ruin: Gremory herself triggered it — fire if not already done
                if not pl.gremory_ruin_done and self.discard:
                    pl.hand.append(self.discard[-1])
                    self.discard.pop()
                    pl.gremory_ruin_done = True
                if self._check_win(): return

        # Kanifous Penitent cleanup
        for pl in self.players:
            temp = getattr(pl, 'penitent_temp_guards', [])
            for g in temp:
                if g in pl.lord_guards:
                    pl.lord_guards.remove(g)
                    self._discard([g])
                elif g in pl.castle_guards:
                    pl.castle_guards.remove(g)
                    self._discard([g])
            pl.penitent_temp_guards = []

        # Profane — Tear lands at the END of Resolution (v5.29)
        for pl in self.players:
            if pl.pending_profane:
                pl.pending_profane = ''
                self._gain_tear(pl, 'profane_action')
                if self._check_win(): return

    # ─────────────────────────────────────────────────────────────────
    #  PROFANE (Commitment action: Siege + own color)
    # ─────────────────────────────────────────────────────────────────
    def _resolve_profane(self, pl: Player, op: Player):
        """Profane Denial: cancelled if the opponent controls a Fresh Sigil
        in ANY zone (Flipped do not block). Castle flips to Profaned now;
        the Tear lands at the end of Resolution."""
        if (not VARIANT.get('fix_b', False)
                and 'fresh' in op.sigils.values()):
            # A Fresh Sigil cancels Profane completely. Clear the queued
            # target so Resolution cleanup cannot award an invalid Tear.
            pl.pending_profane = ''
            return
        target = pl.pending_profane
        if not target or not profane_eligible(pl, target):
            pl.pending_profane = ''
            return
        pl.castles.discard(target)
        pl.profaned_castles.add(target)
        if ACTIVE_FEATURES['castle_integrity']:
            pl.castle_integrity[target] = 0
        pl.profane_this_round = True
        # pending_profane stays set — Tear applied at end of Resolution

    # ─────────────────────────────────────────────────────────────────
    #  OFFER THE VESSEL (Resolution rite, once per game)
    # ─────────────────────────────────────────────────────────────────
    def _ai_offer_vessel(self, pl: Player):
        if pl.vessel_used or not pl.alive: return
        op   = self.opp(pl.pid)
        plan = self._plan(pl, op)
        # AI gate: racing Dominion, opponent not about to win by Ritual,
        # and the Lord is compromised (high Threat) or the Tear seals it.
        seals_dominion = (self._total_tears() + 1 >= DOMINION_TRACK
                          and pl.tears + 1 > op.tears
                          and pl.tears + 1 >= self._dominion_req())
        wants = seals_dominion or (
            plan == 'race_dominion' and pl.threat >= 3
            and op.souls <= WIN_SOULS - 3)
        if not wants: return
        if op.souls + 1 >= WIN_SOULS and not seals_dominion: return

        pl.vessel_used = True
        pl.vessel_offered_lord = pl.lord
        self._gain_soul(op, 1)
        defeated_guards = pl.lord_guards[:]
        self._discard(defeated_guards)
        pl.lord_guards.clear()
        if defeated_guards:
            self._gremory_lord_guard_trigger()
        pl.alive = False           # Lord removed — NOT Banished: no Breach change
        self._gain_tear(pl, 'offer_vessel')

    # ─────────────────────────────────────────────────────────────────
    #  REFLEX SECOND ACTION (v5.29)
    # ─────────────────────────────────────────────────────────────────
    def _resolve_reflex_action(self, pid: int):
        pl = self.players[pid]
        op = self.opp(pid)

        choice = self._ai_reflex_choice(pl, op)

        # Odradek Breach — Paradox Geometry: the Odradek player may attempt
        # to steal the Reflex action by secretly matching the action card.
        if (self.breach == 'Odradek' and self.breach_owner >= 0
                and self.breach_owner != pid and choice is not None):
            thief = self.players[self.breach_owner]
            if thief.hand:
                # Secret guess: 50% the thief reads the winner correctly
                guess = choice[0] if self.rng.stream(f'reflex-guess:{pl.pid}:{self.round}').random() < 0.5 else \
                        self.rng.stream(f'reflex-guess:{pl.pid}:{self.round}').choice(['Hunt', 'Siege', 'Ward'])
                if guess == choice[0]:
                    self.stat_breach_triggers += 1
                    # Winner's chosen Subjects are discarded, action stolen.
                    # _ai_reflex_choice returns a selection that still lives in
                    # Hand; remove the physical cards before placing them in
                    # discard or the same objects occupy two zones.
                    for card in choice[1]:
                        if card in pl.hand:
                            pl.hand.remove(card)
                    # BUG FIX: these cards are a SELECTION and are still in
                    # the winner's hand. Discarding without removing them put
                    # the same Card object in two zones.
                    if VARIANT['fix_breach_discard_alias']:
                        for _c in choice[1]:
                            if _c in pl.hand: pl.hand.remove(_c)
                    self._discard(choice[1])
                    steal = self._ai_reflex_choice(thief, self.players[pid])
                    if steal is not None:
                        self._execute_reflex(thief, self.players[pid], steal)
                    return
        if choice is not None:
            self._execute_reflex(pl, op, choice)

    def _ai_reflex_choice(self, pl: Player, op: Player):
        """Pick a second action with full board knowledge.
        Returns (action, cards, target) or None to pass."""
        hand_sorted = sorted(pl.hand, key=lambda c: c.value, reverse=True)

        def minimal_commit(needed: int, target_type: str):
            picked, total = [], 0
            for c in hand_sorted:
                if total > needed:
                    break
                picked.append(c)
                total += effective_attack_value(pl, c, target_type)
            return (picked, total) if total > needed else (None, 0)

        # Option 1: lethal Hunt (Hunt still costs 1 Threat on reveal)
        if op.alive and pl.threat < MAX_THREAT:
            lord_def  = op.lord_base_def(breach=self.breach)
            lord_def += sum(g.value for g in op.lord_guards)
            lord_def += self._sigil_value(op, op.sigils['Lord'])
            cards, _ = minimal_commit(lord_def, 'Lord')
            # A pending Recoil deletes our 2nd-highest — pad the commit
            if (cards and op.lord == 'Odradek' and not op.odradek_recoil_done):
                pool = sorted((c for c in pl.hand if c not in cards),
                              key=lambda c: c.value, reverse=True)
                def eff(cs):
                    if len(cs) <= 1:
                        return 0
                    ordered = sorted(cs, key=lambda c: c.value, reverse=True)
                    victim = ordered[-1] if VARIANT['recoil_lowest'] else ordered[1]
                    return sum(effective_attack_value(pl, c, 'Lord')
                               for c in cs if c is not victim)
                for c in pool:
                    if eff(cards) > lord_def: break
                    cards.append(c)
                if eff(cards) <= lord_def:
                    cards = None
            if cards:
                return ('Hunt', cards, 'Lord')

        # Option 2: crack a castle (Siege Engine bypass does NOT apply)
        if op.castles:
            target = self._pick_siege_target(pl, op)
            need  = op.castle_def(target, breach=self.breach)
            need += sum(g.value for g in op.castle_guards)
            need += self._sigil_value(op, op.sigils['Castle'])
            cards, _ = minimal_commit(need, 'Castle')
            if cards:
                return ('Siege', cards, target)

        # Option 3: uncontested Fresh Sigil (Lord zone if hot, else Castle)
        if pl.alive and pl.threat >= 2 and pl.sigils['Lord'] == '':
            return ('Ward', [], 'Lord')
        if pl.sigils['Castle'] == '' and pl.castles:
            if pl.souls >= WIN_SOULS - 2 or pl.tears >= 2:
                return ('Ward', [], 'Castle')

        return None  # pass

    def _execute_reflex(self, pl: Player, op: Player, choice):
        action, cards, target = choice
        for c in cards:
            if c in pl.hand: pl.hand.remove(c)
        pl.committed = cards

        if action == 'Hunt':
            self._gain_threat(pl, 1)   # Hunt always costs 1 Threat
            self._resolve_hunt(pl, op)
        elif action == 'Siege':
            self._resolve_siege(pl, op, forced_target=target, reflex=True)
        elif action == 'Ward':
            pl.sigils[target] = 'fresh'   # uncontested Fresh
            if target == 'Lord':
                pl.threat = max(0, pl.threat - 1)

        self._discard(pl.committed)
        pl.committed = []
        self._check_win()

    def _apply_collapse_effect(self, pl: Player, from_breach: bool, from_veil: bool):
        """
        Discard 1 Guard from a zone attacked last round.
        Fires once per active source (Breach or Veil), so can fire twice.
        """
        sources = 0
        if from_breach:
            sources += 1
            self.stat_breach_triggers += 1
        if from_veil and not self._immune_to_threshold(pl, 9):
            sources += 1

        for _ in range(sources):
            discarded = False
            if pl.was_lord_attacked_prev and pl.lord_guards:
                victim = min(pl.lord_guards, key=lambda g: g.value)
                pl.lord_guards.remove(victim)
                self._discard([victim])
                discarded = True
            if pl.was_castle_attacked_prev and pl.castle_guards and not discarded:
                victim = min(pl.castle_guards, key=lambda g: g.value)
                pl.castle_guards.remove(victim)
                self._discard([victim])

    # ─────────────────────────────────────────────────────────────────
    #  KRONI CONSUME
    # ─────────────────────────────────────────────────────────────────
    def _gremory_lord_guard_trigger(self):
        """Predator of Ruin (new): first time each round a Lord Guard is Defeated,
        Gremory (if alive) draws 1 card then discards 1 (card filtering)."""
        for pl in self.players:
            if pl.lord == 'Gremory' and pl.alive and not pl.gremory_lord_guard_draw_done:
                pl.gremory_lord_guard_draw_done = True
                self._draw(pl, outside_draw=True)
                if pl.hand:
                    worst = min(pl.hand, key=lambda c: c.value)
                    pl.hand.remove(worst)
                    self._discard([worst])
                break  # only one Gremory can be in play

    def _try_kroni_consume(self, pl: Player):
        """Fires after combat. Gain Hunger if any destruction occurred this round.
        Tear (Hunger 3+): only if Hunger came from defeating an ENEMY guard or castle
        — not from self-sacrifice. Requires real interaction."""
        if pl.lord != 'Kroni' or not pl.alive or pl.kroni_consume_done: return
        if not self.any_destruction_this_round: return
        pl.kroni_consume_done = True
        self._kroni_gain_hunger(pl)

        # Gorge (Hunger 1+): personally defeated a guard this round
        if pl.kroni_hunger >= 1 and pl.kroni_personally_defeated_guard:
            self._gain_soul(pl, 1)

        # Old enemy-destruction Tear removed — replaced by Hunger 3 milestone

    def _try_kroni_fallback(self, pl: Player):
        """Resolve compulsory self-consumption when real destruction did not feed Kroni.

        Canonical DE v2 preserves the legacy Hunger payout. The measured lab
        removes the chosen physical card but grants no Hunger, so the fallback
        is a cost rather than an unconditional income engine.
        """
        if pl.lord != 'Kroni' or not pl.alive or pl.kroni_consume_done:
            return None

        all_guards = pl.lord_guards + pl.castle_guards
        victim = min(all_guards, key=lambda g: g.value) if all_guards else None

        if victim is not None:
            if victim in pl.lord_guards:
                pl.lord_guards.remove(victim)
            else:
                pl.castle_guards.remove(victim)
        elif pl.garrison:
            victim = min(pl.garrison, key=lambda g: g.value)
            pl.garrison.remove(victim)
        else:
            return None

        self.removed_from_play.append(victim)
        pl.kroni_consume_done = True

        if ACTIVE_FEATURES['kro_fallback_feeds']:
            self._kroni_gain_hunger(pl)

        return victim

    def _kroni_gain_hunger(self, pl: Player, n: int = 1):
        """Increment Hunger and check the Hunger-3 milestone Tear.

        Canonical DE v2 resets the milestone on each summon. The measured lab
        keeps the flag for the full game, so reaching Hunger 3 awards at most
        one milestone Tear no matter how often Kroni is Banished and returned.
        """
        for _ in range(n):
            was_two = (pl.kroni_hunger == 2)
            pl.kroni_hunger += 1
            if was_two and not pl.kroni_tear_milestone_fired:
                pl.kroni_tear_milestone_fired = True
                self._gain_tear(pl)

    # ─────────────────────────────────────────────────────────────────
    #  COMBAT: HUNT
    # ─────────────────────────────────────────────────────────────────
    def _resolve_hunt(self, atk: Player, dfn: Player):
        if not dfn.alive: return
        if (VARIANT.get('ward_threshold', False)
                and not VARIANT.get('ward_frontline', False)
                and 'Lord' in dfn.ward_turned
                and not (VARIANT.get('se_breach_the_gate', False)
                         and atk.castle_power_active('SiegeEngine'))):
            # Historical binary-Ward compatibility only. In the current lab,
            # Ward is a physical reinforcement layer and stops attacks naturally
            # through combat rather than via a pre-combat cancellation flag.
            dfn.was_hunted = True
            return
        # SiegeEngine — Breach the Gate: the engine rolls through the Ward.
        # Keyed to banishment, the only currency measured above the floor.
        dfn.was_hunted = True
        # A committed Hunt turns the defending Lord Guard area face-up.
        for _guard in dfn.lord_guards:
            _guard.guard_revealed = True

        # Relentless Pursuit: Orias hunting his marked lord gets a clean hunt
        # — Recoil and Backwash are suppressed for this attack
        orias_clean_hunt = (atk.lord == 'Orias' and self.orias_marked_lord == dfn.lord)

        # ── Odradek — Psychic Recoil (PRE-COMBAT, first attack this round)
        # Discard the attacker's second-highest committed card and gain 1 Soul.
        if (dfn.lord == 'Odradek' and dfn.alive and not dfn.odradek_recoil_done
                and not orias_clean_hunt):
            self._odradek_recoil(atk, dfn)

        strength  = atk.attack_value()
        strength += atk.suit_bonus('Butcher')

        # Orias — Marked Prey: +1 Hunt Strength; +1 additional if defender 2+ Threat
        if atk.lord == 'Orias' and atk.alive:
            strength += 1
            if dfn.threat >= 2: strength += 1

        # Crushing Presence / Invoked Butcher: lowest defending Guard gives no Defense
        ignore_lowest = False
        butcher_suppressed_guard = None
        if atk.lord == 'Valak' and atk.alive and len(dfn.lord_guards) >= 2:
            ignore_lowest = True
        if (atk.lord == 'Kanifous' and atk.alive
                and atk.kanifous_invoked_suit == 'Butcher' and dfn.lord_guards):
            butcher_suppressed_guard = min(
                dfn.lord_guards,
                key=lambda c: c.value,
            )
            dfn.lord_guards.remove(butcher_suppressed_guard)
            self._discard([butcher_suppressed_guard])

        lord_def = dfn.lord_base_def(breach=self.breach)
        ward_screen = 0
        if (ACTIVE_FEATURES['ward_commit_defense']
                and dfn.action == 'Ward'
                and dfn.ward_target == 'Lord'):
            # Canonical combat order: Ward reinforcements are physically in
            # front of Guards, Sigil and the Lord. They are not part of DEF.
            ward_screen = dfn.ward_reinforcement_value()

        sigil_state = dfn.sigils['Lord']
        sigil_value = self._sigil_value(dfn, sigil_state)

        guards_before = len(dfn.lord_guards)
        self.stat_combats += 1
        destroyed, sigil_broken, excess = self._combat_layers(
            atk, strength, dfn.lord_guards, ignore_lowest,
            sigil_value, has_sigil=(sigil_state != ''), struct_def=lord_def,
            ward_screen=ward_screen,
            guard_tax_exempt=(VARIANT.get('circle_ignores_guard_tax', False)
                and dfn.castle_power_active('SummoningCircle')))
        guards_lost = guards_before - len(dfn.lord_guards)

        # ── Keep — Sanctuary ─────────────────────────────────────────
        # The Lord retreats into the Keep; its stones take the blow.
        # Transfer EXACTLY the Hunt strength that exceeded Lord DEF. Because
        # equality already holds, removing the excess leaves the Lord alive.
        # A partial transfer is not allowed: if Keep cannot absorb the entire
        # excess without self-Ruining, the Lord is Banished normally.
        if destroyed and VARIANT.get('keep_sanctuary', False) and dfn.castle_power_active('Keep'):
            _kit('keep_opportunity')
            need = max(1, excess)
            if dfn.can_exert('Keep', need):
                dfn.exert('Keep', need, game=self, reason='sanctuary')
                _kit('keep_activation'); _kit('keep_integrity_spent', need)
                destroyed = False
                excess = -1
            else:
                _kit('keep_short')

        if (VARIANT.get('momentum', False)
                and destroyed
                and self.reflex_winner is None
                and 0 <= excess <= VARIANT.get('momentum_band', 3)):
            self.reflex_winner = atk.pid
            atk.momentum_refund_due += ACTIVE_FEATURES['momentum_refund']
            self.stat_momentum_triggers += 1

        if guards_lost > 0:
            self.any_destruction_this_round = True
            if atk.lord == 'Kroni':
                atk.kroni_personally_defeated_guard = True
                atk.kroni_enemy_destroyed = True
            if dfn.lord == 'Odradek':
                dfn.odradek_guards_defeated += guards_lost
            self._gremory_lord_guard_trigger()

        # Sigil Broken: remove it; controller gains 1 Soul if the target survives
        if sigil_broken:
            dfn.sigils['Lord'] = ''
            if not destroyed and (sigil_state == 'fresh'
                                  or not VARIANT['sigil_soul_fresh_only']):
                self._gain_soul(dfn, 1)
                self.stat_ward_souls += 1

        if destroyed:
            op = self.opp(atk.pid)
            # Consume the Hunt — forgo Banishment for a personal Tear (AI rite)
            consume = False
            total_after = self._total_tears() + 1
            if (total_after >= DOMINION_TRACK and atk.tears + 1 > op.tears
                    and atk.tears + 1 >= self._dominion_req()):
                consume = True
            elif (atk.tears >= 2 and atk.tears > op.tears
                  and atk.souls < WIN_SOULS - 1 and self.rng.stream(f'consume-hunt:{atk.pid}:{self.round}').random() < 0.25):
                consume = True
            elif (VARIANT['ai_dominion_drive'] and atk.tears >= 1
                  and atk.tears + 1 > op.tears and atk.souls < WIN_SOULS - 2
                  and self.rng.stream(f'consume-hunt:{atk.pid}:{self.round}').random() < 0.5):
                consume = True
            if consume:
                self._gain_tear(atk, 'consume_hunt')
                self._check_win()
                return

            self._lord_killed(atk, dfn)

            # Overkill: Banish with excess ≥3 → return one committed card ≤3 to hand
            if excess >= 3:
                low = [c for c in atk.committed if c.value <= 3]
                if low:
                    keep = max(low, key=lambda c: c.value)
                    atk.committed.remove(keep)
                    atk.hand.append(keep)

        # Valak — Siphon: after a Hunt that Defeated 1+ Guards, remove one more
        # Guard from that zone (if any remain)
        if (atk.lord == 'Valak' and atk.alive
                and guards_lost > 0 and dfn.lord_guards):
            victim = min(dfn.lord_guards, key=lambda c: c.value)
            dfn.lord_guards.remove(victim)
            self._discard([victim])
            self.any_destruction_this_round = True
            self._gremory_lord_guard_trigger()

        # Odradek — Psychic Backwash: attacker gains Threat if Odradek survives
        # Suppressed on Orias clean hunt (Relentless Pursuit)
        if (dfn.lord == 'Odradek' and dfn.alive and not orias_clean_hunt
                and not VARIANT['no_backwash']):
            self._gain_threat(atk, 1)

        # Orias — Barbed Web: after Hunt defeats 1+ guard, defender gains Threat
        # +1 normally; +2 if defender was already at 2+ Threat (escalation spiral)
        if atk.lord == 'Orias' and atk.alive and guards_lost > 0 and dfn.alive:
            threat_gain = 2 if dfn.threat >= 2 else 1
            self._gain_threat(dfn, threat_gain)

        # Kroni — Ravenous (Hunger 3+, once per game): +2 Souls on kill
        if (destroyed and atk.lord == 'Kroni' and atk.alive
                and atk.kroni_hunger >= 3 and not atk.kroni_ravenous_used):
            self._gain_soul(atk, 2)
            self._kroni_gain_hunger(atk)
            atk.kroni_ravenous_used = True

    # ─────────────────────────────────────────────────────────────────
    #  COMBAT: SIEGE
    # ─────────────────────────────────────────────────────────────────
    def _resolve_castle_ruination(self, atk: Player, dfn: Player, castle: str,
                                  guards_lost: int) -> bool:
        """Apply the complete consequence chain for any Castle Ruination.

        v6.10 duplicated a partial Ruination path inside Bastion interposition;
        that path removed Bastion but skipped normal Tear/Soul/Lord-kit effects.
        Every destruction now comes through this single resolver.  Returns True
        if the Ruination ended the game before later consequences resolve.
        """
        dfn.castles.discard(castle)
        if ACTIVE_FEATURES['castle_integrity']:
            dfn.castle_integrity[castle] = 0
        if (VARIANT.get('castle_permanent_loss', False)
                and dfn.castle_scars.get(castle, 0) >= 1):
            dfn.lost_castles.add(castle)
            if VARIANT.get('veil_on_permanent_loss', False):
                self._gain_neutral_tear('castle_permanent_loss')
        else:
            dfn.ruined_castles.add(castle)
        self.stat_castles_destroyed += 1
        self.stat_castle_ruined_by_owner[dfn.pid][castle] += 1
        self.any_destruction_this_round = True
        if atk.lord == 'Kroni':
            atk.kroni_enemy_destroyed = True

        # ── D7: Consume the Siege — forgo the Souls to claim the Tear.
        # AI gates mirror Consume the Hunt.
        consumed_siege = False
        if VARIANT['consume_the_siege']:
            op_c  = self.opp(atk.pid)
            plan_c = self._plan(atk, op_c)
            total_after = self._total_tears() + 1
            if (total_after >= DOMINION_TRACK and atk.tears + 1 > op_c.tears
                    and atk.tears + 1 >= self._dominion_req()):
                consumed_siege = True
            elif (plan_c == 'race_dominion' and atk.souls < WIN_SOULS - 2
                  and self.rng.stream(f'consume-siege:{atk.pid}:{self.round}:{castle}').random() < 0.5):
                consumed_siege = True
            elif (atk.tears < 2 and atk.tears <= op_c.tears
                  and atk.souls <= WIN_SOULS - 3
                  and self.rng.stream(f'consume-siege:{atk.pid}:{self.round}:{castle}').random() < 0.35):
                consumed_siege = True   # bootstrap: bank a speculative Tear

        # ── Neutral Tear: first castle destroyed this round
        # (D4: every castle destroyed; E4: Deimos claims it personally)
        if VARIANT['castle_tear_uncapped'] or not self.first_castle_neutral_done:
            claims = (VARIANT['deimos_claims_breach'] and atk.lord == 'Deimos'
                      and atk.alive
                      and (VARIANT['deimos_claims_breach'] >= 2
                           or not atk.deimos_breach_claimed))
            if consumed_siege:
                self._gain_tear(atk)
            elif claims:
                atk.deimos_breach_claimed = True
                self._gain_tear(atk)
            else:
                _tear_mode = VARIANT.get('castle_ruination_tear_mode', 'neutral')
                if _tear_mode == 'neutral':
                    self._gain_neutral_tear('castle_ruination')
                elif _tear_mode == 'attacker':
                    self._gain_tear(atk, 'castle_ruination')
                elif _tear_mode == 'none':
                    pass
                else:
                    raise ValueError(f'unknown castle_ruination_tear_mode: {_tear_mode}')
            self.first_castle_neutral_done = True
        if self._check_win(): return True

        # 2 Souls if at least one Castle Guard was Defeated this Siege
        # (forfeited under Consume the Siege)
        if consumed_siege:
            pass
        else:
            base_reward = 2 if guards_lost > 0 else 1
            ruination_bonus = int(VARIANT.get('ruination_soul_bonus', 0))
            reward = base_reward + ruination_bonus
            self._gain_soul(atk, reward)
            self.stat_ritual_souls += reward
            self.stat_ruination_soul_bonus += ruination_bonus

        # Gremory — Predator of Ruin
        for p in self.players:
            if p.lord == 'Gremory' and p.alive and not p.gremory_ruin_done:
                if self.discard:
                    p.hand.append(self.discard[-1])
                    self.discard.pop()
                p.gremory_ruin_done = True
                break

        # Kalligan — Wildfire resolves before Inferno so an Inferno
        # Scorch on the Lord zone remains the final persistent token.
        if atk.lord == 'Kalligan' and atk.alive:
            new_zone = 'Castle' if dfn.castles else 'Lord'
            if (self.persist_scorch_pid != dfn.pid
                    or self.persist_scorch_type != new_zone):
                self.persist_scorch_level = 1
            self.persist_scorch_pid = dfn.pid
            self.persist_scorch_type = new_zone

        # Kalligan — Inferno defeats the highest Lord Guard. The measured
        # profile removes its automatic Threat cost.
        if (atk.lord == 'Kalligan' and atk.alive
                and (atk.threat < MAX_THREAT
                     or not ACTIVE_FEATURES['kal_inferno_threat'])):
            if ACTIVE_FEATURES['kal_inferno_threat']:
                self._gain_threat(atk, 1)
            if dfn.lord_guards:
                victim = max(dfn.lord_guards, key=lambda g: g.value)
                dfn.lord_guards.remove(victim)
                self._discard([victim])
            else:
                self.persist_scorch_pid = dfn.pid
                self.persist_scorch_type = 'Lord'

        # Kroni — Ravenous
        if (atk.lord == 'Kroni' and atk.alive
                and atk.kroni_hunger >= 3 and not atk.kroni_ravenous_used):
            self._gain_soul(atk, 2)
            self._kroni_gain_hunger(atk)
            atk.kroni_ravenous_used = True
        return False

    def _resolve_siege(self, atk: Player, dfn: Player,
                       forced_target: Optional[str] = None,
                       reflex: bool = False):
        if not dfn.castles: return
        if (VARIANT.get('ward_threshold', False)
                and not VARIANT.get('ward_frontline', False)
                and 'Castle' in dfn.ward_turned):
            # Historical binary-Ward compatibility only; current Ward resolves
            # as the first physical combat layer.
            dfn.was_sieged = True
            return
        dfn.was_sieged = True
        # A committed Siege turns the defending Castle Guard area face-up.
        for _guard in dfn.castle_guards:
            _guard.guard_revealed = True

        target_castle = forced_target if forced_target in dfn.castles else \
                        self._pick_siege_target(atk, dfn, record=True)
        dfn.last_sieged_castle = target_castle

        # ── Odradek — Psychic Recoil (PRE-COMBAT, first attack this round)
        # Variant O1: Recoil fires on Hunts only — Sieges bypass it entirely
        if (dfn.lord == 'Odradek' and dfn.alive and not dfn.odradek_recoil_done
                and not VARIANT['recoil_hunts_only']):
            self._odradek_recoil(atk, dfn)

        strength  = atk.attack_value(siege=True)
        strength += atk.suit_bonus('Butcher')

        # Siege Engine bypass does NOT apply to the Reflex second action
        siege_engine_bypass = (
            VARIANT.get('siege_engine_bypass', False)
            and atk.castle_power_active('SiegeEngine') and not reflex)

        # Deimos — War Machine: +2 Siege Strength, −1 per castle lost.
        # REQUIRES Siege Engine to be active.
        if atk.lord == 'Deimos' and atk.alive and (
                atk.castle_power_active('SiegeEngine') or VARIANT['deimos_war_machine_free']):
            lost = len(atk.ruined_castles)
            if not VARIANT['war_machine_ignores_profaned']:
                lost += len(atk.profaned_castles)
            strength += max(0, 2 - lost)

        # Kalligan — Pyroclasm: +1 always; +1 additional if defender has Ruined Castles
        if atk.lord == 'Kalligan' and atk.alive:
            strength += 2 if dfn.ruined_castles else 1

        # Deimos — Fear Aura: defender with 2+ Castle Guards returns one to hand
        # (before Defense is calculated; the last Guard cannot be returned)
        if atk.lord == 'Deimos' and atk.alive and len(dfn.castle_guards) >= 2:
            weakest = min(dfn.castle_guards, key=lambda c: c.value)
            dfn.castle_guards.remove(weakest)
            dfn.hand.append(weakest)

        # Crushing Presence / Invoked Butcher: lowest defending Guard gives no Defense
        ignore_lowest = False
        butcher_suppressed_guard = None
        if atk.lord == 'Valak' and atk.alive and len(dfn.castle_guards) >= 2:
            ignore_lowest = True
        if (atk.lord == 'Kanifous' and atk.alive
                and atk.kanifous_invoked_suit == 'Butcher' and dfn.castle_guards):
            butcher_suppressed_guard = min(
                dfn.castle_guards,
                key=lambda c: c.value,
            )
            dfn.castle_guards.remove(butcher_suppressed_guard)
            self._discard([butcher_suppressed_guard])

        # Integrity is structural HP. Ward commitments are temporary
        # REINFORCEMENTS and therefore resolve before permanent Castle Guards,
        # Sigil, Bastion and the target structure.
        integrity_before = dfn.castle_integrity.get(
            target_castle, castle_max_integrity(target_castle)
        )
        ward_screen = 0
        if (ACTIVE_FEATURES['ward_commit_defense']
                and dfn.action == 'Ward'
                and dfn.ward_target == 'Castle'):
            ward_screen = dfn.ward_reinforcement_value()
        structure_screen = 0
        structure_vulnerability = 1 if self.breach in ('Deimos', 'Humbaba') else 0

        sigil_state = dfn.sigils['Castle']
        sigil_value = self._sigil_value(dfn, sigil_state)

        guards_before = len(dfn.castle_guards)
        self.stat_combats += 1
        self.stat_sieges += 1
        if siege_engine_bypass:
            self.stat_structure_first_bypasses += 1
        if ACTIVE_FEATURES['castle_integrity']:
            _wall_active = (
                VARIANT.get('bastion_fortified', False)
                and 'Bastion' in dfn.castles
                and 'Bastion' not in dfn.disabled_castle_powers
                and dfn.castle_integrity.get('Bastion', 0) > 0
                and target_castle != 'Bastion'
            )
            _wall_hp = (dfn.castle_integrity.get('Bastion', castle_max_integrity('Bastion'))
                        if _wall_active else 0)
            _wall_mit = (int(VARIANT.get('bastion_overflow_mitigation', 0) or 0)
                         if _wall_active else 0)
            # In forced-wall mode the physical structure layer is Bastion ->
            # mitigation -> intended rear Castle. Feed the combined depth to the
            # layer resolver so arriving Strength is not prematurely capped by
            # the rear Castle's HP before Bastion gets a chance to absorb it.
            _effective_structure_depth = integrity_before + _wall_hp + _wall_mit
            destroyed, sigil_broken, excess = self._combat_layers(
                atk, strength, dfn.castle_guards, ignore_lowest,
                sigil_value, has_sigil=(sigil_state != ''), struct_def=0,
                bypass=siege_engine_bypass, structure_integrity=_effective_structure_depth,
                ward_screen=ward_screen, structure_screen=structure_screen,
                structure_vulnerability=structure_vulnerability,
                guard_tax_exempt=(VARIANT.get('circle_ignores_guard_tax', False)
                and dfn.castle_power_active('SummoningCircle')))
            struct_hit = self._structure_damage

            # ── Bastion — Fortified Layers ───────────────────────────
            # The outer wall interposes: it takes EVERY hit aimed at another
            # Castle until it breaks. Not exertion — damage taken for someone
            # else can kill you, so Bastion is destructible here and drops out
            # of the "may not self-Ruin" rule. Mandatory, so there is no
            # doctrine surface to over-fire (§3).
            if (VARIANT.get('bastion_fortified', False)
                    and struct_hit > 0
                    and 'Bastion' in dfn.castles
                    and 'Bastion' not in dfn.disabled_castle_powers
                    and dfn.castle_integrity.get('Bastion', 0) > 0
                    and target_castle != 'Bastion'):
                _kit('bastion_opportunity')
                shield = dfn.castle_integrity.get('Bastion', castle_max_integrity('Bastion'))
                soak = min(shield, struct_hit)
                if soak > 0:
                    dfn.castle_integrity['Bastion'] = shield - soak
                    struct_hit -= soak
                    self.stat_castle_damage += soak
                    _kit('bastion_activation'); _kit('bastion_integrity_spent', soak)
                    # Optional LAB rider: a hit that actually punches THROUGH the
                    # Bastion loses additional force before reaching the rear Castle.
                    if struct_hit > 0:
                        _mit = int(VARIANT.get('bastion_overflow_mitigation', 0) or 0)
                        if _mit > 0:
                            _saved = min(_mit, struct_hit)
                            struct_hit -= _saved
                            _kit('bastion_overflow_mitigated', _saved)
                    if dfn.castle_integrity['Bastion'] <= 0:
                        _kit('bastion_broken')
                        _guards_lost_so_far = guards_before - len(dfn.castle_guards)
                        if self._resolve_castle_ruination(
                                atk, dfn, 'Bastion', _guards_lost_so_far):
                            return
                    destroyed = struct_hit >= integrity_before
                    if struct_hit == 0:
                        _kit('bastion_full_absorb')

            integrity_after = max(0, integrity_before - struct_hit)
            dfn.castle_integrity[target_castle] = integrity_after
            self.stat_castle_damage += struct_hit
            assert integrity_after == max(0, integrity_before - struct_hit)
            assert destroyed == (integrity_after == 0)
        else:
            struct_def = dfn.castle_def(target_castle, breach=self.breach, game=self)
            struct_def += structure_screen
            destroyed, sigil_broken, excess = self._combat_layers(
                atk, strength, dfn.castle_guards, ignore_lowest,
                sigil_value, has_sigil=(sigil_state != ''), struct_def=struct_def,
                bypass=siege_engine_bypass, ward_screen=ward_screen,
                guard_tax_exempt=(VARIANT.get('circle_ignores_guard_tax', False)
                and dfn.castle_power_active('SummoningCircle')))

        guards_lost = guards_before - len(dfn.castle_guards)

        if (VARIANT.get('momentum', False)
                and destroyed
                and self.reflex_winner is None
                and 0 <= excess <= VARIANT.get('momentum_band', 3)):
            self.reflex_winner = atk.pid
            atk.momentum_refund_due += ACTIVE_FEATURES['momentum_refund']
            self.stat_momentum_triggers += 1

        if guards_lost > 0:
            self.any_destruction_this_round = True
            if atk.lord == 'Kroni':
                atk.kroni_personally_defeated_guard = True
                atk.kroni_enemy_destroyed = True
            if dfn.lord == 'Odradek':
                dfn.odradek_guards_defeated += guards_lost

        # Sigil Broken: remove it; controller gains 1 Soul if the castle survives
        if sigil_broken:
            dfn.sigils['Castle'] = ''
            if not destroyed and (sigil_state == 'fresh'
                                  or not VARIANT['sigil_soul_fresh_only']):
                self._gain_soul(dfn, 1)
                self.stat_ward_souls += 1

        if destroyed:
            if self._resolve_castle_ruination(atk, dfn, target_castle, guards_lost):
                return

        # Valak — Siphon: after a Siege that Defeated 1+ Guards, remove one more
        # Guard from that zone (if any remain) — applies whether or not the
        # castle was destroyed
        if (atk.lord == 'Valak' and atk.alive
                and guards_lost > 0 and dfn.castle_guards):
            victim = min(dfn.castle_guards, key=lambda c: c.value)
            dfn.castle_guards.remove(victim)
            self._discard([victim])
            self.any_destruction_this_round = True

    # ─────────────────────────────────────────────────────────────────
    #  CORE COMBAT — legacy layers keep the Golden Rule; Integrity is HP,
    #  so arriving Strength equal to remaining Integrity does Ruin it.
    #  Normal order:  Ward → Guards → Sigil → Structure
    #  Siege Engine:  Ward → Sigil → Structure → Guards
    # ─────────────────────────────────────────────────────────────────
    def _combat_layers(self, atk: Player, strength: int,
                       guards: List[Card], ignore_lowest: bool,
                       sigil_value: int, has_sigil: bool,
                       struct_def: int,
                       bypass: bool = False,
                       structure_integrity: Optional[int] = None,
                       ward_screen: int = 0,
                       structure_screen: int = 0,
                       structure_vulnerability: int = 0,
                       guard_tax_exempt: bool = False) -> Tuple[bool, bool, int]:
        """Resolve the ordered defense layers and preserve the legacy tuple.

        ``ward_screen`` is always the first combat layer: temporary Ward
        reinforcements arrive for this battle, absorb Strength before any
        permanent defenders, and leave after primary Resolution.

        With ``structure_integrity`` supplied, arriving Strength damages the
        Castle directly. ``_structure_hit`` records Strength that reached stone,
        ``_structure_damage`` records HP removed, and ``_structure_spill`` records
        Strength passed to Guards by a structure-first Siege Engine attack.
        """
        self._structure_hit = 0
        self._structure_damage = 0
        self._structure_spill = 0

        _gpen = int(VARIANT.get('guard_offsuit_penalty', 0) or 0)
        _gexempt = guard_tax_exempt
        _gsuit = VARIANT.get('guard_penalty_exempt_suit', 'Vulture')
        _gfloor = int(VARIANT.get('guard_offsuit_floor', 1))

        def _gv(card):
            """Guard defence value under the Vulture tax. SummoningCircle —
            the Rite of Watch: your Guards are not suit-taxed."""
            if _gpen <= 0 or _gexempt or card.suit == _gsuit:
                return card.value
            return max(_gfloor, card.value - _gpen)

        def _effective(gs: List[Card]):
            if not gs:
                return []
            eff = [(guard, _gv(guard)) for guard in gs]
            if ignore_lowest:
                low_i = min(range(len(eff)), key=lambda i: eff[i][1])
                eff[low_i] = (eff[low_i][0], 0)
            eff.sort(key=lambda item: item[1], reverse=True)
            return eff

        def _ward_layer(remaining: int) -> int:
            # Ward is reinforcement, not a modifier to the target's DEF. Equality
            # stops the attack here; any surplus continues into permanent layers.
            screen = max(0, int(ward_screen or 0))
            if screen <= 0:
                return remaining
            if remaining <= screen:
                return -1
            return remaining - screen

        def _strip_guards(remaining: int) -> int:
            for guard, value in _effective(guards):
                if remaining > value:
                    guards.remove(guard)
                    self._discard([guard])
                    remaining -= value
                else:
                    return -1
            return remaining

        def _sigil_layer(remaining: int) -> Tuple[bool, int]:
            if not has_sigil:
                return False, remaining
            if sigil_value == 0:
                return True, remaining
            if remaining > sigil_value:
                return True, remaining - sigil_value
            return False, -1

        def _integrity_layer(remaining: int) -> Tuple[bool, int]:
            # Temporary structure defense is consumed before the actual wall.
            remaining -= max(0, structure_screen)
            if remaining <= 0:
                return False, remaining
            hit = max(1, remaining + max(0, structure_vulnerability))
            integrity = max(0, int(structure_integrity or 0))
            damage = min(integrity, hit)
            spill = max(0, hit - integrity)
            self._structure_hit = hit
            self._structure_damage = damage
            self._structure_spill = spill
            self._aha(abs(integrity - hit))
            return damage >= integrity and integrity > 0, hit - integrity

        remaining = _ward_layer(strength)
        if remaining < 0:
            return False, False, remaining

        if structure_integrity is not None:
            if bypass:
                # Ward → Sigil → temporary screen → Integrity → Guards.
                broken, remaining = _sigil_layer(remaining)
                if remaining < 0:
                    self._aha(sigil_value - strength)
                    return False, broken, remaining
                ruined, structural_excess = _integrity_layer(remaining)
                if not ruined:
                    return False, broken, structural_excess
                leftover = _strip_guards(self._structure_spill)
                excess = leftover if leftover >= 0 else 0
                return True, broken, excess

            # Ward → Guards → Sigil → temporary screen → Integrity.
            remaining = _strip_guards(remaining)
            if remaining < 0:
                return False, False, -1
            broken, remaining = _sigil_layer(remaining)
            if remaining < 0:
                self._aha(sigil_value)
                return False, broken, -1
            ruined, structural_excess = _integrity_layer(remaining)
            return ruined, broken, structural_excess

        # Legacy binary structure resolution (Ward still remains first).
        if bypass:
            broken, remaining = _sigil_layer(remaining)
            if remaining < 0:
                self._aha(sigil_value - strength)
                return False, broken, remaining
            if remaining > struct_def:
                remaining -= struct_def
                self._aha(remaining)
                leftover = _strip_guards(remaining)
                excess = leftover if leftover >= 0 else 0
                return True, broken, excess
            self._aha(struct_def - remaining)
            return False, broken, remaining - struct_def

        remaining = _strip_guards(remaining)
        if remaining < 0:
            return False, False, -1
        broken, remaining = _sigil_layer(remaining)
        if remaining < 0:
            self._aha(sigil_value)
            return False, broken, -1
        if remaining > struct_def:
            self._aha(remaining - struct_def)
            return True, broken, remaining - struct_def
        self._aha(struct_def - remaining)
        return False, broken, remaining - struct_def

    # ─────────────────────────────────────────────────────────────────
    #  SIGIL VALUE
    # ─────────────────────────────────────────────────────────────────
    def _sigil_value(self, pl: Player, state: str) -> int:
        """Fresh 2 / Flipped 1, +1 with an active Keep.
        Omen (track 3): −1 (min 0) unless Attunement 3+."""
        if state not in ('fresh', 'flipped'):
            return 0
        base = 2 if state == 'fresh' else 1
        # v6.5 makes Ward value flat: a fresh Ward is 2 and its one-round
        # decay is 1, without Keep/Omen modifiers reappearing behind it.
        if VARIANT.get('sigil_flat', False):
            return base
        base += 1 if pl.castle_power_active('Keep') else 0
        if self._threshold_active(3) and not self._immune_to_threshold(pl, 3):
            base = max(0, base - 1)
        return base

    # ─────────────────────────────────────────────────────────────────
    #  KANIFOUS INVOKE
    # ─────────────────────────────────────────────────────────────────
    def _kanifous_invoke(self, pl: Player):
        """After Reveal: pay the active Invoke cost, reveal two, invoke one."""
        if not ACTIVE_FEATURES['kani_invoke']:
            return

        if not self.deck:
            if self.discard:
                self.deck = self.discard[:]
                self.discard = []
                self.rng.stream('deck').shuffle(self.deck)
            else:
                return

        revealed = []
        for _ in range(2):
            if not self.deck:
                if self.discard:
                    self.deck = self.discard[:]
                    self.discard = []
                    self.rng.stream('deck').shuffle(self.deck)
                else:
                    break
            if self.deck:
                revealed.append(self.deck.pop())

        if not revealed:
            return

        if ACTIVE_FEATURES['kani_hand_cost']:
            if not pl.hand:
                for card in reversed(revealed):
                    self.deck.append(card)
                return
            toll = min(pl.hand, key=lambda card: card.value)
            pl.hand.remove(toll)
            self._discard([toll])

        pl.kanifous_invokes_this_round += 1
        if (ACTIVE_FEATURES['kani_threat_cost']
                and not ACTIVE_FEATURES['kani_hand_cost']):
            self._gain_threat(pl, 1)

        if (ACTIVE_FEATURES['kani_neutral_tear']
                and revealed[0].value >= 4):
            self._gain_neutral_tear('kanifous_invoke')

        def _suit_score(card: Card) -> float:
            suit = card.suit
            if suit == 'Butcher':
                return 1.5 if pl.action in ('Hunt', 'Siege') else 0.5
            if suit == 'Penitent':
                total_guards = len(pl.lord_guards) + len(pl.castle_guards)
                return 1.2 if total_guards <= 2 else 0.6
            if suit == 'Vulture':
                return 1.3 if len(pl.hand) <= 3 else 0.7
            if suit == 'Wright':
                imbalance = abs(len(pl.lord_guards) - len(pl.castle_guards))
                return 0.8 + imbalance * 0.2
            return 0.5

        if len(revealed) == 1:
            chosen = revealed[0]
            discarded = []
        else:
            scores = [_suit_score(card) for card in revealed]
            if scores[0] >= scores[1]:
                chosen, discarded = revealed[0], [revealed[1]]
            else:
                chosen, discarded = revealed[1], [revealed[0]]

        if discarded:
            self._discard(discarded)

        pl.kanifous_invoked_suit = (
            chosen.suit if ACTIVE_FEATURES['kani_suit_effects'] else ''
        )

        if ACTIVE_FEATURES['kani_suit_effects']:
            if chosen.suit == 'Vulture':
                self._draw(pl, outside_draw=True)
                self._draw(pl, outside_draw=True)
                self._draw(pl, outside_draw=True)
                if len(pl.hand) > 1:
                    worst = min(pl.hand, key=lambda card: card.value)
                    pl.hand.remove(worst)
                    self._discard([worst])

            elif chosen.suit == 'Wright':
                moved = 0
                while (moved < 2 and pl.lord_guards
                       and len(pl.castle_guards) < pl.max_castle_guards()):
                    guard = pl.lord_guards.pop(0)
                    pl.castle_guards.append(guard)
                    moved += 1

            elif chosen.suit == 'Penitent':
                def _place(guard):
                    if len(pl.lord_guards) <= len(pl.castle_guards):
                        pl.lord_guards.append(guard)
                    else:
                        pl.castle_guards.append(guard)

                for _ in range(2):
                    if not self.deck:
                        if self.discard:
                            self.deck = self.discard[:]
                            self.discard = []
                            self.rng.stream('deck').shuffle(self.deck)
                        else:
                            break
                    extra = self.deck.pop()
                    _place(extra)
                    pl.penitent_temp_guards.append(extra)
                pl.kanifous_invoked_high = True

        if (ACTIVE_FEATURES['kani_soul_trigger']
                and chosen.value == pl.threat):
            self._gain_soul(pl, 1)

        if (ACTIVE_FEATURES['kani_garrison_bank']
                and len(pl.garrison) < GARRISON_MAX
                and chosen not in pl.garrison):
            pl.garrison.append(chosen)
        else:
            self._discard([chosen])

    def _lord_killed(self, atk: Player, dfn: Player):
        self.stat_lords_killed += 1

        # Banishment soul exchange resolves fully before any win check
        self._gain_soul(atk, 2)
        self.stat_hunt_souls += 2

        # Orias — Marked Prey: Banishing a Lord with 3+ Threat → +2 additional Souls
        if atk.lord == 'Orias' and atk.alive and dfn.threat >= 3:
            self._gain_soul(atk, 2)

        self._lose_soul(dfn, 1)

        # Kanifous — Death Pact: +1 Soul when Banished by a Hunt;
        # if still behind on Souls after this gain, draw 2
        if dfn.lord == 'Kanifous':
            self._gain_soul(dfn, 1)
            if dfn.souls < atk.souls:
                self._draw(dfn, outside_draw=True)
                self._draw(dfn, outside_draw=True)

        if atk.lord == 'Orias' and atk.alive:
            self.orias_marked_lord = dfn.lord

        if dfn.lord == 'Kroni':
            dfn.kroni_hunger = max(0, dfn.kroni_hunger - 1)
            # milestone flag resets on resummon, not on kill — allows farming

        # Odradek: Reconfiguration tokens reset on Banishment
        if dfn.lord == 'Odradek':
            dfn.odradek_reconfig_tokens = 0

        if VARIANT['neutral_tear_on_banish']:
            self._gain_neutral_tear('banishment')

        if VARIANT.get('lord_threat_retention', False):
            base_threat = LORD_STATS[dfn.lord]['r']
            dfn.return_threat_override = min(
                MAX_THREAT,
                base_threat + dfn.threat // 2,
            )
            dfn.threat = dfn.return_threat_override
        else:
            dfn.return_threat_override = None
            # DE v2 resets Threat as soon as the Lord is Banished. Retaining
            # the old value here would leak the lab's return-state mechanic
            # into canonical snapshots and downstream doctrine reads.
            dfn.threat = LORD_STATS[dfn.lord]['r']
        self.breach = dfn.lord
        self.breach_owner = dfn.pid
        # Stockpile — Muster: the garrison holds even when the Lord falls.
        # Keyed to banishment COST rather than banishment prevention.
        if not (VARIANT.get('stockpile_muster', False)
                and dfn.castle_power_active('Stockpile')):
            dfn.lord_guards.clear()
        else:
            _kit('muster_saved', len(dfn.lord_guards))
        self._odradek_discard_bank(dfn, reason='banished')
        dfn.alive = False
        dfn.banished_on_round = self.round

    # ═══════════════════════════════════════════════════════════════════
    #  AI — SUMMON
    # ═══════════════════════════════════════════════════════════════════
    def _ai_pick_lord(self, pl: Player) -> Optional[str]:
        op = self.opp(pl.pid)
        available = list(pl.lord_pool)

        def lord_score(lord: str) -> float:
            base_cost = summon_base_cost(lord)
            if (VARIANT.get('circle_blood_summon', False)
                    and pl.castle_power_active('SummoningCircle')
                    and pl.can_exert('SummoningCircle', int(VARIANT.get('circle_blood_summon_cost', 3)))):
                base_cost -= int(VARIANT.get('circle_blood_summon_discount', 3))
            elif pl.castle_power_active('SummoningCircle'):
                base_cost -= int(VARIANT.get('circle_discount', 0) or 0)
            breach_penalty = 3 if self.breach == lord else 0
            cost = max(0, base_cost + breach_penalty)
            # v5.29: Summon costs are paid from HAND only
            if sum(c.value for c in pl.hand) < cost: return -999.0

            score = 0.0
            if lord == 'Orias':    score += 1.5 if op.alive and op.threat >= 1 else 0.8
            if lord == 'Deimos':   score += 1.2 if len(op.castles) >= 2 else 0.6
            if lord == 'Gremory':  score += 0.8 + (0.4 if pl.ruined_castles or op.ruined_castles else 0.0)
            if lord == 'Kroni':    score += 0.6 + pl.kroni_hunger * 0.3
            if lord == 'Valak':    score += 0.9 if op.alive and len(op.lord_guards) >= 2 else 0.5
            if lord == 'Kalligan':
                score += (KALLIGAN_PICK_BASE
                          + (0.50 if op.ruined_castles else 0.0)
                          + (0.20 if pl.ruined_castles else 0.0))
            if lord == 'Odradek':  score += 0.8 if op.alive and op.threat >= 2 else 0.5
            if lord == 'Kanifous': score += 0.7
            if lord == 'Humbaba': score += 0.55 + len(pl.castles) * 0.13
            if self.breach == lord: score -= 0.5
            score -= breach_penalty * 0.5
            score -= cost * 0.05
            return score

        scored = sorted(available, key=lord_score, reverse=True)
        for lord in scored:
            base_cost = summon_base_cost(lord)
            if (VARIANT.get('circle_blood_summon', False)
                    and pl.castle_power_active('SummoningCircle')
                    and pl.can_exert('SummoningCircle', int(VARIANT.get('circle_blood_summon_cost', 3)))):
                base_cost -= int(VARIANT.get('circle_blood_summon_discount', 3))
            elif pl.castle_power_active('SummoningCircle'):
                base_cost -= int(VARIANT.get('circle_discount', 0) or 0)
            breach_pen = 3 if self.breach == lord else 0
            cost = max(0, base_cost + breach_pen)
            if sum(c.value for c in pl.hand) >= cost:
                return lord
        return None

    def _resummon_blocked(self, pl: 'Player') -> bool:
        """A banished Lord must wait. SummoningCircle exempts you — the rite
        is already prepared. Same shape as Forge Discipline: a rule that fires
        constantly, and a Castle that grants permission to ignore it."""
        d = int(VARIANT.get('resummon_delay_rounds', 0) or 0)
        if d <= 0:
            return False
        if (VARIANT.get('circle_ignores_delay', False)
                and pl.castle_power_active('SummoningCircle')):
            _kit('circle_delay_skipped')
            return False
        return (self.round - pl.banished_on_round) <= d

    def _ai_summon(self, pl: Player, forced: bool = False):
        if pl.alive and not forced: return
        if not forced and self._resummon_blocked(pl):
            _kit('resummon_blocked'); return

        # In locked mode, always use the one lord in the pool
        if LOCK_LORDS:
            chosen = pl.lord_pool[0]
        else:
            chosen = self._ai_pick_lord(pl)
            if chosen is None and not forced: return
            if chosen is None: chosen = pl.lord_pool[0]

        pl.lord = chosen
        printed_base_cost = summon_base_cost(chosen)
        base_cost = printed_base_cost
        _blood_cost = int(VARIANT.get('circle_blood_summon_cost', 3))
        _blood_discount = int(VARIANT.get('circle_blood_summon_discount', 3))
        circle_blood_summon_applies = (
            VARIANT.get('circle_blood_summon', False)
            and pl.castle_power_active('SummoningCircle')
            and pl.can_exert('SummoningCircle', _blood_cost)
        )
        if circle_blood_summon_applies:
            base_cost -= _blood_discount
        elif (pl.castle_power_active('SummoningCircle')
                and (not forced or VARIANT.get('circle_opening_summon', False))):
            base_cost -= int(VARIANT.get('circle_discount', 0) or 0)
        breach_penalty = 3 if self.breach == chosen else 0
        cost = max(0, base_cost + breach_penalty)

        if not forced and sum(c.value for c in pl.hand) < cost:
            return

        if circle_blood_summon_applies:
            paid = pl.exert('SummoningCircle', _blood_cost, game=self, reason='blood_summon')
            if paid:
                _kit('circle_summon_activation')
                _kit('circle_summon_integrity_spent', paid)
                _kit('circle_summon_discount_saved', min(_blood_discount, printed_base_cost))
            else:
                # Defensive consistency: if the checked exertion somehow becomes
                # illegal, do not grant the discount for free.
                cost = max(0, printed_base_cost + breach_penalty)
                if not forced and sum(c.value for c in pl.hand) < cost:
                    return

        self._pay(pl, cost, hand_only=True)
        pl.alive = True
        pl.threat = (
            pl.return_threat_override
            if (
                VARIANT.get('lord_threat_retention', False)
                and pl.return_threat_override is not None
            )
            else LORD_STATS[chosen]['r']
        )
        # SummoningCircle — Swift Return: the rite is already prepared.
        if (VARIANT.get('circle_swift_return', False)
                and pl.castle_power_active('SummoningCircle')):
            pl.threat = 0
            _kit('swift_return')
        pl.return_threat_override = None
        # Offer the Vessel: the offered Lord resummons at Threat 2
        if pl.vessel_offered_lord == chosen:
            pl.threat = 2
            pl.vessel_offered_lord = ''

        # Canonical resets the milestone each summon. The measured lab keeps
        # it for the full game so killing Kroni cannot refill Dominion income.
        if chosen == 'Kroni' and not ACTIVE_FEATURES['kro_milestone_once']:
            pl.kroni_tear_milestone_fired = False
        if chosen == 'Odradek':
            pl.odradek_reconfig_tokens = 0  # tokens reset on summon

        # Relentless Pursuit: marked lord gets +1 Threat on resummon
        if self.orias_marked_lord == chosen:
            self._gain_threat(pl, 1)

        # ── Tear on all summons after the first. Root-economy probe can
        # keep it shared, assign it to the summoner, or suppress it.
        if pl.first_summon_done:
            self.stat_resummons_by_player[pl.pid] += 1
            _resummon_mode = VARIANT.get('resummon_tear_mode', 'neutral')
            if _resummon_mode == 'neutral':
                self._gain_neutral_tear('resummon')
            elif _resummon_mode == 'summoner':
                self._gain_tear(pl, 'resummon')
            elif _resummon_mode == 'none':
                pass
            else:
                raise ValueError(f'unknown resummon_tear_mode: {_resummon_mode}')
            if self._check_win(): return
        else:
            pl.first_summon_done = True

    def _pay(self, pl: Player, cost: int, hand_only: bool = False):
        if cost <= 0: return
        source = pl.hand if hand_only else (pl.hand + pl.garrison)
        pool  = sorted(source, key=lambda c: c.value)
        paid  = []; total = 0
        for c in pool:
            if total >= cost: break
            paid.append(c); total += c.value
        for c in paid:
            if c in pl.hand:       pl.hand.remove(c)
            elif c in pl.garrison: pl.garrison.remove(c)
        self._discard(paid)

    def _ai_repair_only(self, pl: Player):
        if ACTIVE_FEATURES['castle_integrity']:
            if pl.castle_action_used_this_round:
                return
            legacy_priority = CASTLE_PRIORITIES.get(pl.lord, CASTLES)
            if VARIANT.get('castle_owner_doctrine', 'strategic') == 'legacy':
                priority = list(legacy_priority)
            else:
                priority = sorted(
                    CASTLES,
                    key=lambda c: (self._castle_strategic_value(
                        pl, c, assume_standing=(c not in pl.castles)),
                        -legacy_priority.index(c) if c in legacy_priority else -99),
                    reverse=True,
                )
            payment_zone = list(pl.hand + pl.garrison)
            if not payment_zone:
                return

            damaged = [
                castle for castle in priority
                if castle in pl.castles
                and 0 < pl.castle_integrity.get(castle, castle_max_integrity(castle))
                < castle_max_integrity(castle)
            ]
            severe = [
                castle for castle in damaged
                if pl.castle_integrity.get(castle, castle_max_integrity(castle))
                <= CASTLE_OPERATIONAL_FLOOR
            ]
            unavailable = (
                set(pl.castles)
                | set(pl.ruined_castles)
                | set(pl.profaned_castles)
                | set(pl.lost_castles)
            )
            buildable = [castle for castle in priority if castle not in unavailable]
            active_project = next(
                (castle for castle in priority
                 if castle in buildable
                 and pl.castle_construction_progress.get(castle, 0) > 0),
                None,
            )

            # Emergency maintenance beats expansion. Otherwise finish/start a
            # construction project before topping off harmless chip damage.
            repair_pool = repair_payment_pool(payment_zone, pl)
            can_repair = bool(repair_pool)

            if severe and can_repair:
                action = 'repair'
                target = severe[0]
            elif ACTIVE_FEATURES['castle_construction'] and buildable:
                action = 'construct'
                target = active_project or buildable[0]
            elif damaged and can_repair:
                action = 'repair'
                target = damaged[0]
            else:
                return

            if action == 'repair':
                before = pl.castle_integrity[target]
                missing = castle_max_integrity(target) - before
                using_token = pl.repair_token >= 1
                bonus = 0
                if using_token:
                    bonus += int(VARIANT.get('repair_token_integrity', 3))
                if pl.lord == 'Kalligan' and pl.alive:
                    bonus += int(VARIANT.get('master_builder_integrity', 2))
                if self.breach == 'Kalligan':
                    bonus += int(VARIANT.get('rapid_construction_integrity', 1))
                # Stockpile — the Yard: banked materials are spent FIRST.
                # Cards cover only what the bank cannot.
                tok = 0
                if pl.construction_tokens > 0:
                    tok = min(pl.construction_tokens, max(0, missing - bonus))
                need_cards = max(0, missing - bonus - tok)
                if need_cards <= 0 and tok > 0:
                    # Bank alone covers it, but Repair still needs a legal
                    # payment: the Wright requirement is a card rule and
                    # tokens are not cards.
                    need_cards = 1
                paid = choose_payment_cards(repair_pool, max(1, need_cards))
                if not paid:
                    return
                if tok > 0:
                    pl.construction_tokens -= tok
                    _kit('tokens_spent_repair', tok)
                paid_value = sum(card.value for card in paid)
                for card in paid:
                    if card in pl.hand:
                        pl.hand.remove(card)
                    else:
                        pl.garrison.remove(card)
                self._discard(paid)
                healed = min(missing, paid_value + bonus + tok)
                pl.castle_integrity[target] = before + healed
                if using_token:
                    pl.repair_token = 0
                pl.castle_repairs[target] = pl.castle_repairs.get(target, 0) + 1
                pl.castle_action_used_this_round = True
                pl.repaired_this_round = True
                pl.repair_token_used_this_repair = using_token
                self.stat_castle_repaired += healed
                self.stat_castle_repair_actions += 1
                self.stat_repair_cards += len(paid)
                self.stat_repair_value += paid_value
                if pl.lord == 'Kalligan' and pl.alive:
                    pl.kalligan_repair_used = True
                    opponent = self.opp(pl.pid)
                    self.persist_scorch_pid = opponent.pid
                    self.persist_scorch_type = 'Lord'
                return

            progress_before = pl.castle_construction_progress.get(target, 0)
            remaining = castle_max_integrity(target) - progress_before
            cap = int(VARIANT.get('construction_action_cap', 0) or 0)
            request = min(remaining, cap) if cap > 0 else remaining
            paid = choose_payment_cards(payment_zone, request)
            if not paid:
                return
            paid_value = sum(card.value for card in paid)
            for card in paid:
                if card in pl.hand:
                    pl.hand.remove(card)
                else:
                    pl.garrison.remove(card)
            self._discard(paid)
            # Materials go in FIRST and count toward the SAME per-action cap
            # as cards, so the Yard cannot silently void construction_action_cap.
            allow = min(cap, remaining) if cap > 0 else remaining
            _t2 = min(pl.construction_tokens, allow)
            if _t2 > 0:
                pl.construction_tokens -= _t2
                _kit('tokens_spent_construct', _t2)
            gain = min(paid_value + _t2, allow)
            progress_after = min(castle_max_integrity(target), progress_before + gain)
            pl.castle_construction_progress[target] = progress_after
            pl.castle_action_used_this_round = True
            self.stat_construction_actions += 1
            self.stat_construction_value += paid_value
            if progress_after >= castle_max_integrity(target):
                pl.castles.add(target)
                pl.castle_integrity[target] = castle_max_integrity(target)
                pl.castle_construction_progress.pop(target, None)
                self.stat_castles_built += 1
                if self.stat_first_construction_round == 0:
                    self.stat_first_construction_round = self.round
            return

        if not pl.ruined_castles: return
        priority = CASTLE_PRIORITIES.get(pl.lord, CASTLES)
        target   = next((c for c in priority if c in pl.ruined_castles), None)
        if not target: return
        # Repair cost = flat Defense value of the castle.
        # All discounts stack; the floor of 1 is applied ONCE at the end (v5.29).
        cost = CASTLE_COST[target]
        if VARIANT.get('castle_scarring', False):
            cost = max(
                1,
                cost - pl.castle_scars.get(target, 0)
                * VARIANT.get('castle_scar_def', 2),
            )
        using_token = pl.repair_token >= 1
        if using_token:
            cost -= 3
            pl.repair_token = 0
        # Kalligan Master Builder: −5 per repair; first repair −7 instead
        if pl.lord == 'Kalligan' and pl.alive:
            cost -= 7 if not pl.kalligan_repair_used else 5
        # Breach — Rapid Construction
        if self.breach == 'Kalligan':
            cost -= 1
        cost = max(1, cost)
        cost += (
            VARIANT.get('repair_escalation', 0)
            * pl.castle_repairs.get(target, 0)
        )
        if sum(c.value for c in pl.hand + pl.garrison) < cost: return
        if (VARIANT.get('castle_scarring', False)
                or VARIANT.get('repair_escalation', 0)):
            worth = CASTLE_DEF[target] - (
                pl.castle_scars.get(target, 0)
                * VARIANT.get('castle_scar_def', 2)
            )
            available = sum(c.value for c in pl.hand + pl.garrison)
            if worth <= 1 or (cost > available * 0.5 and cost > 4):
                return
        self._pay(pl, cost)
        pl.ruined_castles.discard(target)
        pl.castles.add(target)
        # Keep disabled lab state out of canonical DE v2 snapshots.  The
        # history is meaningful only to scarring or escalation profiles.
        if (VARIANT.get('castle_scarring', False)
                or VARIANT.get('repair_escalation', 0)):
            pl.castle_repairs[target] = pl.castle_repairs.get(target, 0) + 1
        if VARIANT.get('castle_scarring', False):
            pl.castle_scars[target] = pl.castle_scars.get(target, 0) + 1
        pl.repaired_this_round = True
        pl.repair_token_used_this_repair = using_token  # deploy exception if token spent
        if pl.lord == 'Kalligan' and pl.alive:
            pl.kalligan_repair_used = True
            op = self.opp(pl.pid)
            # Wildfire: persistent Scorch token on repair — AI targets lord zone
            # after repair (applying pressure while defending)
            self.persist_scorch_pid  = op.pid
            self.persist_scorch_type = 'Lord'

    def _reserve_for_commitment(self, pl: Player) -> List[Card]:
        """
        Estimate which hand cards to hold back for this round's commitment.

        Logic mirrors _commit_for_attack/_commit_for_ward but runs during
        Deploy so that good cards are NOT sent to guard slots.

        Returns a list of card objects to reserve (not remove from hand).
        """
        op = self.opp(pl.pid)

        if not pl.alive:
            # Dead — will Ward with Penitents
            penitents = sorted([c for c in pl.hand if c.suit == 'Penitent'],
                               key=lambda c: c.value, reverse=True)[:2]
            low_for_bid = sorted([c for c in pl.hand if c not in penitents],
                                 key=lambda c: c.value)[:1]
            return penitents + low_for_bid

        plan = self._plan(pl, op)
        prof = LORD_AI.get(pl.lord, dict(aggro=1.0, control=1.0, prefer=''))

        h = self._score_hunt( pl, op, plan) * prof.get('aggro', 1.0)
        s = self._score_siege(pl, op, plan) * prof.get('aggro', 1.0)
        w = self._score_ward( pl, op, plan) * prof.get('control', 1.0)

        # ── Doctrine corrections. Ward was the only action with no Threat term
        # and no cost for repetition, so it won by default under pressure. The
        # bank term exists because attacking is the only way to unlock Recoil.
        w -= pl.threat * VARIANT['doctrine_ward_threat']
        w -= getattr(pl, 'consecutive_wards', 0) * VARIANT['doctrine_ward_stagnation']
        _bank = getattr(pl, 'odradek_bank', None)
        if VARIANT['odr_recoil_bank'] and pl.lord == 'Odradek' and _bank is not None:
            _urg = VARIANT['doctrine_bank_urgency'] * _bank.value
            h += _urg; s += _urg; w -= _urg * 0.5

        pref = prof.get('prefer', '')
        if pref == 'Hunt':  h += 0.25
        if pref == 'Siege': s += 0.25
        if pref == 'Ward':  w += 0.25

        best = max((h, 'Hunt'), (s, 'Siege'), (w, 'Ward'))[1]

        # ── Ward reservation ──────────────────────────────────────────
        if best == 'Ward' or (best == 'Hunt' and not op.alive) or (best == 'Siege' and not op.castles):
            penitents = sorted([c for c in pl.hand if c.suit == 'Penitent'],
                               key=lambda c: c.value, reverse=True)[:2]
            low_for_bid = sorted([c for c in pl.hand if c not in penitents],
                                 key=lambda c: c.value)[:1]
            return penitents + low_for_bid

        # ── Attack reservation: use the same estimate final commitment uses.
        attack_target_type = 'Lord' if best == 'Hunt' else 'Castle'
        est_def, _ = self._estimate_attack_defense(
            pl, op, attack_target_type, context=f'reserve:{pl.pid}')
        if attack_target_type == 'Lord' and op.lord == 'Odradek':
            est_def += 4   # rough reserve hedge; exact Recoil padding happens at commit

        plan_pad = 2 if plan in ('deny_ritual', 'deny_dominion') else 1
        target_str = max(3, est_def + plan_pad)

        # ── Select cards to reserve ───────────────────────────────────
        butchers = sorted([c for c in pl.hand if c.suit == 'Butcher'],
                          key=lambda c: c.value, reverse=True)
        others   = sorted([c for c in pl.hand if c.suit != 'Butcher'],
                          key=lambda c: c.value, reverse=True)

        reserved = []
        total    = 0

        # Grab Butcher pair first for suit bonus
        want_bonus = pl.lord in ('Deimos', 'Orias', 'Gremory') or plan.startswith('deny')
        if want_bonus and len(butchers) >= 2:
            for c in butchers[:2]:
                reserved.append(c); total += effective_attack_value(pl, c, attack_target_type)
            butchers = butchers[2:]

        # Fill to target Strength with remaining cards (highest first)
        for c in butchers + others:
            if total >= target_str: break
            reserved.append(c); total += effective_attack_value(pl, c, attack_target_type)

        # Reserve 1 low card for bid from whatever is left
        non_reserved_low = sorted([c for c in pl.hand if c not in reserved],
                                  key=lambda c: c.value)
        if non_reserved_low:
            reserved.append(non_reserved_low[0])

        return reserved

    def _gain_threat(self, pl: 'Player', n: int = 1) -> int:
        """Single chokepoint for every Threat gain.

        SummoningCircle — Blood Conduit: Exert 3 to prevent 1 Threat, but ONLY
        when it stops a crossing of a Lord-DEF breakpoint (2, 3 or 4). Preventing
        0->1 buys nothing, and a doctrine that fires on every gain is exactly the
        §3 failure where overuse makes an ability look good.
        """
        if n > 0 and VARIANT.get('circle_blood_conduit', False) \
                and pl.castle_power_active('SummoningCircle'):
            before = pl.threat
            after = min(MAX_THREAT, before + n)
            crosses = after >= 2 and after > before
            if crosses:
                _kit('circle_opportunity')
                cost = int(VARIANT.get('circle_conduit_cost', 3))
                if pl.can_exert('SummoningCircle', cost):
                    pl.exert('SummoningCircle', cost, game=self, reason='conduit')
                    _kit('circle_activation'); _kit('circle_integrity_spent', cost)
                    n -= 1
                else:
                    _kit('circle_short')
        pl.threat = min(MAX_THREAT, pl.threat + n)
        return pl.threat

    def _run_draw_step(self, pl: 'Player') -> None:
        """Normal Draw Step plus Stockpile Selective Stores.

        Operational Stockpile replaces the historical raw +1 draw with
        draw 2 / keep 1 / discard 1. This seam mirrors live Godot and keeps
        the locked rule directly regression-testable.
        """
        has_stock = pl.castle_power_active('Stockpile')
        filt = has_stock and VARIANT.get('stockpile_filter', False)
        n = 5 + (0 if filt else (1 if has_stock else 0))
        for _ in range(n):
            self._draw(pl)
        if not filt:
            return
        _kit('stockpile_opportunity')
        before = len(pl.hand)
        self._draw(pl); self._draw(pl)
        drawn = pl.hand[before:]
        if len(drawn) != 2:
            return
        keep = self._stockpile_pick(pl, drawn)
        drop = drawn[0] if keep is drawn[1] else drawn[1]
        pl.hand.remove(drop)
        self._discard([drop])
        _kit('stockpile_activation')
        if keep.suit != drop.suit:
            _kit('stockpile_suit_swing')

    def _stockpile_pick(self, pl: 'Player', drawn: list):
        """Which of two drawn cards to keep. Wright and Butcher are gated
        resources now; a card that unblocks Repair or restores attack value is
        worth more than a higher printed number."""
        have_wright = any(c.suit == 'Wright' for c in pl.hand if c not in drawn)
        def score(c):
            s = c.value
            if c.suit == 'Wright' and not have_wright:
                s += 4          # unblocks Repair entirely
            elif c.suit == 'Butcher':
                s += int(VARIANT.get('attack_offsuit_penalty', 0) or 0)
            return s
        return max(drawn, key=score)

    def _deploy_guards(self, pl: Player):
        self._deploy_guards_inner(pl)
        self._march_launch(pl)

    def _deploy_guards_inner(self, pl: Player):
        max_lg = pl.max_lord_guards()
        max_cg = pl.max_castle_guards()

        # Frenzy: Orias Breach OR Veil track >= 6 (not immune)
        frenzy_active = (self.breach == 'Orias') or (
            self._threshold_active(6) and not self._immune_to_threshold(pl, 6))
        frenzy_blocked = frenzy_active and pl.threat >= 3

        # Base garrison limit
        garrison_limit = GARRISON_MAX

        # Orias Snare — restrict ALL guard movement to max 1 total
        # (hand→guards, garrison→guards, and between-zone moves all count)
        snare_active = pl.orias_snare_active
        snare_guards_moved = 0  # track total guard moves under Snare
        if snare_active:
            garrison_limit = min(garrison_limit, 1)

        # Frenzy overrides: no garrison→guard
        if frenzy_blocked:
            garrison_limit = 0

        # ── Repair deploy restriction ─────────────────────────────────────────
        # If repaired this round without spending a Repair token: cannot deploy
        # from hand→guards. Garrison→guards still allowed.
        # Spending a Repair token during repair overrides this restriction.
        repair_restricts_hand_deploy = (
            pl.repaired_this_round and not pl.repair_token_used_this_repair
        )

        # ── Step 1: decide what to keep in hand for combat ────────────
        reserved     = self._reserve_for_commitment(pl)
        reserved_ids = set(id(c) for c in reserved)

        # ── Snare: ONE total guard move — spend it where the threat is ──
        if snare_active:
            op = self.opp(pl.pid)
            want_lord = ((op.lord == 'Orias' or pl.was_hunted or op.alive)
                         and len(pl.lord_guards) < max_lg and pl.alive
                         and not frenzy_blocked)
            # Source: best garrison card; else best non-reserved hand card
            src_card = None; from_hand = False
            if pl.garrison:
                src_card = max(pl.garrison, key=lambda c: c.value)
            if not src_card and not repair_restricts_hand_deploy:
                cands = [c for c in pl.hand if id(c) not in reserved_ids]
                if cands:
                    src_card = max(cands, key=lambda c: c.value); from_hand = True
            if src_card is not None:
                zone = pl.lord_guards if want_lord else (
                    pl.castle_guards if len(pl.castle_guards) < max_cg else pl.lord_guards)
                target_ok = (zone is pl.castle_guards and len(pl.castle_guards) < max_cg) or \
                            (zone is pl.lord_guards and len(pl.lord_guards) < max_lg
                             and not (zone is pl.lord_guards and frenzy_blocked and not from_hand))
                if target_ok:
                    src_card.guard_revealed = False
                    zone.append(src_card)
                    if from_hand: pl.hand.remove(src_card)
                    else:         pl.garrison.remove(src_card)
            return   # one move total — Deploy ends here under Snare

        # ── Step 2: deploy GARRISON → guards first ────────────────────
        # Garrison can't be committed; always worth deploying
        garrison_moves = 0
        pl.garrison.sort(key=lambda c: c.value, reverse=True)
        while (len(pl.castle_guards) < max_cg and pl.garrison
               and garrison_moves < garrison_limit):
            _guard = pl.garrison.pop(0)
            _guard.guard_revealed = False
            pl.castle_guards.append(_guard)
            garrison_moves += 1

        # ── Step 3: deploy LOW-value non-reserved hand cards ──────────
        # Sort ASCENDING — chaff to guards, power stays for offense
        # Skip hand→guards if repair restricts it
        # Snare caps total guard moves from all sources to 1
        # Chaff to guards — but under the Vulture tax "chaff" means lowest
        # DEFENSIVE worth, not lowest printed value. A Butcher 3 walls for 2;
        # a Vulture 2 also walls for 2. Send the one that defends worse.
        _dep_ex = (VARIANT.get('circle_ignores_guard_tax', False)
                   and pl.castle_power_active('SummoningCircle'))
        if not repair_restricts_hand_deploy:
            deployable = sorted(
                [c for c in pl.hand if id(c) not in reserved_ids],
                key=lambda c: (effective_guard_value(c, _dep_ex), c.value)
            )
            for c in deployable:
                if len(pl.castle_guards) >= max_cg: break
                if snare_active and snare_guards_moved >= 1: break
                c.guard_revealed = False
                pl.castle_guards.append(c)
                pl.hand.remove(c)
                snare_guards_moved += 1

        castle_full = len(pl.castle_guards) >= max_cg

        # ── Step 4: lord guards — garrison first (if castle full) ─────
        if castle_full and not frenzy_blocked:
            pl.garrison.sort(key=lambda c: c.value, reverse=True)
            while (len(pl.lord_guards) < max_lg and pl.garrison
                   and garrison_moves < garrison_limit):
                if snare_active and snare_guards_moved >= 1: break
                _guard = pl.garrison.pop(0)
                _guard.guard_revealed = False
                pl.lord_guards.append(_guard)
                garrison_moves += 1
                snare_guards_moved += 1

        # Fill lord guards from low-value non-reserved hand
        if not repair_restricts_hand_deploy:
            deployable2 = sorted(
                [c for c in pl.hand if id(c) not in reserved_ids],
                key=lambda c: (effective_guard_value(c, _dep_ex), c.value)
            )
            for c in deployable2:
                if len(pl.lord_guards) >= max_lg: break
                if snare_active and snare_guards_moved >= 1: break
                c.guard_revealed = False
                pl.lord_guards.append(c)
                pl.hand.remove(c)
                snare_guards_moved += 1

    def _suit_adv(self, attacker_suit: str, defender_suit: str) -> bool:
        return SUIT_BEATS.get(attacker_suit, '') == defender_suit

    def _is_marshal(self, marcher: dict) -> bool:
        card = marcher['card']
        return (VARIANT.get('march_exception_pair', True)
                and card.suit == 'Vulture' and card.value == 5)

    def _is_spy(self, marcher: dict) -> bool:
        card = marcher['card']
        return (VARIANT.get('march_exception_pair', True)
                and card.suit == 'Butcher' and card.value == 1)

    def _march_launch(self, pl: Player):
        """Launch one bot-selected Guard after normal deployment settles."""
        if not VARIANT.get('marching', False):
            return

        op = self.opp(pl.pid)
        base_cap = VARIANT.get('march_max_in_flight', 1)
        reactive_lane = ''
        if (ACTIVE_FEATURES['humbaba_reactive_lane']
                and pl.lord == 'Humbaba'
                and len(pl.marchers) == base_cap
                and op.marchers):
            enemy_lanes = {marcher['lane'] for marcher in op.marchers}
            own_lanes = {marcher['lane'] for marcher in pl.marchers}
            reactive_lane = next(
                (lane for lane in ('Lord', 'Castle')
                 if lane in enemy_lanes and lane not in own_lanes),
                '',
            )

        cap = base_cap + (1 if reactive_lane else 0)
        if len(pl.marchers) >= cap:
            return

        threshold = VARIANT.get('march_threshold', 3)
        threat = (
            next(
                (marcher for marcher in op.marchers
                 if marcher['lane'] == reactive_lane),
                None,
            )
            if reactive_lane
            else next(
                (marcher for marcher in op.marchers
                 if marcher['value'] >= threshold),
                None,
            )
        )
        candidates = []

        for zone, guards in (
                ('Lord', pl.lord_guards),
                ('Castle', pl.castle_guards)):
            for card in guards:
                if len(guards) <= 1:
                    continue

                score = 0.0
                if card.value < threshold:
                    if threat is None:
                        continue
                    damage = VARIANT.get('march_damage', 2)
                    if self._suit_adv(card.suit, threat['card'].suit):
                        damage += VARIANT.get('march_suit_bonus', 1)
                    if self._is_marshal(threat):
                        score += 4.0 if self._is_spy({'card': card}) else -5.0
                    elif threat['value'] - damage < threshold:
                        score += 1.6
                    else:
                        score += 0.2
                    score -= card.value * 0.05
                else:
                    if card.value - VARIANT.get('march_damage', 2) >= threshold:
                        score += 2.0
                    else:
                        score += 0.7
                    if self._is_marshal({'card': card}):
                        score += 3.0

                if zone == 'Lord' and pl.threat >= 2:
                    score -= 0.8
                if zone == 'Castle' and len(pl.castles) <= 2:
                    score -= 0.5
                candidates.append((score, zone, card))

        if not candidates:
            return
        score, zone, card = max(candidates, key=lambda entry: entry[0])
        if score <= 0:
            return

        if reactive_lane:
            lane = reactive_lane
        else:
            wants_contact = (
                card.value < threshold
                or card.value - VARIANT.get('march_damage', 2) >= threshold
            )
            enemy_lanes = {marcher['lane'] for marcher in op.marchers}
            if enemy_lanes:
                occupied = sorted(enemy_lanes)[0]
                other = 'Castle' if occupied == 'Lord' else 'Lord'
                lane = occupied if wants_contact else other
            else:
                lane = zone

        if any(marcher['lane'] == lane for marcher in pl.marchers):
            return

        guards = pl.lord_guards if zone == 'Lord' else pl.castle_guards
        guards.remove(card)
        pl.marchers.append({
            'card': card,
            'value': card.value,
            'lane': lane,
            'pos': 0,
        })

    def _march_advance(self):
        """Advance lanes after Resolution: clash, destroy, then score arrivals."""
        if not VARIANT.get('marching', False):
            return

        for pl in self.players:
            for marcher in pl.marchers:
                marcher['pos'] += 1

        p0, p1 = self.players
        for lane in ('Lord', 'Castle'):
            first = next((m for m in p0.marchers if m['lane'] == lane), None)
            second = next((m for m in p1.marchers if m['lane'] == lane), None)
            if first is None or second is None:
                continue

            if ((self._is_marshal(first) and self._is_spy(second))
                    or (self._is_marshal(second) and self._is_spy(first))):
                first['value'] = 0
                second['value'] = 0
            elif self._is_marshal(first) or self._is_marshal(second):
                # The Marshal evades ordinary collision; both keep moving.
                pass
            else:
                base_damage = VARIANT.get('march_damage', 2)
                suit_bonus = VARIANT.get('march_suit_bonus', 1)
                first_damage = base_damage
                second_damage = base_damage
                if self._suit_adv(second['card'].suit, first['card'].suit):
                    first_damage += suit_bonus
                if self._suit_adv(first['card'].suit, second['card'].suit):
                    second_damage += suit_bonus
                first['value'] -= first_damage
                second['value'] -= second_damage

        for pl in self.players:
            survivors = []
            for marcher in pl.marchers:
                if marcher['value'] <= 0:
                    if VARIANT.get('lane_kill_soul', False):
                        self._gain_soul(self.opp(pl.pid), 1)
                    self._discard([marcher['card']])
                    continue
                if marcher['pos'] >= VARIANT.get('march_steps', 3):
                    if marcher['value'] >= VARIANT.get('march_threshold', 3):
                        self._gain_tear(pl, 'marching')
                    self._discard([marcher['card']])
                    continue
                survivors.append(marcher)
            pl.marchers = survivors

        self._check_win()

    def _refresh_market_offers(self) -> None:
        """Roll v6.5's unclaimed offers into the bottom of the deck.

        The setup Market remains available in round one.  Beginning in round
        two, the public row receives three fresh offers before either player
        makes a swap.  Prior offers are not discarded—the Market is a rotating
        window, not a source of free discard-pile fuel for Gremory.
        """
        if not ACTIVE_FEATURES['market_refresh'] or self.round <= 1:
            return

        rolled_offers = list(self.market)
        self.market.clear()

        # Draw the replacement row before returning the old offers below the
        # deck.  If the deck is exhausted, `_take_top_card` recycles discard
        # exactly as a normal draw would; the old row cannot mask that recycle.
        # Only an entirely exhausted game has to reuse its own old offers.
        reused_rolled_offer = False
        while len(self.market) < MARKET_SIZE:
            card = self._take_top_card()
            if card is None:
                if reused_rolled_offer:
                    break
                for rolled_offer in rolled_offers:
                    self.deck.insert(0, rolled_offer)
                reused_rolled_offer = True
                continue
            self.market.append(card)

        if not reused_rolled_offer:
            for card in rolled_offers:
                self.deck.insert(0, card)

    def _ai_market(self, pl: Player):
        if not self.market or not pl.hand: return
        if self.rng.stream(f'market:{pl.pid}:{self.round}').random() < 0.5:
            best_market = max(self.market, key=lambda c: c.value)
            worst_hand  = min(pl.hand,     key=lambda c: c.value)
            if best_market.value > worst_hand.value:
                self.market.remove(best_market)
                pl.hand.remove(worst_hand)
                pl.hand.append(best_market)
                self.market.append(worst_hand)   # swapped card joins the Market

    # ─────────────────────────────────────────────────────────────────
    #  AI — BID / ACTION / COMMIT
    # ─────────────────────────────────────────────────────────────────
    def _ai_bid(self, pl: Player) -> List[Card]:
        if not pl.hand: return []
        op   = self.opp(pl.pid)
        prof = LORD_AI.get(pl.lord, dict(control=1.0))
        plan = self._plan(pl, op)

        want_cards = 1
        if plan in ('deny_ritual', 'deny_dominion'):          want_cards = 2
        if prof.get('control', 1.0) >= 1.25 and self.rng.stream(f'bid:{pl.pid}:{self.round}').random() < 0.6:
            want_cards = max(want_cards, 2)
        if pl.alive and pl.souls >= WIN_SOULS - 1 and self.rng.stream(f'bid:{pl.pid}:{self.round}').random() < 0.8:
            want_cards = max(want_cards, 2)

        want_cards = min(want_cards, 3, len(pl.hand))
        pl.hand.sort(key=lambda c: c.value)
        bid = pl.hand[:want_cards]
        for c in bid: pl.hand.remove(c)
        return bid

    def _ai_choose_action(self, pl: Player):
        op = self.opp(pl.pid)

        if not pl.alive:
            pl.action = 'Ward'; pl.ward_target = 'Castle'
            self._commit_for_ward(pl, 'neutral')
            return

        prof = LORD_AI.get(pl.lord, dict(aggro=1.0, control=1.0, risk=1.0, prefer=''))
        plan = self._plan(pl, op)

        h = self._score_hunt( pl, op, plan) * prof['aggro']
        s = self._score_siege(pl, op, plan) * prof['aggro']
        w = self._score_ward( pl, op, plan) * prof['control']

        caution = max(0.0, 1.0 - prof.get('risk', 1.0))
        h -= pl.threat * caution * 0.9
        s -= pl.threat * caution * 0.5

        # ── Doctrine corrections. Ward was the only action with no Threat term
        # and no cost for repetition, so it won by default under pressure. The
        # bank term exists because attacking is the only way to unlock Recoil.
        w -= pl.threat * VARIANT['doctrine_ward_threat']
        w -= getattr(pl, 'consecutive_wards', 0) * VARIANT['doctrine_ward_stagnation']
        _bank = getattr(pl, 'odradek_bank', None)
        if VARIANT['odr_recoil_bank'] and pl.lord == 'Odradek' and _bank is not None:
            _urg = VARIANT['doctrine_bank_urgency'] * _bank.value
            h += _urg; s += _urg; w -= _urg * 0.5

        pref = prof.get('prefer', '')
        if pref == 'Hunt':  h += 0.25
        if pref == 'Siege': s += 0.25
        if pref == 'Ward':  w += 0.25

        _prng = self.rng.stream(f'action-score:{pl.pid}:{self.round}')
        h += _prng.uniform(-0.25, 0.25)
        s += _prng.uniform(-0.25, 0.25)
        w += _prng.uniform(-0.25, 0.25)

        # ── Profane (Siege + own color) — sacrifice a Castle for a Tear.
        # Risk: cancelled by an opponent Fresh Sigil placed this round.
        p_score = -5.0
        profanable = [c for c in pl.castles if profane_eligible(pl, c)]
        can_profane = VARIANT.get('profane_action_enabled', True) and bool(profanable) and (
            VARIANT.get('profane_no_castle_gate', False)
            or len(pl.castles) >= 3
        )
        if can_profane:
            soul_deficit = op.souls - pl.souls
            tear_lead    = pl.tears - op.tears
            p_score = 0.0
            if soul_deficit >= 2:                 p_score += float(VARIANT.get('profane_soul_deficit_bonus', 1.6))
            if pl.tears >= 2 and tear_lead >= 1:  p_score += 1.8
            if plan in ('race_dominion',):        p_score += 1.2
            if plan == 'deny_dominion':           p_score -= 1.0
            if plan == 'deny_ritual':             p_score -= 2.0
            if pl.lord == 'Humbaba':
                p_score -= 2.5   # profaning his own stones guts his defense
            if VARIANT['ai_dominion_drive']:
                p_score += 0.9                                # value the Tear economy
                if len(pl.castles) >= 4:          p_score += 0.5
                if op.alive and op.lord == 'Odradek': p_score += 0.8  # starve the Recoil engine
            p_score += _prng.uniform(-0.25, 0.25)

        # ── Chip doctrine ──
        chip_siege = False
        if op.alive and op.castles and op.castle_guards:
            # Token denial: any guard defeat shuts Reconfiguration off this round.
            # HUMBABA-ONLY doctrine: a universal chip bonus proved toxic — it
            # replaced lethal pressure across the whole roster and left
            # Odradek's Lord unthreatened (v: chip-meta experiment).
            if op.lord == 'Odradek' and VARIANT['reconfig_strict'] and pl.lord == 'Humbaba':
                chip_siege = True
                if True:
                    # Alternating doctrine: chip while his Sigils stand (Patient
                    # Hunger only preserves on passive rounds — so chip on the
                    # rounds where the walls can afford one update unattended),
                    # ward when the Sigils have decayed away.
                    sigils_standing = ('fresh' in pl.sigils.values()
                                       or 'flipped' in pl.sigils.values())
                    if sigils_standing and op.tears + 1 >= self._dominion_req() - 1:
                        s += 4.0    # denial is now mandatory
                    elif sigils_standing:
                        s += 2.2
                    else:
                        s -= 0.5    # rebuild the walls first
            # Kroni anti-wall: farm Hunger off cheap guard kills, stop feeding sigils
            if pl.lord == 'Kroni' and op.lord == 'Humbaba':
                s += 1.2
                chip_siege = True

        best = max((h, 'Hunt'), (s, 'Siege'), (w, 'Ward'), (p_score, 'Profane'))[1]

        if best == 'Hunt' and op.alive:
            pl.action = 'Hunt'; pl.tgt_pid = op.pid; pl.tgt_type = 'Lord'
            self._commit_for_attack(pl, op, 'Lord', plan)
        elif best == 'Siege' and op.castles:
            pl.action = 'Siege'; pl.tgt_pid = op.pid; pl.tgt_type = 'Castle'
            self._commit_for_attack(pl, op, 'Castle', plan, chip=chip_siege)
        elif best == 'Profane' and can_profane:
            pl.action = 'Profane'
            eligible = [c for c in pl.castles if profane_eligible(pl, c)]
            if VARIANT.get('castle_owner_doctrine', 'strategic') == 'legacy':
                priority = CASTLE_PRIORITIES.get(pl.lord, CASTLES)
                pl.pending_profane = next(
                    (c for c in reversed(priority) if c in eligible),
                    sorted(eligible)[0])
            else:
                pl.pending_profane = min(
                    eligible,
                    key=lambda c: (self._castle_strategic_value(pl, c), c))
            # Profane needs no Strength — commit nothing
            pl.committed = []
        else:
            pl.action = 'Ward'
            # A threshold Ward must be a read, not a deterministic zone-cycle.
            if VARIANT.get('ward_read', False):
                _wrng = self.rng.stream(f'ward-read:{pl.pid}:{self.round}')
                if _wrng.random() < WARD_READ_CONFIDENCE:
                    pl.ward_target = self._ward_read_zone(pl, op)
                else:
                    pl.ward_target = _wrng.choice(['Lord', 'Castle'])
            elif plan == 'deny_ritual' and pl.prev_ward_target != 'Lord':
                pl.ward_target = 'Lord'
            else:
                want_lord = (pl.souls >= 2) or (pl.threat >= 2)
                pl.ward_target = 'Lord' if want_lord else 'Castle'
                if (VARIANT.get('ward_anti_repeat', True)
                        and pl.ward_target == pl.prev_ward_target):
                    pl.ward_target = 'Castle' if pl.ward_target == 'Lord' else 'Lord'
            self._commit_for_ward(pl, plan)

    def _ward_read_zone(self, pl: Player, op: Player) -> str:
        """Predict the opponent's next attack door from public information."""
        profile = LORD_AI.get(op.lord, {})
        lord_score = 0.0
        castle_score = 0.0
        preferred = profile.get('prefer', '')
        if preferred == 'Hunt':
            lord_score += WARD_READ_PREF
        elif preferred == 'Siege':
            castle_score += WARD_READ_PREF

        if op.alive and pl.threat >= 2:
            lord_score += 0.5
        if pl.castles:
            castle_score += 0.35
        if pl.was_lord_attacked_prev:
            lord_score += 0.35
        if pl.was_castle_attacked_prev:
            castle_score += 0.35

        if VARIANT.get('adaptive_doctrine', False):
            memory = self.action_memory[op.pid]
            rate = ADAPT_RATE.get(pl.lord, 1.0)
            lord_score += memory.get('Hunt', 0.0) * rate * 0.8
            castle_score += memory.get('Siege', 0.0) * rate * 0.8

        return 'Lord' if lord_score >= castle_score else 'Castle'

    def _attack_tax_factor(self, pl: 'Player', target_type: str) -> float:
        """Fraction of hand value available to this specific attack type."""
        raw = sum(c.value for c in pl.hand)
        if raw <= 0:
            return 1.0
        return sum(effective_attack_value(pl, c, target_type)
                   for c in pl.hand) / raw

    def _score_hunt(self, pl: Player, op: Player, plan: str) -> float:
        if not op.alive: return -5.0
        score = HUNT_BASE if VARIANT.get('fix_a', False) else 1.8
        score += op.threat * 0.55
        score -= pl.threat * 0.20
        if pl.threat >= 3:  score -= 2.5
        elif pl.threat == 2: score -= 0.9
        if op.lord == 'Orias' and op.alive and pl.threat >= 1: score -= 1.5
        if plan == 'deny_ritual':    score += 2.8
        if plan == 'protect_souls':  score -= 0.6
        if plan == 'pressure_souls': score += 0.8
        if pl.lord == 'Orias':
            score += 1.1   # +1 baseline Marked Prey
            op_inst = self.opp(pl.pid)
            if op_inst.alive and op_inst.threat >= 2:
                score += 0.5  # Barbed Web fires at +2 — escalation window open
        if pl.lord == 'Gremory': score += 0.4
        if pl.lord == 'Valak' and pl.souls < 2: score += 0.7
        # Kroni: hunting becomes more attractive at higher Hunger
        # At Hunger 3+ each successful attack also generates a Tear
        if pl.lord == 'Kroni':  score += min(1.2, pl.kroni_hunger * 0.4)
        if op.lord == 'Odradek':
            # Fear calibrated to the CURRENT recoil, not the pre-errata one:
            # under hunts-only + strips-lowest, hunting him is a fair trade.
            harsh = not (VARIANT['recoil_hunts_only'] and VARIANT['recoil_lowest'])
            score -= 0.3 if not harsh else 0.9
            if VARIANT['ai_dominion_drive'] and harsh:
                score -= 0.9

        # Odradek: at Threat 3+ becomes an aggressive attacker
        # Orias: Relentless Pursuit gives clean hunt vs marked lord — no Recoil cost
        if pl.lord == 'Orias' and self.orias_marked_lord == op.lord:
            score += 0.5
        if pl.lord == 'Odradek': score -= 0.1   # Odradek prefers Ward
        if (VARIANT.get('ward_threshold', False)
                and op.prev_ward_target != 'Lord'):
            score -= HUNT_W1_PENALTY
        score += self._attack_feasibility_adjustment(pl, op, 'Lord')
        # Easy resummon reduces the strategic value of a Banishment.
        if op.castle_power_active('SummoningCircle') and (
                VARIANT.get('circle_ignores_delay', False)
                or int(VARIANT.get('circle_discount', 0) or 0) > 0
                or VARIANT.get('circle_swift_return', False)):
            score -= 0.35
        return score * self._attack_tax_factor(pl, 'Lord')

    def _score_siege(self, pl: Player, op: Player, plan: str) -> float:
        if not op.castles: return -5.0
        score = 0.333 if VARIANT.get('fix_a', False) else 1.0
        score += len(op.castles) * 0.25
        if plan == 'deny_dominion': score += 3.0
        if plan == 'race_dominion': score += 1.2
        if op.lord == 'Orias' and op.alive and pl.threat >= 1: score += 1.2
        if pl.threat >= 2: score += 0.5
        if pl.threat >= 3: score += 0.6
        if pl.lord == 'Deimos':   score += 1.0
        if pl.lord == 'Kalligan': score += 0.8   # now has +1 baseline from Pyroclasm
        if pl.lord == 'Gremory':  score += 0.7
        if pl.lord == 'Kalligan' and pl.alive and self.opp(pl.pid).ruined_castles:
            score += 0.5
        # Siege advances Veil track — bonus if we're ahead on personal tears
        op = self.opp(pl.pid)
        if pl.tears > op.tears: score += 0.3
        if (VARIANT.get('ward_threshold', False)
                and op.prev_ward_target != 'Castle'):
            score -= HUNT_W1_PENALTY
        score += self._attack_feasibility_adjustment(pl, op, 'Castle')
        # Valuable live enemy engines make Siege strategically meaningful.
        score += min(0.8, sum(self._castle_strategic_value(op, c)
                              for c in op.castles) * 0.10)
        return score * self._attack_tax_factor(pl, 'Castle')

    def _score_ward(self, pl: Player, op: Player, plan: str) -> float:
        if VARIANT.get('fix_a', False):
            score = 0.333
            score += pl.souls * 0.12
            score += castle_board_fraction(len(pl.castles)) * 0.40
            score += pl.threat * 0.20
        else:
            score = 0.6
            score += pl.souls * 0.55
            score += len(pl.castles) * 0.30
            score += pl.threat * 0.35
        if pl.threat >= 2: score += 0.6
        if pl.threat >= 3: score += 0.8
        if plan == 'protect_souls': score += 1.0
        if plan == 'deny_ritual':   score += 0.7
        if plan in ('deny_dominion', 'race_dominion'): score += 0.4
        if pl.lord == 'Kroni':   score += 0.5   # survive to scale
        if pl.lord == 'Odradek': score += 0.8   # Ward: make opponents commit to stripping 2+ guards
        # Penitent tax — the Ward is only as good as the suits you hold.
        # Without this, action selection Wards just as often while the resolver
        # quietly pays the tax: the rule fires but the bot never declines it (§3).
        pen = int(VARIANT.get('ward_offsuit_penalty', 0) or 0)
        if pen > 0 and not (VARIANT.get('keep_ignores_ward_tax', False)
                            and pl.castle_power_active('Keep')):
            raw = sum(c.value for c in pl.hand)
            if raw > 0:
                eff = sum(effective_ward_value(pl, c) for c in pl.hand)
                # Scale Ward's appeal by how much of your hand survives the tax.
                score *= (eff / raw)
                _kit('ward_tax_priced')

        if VARIANT.get('ward_threshold', False):
            incoming = 0.0
            if op.alive:
                incoming += 0.5
            if pl.castles:
                incoming += 0.4
            if pl.souls >= WIN_SOULS - 2:
                incoming += 0.6
            if pl.threat >= 2:
                incoming += 0.5
            if sum(card.value for card in pl.hand) < 4:
                incoming *= 0.3
            score += incoming * WARD_INCOMING_WEIGHT
        return score

    def _est_guards(self, guards: List[Card], viewer_knows: bool = False,
                    exempt: bool = False, context: str = 'generic') -> int:
        if not guards:
            return 0
        if viewer_knows or not VARIANT.get('fog_of_war', False):
            return sum(effective_guard_value(c, exempt) for c in guards)

        known = [c for c in guards if getattr(c, 'guard_revealed', False)]
        unknown_count = len(guards) - len(known)
        known_total = sum(effective_guard_value(c, exempt) for c in known)
        if unknown_count <= 0:
            return known_total

        estimate = unknown_count * DECK_MEAN_VALUE
        # Context+round streams make reserve/score/commit repeatable without one
        # probe consuming the noise intended for another doctrine layer.
        estimate += self.rng.stream(
            f'fog:{context}:{self.round}'
        ).gauss(0.0, FOG_NOISE * unknown_count ** 0.5)
        return known_total + max(unknown_count, int(round(estimate)))

    def _estimate_attack_defense(self, atk: Player, dfn: Player,
                                 target_type: str, *, context: str,
                                 target_castle: Optional[str] = None) -> Tuple[int, Optional[str]]:
        """One doctrine estimate used by reserve, action scoring and commit.

        It includes the *actual* defensive consequences of Castle powers. In
        particular, Sanctuary adds the excess needed to overwhelm the Keep and
        Fortified Bastion adds the wall that must be crossed before a rear Castle.
        """
        guard_exempt = (VARIANT.get('circle_ignores_guard_tax', False)
                        and dfn.castle_power_active('SummoningCircle'))
        if target_type == 'Lord':
            est = dfn.lord_base_def(breach=self.breach)
            est += self._est_guards(
                dfn.lord_guards, exempt=guard_exempt, context=f'{context}:lord')
            est += max(2, self._sigil_value(dfn, dfn.sigils['Lord']))
            if VARIANT.get('keep_sanctuary', False) and dfn.castle_power_active('Keep'):
                keep_hp = dfn.castle_integrity.get('Keep', castle_max_integrity('Keep'))
                # Sanctuary transfers exact excess and may self-spend only while at
                # least 1 Integrity remains. Thus keep_hp-1 additional excess is
                # the maximum amount it can currently absorb.
                est += max(0, keep_hp - 1)
            if atk.lord == 'Orias':
                est -= 1
                if dfn.threat >= 2:
                    est -= 1
            return max(0, est), None

        target = target_castle or self._pick_siege_target(atk, dfn)
        _forced_wall = (
            VARIANT.get('bastion_fortified', False)
            and 'Bastion' in dfn.castles
            and 'Bastion' not in dfn.disabled_castle_powers
            and dfn.castle_integrity.get('Bastion', 0) > 0
            and target != 'Bastion'
        )
        # A rear-target Siege must budget for BOTH the chosen rear structure
        # and the standing Bastion that physically intercepts it. The earlier
        # contextual-v2 lab accidentally replaced rear DEF with Bastion HP,
        # which made doctrine underfund exactly the wall it was meant to see.
        est = dfn.castle_def(target, breach=self.breach)
        if _forced_wall:
            _bhp = dfn.castle_integrity.get('Bastion', castle_max_integrity('Bastion'))
            if str(context).startswith('score:'):
                est += min(_bhp, max(1, int(VARIANT.get('bastion_wall_chip_target', 4) or 4)))
            else:
                est += _bhp
        bypass = (VARIANT.get('siege_engine_bypass', False)
                  and atk.castle_power_active('SiegeEngine'))
        if not bypass:
            est += self._est_guards(
                dfn.castle_guards, exempt=guard_exempt, context=f'{context}:castle')
        est += max(1, self._sigil_value(dfn, dfn.sigils['Castle']))
        if _forced_wall and not str(context).startswith('score:'):
            est += int(VARIANT.get('bastion_overflow_mitigation', 0) or 0)
        if atk.lord == 'Deimos' and atk.castle_power_active('SiegeEngine'):
            est -= max(0, 2 - len(atk.ruined_castles) - len(atk.profaned_castles))
        if atk.lord == 'Kalligan':
            est -= 2 if dfn.ruined_castles else 1
        return max(0, est), target

    def _attack_feasibility_adjustment(self, atk: Player, dfn: Player,
                                       target_type: str) -> float:
        """Action-selection correction for whether the hand can fund the attack."""
        if target_type == 'Lord' and not dfn.alive:
            return -5.0
        if target_type == 'Castle' and not dfn.castles:
            return -5.0
        need, _ = self._estimate_attack_defense(
            atk, dfn, target_type, context=f'score:{atk.pid}:{target_type}')
        capacity = sum(effective_attack_value(atk, c, target_type) for c in atk.hand)
        if sum(1 for c in atk.hand if c.suit == 'Butcher') >= 2:
            capacity += 1
        gap = capacity - need
        # Large unfundable gaps strongly discourage the action; a clearly fundable
        # line gets a modest bonus rather than overwhelming Lord personality.
        return max(-2.5, min(0.6, gap / 5.0))

    def _commit_for_attack(self, pl: Player, op: Player, target_type: str, plan: str,
                           chip: bool = False):
        _cg_exempt = (VARIANT.get('circle_ignores_guard_tax', False)
                      and op.castle_power_active('SummoningCircle'))
        # Chip mode: commit just enough to strictly exceed the HIGHEST guard in
        # the zone (guards strip highest-first) and no more — deny Reconfiguration
        # tokens / feed Kroni's Hunger without reaching the Sigil layer.
        if chip:
            guards = op.castle_guards if target_type == 'Castle' else op.lord_guards
            if guards:
                need = max(effective_guard_value(g, _cg_exempt) for g in guards)
                picked, total = [], 0
                for c in sorted(pl.hand, key=lambda c: (effective_attack_value(pl, c, target_type), c.value)):
                    if total > need: break
                    picked.append(c); total += effective_attack_value(pl, c, target_type)
                if total > need:
                    for c in picked: pl.hand.remove(c)
                    pl.committed = picked
                    return
            # no guards to chip — fall through to a normal commit
        est_def, target_c = self._estimate_attack_defense(
            pl, op, target_type, context=f'commit:{pl.pid}')

        pad = 2 if plan in ('deny_ritual', 'deny_dominion') else (0 if plan == 'protect_souls' else 1)
        if VARIANT.get('momentum', False):
            pad = min(pad, 1)
        target_str = est_def + pad

        butchers = sorted([c for c in pl.hand if c.suit == 'Butcher'],
                          key=lambda c: c.value,
                          reverse=not VARIANT.get('momentum', False))
        others   = sorted([c for c in pl.hand if c.suit != 'Butcher'],
                          key=lambda c: c.value,
                          reverse=not VARIANT.get('momentum', False))

        committed = []; total = 0
        want_bonus = (pl.lord in ('Deimos', 'Orias', 'Gremory') or plan.startswith('deny'))
        if want_bonus:
            for c in butchers[:2]:
                committed.append(c); total += effective_attack_value(pl, c, target_type)
            butchers = butchers[2:]

        for c in butchers + others:
            if total >= target_str: break
            committed.append(c); total += effective_attack_value(pl, c, target_type)

        trim = 3 if plan.startswith('deny') else 2
        while (len(committed) > 1
               and total - effective_attack_value(pl, committed[-1], target_type)
               > target_str + trim):
            total -= effective_attack_value(pl, committed[-1], target_type)
            committed.pop()

        # ── Play around Psychic Recoil: Odradek will delete our 2nd-highest
        # committed card pre-combat, so pad until the EFFECTIVE total clears.
        recoil_applies = (op.lord == 'Odradek' and op.alive
                          and not (pl.lord == 'Orias'
                                   and self.orias_marked_lord == op.lord)
                          and (target_type == 'Lord'
                               or not VARIANT['recoil_hunts_only']))
        if recoil_applies and committed:
            def eff_total():
                if len(committed) <= 1:
                    return 0
                ordered = sorted(committed, key=lambda c: c.value, reverse=True)
                victim = ordered[-1] if VARIANT['recoil_lowest'] else ordered[1]
                return sum(effective_attack_value(pl, c, target_type)
                           for c in committed if c is not victim)
            remaining = list(pl.hand)
            for c in committed:
                remaining.remove(c)
            remaining.sort(key=lambda c: c.value, reverse=True)
            for c in remaining:
                if eff_total() >= target_str: break
                committed.append(c)
            if eff_total() < target_str and len(committed) < 2:
                pass  # can't clear recoil — commit what we have (bluff value)

        for c in committed: pl.hand.remove(c)
        # INTERLOCK: an attack spends the bank and rearms Recoil. Legal even
        # when the player selected no Hand cards.
        self._odradek_spend_bank(pl, committed)
        pl.committed = committed

    def _commit_for_ward(self, pl: Player, plan: str):
        if VARIANT.get('ward_commit_any', False):
            op = self.opp(pl.pid)
            opponent_pool = (
                self._precommit_pool_value[op.pid]
                if self._precommit_pool_value is not None
                else sum(card.value for card in op.hand + op.garrison)
            )
            profile = LORD_AI.get(pl.lord, {})
            expected = opponent_pool * WARD_READ_FRACTION
            if plan in ('protect_souls', 'deny_ritual'):
                expected *= 1.15
            if plan in ('race_dominion', 'pressure_souls'):
                expected *= 0.75
            expected *= profile.get('control', 1.0)
            budget = min(
                expected,
                sum(card.value for card in pl.hand) * WARD_MAX_HAND_FRACTION,
            )
            committed: List[Card] = []
            total = 0
            for card in sorted(
                    pl.hand,
                    key=lambda c: effective_ward_value(pl, c), reverse=True):
                if total >= budget:
                    break
                committed.append(card)
                total += effective_ward_value(pl, card)
            for card in committed:
                pl.hand.remove(card)
            pl.committed = committed
            return

        penitents = sorted([c for c in pl.hand if c.suit == 'Penitent'],
                           key=lambda c: c.value, reverse=True)
        committed = penitents[:2]
        for c in committed: pl.hand.remove(c)
        pl.committed = committed


# ═══════════════════════════════════════════════════════════════════════
#  SIMULATION RUNNER
# ═══════════════════════════════════════════════════════════════════════
def run_matchup(lord0: str, lord1: str, n_games: int, *, base_seed: int = 1) -> dict:
    wins0 = wins1 = 0
    timeouts = 0
    win_cond = defaultdict(int)
    rounds_list = []
    souls0_list = []; souls1_list = []
    threat0_list = []; threat1_list = []
    castles0_list = []; castles1_list = []
    total_combats = total_lords_killed = 0
    total_castles_destroyed = total_ward_souls = total_ritual_souls = 0
    total_castle_damage = total_castle_repaired = total_repair_cards = 0
    total_repair_value = total_castles_built = total_construction_value = 0
    total_repair_actions = total_construction_actions = 0
    total_first_construction_round = construction_games = 0
    total_castles_standing_end = total_sieges = total_bypasses = 0
    total_momentum_triggers = total_ruination_bonus = 0
    total_hunt_souls = total_breach_triggers = 0
    total_humbaba_tolls = 0
    total_personal_tears = total_neutral_tears = 0
    neutral_tear_source_totals = defaultdict(int)
    # Tension counters
    n_close = n_comeback = n_dominant = 0
    margin_list = []
    aha_total = 0   # total aha moments across all games
    aha_any   = 0   # games with at least one aha moment
    # Cross-tabulated: tension × win condition
    tension_by_cond = {
        'Ritual':   {'close': 0, 'comeback': 0, 'dominant': 0, 'total': 0, 'aha': 0, 'aha_pre_cat': 0, 'aha_close': 0, 'n_close': 0,
                     'telegraphed': 0, 'sudden': 0, 'path_surprise': 0, 'warning_sum': 0, 'warning_n': 0},
        'Dominion': {'close': 0, 'comeback': 0, 'dominant': 0, 'total': 0, 'aha': 0, 'aha_pre_cat': 0, 'aha_comeback': 0, 'n_comeback': 0,
                     'telegraphed': 0, 'sudden': 0, 'path_surprise': 0, 'warning_sum': 0, 'warning_n': 0},
        'Timeout':  {'close': 0, 'comeback': 0, 'dominant': 0, 'total': 0, 'aha': 0, 'aha_pre_cat': 0,
                     'telegraphed': 0, 'sudden': 0, 'path_surprise': 0, 'warning_sum': 0, 'warning_n': 0},
    }
    aha_pre_cat_total = 0

    for game_index in range(n_games):
        hrng = random.Random(stable_seed(base_seed, 'matchup', lord0, lord1, game_index))
        if LOCK_LORDS:
            # Pure 1v1: each player has exactly one lord, no switching.
            pool0 = [lord0]
            pool1 = [lord1]
        else:
            # Pool mode now has a precise meaning: the named Lord is the starter;
            # two randomized bench Lords may replace it on later resummons.
            others = [l for l in ALL_LORDS if l not in (lord0, lord1)]
            hrng.shuffle(others)
            pool0 = [lord0] + others[:2]
            pool1 = [lord1] + others[2:4]

        swapped = hrng.random() >= 0.5
        game_seed = stable_seed(base_seed, 'game', lord0, lord1, game_index)
        if not swapped:
            g = Game(pool0, pool1, seed=game_seed)
            w, wb = g.run()
            logical0, logical1 = g.players[0], g.players[1]
            logical_winner = w
        else:
            g = Game(pool1, pool0, seed=game_seed)
            w, wb = g.run()
            logical0, logical1 = g.players[1], g.players[0]
            logical_winner = 1 - w

        if logical_winner == 0:
            wins0 += 1
        elif logical_winner == 1:
            wins1 += 1

        if wb == 'Timeout': timeouts += 1
        win_cond[wb] += 1
        rounds_list.append(g.round)
        # Every per-side metric is mapped back to the logical matchup labels.
        souls0_list.append(logical0.souls); souls1_list.append(logical1.souls)
        threat0_list.append(logical0.threat); threat1_list.append(logical1.threat)
        castles0_list.append(len(logical0.castles)); castles1_list.append(len(logical1.castles))
        total_combats           += g.stat_combats
        total_lords_killed      += g.stat_lords_killed
        total_castles_destroyed += g.stat_castles_destroyed
        total_castle_damage     += g.stat_castle_damage
        total_castle_repaired   += g.stat_castle_repaired
        total_repair_cards      += g.stat_repair_cards
        total_repair_value      += g.stat_repair_value
        total_repair_actions    += g.stat_castle_repair_actions
        total_castles_built     += g.stat_castles_built
        total_construction_actions += g.stat_construction_actions
        total_construction_value += g.stat_construction_value
        total_castles_standing_end += len(logical0.castles) + len(logical1.castles)
        total_sieges += g.stat_sieges
        total_bypasses += g.stat_structure_first_bypasses
        total_momentum_triggers += g.stat_momentum_triggers
        total_ruination_bonus += g.stat_ruination_soul_bonus
        if g.stat_first_construction_round > 0:
            total_first_construction_round += g.stat_first_construction_round
            construction_games += 1
        total_ward_souls        += g.stat_ward_souls
        total_ritual_souls      += g.stat_ritual_souls
        total_hunt_souls        += g.stat_hunt_souls
        total_personal_tears    += g.stat_personal_tears
        total_neutral_tears     += g.stat_neutral_tears
        for _source, _count in g.stat_neutral_tear_sources.items():
            neutral_tear_source_totals[_source] += _count
        total_breach_triggers   += g.stat_breach_triggers
        total_humbaba_tolls     += g.stat_humbaba_tolls
        # Tension
        n_close    += int(g.was_close)
        n_comeback += int(g.was_comeback)
        n_dominant += int(g.was_dominant)
        margin_list.append(g.final_margin_souls)
        aha_total  += g.aha_moments
        aha_any    += int(g.aha_moments > 0)
        # Cross-tabulate with win condition
        cond = wb if wb in tension_by_cond else 'Timeout'
        tension_by_cond[cond]['total']       += 1
        tension_by_cond[cond]['close']       += int(g.was_close)
        tension_by_cond[cond]['comeback']    += int(g.was_comeback)
        tension_by_cond[cond]['dominant']    += int(g.was_dominant)
        tension_by_cond[cond]['aha']         += g.aha_moments
        tension_by_cond[cond]['aha_pre_cat'] += g.aha_pre_cataclysm
        tension_by_cond[cond]['telegraphed'] += int(g.telegraphed)
        tension_by_cond[cond]['sudden']      += int(g.sudden_win)
        tension_by_cond[cond]['path_surprise'] += int(g.path_surprise)
        if g.telegraphed:
            tension_by_cond[cond]['warning_sum'] += g.warning_rounds
            tension_by_cond[cond]['warning_n']   += 1
        if cond == 'Ritual' and g.was_close:
            tension_by_cond[cond]['aha_close'] += g.aha_moments
            tension_by_cond[cond]['n_close']   += 1
        if cond == 'Dominion' and g.was_comeback:
            tension_by_cond[cond]['aha_comeback'] += g.aha_moments
            tension_by_cond[cond]['n_comeback']   += 1
        aha_pre_cat_total += g.aha_pre_cataclysm

    def _avg(lst): return sum(lst) / len(lst) if lst else 0

    return {
        'wins0': wins0, 'wins1': wins1, 'timeouts': timeouts,
        'win_rate_0': wins0 / n_games, 'win_rate_1': wins1 / n_games,
        'win_cond': dict(win_cond),
        'avg_rounds':            _avg(rounds_list),
        'avg_souls_0':           _avg(souls0_list),
        'avg_souls_1':           _avg(souls1_list),
        'avg_castles_0':         _avg(castles0_list),
        'avg_castles_1':         _avg(castles1_list),
        'avg_combats':           total_combats / n_games,
        'avg_lords_killed':      total_lords_killed / n_games,
        'avg_castles_destroyed': total_castles_destroyed / n_games,
        'avg_castle_damage':     total_castle_damage / n_games,
        'avg_castle_repaired':   total_castle_repaired / n_games,
        'avg_repair_cards':      total_repair_cards / n_games,
        'avg_repair_value':      total_repair_value / n_games,
        'avg_repair_actions':    total_repair_actions / n_games,
        'avg_castles_built':     total_castles_built / n_games,
        'avg_construction_actions': total_construction_actions / n_games,
        'avg_construction_value': total_construction_value / n_games,
        'zero_construction_pct': 1.0 - (construction_games / n_games),
        'avg_castles_standing_end': total_castles_standing_end / n_games,
        'structure_first_bypass_rate': total_bypasses / total_sieges if total_sieges else 0.0,
        'avg_momentum_triggers': total_momentum_triggers / n_games,
        'avg_ruination_soul_bonus': total_ruination_bonus / n_games,
        'avg_first_construction_round': (
            total_first_construction_round / construction_games
            if construction_games else 0.0
        ),
        'avg_ward_souls':        total_ward_souls / n_games,
        'avg_ritual_souls':      total_ritual_souls / n_games,
        'avg_hunt_souls':        total_hunt_souls / n_games,
        'avg_personal_tears':    total_personal_tears / n_games,
        'avg_neutral_tears':     total_neutral_tears / n_games,
        'avg_neutral_tear_sources': {
            source: count / n_games for source, count in neutral_tear_source_totals.items()
        },
        'avg_breach_triggers':   total_breach_triggers / n_games,
        'avg_humbaba_tolls':     total_humbaba_tolls / n_games,
        # Tension metrics
        'close_pct':    n_close    / n_games,
        'comeback_pct': n_comeback / n_games,
        'dominant_pct': n_dominant / n_games,
        'avg_margin':   _avg(margin_list),
        'tension_by_cond': tension_by_cond,
        'avg_aha':      aha_total / n_games,
        'aha_any_pct':  aha_any   / n_games,
        'aha_pre_cat':  aha_pre_cat_total / n_games,
    }


# ═══════════════════════════════════════════════════════════════════════
#  CASTLE CAUSAL EXPERIMENT RUNNER
# ═══════════════════════════════════════════════════════════════════════
CASTLE_EXPERIMENT_SEEDS = (7, 21, 43, 101, 257, 389, 512, 733, 881, 997)


def castle_loadout_contexts(castle: str, all_contexts: bool = True) -> List[List[str]]:
    """Every 3-Castle opening loadout containing the tested Castle.

    The old harness used one fixed priority split.  Averaging all six companions
    prevents a Keep/Bastion/Stockpile filler choice from becoming an invisible
    treatment interaction.
    """
    opening_count = max(1, int(VARIANT.get('starting_castles', 3)))
    if opening_count <= 1:
        return [[castle]]
    others = [c for c in CASTLES if c != castle]
    if not all_contexts:
        return [[castle] + others[:opening_count - 1]]
    need = min(opening_count - 1, len(others))
    return [[castle] + list(combo) for combo in itertools.combinations(others, need)]


def _castle_masks(castle: str, mode: str, with_power: bool,
                  treated_seat: int) -> Dict[int, Set[str]]:
    all_powers = set(CASTLES)
    other = 1 - treated_seat
    if mode == 'add':
        # Structural/direct effect: every other Castle is an inert wall.
        treated_disabled = all_powers - ({castle} if with_power else set())
        return {treated_seat: treated_disabled, other: set(all_powers)}
    if mode == 'remove':
        # System contribution: full live ecosystem, then remove one identity.
        treated_disabled = set() if with_power else {castle}
        return {treated_seat: treated_disabled, other: set()}
    raise ValueError(f'unknown castle experiment mode: {mode}')


def _castle_game_outcome(game: Game, treated_seat: int, castle: str) -> dict:
    pl = game.players[treated_seat]
    op = game.players[1 - treated_seat]
    return {
        'win': 1.0 if game.winner == treated_seat else 0.0,
        'rounds': float(game.round),
        'souls': float(pl.souls),
        'opp_souls': float(op.souls),
        'personal_tears': float(pl.tears),
        'opp_personal_tears': float(op.tears),
        'neutral_tears': float(game.neutral_tears),
        'castles_end': float(len(pl.castles)),
        'opp_castles_end': float(len(op.castles)),
        'standing_rounds': float(game.stat_castle_standing_rounds[treated_seat].get(castle, 0)),
        'power_rounds': float(game.stat_castle_power_rounds[treated_seat].get(castle, 0)),
        'targeted': float(game.stat_castle_targeted[treated_seat].get(castle, 0)),
        'ruined': float(game.stat_castle_ruined_by_owner[treated_seat].get(castle, 0)),
    }


def run_castle_experiment(castle: str, *, mode: str = 'add',
                          games_per_seed: int = 200,
                          seeds: Iterable[int] = CASTLE_EXPERIMENT_SEEDS,
                          gate_mode: str = 'owned',
                          treated_lord: str = 'Vanilla',
                          opponent_lord: str = 'Vanilla',
                          all_loadout_contexts: bool = True) -> dict:
    """Paired, crossed-seat causal estimate of one Castle's marginal value.

    Each counterfactual pair shares the same game seed, deck stream, setup stream,
    per-player policy streams, effect stream and fog stream.  The only requested
    difference is whether the treated player's Castle identity is enabled.

    ``add`` answers: what does this power do on an otherwise blank Castle board?
    ``remove`` answers: what does this power contribute inside the full Castle kit?
    Neither is substituted for the other.
    """
    if castle not in CASTLES:
        raise ValueError(f'unknown Castle: {castle}')
    if mode not in ('add', 'remove'):
        raise ValueError('mode must be add or remove')
    if gate_mode not in ('owned', 'operational'):
        raise ValueError('gate_mode must be owned or operational')
    if treated_lord not in LORD_STATS or opponent_lord not in LORD_STATS:
        raise ValueError('unknown experiment Lord')

    seeds = tuple(int(x) for x in seeds)
    contexts = castle_loadout_contexts(castle, all_loadout_contexts)
    old_gate = VARIANT.get('castle_power_gate_mode', 'owned')
    VARIANT['castle_power_gate_mode'] = gate_mode
    per_seed = []
    metric_names = (
        'win', 'rounds', 'souls', 'opp_souls', 'personal_tears',
        'opp_personal_tears', 'neutral_tears', 'castles_end',
        'opp_castles_end', 'standing_rounds', 'power_rounds', 'targeted', 'ruined',
    )
    try:
        for seed in seeds:
            diffs = {k: [] for k in metric_names}
            live_wins = control_wins = 0.0
            pair_count = 0
            for context_index, loadout in enumerate(contexts):
                opening = {0: list(loadout), 1: list(loadout)}
                for game_index in range(games_per_seed):
                    for treated_seat in (0, 1):
                        game_seed = stable_seed(
                            seed, 'castle-exp', castle, mode, gate_mode,
                            context_index, game_index, treated_seat,
                            treated_lord, opponent_lord,
                        )
                        pools = (
                            [treated_lord] if treated_seat == 0 else [opponent_lord],
                            [treated_lord] if treated_seat == 1 else [opponent_lord],
                        )
                        live_game = Game(
                            pools[0], pools[1], seed=game_seed,
                            disabled_castle_powers=_castle_masks(
                                castle, mode, True, treated_seat),
                            opening_castles=opening,
                        )
                        live_game.run()
                        control_game = Game(
                            pools[0], pools[1], seed=game_seed,
                            disabled_castle_powers=_castle_masks(
                                castle, mode, False, treated_seat),
                            opening_castles=opening,
                        )
                        control_game.run()
                        live = _castle_game_outcome(live_game, treated_seat, castle)
                        control = _castle_game_outcome(control_game, treated_seat, castle)
                        for key in metric_names:
                            diffs[key].append(live[key] - control[key])
                        live_wins += live['win']
                        control_wins += control['win']
                        pair_count += 1
            seed_result = {
                'seed': seed,
                'pairs': pair_count,
                'live_win_rate': live_wins / max(1, pair_count),
                'control_win_rate': control_wins / max(1, pair_count),
            }
            for key in metric_names:
                seed_result[f'delta_{key}'] = statistics.fmean(diffs[key]) if diffs[key] else 0.0
            per_seed.append(seed_result)
    finally:
        VARIANT['castle_power_gate_mode'] = old_gate

    edges = [r['delta_win'] * 100.0 for r in per_seed]
    mean_edge = statistics.fmean(edges) if edges else 0.0
    sd_edge = statistics.stdev(edges) if len(edges) > 1 else 0.0
    se_edge = sd_edge / (len(edges) ** 0.5) if edges else 0.0
    summary = {
        'castle': castle,
        'mode': mode,
        'gate_mode': gate_mode,
        'treated_lord': treated_lord,
        'opponent_lord': opponent_lord,
        'games_per_seed': games_per_seed,
        'loadout_contexts': len(contexts),
        'seeds': list(seeds),
        'pairs_per_seed': per_seed[0]['pairs'] if per_seed else 0,
        'mean_edge_pp': mean_edge,
        'sd_edge_pp': sd_edge,
        'ci95_low_pp': mean_edge - 1.96 * se_edge,
        'ci95_high_pp': mean_edge + 1.96 * se_edge,
        'mean_live_win_rate': statistics.fmean(r['live_win_rate'] for r in per_seed) if per_seed else 0.0,
        'mean_control_win_rate': statistics.fmean(r['control_win_rate'] for r in per_seed) if per_seed else 0.0,
        'per_seed': per_seed,
    }
    for key in metric_names:
        if key == 'win':
            continue
        vals = [r[f'delta_{key}'] for r in per_seed]
        summary[f'mean_delta_{key}'] = statistics.fmean(vals) if vals else 0.0
    return summary


def format_castle_experiment(result: dict) -> str:
    lines = []
    lines.append('=' * 88)
    lines.append(
        f"CASTLE EXPERIMENT — {result['castle']} / {result['mode'].upper()} / "
        f"gate={result['gate_mode']}"
    )
    lines.append('=' * 88)
    lines.append(
        f"{result['treated_lord']} vs {result['opponent_lord']} | "
        f"{len(result['seeds'])} seeds × {result['games_per_seed']} games × "
        f"2 seats × {result['loadout_contexts']} loadouts"
    )
    lines.append(
        f"Power edge: {result['mean_edge_pp']:+.2f} pp  "
        f"(seed SD {result['sd_edge_pp']:.2f}; 95% CI "
        f"{result['ci95_low_pp']:+.2f}..{result['ci95_high_pp']:+.2f})"
    )
    lines.append(
        f"With power {result['mean_live_win_rate']*100:.1f}% | "
        f"without {result['mean_control_win_rate']*100:.1f}%"
    )
    lines.append('')
    lines.append('Secondary paired deltas (with − without):')
    for key, label in (
        ('rounds', 'game rounds'), ('souls', 'treated Souls'),
        ('personal_tears', 'treated personal Tears'), ('neutral_tears', 'neutral Tears'),
        ('castles_end', 'treated Castles standing'), ('standing_rounds', 'tested Castle standing-rounds'),
        ('power_rounds', 'tested Castle powered-rounds'), ('targeted', 'times targeted'),
        ('ruined', 'tested Castle ruinations'),
    ):
        lines.append(f"  {label:<32} {result.get('mean_delta_'+key, 0.0):+7.3f}")
    lines.append('')
    lines.append('Per-seed edge (pp):')
    lines.append('  ' + '  '.join(f"{r['seed']}:{r['delta_win']*100:+.2f}" for r in result['per_seed']))
    return '\n'.join(lines)


# ═══════════════════════════════════════════════════════════════════════
#  REPORTING
# ═══════════════════════════════════════════════════════════════════════
def generate_report(results: dict, n_games: int) -> str:
    lords = ALL_LORDS
    lines = []
    W = 100

    def bar(text): return f"\n{'═'*W}\n  {text}\n{'═'*W}"

    lines.append(bar("CORRUPTOR BALANCE SIMULATION REPORT  v%s (%s)  ai=%s" % (SIM_VERSION, SIM_CODENAME, AI_POLICY)))
    if ACTIVE_RULESET == "lab-v6.5":
        lines.append(
            "  Lab profile        : %s (market_refresh=%s, ward_commit_defense=%s, "
            "kani_hand_cost=%s, humbaba_reactive_lane=%s, kro_fallback_feeds=%s, "
            "kro_milestone_once=%s, momentum_refund=%s, veil_drift=%s/%s, "
            "kal_flame_tokens=%s)"
            % (
                LAB_PROFILE_VERSION,
                ACTIVE_FEATURES["market_refresh"],
                ACTIVE_FEATURES["ward_commit_defense"],
                ACTIVE_FEATURES["kani_hand_cost"],
                ACTIVE_FEATURES["humbaba_reactive_lane"],
                ACTIVE_FEATURES["kro_fallback_feeds"],
                ACTIVE_FEATURES["kro_milestone_once"],
                ACTIVE_FEATURES["momentum_refund"],
                ACTIVE_FEATURES["veil_drift_after"],
                ACTIVE_FEATURES["veil_drift_growth"],
                ACTIVE_FEATURES["kal_flame_tokens"],
            )
        )
    lines.append(f"  Games per matchup  : {n_games:,}")
    lines.append(f"  Total matchups     : {len(lords)*(len(lords)-1)//2}")
    lines.append(f"  Total games played : {n_games * len(lords)*(len(lords)-1)//2:,}")
    lines.append(f"  Lord mode          : {'LOCKED — pure 1v1, no switching' if LOCK_LORDS else 'POOL — 3-lord pool with AI switching'}")
    lines.append(f"  Dominion track     : {DOMINION_TRACK} Tears (Standard mode)")
    lines.append(f"  Dominion req.      : {DOMINION_REQUIREMENT} personal Tears")
    lines.append(f"  Final Collapse     : {FINAL_COLLAPSE_TRACK} Tears\n")

    # ── Overall win-rate ─────────────────────────────────────────────
    lines.append(bar("1. OVERALL WIN RATES  (vs all other lords)"))
    overall = {}
    for lord in lords:
        wins = total = 0
        for (l0, l1), res in results.items():
            if l0 == lord:   wins += res['wins0']; total += n_games
            elif l1 == lord: wins += res['wins1']; total += n_games
        overall[lord] = wins / total if total else 0

    ranked = sorted(overall.items(), key=lambda x: -x[1])
    lines.append(f"\n  {'Lord':<12} {'Win%':>7}  {'Rating':>8}  Bar")
    lines.append(f"  {'-'*12} {'-'*7}  {'-'*8}  ---")
    for lord, wr in ranked:
        rating = ("DOMINANT"  if wr > 0.62 else
                  "STRONG"    if wr > 0.56 else
                  "BALANCED"  if wr > 0.44 else
                  "WEAK"      if wr > 0.38 else "VERY WEAK")
        marker  = " ◄◄ IMBALANCED" if wr > 0.60 or wr < 0.40 else ""
        bar_len = int(wr * 40)
        lines.append(f"  {lord:<12} {wr*100:>6.1f}%  {rating:>8}  {'█'*bar_len}{marker}")

    # ── Head-to-head matrix ──────────────────────────────────────────
    lines.append(bar("2. HEAD-TO-HEAD WIN RATE MATRIX  (row wins vs col)"))
    lines.append(f"\n  {'':>10}" + "".join(f"  {l[:7]:>7}" for l in lords))
    lines.append(f"  {'':>10}" + "  " + "─"*7*len(lords))
    for l0 in lords:
        row = f"  {l0:<10}|"
        for l1 in lords:
            if l0 == l1:
                row += "    --- "
            elif (l0, l1) in results:
                wr   = results[(l0, l1)]['win_rate_0']
                flag = "*" if wr > 0.60 or wr < 0.40 else " "
                row += f"  {wr*100:>5.1f}{flag}"
            elif (l1, l0) in results:
                wr   = results[(l1, l0)]['win_rate_1']
                flag = "*" if wr > 0.60 or wr < 0.40 else " "
                row += f"  {wr*100:>5.1f}{flag}"
            else:
                row += "    n/a "
        lines.append(row)
    lines.append("  (* = win rate outside 40–60% range)\n")

    # ── Tension & Perceived Fairness ─────────────────────────────────
    lines.append(bar("3b. TENSION & PERCEIVED FAIRNESS"))
    total_games = sum(res['wins0'] + res['wins1'] + res['timeouts'] for res in results.values())

    def tension_sum(key):
        return sum(res[key] * (res['wins0']+res['wins1']+res['timeouts']) for res in results.values())

    total_close    = tension_sum('close_pct')
    total_comeback = tension_sum('comeback_pct')
    total_dominant = tension_sum('dominant_pct')
    avg_margin     = tension_sum('avg_margin') / max(1, total_games)
    close_pct    = total_close    / max(1, total_games) * 100
    comeback_pct = total_comeback / max(1, total_games) * 100
    dominant_pct = total_dominant / max(1, total_games) * 100
    contested_pct = 100 - dominant_pct

    lines.append(f"""
  Close finishes     (loser within 2 Souls) : {close_pct:5.1f}%
  Comeback wins      (winner was trailing)  : {comeback_pct:5.1f}%
  Dominant wins      (led from round 3+)    : {dominant_pct:5.1f}%
  Contested games    (not dominant)         : {contested_pct:5.1f}%
  Avg winning margin                        : {avg_margin:5.1f} Souls
""")

    # Qualitative read
    if close_pct >= 35:
        lines.append("  ✓  High close-finish rate — games feel tight and decisive.")
    elif close_pct >= 20:
        lines.append("  ~  Moderate close-finish rate — tension is present but not consistent.")
    else:
        lines.append("  ⚠  Low close-finish rate — many games may feel one-sided.")

    if comeback_pct >= 20:
        lines.append("  ✓  Strong comeback rate — losing position is not hopeless.")
    elif comeback_pct >= 10:
        lines.append("  ~  Moderate comeback rate — trailing is difficult but possible.")
    else:
        lines.append("  ⚠  Low comeback rate — early leads tend to be decisive.")

    if dominant_pct <= 30:
        lines.append("  ✓  Low dominant-win rate — games remain contested through the mid-game.")
    elif dominant_pct <= 50:
        lines.append("  ~  Moderate dominant-win rate — some games break open early.")
    else:
        lines.append("  ⚠  High dominant-win rate — many games feel decided before the end.")

    # Cross-tabulation: tension × win condition
    # Aggregate tension_by_cond across all matchups
    agg_by_cond = {'Ritual': {'close':0,'comeback':0,'dominant':0,'total':0},
                   'Dominion': {'close':0,'comeback':0,'dominant':0,'total':0},
                   'Timeout':  {'close':0,'comeback':0,'dominant':0,'total':0}}
    for res in results.values():
        tbc = res.get('tension_by_cond', {})
        for cond in ('Ritual', 'Dominion', 'Timeout'):
            if cond in tbc:
                for k in ('close','comeback','dominant','total'):
                    agg_by_cond[cond][k] += tbc[cond][k]

    lines.append(f"\n  {'Win Path':<12} {'Total':>7} {'Close%':>8} {'Comeback%':>10} {'Dominant%':>10}")
    lines.append(f"  {'-'*12} {'-'*7} {'-'*8} {'-'*10} {'-'*10}")
    for cond in ('Ritual', 'Dominion', 'Timeout'):
        d = agg_by_cond[cond]
        t = max(1, d['total'])
        cp  = d['close']    / t * 100
        kp  = d['comeback'] / t * 100
        dp  = d['dominant'] / t * 100
        lines.append(f"  {cond:<12} {d['total']:>7,} {cp:>7.1f}% {kp:>9.1f}% {dp:>9.1f}%")

    lines.append("")
    # Qualitative Dominion read — the key question
    dom = agg_by_cond['Dominion']
    dom_t = max(1, dom['total'])
    dom_close = dom['close'] / dom_t * 100
    dom_comeback = dom['comeback'] / dom_t * 100
    dom_dominant = dom['dominant'] / dom_t * 100
    rit = agg_by_cond['Ritual']
    rit_t = max(1, rit['total'])
    rit_close = rit['close'] / rit_t * 100

    lines.append("  Dominion verdict:")
    if dom_close >= rit_close - 5:
        lines.append("  ✓  Dominion wins are as tense as Ritual wins — it earns its victories.")
    elif dom_close >= 20:
        lines.append("  ~  Dominion wins are somewhat less tense than Ritual wins.")
    else:
        lines.append("  ⚠  Dominion wins have low close-finish rate — may feel like stolen games.")

    if dom_comeback >= 25:
        lines.append("  ✓  Dominion comebacks are common — trailing players can pivot to Tears.")
    else:
        lines.append("  ~  Dominion comebacks are less common — Tear leads tend to hold.")

    if dom_dominant >= 40:
        lines.append("  ⚠  High dominant-win rate for Dominion — Tear leads are hard to overcome.")
    else:
        lines.append("  ✓  Dominion dominant-win rate is acceptable.")

    # Aha moments — overall
    total_aha     = sum(res['avg_aha']     * (res['wins0']+res['wins1']+res['timeouts']) for res in results.values())
    total_aha_any = sum(res['aha_any_pct'] * (res['wins0']+res['wins1']+res['timeouts']) for res in results.values())
    total_pre_cat = sum(res['aha_pre_cat'] * (res['wins0']+res['wins1']+res['timeouts']) for res in results.values())
    avg_aha     = total_aha     / max(1, total_games)
    aha_any_pct = total_aha_any / max(1, total_games) * 100
    avg_pre_cat = total_pre_cat / max(1, total_games)

    # Aha cross-tab by condition (aggregate tension_by_cond across matchups)
    agg_aha = {
        'Ritual':   {'aha': 0, 'aha_pre_cat': 0, 'total': 0, 'aha_close': 0,   'n_close': 0},
        'Dominion': {'aha': 0, 'aha_pre_cat': 0, 'total': 0, 'aha_comeback': 0, 'n_comeback': 0},
    }
    for res in results.values():
        tbc = res.get('tension_by_cond', {})
        for cond in ('Ritual', 'Dominion'):
            if cond in tbc:
                agg_aha[cond]['aha']         += tbc[cond]['aha']
                agg_aha[cond]['aha_pre_cat'] += tbc[cond].get('aha_pre_cat', 0)
                agg_aha[cond]['total']       += tbc[cond]['total']
                if cond == 'Ritual':
                    agg_aha[cond]['aha_close'] += tbc[cond].get('aha_close', 0)
                    agg_aha[cond]['n_close']   += tbc[cond].get('n_close', 0)
                if cond == 'Dominion':
                    agg_aha[cond]['aha_comeback'] += tbc[cond].get('aha_comeback', 0)
                    agg_aha[cond]['n_comeback']   += tbc[cond].get('n_comeback', 0)

    rit_avg_aha   = agg_aha['Ritual']['aha']         / max(1, agg_aha['Ritual']['total'])
    rit_pre_cat   = agg_aha['Ritual']['aha_pre_cat'] / max(1, agg_aha['Ritual']['total'])
    rit_close_aha = agg_aha['Ritual']['aha_close']   / max(1, agg_aha['Ritual']['n_close'])
    dom_avg_aha   = agg_aha['Dominion']['aha']         / max(1, agg_aha['Dominion']['total'])
    dom_pre_cat   = agg_aha['Dominion']['aha_pre_cat'] / max(1, agg_aha['Dominion']['total'])
    dom_cb_aha    = agg_aha['Dominion']['aha_comeback'] / max(1, agg_aha['Dominion']['n_comeback'])

    lines.append(f"\n  ── Aha Moments (razor-margin plays) ──")
    lines.append(f"  Avg aha moments per game               : {avg_aha:5.1f}")
    lines.append(f"  Games with at least one aha moment     : {aha_any_pct:5.1f}%")
    lines.append(f"  Avg aha moments before Cataclysm       : {avg_pre_cat:5.1f}  (of {avg_aha:.1f} total)")
    lines.append(f"  (Defined as: bid margin ≤2, attack/defense margin ≤2, or 1-Soul final win)\n")

    # Cross-tab table: the five numbers you actually care about
    lines.append(f"  {'Win Path':<12} {'Avg Aha':>8} {'Pre-Cat Aha':>12} {'Close-Game Aha':>16} {'Comeback Aha':>13}")
    lines.append(f"  {'-'*12} {'-'*8} {'-'*12} {'-'*16} {'-'*13}")
    lines.append(f"  {'Ritual':<12} {rit_avg_aha:>8.1f} {rit_pre_cat:>12.1f} {rit_close_aha:>16.1f} {'(n/a)':>13}")
    lines.append(f"  {'Dominion':<12} {dom_avg_aha:>8.1f} {dom_pre_cat:>12.1f} {'(n/a)':>16} {dom_cb_aha:>13.1f}")
    lines.append(f"")
    lines.append(f"    Avg Aha        — all aha moments per game won by this path")
    lines.append(f"    Pre-Cat Aha    — aha moments that occurred before Cataclysm fires")
    lines.append(f"    Close-Game Aha — aha/game in Ritual wins where loser was within 2 Souls")
    lines.append(f"    Comeback Aha   — aha/game in Dominion wins where winner was trailing at midpoint")
    lines.append(f"")

    # Verdicts
    if dom_avg_aha >= 5:
        lines.append("  ✓  Dominion wins contain rich micro-decision content — not sudden steals.")
    elif dom_avg_aha >= 3:
        lines.append("  ~  Dominion wins have moderate aha content — some feel earned, some abrupt.")
    else:
        lines.append("  ⚠  Dominion wins have low aha content — likely feel like sudden steals.")

    if dom_pre_cat >= rit_pre_cat * 0.7:
        lines.append(f"  ✓  Dominion pre-Cataclysm aha ({dom_pre_cat:.1f}) comparable to Ritual ({rit_pre_cat:.1f}) — tension builds throughout, not just at the threshold.")
    else:
        lines.append(f"  ~  Dominion pre-Cataclysm aha ({dom_pre_cat:.1f}) lower than Ritual ({rit_pre_cat:.1f}) — tension may cluster near the track threshold.")

    if dom_cb_aha >= rit_avg_aha * 0.8:
        lines.append("  ✓  Dominion comeback wins are as aha-rich as Ritual wins — pivots feel hard-fought.")
    else:
        lines.append("  ~  Dominion comeback wins have fewer aha moments than Ritual — pivots may feel passive.")

    if avg_pre_cat >= avg_aha * 0.6:
        lines.append("  ✓  Most aha moments occur before Cataclysm — tension builds before the endgame.")
    else:
        lines.append("  ~  Many aha moments cluster near Cataclysm — endgame is the tension spike.")

    if avg_aha >= 4:
        lines.append("  ✓  Rich with tense micro-decisions — players will remember these games.")
    elif avg_aha >= 2:
        lines.append("  ~  Moderate aha density — key moments exist but aren't constant.")
    else:
        lines.append("  ⚠  Low aha density — games may feel decided rather than fought for.")

    # Most / least aha matchups
    matchup_aha = sorted(results.items(), key=lambda x: x[1]['avg_aha'], reverse=True)
    if matchup_aha:
        top = matchup_aha[0]
        bot = matchup_aha[-1]
        lines.append(f"\n  Most aha-rich matchup : {top[0][0]} vs {top[0][1]} ({top[1]['avg_aha']:.1f} aha/game)")
        lines.append(f"  Least aha-rich matchup: {bot[0][0]} vs {bot[0][1]} ({bot[1]['avg_aha']:.1f} aha/game)")
    matchup_close = sorted(results.items(), key=lambda x: x[1]["close_pct"], reverse=True)
    if matchup_close:
        top = matchup_close[0]
        bot = matchup_close[-1]
        lines.append(f"\n  Most tense matchup  : {top[0][0]} vs {top[0][1]} ({top[1]['close_pct']*100:.0f}% close finishes)")
        lines.append(f"  Least tense matchup : {bot[0][0]} vs {bot[0][1]} ({bot[1]['close_pct']*100:.0f}% close finishes)")

    # ── Win condition breakdown ──────────────────────────────────────
    lines.append(bar("3d. FAIRNESS / TELEGRAPHING"))

    # Aggregate telegraph cross-tab across all matchups
    agg_tel = {c: {'telegraphed':0,'sudden':0,'path_surprise':0,
                   'warning_sum':0,'warning_n':0,'total':0}
               for c in ('Ritual','Dominion','Timeout')}
    for res in results.values():
        tbc = res.get('tension_by_cond', {})
        for cond in agg_tel:
            if cond in tbc:
                for k in ('telegraphed','sudden','path_surprise','warning_sum','warning_n','total'):
                    agg_tel[cond][k] += tbc[cond].get(k, 0)

    def _tel_pct(cond, key):
        t = max(1, agg_tel[cond]['total'])
        return agg_tel[cond][key] / t * 100

    def _warn_avg(cond):
        n = max(1, agg_tel[cond]['warning_n'])
        return agg_tel[cond]['warning_sum'] / n

    lines.append(f"""
  Visible threat definitions:
    Ritual   — winner had ≥{WIN_SOULS-2} Souls (one Lord kill from victory)
    Dominion — winner had ≥{DOMINION_REQUIREMENT-1} personal Tears AND Veil ≥{DOMINION_TRACK-2} (one action from Cataclysm)
    Collapse — Veil ≥{FINAL_COLLAPSE_TRACK-2} (track two steps from hard end)

  Telegraphed win  : winner was visibly threatening at the start of the final round
  Sudden win       : winner was NOT visibly threatening at the start of the final round
  Path surprise    : winner was behind on their eventual win-path metric at round start
  Warning rounds   : rounds between first visible threat and actual win (telegraphed games only)
""")

    lines.append(f"  {'Win Path':<14} {'Telegraphed':>12} {'Sudden':>8} {'Path Surpr':>11} {'Avg Warning':>12}")
    lines.append(f"  {'-'*14} {'-'*12} {'-'*8} {'-'*11} {'-'*12}")
    for cond in ('Ritual', 'Dominion', 'Timeout'):
        t = agg_tel[cond]['total']
        if t == 0:
            lines.append(f"  {cond:<14} {'(no data)':>12}")
            continue
        lines.append(
            f"  {cond:<14} {_tel_pct(cond,'telegraphed'):>11.1f}%"
            f" {_tel_pct(cond,'sudden'):>7.1f}%"
            f" {_tel_pct(cond,'path_surprise'):>10.1f}%"
            f" {_warn_avg(cond):>11.1f} rds"
        )

    lines.append("")

    # Global telegraphed rate
    all_total      = sum(agg_tel[c]['total']      for c in agg_tel)
    all_telegraphed = sum(agg_tel[c]['telegraphed'] for c in agg_tel)
    all_sudden     = sum(agg_tel[c]['sudden']      for c in agg_tel)
    all_surprise   = sum(agg_tel[c]['path_surprise'] for c in agg_tel)
    all_warn_sum   = sum(agg_tel[c]['warning_sum'] for c in agg_tel)
    all_warn_n     = sum(agg_tel[c]['warning_n']   for c in agg_tel)
    g_tele_pct = all_telegraphed / max(1, all_total) * 100
    g_sudden_pct = all_sudden    / max(1, all_total) * 100
    g_surprise_pct = all_surprise / max(1, all_total) * 100
    g_warn_avg = all_warn_sum / max(1, all_warn_n)

    lines.append(f"  Overall telegraphed  : {g_tele_pct:.1f}%   (target ≥70%)")
    lines.append(f"  Overall sudden wins  : {g_sudden_pct:.1f}%   (target <20%)")
    lines.append(f"  Overall path surprise: {g_surprise_pct:.1f}%")
    lines.append(f"  Overall avg warning  : {g_warn_avg:.1f} rounds")
    lines.append("")

    rit_warn = _warn_avg('Ritual')
    dom_warn = _warn_avg('Dominion')
    rit_sud  = _tel_pct('Ritual',  'sudden')
    dom_sud  = _tel_pct('Dominion','sudden')

    if g_tele_pct >= 70:
        lines.append(f"  ✓  {g_tele_pct:.0f}% telegraphed — most wins are legibly inevitable.")
    elif g_tele_pct >= 55:
        lines.append(f"  ~  {g_tele_pct:.0f}% telegraphed — many wins visible, but gap exists.")
    else:
        lines.append(f"  ⚠  Only {g_tele_pct:.0f}% telegraphed — too many wins arriving without warning.")

    if g_sudden_pct < 20:
        lines.append(f"  ✓  Sudden win rate {g_sudden_pct:.0f}% is healthy.")
    elif g_sudden_pct < 35:
        lines.append(f"  ~  Sudden win rate {g_sudden_pct:.0f}% is elevated — some wins feel out of nowhere.")
    else:
        lines.append(f"  ⚠  Sudden win rate {g_sudden_pct:.0f}% is too high — wins frequently appear from nowhere.")

    if rit_warn >= 1.0:
        lines.append(f"  ✓  Ritual warning window {rit_warn:.1f} rounds — loser has time to respond.")
    else:
        lines.append(f"  ~  Ritual warning window only {rit_warn:.1f} rounds — very little reaction time.")

    if dom_warn >= 1.5:
        lines.append(f"  ✓  Dominion warning window {dom_warn:.1f} rounds — Tear threat is visible early enough.")
    else:
        lines.append(f"  ~  Dominion warning window only {dom_warn:.1f} rounds — Cataclysm arrives quickly once telegraphed.")

    if dom_sud > 30:
        lines.append(f"  ⚠  Dominion sudden wins at {dom_sud:.0f}% — Cataclysm still surprising too often. Consider board visibility improvements or slower track.")
    elif dom_sud > 20:
        lines.append(f"  ~  Dominion sudden wins at {dom_sud:.0f}% — within tolerance for an alternate-axis path.")
    else:
        lines.append(f"  ✓  Dominion sudden wins at {dom_sud:.0f}% — Tear threat consistently legible.")

    # ── Win condition breakdown ──────────────────────────────────────
    lines.append(bar("3. WIN CONDITION BREAKDOWN"))
    cond_totals = defaultdict(int)
    for res in results.values():
        for cond, cnt in res['win_cond'].items():
            cond_totals[cond] += cnt
    grand = sum(cond_totals.values())
    lines.append("")
    for cond, cnt in sorted(cond_totals.items(), key=lambda x: -x[1]):
        pct = cnt / grand * 100 if grand else 0
        lines.append(f"  {cond:<14} {cnt:>8,}  ({pct:.1f}%)")

    # ── Veil / Tear economy ──────────────────────────────────────────
    lines.append(bar("4. VEIL TRACK & TEAR ECONOMY"))
    avg_all = lambda key: sum(res[key] for res in results.values()) / max(1, len(results))
    avg_neutral_source = lambda source: (
        sum(res.get('avg_neutral_tear_sources', {}).get(source, 0.0)
            for res in results.values()) / max(1, len(results))
    )
    avg_pt  = avg_all('avg_personal_tears')
    avg_nt  = avg_all('avg_neutral_tears')
    avg_tot = avg_pt + avg_nt
    lines.append(f"\n  Avg personal tears per game  : {avg_pt:.2f}")
    lines.append(f"  Avg neutral tears per game   : {avg_nt:.2f}")
    lines.append(f"  Avg total track position     : {avg_tot:.2f}  (Cataclysm at {DOMINION_TRACK})")
    lines.append(f"  Avg castles destroyed/game   : {avg_all('avg_castles_destroyed'):.2f}  (each generates 1 neutral tear)")
    lines.append(f"  Avg lords killed/game        : {avg_all('avg_lords_killed'):.2f}  (each resummon after 1st generates 1 neutral tear)")
    pct_of_track = avg_tot / DOMINION_TRACK * 100
    lines.append(f"\n  Track fills to {pct_of_track:.0f}% of Cataclysm on average.")
    if avg_tot < DOMINION_TRACK * 0.5:
        lines.append("  ⚠  Track rarely reaches halfway — Dominion path likely unreachable.")
    elif avg_tot < DOMINION_TRACK * 0.8:
        lines.append("  ⚠  Track reaches ~halfway — Dominion possible but not routine.")
    else:
        lines.append("  ✓  Track is reaching Cataclysm range regularly.")

    # ── Per-matchup stats ────────────────────────────────────────────
    lines.append(bar("5. PER-MATCHUP STATISTICS"))
    lines.append(f"\n  {'Matchup':<22} {'WR0':>6} {'WR1':>6} {'Rnds':>6} "
                 f"{'Lrds/g':>7} {'PTeats':>7} {'NTeats':>7} {'TTrack':>7}")
    lines.append(f"  {'-'*22} {'-'*6} {'-'*6} {'-'*6} {'-'*7} {'-'*7} {'-'*7} {'-'*7}")
    for (l0, l1), res in sorted(results.items()):
        label = f"{l0} vs {l1}"
        tot   = res['avg_personal_tears'] + res['avg_neutral_tears']
        lines.append(
            f"  {label:<22} {res['win_rate_0']*100:>5.1f}% {res['win_rate_1']*100:>5.1f}% "
            f"{res['avg_rounds']:>6.1f} {res['avg_lords_killed']:>7.2f} "
            f"{res['avg_personal_tears']:>7.2f} {res['avg_neutral_tears']:>7.2f} "
            f"{tot:>7.2f}"
        )

    # ── Timeout analysis ─────────────────────────────────────────────
    lines.append(bar("6. TIMEOUT / STALL ANALYSIS"))
    timeout_matchups = sorted(
        [((l0, l1), res['timeouts'] / n_games * 100, res['avg_rounds'])
         for (l0, l1), res in results.items() if res['timeouts'] > 0],
        key=lambda x: -x[1]
    )
    lines.append("")
    if timeout_matchups:
        lines.append(f"  {'Matchup':<22} {'Timeout%':>10}  {'Avg Rounds':>12}")
        lines.append(f"  {'-'*22} {'-'*10}  {'-'*12}")
        for (l0, l1), pct, avg_r in timeout_matchups:
            flag = "  ◄◄ CRITICAL STALL" if pct > 15 else ""
            lines.append(f"  {l0+' vs '+l1:<22} {pct:>9.1f}%  {avg_r:>12.1f}{flag}")
    else:
        lines.append("  No timeouts recorded.")

    # ── Ability activity ─────────────────────────────────────────────
    lines.append(bar("7. ABILITY & MECHANIC ACTIVITY"))
    lines.append("")
    lines.append(f"  Avg combats per game          : {avg_all('avg_combats'):.2f}")
    lines.append(f"  Avg lords killed per game     : {avg_all('avg_lords_killed'):.2f}")
    lines.append(f"  Avg castles destroyed per game: {avg_all('avg_castles_destroyed'):.2f}")
    if ACTIVE_FEATURES['castle_integrity']:
        lines.append(f"  Avg Integrity damage per game : {avg_all('avg_castle_damage'):.2f}")
        lines.append(f"  Avg Integrity repaired/game   : {avg_all('avg_castle_repaired'):.2f}")
        lines.append(f"  Avg repair actions/game       : {avg_all('avg_repair_actions'):.2f}")
        lines.append(f"  Avg repair cards spent/game   : {avg_all('avg_repair_cards'):.2f}")
        lines.append(f"  Avg repair card value/game    : {avg_all('avg_repair_value'):.2f}")
        lines.append(f"  Avg castles constructed/game  : {avg_all('avg_castles_built'):.2f}")
        lines.append(f"  Avg construction actions/game : {avg_all('avg_construction_actions'):.2f}")
        lines.append(f"  Avg construction value/game   : {avg_all('avg_construction_value'):.2f}")
        lines.append(f"  Zero-construction games       : {avg_all('zero_construction_pct')*100:.1f}%")
        lines.append(f"  Avg castles standing at end   : {avg_all('avg_castles_standing_end'):.2f}")
        lines.append(f"  Avg round first construction  : {avg_all('avg_first_construction_round'):.2f}")
        lines.append(f"  Structure-first bypass rate   : {avg_all('structure_first_bypass_rate')*100:.1f}%")
        lines.append(f"  Avg Momentum triggers/game    : {avg_all('avg_momentum_triggers'):.2f}")
        ruins = avg_all('avg_castles_destroyed')
        repairs = avg_all('avg_repair_actions')
        lines.append(f"  Repair : Ruination ratio      : {(repairs / ruins if ruins else 0.0):.2f}")
    lines.append(f"  Avg ritual souls per game     : {avg_all('avg_ritual_souls'):.2f}")
    lines.append(f"  Avg hunt souls per game       : {avg_all('avg_hunt_souls'):.2f}")
    lines.append(f"  Avg ward souls per game       : {avg_all('avg_ward_souls'):.2f}")
    lines.append(f"  Avg breach triggers per game  : {avg_all('avg_breach_triggers'):.2f}")

    # ── Critical flaw detection ──────────────────────────────────────
    lines.append(bar("8. CRITICAL FLAW DETECTION"))
    flaws = []

    for lord, wr in ranked:
        if wr > 0.62: flaws.append(f"  [BALANCE] {lord} DOMINANT ({wr*100:.1f}% — threshold 62%)")
        if wr < 0.38: flaws.append(f"  [BALANCE] {lord} UNDERPOWERED ({wr*100:.1f}% — threshold 38%)")

    for (l0, l1), res in results.items():
        wr = res['win_rate_0']
        if wr > 0.68: flaws.append(f"  [MATCHUP] {l0} crushes {l1}: {wr*100:.1f}%")
        if wr < 0.32: flaws.append(f"  [MATCHUP] {l0} hard countered by {l1}: {wr*100:.1f}%")
        if res['timeouts'] / n_games > 0.20:
            flaws.append(f"  [STALL]   {l0} vs {l1}: {res['timeouts']/n_games*100:.0f}% timeout")

    avg_rounds_all = avg_all('avg_rounds')
    if avg_rounds_all > 30: flaws.append(f"  [PACING] Avg game {avg_rounds_all:.1f} rounds — very long")
    if avg_rounds_all < 6:  flaws.append(f"  [PACING] Avg game {avg_rounds_all:.1f} rounds — too fast")

    ritual_pct   = cond_totals.get('Ritual',       0) / grand * 100 if grand else 0
    dominion_pct = cond_totals.get('Dominion',     0) / grand * 100 if grand else 0
    collapse_pct = cond_totals.get('FinalCollapse', 0) / grand * 100 if grand else 0
    timeout_pct  = cond_totals.get('Timeout',      0) / grand * 100 if grand else 0

    if ritual_pct > 90:
        flaws.append(f"  [WIN COND] Ritual dominates {ritual_pct:.0f}% — Dominion path irrelevant")
    if dominion_pct < 3:
        flaws.append(f"  [WIN COND] Dominion rarely fires ({dominion_pct:.1f}%) — track or requirement may be miscalibrated")
    if collapse_pct > 10:
        flaws.append(f"  [WIN COND] FinalCollapse fires {collapse_pct:.1f}% — track reaching {FINAL_COLLAPSE_TRACK} too often, or Dominion too hard to achieve")
    if timeout_pct > 15:
        flaws.append(f"  [STALL]   Overall timeout rate {timeout_pct:.1f}% — game length concern")
    if avg_tot < DOMINION_TRACK * 0.5:
        flaws.append(f"  [VEIL]    Track only reaches {avg_tot:.1f} avg ({pct_of_track:.0f}% of Cataclysm) — passive tears too rare")

    lines.append("")
    if flaws:
        for f in flaws: lines.append(f)
    else:
        lines.append("  ✓ No critical flaws detected at this sample size.")

    lines.append(bar("9. VEIL SYSTEM CALIBRATION NOTES"))
    lines.append(f"""
  NEUTRAL TEAR SOURCES (causally attributed):
  • Castle Ruination gate          : {avg_neutral_source('castle_ruination'):.2f}/game
  • Inevitable Ruin castle effect : {avg_neutral_source('castle_inevitable_ruin'):.2f}/game
  • Lord resummon                 : {avg_neutral_source('resummon'):.2f}/game
  • Banishment rule               : {avg_neutral_source('banishment'):.2f}/game
  • Veil drift (fixed + growth)   : {avg_neutral_source('veil_drift_fixed') + avg_neutral_source('veil_drift_growth'):.2f}/game
  • Other named sources           : {avg_neutral_source('humbaba_toll') + avg_neutral_source('odradek_reconfiguration') + avg_neutral_source('kanifous_invoke') + avg_neutral_source('castle_permanent_loss'):.2f}/game

  Total Neutral Tears             : {avg_all('avg_neutral_tears'):.2f}/game
  Avg castles destroyed           : {avg_all('avg_castles_destroyed'):.2f}/game
  Avg Lords killed               : {avg_all('avg_lords_killed'):.2f}/game

  v7 no longer infers source counts from the total Neutral Tear counter; the
  previous report could attribute resummon/rite tears to Castle destruction.

  ATTUNEMENT / IMMUNITY NOTE:
  • With avg {avg_all('avg_personal_tears'):.2f} personal tears/game, most players have Attunement 0–1.
  • Omen (track 3) affects nearly everyone — Attunement immunity rarely triggers.
  • Frenzy (track 6) and Collapse (track 9): only reached if Veil track advances enough.
  • Players racing Dominion accumulate Attunement and resist thresholds others suffer.
    This creates meaningful asymmetry in late-game board pressure.

  DOMINION FEASIBILITY:
  • Track reaches Cataclysm ({DOMINION_TRACK}) in {cond_totals.get('Dominion',0)/grand*100:.1f}% of games.
  • Dominion requirement ({DOMINION_REQUIREMENT} personal tears): needs deliberate investment.
  • If Dominion rate is below 5%, consider: reducing requirement OR reducing track length.
  • If FinalCollapse fires often, players are reaching {FINAL_COLLAPSE_TRACK} tears without Dominion winners
    — reduce requirement or add a personal tear source.
""")

    lines.append("═" * W + "\n")
    return "\n".join(lines)


# ═══════════════════════════════════════════════════════════════════════
#  SELF-TESTS
# ═══════════════════════════════════════════════════════════════════════
def run_mechanic_tests() -> List[str]:
    failures = []

    def make_guards(values):
        return [Card('Butcher', v) for v in values]

    def fresh_game(l0='Orias', l1='Valak'):
        return Game([l0], [l1])

    # ── T1: Breakthrough — guards + structure strictly exceeded
    g = fresh_game(); guards = make_guards([5, 1])
    destroyed, broken, excess = g._combat_layers(
        g.players[0], 11, guards, False, 0, False, struct_def=4)
    if not destroyed:    failures.append("FAIL T1: Strength 11 vs 5+1+4 should destroy")
    if len(guards) != 0: failures.append("FAIL T1: Breakthrough should clear all guards")
    if excess != 1:      failures.append(f"FAIL T1: excess should be 1, got {excess}")

    # ── T2: Equality never destroys (the Golden Rule, final layer)
    g = fresh_game(); guards = make_guards([5, 1])
    destroyed, _, _ = g._combat_layers(
        g.players[0], 10, guards, False, 0, False, struct_def=4)
    if destroyed:        failures.append("FAIL T2: Strength 10 vs total 10 must NOT destroy")
    if len(guards) != 0: failures.append(f"FAIL T2: Both guards should be defeated. Got: {guards}")

    # ── T3: Partial stop — equality at a guard layer stops the attack
    g = fresh_game(); guards = make_guards([5, 1])
    destroyed, _, _ = g._combat_layers(
        g.players[0], 5, guards, False, 0, False, struct_def=4)
    if destroyed:        failures.append("FAIL T3: Strength 5 should not destroy")
    if len(guards) != 2: failures.append(f"FAIL T3: Equality vs Guard 5 defeats nothing. Got: {guards}")

    # ── T4: Mid-stack stop — first guard falls, second holds
    g = fresh_game(); guards = make_guards([5, 3])
    destroyed, _, _ = g._combat_layers(
        g.players[0], 7, guards, False, 0, False, struct_def=4)
    if destroyed: failures.append("FAIL T4: Strength 7 should not destroy")
    if sorted(x.value for x in guards) != [3]:
        failures.append(f"FAIL T4: Only guard 3 should remain. Got: {guards}")

    # ── T5: Sigil layer — broken, target survives
    g = fresh_game(); guards = make_guards([2])
    destroyed, broken, _ = g._combat_layers(
        g.players[0], 8, guards, False, sigil_value=2, has_sigil=True, struct_def=4)
    if destroyed:   failures.append("FAIL T5: 8 vs 2+2+4 must NOT destroy (equality at structure)")
    if not broken:  failures.append("FAIL T5: Sigil (2) should be Broken by remaining 6")

    # ── T6: Sigil holds — attack ends, structure untouched even if beatable
    g = fresh_game(); guards = make_guards([2])
    destroyed, broken, _ = g._combat_layers(
        g.players[0], 4, guards, False, sigil_value=2, has_sigil=True, struct_def=1)
    if destroyed: failures.append("FAIL T6: Sigil equality (2 vs 2) must stop the attack")
    if broken:    failures.append("FAIL T6: Sigil at equality is NOT Broken")

    # ── T7: Omen 0-value Sigil breaks on any attack reaching it
    g = fresh_game()
    destroyed, broken, _ = g._combat_layers(
        g.players[0], 1, [], False, sigil_value=0, has_sigil=True, struct_def=4)
    if not broken: failures.append("FAIL T7: 0-value Sigil must break on any attack")
    if destroyed:  failures.append("FAIL T7: Strength 1 vs struct 4 must not destroy")

    # ── T8: Sigil values — baseline modifiers or the v6.5 flat Ward ladder
    g = fresh_game(); pl = g.players[0]
    g.neutral_tears = 0; pl.tears = 0
    if g._sigil_value(pl, 'fresh')   != 2: failures.append("FAIL T8a: Fresh sigil = 2")
    if g._sigil_value(pl, 'flipped') != 1: failures.append("FAIL T8b: Flipped sigil = 1")
    g.neutral_tears = 3
    omen_fresh = 2 if VARIANT.get('sigil_flat', False) else 1
    if g._sigil_value(pl, 'fresh') != omen_fresh:
        failures.append(f"FAIL T8c: Fresh under Omen should be {omen_fresh}")
    pl.tears = 3; g.neutral_tears = 0   # track 3 via personal; Attunement 3 = immune
    if g._sigil_value(pl, 'fresh') != 2:
        failures.append("FAIL T8d: Attunement 3 is immune to Omen")
    pl.tears = 0
    pl.castles.add('Keep')
    keep_fresh = 2 if VARIANT.get('sigil_flat', False) else 3
    keep_flipped = 1 if VARIANT.get('sigil_flat', False) else 2
    if g._sigil_value(pl, 'fresh') != keep_fresh:
        failures.append(f"FAIL T8e: Fresh + Keep should be {keep_fresh}")
    if g._sigil_value(pl, 'flipped') != keep_flipped:
        failures.append(f"FAIL T8f: Flipped + Keep should be {keep_flipped}")

    # ── T9: Crushing Presence — lowest guard defends at 0
    g = fresh_game(); guards = make_guards([5, 1])
    destroyed, _, _ = g._combat_layers(
        g.players[0], 10, guards, True, 0, False, struct_def=4)
    if not destroyed: failures.append("FAIL T9: 10 vs (5 + crushed 1→0 + 4) = 9 should destroy")

    # ── T10: Siege Engine bypass — Sigil → Structure → Guards
    g = fresh_game(); guards = make_guards([4, 3, 2])
    destroyed, _, _ = g._combat_layers(
        g.players[0], 6, guards, False, 0, False, struct_def=7, bypass=True)
    if destroyed:        failures.append("FAIL T10a: bypass 6 vs struct 7 should NOT destroy")
    if len(guards) != 3: failures.append("FAIL T10a: guards untouched when structure holds")
    guards = make_guards([4, 3, 2])
    destroyed, _, _ = g._combat_layers(
        g.players[0], 13, guards, False, 0, False, struct_def=7, bypass=True)
    if not destroyed:    failures.append("FAIL T10b: bypass 13 vs struct 7 should destroy")
    if sorted(x.value for x in guards) != [2, 3]:
        failures.append(f"FAIL T10b: leftover 6 strips only guard 4. Got: {guards}")

    # ── T11: Threat defense penalties & lord stats
    g = fresh_game('Valak', 'Orias'); pl = g.players[0]; pl.threat = 0
    if pl.lord_base_def() != 5: failures.append("FAIL T11a: Valak threat 0 → def 5")
    pl.threat = 2
    if pl.lord_base_def() != 4: failures.append("FAIL T11b: Valak threat 2 → def 4")
    pl.threat = 4
    if pl.lord_base_def() != 2: failures.append("FAIL T11c: Valak threat 4 → def 2")

    # ── T12: Kroni hunger scaling
    g = fresh_game('Kroni', 'Orias'); pl = g.players[0]
    pl.kroni_hunger = 0
    if pl.lord_base_def() != 4: failures.append("FAIL T12a: Kroni hunger 0 → def 4")
    pl.kroni_hunger = 1
    if pl.lord_base_def() != 6: failures.append("FAIL T12b: Kroni hunger 1 → def 6")
    pl.kroni_hunger = 3
    if pl.lord_base_def() != 8: failures.append("FAIL T12c: Kroni hunger 3 → def 8")

    # ── T13: Deck construction — 60 cards, 15 per suit
    deck = make_deck_2p()
    if len(deck) != 60:
        failures.append(f"FAIL T13: 2p deck should be 60 cards, got {len(deck)}")
    suit_counts = defaultdict(int)
    for c in deck: suit_counts[c.suit] += 1
    for s in SUITS:
        if suit_counts[s] != 15:
            failures.append(f"FAIL T13: Suit {s} should have 15, got {suit_counts[s]}")

    # ── T14: Veil total = neutral + personal
    g = fresh_game()
    g.neutral_tears = 5
    g.players[0].tears = 2; g.players[1].tears = 1
    if g._total_tears() != 8:
        failures.append(f"FAIL T14: total_tears should be 8, got {g._total_tears()}")

    # ── T15: Attunement immunity — Omen (3) and Frenzy (6) ONLY
    g = fresh_game(); pl = g.players[0]
    pl.tears = 3
    if not g._immune_to_threshold(pl, 3): failures.append("FAIL T15a: Att 3 immune to Omen")
    if g._immune_to_threshold(pl, 6):     failures.append("FAIL T15b: Att 3 NOT immune to Frenzy")
    pl.tears = 7
    if g._immune_to_threshold(pl, 7):
        failures.append("FAIL T15c: Collapse (7) has NO Attunement immunity")
    if g._immune_to_threshold(pl, 9):
        failures.append("FAIL T15d: The Waning (9) has NO Attunement immunity")

    # ── T16: Reflex Bid — tie returns all cards; winner retrieves lowest
    g = fresh_game()
    p0, p1 = g.players
    p0.hand = [Card('Butcher', 4), Card('Wright', 2)]
    p1.hand = [Card('Vulture', 4), Card('Penitent', 2)]
    # Force deterministic bids by monkey-patching _ai_bid
    bids = {0: [p0.hand[0], p0.hand[1]], 1: [p1.hand[0], p1.hand[1]]}
    orig_bid = Game._ai_bid
    def fake_bid(self, pl):
        b = bids[pl.pid]
        for c in b: pl.hand.remove(c)
        return list(b)
    Game._ai_bid = fake_bid
    g._phase_reflex_bid()
    Game._ai_bid = orig_bid
    if g.reflex_winner is not None:
        failures.append("FAIL T16a: equal bids (6 vs 6) must be a tie — no Reflex")
    if len(p0.hand) != 2 or len(p1.hand) != 2:
        failures.append("FAIL T16a: tie must return ALL bid cards to hand")
    # Winner case
    g = fresh_game(); p0, p1 = g.players
    c_hi1, c_lo1 = Card('Butcher', 5), Card('Wright', 1)
    c_hi2, c_lo2 = Card('Vulture', 3), Card('Penitent', 1)
    p0.hand = [c_hi1, c_lo1]; p1.hand = [c_hi2, c_lo2]
    bids = {0: [c_hi1, c_lo1], 1: [c_hi2, c_lo2]}
    Game._ai_bid = fake_bid
    g._phase_reflex_bid()
    Game._ai_bid = orig_bid
    if g.reflex_winner != 0:
        failures.append("FAIL T16b: bid 6 beats bid 4")
    if c_lo1 not in p0.hand or c_lo2 not in p1.hand:
        failures.append("FAIL T16b: each player retrieves their single lowest bid card")
    if c_hi2 not in p1.garrison:
        failures.append("FAIL T16b: loser's remaining bid cards go to Garrison")
    if c_hi1 in p0.hand or c_hi1 in p0.garrison:
        failures.append("FAIL T16b: winner's remaining bid cards are discarded")

    # ── T17: Neutral Tears — first summon free, later summons pay
    g = fresh_game(); pl = g.players[0]
    pl.hand = [Card('Butcher', 5), Card('Butcher', 5)]
    before = g.neutral_tears
    g._ai_summon(pl, forced=True)
    if g.neutral_tears != before:
        failures.append("FAIL T17a: first summon must NOT place a Neutral Tear")
    pl.alive = False
    pl.hand = [Card('Butcher', 5), Card('Butcher', 5), Card('Butcher', 5)]
    tears_before = pl.tears
    g._ai_summon(pl, forced=True)
    _rm = VARIANT.get('resummon_tear_mode', 'neutral')
    if _rm == 'neutral' and g.neutral_tears != before + 1:
        failures.append("FAIL T17b: neutral-mode resummon places 1 Neutral Tear")
    elif _rm == 'none' and g.neutral_tears != before:
        failures.append("FAIL T17b: none-mode resummon must not place a Neutral Tear")
    elif _rm == 'summoner' and pl.tears != tears_before + 1:
        failures.append("FAIL T17b: summoner-mode resummon places 1 personal Tear")

    # ── T17c: Summoning Circle opening discount obeys circle_opening_summon.
    # The current profile explicitly disables the opening discount; a forced setup
    # summon must therefore pay printed cost even if the Circle is already standing.
    g = fresh_game(); pl = g.players[0]
    pl.castles = {'SummoningCircle'}
    pl.castle_integrity = {'SummoningCircle': castle_max_integrity('SummoningCircle')}
    pl.hand = [Card('Butcher', 5), Card('Penitent', 1)]
    old_opening = VARIANT.get('circle_opening_summon', False)
    VARIANT['circle_opening_summon'] = False
    g._ai_summon(pl, forced=True)
    if pl.hand:
        failures.append("FAIL T17c: disabled opening Circle discount must pay printed summon cost")
    VARIANT['circle_opening_summon'] = old_opening

    # ── T18: Granular Castle-Integrity repair and bounded modifiers.
    # Historical DE-v2/v5.29 profiles do not enable this subsystem, so this is
    # a profile-conditional regression rather than a universal rules assertion.
    if ACTIVE_FEATURES.get('castle_integrity', False):
        g = fresh_game('Kalligan', 'Valak'); pl = g.players[0]
        pl.alive = True
        pl.castles = {'Keep'}
        pl.castle_integrity = {'Keep': 7}
        pl.repair_token = 1
        pl.hand = [Card('Wright', 1)]
        g.breach = 'Kalligan'
        g._ai_repair_only(pl)
        # 1 paid + token 3 + Master Builder 2 + Rapid Construction 1 = 7.
        if pl.castle_integrity.get('Keep') != 14:
            failures.append("FAIL T18: bounded repair modifiers must restore Keep to 14")
        if pl.repair_token != 0 or len(pl.hand) != 0:
            failures.append("FAIL T18: repair consumes its token and exact physical card")

    # ── T19: Summon pays from HAND only
    g = fresh_game('Deimos', 'Valak'); pl = g.players[0]
    pl.alive = False
    pl.first_summon_done = True
    pl.lord = 'Deimos'
    pl.hand = [Card('Butcher', 2)]                       # 2 < 9: cannot afford
    pl.garrison = [Card('Butcher', 5), Card('Butcher', 5)]
    g._ai_summon(pl, forced=False)
    if pl.alive:
        failures.append("FAIL T19: Garrison cards must not pay Summon costs")

    # ── T20: Overkill — Hunt banish with excess ≥3 returns a card ≤3
    g = fresh_game('Deimos', 'Valak'); atk, dfn = g.players
    atk.alive = True; dfn.alive = True
    dfn.lord = 'Valak'; dfn.threat = 0; dfn.lord_guards = []
    dfn.castles = set()
    atk.committed = [Card('Butcher', 5), Card('Butcher', 5), Card('Butcher', 3)]
    # Strength 13 + butcher pair 1 = 14 vs Valak def 5 → excess 9 ≥ 3
    g._resolve_hunt(atk, dfn)
    if dfn.alive:
        failures.append("FAIL T20: Strength 14 vs def 5 must Banish")
    if not any(c.value == 3 for c in atk.hand):
        failures.append("FAIL T20: Overkill must return the committed 3 to hand")

    # ── T21: Humbaba — defense woven into the stones
    g = fresh_game('Humbaba', 'Valak'); pl = g.players[0]
    pl.castles = {'Keep', 'Bastion', 'Stockpile', 'SummoningCircle', 'SiegeEngine'}
    pl.threat = 0
    expected_humbaba = 2 + 5 + int(VARIANT.get('bastion_lord_def_bonus', 0) or 0)
    if pl.lord_base_def() != expected_humbaba:
        failures.append(f"FAIL T21a: Humbaba full board expected {expected_humbaba}, got {pl.lord_base_def()}")
    pl.castles = {'Keep'}
    if pl.lord_base_def() != 3:
        failures.append(f"FAIL T21b: Humbaba one castle = 3, got {pl.lord_base_def()}")
    pl.castles = set()
    if pl.lord_base_def() != 2:
        failures.append(f"FAIL T21c: Humbaba bare = 2, got {pl.lord_base_def()}")

    # ── T22: Gate Guard — 4th slot only while stones unbroken
    g = fresh_game('Humbaba', 'Valak'); pl = g.players[0]
    expected_slots = 4 if VARIANT['humbaba_gate4'] else 3
    if pl.max_castle_guards() != expected_slots:
        failures.append(
            f"FAIL T22a: active Gate Guard setting expected {expected_slots} slots"
        )
    pl.ruined_castles.add('Keep')
    if pl.max_castle_guards() != 3:
        failures.append("FAIL T22b: a Ruined castle breaks the Gate Guard")

    # ── T23: The Seal — Dominion +1 while Humbaba stands, off while banished
    g = fresh_game('Humbaba', 'Valak')
    g.players[0].alive = True
    base_req = DOMINION_REQUIREMENT
    expected_req = base_req + (1 if VARIANT['humbaba_seal'] else 0)
    if g._dominion_req() != expected_req:
        failures.append(
            f"FAIL T23a: active Seal setting expected requirement {expected_req}"
        )
    g.players[0].alive = False
    if g._dominion_req() != base_req:
        failures.append("FAIL T23b: Seal suspends while Humbaba is banished")

    # ── T24: Castle power gate is explicit — owned vs operational
    old_gate = VARIANT.get('castle_power_gate_mode', 'owned')
    try:
        g = fresh_game(); pl = g.players[0]
        pl.castles = {'SiegeEngine'}
        pl.castle_integrity = {'SiegeEngine': 3}
        VARIANT['castle_power_gate_mode'] = 'owned'
        if not pl.castle_power_active('SiegeEngine'):
            failures.append("FAIL T24a: owned gate must power a standing 3-Integrity Engine")
        VARIANT['castle_power_gate_mode'] = 'operational'
        if pl.castle_power_active('SiegeEngine'):
            failures.append("FAIL T24b: operational gate must suppress a Defunct 3-Integrity Engine")
    finally:
        VARIANT['castle_power_gate_mode'] = old_gate

    # ── T25: Forge Discipline has one contextual truth across Hunt/Siege
    old_scope = VARIANT.get('siege_engine_scope', 'siege')
    old_gate = VARIANT.get('castle_power_gate_mode', 'owned')
    try:
        VARIANT['castle_power_gate_mode'] = 'owned'
        VARIANT['siege_engine_scope'] = 'siege'
        g = fresh_game(); pl = g.players[0]
        pl.castles = {'SiegeEngine'}
        pl.castle_integrity = {'SiegeEngine': 14}
        off = Card('Wright', 5)
        pl.committed = [off]
        if pl.attack_value(siege=True) != 5:
            failures.append("FAIL T25a: operational Siege Engine must exempt Siege from attack tax")
        expected_hunt = max(int(VARIANT.get('attack_offsuit_floor', 1)), 5 - int(VARIANT.get('attack_offsuit_penalty', 0)))
        if pl.attack_value(siege=False) != expected_hunt:
            failures.append("FAIL T25b: siege-scope Engine must NOT exempt Hunt")
        pl.disabled_castle_powers.add('SiegeEngine')
        if pl.attack_value(siege=True) != expected_hunt:
            failures.append("FAIL T25c: ablated Siege Engine must not exempt Siege")
    finally:
        VARIANT['siege_engine_scope'] = old_scope
        VARIANT['castle_power_gate_mode'] = old_gate

    # ── T26: Strategic target selection does not mechanically force Bastion
    old_gate = VARIANT.get('castle_power_gate_mode', 'owned')
    old_targeting = VARIANT.get('castle_targeting_mode', 'strategic')
    try:
        VARIANT['castle_power_gate_mode'] = 'owned'
        VARIANT['castle_targeting_mode'] = 'strategic'
        g = fresh_game(); atk, dfn = g.players
        dfn.alive = True
        dfn.castles = {'Bastion', 'Keep'}
        dfn.castle_integrity = {'Bastion': 14, 'Keep': 1}
        target = g._pick_siege_target(atk, dfn)
        if target != 'Keep':
            failures.append(f"FAIL T26: strategic targeting should finish wounded Keep, got {target}")
    finally:
        VARIANT['castle_power_gate_mode'] = old_gate
        VARIANT['castle_targeting_mode'] = old_targeting

    # ── T27: Commitment reads immutable precommit opponent pool
    if VARIANT.get('ward_commit_any', False):
        g = fresh_game(); p0, p1 = g.players
        p0.hand = [Card('Penitent', 5), Card('Penitent', 5)]
        p1.hand = []
        p1.garrison = []
        g._precommit_pool_value = [10, 10]
        g._commit_for_ward(p0, 'neutral')
        if not p0.committed:
            failures.append("FAIL T27: Ward sizing leaked sequentially-mutated opponent hand")
        g._precommit_pool_value = None

    # ── T28: Named RNG streams make identical seeds replay-identical
    g1 = Game(['Vanilla'], ['Vanilla'], seed=123456)
    g2 = Game(['Vanilla'], ['Vanilla'], seed=123456)
    r1 = g1.run(); r2 = g2.run()
    state1 = (r1, g1.round, tuple((p.souls, p.tears, p.threat, len(p.castles)) for p in g1.players), g1.neutral_tears)
    state2 = (r2, g2.round, tuple((p.souls, p.tears, p.threat, len(p.castles)) for p in g2.players), g2.neutral_tears)
    if state1 != state2:
        failures.append("FAIL T28: identical game seed did not replay identically")

    # ── T29: Per-seat Castle ablation suppresses only that seat's identity
    g = Game(['Vanilla'], ['Vanilla'], disabled_castle_powers={0: {'Keep'}})
    for pl in g.players:
        pl.castles = {'Keep'}
        pl.castle_integrity = {'Keep': 14}
    if g.players[0].castle_power_active('Keep'):
        failures.append("FAIL T29a: treated seat Keep power should be ablated")
    if not g.players[1].castle_power_active('Keep'):
        failures.append("FAIL T29b: opponent Keep power should remain live")

    # ── T30: Sanctuary is present in doctrine sizing, not resolver-only
    old_gate = VARIANT.get('castle_power_gate_mode', 'owned')
    try:
        VARIANT['castle_power_gate_mode'] = 'owned'
        g = Game(['Vanilla'], ['Vanilla'], seed=99)
        atk, dfn = g.players
        dfn.alive = True
        dfn.castles = {'Keep'}
        dfn.castle_integrity = {'Keep': 14}
        with_keep, _ = g._estimate_attack_defense(atk, dfn, 'Lord', context='test30a')
        dfn.disabled_castle_powers.add('Keep')
        without_keep, _ = g._estimate_attack_defense(atk, dfn, 'Lord', context='test30b')
        if VARIANT.get('keep_sanctuary', False) and with_keep - without_keep != 13:
            failures.append(
                f"FAIL T30: full Keep Sanctuary should add 13 to kill estimate, got {with_keep-without_keep}")
    finally:
        VARIANT['castle_power_gate_mode'] = old_gate

    # ── T31: Bastion is directly targetable, but a standing Defunct Bastion
    # still physically screens damage aimed at a rear Castle.
    old_gate = VARIANT.get('castle_power_gate_mode', 'owned')
    try:
        VARIANT['castle_power_gate_mode'] = 'operational'
        # Rear-target breakthrough: 8 structural Strength reaches a Defunct
        # Bastion at 6 HP, so Bastion Ruins and exactly 2 carries into Keep.
        g = fresh_game('Vanilla', 'Vanilla'); atk, dfn = g.players
        atk.committed = [Card('Butcher', 8)]
        dfn.action = ''; dfn.committed = []; dfn.castle_guards = []; dfn.sigils['Castle'] = ''
        dfn.castles = {'Bastion', 'Keep'}
        dfn.castle_integrity = {'Bastion': 6, 'Keep': 14}
        g._resolve_siege(atk, dfn, forced_target='Keep')
        if 'Bastion' in dfn.castles or dfn.castle_integrity.get('Keep') != 12:
            failures.append(
                f"FAIL T31a: Defunct Bastion should screen 6 then spill 2; "
                f"castles={dfn.castles}, Keep={dfn.castle_integrity.get('Keep')}")

        # Strategic doctrine should choose a rear target because direct Bastion
        # targeting wastes overflow, even though direct targeting remains legal.
        g = fresh_game('Vanilla', 'Vanilla'); atk, dfn = g.players
        dfn.castles = {'Bastion', 'Keep'}
        dfn.castle_integrity = {'Bastion': 6, 'Keep': 14}
        if g._pick_siege_target(atk, dfn) == 'Bastion':
            failures.append('FAIL T31b: AI should not waste Bastion overflow on a dominated direct target')

        # Forced/direct targeting must still hit Bastion itself with no rear spill.
        g = fresh_game('Vanilla', 'Vanilla'); atk, dfn = g.players
        atk.committed = [Card('Butcher', 8)]
        dfn.action = ''; dfn.committed = []; dfn.castle_guards = []; dfn.sigils['Castle'] = ''
        dfn.castles = {'Bastion', 'Keep'}
        dfn.castle_integrity = {'Bastion': 6, 'Keep': 14}
        g._resolve_siege(atk, dfn, forced_target='Bastion')
        if 'Bastion' in dfn.castles or dfn.castle_integrity.get('Keep') != 14:
            failures.append(
                f"FAIL T31c: direct Bastion target should Ruin Bastion without touching Keep; "
                f"castles={dfn.castles}, Keep={dfn.castle_integrity.get('Keep')}")
    finally:
        VARIANT['castle_power_gate_mode'] = old_gate

    # ── T32: planning probes do not inflate actual-target telemetry
    g = Game(['Vanilla'], ['Vanilla'])
    atk, dfn = g.players
    dfn.castles = {'Keep', 'Bastion'}
    dfn.castle_integrity = {'Keep': 14, 'Bastion': 14}
    chosen = g._pick_siege_target(atk, dfn)
    if sum(g.stat_castle_targeted[dfn.pid].values()) != 0:
        failures.append("FAIL T32a: planning target probe counted as an actual Siege")
    g._pick_siege_target(atk, dfn, record=True)
    if sum(g.stat_castle_targeted[dfn.pid].values()) != 1:
        failures.append("FAIL T32b: resolved target was not recorded exactly once")

    # ── T33: Ward is the FIRST combat layer, ahead of permanent Guards/Sigil.
    g = fresh_game(); guards = make_guards([5])
    destroyed, broken, _ = g._combat_layers(
        g.players[0], 5, guards, False, 2, True, struct_def=4, ward_screen=5)
    if destroyed or broken or len(guards) != 1:
        failures.append("FAIL T33a: Ward equality must stop attack before Guard/Sigil")
    guards = make_guards([3])
    destroyed, broken, _ = g._combat_layers(
        g.players[0], 11, guards, False, 2, True, struct_def=4, ward_screen=5)
    if destroyed or not broken or guards:
        failures.append("FAIL T33b: Ward breakthrough must continue Ward→Guard→Sigil→target")

    # ── T34: Ward commitments persist even if Ward resolves before the attack.
    g = fresh_game('Vanilla', 'Vanilla'); atk, dfn = g.players
    dfn.alive = True
    atk.action = 'Hunt'; atk.committed = [Card('Butcher', 6)]
    dfn.action = 'Ward'; dfn.ward_target = 'Lord'; dfn.committed = [Card('Penitent', 7)]
    dfn.sigils['Lord'] = ''
    dfn.lord_guards = []
    dfn.ward_turned.clear()
    g._phase_resolution([dfn.pid, atk.pid])
    if not dfn.alive:
        failures.append("FAIL T34a: higher-initiative Ward was discarded before the later Hunt")
    if atk.committed or dfn.committed:
        failures.append("FAIL T34b: primary commitments must leave after both actions resolve")

    # ── T35: Sanctuary transfers EXACT Hunt excess (no +1 off-by-one).
    old_gate = VARIANT.get('castle_power_gate_mode', 'owned')
    try:
        VARIANT['castle_power_gate_mode'] = 'operational'
        g = fresh_game('Vanilla', 'Vanilla'); atk, dfn = g.players
        dfn.alive = True
        atk.action = 'Hunt'; atk.committed = [Card('Butcher', 6)]
        dfn.action = ''; dfn.committed = []; dfn.lord_guards = []; dfn.sigils['Lord'] = ''
        dfn.castles = {'Keep'}; dfn.castle_integrity = {'Keep': 14}
        before = dfn.castle_integrity['Keep']
        base_def = dfn.lord_base_def(breach=g.breach)
        # Vanilla DEF is 5 in this fixture, so Strength 6 should transfer exactly 1.
        if base_def != 5:
            failures.append(f"FAIL T35 fixture: expected Vanilla DEF 5, got {base_def}")
        g._resolve_hunt(atk, dfn)
        if not dfn.alive or dfn.castle_integrity['Keep'] != before - 1:
            failures.append(
                f"FAIL T35: Sanctuary should absorb exactly 1 excess; alive={dfn.alive}, "
                f"Keep={dfn.castle_integrity.get('Keep')}")
    finally:
        VARIANT['castle_power_gate_mode'] = old_gate

    # ── T35b: Summoning Circle Blood Offering burns 3 Integrity for 3 cost.
    old_gate = VARIANT.get('castle_power_gate_mode', 'owned')
    try:
        VARIANT['castle_power_gate_mode'] = 'operational'
        g = fresh_game('Vanilla', 'Vanilla'); pl = g.players[0]
        pl.alive = False
        pl.castles = {'SummoningCircle'}
        pl.castle_integrity = {'SummoningCircle': 14}
        pl.hand = [Card('Wright', 3), Card('Butcher', 3)]
        pl.lord_pool = ['Vanilla']
        before_value = sum(c.value for c in pl.hand)
        g._ai_summon(pl, forced=False)
        after_value = sum(c.value for c in pl.hand)
        printed = summon_base_cost('Vanilla')
        expected_paid = max(0, printed - int(VARIANT.get('circle_blood_summon_discount', 3)))
        if (not pl.alive or pl.castle_integrity.get('SummoningCircle') != 11
                or before_value - after_value != expected_paid):
            failures.append(
                f"FAIL T35b: Blood Offering should Exert 3 and reduce Summon by 3; "
                f"alive={pl.alive}, Circle={pl.castle_integrity.get('SummoningCircle')}, "
                f"paid~={before_value-after_value}, expected={expected_paid}")
    finally:
        VARIANT['castle_power_gate_mode'] = old_gate

    # ── T36: current Ward ignores legacy pre-combat ward_turned cancellation.
    g = fresh_game('Vanilla', 'Vanilla'); atk, dfn = g.players
    dfn.alive = True
    atk.action = 'Hunt'; atk.committed = [Card('Butcher', 6)]
    dfn.action = ''; dfn.committed = []; dfn.lord_guards = []; dfn.sigils['Lord'] = ''
    dfn.ward_turned.add('Lord')
    g._resolve_hunt(atk, dfn)
    if dfn.alive:
        failures.append("FAIL T36: ward_turned shortcut still cancelled combat in reinforcement mode")

    return failures


# ═══════════════════════════════════════════════════════════════════════
#  ENTRY POINT
# ═══════════════════════════════════════════════════════════════════════
def main():
    parser = argparse.ArgumentParser(
        description='CORRUPTOR Balance Simulation — current Castle Integrity profile',
    )
    parser.add_argument('--games', type=int, default=500)
    parser.add_argument('--quiet', action='store_true')
    parser.add_argument('--seed',  type=int, default=None)
    parser.add_argument('--allow-failed-tests', action='store_true',
                        help='Dangerous: continue simulation even if regression tests fail.')
    parser.add_argument('--castle-experiment', choices=tuple(CASTLES) + ('all',), default=None,
                        help='Run paired crossed-seat Castle causal experiments instead of roster grid.')
    parser.add_argument('--experiment-mode', choices=('add', 'remove', 'both'), default='both',
                        help='ADD isolates a power; REMOVE ablates it from the full Castle ecosystem.')
    parser.add_argument('--experiment-seeds',
                        default=','.join(str(x) for x in CASTLE_EXPERIMENT_SEEDS),
                        help='Comma-separated replication seeds for Castle experiments.')
    parser.add_argument('--castle-gate', choices=('owned', 'operational', 'both'), default='operational',
                        help='Castle power gate: standing-at-1HP legacy, Defunct-at-<7, or sweep both.')
    parser.add_argument('--castle-targeting', choices=('strategic', 'legacy'), default='strategic')
    parser.add_argument('--castle-owner-doctrine', choices=('strategic', 'legacy'), default='strategic')
    parser.add_argument('--experiment-lord', choices=tuple(LORD_STATS), default='Vanilla')
    parser.add_argument('--experiment-opponent', choices=tuple(LORD_STATS), default='Vanilla')
    parser.add_argument('--single-loadout-context', action='store_true',
                        help='Faster but weaker: use one opening loadout instead of all containing the tested Castle.')
    parser.add_argument(
        '--output',
        default=None,
        help='Optional report path. Defaults to a report in the current working directory.',
    )
    parser.add_argument('--lock',  action='store_true',
                        help='Lock each player to one lord — pure head-to-head, no switching')
    parser.add_argument(
        '--ruleset',
        choices=('de-v2', 'v5.29', 'lab-v6.5'),
        default='lab-v6.5',
        help='Rules preset. Defaults to the current Castle Integrity profile; de-v2 remains for historical golden traces.',
    )
    parser.add_argument('--recoil-hunts-only',     action='store_true', default=None)
    parser.add_argument('--sigil-soul-fresh-only', action='store_true', default=None)
    parser.add_argument('--invocation-gate',  type=int, default=None)
    parser.add_argument('--profane-ruins-req', type=int, default=None)
    parser.add_argument('--ai-dominion', action='store_true', default=None)
    parser.add_argument('--no-backwash', action='store_true', default=None)
    parser.add_argument('--reconfig-strict', action='store_true', default=None)
    parser.add_argument('--kroni-def-soft', action='store_true', default=None)
    parser.add_argument('--kroni-hunger-decay', action='store_true', default=None)
    parser.add_argument('--deimos-war-machine-free', action='store_true', default=None)
    parser.add_argument('--deimos-summon-cost', type=int, default=None)
    parser.add_argument('--recoil-lowest', action='store_true', default=None)
    parser.add_argument('--neutral-tear-on-banish', action='store_true', default=None)
    parser.add_argument('--castle-tear-uncapped', action='store_true', default=None)
    parser.add_argument('--veil-drift', type=int, default=None)
    parser.add_argument('--invocation-repeatable', action='store_true', default=None)
    parser.add_argument('--reconfig-tokens', type=int, default=None)
    parser.add_argument('--reconfig-neutral', action='store_true', default=None)
    parser.add_argument('--deimos-claims-breach', type=int, default=None)
    parser.add_argument('--consume-the-siege', action='store_true', default=None)
    parser.add_argument('--war-machine-ignores-profaned', action='store_true', default=None)
    parser.add_argument('--gremory-summon-cost', type=int, default=None)
    parser.add_argument('--no-humbaba-seal',    action='store_true')
    parser.add_argument('--no-humbaba-toll',    action='store_true')
    parser.add_argument('--no-humbaba-gate4',   action='store_true')
    parser.add_argument('--no-humbaba-patient', action='store_true')
    parser.add_argument('--dominion-req', type=int, default=None)
    parser.add_argument('--win-souls', type=int, default=None)
    parser.add_argument('--dominion-track', type=int, default=None)
    args = parser.parse_args()

    if args.seed is not None:
        random.seed(args.seed)  # compatibility only; Game uses named deterministic streams

    presets = {
        'de-v2': (DE_V2_VARIANT, DE_V2_CONSTANTS, DE_V2_FEATURES),
        'v5.29': (BASE_V5_29_VARIANT, BASE_V5_29_CONSTANTS, BASE_V5_29_FEATURES),
        'lab-v6.5': (LAB_V6_5_VARIANT, LAB_V6_5_CONSTANTS, LAB_V6_5_FEATURES),
    }
    preset_variant, preset_constants, _preset_features = presets[args.ruleset]
    activate_ruleset(args.ruleset)

    variant_overrides = {
        'recoil_hunts_only': args.recoil_hunts_only,
        'sigil_soul_fresh_only': args.sigil_soul_fresh_only,
        'invocation_gate': args.invocation_gate,
        'profane_ruins_req': args.profane_ruins_req,
        'ai_dominion_drive': args.ai_dominion,
        'no_backwash': args.no_backwash,
        'reconfig_strict': args.reconfig_strict,
        'kroni_def_soft': args.kroni_def_soft,
        'kroni_hunger_decay': args.kroni_hunger_decay,
        'deimos_war_machine_free': args.deimos_war_machine_free,
        'deimos_summon_cost': args.deimos_summon_cost,
        'recoil_lowest': args.recoil_lowest,
        'neutral_tear_on_banish': args.neutral_tear_on_banish,
        'castle_tear_uncapped': args.castle_tear_uncapped,
        'veil_drift': args.veil_drift,
        'invocation_repeatable': args.invocation_repeatable,
        'reconfig_tokens_needed': args.reconfig_tokens,
        'reconfig_neutral': args.reconfig_neutral,
        'deimos_claims_breach': args.deimos_claims_breach,
        'consume_the_siege': args.consume_the_siege,
        'war_machine_ignores_profaned': args.war_machine_ignores_profaned,
        'gremory_summon_cost': args.gremory_summon_cost,
    }

    for key, value in variant_overrides.items():
        if value is not None:
            VARIANT[key] = value

    VARIANT['castle_targeting_mode'] = args.castle_targeting
    VARIANT['castle_owner_doctrine'] = args.castle_owner_doctrine
    if args.castle_gate != 'both':
        VARIANT['castle_power_gate_mode'] = args.castle_gate

    if args.no_humbaba_seal:
        VARIANT['humbaba_seal'] = False
    if args.no_humbaba_toll:
        VARIANT['humbaba_toll'] = False
    if args.no_humbaba_gate4:
        VARIANT['humbaba_gate4'] = False
    if args.no_humbaba_patient:
        VARIANT['humbaba_patient'] = False

    global DOMINION_REQUIREMENT, WIN_SOULS
    DOMINION_REQUIREMENT = (
        args.dominion_req
        if args.dominion_req is not None
        else preset_constants['DOMINION_REQUIREMENT']
    )
    WIN_SOULS = (
        args.win_souls
        if args.win_souls is not None
        else preset_constants['WIN_SOULS']
    )
    global DOMINION_TRACK
    DOMINION_TRACK = (
        args.dominion_track
        if args.dominion_track is not None
        else preset_constants['DOMINION_TRACK']
    )

    # Apply CLI override
    global LOCK_LORDS
    if args.lock:
        LOCK_LORDS = True

    print("Running mechanic unit tests...")
    failures = run_mechanic_tests()
    if failures:
        print(f"\n  ⚠  {len(failures)} test(s) FAILED:")
        for f in failures:
            print(f"     {f}")
        if not args.allow_failed_tests:
            print("\n  ABORTED: v7 never runs measurements on a failing build.\n")
            raise SystemExit(2)
        print("\n  DANGEROUS OVERRIDE: continuing despite failed tests.\n")
    else:
        print("  ✓ All mechanic/regression tests passed.\n")

    # Castle causal harness is a first-class mode, not an external patch script.
    if args.castle_experiment is not None:
        castles = CASTLES if args.castle_experiment == 'all' else [args.castle_experiment]
        modes = ('add', 'remove') if args.experiment_mode == 'both' else (args.experiment_mode,)
        gates = ('owned', 'operational') if args.castle_gate == 'both' else (args.castle_gate,)
        seeds = tuple(int(x.strip()) for x in args.experiment_seeds.split(',') if x.strip())
        reports = []
        summaries = []
        t0 = time.time()
        for castle in castles:
            for mode in modes:
                for gate in gates:
                    result = run_castle_experiment(
                        castle, mode=mode, games_per_seed=args.games, seeds=seeds,
                        gate_mode=gate, treated_lord=args.experiment_lord,
                        opponent_lord=args.experiment_opponent,
                        all_loadout_contexts=not args.single_loadout_context,
                    )
                    summaries.append(result)
                    reports.append(format_castle_experiment(result))
                    if not args.quiet:
                        print(reports[-1])
                        print()
        report = '\n\n'.join(reports)
        elapsed = time.time() - t0
        print(f"Castle experiment completed in {elapsed:.1f}s")
        if args.quiet:
            print(report)
        out_path = args.output or 'corruptor_castle_experiment_v7.txt'
        with open(out_path, 'w') as f:
            f.write(report + '\n')
        print(f"Report saved to: {out_path}")
        return

    matchups = list(itertools.combinations(ALL_LORDS, 2))
    total    = len(matchups) * args.games
    results  = {}
    t0       = time.time()

    print(f"Running {len(matchups)} matchups × {args.games:,} games = {total:,} total games...")
    print(f"Lords: {', '.join(ALL_LORDS)}")
    print(f"Veil: track {DOMINION_TRACK}, requirement {DOMINION_REQUIREMENT} personal tears, collapse {FINAL_COLLAPSE_TRACK}\n")

    for i, (l0, l1) in enumerate(matchups, 1):
        if not args.quiet:
            pct     = (i - 1) / len(matchups) * 100
            elapsed = time.time() - t0
            eta     = (elapsed / max(i - 1, 1)) * (len(matchups) - (i - 1))
            print(f"  [{i:>2}/{len(matchups)}]  {l0:<10} vs {l1:<10}  "
                  f"({pct:>4.0f}% done, ETA {eta:>4.0f}s)", end='\r')
        results[(l0, l1)] = run_matchup(l0, l1, args.games, base_seed=(args.seed if args.seed is not None else 1))

    elapsed = time.time() - t0
    print(f"\n  Completed {total:,} games in {elapsed:.1f}s  ({total/elapsed:,.0f} games/sec)\n")

    report = generate_report(results, args.games)
    print(report)

    mode_tag = 'locked' if LOCK_LORDS else 'pool'
    out_path = (
        args.output
        if args.output is not None
        else f'corruptor_balance_report_v7_{mode_tag}.txt'
    )
    with open(out_path, 'w') as f:
        f.write(report)
    print(f"Report saved to: {out_path}")


if __name__ == '__main__':
    main()
