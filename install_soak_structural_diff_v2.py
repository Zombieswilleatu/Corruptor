#!/usr/bin/env python3
"""Whitespace-independent wrapper for install_soak_structural_diff.py."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import sys


BASE_PATH = Path(__file__).with_name("install_soak_structural_diff.py")


def load_base():
    if not BASE_PATH.is_file():
        raise RuntimeError(f"REFUSED: missing original installer: {BASE_PATH}")

    spec = importlib.util.spec_from_file_location(
        "soak_structural_diff_base",
        BASE_PATH,
    )
    if spec is None or spec.loader is None:
        raise RuntimeError("REFUSED: unable to load original installer")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


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


def patch_matrix(text: str) -> str:
    if 'hash_failure["actual_snapshot"]' in text:
        raise RuntimeError("REFUSED: actual-snapshot reporting already installed")

    lines = text.splitlines(keepends=True)
    conditions = [
        index
        for index, line in enumerate(lines)
        if line.strip() == "if expected_hash != actual_hash:"
    ]
    if len(conditions) != 1:
        raise RuntimeError(
            "REFUSED: expected one matrix hash condition, "
            f"found {len(conditions)}"
        )

    condition_index = conditions[0]
    return_indexes = [
        index
        for index in range(condition_index + 1, len(lines))
        if lines[index].strip() == "return _fail("
    ]
    if not return_indexes:
        raise RuntimeError("REFUSED: matrix hash condition has no _fail return")

    return_index = return_indexes[0]
    call_end = balanced_call_end(lines, return_index)
    condition_indent = leading_whitespace(lines[condition_index])
    child_indent = leading_whitespace(lines[return_index])

    if not child_indent.startswith(condition_indent):
        raise RuntimeError("REFUSED: invalid matrix hash-block indentation")

    newline = "\r\n" if lines[return_index].endswith("\r\n") else "\n"
    lines[return_index] = (
        child_indent
        + "var hash_failure: Dictionary = _fail("
        + newline
    )
    lines[call_end + 1:call_end + 1] = [
        newline,
        child_indent + 'hash_failure["checkpoint"] = actual_checkpoint' + newline,
        child_indent + 'hash_failure["actual_snapshot"] = actual_snapshot' + newline,
        newline,
        child_indent + "return hash_failure" + newline,
    ]
    return "".join(lines)


def patch_runner(text: str) -> str:
    if "terminal-round structural differences:" in text:
        raise RuntimeError("REFUSED: soak structural diff already installed")

    lines = text.splitlines(keepends=True)
    messages = [
        index
        for index, line in enumerate(lines)
        if '"expected terminal snapshot: %s"' in line
    ]
    if len(messages) != 1:
        raise RuntimeError(
            "REFUSED: expected one soak terminal-snapshot message, "
            f"found {len(messages)}"
        )

    message_index = messages[0]
    print_start = next(
        (
            index
            for index in range(message_index - 1, -1, -1)
            if lines[index].strip() == "print("
        ),
        -1,
    )
    if print_start < 0:
        raise RuntimeError("REFUSED: terminal-snapshot print start not found")

    print_end = balanced_call_end(lines, print_start)
    base = leading_whitespace(lines[print_start])
    message_indent = leading_whitespace(lines[message_index])

    if not message_indent.startswith(base):
        raise RuntimeError("REFUSED: invalid soak report indentation")
    unit = message_indent[len(base):]
    if not unit:
        raise RuntimeError("REFUSED: empty soak indentation unit")

    generated: list[str] = []

    def add(level: int = 0, value: str = "") -> None:
        if value:
            generated.append(base + unit * level + value + "\n")
        else:
            generated.append("\n")

    add(0, "var expected_terminal_raw = scenario.get(")
    add(1, '"terminal_snapshot",')
    add(1, "{}")
    add(0, ")")
    add(0, "var actual_snapshot_raw = result.get(")
    add(1, '"actual_snapshot",')
    add(1, "{}")
    add(0, ")")
    add()
    add(0, "if (")
    add(1, "typeof(expected_terminal_raw) == TYPE_DICTIONARY")
    add(1, "and typeof(actual_snapshot_raw) == TYPE_DICTIONARY")
    add(0, "):")
    add(1, "var expected_terminal: Dictionary = expected_terminal_raw")
    add(1, "var actual_snapshot: Dictionary = actual_snapshot_raw")
    add()
    add(1, "if (")
    add(2, 'int(actual_snapshot.get("round", -1))')
    add(2, '== int(scenario.get("round", -2))')
    add(1, "):")
    add(2, "var expected_checkpoint: Dictionary = expected_terminal.duplicate(true)")
    add(2, 'expected_checkpoint["checkpoint"] = String(')
    add(3, 'actual_snapshot.get("checkpoint", "")')
    add(2, ")")
    add()
    add(2, "var divergences: Array[Dictionary] = (")
    add(3, "GoldenMasterData._all_divergences(")
    add(4, "[expected_checkpoint],")
    add(4, "[actual_snapshot],")
    add(4, "32")
    add(3, ")")
    add(2, ")")
    add()
    add(2, 'print("terminal-round structural differences:")')
    add()
    add(2, "if divergences.is_empty():")
    add(3, 'print("  none (hash-only serialization difference)")')
    add(2, "else:")
    add(3, "for divergence: Dictionary in divergences:")
    add(4, "print(")
    add(5, '"  %s expected=%s actual=%s"')
    add(5, "% [")
    add(6, 'String(divergence.get("field", "?")),')
    add(6, 'str(divergence.get("want", "<missing>")),')
    add(6, 'str(divergence.get("got", "<missing>")),')
    add(5, "]")
    add(4, ")")
    add(1, "else:")
    add(2, "print(")
    add(3, '"actual checkpoint snapshot: %s"')
    add(3, '% JSON.stringify(actual_snapshot, "", true)')
    add(2, ")")
    add()
    add(0, "print(")
    add(1, '"expected terminal snapshot: %s"')
    add(1, '% JSON.stringify(expected_terminal_raw, "", true)')
    add(0, ")")

    lines[print_start:print_end + 1] = generated
    return "".join(lines)


def main() -> int:
    base = load_base()
    base.patch_matrix = patch_matrix
    base.patch_runner = patch_runner
    return int(base.main())


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
