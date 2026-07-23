#!/usr/bin/env python3
"""Audit parity-sensitive Python-oracle events across exact soak scenarios.

The auditor imports the same configured oracle and seed generator as the
Godot parity soak. Instrumentation is process-local: Game methods are wrapped
after import, no simulation source or game state is modified, and every event
is attributed to an exact (seed index, seed, ordered matchup) case.

This is semantic event coverage, not exhaustive control-flow coverage. A clean
report proves that every event named in TRACKED_EVENTS occurred; it must not be
described as proof that every Python/Godot code branch executed.
"""

from __future__ import annotations

import argparse
import json
import random
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable

import golden_master as gm
import lord_matrix_master as matrix
import lord_matrix_soak_master as soak


TRACKED_EVENTS: tuple[str, ...] = (
    "draw_discard_recycle",
    "kanifous_reveal_recycle",
    "kanifous_invoke",
    "kanifous_high_invoke",
    "kroni_combat_consume",
    "kroni_ravenous",
    "consume_the_hunt",
    "vessel_offer",
    "odradek_paradox_steal",
    "odradek_reconfiguration_tear",
    "gremory_inevitable_ruin",
    "gremory_ruinous_harvest",
    "humbaba_toll",
    "cataclysmic_invocation",
    "profane_the_ruins",
    "profane_commitment_success",
    "profane_blocked_by_fresh_sigil",
    "deimos_claim_the_breach",
)


@dataclass(frozen=True, order=True)
class Case:
    seed_index: int
    seed: int
    player_zero_lord: str
    player_one_lord: str

    @property
    def matchup(self) -> str:
        return f"{self.player_zero_lord} vs {self.player_one_lord}"

    def as_dict(self) -> dict[str, Any]:
        return {
            "seed_index": self.seed_index,
            "seed": self.seed,
            "player_zero_lord": self.player_zero_lord,
            "player_one_lord": self.player_one_lord,
        }


class Counter:
    def __init__(self) -> None:
        self.current_case: Case | None = None
        self.enabled = True
        self.event_counts: defaultdict[str, int] = defaultdict(int)
        self.cases_hitting: defaultdict[str, set[Case]] = defaultdict(set)
        self.seeds_hitting: defaultdict[str, set[int]] = defaultdict(set)

    def fire(self, event: str, count: int = 1) -> None:
        if not self.enabled:
            return

        if event not in TRACKED_EVENTS:
            raise RuntimeError(f"Unregistered coverage event: {event}")

        if self.current_case is None:
            raise RuntimeError(f"Coverage event outside a scenario: {event}")

        self.event_counts[event] += count
        self.cases_hitting[event].add(self.current_case)
        self.seeds_hitting[event].add(self.current_case.seed)

    def clear(self) -> None:
        self.event_counts.clear()
        self.cases_hitting.clear()
        self.seeds_hitting.clear()


PreObserver = Callable[..., Any]
PostObserver = Callable[..., None]


