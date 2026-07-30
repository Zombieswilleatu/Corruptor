#!/usr/bin/env python3
"""Simplify terminal snapshot attachment for Godot 4.2 parsing."""

from __future__ import annotations

import os
from pathlib import Path
import sys


PATH = Path("Scripts/Sim/LordMatrixTests.gd")
OLD_MARKER = 'terminal_result["actual_snapshot"] = actual_terminal'
NEW_MARKER = 'terminal_result["actual_snapshot"] = snapshots.back()'


def leading_whitespace(line: str) -> str:
    return line[: len(line) - len(line.lstrip())]


def patch(text: str) -> str:
    if NEW_MARKER in text:
        raise RuntimeError("REFUSED: simplified terminal attachment is already installed")

    if text.count(OLD_MARKER) != 1:
        raise RuntimeError(
            "REFUSED: expected one typed terminal attachment, "
            f"found {text.count(OLD_MARKER)}"
        )

    lines = text.splitlines(keepends=True)
    marker = next(
        index
        for index, line in enumerate(lines)
        if OLD_MARKER in line
    )
    if_starts = [
        index
        for index in range(marker - 1, max(-1, marker - 30), -1)
        if lines[index].strip() == "if not snapshots.is_empty():"
    ]

    if len(if_starts) != 1:
        raise RuntimeError(
            "REFUSED: expected one snapshot guard before attachment, "
            f"found {len(if_starts)}"
        )

    if_start = if_starts[0]
    returns = [
        index
        for index in range(marker + 1, min(len(lines), marker + 10))
        if lines[index].strip() == "return terminal_result"
    ]

    if len(returns) != 1:
        raise RuntimeError(
            "REFUSED: expected one terminal-result return, "
            f"found {len(returns)}"
        )

    return_index = returns[0]
    indent = leading_whitespace(lines[return_index])
    if_indent = leading_whitespace(lines[if_start])

    if indent != if_indent:
        raise RuntimeError("REFUSED: snapshot guard and return indentation differ")

    old_block = "".join(lines[if_start:return_index])

    if (
        'terminal_result["checkpoint"]' not in old_block
        or "actual_terminal" not in old_block
    ):
        raise RuntimeError("REFUSED: terminal attachment block was not recognized")

    replacement = [
        indent + 'terminal_result["checkpoint"] = "game:end"\n',
        indent + 'terminal_result["actual_snapshot"] = snapshots.back()\n',
        "\n",
    ]
    lines[if_start:return_index] = replacement
    updated = "".join(lines)

    if OLD_MARKER in updated or "var actual_terminal" in updated:
        raise RuntimeError("REFUSED: typed terminal attachment removal was incomplete")

    return updated


def main() -> int:
    if not PATH.is_file():
        raise RuntimeError(f"REFUSED: missing required file: {PATH}")

    data = PATH.read_bytes()
    newline = "\r\n" if b"\r\n" in data else "\n"
    text = data.decode("utf-8").replace("\r\n", "\n")
    updated = patch(text)
    temporary = PATH.with_name(PATH.name + ".terminal_parser.tmp")

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

    print("Simplified terminal snapshot attachment for Godot 4.2.")
    print("Preserved the Reveal timing fix and structural-diff diagnostics.")
    print("No simulation, oracle, golden file, retained batch, or Git ref was changed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
