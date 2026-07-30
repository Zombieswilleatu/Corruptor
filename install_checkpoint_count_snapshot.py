#!/usr/bin/env python3
"""Attach Godot's last snapshot to matrix checkpoint-count failures."""

from __future__ import annotations

import os
from pathlib import Path
import re
import sys


PATH = Path("Scripts/Sim/LordMatrixTests.gd")
FIX_MARKER = "Preserve the last actual snapshot when checkpoint counts differ"


def patch(text: str) -> str:
    if FIX_MARKER in text:
        raise RuntimeError(
            "REFUSED: checkpoint-count snapshot reporting is already installed"
        )

    start_pattern = re.compile(
        r"^(?P<indent>[ \t]+)if expected_checkpoints\.size\(\) "
        r"!= snapshots\.size\(\):$",
        re.MULTILINE,
    )
    starts = list(start_pattern.finditer(text))

    if len(starts) != 1:
        raise RuntimeError(
            "REFUSED: expected the checkpoint-count branch once, "
            f"found {len(starts)}"
        )

    match = starts[0]
    indent = match.group("indent")
    next_loop_pattern = re.compile(
        rf"^{re.escape(indent)}for index: int in range\($",
        re.MULTILINE,
    )
    loops = [
        candidate
        for candidate in next_loop_pattern.finditer(text, match.end())
    ]

    if not loops:
        raise RuntimeError(
            "REFUSED: could not find the checkpoint comparison loop"
        )

    block_end = loops[0].start()
    old_block = text[match.start():block_end]
    required_counts = {
        "return _fail(": 1,
        '"Checkpoint count mismatch: want=%d got=%d"': 1,
        "expected_checkpoints.size()": 2,
        "snapshots.size()": 2,
    }

    for fragment, expected_count in required_counts.items():
        if old_block.count(fragment) != expected_count:
            raise RuntimeError(
                "REFUSED: unexpected checkpoint-count branch; "
                f"expected {fragment!r} {expected_count} time(s), found "
                f"{old_block.count(fragment)}"
            )

    deep = indent + indent
    deeper = deep + indent
    deepest = deeper + indent
    replacement = (
        f"{indent}if expected_checkpoints.size() != snapshots.size():\n"
        f"{deep}# {FIX_MARKER}.\n"
        f"{deep}var count_result: Dictionary = _fail(\n"
        f"{deeper}scenario_name,\n"
        f'{deeper}"Checkpoint count mismatch: want=%d got=%d"\n'
        f"{deeper}% [\n"
        f"{deepest}expected_checkpoints.size(),\n"
        f"{deepest}snapshots.size(),\n"
        f"{deeper}]\n"
        f"{deep})\n\n"
        f"{deep}if not snapshots.is_empty():\n"
        f"{deeper}var actual_terminal: Dictionary = snapshots[\n"
        f"{deepest}snapshots.size() - 1\n"
        f"{deeper}]\n\n"
        f'{deeper}count_result["checkpoint"] = String(\n'
        f"{deepest}actual_terminal.get(\n"
        f'{deepest + indent}"checkpoint",\n'
        f'{deepest + indent}""\n'
        f"{deepest})\n"
        f"{deeper})\n\n"
        f'{deeper}count_result["actual_snapshot"] = actual_terminal\n\n'
        f"{deep}return count_result\n\n"
    )

    return text[:match.start()] + replacement + text[block_end:]


def main() -> int:
    if not PATH.is_file():
        raise RuntimeError(f"REFUSED: missing required file: {PATH}")

    original = PATH.read_bytes()
    newline = "\r\n" if b"\r\n" in original else "\n"
    text = original.decode("utf-8").replace("\r\n", "\n")
    updated = patch(text).replace("\n", newline).encode("utf-8")
    temporary = PATH.with_name(PATH.name + ".count_snapshot.tmp")

    if temporary.exists():
        raise RuntimeError(
            f"REFUSED: temporary path already exists: {temporary}"
        )

    try:
        temporary.write_bytes(updated)
        os.replace(temporary, PATH)
    finally:
        if temporary.exists():
            temporary.unlink()

    print("Installed actual-snapshot reporting for checkpoint-count failures.")
    print("No simulation, oracle, golden data, soak batch, or Git ref was changed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