def install_instrument(counter: Counter) -> None:
    """Wrap configured oracle methods with pure pre/post observations."""
    game_type = gm.sim.Game

    def wrap(
        method_name: str,
        pre_observer: PreObserver | None,
        post_observer: PostObserver,
    ) -> None:
        original = getattr(game_type, method_name)

        def wrapped(game, *args, **kwargs):
            before = (
                pre_observer(game, *args, **kwargs)
                if pre_observer is not None
                else None
            )
            result = original(game, *args, **kwargs)
            post_observer(game, before, result, *args, **kwargs)
            return result

        wrapped.__name__ = method_name
        wrapped.__qualname__ = original.__qualname__
        setattr(game_type, method_name, wrapped)

    def draw_pre(game, *args, **kwargs):
        return not game.deck and bool(game.discard)

    def draw_post(game, recycled, result, *args, **kwargs):
        if recycled:
            counter.fire("draw_discard_recycle")

    wrap("_draw", draw_pre, draw_post)

    def invoke_pre(game, player, *args, **kwargs):
        return {
            "deck_count": len(game.deck),
            "discard_count": len(game.discard),
            "invokes": int(player.kanifous_invokes_this_round),
            "high": bool(player.kanifous_invoked_high),
        }

    def invoke_post(game, before, result, player, *args, **kwargs):
        if before["discard_count"] > 0 and before["deck_count"] <= 1:
            counter.fire("kanifous_reveal_recycle")
        if int(player.kanifous_invokes_this_round) > before["invokes"]:
            counter.fire("kanifous_invoke")
        if not before["high"] and player.kanifous_invoked_high:
            counter.fire("kanifous_high_invoke")

    wrap("_kanifous_invoke", invoke_pre, invoke_post)

    def consume_pre(game, player, *args, **kwargs):
        return bool(player.kroni_consume_done)

    def consume_post(game, was_done, result, player, *args, **kwargs):
        if not was_done and player.kroni_consume_done:
            counter.fire("kroni_combat_consume")

    wrap("_try_kroni_consume", consume_pre, consume_post)

    def hunt_pre(game, attacker, defender, *args, **kwargs):
        return {
            "defender_alive": bool(defender.alive),
            "attacker_tears": int(attacker.tears),
            "ravenous": bool(attacker.kroni_ravenous_used),
        }

    def hunt_post(game, before, result, attacker, defender, *args, **kwargs):
        if (
            before["defender_alive"]
            and defender.alive
            and int(attacker.tears) == before["attacker_tears"] + 1
        ):
            counter.fire("consume_the_hunt")
        if not before["ravenous"] and attacker.kroni_ravenous_used:
            counter.fire("kroni_ravenous")

    wrap("_resolve_hunt", hunt_pre, hunt_post)

    def siege_pre(game, attacker, *args, **kwargs):
        return {
            "ravenous": bool(attacker.kroni_ravenous_used),
            "deimos_claimed": bool(attacker.deimos_breach_claimed),
        }

    def siege_post(game, before, result, attacker, *args, **kwargs):
        if not before["ravenous"] and attacker.kroni_ravenous_used:
            counter.fire("kroni_ravenous")
        if not before["deimos_claimed"] and attacker.deimos_breach_claimed:
            counter.fire("deimos_claim_the_breach")

    wrap("_resolve_siege", siege_pre, siege_post)

    def vessel_pre(game, player, *args, **kwargs):
        return bool(player.vessel_used)

    def vessel_post(game, was_used, result, player, *args, **kwargs):
        if not was_used and player.vessel_used:
            counter.fire("vessel_offer")

    wrap("_ai_offer_vessel", vessel_pre, vessel_post)

    def reflex_pre(game, player_id, *args, **kwargs):
        return {
            "eligible": (
                game.breach == "Odradek"
                and int(game.breach_owner) >= 0
                and int(game.breach_owner) != int(player_id)
            ),
            "triggers": int(game.stat_breach_triggers),
        }

    def reflex_post(game, before, result, *args, **kwargs):
        delta = int(game.stat_breach_triggers) - before["triggers"]
        if before["eligible"] and delta > 0:
            counter.fire("odradek_paradox_steal", delta)

    wrap("_resolve_reflex_action", reflex_pre, reflex_post)

    def harvest_pre(game, *args, **kwargs):
        return {
            player.pid: bool(player.gremory_veil_draw_done)
            for player in game.players
        }

    def harvest_post(game, before, result, *args, **kwargs):
        for player in game.players:
            if (
                not before.get(player.pid, True)
                and player.gremory_veil_draw_done
            ):
                counter.fire("gremory_ruinous_harvest")

    wrap("_gremory_ruinous_harvest", harvest_pre, harvest_post)

    def rites_pre(game, player, *args, **kwargs):
        return {
            "cataclysmic": bool(player.cataclysmic_used),
            "profane_ruins": bool(player.profane_ruins_used_this_round),
        }

    def rites_post(game, before, result, player, *args, **kwargs):
        if not before["cataclysmic"] and player.cataclysmic_used:
            counter.fire("cataclysmic_invocation")
        if not before["profane_ruins"] and player.profane_ruins_used_this_round:
            counter.fire("profane_the_ruins")

    wrap("_ai_dominion_rites", rites_pre, rites_post)

    def profane_pre(game, player, opponent, *args, **kwargs):
        return {
            "pending": str(player.pending_profane),
            "profane_this_round": bool(player.profane_this_round),
            "fresh_blocker": "fresh" in opponent.sigils.values(),
        }

    def profane_post(game, before, result, player, *args, **kwargs):
        if (
            before["fresh_blocker"]
            and before["pending"]
            and not player.pending_profane
        ):
            counter.fire("profane_blocked_by_fresh_sigil")
        if (
            not before["profane_this_round"]
            and player.profane_this_round
        ):
            counter.fire("profane_commitment_success")

    wrap("_resolve_profane", profane_pre, profane_post)

    def resolution_pre(game, *args, **kwargs):
        return {
            "humbaba_tolls": int(game.stat_humbaba_tolls),
            "gremory_done": {
                player.pid: bool(player.gremory_inevitable_ruin_done)
                for player in game.players
            },
            "odradek": {
                player.pid: {
                    "alive": bool(player.alive),
                    "tokens": int(player.odradek_reconfig_tokens),
                    "tears": int(player.tears),
                }
                for player in game.players
                if player.lord == "Odradek"
            },
        }

    def resolution_post(game, before, result, *args, **kwargs):
        toll_delta = int(game.stat_humbaba_tolls) - before["humbaba_tolls"]
        if toll_delta > 0:
            counter.fire("humbaba_toll", toll_delta)

        for player in game.players:
            if (
                not before["gremory_done"].get(player.pid, True)
                and player.gremory_inevitable_ruin_done
            ):
                counter.fire("gremory_inevitable_ruin")

            odradek_before = before["odradek"].get(player.pid)
            if odradek_before is None or player.lord != "Odradek":
                continue

            needed = int(gm.sim.VARIANT["reconfig_tokens_needed"])
            if (
                odradek_before["alive"]
                and player.alive
                and odradek_before["tokens"] == needed - 1
                and int(player.odradek_reconfig_tokens) == 0
                and int(player.tears) > odradek_before["tears"]
            ):
                counter.fire("odradek_reconfiguration_tear")

    wrap("_phase_resolution", resolution_pre, resolution_post)


