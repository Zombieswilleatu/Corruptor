#!/usr/bin/env python3
"""Install a temporary compact phase probe for Valak-vs-Kanifous round 8."""

from __future__ import annotations

import os
from pathlib import Path
import re
import sys


PATH = Path("Scripts/Sim/BotRoundEngine.gd")
MARKER = "DEBUG SOAK VALAK KANIFOUS R8"


def patch(text: str) -> str:
    if MARKER in text:
        raise RuntimeError("REFUSED: round-8 phase probe is already installed")

    pattern = re.compile(
        r'^(?P<header>static func _append_event\(\n'
        r'[ \t]*events: Array\[Dictionary\],\n'
        r'[ \t]*game,\n'
        r'[ \t]*phase_name: String,\n'
        r'[ \t]*data\n'
        r'\) -> void:\n)'
        r'(?P<indent>[ \t]+)events\.append\(\{',
        re.MULTILINE,
    )
    matches = list(pattern.finditer(text))

    if len(matches) != 1:
        raise RuntimeError(
            "REFUSED: expected _append_event boundary exactly once, "
            f"found {len(matches)}"
        )

    match = matches[0]
    indent = match.group("indent")
    deep = indent + indent
    deeper = deep + indent
    probe = (
        f'{indent}if (\n'
        f'{deep}int(game.round) == 8\n'
        f'{deep}and game.players.size() == 2\n'
        f'{deep}and String(game.players[0].lord) == "Valak"\n'
        f'{deep}and String(game.players[1].lord) == "Kanifous"\n'
        f'{deep}and int(game.first_player) == 0\n'
        f'{indent}):\n'
        f'{deep}var debug_players: Array[Dictionary] = []\n\n'
        f'{deep}for debug_player in game.players:\n'
        f'{deeper}debug_players.append({{\n'
        f'{deeper}{indent}"pid": int(debug_player.pid),\n'
        f'{deeper}{indent}"action": String(debug_player.action),\n'
        f'{deeper}{indent}"alive": bool(debug_player.alive),\n'
        f'{deeper}{indent}"souls": int(debug_player.souls),\n'
        f'{deeper}{indent}"tears": int(debug_player.tears),\n'
        f'{deeper}{indent}"threat": int(debug_player.threat),\n'
        f'{deeper}{indent}"committed": debug_player.committed.size(),\n'
        f'{deeper}{indent}"hand": debug_player.hand.size(),\n'
        f'{deeper}{indent}"cataclysmic": bool(debug_player.cataclysmic_used),\n'
        f'{deeper}}})\n\n'
        f'{deep}print(\n'
        f'{deeper}"{MARKER} phase=%s winner=%d win_by=%s veil=%d neutral=%d breach=%s players=%s"\n'
        f'{deeper}% [\n'
        f'{deeper}{indent}phase_name,\n'
        f'{deeper}{indent}int(game.winner),\n'
        f'{deeper}{indent}String(game.win_by),\n'
        f'{deeper}{indent}int(game.calculate_veil_total()),\n'
        f'{deeper}{indent}int(game.neutral_tears),\n'
        f'{deeper}{indent}String(game.breach),\n'
        f'{deeper}{indent}str(debug_players),\n'
        f'{deeper}]\n'
        f'{deep})\n\n'
    )
    replacement = (
        match.group("header")
        + probe
        + indent
        + "events.append({"
    )

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

    print("Installed temporary Valak-vs-Kanifous round-8 phase probe.")
    print(
        "Simulation behavior, Python oracle, golden data, and Git refs "
        "were unchanged."
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
