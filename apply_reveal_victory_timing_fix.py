#!/usr/bin/env python3
"""Align Godot Kanifous Reveal victory timing with the Python oracle."""

from __future__ import annotations

import os
from pathlib import Path
import sys


ROUND_ENGINE_PATH = Path("Scripts/Sim/BotRoundEngine.gd")
MATRIX_TESTS_PATH = Path("Scripts/Sim/LordMatrixTests.gd")

ROUND_MARKER = "# Kanifous can place a Tear or gain a Soul during Reveal."
TEST_MARKER = "REVEAL_TERMINAL_TIMING_TEST_NAME"


def read(path: Path) -> tuple[str, str]:
    data = path.read_bytes()
    newline = "\r\n" if b"\r\n" in data else "\n"
    return data.decode("utf-8").replace("\r\n", "\n"), newline


def leading_whitespace(line: str) -> str:
    return line[: len(line) - len(line.lstrip())]


def balanced_call_end(lines: list[str], start: int) -> int:
    balance = 0
    began = False

    for index in range(start, len(lines)):
        balance += lines[index].count("(")
        balance -= lines[index].count(")")
        began = began or "(" in lines[index]

        if began and balance == 0:
            return index

    raise RuntimeError("REFUSED: could not find the end of a call block")


def patch_round_engine(text: str) -> str:
    if "Python oracle timing: Reveal mutations" in text:
        raise RuntimeError("REFUSED: Reveal victory-timing fix is already installed")

    lines = text.splitlines(keepends=True)
    markers = [
        index
        for index, line in enumerate(lines)
        if line.strip() == ROUND_MARKER
    ]

    if len(markers) != 1:
        raise RuntimeError(
            "REFUSED: expected one Kanifous Reveal win-check marker, "
            f"found {len(markers)}"
        )

    marker = markers[0]
    check_starts = [
        index
        for index in range(marker + 1, min(len(lines), marker + 20))
        if lines[index].strip() == "_check_win("
    ]

    if len(check_starts) != 1:
        raise RuntimeError(
            "REFUSED: expected one post-Reveal _check_win call, "
            f"found {len(check_starts)}"
        )

    check_start = check_starts[0]
    check_end = balanced_call_end(lines, check_start)
    return_starts = [
        index
        for index in range(check_end + 1, min(len(lines), check_end + 30))
        if lines[index].strip() == "return _finish_round("
    ]

    if len(return_starts) != 1:
        raise RuntimeError(
            "REFUSED: expected one post-Reveal early return, "
            f"found {len(return_starts)}"
        )

    return_start = return_starts[0]
    return_end = balanced_call_end(lines, return_start)
    old_block = "".join(lines[marker : return_end + 1])

    if '"reveal"' not in old_block or "game.winner" not in old_block:
        raise RuntimeError("REFUSED: post-Reveal block shape was not recognized")

    indent = leading_whitespace(lines[marker])
    replacement = [
        indent
        + "# Python oracle timing: Reveal mutations are not a victory checkpoint.\n",
        indent
        + "# Resolution begins before Kanifous Reveal gains are checked for victory.\n",
    ]

    lines[marker : return_end + 1] = replacement
    return "".join(lines)


def timing_test_source() -> str:
    return '''static func _test_kanifous_reveal_terminal_timing(
        rules: RuleConfig
) -> Dictionary:
        var setup: Dictionary = (
                SeededGameSetupData.setup_locked_game(
                        "Valak",
                        "Kanifous",
                        REVEAL_TERMINAL_TIMING_SEED,
                        rules
                )
        )

        var game = setup.get(
                "game"
        )

        var random_source = setup.get(
                "rng"
        )

        if (
                game == null
                or random_source == null
        ):
                return _fail(
                        REVEAL_TERMINAL_TIMING_TEST_NAME,
                        "Seeded timing setup returned no game or RNG."
                )

        var round_eight_result: Dictionary = {}

        for round_number: int in range(
                1,
                REVEAL_TERMINAL_TIMING_ROUND + 1
        ):
                var round_result: Dictionary = (
                        BotRoundEngineData.resolve_round(
                                game,
                                rules,
                                random_source,
                                round_number,
                                BotPolicyData.golden_core()
                        )
                )

                if String(
                        round_result.get(
                                "action",
                                ""
                        )
                ) == "invalid":
                        return _fail(
                                REVEAL_TERMINAL_TIMING_TEST_NAME,
                                "Timing fixture became invalid in round %d: %s"
                                % [
                                        round_number,
                                        String(
                                                round_result.get(
                                                        "reason",
                                                        ""
                                                )
                                        ),
                                ]
                        )

                if round_number < REVEAL_TERMINAL_TIMING_ROUND:
                        if int(
                                game.winner
                        ) >= 0:
                                return _fail(
                                        REVEAL_TERMINAL_TIMING_TEST_NAME,
                                        "Timing fixture ended before round eight."
                                )

                        continue

                round_eight_result = round_result

        var phases_raw = round_eight_result.get(
                "phases",
                {}
        )

        if typeof(
                phases_raw
        ) != TYPE_DICTIONARY:
                return _fail(
                        REVEAL_TERMINAL_TIMING_TEST_NAME,
                        "Round-eight phases are not a Dictionary."
                )

        var phases: Dictionary = phases_raw

        if not phases.has(
                "resolution"
        ):
                return _fail(
                        REVEAL_TERMINAL_TIMING_TEST_NAME,
                        "Final Collapse during Kanifous Reveal skipped Resolution."
                )

        if String(
                round_eight_result.get(
                        "stopped_phase",
                        ""
                )
        ) != "resolution":
                return _fail(
                        REVEAL_TERMINAL_TIMING_TEST_NAME,
                        "Timing fixture did not become terminal during Resolution."
                )

        if (
                int(
                        game.winner
                ) != 1
                or String(
                        game.win_by
                ) != "FinalCollapse"
        ):
                return _fail(
                        REVEAL_TERMINAL_TIMING_TEST_NAME,
                        "Timing fixture recorded the wrong terminal result."
                )

        var valak = game.get_player(
                0
        )

        var kanifous = game.get_player(
                1
        )

        if (
                valak == null
                or kanifous == null
        ):
                return _fail(
                        REVEAL_TERMINAL_TIMING_TEST_NAME,
                        "Timing fixture players are missing."
                )

        if not valak.lord_guards.is_empty():
                return _fail(
                        REVEAL_TERMINAL_TIMING_TEST_NAME,
                        "Resolution Prelude did not discard Valak's three Lord Guards."
                )

        if not bool(
                kanifous.was_hunted
        ):
                return _fail(
                        REVEAL_TERMINAL_TIMING_TEST_NAME,
                        "Valak's committed Hunt did not resolve before Final Collapse."
                )

        return _pass(
                REVEAL_TERMINAL_TIMING_TEST_NAME
        )


'''


