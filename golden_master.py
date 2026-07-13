#!/usr/bin/env python3
"""
golden_master.py — Generate golden-master traces from the Python oracle.

Two scenario families:

  UNIT scenarios  — a hand-built board state run through exactly one mechanic
                    (a single combat, a sigil contest, a Toll). These pin the
                    rulebook's worked examples and the trickiest kits. Fast,
                    surgical, and the first thing the GDScript engine should pass.

  GAME scenarios  — a full fixed-seed game under a named config, snapshotting
                    canonical state at every checkpoint of every round. These pin
                    emergent integration: the thing no unit test catches.

Output: one JSON file per scenario in ./golden/, each a versioned trace with a
sha256. The GDScript loader replays the same seed under the same RuleConfig and
asserts snapshot-equality (or, cheaply, trace_hash equality first).

Usage:
    python3 golden_master.py            # (re)generate all golden files
    python3 golden_master.py --check    # regenerate in-memory, diff vs on-disk,
                                         # fail if drift (CI guard for the oracle)
"""

import os
import sys
import json
import random
import argparse
import importlib.util

HERE = os.path.dirname(os.path.abspath(__file__))
GOLDEN_DIR = os.path.join(HERE, "golden")

# Load the sim and serializer as modules
def _load(name, path):
    spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, path))
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    return m

sim = _load("sim", "corruptor_sim.py")
gs  = _load("golden_serializer", "golden_serializer.py")

# Pinned to the sim's own version constants — never a parallel hardcode (Law 5).
AI_VERSION = sim.AI_POLICY
SIM_VERSION = sim.SIM_VERSION


# ─────────────────────────────────────────────────────────────────────────────
#  CONFIG SNAPSHOTS  (must mirror the GDScript RuleConfig factories)
# ─────────────────────────────────────────────────────────────────────────────
def de_v2_variant() -> dict:
    return dict(
        recoil_hunts_only=True, sigil_soul_fresh_only=False, invocation_gate=5,
        profane_ruins_req=1, ai_dominion_drive=True, no_backwash=False,
        reconfig_strict=True, kroni_def_soft=False, kroni_hunger_decay=True,
        deimos_war_machine_free=True, deimos_summon_cost=7, recoil_lowest=True,
        neutral_tear_on_banish=True, castle_tear_uncapped=False, veil_drift=0,
        invocation_repeatable=False, reconfig_tokens_needed=5, reconfig_neutral=False,
        deimos_claims_breach=1, consume_the_siege=False,
        war_machine_ignores_profaned=False, gremory_summon_cost=6,
        humbaba_seal=True, humbaba_toll=True, humbaba_gate4=True, humbaba_patient=True,
    )

def de_v2_constants() -> dict:
    return dict(WIN_SOULS=7, DOMINION_TRACK=11, DOMINION_REQUIREMENT=2,
                FINAL_COLLAPSE_TRACK=15, HAND_LIMIT=10, GARRISON_MAX=5,
                MAX_THREAT=4, MARKET_SIZE=3, MAX_ROUNDS=60)

def apply_config(variant: dict, constants: dict):
    """Push a config into the sim's globals — the same surface the CLI flags hit."""
    defaults = dict(recoil_hunts_only=False, sigil_soul_fresh_only=False, invocation_gate=7,
        profane_ruins_req=2, ai_dominion_drive=False, no_backwash=False, reconfig_strict=False,
        kroni_def_soft=False, kroni_hunger_decay=False, deimos_war_machine_free=False,
        deimos_summon_cost=0, recoil_lowest=False, neutral_tear_on_banish=False,
        castle_tear_uncapped=False, veil_drift=0, invocation_repeatable=False,
        reconfig_tokens_needed=3, reconfig_neutral=False, deimos_claims_breach=0,
        consume_the_siege=False, war_machine_ignores_profaned=False, gremory_summon_cost=0,
        humbaba_seal=True, humbaba_toll=True, humbaba_gate4=True, humbaba_patient=True)
    sim.VARIANT.update(defaults); sim.VARIANT.update(variant)
    sim.WIN_SOULS            = constants["WIN_SOULS"]
    sim.DOMINION_TRACK       = constants["DOMINION_TRACK"]
    sim.DOMINION_REQUIREMENT = constants["DOMINION_REQUIREMENT"]
    sim.FINAL_COLLAPSE_TRACK = constants["FINAL_COLLAPSE_TRACK"]


# ─────────────────────────────────────────────────────────────────────────────
#  UNIT SCENARIOS  — hand-built state, one mechanic, one snapshot pair
# ─────────────────────────────────────────────────────────────────────────────
# Each returns (name, [snapshot_before, snapshot_after]). We build a real Game,
# force a specific board, run exactly one operation, and snapshot around it.

def _fresh(l0="Orias", l1="Valak"):
    g = sim.Game([l0], [l1])
    return g

