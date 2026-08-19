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


def _load(name, path):
    spec = importlib.util.spec_from_file_location(
        name,
        os.path.join(HERE, path),
    )

    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load module {name} from {path}.")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


sim = _load("sim", "corruptor_sim.py")
policy = _load(
    "corruptor_softmax_policy",
    "corruptor_softmax_policy.py",
)
policy.install(sim)

gs = _load(
    "golden_serializer",
    "golden_serializer.py",
)

# Pinned to the installed policy and sim rules versions.
AI_VERSION = sim.AI_POLICY
SIM_VERSION = sim.SIM_VERSION


# ─────────────────────────────────────────────────────────────────────────────
#  CONFIG SNAPSHOTS  (must mirror the GDScript RuleConfig factories)
# ─────────────────────────────────────────────────────────────────────────────
# These switches exist at runtime because the measured lab consumes them, but
# they are inert under canonical DE v2 and are deliberately absent from the
# published canonical golden identity. This mirrors GoldenMaster.gd.
LAB_ONLY_RUNTIME_VARIANT_KEYS = frozenset({
    "odr_recoil_bank",
    "fix_breach_discard_alias",
    "doctrine_ward_threat",
    "doctrine_ward_stagnation",
    "doctrine_bank_urgency",
})


def de_v2_variant() -> dict:
    return {
        key: value
        for key, value in sim.DE_V2_VARIANT.items()
        if key not in LAB_ONLY_RUNTIME_VARIANT_KEYS
    }


def de_v2_constants() -> dict:
    return dict(sim.DE_V2_CONSTANTS)


def apply_config(variant: dict, constants: dict):
    """Push a config into the sim's globals — the same surface the CLI flags hit."""
    # Runtime execution still receives every canonical default, including
    # lab-only switches that are excluded from serialized trace identity.
    sim.VARIANT.clear()
    sim.VARIANT.update(sim.DE_V2_VARIANT)
    sim.VARIANT.update(variant)

    for key, value in constants.items():
        setattr(sim, key, value)


def live_constants(keys=None) -> dict:
    """Read the oracle globals that actually govern the current run."""
    selected_keys = (
        de_v2_constants().keys()
        if keys is None
        else keys
    )

    return {
        key: getattr(sim, key)
        for key in selected_keys
    }


def assert_live_identity(
    variant: dict,
    constants: dict,
    ai_version: str = AI_VERSION,
) -> None:
    """Refuse to generate evidence under a mislabeled live configuration."""
    errors = []
    actual_constants = live_constants(
        constants.keys()
    )

    if actual_constants != constants:
        errors.append(
            "live constants=%r expected=%r"
            % (
                actual_constants,
                constants,
            )
        )

    live_identity_variant = {
        key: sim.VARIANT.get(key)
        for key in variant
    }

    if live_identity_variant != variant:
        errors.append(
            "live identity variant=%r expected=%r"
            % (
                live_identity_variant,
                variant,
            )
        )

    if sim.VARIANT != sim.DE_V2_VARIANT:
        errors.append(
            "live runtime variant=%r expected canonical runtime=%r"
            % (
                sim.VARIANT,
                sim.DE_V2_VARIANT,
            )
        )

    if sim.AI_POLICY != ai_version:
        errors.append(
            "live ai_version=%r expected=%r"
            % (
                sim.AI_POLICY,
                ai_version,
            )
        )

    if errors:
        raise RuntimeError(
            "Golden identity refused: "
            + "; ".join(errors)
        )


def trace_identity_errors(
    trace: dict,
    variant: dict,
    constants: dict,
    ai_version: str = AI_VERSION,
) -> list:
    """Return every identity mismatch between an on-disk trace and live rules."""
    errors = []
    expected_identity = gs.config_identity(
        variant,
        constants,
    )

    if trace.get("ai_version") != ai_version:
        errors.append(
            "ai_version trace=%r live=%r"
            % (
                trace.get("ai_version"),
                ai_version,
            )
        )

    if trace.get("identity") != expected_identity:
        errors.append(
            "identity block does not match canonical live configuration"
        )

    return errors


