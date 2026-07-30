#!/usr/bin/env python3
"""Fix aftermath winner re-evaluation and remove the temporary phase probe."""

from __future__ import annotations

import os
from pathlib import Path
import re
import sys


AFTERMATH_PATH = Path(
    "Scripts/Sim/ResolutionActionAftermathEngine.gd"
)
ROUND_PATH = Path("Scripts/Sim/BotRoundEngine.gd")
PROBE_MARKER = "DEBUG SOAK KRONI KANIFOUS R8"


def _remove_phase_probe(text: str) -> str:
    if text.count(PROBE_MARKER) != 2:
        raise RuntimeError(
            "REFUSED: expected the temporary phase-probe marker twice, "
            f"found {text.count(PROBE_MARKER)}"
        )

    boundary_pattern = re.compile(
        r'^(?P<header>static func _finish_round\(\n'
        r'[ \t]*game,\n'
        r'[ \t]*phase_results: Dictionary,\n'
        r'[ \t]*events: Array\[Dictionary\],\n'
        r'[ \t]*completed: bool,\n'
        r'[ \t]*stopped_phase: String\n'
        r'\) -> Dictionary:\n)'
        r'(?P<body>[\s\S]*?)'
        r'^(?P<indent>[ \t]+)return \{',
        re.MULTILINE,
    )
    matches = list(boundary_pattern.finditer(text))

    if len(matches) != 1:
        raise RuntimeError(
            "REFUSED: expected _finish_round boundary exactly once, "
            f"found {len(matches)}"
        )

    match = matches[0]
    indent = match.group("indent")
    deep = indent + indent
    expected_probe = (
        f'{indent}if (\n'
        f'{deep}int(game.round) == 8\n'
        f'{deep}and game.players.size() == 2\n'
        f'{deep}and String(game.players[0].lord) == "Kroni"\n'
        f'{deep}and String(game.players[1].lord) == "Kanifous"\n'
        f'{deep}and int(game.winner) >= 0\n'
        f'{deep}and String(game.win_by) == "Dominion"\n'
        f'{indent}):\n'
        f'{deep}print(\n'
        f'{deep}{indent}"{PROBE_MARKER} stopped_phase=%s winner=%d win_by=%s"\n'
        f'{deep}{indent}% [\n'
        f'{deep}{deep}stopped_phase,\n'
        f'{deep}{deep}int(game.winner),\n'
        f'{deep}{deep}String(game.win_by),\n'
        f'{deep}{indent}]\n'
        f'{deep})\n'
        f'{deep}print(\n'
        f'{deep}{indent}"{PROBE_MARKER} PHASE_RESULTS %s"\n'
        f'{deep}{indent}% str(phase_results)\n'
        f'{deep})\n\n'
    )

    if match.group("body") != expected_probe:
        raise RuntimeError(
            "REFUSED: _finish_round contains unexpected text around "
            "the temporary phase probe"
        )

    return (
        text[: match.start()]
        + match.group("header")
        + indent
        + "return {"
        + text[match.end() :]
    )


def _fix_aftermath_check(text: str) -> str:
    comment_marker = (
        "Kroni's action can provisionally win before aftermath Soul gains."
    )

    if comment_marker in text:
        raise RuntimeError(
            "REFUSED: aftermath winner re-evaluation fix is already installed"
        )

    pattern = re.compile(
        r'^(?P<header>static func _check_win\(\n'
        r'(?P<indent>[ \t]+)game,\n'
        r'(?P=indent)rules: RuleConfig\n'
        r'\) -> bool:\n)'
        r'(?P=indent)if int\(\n'
        r'(?P<deep>[ \t]+)game\.winner\n'
        r'(?P=indent)\) >= 0:\n'
        r'(?P=deep)return true\n\n',
        re.MULTILINE,
    )
    matches = list(pattern.finditer(text))

    if len(matches) != 1:
        raise RuntimeError(
            "REFUSED: expected the aftermath stale-winner guard exactly "
            f"once, found {len(matches)}"
        )

    match = matches[0]
    indent = match.group("indent")
    replacement = (
        match.group("header")
        + indent
        + "# Kroni's action can provisionally win before aftermath Soul gains.\n"
        + indent
        + "# Re-evaluate so Ritual-first priority can replace that label.\n"
    )

    return text[: match.start()] + replacement + text[match.end() :]


def _read_normalized(path: Path) -> tuple[bytes, str, str]:
    if not path.is_file():
        raise RuntimeError(f"REFUSED: missing required file: {path}")

    data = path.read_bytes()
    newline = "\r\n" if b"\r\n" in data else "\n"
    text = data.decode("utf-8").replace("\r\n", "\n")
    return data, newline, text


def _write_transaction(updates: list[tuple[Path, bytes]]) -> None:
    staged: list[tuple[Path, Path, bytes]] = []

    for path, updated in updates:
        temporary = path.with_name(path.name + ".aftermath_fix.tmp")

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
            rollback = path.with_name(path.name + ".aftermath_rollback.tmp")
            rollback.write_bytes(original)
            os.replace(rollback, path)
        raise
    finally:
        for _, temporary, _ in staged:
            if temporary.exists():
                temporary.unlink()


def main() -> int:
    _, aftermath_newline, aftermath_text = _read_normalized(
        AFTERMATH_PATH
    )
    _, round_newline, round_text = _read_normalized(ROUND_PATH)

    updated_aftermath = _fix_aftermath_check(aftermath_text)
    updated_round = _remove_phase_probe(round_text)

    _write_transaction([
        (
            AFTERMATH_PATH,
            updated_aftermath.replace(
                "\n",
                aftermath_newline,
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

    print("Fixed aftermath winner re-evaluation.")
    print("Removed temporary Kroni-vs-Kanifous phase probe.")
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