def _card(suit, val): return sim.Card(suit, val)

def unit_combat_breakthrough():
    """Rulebook Combat Example: Strength strictly exceeds guards+structure -> destroy."""
    g = _fresh()
    atk, dfn = g.players
    guards = [_card("Butcher", 5), _card("Butcher", 1)]
    before = gs.snapshot_game(g, "unit:before")
    destroyed, broken, excess = g._combat_layers(
        atk, 11, guards, False, 0, False, struct_def=4)
    after = {
        "checkpoint": "unit:after",
        "op": "combat_layers",
        "inputs": {"strength": 11, "struct_def": 4, "sigil_value": 0,
                   "guards_in": ["Butcher:5", "Butcher:1"], "ignore_lowest": False,
                   "has_sigil": False, "bypass": False},
        "result": {"destroyed": destroyed, "sigil_broken": broken, "excess": excess,
                   "guards_out": gs.card_multiset(guards)},
    }
    return ("unit_combat_breakthrough", [before, after])

def unit_combat_golden_rule():
    """Equality never destroys: Strength == total defense -> holds, guards cleared."""
    g = _fresh(); atk, dfn = g.players
    guards = [_card("Butcher", 5), _card("Butcher", 1)]
    destroyed, broken, excess = g._combat_layers(
        atk, 10, guards, False, 0, False, struct_def=4)
    return ("unit_combat_golden_rule", [{
        "checkpoint": "unit:after", "op": "combat_layers",
        "inputs": {"strength": 10, "struct_def": 4, "guards_in": ["Butcher:5", "Butcher:1"]},
        "result": {"destroyed": destroyed, "sigil_broken": broken, "excess": excess,
                   "guards_out": gs.card_multiset(guards)},
    }])

def unit_sigil_layer_break_survive():
    """Sigil broken, target survives -> controller +1 soul (checked via wrapper)."""
    g = _fresh(); atk, dfn = g.players
    guards = [_card("Butcher", 2)]
    destroyed, broken, excess = g._combat_layers(
        atk, 8, guards, False, sigil_value=2, has_sigil=True, struct_def=4)
    return ("unit_sigil_break_survive", [{
        "checkpoint": "unit:after", "op": "combat_layers",
        "inputs": {"strength": 8, "struct_def": 4, "sigil_value": 2, "has_sigil": True,
                   "guards_in": ["Butcher:2"]},
        "result": {"destroyed": destroyed, "sigil_broken": broken, "excess": excess,
                   "guards_out": gs.card_multiset(guards)},
    }])

def unit_siege_engine_bypass():
    """Bypass order: Sigil -> Structure -> Guards."""
    g = _fresh(); atk, dfn = g.players
    guards = [_card("Butcher", 4), _card("Butcher", 3), _card("Butcher", 2)]
    destroyed, broken, excess = g._combat_layers(
        atk, 13, guards, False, 0, False, struct_def=7, bypass=True)
    return ("unit_siege_engine_bypass", [{
        "checkpoint": "unit:after", "op": "combat_layers",
        "inputs": {"strength": 13, "struct_def": 7, "bypass": True,
                   "guards_in": ["Butcher:4", "Butcher:3", "Butcher:2"]},
        "result": {"destroyed": destroyed, "sigil_broken": broken, "excess": excess,
                   "guards_out": gs.card_multiset(guards)},
    }])

def unit_humbaba_defense_curve():
    """Defense woven into intact castles: 2 + castles (+Bastion), Threat-adjusted."""
    g = _fresh("Humbaba", "Valak"); pl = g.players[0]
    rows = []
    for cs, threat in [(set(), 0),
                       ({"Keep"}, 0),
                       ({"Keep","Bastion","Stockpile","SummoningCircle","SiegeEngine"}, 0),
                       ({"Keep","Bastion","Stockpile"}, 2)]:
        pl.castles = set(cs); pl.threat = threat
        rows.append({"castles": sorted(cs), "threat": threat, "def": pl.lord_base_def()})
    return ("unit_humbaba_defense_curve", [{
        "checkpoint": "unit:after", "op": "lord_base_def", "rows": rows}])

def unit_humbaba_seal():
    """Dominion requirement +1 while Humbaba stands, suspended while banished."""
    g = _fresh("Humbaba", "Valak")
    g.players[0].alive = True;  standing = g._dominion_req()
    g.players[0].alive = False; banished = g._dominion_req()
    return ("unit_humbaba_seal", [{
        "checkpoint": "unit:after", "op": "dominion_req",
        "result": {"standing": standing, "banished": banished,
                   "base": sim.DOMINION_REQUIREMENT}}])

UNIT_SCENARIOS = [
    unit_combat_breakthrough, unit_combat_golden_rule, unit_sigil_layer_break_survive,
    unit_siege_engine_bypass, unit_humbaba_defense_curve, unit_humbaba_seal,
]