def exact_seeds(master_seed: int, seed_start: int, seed_count: int) -> list[int]:
    return soak.deterministic_seeds(
        master_seed,
        seed_start + seed_count,
    )[seed_start:seed_start + seed_count]


def play_case(case: Case) -> tuple[str, str]:
    gm.apply_config(
        gm.de_v2_variant(),
        gm.de_v2_constants(),
    )
    random.seed(case.seed)
    game = gm.sim.Game(
        [case.player_zero_lord],
        [case.player_one_lord],
    )
    snapshots = gm._play_game_with_round_snapshots(game)
    return gm.gs.trace_hash(snapshots), str(game.win_by)


def iter_cases(
    master_seed: int,
    seed_start: int,
    seed_count: int,
):
    seeds = exact_seeds(master_seed, seed_start, seed_count)
    for relative_index, seed in enumerate(seeds):
        seed_index = seed_start + relative_index
        for player_zero_lord in matrix.LORDS:
            for player_one_lord in matrix.LORDS:
                yield Case(
                    seed_index,
                    seed,
                    player_zero_lord,
                    player_one_lord,
                )


def greedy_cover(counter: Counter) -> list[tuple[int, set[str]]]:
    universe = {
        event
        for event in TRACKED_EVENTS
        if counter.event_counts[event] > 0
    }
    events_by_seed: defaultdict[int, set[str]] = defaultdict(set)
    seed_indexes: dict[int, int] = {}
    for event in universe:
        for case in counter.cases_hitting[event]:
            events_by_seed[case.seed].add(event)
            seed_indexes[case.seed] = case.seed_index

    uncovered = set(universe)
    selected: list[tuple[int, set[str]]] = []
    while uncovered:
        seed, covered = max(
            (
                (seed, events & uncovered)
                for seed, events in events_by_seed.items()
            ),
            key=lambda item: (
                len(item[1]),
                -seed_indexes[item[0]],
            ),
        )
        if not covered:
            break
        selected.append((seed, set(covered)))
        uncovered -= covered
    return selected


def report(counter: Counter) -> tuple[list[str], list[str]]:
    zero: list[str] = []
    thin: list[str] = []
    print()
    print(
        f"{'tracked semantic event':<38} "
        f"{'fires':>8} {'games':>8} {'seeds':>8}  first exact case"
    )
    print("-" * 106)
    for event in TRACKED_EVENTS:
        event_count = counter.event_counts[event]
        cases = sorted(counter.cases_hitting[event])
        seed_count = len(counter.seeds_hitting[event])
        if event_count == 0:
            zero.append(event)
        elif seed_count <= 2:
            thin.append(event)

        if cases:
            first = cases[0]
            first_text = (
                f"index={first.seed_index} seed={first.seed} "
                f"{first.matchup}"
            )
        else:
            first_text = "-"
        print(
            f"{event:<38} {event_count:>8,} {len(cases):>8,} "
            f"{seed_count:>8,}  {first_text}"
        )

    print()
    if zero:
        print("ZERO tracked events: " + ", ".join(zero))
    if thin:
        print("THIN tracked events (<=2 seeds): " + ", ".join(thin))
    if not zero and not thin:
        print("All tracked semantic events fired across at least three seeds.")

    cover = greedy_cover(counter)
    if cover:
        print("\nGreedy seed cover for the tracked events:")
        for seed, events in cover:
            print(f"  seed {seed}: {', '.join(sorted(events))}")
    return zero, thin


