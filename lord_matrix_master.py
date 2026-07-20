#!/usr/bin/env python3
"""
lord_matrix_master.py — Compact full-game oracle matrix for every ordered Lord matchup.

This does NOT emit 81 enormous full traces. Instead, each scenario stores:
  * its deterministic seed,
  * terminal summary,
  * one SHA-256 hash per canonical checkpoint,
  * one SHA-256 hash for the complete checkpoint sequence.

Godot replays each scenario and compares the same hashes. A failing matchup can
then be promoted temporarily to a full golden trace for detailed structural diff.
"""

from __future__ import annotations

import argparse
import json
import os
import random
import sys
from typing import Any

import golden_master as gm


HERE = os.path.dirname(os.path.abspath(__file__))
OUTPUT_PATH = os.path.join(HERE, "golden", "lord_matrix.json")

MATRIX_VERSION = 1
BASE_SEED = 1000

# Explicit canonical order. There are 9 × 9 = 81 ordered matchups.
LORDS = [
    "Orias",
    "Deimos",
    "Valak",
    "Kroni",
    "Kalligan",
    "Gremory",
    "Odradek",
    "Kanifous",
    "Humbaba",
]


def _slug(value: str) -> str:
    return value.lower()


def scenario_seed(player_zero_index: int, player_one_index: int) -> int:
    """
    Reversed seats use the same seed.

    Example:
      Orias vs Valak and Valak vs Orias share one shuffled deck/RNG stream,
      making seat-order differences easier to diagnose.
    """
    low = min(player_zero_index, player_one_index)
    high = max(player_zero_index, player_one_index)
    return BASE_SEED + low * len(LORDS) + high


def _checkpoint_rows(snapshots: list[dict[str, Any]]) -> list[dict[str, str]]:
    return [
        {
            "checkpoint": str(snapshot.get("checkpoint", "")),
            "hash": gm.gs.trace_hash([snapshot]),
        }
        for snapshot in snapshots
    ]


def _player_summary(player) -> dict[str, Any]:
    return {
        "pid": int(player.pid),
        "lord": str(player.lord),
        "alive": bool(player.alive),
        "souls": int(player.souls),
        "tears": int(player.tears),
        "threat": int(player.threat),
        "castles": len(player.castles),
        "ruined_castles": len(player.ruined_castles),
        "profaned_castles": len(player.profaned_castles),
    }


def _build_scenario(
    player_zero_lord: str,
    player_one_lord: str,
    player_zero_index: int,
    player_one_index: int,
    variant: dict,
    constants: dict,
) -> dict[str, Any]:
    gm.apply_config(variant, constants)

    seed = scenario_seed(
        player_zero_index,
        player_one_index,
    )

    random.seed(seed)

    game = gm.sim.Game(
        [player_zero_lord],
        [player_one_lord],
    )

    snapshots = gm._play_game_with_round_snapshots(game)

    name = (
        f"matrix_{_slug(player_zero_lord)}"
        f"_vs_{_slug(player_one_lord)}"
        f"_s{seed}"
    )

    return {
        "name": name,
        "player_zero_lord": player_zero_lord,
        "player_one_lord": player_one_lord,
        "seed": seed,
        "first_player": int(game.fp),
        "round": int(game.round),
        "winner": int(game.winner),
        "win_by": str(game.win_by),
        "players": [
            _player_summary(player)
            for player in game.players
        ],
        "checkpoint_count": len(snapshots),
        "checkpoints": _checkpoint_rows(snapshots),
        "trace_hash": gm.gs.trace_hash(snapshots),
    }