# ─────────────────────────────────────────────────────────────────────────────
#  UNIT SCENARIOS  — hand-built state, one mechanic, one snapshot pair
# ─────────────────────────────────────────────────────────────────────────────
def _fresh(l0="Orias", l1="Valak"):
    return sim.Game(
        [l0],
        [l1],
    )


def _card(suit, val):
    return sim.Card(
        suit,
        val,
    )


def unit_combat_breakthrough():
    """Rulebook Combat Example: Strength strictly exceeds defense."""
    game = _fresh()
    attacker, _defender = game.players

    guards = [
        _card("Butcher", 5),
        _card("Butcher", 1),
    ]

    before = gs.snapshot_game(
        game,
        "unit:before",
    )

    destroyed, broken, excess = game._combat_layers(
        attacker,
        11,
        guards,
        False,
        0,
        False,
        struct_def=4,
    )

    after = {
        "checkpoint": "unit:after",
        "op": "combat_layers",
        "inputs": {
            "strength": 11,
            "struct_def": 4,
            "sigil_value": 0,
            "guards_in": [
                "Butcher:5",
                "Butcher:1",
            ],
            "ignore_lowest": False,
            "has_sigil": False,
            "bypass": False,
        },
        "result": {
            "destroyed": destroyed,
            "sigil_broken": broken,
            "excess": excess,
            "guards_out": gs.card_multiset(
                guards
            ),
        },
    }

    return (
        "unit_combat_breakthrough",
        [
            before,
            after,
        ],
    )


def unit_combat_golden_rule():
    """Equality never destroys: Strength == total defense."""
    game = _fresh()
    attacker, _defender = game.players

    guards = [
        _card("Butcher", 5),
        _card("Butcher", 1),
    ]

    destroyed, broken, excess = game._combat_layers(
        attacker,
        10,
        guards,
        False,
        0,
        False,
        struct_def=4,
    )

    return (
        "unit_combat_golden_rule",
        [
            {
                "checkpoint": "unit:after",
                "op": "combat_layers",
                "inputs": {
                    "strength": 10,
                    "struct_def": 4,
                    "guards_in": [
                        "Butcher:5",
                        "Butcher:1",
                    ],
                },
                "result": {
                    "destroyed": destroyed,
                    "sigil_broken": broken,
                    "excess": excess,
                    "guards_out": gs.card_multiset(
                        guards
                    ),
                },
            },
        ],
    )


def unit_sigil_layer_break_survive():
    """Sigil broken and target survives."""
    game = _fresh()
    attacker, _defender = game.players

    guards = [
        _card("Butcher", 2),
    ]

    destroyed, broken, excess = game._combat_layers(
        attacker,
        8,
        guards,
        False,
        sigil_value=2,
        has_sigil=True,
        struct_def=4,
    )

    return (
        "unit_sigil_break_survive",
        [
            {
                "checkpoint": "unit:after",
                "op": "combat_layers",
                "inputs": {
                    "strength": 8,
                    "struct_def": 4,
                    "sigil_value": 2,
                    "has_sigil": True,
                    "guards_in": [
                        "Butcher:2",
                    ],
                },
                "result": {
                    "destroyed": destroyed,
                    "sigil_broken": broken,
                    "excess": excess,
                    "guards_out": gs.card_multiset(
                        guards
                    ),
                },
            },
        ],
    )