def manifest(
    counter: Counter,
    master_seed: int,
    seed_start: int,
    seed_count: int,
) -> dict[str, Any]:
    cover_rows = []
    for seed, events in greedy_cover(counter):
        event_cases = {}
        seed_index = None
        for event in sorted(events):
            matching = sorted(
                case
                for case in counter.cases_hitting[event]
                if case.seed == seed
            )
            if not matching:
                raise RuntimeError(
                    f"Coverage manifest lost {event} for seed {seed}"
                )
            seed_index = matching[0].seed_index
            event_cases[event] = matching[0].as_dict()
        cover_rows.append(
            {
                "seed_index": seed_index,
                "seed": seed,
                "events": event_cases,
            }
        )

    return {
        "format_version": 1,
        "scope": "tracked parity-sensitive semantic events",
        "exhaustive_control_flow_coverage": False,
        "sim_version": gm.SIM_VERSION,
        "ai_version": gm.AI_VERSION,
        "master_seed": master_seed,
        "seed_start": seed_start,
        "seed_count": seed_count,
        "seeds": exact_seeds(master_seed, seed_start, seed_count),
        "ordered_matchups_per_seed": len(matrix.LORDS) ** 2,
        "tracked_events": list(TRACKED_EVENTS),
        "events": {
            event: {
                "fire_count": counter.event_counts[event],
                "game_count": len(counter.cases_hitting[event]),
                "seed_count": len(counter.seeds_hitting[event]),
                "first_case": (
                    sorted(counter.cases_hitting[event])[0].as_dict()
                    if counter.cases_hitting[event]
                    else None
                ),
            }
            for event in TRACKED_EVENTS
        },
        "greedy_cover": cover_rows,
    }


def run_audit(args) -> int:
    cases = list(
        iter_cases(
            args.master_seed,
            args.seed_start,
            args.seed_count,
        )
    )
    counter = Counter()

    # Establish one uninstrumented trace before installing wrappers.
    counter.enabled = False
    baseline_hash, _ = play_case(cases[0])
    install_instrument(counter)
    instrumented_hash, _ = play_case(cases[0])
    if baseline_hash != instrumented_hash:
        raise RuntimeError(
            "Instrumentation perturbed the self-check trace: "
            f"want={baseline_hash} got={instrumented_hash}"
        )
    counter.clear()
    counter.enabled = True

    print(
        "Auditing exact soak lineage: "
        f"master_seed={args.master_seed} "
        f"seed_indexes={args.seed_start}.."
        f"{args.seed_start + args.seed_count - 1} "
        f"games={len(cases):,}"
    )
    print("Instrumentation self-check: trace hash unchanged.")

    win_conditions: defaultdict[str, int] = defaultdict(int)
    for position, case in enumerate(cases, 1):
        counter.current_case = case
        _, win_by = play_case(case)
        win_conditions[win_by] += 1
        if position % (len(matrix.LORDS) ** 2) == 0:
            completed_seeds = position // (len(matrix.LORDS) ** 2)
            print(
                f"PASS coverage seed index {case.seed_index} "
                f"({completed_seeds}/{args.seed_count})"
            )

    zero, thin = report(counter)
    print("\nWin-condition distribution:")
    for win_by, count in sorted(
        win_conditions.items(),
        key=lambda item: (-item[1], item[0]),
    ):
        print(f"  {win_by or '<empty>':<16} {count:>8,}")

    if args.output:
        output_path = Path(args.output)
        output_path.write_text(
            json.dumps(
                manifest(
                    counter,
                    args.master_seed,
                    args.seed_start,
                    args.seed_count,
                ),
                indent=2,
                sort_keys=True,
            )
            + "\n",
            encoding="utf-8",
            newline="\n",
        )
        print(f"\nWrote coverage manifest: {output_path}")

    return 1 if zero else 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--master-seed", type=int, default=20260719)
    parser.add_argument("--seed-start", type=int, default=0)
    parser.add_argument("--seed-count", type=int, default=100)
    parser.add_argument("--output")
    args = parser.parse_args()
    if args.seed_start < 0:
        parser.error("--seed-start must be at least zero")
    if args.seed_count <= 0:
        parser.error("--seed-count must be positive")
    return args


if __name__ == "__main__":
    raise SystemExit(run_audit(parse_args()))