def build_matrix() -> dict[str, Any]:
    variant = gm.de_v2_variant()
    constants = gm.de_v2_constants()

    scenarios = []

    for player_zero_index, player_zero_lord in enumerate(LORDS):
        for player_one_index, player_one_lord in enumerate(LORDS):
            scenarios.append(
                _build_scenario(
                    player_zero_lord,
                    player_one_lord,
                    player_zero_index,
                    player_one_index,
                    variant,
                    constants,
                )
            )

    return {
        "matrix_version": MATRIX_VERSION,
        "schema_version": gm.gs.SCHEMA_VERSION,
        "sim_version": gm.SIM_VERSION,
        "ai_version": gm.AI_VERSION,
        "identity": gm.gs.config_identity(
            variant,
            constants,
        ),
        "lords": LORDS,
        "ordered_matchups": True,
        "scenario_count": len(scenarios),
        "unique_seed_count": len(
            {
                int(scenario["seed"])
                for scenario in scenarios
            }
        ),
        "seed_scheme": (
            "1000 + min(p0_index,p1_index) * 9 + max(p0_index,p1_index); "
            "reversed seats share a seed"
        ),
        "scenarios": scenarios,
    }


def write_matrix(matrix: dict[str, Any]) -> None:
    os.makedirs(
        os.path.dirname(OUTPUT_PATH),
        exist_ok=True,
    )

    with open(
        OUTPUT_PATH,
        "w",
        encoding="utf-8",
        newline="\n",
    ) as file_handle:
        json.dump(
            matrix,
            file_handle,
            indent=2,
            sort_keys=True,
        )

        file_handle.write("\n")


def check_matrix(matrix: dict[str, Any]) -> int:
    if not os.path.exists(OUTPUT_PATH):
        print(
            "No lord matrix exists on disk. "
            "Run without --check first."
        )
        return 1

    with open(
        OUTPUT_PATH,
        "r",
        encoding="utf-8",
    ) as file_handle:
        disk = json.load(file_handle)

    if disk == matrix:
        print(
            "OK — all %d ordered Lord matchups match the on-disk oracle matrix."
            % int(matrix["scenario_count"])
        )
        return 0

    disk_scenarios = {
        scenario.get("name", ""): scenario
        for scenario in disk.get("scenarios", [])
    }

    current_scenarios = {
        scenario.get("name", ""): scenario
        for scenario in matrix.get("scenarios", [])
    }

    all_names = sorted(
        set(disk_scenarios)
        | set(current_scenarios)
    )

    for name in all_names:
        if disk_scenarios.get(name) != current_scenarios.get(name):
            print(
                "DRIFT — first changed matchup: %s"
                % name
            )
            print(
                "disk trace_hash=%s"
                % disk_scenarios.get(
                    name,
                    {},
                ).get(
                    "trace_hash",
                    "<missing>",
                )
            )
            print(
                "now  trace_hash=%s"
                % current_scenarios.get(
                    name,
                    {},
                ).get(
                    "trace_hash",
                    "<missing>",
                )
            )
            break

    return 1


def print_seed_table(matrix: dict[str, Any]) -> None:
    for scenario in matrix["scenarios"]:
        print(
            "%-9s vs %-9s  seed=%d"
            % (
                scenario["player_zero_lord"],
                scenario["player_one_lord"],
                scenario["seed"],
            )
        )


def main() -> None:
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--check",
        action="store_true",
        help="verify the on-disk matrix still matches the Python oracle",
    )

    parser.add_argument(
        "--print-seeds",
        action="store_true",
        help="print the deterministic seed assigned to every ordered matchup",
    )

    args = parser.parse_args()
    matrix = build_matrix()

    if args.print_seeds:
        print_seed_table(matrix)

    if args.check:
        sys.exit(
            check_matrix(matrix)
        )

    write_matrix(matrix)

    print(
        "Wrote %d ordered Lord matchups to %s"
        % (
            matrix["scenario_count"],
            OUTPUT_PATH,
        )
    )

    print(
        "%d Lords, %d unique seeds, ai=%s"
        % (
            len(matrix["lords"]),
            matrix["unique_seed_count"],
            matrix["ai_version"],
        )
    )


if __name__ == "__main__":
    main()
