#!/usr/bin/env python3
"""Match Python Consume doctrine at Final Collapse and remove its phase probe."""

from __future__ import annotations

import os
from pathlib import Path
import re
import sys


DOCTRINE_PATH = Path("Scripts/Sim/BotResolutionDoctrine.gd")
ROUND_PATH = Path("Scripts/Sim/BotRoundEngine.gd")
PROBE_MARKER = "DEBUG SOAK VALAK KANIFOUS R8"
FIX_MARKER = "Python still takes Consume when it triggers Final Collapse"


def _fix_consume_doctrine(text: str) -> str:
    if FIX_MARKER in text:
        raise RuntimeError(
            "REFUSED: Consume Final-Collapse parity fix is already installed"
        )

    pattern = re.compile(
        r'^(?P<indent>[ \t]+)if \(\n'
        r'(?P<deep>[ \t]+)veil_after < rules\.dominion_track\n'
        r'(?P=deep)or veil_after\n'
        r'(?P<deeper>[ \t]+)>= rules\.final_collapse_threshold\n'
        r'(?P=indent)\):\n'
        r'(?P=deep)return false$',
        re.MULTILINE,
    )
    matches = list(pattern.finditer(text))

    if len(matches) != 1:
        raise RuntimeError(
            "REFUSED: expected the Consume veil-range guard exactly once, "
            f"found {len(matches)}"
        )

    match = matches[0]
    indent = match.group("indent")
    deep = match.group("deep")
    replacement = (
        f"{indent}# {FIX_MARKER}; the normal\n"
        f"{indent}# win-priority check then selects the actual winner.\n"
        f"{indent}if veil_after < rules.dominion_track:\n"
        f"{deep}return false"
    )

    return text[: match.start()] + replacement + text[match.end() :]


def _remove_phase_probe(text: str) -> str:
    if text.count(PROBE_MARKER) != 1:
        raise RuntimeError(
            "REFUSED: expected the temporary phase-probe marker once, "
            f"found {text.count(PROBE_MARKER)}"
        )

    boundary_pattern = re.compile(
        r'^(?P<header>static func _append_event\(\n'
        r'[ \t]*events: Array\[Dictionary\],\n'
        r'[ \t]*game,\n'
        r'[ \t]*phase_name: String,\n'
        r'[ \t]*data\n'
        r'\) -> void:\n)'
        r'(?P<body>[\s\S]*?)'
        r'^(?P<indent>[ \t]+)events\.append\(\{',
        re.MULTILINE,
    )
    matches = list(boundary_pattern.finditer(text))

    if len(matches) != 1:
        raise RuntimeError(
            "REFUSED: expected _append_event boundary exactly once, "
            f"found {len(matches)}"
        )

    match = matches[0]
    indent = match.group("indent")
    deep = indent + indent
    deeper = deep + indent
    expected_probe = (
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
        f'{deeper}"{PROBE_MARKER} phase=%s winner=%d win_by=%s veil=%d neutral=%d breach=%s players=%s"\n'
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

    if match.group("body") != expected_probe:
        raise RuntimeError(
            "REFUSED: _append_event contains unexpected text around "
            "the temporary phase probe"
        )

    return (
        text[: match.start()]
        + match.group("header")
        + indent
        + "events.append({"
        + text[match.end() :]
    )


def _read_normalized(path: Path) -> tuple[str, str]:
    if not path.is_file():
        raise RuntimeError(f"REFUSED: missing required file: {path}")

    data = path.read_bytes()
    newline = "\r\n" if b"\r\n" in data else "\n"
    text = data.decode("utf-8").replace("\r\n", "\n")
    return newline, text


def _write_transaction(updates: list[tuple[Path, bytes]]) -> None:
    staged: list[tuple[Path, Path, bytes]] = []

    for path, updated in updates:
        temporary = path.with_name(path.name + ".consume_fix.tmp")

        if temporary.exists():
            raise RuntimeError(
                f"REFUSED: temporary path already exists: {temporary}"
            )

        original = path.read_bytes()
        temporary.write_bytes(updated)
        staged.append((path, temporary, original))

    replaced: list[tuple[Path, bytes]] = []

    try:
        for path, temporary, original in staged:
            os.replace(temporary, path)
            replaced.append((path, original))
    except Exception:
        for path, original in reversed(replaced):
            rollback = path.with_name(path.name + ".consume_rollback.tmp")
            rollback.write_bytes(original)
            os.replace(rollback, path)
        raise
    finally:
        for _, temporary, _ in staged:
            if temporary.exists():
                temporary.unlink()


def main() -> int:
    doctrine_newline, doctrine_text = _read_normalized(DOCTRINE_PATH)
    round_newline, round_text = _read_normalized(ROUND_PATH)

    updated_doctrine = _fix_consume_doctrine(doctrine_text)
    updated_round = _remove_phase_probe(round_text)

    _write_transaction([
        (
            DOCTRINE_PATH,
            updated_doctrine.replace(
                "\n",
                doctrine_newline,
            ).encode("utf-8"),
        ),
        (
            ROUND_PATH,
            updated_round.replace(
                "\n",
                round_newline,
            ).encode("utf-8"),
        ),
    ])

    print("Matched Python Consume doctrine at Final Collapse.")
    print("Removed temporary Valak-vs-Kanifous phase probe.")
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