def patch_matrix_tests(text: str) -> str:
    if TEST_MARKER in text:
        raise RuntimeError("REFUSED: Reveal timing regression is already installed")

    lines = text.splitlines(keepends=True)
    count_lines = [
        index
        for index, line in enumerate(lines)
        if line.strip() == "const EXPECTED_SCENARIO_COUNT: int = 81"
    ]

    if len(count_lines) != 1:
        raise RuntimeError(
            "REFUSED: expected one matrix scenario-count constant, "
            f"found {len(count_lines)}"
        )

    count_index = count_lines[0]
    constants = '''
const REVEAL_TERMINAL_TIMING_TEST_NAME: String = (
        "unit_kanifous_reveal_terminal_timing"
)

const REVEAL_TERMINAL_TIMING_SEED: int = 2052353491
const REVEAL_TERMINAL_TIMING_ROUND: int = 8
'''
    lines[count_index + 1 : count_index + 1] = [constants]
    text_with_constants = "".join(lines)
    lines = text_with_constants.splitlines(keepends=True)

    run_starts = [
        index
        for index, line in enumerate(lines)
        if line.strip() == "static func run("
    ]
    scenario_starts = [
        index
        for index, line in enumerate(lines)
        if line.strip() == "static func _run_scenario("
    ]

    if len(run_starts) != 1 or len(scenario_starts) != 1:
        raise RuntimeError(
            "REFUSED: matrix run/scenario function markers were not unique"
        )

    run_start = run_starts[0]
    scenario_start = scenario_starts[0]
    returns = [
        index
        for index in range(run_start, scenario_start)
        if lines[index].strip() == "return results"
    ]

    if len(returns) != 1:
        raise RuntimeError(
            "REFUSED: expected one matrix run return, "
            f"found {len(returns)}"
        )

    return_index = returns[0]
    indent = leading_whitespace(lines[return_index])
    child = indent + "        "
    append_block = [
        indent + "results.append(\n",
        child + "_test_kanifous_reveal_terminal_timing(\n",
        child + "        rules\n",
        child + ")\n",
        indent + ")\n",
        "\n",
    ]
    lines[return_index:return_index] = append_block

    scenario_start = next(
        index
        for index, line in enumerate(lines)
        if line.strip() == "static func _run_scenario("
    )
    lines[scenario_start:scenario_start] = [timing_test_source()]
    return "".join(lines)


def main() -> int:
    for path in (ROUND_ENGINE_PATH, MATRIX_TESTS_PATH):
        if not path.is_file():
            raise RuntimeError(f"REFUSED: missing required file: {path}")

    round_engine, round_newline = read(ROUND_ENGINE_PATH)
    matrix_tests, matrix_newline = read(MATRIX_TESTS_PATH)

    updates = {
        ROUND_ENGINE_PATH: (
            patch_round_engine(round_engine),
            round_newline,
        ),
        MATRIX_TESTS_PATH: (
            patch_matrix_tests(matrix_tests),
            matrix_newline,
        ),
    }
    temporaries: dict[Path, Path] = {}

    try:
        for path, (content, newline) in updates.items():
            temporary = path.with_name(path.name + ".reveal_timing.tmp")

            if temporary.exists():
                raise RuntimeError(
                    f"REFUSED: temporary path already exists: {temporary}"
                )

            temporary.write_bytes(
                content.replace("\n", newline).encode("utf-8")
            )
            temporaries[path] = temporary

        for path, temporary in temporaries.items():
            os.replace(temporary, path)
    finally:
        for temporary in temporaries.values():
            if temporary.exists():
                temporary.unlink()

    print("Applied Godot Kanifous Reveal victory-timing parity fix.")
    print("Added permanent seeded regression for Valak vs Kanifous seed 2052353491.")
    print("No Python oracle, golden file, retained batch, or Git ref was changed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
