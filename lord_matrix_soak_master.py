#!/usr/bin/env python3
"""Generate one temporary, reproducible Lord-matrix parity soak batch.

This is deliberately separate from the permanent golden suite. Each invocation
writes only one temporary batch containing compact checkpoint hashes and the
expected terminal snapshot. The Godot runner consumes the batch and deletes it
after a clean pass.
"""

from __future__ import annotations

import argparse
import json
import os
import random
import sys
from typing import Any

import golden_master as gm
import lord_matrix_master as matrix


SOAK_VERSION = 1
DEFAULT_MASTER_SEED = 20260719
MAX_GAME_SEED = 2_147_483_647
EXPECTED_CARD_POPULATION = 60


def deterministic_seeds(
    master_seed: int,
    count: int,
) -> list[int]:
    """Return a stable sequence of unique positive 31-bit game seeds."""
    random_source = random.Random(master_seed)
    result: list[int] = []
    seen: set[int] = set()

    while len(result) < count:
        candidate = random_source.randint(
            1,
            MAX_GAME_SEED,
        )

        if candidate in seen:
            continue

        seen.add(candidate)
        result.append(candidate)

    return result


def validate_snapshot_card_population(
    snapshots: list[dict[str, Any]],
    scenario_name: str,
) -> None:
    top_level_zones = ("deck", "discard", "market")
    player_zones = (
        "hand",
        "garrison",
        "castle_guards",
        "lord_guards",
        "committed",
    )

    for snapshot in snapshots:
        total = sum(
            len(snapshot.get(zone, []))
            for zone in top_level_zones
        )

        for player in snapshot.get("players", []):
            total += sum(
                len(player.get(zone, []))
                for zone in player_zones
            )

        if total != EXPECTED_CARD_POPULATION:
            raise RuntimeError(
                "Card population failure for %s at %s: want=%d got=%d"
                % (
                    scenario_name,
                    snapshot.get("checkpoint", "?"),
                    EXPECTED_CARD_POPULATION,
                    total,
                )
            )


def _checkpoint_rows(
    snapshots: list[dict[str, Any]],
) -> list[dict[str, str]]:
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
    seed: int,
    seed_index: int,
    variant: dict,
    constants: dict,
) -> dict[str, Any]:
    gm.apply_config(variant, constants)
    random.seed(seed)

    game = gm.sim.Game(
        [player_zero_lord],
        [player_one_lord],
    )

    snapshots = gm._play_game_with_round_snapshots(game)
    scenario_name = (
        "soak_%s_vs_%s_s%d"
        % (
            player_zero_lord.lower(),
            player_one_lord.lower(),
            seed,
        )
    )
    validate_snapshot_card_population(
        snapshots,
        scenario_name,
    )

    return {
        "name": scenario_name,
        "player_zero_lord": player_zero_lord,
        "player_one_lord": player_one_lord,
        "seed": seed,
        "seed_index": seed_index,
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
        "terminal_snapshot": snapshots[-1],
    }


def build_batch(
    master_seed: int,
    seed_start: int,
    seed_count: int,
) -> dict[str, Any]:
    variant = gm.de_v2_variant()
    constants = gm.de_v2_constants()
    all_seeds = deterministic_seeds(
        master_seed,
        seed_start + seed_count,
    )
    seeds = all_seeds[
        seed_start:seed_start + seed_count
    ]
    scenarios: list[dict[str, Any]] = []

    for relative_index, seed in enumerate(seeds):
        seed_index = seed_start + relative_index

        for player_zero_lord in matrix.LORDS:
            for player_one_lord in matrix.LORDS:
                scenarios.append(
                    _build_scenario(
                        player_zero_lord,
                        player_one_lord,
                        seed,
                        seed_index,
                        variant,
                        constants,
                    )
                )

    return {
        "soak_version": SOAK_VERSION,
        "matrix_version": matrix.MATRIX_VERSION,
        "schema_version": gm.gs.SCHEMA_VERSION,
        "sim_version": gm.SIM_VERSION,
        "ai_version": gm.AI_VERSION,
        "identity": gm.gs.config_identity(
            variant,
            constants,
        ),
        "lords": matrix.LORDS,
        "ordered_matchups": True,
        "master_seed": master_seed,
        "seed_start": seed_start,
        "seed_count": seed_count,
        "seeds": seeds,
        "scenario_count": len(scenarios),
        "scenarios": scenarios,
    }


def write_batch(
    batch: dict[str, Any],
    output_path: str,
) -> None:
    output_path = os.path.abspath(output_path)
    output_directory = os.path.dirname(output_path)

    if output_directory:
        os.makedirs(output_directory, exist_ok=True)

    temporary_path = "%s.tmp.%d" % (
        output_path,
        os.getpid(),
    )

    try:
        with open(
            temporary_path,
            "w",
            encoding="utf-8",
            newline="\n",
        ) as file_handle:
            json.dump(
                batch,
                file_handle,
                separators=(",", ":"),
                sort_keys=True,
            )
            file_handle.write("\n")

        os.replace(
            temporary_path,
            output_path,
        )
    finally:
        if os.path.exists(temporary_path):
            os.unlink(temporary_path)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--master-seed",
        type=int,
        default=DEFAULT_MASTER_SEED,
    )
    parser.add_argument(
        "--seed-start",
        type=int,
        required=True,
    )
    parser.add_argument(
        "--seed-count",
        type=int,
        required=True,
    )
    parser.add_argument(
        "--output",
        required=True,
    )
    args = parser.parse_args()

    if args.seed_start < 0:
        parser.error("--seed-start must be at least zero")

    if args.seed_count <= 0:
        parser.error("--seed-count must be positive")

    batch = build_batch(
        args.master_seed,
        args.seed_start,
        args.seed_count,
    )
    write_batch(batch, args.output)

    seeds = batch["seeds"]
    print(
        "Wrote soak seed indexes %d..%d (%d games; first seed=%d, last seed=%d)."
        % (
            args.seed_start,
            args.seed_start + args.seed_count - 1,
            int(batch["scenario_count"]),
            int(seeds[0]),
            int(seeds[-1]),
        )
    )

    return 0


if __name__ == "__main__":
    sys.exit(main())
