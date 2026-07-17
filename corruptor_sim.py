#!/usr/bin/env python3
"""
╔══════════════════════════════════════════════════════════════════════╗
║          CORRUPTOR — Balance Simulation                             ║
║          SIM_VERSION 6.0  ·  "DE v2 + Humbaba"                      ║
║          AI_POLICY heuristic-2025.06-doctrine                       ║
║                                                                      ║
║  Tests all 9 lords across every head-to-head matchup.               ║
║  Rules axis  (SIM_VERSION): bump on any rule/dial change —           ║
║      invalidates golden-master traces.                               ║
║  Policy axis (AI_POLICY):   bump on any bot-doctrine change —        ║
║      invalidates balance grids (Law 5). The two are independent.     ║
║                                                                      ║
║  Usage:                                                              ║
║    python corruptor_sim.py               (500 games/matchup)        ║
║    python corruptor_sim.py --games 2000  (more games = more stable) ║
║    python corruptor_sim.py --quiet       (suppress progress)        ║
╚══════════════════════════════════════════════════════════════════════╝

SIM_VERSION history
───────────────────
  1.0        Original 8-lord sim (Humbaba present, pre-Kroni). Archived.
  5.29-sync  Rebuilt to Rulebook v5.29 (Reflex Bid, sigils, veil, rites).
  5.29+DEv2  Tuned errata pass: recoil hunts-only/lowest, Kroni decay,
             Deimos buffs + Claim the Breach, Gremory-6, Dominion Edition
             (track 11, req 2, banish-tears, invocation gate 5).
  6.0        Ninth lord: Humbaba, Ancient Guardian (Seal · Toll · Gate
             Guard · Patient Hunger · The Stones Forget). Doctrine pass
             (chip/alternating AI).
  6.0.1      Python oracle identity correction: every physical card is a
             distinct object; Ruinous Harvest removes the exact most-recent
             eligible discard entry. CURRENT.

CHANGELOG (rulebook alignment — retained for reference)
───────────────────────────────────────────────────────
This version aligns the simulation with Rulebook v5.29. Major changes:

• REFLEX BID rebuilt per rulebook: tie → all bid cards return to hand,
  no Reflex; winner → each player retrieves single lowest bid card,
  winner discards rest, loser garrisons rest. Winner gains an optional
  SECOND ACTION after full Resolution with full board knowledge
  (Siege Engine bypass does not apply; Sigil placed is uncontested
  Fresh; Hunt still costs 1 Threat). Skipped in round 1.
• RESOLUTION ORDER: by committed Subject value (higher first), not bid.
• SIGILS rebuilt: two independent zones (Lord/Castle) per player, own
  zones only. Contest at Reveal (attack committed value strictly
  greater → Flipped, else Fresh). Lifecycle Fresh→Flipped→Removed.
  Sigil is a combat LAYER after Guards: Broken if remaining Strength
  strictly exceeds value; Broken + target survives → controller +1 Soul.
  Fresh +2 / Flipped +1 (+1 with active Keep). Omen −1 (min 0); a
  0-value Sigil breaks on any attack reaching it. Fresh Sigils block
  opponent Profane (Flipped do not).
• VICTORY: WIN_SOULS 7 · Cataclysm at 12 · Final Collapse at 15.
• VEIL: 3 Omen · 6 Frenzy · 7 Collapse · 9 The Waning (stacks with
  Collapse) · 12 Cataclysm · 15 Final Collapse. Removed 13/14 extras.
  Attunement immunity ONLY for Omen (3+) and Frenzy (6+).
• DOMINION RITES completed: Profane is now a Commitment action (Siege
  + own color, cancelled by opponent Fresh Sigil, Tear at end of
  Resolution); Cataclysmic Invocation per rulebook (Veil already ≥7,
  discard ≥11 total value, once per game); Profane the Ruins added
  (2+ Ruined → Profane one Ruined for a Tear, once per round);
  Offer the Vessel added (once per game, Tear, opponent +1 Soul,
  Lord guards destroyed, Lord removed, no Breach, resummons at Threat 2).
• HUNT: Overkill added (Banish with excess ≥3 → return one committed
  card ≤3 to hand). Orias Marked Prey fixed to +1/+1 (removed stray +2)
  and kill bonus fixed to +2 Souls vs 3+ Threat lords.
• VALAK Siphon now fires on Hunt AND Siege, regardless of destruction.
• ODRADEK Psychic Recoil awards its Soul on Sieges too, pre-combat.
• ODRADEK Breach (Paradox Geometry) now steals the Reflex second action
  on an action-card match (replaces old resolve-order swap).
• KANIFOUS: Invoke Penitent places 2 deck cards as temporary guards
  (chosen card no longer doubles as a guard). Removed non-rulebook
  mirror-draw on opponent outside-draws.
• DEVELOPMENT reordered per rulebook: Sigil Update → Veil → Draw →
  Market → Repair → Dominion Rites → Deploy → Summon. Repairing without
  a Repair token now actually restricts hand→Guards deployment.
  Round 1 is a full round without the Reflex Bid.
• SUMMON costs paid from HAND ONLY (Garrison cannot pay). Repair may
  still pay from hand + Garrison. Repair floor is 1, applied once after
  all discounts (token −3, Master Builder −5/−7, Rapid Construction −1).
• MARKET swap now places the swapped card INTO the Market.
• REMOVED non-rulebook mechanics: damaged-zone guard caps, Threat −1 on
  castle destroyed, corrupting (opponent-zone) wards, legacy −2 Scorch
  defense penalty (persistent Scorch guard-strip retained).
"""

SIM_VERSION = "6.0.1"                        # trace-affecting oracle implementation version
SIM_CODENAME = "DE v2 + Humbaba"
AI_POLICY = "heuristic-2025.06-doctrine"     # policy axis — pins balance grids (Law 5)

import random
import argparse
import time
from collections import defaultdict
from typing import List, Set, Optional, Tuple
import itertools

# ═══════════════════════════════════════════════════════════════════════
#  CONSTANTS
# ═══════════════════════════════════════════════════════════════════════
SUITS = ['Butcher', 'Penitent', 'Vulture', 'Wright']
CARD_DIST = {1: 4, 2: 4, 3: 4, 4: 3, 5: 3}

HAND_LIMIT   = 10
GARRISON_MAX = 5
WIN_SOULS    = 7
MAX_THREAT   = 4
MARKET_SIZE  = 3
MAX_ROUNDS   = 60

# Dominion / Veil track (Standard mode, rulebook v5.29)
DOMINION_TRACK      = 12
DOMINION_REQUIREMENT = 3
FINAL_COLLAPSE_TRACK = 15

# ── Design-lever variants (candidate erratas — all False/default = pure v5.29)
VARIANT = dict(
    recoil_hunts_only=False,      # O1: Psychic Recoil (strip + Soul) fires on Hunts only
    sigil_soul_fresh_only=False,  # S1: sigil-break Soul only if the Sigil was Fresh
    invocation_gate=7,            # D1: Veil threshold to unlock Cataclysmic Invocation
    profane_ruins_req=2,          # D2: Ruined Castles needed for Profane the Ruins
    ai_dominion_drive=False,      # A1: AI actively pursues the Dominion race
    no_backwash=False,            # O3: remove Psychic Backwash (Threat on hunters)
    reconfig_strict=False,        # O4: ANY Guard defeat in Odradek zones denies the token
    kroni_def_soft=False,         # K3: Hunger defense curve 4/5/7 instead of 4/6/8
    kroni_hunger_decay=False,     # K1: Hunger -1 any round Kroni initiates no attack
    deimos_war_machine_free=False,# E1: War Machine no longer requires Siege Engine
    deimos_summon_cost=0,         # E2/E3: override Deimos Summon cost (0 = printed 9)
    recoil_lowest=False,          # O5: Recoil strips the LOWEST committed card
    neutral_tear_on_banish=False, # D3: Banishing a Lord tears the Veil (1 Neutral Tear)
    castle_tear_uncapped=False,   # D4: EVERY Castle destroyed places a Neutral Tear
    veil_drift=0,                 # D5: every N rounds the Veil frays (+1 Neutral), 0=off
    invocation_repeatable=False,  # D6: Cataclysmic Invocation once per ROUND, not per game
    reconfig_tokens_needed=3,     # O6: Reconfiguration tokens per Tear (rulebook 3)
    reconfig_neutral=False,       # O7: Reconfiguration places NEUTRAL Tears (not personal)
    deimos_claims_breach=0,       # E4: 0=off, 1=first castle kill per GAME is personal, 2=every
    consume_the_siege=False,      # D7: any lord may forgo Siege Souls -> personal Tear
    war_machine_ignores_profaned=False,  # E5: self-Profaned castles don't reduce War Machine
    gremory_summon_cost=0,        # G1: override Gremory Summon cost (0 = printed 5)
    # ── Humbaba, Ancient Guardian (ninth lord) ──
    humbaba_seal=True,            # H1: Dominion needs +1 personal Tear while he stands
    humbaba_toll=True,            # H2: once/round ruin own castle -> opp -1 Soul, +1 Neutral Tear
    humbaba_gate4=True,           # H3: 4th castle guard slot while no Ruined castles
    humbaba_patient=True,         # H4: passive round preserves one Sigil from decay
)

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
CASTLE_COST = CASTLE_DEF   # repair cost == defense value for all castles
CASTLES = list(CASTLE_DEF.keys())

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
}
ALL_LORDS = list(LORD_STATS.keys())

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
}

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
}