def unit_siege_engine_bypass():
    """Bypass order: Sigil -> Structure -> Guards."""
    game = _fresh()
    attacker, _defender = game.players

    guards = [
        _card("Butcher", 4),
        _card("Butcher", 3),
        _card("Butcher", 2),
    ]

    destroyed, broken, excess = game._combat_layers(
        attacker,
        13,
        guards,
        False,
        0,
        False,
        struct_def=7,
        bypass=True,
    )

    return (
        "unit_siege_engine_bypass",
        [
            {
                "checkpoint": "unit:after",
                "op": "combat_layers",
                "inputs": {
                    "strength": 13,
                    "struct_def": 7,
                    "bypass": True,
                    "guards_in": [
                        "Butcher:4",
                        "Butcher:3",
                        "Butcher:2",
                    ],
                },
                "result": {
                    "destroyed": destroyed,
                    "sigil_broken": broken,
                    "excess": excess,
                    "guards_out": gs.card_multiset(
                        guards
                    ),
                },
            },
        ],
    )


def unit_humbaba_defense_curve():
    """Defense woven into intact castles."""
    game = _fresh(
        "Humbaba",
        "Valak",
    )

    player = game.players[0]
    rows = []

    for castles, threat in [
        (
            set(),
            0,
        ),
        (
            {
                "Keep",
            },
            0,
        ),
        (
            {
                "Keep",
                "Bastion",
                "Stockpile",
                "SummoningCircle",
                "SiegeEngine",
            },
            0,
        ),
        (
            {
                "Keep",
                "Bastion",
                "Stockpile",
            },
            2,
        ),
    ]:
        player.castles = set(
            castles
        )

        player.threat = threat

        rows.append(
            {
                "castles": sorted(
                    castles
                ),
                "threat": threat,
                "def": player.lord_base_def(),
            }
        )

    return (
        "unit_humbaba_defense_curve",
        [
            {
                "checkpoint": "unit:after",
                "op": "lord_base_def",
                "rows": rows,
            },
        ],
    )


def unit_humbaba_seal():
    """Dominion requirement rises while Humbaba stands."""
    game = _fresh(
        "Humbaba",
        "Valak",
    )

    game.players[0].alive = True
    standing = game._dominion_req()

    game.players[0].alive = False
    banished = game._dominion_req()

    return (
        "unit_humbaba_seal",
        [
            {
                "checkpoint": "unit:after",
                "op": "dominion_req",
                "result": {
                    "standing": standing,
                    "banished": banished,
                    "base": sim.DOMINION_REQUIREMENT,
                },
            },
        ],
    )


UNIT_SCENARIOS = [
    unit_combat_breakthrough,
    unit_combat_golden_rule,
    unit_sigil_layer_break_survive,
    unit_siege_engine_bypass,
    unit_humbaba_defense_curve,
    unit_humbaba_seal,
]



# ─────────────────────────────────────────────────────────────────────────────
#  GAME SCENARIOS — fixed-seed game with a checkpoint after every round
# ─────────────────────────────────────────────────────────────────────────────
class _GoldenLegacyRNGStreams:
    """Canonical golden compatibility adapter for historical seeded traces."""

    def __init__(self, seed):
        if seed is None:
            raise RuntimeError(
                "Golden game scenarios require an explicit deterministic seed."
            )
        self.seed = int(seed)
        random.seed(self.seed)

    def stream(self, _name: str):
        return random


def _play_game_with_round_snapshots(game):
    """
    Run the oracle one round at a time.

    The ordinary simulator run() method is ideal for balance batches, but the
    golden harness needs a structural checkpoint after each completed round so
    a terminal mismatch reports the first divergent round rather than only the
    final deck.
    """
    snapshots = []

    game._setup()

    snapshots.append(
        gs.snapshot_game(
            game,
            "game:deal",
        )
    )

    for round_number in range(
        1,
        sim.MAX_ROUNDS + 1,
    ):
        game.round = round_number

        if round_number == 1:
            game._round1()
        else:
            game._full_round()

        snapshots.append(
            gs.snapshot_game(
                game,
                f"round:{round_number:02d}:end",
            )
        )

        if game.winner is not None:
            break

        if game._check_win():
            break

    if game.winner is None:
        player_zero, player_one = game.players

        if player_zero.souls != player_one.souls:
            winner = (
                0
                if player_zero.souls > player_one.souls
                else 1
            )
        elif len(player_zero.castles) != len(player_one.castles):
            winner = (
                0
                if len(player_zero.castles) > len(player_one.castles)
                else 1
            )
        elif player_zero.threat != player_one.threat:
            winner = (
                0
                if player_zero.threat < player_one.threat
                else 1
            )
        else:
            winner = random.randint(
                0,
                1,
            )

        game.winner = winner
        game.win_by = "Timeout"

    snapshots.append(
        gs.snapshot_game(
            game,
            "game:end",
        )
    )

    return snapshots


