#!/usr/bin/env python3
"""Report the earliest shared checkpoint divergence before a count mismatch."""

from __future__ import annotations

import os
from pathlib import Path
import re
import sys


PATH = Path("Scripts/Sim/LordMatrixTests.gd")
COUNT_MARKER = "Preserve the last actual snapshot when checkpoint counts differ"
FIX_MARKER = "Compare the shared checkpoint prefix before reporting its length"


def patch(text: str) -> str:
    if FIX_MARKER in text:
        raise RuntimeError(
            "REFUSED: common-prefix checkpoint diagnostics are already installed"
        )

    if text.count(COUNT_MARKER) != 1:
        raise RuntimeError(
            "REFUSED: expected the count-snapshot diagnostic marker once, "
            f"found {text.count(COUNT_MARKER)}"
        )

    pattern = re.compile(
        r"^(?P<indent>[ \t]+)if expected_checkpoints\.size\(\) "
        r"!= snapshots\.size\(\):$",
        re.MULTILINE,
    )
    matches = list(pattern.finditer(text))

    if len(matches) != 1:
        raise RuntimeError(
            "REFUSED: expected the checkpoint-count branch once, "
            f"found {len(matches)}"
        )

    match = matches[0]
    line_end = text.index("\n", match.end()) + 1
    indent = match.group("indent")
    deep = indent + indent
    deeper = deep + indent
    deepest = deeper + indent
    level_five = deepest + indent
    level_six = level_five + indent

    block = (
        f"{deep}# {FIX_MARKER}.\n"
        f"{deep}var shared_count: int = min(\n"
        f"{deeper}expected_checkpoints.size(),\n"
        f"{deeper}snapshots.size()\n"
        f"{deep})\n\n"
        f"{deep}for shared_index: int in range(\n"
        f"{deeper}shared_count\n"
        f"{deep}):\n"
        f"{deeper}var shared_expected_raw = expected_checkpoints[\n"
        f"{deepest}shared_index\n"
        f"{deeper}]\n\n"
        f"{deeper}if typeof(shared_expected_raw) != TYPE_DICTIONARY:\n"
        f"{deepest}continue\n\n"
        f"{deeper}var shared_expected: Dictionary = shared_expected_raw\n"
        f"{deeper}var shared_actual: Dictionary = snapshots[\n"
        f"{deepest}shared_index\n"
        f"{deeper}]\n"
        f"{deeper}var shared_checkpoint: String = String(\n"
        f"{deepest}shared_actual.get(\n"
        f'{level_five}"checkpoint",\n'
        f'{level_five}""\n'
        f"{deepest})\n"
        f"{deeper})\n"
        f"{deeper}var shared_expected_checkpoint: String = String(\n"
        f"{deepest}shared_expected.get(\n"
        f'{level_five}"checkpoint",\n'
        f'{level_five}""\n'
        f"{deepest})\n"
        f"{deeper})\n\n"
        f"{deeper}if shared_expected_checkpoint != shared_checkpoint:\n"
        f"{deepest}var name_result: Dictionary = _fail(\n"
        f"{level_five}scenario_name,\n"
        f'{level_five}"Checkpoint name mismatch at index %d: want=%s got=%s"\n'
        f"{level_five}% [\n"
        f"{level_six}shared_index,\n"
        f"{level_six}shared_expected_checkpoint,\n"
        f"{level_six}shared_checkpoint,\n"
        f"{level_five}]\n"
        f"{deepest})\n"
        f'{deepest}name_result["checkpoint"] = shared_checkpoint\n'
        f'{deepest}name_result["actual_snapshot"] = shared_actual\n'
        f"{deepest}return name_result\n\n"
        f"{deeper}var shared_expected_hash: String = String(\n"
        f"{deepest}shared_expected.get(\n"
        f'{level_five}"hash",\n'
        f'{level_five}""\n'
        f"{deepest})\n"
        f"{deeper})\n"
        f"{deeper}var shared_actual_hash: String = (\n"
        f"{deepest}GoldenMasterData.trace_hash([\n"
        f"{level_five}shared_actual,\n"
        f"{deepest}])\n"
        f"{deeper})\n\n"
        f"{deeper}if shared_expected_hash != shared_actual_hash:\n"
        f"{deepest}var hash_result: Dictionary = _fail(\n"
        f"{level_five}scenario_name,\n"
        f'{level_five}"State hash divergence at %s: want=%s got=%s"\n'
        f"{level_five}% [\n"
        f"{level_six}shared_checkpoint,\n"
        f"{level_six}shared_expected_hash.left(16),\n"
        f"{level_six}shared_actual_hash.left(16),\n"
        f"{level_five}]\n"
        f"{deepest})\n"
        f'{deepest}hash_result["checkpoint"] = shared_checkpoint\n'
        f'{deepest}hash_result["actual_snapshot"] = shared_actual\n'
        f"{deepest}return hash_result\n\n"
    )

    return text[:line_end] + block + text[line_end:]


def main() -> int:
    if not PATH.is_file():
        raise RuntimeError(f"REFUSED: missing required file: {PATH}")

    original = PATH.read_bytes()
    newline = "\r\n" if b"\r\n" in original else "\n"
    text = original.decode("utf-8").replace("\r\n", "\n")
    updated = patch(text).replace("\n", newline).encode("utf-8")
    temporary = PATH.with_name(PATH.name + ".prefix_diff.tmp")

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

    print("Installed earliest shared-checkpoint reporting for count failures.")
    print("No simulation, oracle, golden data, soak batch, or Git ref was changed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
