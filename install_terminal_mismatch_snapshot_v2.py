#!/usr/bin/env python3
"""Indentation-aware wrapper for terminal mismatch snapshot reporting."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import sys


BASE_PATH = Path(__file__).with_name(
    "install_terminal_mismatch_snapshot.py"
)


def load_base():
    if not BASE_PATH.is_file():
        raise RuntimeError(f"REFUSED: missing original installer: {BASE_PATH}")

    spec = importlib.util.spec_from_file_location(
        "terminal_mismatch_snapshot_base",
        BASE_PATH,
    )

    if spec is None or spec.loader is None:
        raise RuntimeError("REFUSED: unable to load original installer")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def patch(text: str) -> str:
    if 'terminal_result["actual_snapshot"]' in text:
        raise RuntimeError(
            "REFUSED: terminal mismatch snapshot is already installed"
        )

    base = load_base()
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
    return_start = -1

    for index in range(condition + 1, len(lines)):
        if not lines[index].strip():
            continue

        if lines[index].strip() != "return _fail(":
            raise RuntimeError(
                "REFUSED: first terminal-failure statement is not _fail"
            )

        return_start = index
        break

    if return_start < 0:
        raise RuntimeError("REFUSED: terminal-failure return was not found")

    condition_indent = base.leading_whitespace(lines[condition])
    indent = base.leading_whitespace(lines[return_start])

    if (
        not indent.startswith(condition_indent)
        or len(indent) <= len(condition_indent)
    ):
        raise RuntimeError("REFUSED: terminal-failure return indentation is invalid")

    return_end = base.balanced_call_end(lines, return_start)
    old_block = "".join(lines[return_start : return_end + 1])

    if "scenario_name" not in old_block or "terminal_failure" not in old_block:
        raise RuntimeError(
            "REFUSED: terminal-failure return shape was not recognized"
        )

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
    base = load_base()
    base.patch = patch
    return int(base.main())


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