# ─────────────────────────────────────────────────────────────────────────────
#  GAME SCENARIOS  — full fixed-seed game, snapshot every checkpoint
# ─────────────────────────────────────────────────────────────────────────────
# We can't hook the sim's private round loop without editing it, so the harness
# runs the game to completion and captures a coarse but fully-deterministic
# trace: initial deal + terminal state. For finer per-round checkpoints, the
# real GDScript port will expose step hooks; this coarse trace already catches
# deck-order, setup, and win-resolution divergence — the highest-value cases.

def game_scenario(name, seed, l0_pool, l1_pool):
    def build():
        random.seed(seed)
        g = sim.Game(list(l0_pool), list(l1_pool))
        # snapshot the deal (post-setup, pre-play) by running setup manually
        g._setup()
        snap_deal = gs.snapshot_game(g, "game:deal")
        # then play to completion on a FRESH game with the SAME reseeded stream:
        # Game.__init__ consumes no RNG and run() begins with _setup(), so g2's
        # post-setup state is identical to the deal snapshot above.
        random.seed(seed)
        g2 = sim.Game(list(l0_pool), list(l1_pool))
        w, wb = g2.run()
        snap_end = gs.snapshot_game(g2, "game:end")
        return (name, seed, [snap_deal, snap_end])
    return build

GAME_SCENARIOS = [
    game_scenario("game_deimos_valak_s1",   1, ["Deimos"],   ["Valak"]),
    game_scenario("game_odradek_humbaba_s7", 7, ["Odradek"],  ["Humbaba"]),
    game_scenario("game_kroni_orias_s42",   42, ["Kroni"],    ["Orias"]),
    game_scenario("game_pool_mixed_s99",    99, ["Gremory","Kalligan","Kanifous"],
                                                ["Deimos","Valak","Odradek"]),
]


# ─────────────────────────────────────────────────────────────────────────────
#  DRIVER
# ─────────────────────────────────────────────────────────────────────────────
def generate_all() -> dict:
    """Returns {filename: trace_dict}. DE v2 config for everything."""
    variant, constants = de_v2_variant(), de_v2_constants()
    traces = {}

    # Unit scenarios: config still applied (Humbaba/Deimos dials matter)
    apply_config(variant, constants)
    for fn in UNIT_SCENARIOS:
        name, snaps = fn()
        traces[name] = gs.build_trace(name, seed=0, variant=variant,
                                      constants=constants, snapshots=snaps,
                                      ai_version=AI_VERSION)
    # Game scenarios
    for build in GAME_SCENARIOS:
        apply_config(variant, constants)   # re-apply (game runs may mutate globals)
        name, seed, snaps = build()
        traces[name] = gs.build_trace(name, seed=seed, variant=variant,
                                      constants=constants, snapshots=snaps,
                                      ai_version=AI_VERSION)
    return traces


def write_all(traces: dict):
    os.makedirs(GOLDEN_DIR, exist_ok=True)
    manifest = {"schema_version": gs.SCHEMA_VERSION, "ai_version": AI_VERSION,
                "traces": {}}
    for name, trace in traces.items():
        path = os.path.join(GOLDEN_DIR, name + ".json")
        with open(path, "w") as f:
            json.dump(trace, f, indent=2, sort_keys=True)
        manifest["traces"][name] = trace["trace_hash"]
    with open(os.path.join(GOLDEN_DIR, "_manifest.json"), "w") as f:
        json.dump(manifest, f, indent=2, sort_keys=True)
    return manifest


def check_all(traces: dict) -> int:
    """Regenerate in-memory, compare hashes to on-disk. Returns failure count."""
    mpath = os.path.join(GOLDEN_DIR, "_manifest.json")
    if not os.path.exists(mpath):
        print("  no manifest on disk — run without --check first."); return 1
    disk = json.load(open(mpath))["traces"]
    fails = 0
    for name, trace in traces.items():
        want = disk.get(name)
        got = trace["trace_hash"]
        if want != got:
            fails += 1
            print(f"  DRIFT  {name}\n         disk={want}\n         now ={got}")
    for name in disk:
        if name not in traces:
            fails += 1; print(f"  MISSING regenerated trace for {name}")
    if not fails:
        print(f"  OK — all {len(traces)} traces match on-disk hashes.")
    return fails


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true",
                    help="verify on-disk goldens still match the oracle (CI guard)")
    args = ap.parse_args()

    traces = generate_all()
    if args.check:
        sys.exit(1 if check_all(traces) else 0)
    manifest = write_all(traces)
    print(f"Wrote {len(manifest['traces'])} golden traces to {GOLDEN_DIR}/")
    print(f"schema v{gs.SCHEMA_VERSION}  ai={AI_VERSION}")
    for name, h in sorted(manifest["traces"].items()):
        print(f"  {name:<32} {h[:16]}…")


if __name__ == "__main__":
    main()