# ═══════════════════════════════════════════════════════════════════════
#  CARD & DECK
# ═══════════════════════════════════════════════════════════════════════
class Card:
    __slots__ = ('suit', 'value')
    def __init__(self, suit: str, value: int):
        self.suit  = suit
        self.value = value
    def __repr__(self): return f"{self.suit[0]}{self.value}"


def summon_base_cost(lord: str) -> int:
    if lord == 'Deimos' and VARIANT['deimos_summon_cost']:
        return VARIANT['deimos_summon_cost']
    if lord == 'Gremory' and VARIANT['gremory_summon_cost']:
        return VARIANT['gremory_summon_cost']
    return LORD_STATS[lord]['s']


def make_deck_2p() -> List[Card]:
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

    random.shuffle(cards)
    removed = defaultdict(int)
    deck = []
    for c in cards:
        if removed[c.suit] < 3:
            removed[c.suit] += 1
        else:
            deck.append(c)
    random.shuffle(deck)
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

        self.souls   = 0
        self.tears   = 0   # personal tears only — Attunement = self.tears
        self.threat  = 0

        # Per-game flags
        self.cataclysmic_used     = False
        self.vessel_used          = False
        self.vessel_offered_lord  = ''    # that lord resummons at Threat 2
        self.repair_token         = 0     # max 1; earned via Wright suit bonus; persists across rounds
        self.kalligan_repair_used = False
        self.repair_token_used_this_repair = False
        self.repaired_this_round = False
        self.kroni_ravenous_used  = False
        self.deimos_breach_claimed = False
        self.humbaba_patient = False   # set at end of round, consumed at Sigil Update
        self.first_summon_done    = False   # first summon doesn't trigger Neutral Tear

        # Kroni Hunger
        self.kroni_hunger = 0

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

        self.odradek_recoil_done         = False
        self.odradek_guards_defeated     = 0   # guards defeated from Odradek zones this round
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

    def committed_value(self) -> int:
        return sum(c.value for c in self.committed)

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
            if 'Bastion' in self.castles:
                d += 2
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

        if 'Bastion' in self.castles:
            d += 2

        return max(0, d)

    def castle_def(self, target: str, breach: Optional[str] = None, game=None) -> int:
        d = CASTLE_DEF.get(target, 0)
        if breach == 'Deimos':
            d = max(0, d - 1)
        # Humbaba Breach — The Stones Forget: all structures soften
        if breach == 'Humbaba':
            d = max(1, d - 1)
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
    def __init__(self, pool0: list, pool1: list):
        self.players = [Player(0, pool0), Player(1, pool1)]
        self.deck:    List[Card] = []
        self.discard: List[Card] = []
        self.market:  List[Card] = []
        self.breach:  Optional[str] = None
        self.breach_owner: int = -1          # pid whose banished lord fuels the Breach
        self.reflex_winner: Optional[int] = None   # this round's Reflex Bid winner

        self.orias_marked_lord: Optional[str] = None

        # Veil track — neutral + personal tears
        self.neutral_tears = 0
        self.first_castle_neutral_done = False  # reset each round

        # Persistent Scorch token (Kalligan Wildfire/Inferno)
        # Survives across rounds until replaced. Defeats all Guards ≤2 in
        # the affected zone at the start of each Resolution.
        self.persist_scorch_pid:  int = -1   # which player's zone
        self.persist_scorch_type: str = ''   # 'Lord' or 'Castle'

        # Odradek Reconfiguration token (3 = personal Tear)
        self.odradek_reconfig_tokens: int = 0  # persists across rounds, resets on summon

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
        self.stat_castles_destroyed = 0
        self.stat_ward_souls        = 0
        self.stat_ritual_souls      = 0
        self.stat_hunt_souls        = 0
        self.stat_personal_tears    = 0
        self.stat_neutral_tears     = 0
        self.stat_breach_triggers   = 0
        self.stat_humbaba_tolls     = 0

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

            for index in range(
                len(self.discard) - 1,
                -1,
                -1,
            ):
                if self.discard[index].value < 4:
                    continue

                harvested = self.discard.pop(index)
                pl.hand.append(harvested)
                pl.gremory_veil_draw_done = True
                break

            # Only one Gremory can be active in a two-player game.
            break

    def _gain_tear(self, pl: Player):
        """Place a personal Tear. Advances track and Attunement."""
        pl.tears += 1
        self.stat_personal_tears += 1
        self._gremory_ruinous_harvest()

    def _gain_neutral_tear(self):
        """Place a Neutral Tear. Advances track only."""
        self.neutral_tears += 1
        self.stat_neutral_tears += 1
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
    def _pick_siege_target(self, atk: Player, dfn: Player) -> str:
        # Deimos exception: destroy Siege Engine first to disable War Machine + bypass
        if dfn.lord == 'Deimos' and dfn.alive and 'SiegeEngine' in dfn.castles:
            return 'SiegeEngine'
        order = ['Stockpile', 'SummoningCircle', 'SiegeEngine', 'Bastion', 'Keep']
        for c in order:
            if c in dfn.castles:
                return c
        return next(iter(dfn.castles))

    # ─────────────────────────────────────────────────────────────────
    #  DRAW
    # ─────────────────────────────────────────────────────────────────
    def _draw(self, pl: Player, outside_draw: bool = False) -> bool:
        if not self.deck:
            if self.discard:
                self.deck    = self.discard[:]
                self.discard = []
                random.shuffle(self.deck)
            else:
                return False
        if len(pl.hand) >= HAND_LIMIT:
            return False
        pl.hand.append(self.deck.pop())

        if outside_draw:
            pl.kanifous_outside_draws += 1
            if self.breach == 'Kanifous':
                pl.threat = min(MAX_THREAT, pl.threat + 1)
                self.stat_breach_triggers += 1
        return True

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

        # Final Collapse (track 15+): most Souls wins
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
        else:                                    w = random.randint(0, 1)
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
        self.deck   = make_deck_2p()
        self.market = [self.deck.pop() for _ in range(MARKET_SIZE)]
        self.fp     = random.randint(0, 1)
        for pl in self.players:
            for c in CASTLES:
                pl.castles.add(c)
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
    def _full_round(self, allow_reflex: bool = True):
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

        if allow_reflex:
            self._phase_reflex_bid()

        self._phase_commitment()
        self._phase_reveal()
        order = self._resolve_order()
        self._phase_resolution(order)

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
            self._gain_neutral_tear()
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
            n = 5 + (1 if 'Stockpile' in pl.castles else 0)
            for _ in range(n):
                self._draw(pl)

        # Market
        for offset in range(2):
            self._ai_market(self.players[(self.fp + offset) % 2])

        # Repair (before Deploy — the no-token repair restriction now bites)
        for pl in self.players:
            self._ai_repair_only(pl)

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
        pl.threat = min(MAX_THREAT, pl.threat + 1)
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
                    self._gain_tear(pl)
                    if self._check_win(): return

        # Profane the Ruins — once per round; requires 2+ Ruined Castles;
        # Profane one Ruined Castle (permanently) for a Tear.
        if (not pl.profane_ruins_used_this_round and len(pl.ruined_castles) >= VARIANT['profane_ruins_req']
                and (plan in ('race_dominion', 'deny_dominion') or pl.tears >= 1)):
            priority = CASTLE_PRIORITIES.get(pl.lord, CASTLES)
            target = next((c for c in reversed(priority) if c in pl.ruined_castles), None)
            if target:
                pl.ruined_castles.discard(target)
                pl.profaned_castles.add(target)
                pl.profane_ruins_used_this_round = True
                self._gain_tear(pl)
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
        for pl in self.players:
            self._ai_choose_action(pl)

    def _phase_reveal(self):
        for pl in self.players:
            if pl.action == 'Hunt':
                pl.threat = min(MAX_THREAT, pl.threat + 1)

        # Register Sigils (own zones only) with the Sigil Contest:
        # if the opponent's revealed action attacks the same zone, compare
        # committed values — attack strictly greater → Flipped, else Fresh.
        for pl in self.players:
            if pl.action == 'Ward':
                zone = pl.ward_target
                op   = self.opp(pl.pid)
                contested = ((op.action == 'Hunt'  and zone == 'Lord') or
                             (op.action == 'Siege' and zone == 'Castle'))
                if contested and op.committed_value() > pl.committed_value():
                    pl.sigils[zone] = 'flipped'
                else:
                    pl.sigils[zone] = 'fresh'

                # Sigil Lord on own zone: reduce Threat by 1 (min 0)
                if zone == 'Lord':
                    pl.threat = max(0, pl.threat - 1)

        for pl in self.players:
            if pl.lord == 'Kanifous' and pl.alive:
                self._kanifous_invoke(pl)

    def _resolve_order(self) -> List[int]:
        """v5.29: higher committed Subject value resolves first.
        Equal values resolve simultaneously (approximated sequentially;
        both actions still fully resolve)."""
        v0 = self.players[0].committed_value()
        v1 = self.players[1].committed_value()
        if v0 > v1: return [0, 1]
        if v1 > v0: return [1, 0]
        first = random.randint(0, 1)
        return [first, 1 - first]

    # ─────────────────────────────────────────────────────────────────
    #  PHASE: RESOLUTION
    # ─────────────────────────────────────────────────────────────────
    def _phase_resolution(self, order: List[int]):
        # ── Kalligan — Persistent Scorch Token (Wildfire/Inferno)
        # Defeats all Guards ≤2 in the affected zone at start of each Resolution.
        if self.persist_scorch_pid >= 0 and self.persist_scorch_type:
            target_pl = self.players[self.persist_scorch_pid]
            if self.persist_scorch_type == 'Lord':
                victims = [g for g in target_pl.lord_guards if g.value <= 2]
                for v in victims:
                    target_pl.lord_guards.remove(v)
                self._discard(victims)
                if victims:
                    self._gremory_lord_guard_trigger()  # Predator of Ruin
            elif self.persist_scorch_type == 'Castle':
                victims = [g for g in target_pl.castle_guards if g.value <= 2]
                for v in victims:
                    target_pl.castle_guards.remove(v)
                self._discard(victims)
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
                    self._lose_soul(op, 1)
                    self._gain_neutral_tear()
                    self.stat_humbaba_tolls += 1
                    # Gate Guard broke — trim the 4th slot immediately
                    while len(pl.castle_guards) > pl.max_castle_guards():
                        victim = min(pl.castle_guards, key=lambda g: g.value)
                        pl.castle_guards.remove(victim)
                        space = GARRISON_MAX - len(pl.garrison)
                        if space > 0: pl.garrison.append(victim)
                        else: self._discard([victim])
                    if self._check_win(): return

        # ── Kroni — Hungering Aura (Hunger 3+)
        for pl in self.players:
            if pl.lord == 'Kroni' and pl.alive and pl.kroni_hunger >= 3:
                op = self.opp(pl.pid)
                if op.committed:
                    victim = min(op.committed, key=lambda c: c.value)
                    op.committed.remove(victim)
                    self._discard([victim])

        for pid in order:
            if self.winner is not None: return
            pl = self.players[pid]
            op = self.opp(pid)

            if   pl.action == 'Ward':    pass
            elif pl.action == 'Hunt':    self._resolve_hunt(pl, op)
            elif pl.action == 'Siege':   self._resolve_siege(pl, op)
            elif pl.action == 'Profane': self._resolve_profane(pl, op)

            self._try_kroni_consume(pl)
            self._try_kroni_consume(op)

            # Offer the Vessel — once per game, during Resolution
            self._ai_offer_vessel(pl)
            if self._check_win(): return

            # Vulture suit bonus
            if pl.suit_count('Vulture') >= 2:
                self._draw(pl, outside_draw=True)

            # Wright suit bonus: gain 1 Repair token (max 1, persists to next Development)
            if pl.suit_count('Wright') >= 2:
                pl.repair_token = 1  # capped at 1 — no stockpiling

            self._discard(pl.committed)
            pl.committed = []

            if self._check_win(): return

        # ── REFLEX ACTION — bid winner's optional second action (v5.29).
        # Resolves after all committed actions, before End-of-Round effects.
        if self.reflex_winner is not None and self.winner is None:
            self._resolve_reflex_action(self.reflex_winner)
            if self.winner is not None: return

        # K1: Hunger decays when Kroni initiates no attack this round
        if VARIANT['kroni_hunger_decay']:
            for pl in self.players:
                if (pl.lord == 'Kroni' and pl.alive
                        and pl.action not in ('Hunt', 'Siege')):
                    pl.kroni_hunger = max(0, pl.kroni_hunger - 1)

        # Kroni end-of-round fallback Consume
        for pl in self.players:
            if pl.lord == 'Kroni' and pl.alive and not pl.kroni_consume_done:
                all_guards = pl.lord_guards + pl.castle_guards
                if all_guards:
                    victim = min(all_guards, key=lambda g: g.value)
                    if victim in pl.lord_guards:     pl.lord_guards.remove(victim)
                    elif victim in pl.castle_guards: pl.castle_guards.remove(victim)
                    self._discard([victim])
                    pl.kroni_consume_done = True
                    self._kroni_gain_hunger(pl)
                elif pl.garrison:
                    victim = min(pl.garrison, key=lambda g: g.value)
                    pl.garrison.remove(victim)
                    self._discard([victim])
                    pl.kroni_consume_done = True
                    self._kroni_gain_hunger(pl)

        # Kroni Breach — Insatiable Hunger
        if self.breach == 'Kroni':
            for pl in self.players:
                all_guards = pl.lord_guards + pl.castle_guards
                if all_guards:
                    victim = min(all_guards, key=lambda g: g.value)
                    if victim in pl.lord_guards:     pl.lord_guards.remove(victim)
                    elif victim in pl.castle_guards: pl.castle_guards.remove(victim)
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
                            self._gain_neutral_tear()
                        else:
                            self._gain_tear(pl)
                        if self._check_win(): return

        for pl in self.players:
            pl.prev_ward_target = pl.ward_target if pl.action == 'Ward' else ''
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
                self.stat_castles_destroyed += 1
                self.any_destruction_this_round = True
                # Neutral Tear: first castle destroyed this round (D4: every)
                if VARIANT['castle_tear_uncapped'] or not self.first_castle_neutral_done:
                    self._gain_neutral_tear()
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
                if g in pl.lord_guards:      pl.lord_guards.remove(g)
                elif g in pl.castle_guards:  pl.castle_guards.remove(g)
                self._discard([g])
            pl.penitent_temp_guards = []

        # Profane — Tear lands at the END of Resolution (v5.29)
        for pl in self.players:
            if pl.pending_profane:
                pl.pending_profane = ''
                self._gain_tear(pl)
                if self._check_win(): return

    # ─────────────────────────────────────────────────────────────────
    #  PROFANE (Commitment action: Siege + own color)
    # ─────────────────────────────────────────────────────────────────
    def _resolve_profane(self, pl: Player, op: Player):
        """Profane Denial: cancelled if the opponent controls a Fresh Sigil
        in ANY zone (Flipped do not block). Castle flips to Profaned now;
        the Tear lands at the end of Resolution."""
        if 'fresh' in op.sigils.values():
            return  # denied — committed cards are wasted
        target = pl.pending_profane
        if not target or target not in pl.castles:
            pl.pending_profane = ''
            return
        pl.castles.discard(target)
        pl.profaned_castles.add(target)
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
        self._discard(pl.lord_guards[:])
        pl.lord_guards.clear()
        pl.alive = False           # Lord removed — NOT Banished: no Breach change
        self._gain_tear(pl)

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
                guess = choice[0] if random.random() < 0.5 else \
                        random.choice(['Hunt', 'Siege', 'Ward'])
                if guess == choice[0]:
                    self.stat_breach_triggers += 1
                    # Winner's chosen Subjects are discarded, action stolen
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

        def minimal_commit(needed: int):
            picked, total = [], 0
            for c in hand_sorted:
                if total > needed: break
                picked.append(c); total += c.value
            return (picked, total) if total > needed else (None, 0)

        # Option 1: lethal Hunt (Hunt still costs 1 Threat on reveal)
        if op.alive and pl.threat < MAX_THREAT:
            lord_def  = op.lord_base_def(breach=self.breach)
            lord_def += sum(g.value for g in op.lord_guards)
            lord_def += self._sigil_value(op, op.sigils['Lord'])
            cards, _ = minimal_commit(lord_def)
            # A pending Recoil deletes our 2nd-highest — pad the commit
            if (cards and op.lord == 'Odradek' and not op.odradek_recoil_done):
                pool = sorted((c for c in pl.hand if c not in cards),
                              key=lambda c: c.value, reverse=True)
                def eff(cs):
                    if len(cs) <= 1: return 0
                    v = sorted((c.value for c in cs), reverse=True)
                    loss = v[-1] if VARIANT['recoil_lowest'] else v[1]
                    return sum(v) - loss
                for c in pool:
                    if eff(cards) > lord_def: break
                    cards.append(c)
                if eff(cards) <= lord_def:
                    cards = None
            if cards:
                return ('Hunt', cards, 'Lord')

        # Option 2: crack a castle (Siege Engine bypass does NOT apply)
        if op.castles:
            target = min(op.castles, key=lambda c: CASTLE_DEF[c])
            need  = op.castle_def(target, breach=self.breach)
            need += sum(g.value for g in op.castle_guards)
            need += self._sigil_value(op, op.sigils['Castle'])
            cards, _ = minimal_commit(need)
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
            pl.threat = min(MAX_THREAT, pl.threat + 1)   # Hunt always costs 1 Threat
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

    def _kroni_gain_hunger(self, pl: Player, n: int = 1):
        """Increment Kroni's Hunger and check the Hunger 3 milestone Tear.
        Milestone: first time Kroni reaches exactly Hunger 3 this summon → 1 Tear.
        Resets when Kroni is re-summoned (kroni_tear_milestone_fired = False on summon).
        Farmable: kill Kroni at 3+ → returns at 2 → reach 3 again → another Tear."""
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
        dfn.was_hunted = True

        # Relentless Pursuit: Orias hunting his marked lord gets a clean hunt
        # — Recoil and Backwash are suppressed for this attack
        orias_clean_hunt = (atk.lord == 'Orias' and self.orias_marked_lord == dfn.lord)

        # ── Odradek — Psychic Recoil (PRE-COMBAT, first attack this round)
        # Discard the attacker's second-highest committed card and gain 1 Soul.
        if (dfn.lord == 'Odradek' and dfn.alive and not dfn.odradek_recoil_done
                and not orias_clean_hunt):
            dfn.odradek_recoil_done = True
            if atk.committed:
                if VARIANT['recoil_lowest']:
                    victim = min(atk.committed, key=lambda c: c.value)
                else:
                    sc = sorted(atk.committed, key=lambda c: c.value, reverse=True)
                    victim = sc[1] if len(sc) > 1 else sc[0]
                atk.committed.remove(victim)
                self._discard([victim])
                self._gain_soul(dfn, 1)

        strength  = atk.committed_value()
        strength += atk.suit_bonus('Butcher')

        # Orias — Marked Prey: +1 Hunt Strength; +1 additional if defender 2+ Threat
        if atk.lord == 'Orias' and atk.alive:
            strength += 1
            if dfn.threat >= 2: strength += 1

        # Crushing Presence / Invoked Butcher: lowest defending Guard gives no Defense
        ignore_lowest = False
        if atk.lord == 'Valak' and atk.alive and len(dfn.lord_guards) >= 2:
            ignore_lowest = True
        if (atk.lord == 'Kanifous' and atk.alive
                and atk.kanifous_invoked_suit == 'Butcher' and dfn.lord_guards):
            ignore_lowest = True

        lord_def    = dfn.lord_base_def(breach=self.breach)
        sigil_state = dfn.sigils['Lord']
        sigil_value = self._sigil_value(dfn, sigil_state)

        guards_before = len(dfn.lord_guards)
        self.stat_combats += 1
        destroyed, sigil_broken, excess = self._combat_layers(
            atk, strength, dfn.lord_guards, ignore_lowest,
            sigil_value, has_sigil=(sigil_state != ''), struct_def=lord_def)
        guards_lost = guards_before - len(dfn.lord_guards)

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
                  and atk.souls < WIN_SOULS - 1 and random.random() < 0.25):
                consume = True
            elif (VARIANT['ai_dominion_drive'] and atk.tears >= 1
                  and atk.tears + 1 > op.tears and atk.souls < WIN_SOULS - 2
                  and random.random() < 0.5):
                consume = True
            if consume:
                self._gain_tear(atk)
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
            atk.threat = min(MAX_THREAT, atk.threat + 1)

        # Orias — Barbed Web: after Hunt defeats 1+ guard, defender gains Threat
        # +1 normally; +2 if defender was already at 2+ Threat (escalation spiral)
        if atk.lord == 'Orias' and atk.alive and guards_lost > 0 and dfn.alive:
            threat_gain = 2 if dfn.threat >= 2 else 1
            dfn.threat = min(MAX_THREAT, dfn.threat + threat_gain)

        # Kroni — Ravenous (Hunger 3+, once per game): +2 Souls on kill
        if (destroyed and atk.lord == 'Kroni' and atk.alive
                and atk.kroni_hunger >= 3 and not atk.kroni_ravenous_used):
            self._gain_soul(atk, 2)
            self._kroni_gain_hunger(atk)
            atk.kroni_ravenous_used = True

    # ─────────────────────────────────────────────────────────────────
    #  COMBAT: SIEGE
    # ─────────────────────────────────────────────────────────────────
    def _resolve_siege(self, atk: Player, dfn: Player,
                       forced_target: Optional[str] = None,
                       reflex: bool = False):
        if not dfn.castles: return
        dfn.was_sieged = True

        target_castle = forced_target if forced_target in dfn.castles else \
                        self._pick_siege_target(atk, dfn)
        dfn.last_sieged_castle = target_castle

        # ── Odradek — Psychic Recoil (PRE-COMBAT, first attack this round)
        # Variant O1: Recoil fires on Hunts only — Sieges bypass it entirely
        if (dfn.lord == 'Odradek' and dfn.alive and not dfn.odradek_recoil_done
                and not VARIANT['recoil_hunts_only']):
            dfn.odradek_recoil_done = True
            if atk.committed:
                if VARIANT['recoil_lowest']:
                    victim = min(atk.committed, key=lambda c: c.value)
                else:
                    sc = sorted(atk.committed, key=lambda c: c.value, reverse=True)
                    victim = sc[1] if len(sc) > 1 else sc[0]
                atk.committed.remove(victim)
                self._discard([victim])
                self._gain_soul(dfn, 1)

        strength  = atk.committed_value()
        strength += atk.suit_bonus('Butcher')

        # Siege Engine bypass does NOT apply to the Reflex second action
        siege_engine_bypass = ('SiegeEngine' in atk.castles) and not reflex

        # Deimos — War Machine: +2 Siege Strength, −1 per castle lost.
        # REQUIRES Siege Engine to be active.
        if atk.lord == 'Deimos' and atk.alive and (
                'SiegeEngine' in atk.castles or VARIANT['deimos_war_machine_free']):
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
        if atk.lord == 'Valak' and atk.alive and len(dfn.castle_guards) >= 2:
            ignore_lowest = True
        if (atk.lord == 'Kanifous' and atk.alive
                and atk.kanifous_invoked_suit == 'Butcher' and dfn.castle_guards):
            ignore_lowest = True

        # Structural defense (+ Penitent suit bonus for the defender)
        struct_def  = dfn.castle_def(target_castle, breach=self.breach, game=self)
        struct_def += dfn.suit_bonus('Penitent')

        sigil_state = dfn.sigils['Castle']
        sigil_value = self._sigil_value(dfn, sigil_state)

        guards_before = len(dfn.castle_guards)
        self.stat_combats += 1
        destroyed, sigil_broken, excess = self._combat_layers(
            atk, strength, dfn.castle_guards, ignore_lowest,
            sigil_value, has_sigil=(sigil_state != ''), struct_def=struct_def,
            bypass=siege_engine_bypass)
        guards_lost = guards_before - len(dfn.castle_guards)

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
            dfn.castles.discard(target_castle)
            dfn.ruined_castles.add(target_castle)
            self.stat_castles_destroyed += 1
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
                      and random.random() < 0.5):
                    consumed_siege = True
                elif (atk.tears < 2 and atk.tears <= op_c.tears
                      and atk.souls <= WIN_SOULS - 3
                      and random.random() < 0.35):
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
                    self._gain_neutral_tear()
                self.first_castle_neutral_done = True
            if self._check_win(): return

            # 2 Souls if at least one Castle Guard was Defeated this Siege
            # (forfeited under Consume the Siege)
            if consumed_siege:
                pass
            elif guards_lost > 0:
                self._gain_soul(atk, 2)
                self.stat_ritual_souls += 2
            else:
                self._gain_soul(atk, 1)
                self.stat_ritual_souls += 1

            # Gremory — Predator of Ruin
            for p in self.players:
                if p.lord == 'Gremory' and p.alive and not p.gremory_ruin_done:
                    if self.discard:
                        p.hand.append(self.discard[-1])
                        self.discard.pop()
                    p.gremory_ruin_done = True
                    break

            # Kalligan — Inferno: may gain 1 Threat → Defeat highest Lord Guard
            # (Scorch on the Lord zone if no Guards). Ability-triggered defeat:
            # does NOT fire Defeat-response abilities.
            if (atk.lord == 'Kalligan' and atk.alive
                    and atk.threat < MAX_THREAT):
                atk.threat = min(MAX_THREAT, atk.threat + 1)
                if dfn.lord_guards:
                    victim = max(dfn.lord_guards, key=lambda g: g.value)
                    dfn.lord_guards.remove(victim)
                    self._discard([victim])
                else:
                    self.persist_scorch_pid  = dfn.pid
                    self.persist_scorch_type = 'Lord'

            # Kalligan — Wildfire: persistent Scorch token after castle destroy
            if atk.lord == 'Kalligan' and atk.alive:
                self.persist_scorch_pid  = dfn.pid
                self.persist_scorch_type = 'Castle' if dfn.castles else 'Lord'

            # Kroni — Ravenous
            if (atk.lord == 'Kroni' and atk.alive
                    and atk.kroni_hunger >= 3 and not atk.kroni_ravenous_used):
                self._gain_soul(atk, 2)
                self._kroni_gain_hunger(atk)
                atk.kroni_ravenous_used = True

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
    #  CORE COMBAT — layered per the Golden Rule (equality never destroys)
    #  Normal order:  Guards → Sigil → Structure
    #  Siege Engine:  Sigil → Structure → Guards
    # ─────────────────────────────────────────────────────────────────
    def _combat_layers(self, atk: Player, strength: int,
                       guards: List[Card], ignore_lowest: bool,
                       sigil_value: int, has_sigil: bool,
                       struct_def: int,
                       bypass: bool = False) -> Tuple[bool, bool, int]:
        """Mutates `guards` (defeated Guards removed and discarded).
        Returns (destroyed, sigil_broken, excess_after_structure)."""

        # Effective guard values: the ignored (crushed) Guard defends at 0
        def _effective(gs: List[Card]):
            if not gs: return []
            eff = [(g, g.value) for g in gs]
            if ignore_lowest:
                low_i = min(range(len(eff)), key=lambda i: eff[i][1])
                eff[low_i] = (eff[low_i][0], 0)
            # Strip highest effective value first
            eff.sort(key=lambda t: t[1], reverse=True)
            return eff

        def _strip_guards(remaining: int) -> int:
            """Strips Guards while remaining Strength strictly exceeds each.
            Returns leftover Strength (or -1 sentinel meaning attack stopped)."""
            for g, val in _effective(guards):
                if remaining > val:
                    guards.remove(g)
                    self._discard([g])
                    remaining -= val
                else:
                    return -1
            return remaining

        def _sigil_layer(remaining: int) -> Tuple[bool, int]:
            """Returns (broken, leftover). A 0-value Sigil (Omen) breaks on
            any attack that reaches it. Leftover −1 means attack stopped."""
            if not has_sigil:
                return False, remaining
            if sigil_value == 0:
                return True, remaining
            if remaining > sigil_value:
                return True, remaining - sigil_value
            return False, -1

        if bypass:
            # Sigil → Structure → Guards
            broken, remaining = _sigil_layer(strength)
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

        # Guards → Sigil → Structure
        remaining = _strip_guards(strength)
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
        base += 1 if 'Keep' in pl.castles else 0
        if self._threshold_active(3) and not self._immune_to_threshold(pl, 3):
            base = max(0, base - 1)
        return base

    # ─────────────────────────────────────────────────────────────────
    #  KANIFOUS INVOKE
    # ─────────────────────────────────────────────────────────────────
    def _kanifous_invoke(self, pl: Player):
        """After Reveal: gain 1 Threat, reveal top 2 cards.
        First card = Kanifous's: if value 4+, place 1 Neutral Tear (regardless of choice).
        Second card = player's. Choose 1 to Invoke, discard the other."""
        if not self.deck:
            if self.discard:
                self.deck = self.discard[:]; self.discard = []; random.shuffle(self.deck)
            else:
                return

        # Reveal up to 2 cards
        revealed = []
        for _ in range(2):
            if not self.deck:
                if self.discard:
                    self.deck = self.discard[:]; self.discard = []; random.shuffle(self.deck)
                else:
                    break
            if self.deck:
                revealed.append(self.deck.pop())

        if not revealed:
            return

        pl.kanifous_invokes_this_round += 1
        pl.threat = min(MAX_THREAT, pl.threat + 1)

        # First card is Kanifous's — Neutral Tear if value 4+
        kanifous_card = revealed[0]
        if kanifous_card.value >= 4:
            self._gain_neutral_tear()

        op = self.opp(pl.pid)

        def _suit_score(card: Card) -> float:
            s = card.suit
            if s == 'Butcher':
                return 1.5 if pl.action in ('Hunt', 'Siege') else 0.5
            elif s == 'Penitent':
                total_guards = len(pl.lord_guards) + len(pl.castle_guards)
                return 1.2 if total_guards <= 2 else 0.6
            elif s == 'Vulture':
                return 1.3 if len(pl.hand) <= 3 else 0.7
            elif s == 'Wright':
                imbalance = abs(len(pl.lord_guards) - len(pl.castle_guards))
                return 0.8 + imbalance * 0.2
            return 0.5

        # Choose the better card to invoke; discard the other
        if len(revealed) == 1:
            chosen = revealed[0]
            discarded = []
        else:
            scores = [_suit_score(c) for c in revealed]
            if scores[0] >= scores[1]:
                chosen, discarded = revealed[0], [revealed[1]]
            else:
                chosen, discarded = revealed[1], [revealed[0]]

        if discarded:
            self._discard(discarded)

        pl.kanifous_invoked_suit = chosen.suit

        # Apply chosen suit effect
        if chosen.suit == 'Vulture':
            self._draw(pl, outside_draw=True)
            self._draw(pl, outside_draw=True)
            self._draw(pl, outside_draw=True)
            if len(pl.hand) > 1:
                worst = min(pl.hand, key=lambda c: c.value)
                pl.hand.remove(worst); self._discard([worst])

        elif chosen.suit == 'Wright':
            moved = 0
            while (moved < 2 and pl.lord_guards
                   and len(pl.castle_guards) < pl.max_castle_guards()):
                g = pl.lord_guards.pop(0)
                pl.castle_guards.append(g); moved += 1

        elif chosen.suit == 'Penitent':
            # Place 2 additional cards from the top of the deck as Guards in
            # any zones (may exceed Guard limits); discarded at end of Resolution.
            def _place(g):
                if len(pl.lord_guards) <= len(pl.castle_guards): pl.lord_guards.append(g)
                else: pl.castle_guards.append(g)
            for _ in range(2):
                if not self.deck:
                    if self.discard:
                        self.deck = self.discard[:]; self.discard = []; random.shuffle(self.deck)
                    else:
                        break
                extra = self.deck.pop(); _place(extra)
                pl.penitent_temp_guards.append(extra)
            pl.kanifous_invoked_high = True

        # Soul trigger: chosen card face value == current Threat level
        if chosen.value == pl.threat:
            self._gain_soul(pl, 1)

        # Bank chosen card to Garrison
        if len(pl.garrison) < GARRISON_MAX and chosen not in pl.garrison:
            pl.garrison.append(chosen)
        else:
            self._discard([chosen])

    # ─────────────────────────────────────────────────────────────────
    #  LORD KILLED
    # ─────────────────────────────────────────────────────────────────
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

        for p in self.players:
            if p.lord == 'Gremory' and p.alive and not p.gremory_ruin_done:
                if self.discard:
                    p.hand.append(self.discard[-1]); self.discard.pop()
                p.gremory_ruin_done = True
                break

        if atk.lord == 'Orias' and atk.alive:
            self.orias_marked_lord = dfn.lord

        if dfn.lord == 'Kroni':
            dfn.kroni_hunger = max(0, dfn.kroni_hunger - 1)
            # milestone flag resets on resummon, not on kill — allows farming

        # Odradek: Reconfiguration tokens reset on Banishment
        if dfn.lord == 'Odradek':
            dfn.odradek_reconfig_tokens = 0

        if VARIANT['neutral_tear_on_banish']:
            self._gain_neutral_tear()

        dfn.threat = LORD_STATS[dfn.lord]['r']
        self.breach = dfn.lord
        self.breach_owner = dfn.pid
        dfn.lord_guards.clear()
        dfn.alive = False

    # ═══════════════════════════════════════════════════════════════════
    #  AI — SUMMON
    # ═══════════════════════════════════════════════════════════════════
    def _ai_pick_lord(self, pl: Player) -> Optional[str]:
        op = self.opp(pl.pid)
        available = list(pl.lord_pool)

        def lord_score(lord: str) -> float:
            base_cost = summon_base_cost(lord)
            if 'SummoningCircle' in pl.castles: base_cost -= 2
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
            if lord == 'Kalligan': score += 0.7 if pl.ruined_castles else 0.3
            if lord == 'Odradek':  score += 0.8 if op.alive and op.threat >= 2 else 0.5
            if lord == 'Kanifous': score += 0.7
            if self.breach == lord: score -= 0.5
            score -= breach_penalty * 0.5
            score -= cost * 0.05
            return score

        scored = sorted(available, key=lord_score, reverse=True)
        for lord in scored:
            base_cost = summon_base_cost(lord)
            if 'SummoningCircle' in pl.castles: base_cost -= 2
            breach_pen = 3 if self.breach == lord else 0
            cost = max(0, base_cost + breach_pen)
            if sum(c.value for c in pl.hand) >= cost:
                return lord
        return None

    def _ai_summon(self, pl: Player, forced: bool = False):
        if pl.alive and not forced: return

        # In locked mode, always use the one lord in the pool
        if LOCK_LORDS:
            chosen = pl.lord_pool[0]
        else:
            chosen = self._ai_pick_lord(pl)
            if chosen is None and not forced: return
            if chosen is None: chosen = pl.lord_pool[0]

        pl.lord = chosen
        base_cost = summon_base_cost(chosen)
        if 'SummoningCircle' in pl.castles: base_cost -= 2
        breach_penalty = 3 if self.breach == chosen else 0
        cost = max(0, base_cost + breach_penalty)

        if not forced:
            if sum(c.value for c in pl.hand) < cost: return

        self._pay(pl, cost, hand_only=True)
        pl.alive = True
        pl.threat = LORD_STATS[chosen]['r']
        # Offer the Vessel: the offered Lord resummons at Threat 2
        if pl.vessel_offered_lord == chosen:
            pl.threat = 2
            pl.vessel_offered_lord = ''

        # Reset per-summon flags
        if chosen == 'Kroni':
            pl.kroni_tear_milestone_fired = False
        if chosen == 'Odradek':
            pl.odradek_reconfig_tokens = 0  # tokens reset on summon

        # Relentless Pursuit: marked lord gets +1 Threat on resummon
        if self.orias_marked_lord == chosen:
            pl.threat = min(MAX_THREAT, pl.threat + 1)

        # ── Neutral Tear: all summons after the first
        if pl.first_summon_done:
            self._gain_neutral_tear()
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
        if not pl.ruined_castles: return
        priority = CASTLE_PRIORITIES.get(pl.lord, CASTLES)
        target   = next((c for c in priority if c in pl.ruined_castles), None)
        if not target: return
        # Repair cost = flat Defense value of the castle.
        # All discounts stack; the floor of 1 is applied ONCE at the end (v5.29).
        cost = CASTLE_COST[target]
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
        if sum(c.value for c in pl.hand + pl.garrison) < cost: return
        self._pay(pl, cost)
        pl.ruined_castles.discard(target)
        pl.castles.add(target)
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

        # ── Attack reservation: estimate target defense ───────────────
        if best == 'Hunt' and op.alive:
            est_def  = op.lord_base_def(breach=self.breach)
            est_def += sum(g.value for g in op.lord_guards)
            est_def += 2   # assume opponent wards
            if op.lord == 'Odradek': est_def += 4   # Recoil compensation card
            # Orias Marked Prey: +1 always, +1 if defender 2+ Threat
            if pl.lord == 'Orias':
                est_def -= 1
                if op.threat >= 2: est_def -= 1
        else:   # Siege
            target_c  = self._pick_siege_target(pl, op)
            est_def   = op.castle_def(target_c, breach=self.breach)
            if 'SiegeEngine' in pl.castles:
                # Siege Engine: resolve Sigil+Structure first, guards last
                # To crack the castle, only need to beat structure (guards don't protect it)
                # Don't add guards to est_def — just need to beat structure
                pass
            else:
                est_def += sum(g.value for g in op.castle_guards)
            est_def  += 1
            # Deimos War Machine: only fires if Siege Engine active
            if pl.lord == 'Deimos' and 'SiegeEngine' in pl.castles:
                est_def -= max(0, 2 - len(pl.ruined_castles) - len(pl.profaned_castles))
            # Kalligan — Pyroclasm
            if pl.lord == 'Kalligan':
                est_def -= 2 if op.ruined_castles else 1

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
                reserved.append(c); total += c.value
            butchers = butchers[2:]

        # Fill to target Strength with remaining cards (highest first)
        for c in butchers + others:
            if total >= target_str: break
            reserved.append(c); total += c.value

        # Reserve 1 low card for bid from whatever is left
        non_reserved_low = sorted([c for c in pl.hand if c not in reserved],
                                  key=lambda c: c.value)
        if non_reserved_low:
            reserved.append(non_reserved_low[0])

        return reserved

    def _deploy_guards(self, pl: Player):
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
            pl.castle_guards.append(pl.garrison.pop(0))
            garrison_moves += 1

        # ── Step 3: deploy LOW-value non-reserved hand cards ──────────
        # Sort ASCENDING — chaff to guards, power stays for offense
        # Skip hand→guards if repair restricts it
        # Snare caps total guard moves from all sources to 1
        if not repair_restricts_hand_deploy:
            deployable = sorted(
                [c for c in pl.hand if id(c) not in reserved_ids],
                key=lambda c: c.value   # lowest first
            )
            for c in deployable:
                if len(pl.castle_guards) >= max_cg: break
                if snare_active and snare_guards_moved >= 1: break
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
                pl.lord_guards.append(pl.garrison.pop(0))
                garrison_moves += 1
                snare_guards_moved += 1

        # Fill lord guards from low-value non-reserved hand
        if not repair_restricts_hand_deploy:
            deployable2 = sorted(
                [c for c in pl.hand if id(c) not in reserved_ids],
                key=lambda c: c.value
            )
            for c in deployable2:
                if len(pl.lord_guards) >= max_lg: break
                if snare_active and snare_guards_moved >= 1: break
                pl.lord_guards.append(c)
                pl.hand.remove(c)
                snare_guards_moved += 1

    def _ai_market(self, pl: Player):
        if not self.market or not pl.hand: return
        if random.random() < 0.5:
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
        if prof.get('control', 1.0) >= 1.25 and random.random() < 0.6:
            want_cards = max(want_cards, 2)
        if pl.alive and pl.souls >= WIN_SOULS - 1 and random.random() < 0.8:
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

        pref = prof.get('prefer', '')
        if pref == 'Hunt':  h += 0.25
        if pref == 'Siege': s += 0.25
        if pref == 'Ward':  w += 0.25

        h += random.uniform(-0.25, 0.25)
        s += random.uniform(-0.25, 0.25)
        w += random.uniform(-0.25, 0.25)

        # ── Profane (Siege + own color) — sacrifice a Castle for a Tear.
        # Risk: cancelled by an opponent Fresh Sigil placed this round.
        p_score = -5.0
        if len(pl.castles) >= 3:
            soul_deficit = op.souls - pl.souls
            tear_lead    = pl.tears - op.tears
            p_score = 0.0
            if soul_deficit >= 2:                 p_score += 1.6
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
            p_score += random.uniform(-0.25, 0.25)

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
        elif best == 'Profane' and len(pl.castles) >= 3:
            pl.action = 'Profane'
            priority = CASTLE_PRIORITIES.get(pl.lord, CASTLES)
            pl.pending_profane = next(
                (c for c in reversed(priority) if c in pl.castles),
                next(iter(pl.castles)))
            # Profane needs no Strength — commit nothing
            pl.committed = []
        else:
            pl.action = 'Ward'
            # Own zones only (v5.29)
            if plan == 'deny_ritual' and pl.prev_ward_target != 'Lord':
                pl.ward_target = 'Lord'
            else:
                want_lord = (pl.souls >= 2) or (pl.threat >= 2)
                pl.ward_target = 'Lord' if want_lord else 'Castle'
                if pl.ward_target == pl.prev_ward_target:
                    pl.ward_target = 'Castle' if pl.ward_target == 'Lord' else 'Lord'
            self._commit_for_ward(pl, plan)

    def _score_hunt(self, pl: Player, op: Player, plan: str) -> float:
        if not op.alive: return -5.0
        score = 1.8
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
        return score

    def _score_siege(self, pl: Player, op: Player, plan: str) -> float:
        if not op.castles: return -5.0
        score = 1.0
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
        return score

    def _score_ward(self, pl: Player, op: Player, plan: str) -> float:
        score = 0.6
        score += pl.souls        * 0.55
        score += len(pl.castles) * 0.30
        score += pl.threat       * 0.35
        if pl.threat >= 2: score += 0.6
        if pl.threat >= 3: score += 0.8
        if plan == 'protect_souls': score += 1.0
        if plan == 'deny_ritual':   score += 0.7
        if plan in ('deny_dominion', 'race_dominion'): score += 0.4
        if pl.lord == 'Kroni':   score += 0.5   # survive to scale
        if pl.lord == 'Odradek': score += 0.8   # Ward: make opponents commit to stripping 2+ guards
        return score

    def _commit_for_attack(self, pl: Player, op: Player, target_type: str, plan: str,
                           chip: bool = False):
        # Chip mode: commit just enough to strictly exceed the HIGHEST guard in
        # the zone (guards strip highest-first) and no more — deny Reconfiguration
        # tokens / feed Kroni's Hunger without reaching the Sigil layer.
        if chip:
            guards = op.castle_guards if target_type == 'Castle' else op.lord_guards
            if guards:
                need = max(g.value for g in guards)
                picked, total = [], 0
                for c in sorted(pl.hand, key=lambda c: c.value):
                    if total > need: break
                    picked.append(c); total += c.value
                if total > need:
                    for c in picked: pl.hand.remove(c)
                    pl.committed = picked
                    return
            # no guards to chip — fall through to a normal commit
        if target_type == 'Lord':
            est_def  = op.lord_base_def(breach=self.breach)
            est_def += sum(g.value for g in op.lord_guards)
            # Standing sigils are public information; hedge 2 for a fresh placement
            est_def += max(2, self._sigil_value(op, op.sigils['Lord']))
        else:
            target_c  = self._pick_siege_target(pl, op)
            est_def   = op.castle_def(target_c, breach=self.breach)
            if not ('SiegeEngine' in pl.castles):
                est_def += sum(g.value for g in op.castle_guards)
            est_def  += max(1, self._sigil_value(op, op.sigils['Castle']))

        pad = 2 if plan in ('deny_ritual', 'deny_dominion') else (0 if plan == 'protect_souls' else 1)
        target_str = est_def + pad

        butchers = sorted([c for c in pl.hand if c.suit == 'Butcher'],
                          key=lambda c: c.value, reverse=True)
        others   = sorted([c for c in pl.hand if c.suit != 'Butcher'],
                          key=lambda c: c.value, reverse=True)

        committed = []; total = 0
        want_bonus = (pl.lord in ('Deimos', 'Orias', 'Gremory') or plan.startswith('deny'))
        if want_bonus:
            for c in butchers[:2]: committed.append(c); total += c.value
            butchers = butchers[2:]

        for c in butchers + others:
            if total >= target_str: break
            committed.append(c); total += c.value

        trim = 3 if plan.startswith('deny') else 2
        while len(committed) > 1 and total - committed[-1].value > target_str + trim:
            total -= committed[-1].value; committed.pop()

        # ── Play around Psychic Recoil: Odradek will delete our 2nd-highest
        # committed card pre-combat, so pad until the EFFECTIVE total clears.
        recoil_applies = (op.lord == 'Odradek' and op.alive
                          and not (pl.lord == 'Orias'
                                   and self.orias_marked_lord == op.lord)
                          and (target_type == 'Lord'
                               or not VARIANT['recoil_hunts_only']))
        if recoil_applies and committed:
            def eff_total():
                if len(committed) <= 1: return 0
                vals = sorted((c.value for c in committed), reverse=True)
                loss = vals[-1] if VARIANT['recoil_lowest'] else vals[1]
                return sum(vals) - loss
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
        pl.committed = committed

    def _commit_for_ward(self, pl: Player, plan: str):
        penitents = sorted([c for c in pl.hand if c.suit == 'Penitent'],
                           key=lambda c: c.value, reverse=True)
        committed = penitents[:2]
        for c in committed: pl.hand.remove(c)
        pl.committed = committed


