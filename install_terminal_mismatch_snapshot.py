#!/usr/bin/env python3
"""Attach Godot's terminal snapshot when Lord-matrix summary checks fail."""

from __future__ import annotations

import os
from pathlib import Path
import sys


PATH = Path("Scripts/Sim/LordMatrixTests.gd")
INSTALLED_MARKER = 'terminal_result["actual_snapshot"]'


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


def patch(text: str) -> str:
    if INSTALLED_MARKER in text:
        raise RuntimeError("REFUSED: terminal mismatch snapshot is already installed")

    lines = text.splitlines(keepends=True)
    conditions = [
        index
        for index, line in enumerate(lines)
        if line.strip() == "if not terminal_failure.is_empty():"
    ]

    if len(conditions) != 1:
        raise RuntimeError(
            "REFUSED: expected one terminal-failure condition, "
            f"found {len(conditions)}"
        )

    condition = conditions[0]
    returns = [
        index
        for index in range(condition + 1, min(len(lines), condition + 20))
        if lines[index].strip() == "return _fail("
    ]

    if len(returns) != 1:
        raise RuntimeError(
            "REFUSED: expected one terminal-failure return, "
            f"found {len(returns)}"
        )

    return_start = returns[0]
    return_end = balanced_call_end(lines, return_start)
    old_block = "".join(lines[return_start : return_end + 1])

    if "scenario_name" not in old_block or "terminal_failure" not in old_block:
        raise RuntimeError("REFUSED: terminal-failure return shape was not recognized")

    indent = leading_whitespace(lines[return_start])
    child = indent + "        "
    grandchild = child + "        "
    replacement = [
        indent + "var terminal_result: Dictionary = _fail(\n",
        child + "scenario_name,\n",
        child + "terminal_failure\n",
        indent + ")\n",
        "\n",
        indent + "if not snapshots.is_empty():\n",
        child + "var actual_terminal: Dictionary = snapshots[\n",
        grandchild + "snapshots.size() - 1\n",
        child + "]\n",
        "\n",
        child + 'terminal_result["checkpoint"] = String(\n',
        grandchild + "actual_terminal.get(\n",
        grandchild + '        "checkpoint",\n',
        grandchild + '        ""\n',
        grandchild + ")\n",
        child + ")\n",
        "\n",
        child + 'terminal_result["actual_snapshot"] = actual_terminal\n',
        "\n",
        indent + "return terminal_result\n",
    ]

    lines[return_start : return_end + 1] = replacement
    return "".join(lines)


def main() -> int:
    if not PATH.is_file():
        raise RuntimeError(f"REFUSED: missing required file: {PATH}")

    data = PATH.read_bytes()
    newline = "\r\n" if b"\r\n" in data else "\n"
    text = data.decode("utf-8").replace("\r\n", "\n")
    updated = patch(text)
    temporary = PATH.with_name(PATH.name + ".terminal_snapshot.tmp")

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

    print("Installed actual terminal-snapshot reporting for summary mismatches.")
    print("No simulation, oracle, golden file, retained batch, or Git ref was changed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
