#!/usr/bin/env python3
"""Store a sealed Profane target at Godot's Commitment boundary."""

from __future__ import annotations

import os
from pathlib import Path
import re
import sys


PATH = Path("Scripts/Sim/CommitmentEngine.gd")
MARKER = "Profane targets are sealed during Commitment"


def _replace_once(
    text: str,
    pattern: re.Pattern[str],
    replacement,
    description: str,
) -> str:
    updated, count = pattern.subn(replacement, text)

    if count != 1:
        raise RuntimeError(
            f"REFUSED: expected {description} exactly once, found {count}"
        )

    return updated


def patch(text: str) -> str:
    if MARKER in text:
        raise RuntimeError(
            "REFUSED: Profane commitment-target timing fix is already installed"
        )

    unit_pattern = re.compile(
        r'^static func _validate_commitment\(\n'
        r'(?P<unit>[ \t]+)game,\n',
        re.MULTILINE,
    )
    unit_matches = list(unit_pattern.finditer(text))

    if len(unit_matches) != 1:
        raise RuntimeError(
            "REFUSED: expected _validate_commitment indentation boundary "
            f"exactly once, found {len(unit_matches)}"
        )

    unit = unit_matches[0].group("unit")

    assignment_pattern = re.compile(
        r'^(?P<indent>[ \t]+)'
        r'# Specific Siege and Profane Castles are chosen after Reveal\.\n'
        r'(?P=indent)player\.last_sieged_castle = ""\n'
        r'(?P=indent)player\.pending_profane = ""',
        re.MULTILINE,
    )

    def replace_assignment(match: re.Match[str]) -> str:
        indent = match.group("indent")
        deep = indent + unit
        deeper = deep + unit
        return (
            f"{indent}# Siege target state is recorded only if that action resolves.\n"
            f"{indent}player.last_sieged_castle = \"\"\n"
            f"{indent}# {MARKER}, matching Python.\n"
            f"{indent}player.pending_profane = String(\n"
            f"{deep}plan.get(\n"
            f'{deeper}"pending_profane",\n'
            f'{deeper}""\n'
            f"{deep})\n"
            f"{indent})"
        )

    text = _replace_once(
        text,
        assignment_pattern,
        replace_assignment,
        "Commitment target reset block",
    )

    declaration_pattern = re.compile(
        r'^(?P<indent>[ \t]+)var target_type: String = ""\n'
        r'(?P=indent)var ward_target: String = ""$',
        re.MULTILINE,
    )

    def replace_declarations(match: re.Match[str]) -> str:
        indent = match.group("indent")
        return (
            f'{indent}var target_type: String = ""\n'
            f'{indent}var ward_target: String = ""\n'
            f'{indent}var pending_profane: String = ""'
        )

    text = _replace_once(
        text,
        declaration_pattern,
        replace_declarations,
        "Commitment target-variable block",
    )

    cards_pattern = re.compile(
        r'^(?P<indent>[ \t]+)var raw_cards = decision\.get\($',
        re.MULTILINE,
    )

    def insert_profane_target(match: re.Match[str]) -> str:
        indent = match.group("indent")
        deep = indent + unit
        deeper = deep + unit
        deepest = deeper + unit
        return (
            f"{indent}if action_name == ACTION_PROFANE:\n"
            f"{deep}var requested_profane: String = String(\n"
            f"{deeper}decision.get(\n"
            f'{deepest}"target_castle",\n'
            f'{deepest}""\n'
            f"{deeper})\n"
            f"{deep})\n\n"
            f"{deep}if player.castles.has(\n"
            f"{deeper}requested_profane\n"
            f"{deep}):\n"
            f"{deeper}pending_profane = requested_profane\n\n"
            + match.group(0)
        )

    text = _replace_once(
        text,
        cards_pattern,
        insert_profane_target,
        "raw Commitment card-selection boundary",
    )

    result_pattern = re.compile(
        r'^(?P<indent>[ \t]+)"ward_target": ward_target,\n'
        r'(?P=indent)"cards": selection\.get\($',
        re.MULTILINE,
    )

    def add_result_field(match: re.Match[str]) -> str:
        indent = match.group("indent")
        return (
            f'{indent}"ward_target": ward_target,\n'
            f'{indent}"pending_profane": pending_profane,\n'
            f'{indent}"cards": selection.get('
        )

    text = _replace_once(
        text,
        result_pattern,
        add_result_field,
        "validated Commitment result boundary",
    )

    if text.count(MARKER) != 1:
        raise RuntimeError(
            "REFUSED: transformed source did not contain exactly one fix marker"
        )

    return text


def main() -> int:
    if not PATH.is_file():
        raise RuntimeError(f"REFUSED: missing required file: {PATH}")

    data = PATH.read_bytes()
    newline = "\r\n" if b"\r\n" in data else "\n"
    text = data.decode("utf-8").replace("\r\n", "\n")
    updated = patch(text)
    temporary = PATH.with_name(PATH.name + ".profane_timing.tmp")

    if temporary.exists():
        raise RuntimeError(
            f"REFUSED: temporary path already exists: {temporary}"
        )

    try:
        temporary.write_bytes(
            updated.replace("\n", newline).encode("utf-8")
        )
        os.replace(temporary, PATH)
    finally:
        if temporary.exists():
            temporary.unlink()

    print("Stored sealed Profane targets during Godot Commitment.")
    print(
        "Python oracle, golden data, retained batch, and Git refs "
        "were unchanged."
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