# ═══════════════════════════════════════════════════════════════════════
#  SIMULATION RUNNER
# ═══════════════════════════════════════════════════════════════════════
def run_matchup(lord0: str, lord1: str, n_games: int) -> dict:
    wins0 = wins1 = 0
    timeouts = 0
    win_cond = defaultdict(int)
    rounds_list = []
    souls0_list = []; souls1_list = []
    threat0_list = []; threat1_list = []
    castles0_list = []; castles1_list = []
    total_combats = total_lords_killed = 0
    total_castles_destroyed = total_ward_souls = total_ritual_souls = 0
    total_hunt_souls = total_breach_triggers = 0
    total_humbaba_tolls = 0
    total_personal_tears = total_neutral_tears = 0
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

    for _ in range(n_games):
        if LOCK_LORDS:
            # Pure 1v1: each player has exactly one lord, no switching
            p0 = [lord0]
            p1 = [lord1]
        else:
            others = [l for l in ALL_LORDS if l not in (lord0, lord1)]
            random.shuffle(others)
            p0 = [lord0] + others[:2]
            p1 = [lord1] + others[2:4]
            random.shuffle(p0); random.shuffle(p1)

        if random.random() < 0.5:
            g = Game(p0, p1); w, wb = g.run()
            if w == 0: wins0 += 1
            elif w == 1: wins1 += 1
        else:
            g = Game(p1, p0); w, wb = g.run()
            if w == 0: wins1 += 1
            elif w == 1: wins0 += 1

        if wb == 'Timeout': timeouts += 1
        win_cond[wb] += 1
        rounds_list.append(g.round)
        p0p, p1p = g.players
        souls0_list.append(p0p.souls); souls1_list.append(p1p.souls)
        threat0_list.append(p0p.threat); threat1_list.append(p1p.threat)
        castles0_list.append(len(p0p.castles)); castles1_list.append(len(p1p.castles))
        total_combats           += g.stat_combats
        total_lords_killed      += g.stat_lords_killed
        total_castles_destroyed += g.stat_castles_destroyed
        total_ward_souls        += g.stat_ward_souls
        total_ritual_souls      += g.stat_ritual_souls
        total_hunt_souls        += g.stat_hunt_souls
        total_personal_tears    += g.stat_personal_tears
        total_neutral_tears     += g.stat_neutral_tears
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
        'avg_ward_souls':        total_ward_souls / n_games,
        'avg_ritual_souls':      total_ritual_souls / n_games,
        'avg_hunt_souls':        total_hunt_souls / n_games,
        'avg_personal_tears':    total_personal_tears / n_games,
        'avg_neutral_tears':     total_neutral_tears / n_games,
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
#  REPORTING
# ═══════════════════════════════════════════════════════════════════════
def generate_report(results: dict, n_games: int) -> str:
    lords = ALL_LORDS
    lines = []
    W = 100

    def bar(text): return f"\n{'═'*W}\n  {text}\n{'═'*W}"

    lines.append(bar("CORRUPTOR BALANCE SIMULATION REPORT  v%s (%s)  ai=%s" % (SIM_VERSION, SIM_CODENAME, AI_POLICY)))
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
        flaws.append(f"  [WIN COND] FinalCollapse fires {collapse_pct:.1f}% — track reaching 15 too often, or Dominion too hard to achieve")
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
  NEUTRAL TEAR SOURCES (passive clock):
  • Castle destroyed (first per round): avg {avg_all('avg_neutral_tears'):.2f} neutral tears/game
    → This scales with siege pressure. More sieges = faster clock.
    → At avg {avg_all('avg_castles_destroyed'):.1f} castles destroyed/game, roughly {avg_all('avg_neutral_tears'):.1f} of those
       generate a neutral tear (first-per-round gate prevents stacking).
  • Lord resummoned (after first): avg {avg_all('avg_lords_killed'):.2f} kills/game → similar resummon count
    → Each kill after round 1 = 1 neutral tear on next resummon.

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
  • If FinalCollapse fires often, players are reaching 15 tears without Dominion winners
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

    # ── T8: Sigil values — Fresh/Flipped, Keep, Omen, Attunement immunity
    g = fresh_game(); pl = g.players[0]
    g.neutral_tears = 0; pl.tears = 0
    if g._sigil_value(pl, 'fresh')   != 2: failures.append("FAIL T8a: Fresh sigil = 2")
    if g._sigil_value(pl, 'flipped') != 1: failures.append("FAIL T8b: Flipped sigil = 1")
    g.neutral_tears = 3
    if g._sigil_value(pl, 'fresh') != 1:
        failures.append("FAIL T8c: Fresh under Omen (track 3) = 1")
    pl.tears = 3; g.neutral_tears = 0   # track 3 via personal; Attunement 3 = immune
    if g._sigil_value(pl, 'fresh') != 2:
        failures.append("FAIL T8d: Attunement 3 is immune to Omen")
    pl.tears = 0
    pl.castles.add('Keep')
    if g._sigil_value(pl, 'fresh')   != 3: failures.append("FAIL T8e: Fresh + Keep = 3")
    if g._sigil_value(pl, 'flipped') != 2: failures.append("FAIL T8f: Flipped + Keep = 2")

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
    g._ai_summon(pl, forced=True)
    if g.neutral_tears != before + 1:
        failures.append("FAIL T17b: later summons place 1 Neutral Tear")

    # ── T18: Repair floor — all discounts stack, floor 1 applied once
    g = fresh_game('Kalligan', 'Valak'); pl = g.players[0]
    pl.alive = True
    pl.castles = {'Keep'}
    pl.ruined_castles = {'SiegeEngine'}
    pl.repair_token = 1
    pl.hand = [Card('Wright', 1), Card('Wright', 1)]
    g.breach = 'Kalligan'
    # SiegeEngine 7 − token 3 − first-repair 7 − breach 1 = −4 → floor 1
    g._ai_repair_only(pl)
    if 'SiegeEngine' not in pl.castles:
        failures.append("FAIL T18: repair should succeed at floored cost 1")
    if len(pl.hand) != 1:
        failures.append(f"FAIL T18: floored cost 1 pays exactly one 1-card, hand left {len(pl.hand)}")

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
    if pl.lord_base_def() != 9:
        failures.append(f"FAIL T21a: Humbaba full board = 2+5+Bastion2 = 9, got {pl.lord_base_def()}")
    pl.castles = {'Keep'}
    if pl.lord_base_def() != 3:
        failures.append(f"FAIL T21b: Humbaba one castle = 3, got {pl.lord_base_def()}")
    pl.castles = set()
    if pl.lord_base_def() != 2:
        failures.append(f"FAIL T21c: Humbaba bare = 2, got {pl.lord_base_def()}")

    # ── T22: Gate Guard — 4th slot only while stones unbroken
    g = fresh_game('Humbaba', 'Valak'); pl = g.players[0]
    if pl.max_castle_guards() != 4:
        failures.append("FAIL T22a: unbroken Humbaba has 4 castle guard slots")
    pl.ruined_castles.add('Keep')
    if pl.max_castle_guards() != 3:
        failures.append("FAIL T22b: a Ruined castle breaks the Gate Guard")

    # ── T23: The Seal — Dominion +1 while Humbaba stands, off while banished
    g = fresh_game('Humbaba', 'Valak')
    g.players[0].alive = True
    base_req = DOMINION_REQUIREMENT
    if g._dominion_req() != base_req + 1:
        failures.append("FAIL T23a: Seal must raise Dominion requirement by 1")
    g.players[0].alive = False
    if g._dominion_req() != base_req:
        failures.append("FAIL T23b: Seal suspends while Humbaba is banished")

    return failures


