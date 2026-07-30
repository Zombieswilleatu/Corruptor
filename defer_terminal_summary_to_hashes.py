#!/usr/bin/env python3
"""Let checkpoint hashes locate drift before terminal summary checks."""

from __future__ import annotations

import os
from pathlib import Path
import sys


PATH = Path("Scripts/Sim/LordMatrixTests.gd")
START_MARKER = "var terminal_failure: String = ("
END_MARKER = "return terminal_result"
INSTALLED_MARKER = "Terminal summary comparison is deferred to checkpoint hashes."


def leading_whitespace(line: str) -> str:
    return line[: len(line) - len(line.lstrip())]


def patch(text: str) -> str:
    if INSTALLED_MARKER in text:
        raise RuntimeError("REFUSED: terminal summary is already deferred")

    lines = text.splitlines(keepends=True)
    starts = [
        index
        for index, line in enumerate(lines)
        if line.strip() == START_MARKER
    ]
    ends = [
        index
        for index, line in enumerate(lines)
        if line.strip() == END_MARKER
    ]

    if len(starts) != 1 or len(ends) != 1:
        raise RuntimeError(
            "REFUSED: terminal diagnostic block markers were not unique "
            f"(starts={len(starts)}, ends={len(ends)})"
        )

    start = starts[0]
    end = ends[0]

    if start >= end:
        raise RuntimeError("REFUSED: terminal diagnostic block order is invalid")

    block = "".join(lines[start : end + 1])

    required = [
        "_terminal_failure(",
        "if not terminal_failure.is_empty():",
        'terminal_result["actual_snapshot"] = snapshots.back()',
    ]

    missing = [marker for marker in required if marker not in block]

    if missing:
        raise RuntimeError(
            "REFUSED: terminal diagnostic block shape was not recognized; "
            f"missing={missing}"
        )

    indent = leading_whitespace(lines[start])
    replacement = [
        indent
        + "# Terminal summary comparison is deferred to checkpoint hashes.\n",
        indent
        + "# This preserves the earliest round/state divergence as the failure.\n",
    ]

    stop = end + 1

    if stop < len(lines) and lines[stop].strip() == "":
        stop += 1

    lines[start:stop] = replacement
    updated = "".join(lines)

    if START_MARKER in updated or END_MARKER in updated:
        raise RuntimeError("REFUSED: terminal diagnostic block removal was incomplete")

    return updated


def main() -> int:
    if not PATH.is_file():
        raise RuntimeError(f"REFUSED: missing required file: {PATH}")

    data = PATH.read_bytes()
    newline = "\r\n" if b"\r\n" in data else "\n"
    text = data.decode("utf-8").replace("\r\n", "\n")
    updated = patch(text)
    temporary = PATH.with_name(PATH.name + ".defer_terminal.tmp")

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

    print("Deferred terminal summary validation to checkpoint hash comparison.")
    print("The next failure will identify the earliest divergent round.")
    print("No simulation, oracle, golden file, retained batch, or Git ref was changed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