def game_scenario(
    name,
    seed,
    l0_pool,
    l1_pool,
):
    def build():
        random.seed(
            seed
        )

        game = sim.Game(
            list(l0_pool),
            list(l1_pool),
            seed=seed,
        )

        # The historical Python/Godot goldens consume one shared Python
        # Mersenne-Twister stream. v7's named RNGStreams are correct for balance
        # experiments, but the golden contract deliberately preserves the
        # historical seeded stream so Godot's PythonRandom replay remains exact.
        game.rng = _GoldenLegacyRNGStreams(seed)

        snapshots = _play_game_with_round_snapshots(
            game
        )

        return (
            name,
            seed,
            snapshots,
        )

    return build


GAME_SCENARIOS = [
    game_scenario(
        "game_deimos_valak_s1",
        1,
        [
            "Deimos",
        ],
        [
            "Valak",
        ],
    ),
    game_scenario(
        "game_odradek_humbaba_s7",
        7,
        [
            "Odradek",
        ],
        [
            "Humbaba",
        ],
    ),
    game_scenario(
        "game_kroni_orias_s42",
        42,
        [
            "Kroni",
        ],
        [
            "Orias",
        ],
    ),
    game_scenario(
        "game_pool_mixed_s99",
        99,
        [
            "Gremory",
            "Kalligan",
            "Kanifous",
        ],
        [
            "Deimos",
            "Valak",
            "Odradek",
        ],
    ),
]


# ─────────────────────────────────────────────────────────────────────────────
#  DRIVER
# ─────────────────────────────────────────────────────────────────────────────
def generate_all() -> dict:
    """Return {filename: trace_dict} using the DE v2 config."""
    variant = de_v2_variant()
    constants = de_v2_constants()
    traces = {}

    apply_config(
        variant,
        constants,
    )
    assert_live_identity(
        variant,
        constants,
    )

    for scenario in UNIT_SCENARIOS:
        name, snapshots = scenario()

        traces[name] = gs.build_trace(
            name,
            seed=0,
            variant=variant,
            constants=constants,
            snapshots=snapshots,
            ai_version=AI_VERSION,
        )

    for build in GAME_SCENARIOS:
        apply_config(
            variant,
            constants,
        )
        assert_live_identity(
            variant,
            constants,
        )

        name, seed, snapshots = build()

        traces[name] = gs.build_trace(
            name,
            seed=seed,
            variant=variant,
            constants=constants,
            snapshots=snapshots,
            ai_version=AI_VERSION,
        )

    return traces


def write_all(traces: dict):
    os.makedirs(
        GOLDEN_DIR,
        exist_ok=True,
    )

    manifest = {
        "schema_version": gs.SCHEMA_VERSION,
        "ai_version": AI_VERSION,
        "traces": {},
    }

    for name, trace in traces.items():
        path = os.path.join(
            GOLDEN_DIR,
            name + ".json",
        )

        with open(
            path,
            "w",
            encoding="utf-8",
        ) as file_handle:
            json.dump(
                trace,
                file_handle,
                indent=2,
                sort_keys=True,
            )

        manifest["traces"][name] = trace[
            "trace_hash"
        ]

    with open(
        os.path.join(
            GOLDEN_DIR,
            "_manifest.json",
        ),
        "w",
        encoding="utf-8",
    ) as file_handle:
        json.dump(
            manifest,
            file_handle,
            indent=2,
            sort_keys=True,
        )

    return manifest