# ═══════════════════════════════════════════════════════════════════════
#  ENTRY POINT
# ═══════════════════════════════════════════════════════════════════════
def main():
    parser = argparse.ArgumentParser(description='CORRUPTOR Balance Simulation v5.29-sync')
    parser.add_argument('--games', type=int, default=500)
    parser.add_argument('--quiet', action='store_true')
    parser.add_argument('--seed',  type=int, default=None)
    parser.add_argument('--lock',  action='store_true',
                        help='Lock each player to one lord — pure head-to-head, no switching')
    parser.add_argument('--recoil-hunts-only',     action='store_true')
    parser.add_argument('--sigil-soul-fresh-only', action='store_true')
    parser.add_argument('--invocation-gate',  type=int, default=7)
    parser.add_argument('--profane-ruins-req', type=int, default=2)
    parser.add_argument('--ai-dominion', action='store_true')
    parser.add_argument('--no-backwash', action='store_true')
    parser.add_argument('--reconfig-strict', action='store_true')
    parser.add_argument('--kroni-def-soft', action='store_true')
    parser.add_argument('--kroni-hunger-decay', action='store_true')
    parser.add_argument('--deimos-war-machine-free', action='store_true')
    parser.add_argument('--deimos-summon-cost', type=int, default=0)
    parser.add_argument('--recoil-lowest', action='store_true')
    parser.add_argument('--neutral-tear-on-banish', action='store_true')
    parser.add_argument('--castle-tear-uncapped', action='store_true')
    parser.add_argument('--veil-drift', type=int, default=0)
    parser.add_argument('--invocation-repeatable', action='store_true')
    parser.add_argument('--reconfig-tokens', type=int, default=3)
    parser.add_argument('--reconfig-neutral', action='store_true')
    parser.add_argument('--deimos-claims-breach', type=int, default=0)
    parser.add_argument('--consume-the-siege', action='store_true')
    parser.add_argument('--war-machine-ignores-profaned', action='store_true')
    parser.add_argument('--gremory-summon-cost', type=int, default=0)
    parser.add_argument('--no-humbaba-seal',    action='store_true')
    parser.add_argument('--no-humbaba-toll',    action='store_true')
    parser.add_argument('--no-humbaba-gate4',   action='store_true')
    parser.add_argument('--no-humbaba-patient', action='store_true')
    parser.add_argument('--dominion-req', type=int, default=3)
    parser.add_argument('--win-souls', type=int, default=7)
    parser.add_argument('--dominion-track', type=int, default=12)
    args = parser.parse_args()

    if args.seed is not None:
        random.seed(args.seed)

    VARIANT['recoil_hunts_only']     = args.recoil_hunts_only
    VARIANT['sigil_soul_fresh_only'] = args.sigil_soul_fresh_only
    VARIANT['invocation_gate']       = args.invocation_gate
    VARIANT['profane_ruins_req']     = args.profane_ruins_req
    VARIANT['ai_dominion_drive']     = args.ai_dominion
    VARIANT['no_backwash']           = args.no_backwash
    VARIANT['reconfig_strict']       = args.reconfig_strict
    VARIANT['kroni_def_soft']        = args.kroni_def_soft
    VARIANT['kroni_hunger_decay']    = args.kroni_hunger_decay
    VARIANT['deimos_war_machine_free'] = args.deimos_war_machine_free
    VARIANT['deimos_summon_cost']    = args.deimos_summon_cost
    VARIANT['recoil_lowest']         = args.recoil_lowest
    VARIANT['neutral_tear_on_banish'] = args.neutral_tear_on_banish
    VARIANT['castle_tear_uncapped']  = args.castle_tear_uncapped
    VARIANT['veil_drift']            = args.veil_drift
    VARIANT['invocation_repeatable'] = args.invocation_repeatable
    VARIANT['reconfig_tokens_needed'] = args.reconfig_tokens
    VARIANT['reconfig_neutral']       = args.reconfig_neutral
    VARIANT['deimos_claims_breach']   = args.deimos_claims_breach
    VARIANT['consume_the_siege']      = args.consume_the_siege
    VARIANT['war_machine_ignores_profaned'] = args.war_machine_ignores_profaned
    VARIANT['gremory_summon_cost']    = args.gremory_summon_cost
    VARIANT['humbaba_seal']    = not args.no_humbaba_seal
    VARIANT['humbaba_toll']    = not args.no_humbaba_toll
    VARIANT['humbaba_gate4']   = not args.no_humbaba_gate4
    VARIANT['humbaba_patient'] = not args.no_humbaba_patient
    global DOMINION_REQUIREMENT, WIN_SOULS
    DOMINION_REQUIREMENT = args.dominion_req
    WIN_SOULS = args.win_souls
    global DOMINION_TRACK
    DOMINION_TRACK = args.dominion_track

    # Apply CLI override
    global LOCK_LORDS
    if args.lock:
        LOCK_LORDS = True

    print("Running mechanic unit tests...")
    failures = run_mechanic_tests()
    if failures:
        print(f"\n  ⚠  {len(failures)} test(s) FAILED:")
        for f in failures: print(f"     {f}")
        print("\n  Fix these before trusting simulation results.\n")
    else:
        print(f"  ✓ All 17 mechanic tests passed.\n")

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
        results[(l0, l1)] = run_matchup(l0, l1, args.games)

    elapsed = time.time() - t0
    print(f"\n  Completed {total:,} games in {elapsed:.1f}s  ({total/elapsed:,.0f} games/sec)\n")

    report = generate_report(results, args.games)
    print(report)

    mode_tag = 'locked' if LOCK_LORDS else 'pool'
    out_path = f'/mnt/user-data/outputs/corruptor_balance_report_v44m_{mode_tag}.txt'
    with open(out_path, 'w') as f:
        f.write(report)
    print(f"Report saved to: {out_path}")


if __name__ == '__main__':
    main()
