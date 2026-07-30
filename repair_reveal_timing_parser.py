#!/usr/bin/env python3
"""Remove the failed inline timing regression while preserving the sim fix."""

from __future__ import annotations

import os
from pathlib import Path
import sys


PATH = Path("Scripts/Sim/LordMatrixTests.gd")
TEST_NAME = "_test_kanifous_reveal_terminal_timing"
CONSTANT_NAME = "REVEAL_TERMINAL_TIMING_TEST_NAME"


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


def remove_regression(text: str) -> str:
    if CONSTANT_NAME not in text or TEST_NAME not in text:
        raise RuntimeError("REFUSED: inline Reveal timing regression was not found")

    lines = text.splitlines(keepends=True)

    constant_starts = [
        index
        for index, line in enumerate(lines)
        if line.strip().startswith(
            "const REVEAL_TERMINAL_TIMING_TEST_NAME:"
        )
    ]
    constant_ends = [
        index
        for index, line in enumerate(lines)
        if line.strip().startswith(
            "const REVEAL_TERMINAL_TIMING_ROUND:"
        )
    ]

    if len(constant_starts) != 1 or len(constant_ends) != 1:
        raise RuntimeError("REFUSED: timing constant block was not unique")

    constant_start = constant_starts[0]
    constant_end = constant_ends[0]

    if constant_start >= constant_end:
        raise RuntimeError("REFUSED: timing constant block order is invalid")

    # Consume one following blank line, but leave the pre-existing blank line
    # before the block intact.
    constant_stop = constant_end + 1
    if (
        constant_stop < len(lines)
        and lines[constant_stop].strip() == ""
    ):
        constant_stop += 1

    del lines[constant_start:constant_stop]

    function_starts = [
        index
        for index, line in enumerate(lines)
        if line.strip() == f"static func {TEST_NAME}("
    ]
    scenario_starts = [
        index
        for index, line in enumerate(lines)
        if line.strip() == "static func _run_scenario("
    ]

    if len(function_starts) != 1 or len(scenario_starts) != 1:
        raise RuntimeError("REFUSED: timing/scenario function markers were not unique")

    function_start = function_starts[0]
    scenario_start = scenario_starts[0]

    if function_start >= scenario_start:
        raise RuntimeError("REFUSED: timing function block order is invalid")

    del lines[function_start:scenario_start]

    call_lines = [
        index
        for index, line in enumerate(lines)
        if (
            line.strip() == f"{TEST_NAME}("
            and not line.strip().startswith("static func")
        )
    ]

    if len(call_lines) != 1:
        raise RuntimeError(
            "REFUSED: expected one timing regression call, "
            f"found {len(call_lines)}"
        )

    call_line = call_lines[0]
    append_starts = [
        index
        for index in range(call_line - 1, max(-1, call_line - 8), -1)
        if lines[index].strip() == "results.append("
    ]

    if len(append_starts) != 1:
        raise RuntimeError("REFUSED: timing regression append block was not found")

    append_start = append_starts[0]
    append_end = balanced_call_end(lines, append_start)
    append_block = "".join(lines[append_start : append_end + 1])

    if TEST_NAME not in append_block or "rules" not in append_block:
        raise RuntimeError("REFUSED: timing regression append block was not recognized")

    append_stop = append_end + 1
    if append_stop < len(lines) and lines[append_stop].strip() == "":
        append_stop += 1

    del lines[append_start:append_stop]
    updated = "".join(lines)

    if CONSTANT_NAME in updated or TEST_NAME in updated:
        raise RuntimeError("REFUSED: timing regression removal was incomplete")

    return updated


def main() -> int:
    if not PATH.is_file():
        raise RuntimeError(f"REFUSED: missing required file: {PATH}")

    round_engine_path = Path("Scripts/Sim/BotRoundEngine.gd")

    if not round_engine_path.is_file():
        raise RuntimeError(
            f"REFUSED: missing required file: {round_engine_path}"
        )

    round_engine = round_engine_path.read_text(encoding="utf-8")

    if "Python oracle timing: Reveal mutations" not in round_engine:
        raise RuntimeError("REFUSED: BotRoundEngine parity fix is not installed")

    data = PATH.read_bytes()
    newline = "\r\n" if b"\r\n" in data else "\n"
    text = data.decode("utf-8").replace("\r\n", "\n")
    updated = remove_regression(text)
    temporary = PATH.with_name(PATH.name + ".parser_repair.tmp")

    if temporary.exists():
        raise RuntimeError(f"REFUSED: temporary path already exists: {temporary}")

    try:
        temporary.write_bytes(
            updated.replace("\n", newline).encode("utf-8")
        )
        os.replace(temporary, PATH)
    finally:
        if temporary.exists():
            temporary.unlink()

    print("Removed failed inline Reveal timing regression from LordMatrixTests.gd.")
    print("Preserved the BotRoundEngine Reveal victory-timing parity fix.")
    print("No Python oracle, golden file, retained batch, or Git ref was changed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
