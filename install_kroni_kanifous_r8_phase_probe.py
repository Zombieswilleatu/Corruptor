#!/usr/bin/env python3
"""Install a temporary phase probe for Kroni-vs-Kanifous round 8."""

from __future__ import annotations

import os
from pathlib import Path
import re
import sys


PATH = Path("Scripts/Sim/BotRoundEngine.gd")
MARKER = "DEBUG SOAK KRONI KANIFOUS R8"


def patch(text: str) -> str:
    if MARKER in text:
        raise RuntimeError("REFUSED: round-8 phase probe is already installed")

    pattern = re.compile(
        r'^(?P<header>static func _finish_round\(\n'
        r'[ \t]*game,\n'
        r'[ \t]*phase_results: Dictionary,\n'
        r'[ \t]*events: Array\[Dictionary\],\n'
        r'[ \t]*completed: bool,\n'
        r'[ \t]*stopped_phase: String\n'
        r'\) -> Dictionary:\n)'
        r'(?P<indent>[ \t]*)return \{',
        re.MULTILINE,
    )
    matches = list(pattern.finditer(text))

    if len(matches) != 1:
        raise RuntimeError(
            "REFUSED: expected _finish_round boundary exactly once, "
            f"found {len(matches)}"
        )

    match = matches[0]
    indent = match.group("indent")

    if not indent:
        raise RuntimeError("REFUSED: could not infer function-body indentation")

    deep = indent + indent
    probe = (
        f'{indent}if (\n'
        f'{deep}int(game.round) == 8\n'
        f'{deep}and game.players.size() == 2\n'
        f'{deep}and String(game.players[0].lord) == "Kroni"\n'
        f'{deep}and String(game.players[1].lord) == "Kanifous"\n'
        f'{deep}and int(game.winner) >= 0\n'
        f'{deep}and String(game.win_by) == "Dominion"\n'
        f'{indent}):\n'
        f'{deep}print(\n'
        f'{deep}{indent}"{MARKER} stopped_phase=%s winner=%d win_by=%s"\n'
        f'{deep}{indent}% [\n'
        f'{deep}{deep}stopped_phase,\n'
        f'{deep}{deep}int(game.winner),\n'
        f'{deep}{deep}String(game.win_by),\n'
        f'{deep}{indent}]\n'
        f'{deep})\n'
        f'{deep}print(\n'
        f'{deep}{indent}"{MARKER} PHASE_RESULTS %s"\n'
        f'{deep}{indent}% str(phase_results)\n'
        f'{deep})\n\n'
    )
    replacement = match.group("header") + probe + indent + "return {"

    return text[: match.start()] + replacement + text[match.end() :]


def main() -> int:
    if not PATH.is_file():
        raise RuntimeError(f"REFUSED: missing required file: {PATH}")

    data = PATH.read_bytes()
    newline = "\r\n" if b"\r\n" in data else "\n"
    text = data.decode("utf-8").replace("\r\n", "\n")
    updated = patch(text)
    temporary = PATH.with_name(PATH.name + ".phase_probe.tmp")

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

    print("Installed temporary Kroni-vs-Kanifous round-8 phase probe.")
    print("Simulation behavior, Python oracle, golden data, and Git refs were unchanged.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