def check_all(traces: dict) -> int:
    """Validate identity, file integrity, manifest integrity, and live drift."""
    manifest_path = os.path.join(
        GOLDEN_DIR,
        "_manifest.json",
    )

    if not os.path.exists(
        manifest_path
    ):
        print(
            "  no manifest on disk — run without --check first."
        )

        return 1

    with open(
        manifest_path,
        "r",
        encoding="utf-8",
    ) as file_handle:
        manifest = json.load(
            file_handle
        )

    failures = 0
    disk = manifest.get(
        "traces",
        {},
    )
    variant = de_v2_variant()
    constants = de_v2_constants()

    if manifest.get("schema_version") != gs.SCHEMA_VERSION:
        failures += 1
        print(
            "  IDENTITY  manifest schema trace=%r live=%r"
            % (
                manifest.get("schema_version"),
                gs.SCHEMA_VERSION,
            )
        )

    if manifest.get("ai_version") != AI_VERSION:
        failures += 1
        print(
            "  IDENTITY  manifest ai_version trace=%r live=%r"
            % (
                manifest.get("ai_version"),
                AI_VERSION,
            )
        )

    for name, trace in traces.items():
        trace_path = os.path.join(
            GOLDEN_DIR,
            name + ".json",
        )

        if not os.path.exists(trace_path):
            failures += 1
            print(
                "  MISSING trace file for %s"
                % name
            )
            continue

        with open(
            trace_path,
            "r",
            encoding="utf-8",
        ) as file_handle:
            disk_trace = json.load(
                file_handle
            )

        for error in trace_identity_errors(
            disk_trace,
            variant,
            constants,
        ):
            failures += 1
            print(
                "  IDENTITY  %s: %s"
                % (
                    name,
                    error,
                )
            )

        recorded_hash = disk_trace.get(
            "trace_hash"
        )
        actual_hash = gs.trace_hash(
            disk_trace.get(
                "snapshots",
                [],
            )
        )
        manifest_hash = disk.get(
            name
        )
        regenerated_hash = trace[
            "trace_hash"
        ]

        if recorded_hash != actual_hash:
            failures += 1
            print(
                "  CORRUPT  %s trace_hash=%s snapshots=%s"
                % (
                    name,
                    recorded_hash,
                    actual_hash,
                )
            )

        if manifest_hash != recorded_hash:
            failures += 1
            print(
                "  MANIFEST  %s manifest=%s trace=%s"
                % (
                    name,
                    manifest_hash,
                    recorded_hash,
                )
            )

        if regenerated_hash != recorded_hash:
            failures += 1
            print(
                "  DRIFT  %s\n"
                "         disk=%s\n"
                "         now =%s"
                % (
                    name,
                    recorded_hash,
                    regenerated_hash,
                )
            )

    for name in disk:
        if name not in traces:
            failures += 1

            print(
                "  MISSING regenerated trace for %s"
                % name
            )

    if failures == 0:
        print(
            "  OK — all %d traces match on-disk hashes."
            % len(
                traces
            )
        )

    return failures


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--check",
        action="store_true",
        help=(
            "verify on-disk goldens still match "
            "the oracle (CI guard)"
        ),
    )

    args = parser.parse_args()
    traces = generate_all()

    if args.check:
        sys.exit(
            1
            if check_all(
                traces
            )
            else 0
        )

    manifest = write_all(
        traces
    )

    print(
        "Wrote %d golden traces to %s/"
        % (
            len(
                manifest["traces"]
            ),
            GOLDEN_DIR,
        )
    )

    print(
        "schema v%d  ai=%s"
        % (
            gs.SCHEMA_VERSION,
            AI_VERSION,
        )
    )

    for name, trace_hash in sorted(
        manifest["traces"].items()
    ):
        print(
            "  %-32s %s…"
            % (
                name,
                trace_hash[:16],
            )
        )


if __name__ == "__main__":
    main()
