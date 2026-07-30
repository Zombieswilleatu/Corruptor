#!/usr/bin/env python3
"""Install a temporary Deimos-vs-Kroni post-Consume Vessel probe."""

from __future__ import annotations

import os
from pathlib import Path
import re
import sys


PATH = Path("Scripts/Sim/ResolutionActionAftermathEngine.gd")
MARKER = "DEBUG SOAK DEIMOS KRONI R9 VESSEL"


def _debug_block(indent: str, stage: str) -> str:
    deep = indent + indent
    deeper = deep + indent
    deepest = deeper + indent
    suffix = stage.lower()
    players_name = f"debug_players_{suffix}"
    player_name = f"debug_player_{suffix}"

    lines = [
        f"{indent}if (",
        f"{deep}int(game.round) == 9",
        f"{deep}and game.players.size() == 2",
        f'{deep}and String(game.players[0].lord) == "Deimos"',
        f'{deep}and String(game.players[1].lord) == "Kroni"',
        f"{deep}and acting_player_id == 1",
        f"{indent}):",
        f"{deep}var {players_name}: Array[Dictionary] = []",
        "",
        f"{deep}for {player_name} in game.players:",
        f"{deeper}{players_name}.append({{",
        f'{deepest}"pid": int({player_name}.pid),',
        f'{deepest}"alive": bool({player_name}.alive),',
        f'{deepest}"souls": int({player_name}.souls),',
        f'{deepest}"tears": int({player_name}.tears),',
        f'{deepest}"threat": int({player_name}.threat),',
        f'{deepest}"lord_def": int({player_name}.derived_lord_def),',
        f'{deepest}"committed": {player_name}.committed.size(),',
        f'{deepest}"hunger": int({player_name}.kroni_hunger),',
        f'{deepest}"consume_done": bool({player_name}.kroni_consume_done),',
        f'{deepest}"milestone": bool({player_name}.kroni_tear_milestone_fired),',
        f'{deepest}"vessel_used": bool({player_name}.vessel_used),',
        f'{deepest}"vessel_offered": String({player_name}.vessel_offered_lord),',
        f"{deeper}}})",
        "",
    ]

    if stage == "BEFORE":
        lines.extend([
            f"{deep}print(",
            f'{deeper}"{MARKER} BEFORE winner=%d win_by=%s veil=%d neutral=%d breach=%s decision=%s validation=%s action_result=%s kroni_events=%s players=%s"',
            f"{deeper}% [",
            f"{deepest}int(game.winner),",
            f"{deepest}String(game.win_by),",
            f"{deepest}int(game.calculate_veil_total()),",
            f"{deepest}int(game.neutral_tears),",
            f"{deepest}String(game.breach),",
            f"{deepest}str(vessel_decision),",
            f"{deepest}str(vessel_validation),",
            f"{deepest}str(action_result),",
            f"{deepest}str(kroni_events),",
            f"{deepest}str({players_name}),",
            f"{deeper}]",
            f"{deep})",
            "",
        ])
    else:
        lines.extend([
            f"{deep}print(",
            f'{deeper}"{MARKER} AFTER winner=%d win_by=%s veil=%d neutral=%d breach=%s event=%s players=%s"',
            f"{deeper}% [",
            f"{deepest}int(game.winner),",
            f"{deepest}String(game.win_by),",
            f"{deepest}int(game.calculate_veil_total()),",
            f"{deepest}int(game.neutral_tears),",
            f"{deepest}String(game.breach),",
            f"{deepest}str(vessel_event),",
            f"{deepest}str({players_name}),",
            f"{deeper}]",
            f"{deep})",
            "",
        ])

    return "\n".join(lines)


def patch(text: str) -> str:
    if MARKER in text:
        raise RuntimeError("REFUSED: Deimos-vs-Kroni Vessel probe is already installed")

    before_pattern = re.compile(
        r"^(?P<indent>[ \t]+)var vessel_event: Dictionary = \($",
        re.MULTILINE,
    )
    before_matches = list(before_pattern.finditer(text))

    if len(before_matches) != 1:
        raise RuntimeError(
            "REFUSED: expected the Vessel resolution boundary exactly once, "
            f"found {len(before_matches)}"
        )

    before_match = before_matches[0]
    indent = before_match.group("indent")
    text = (
        text[: before_match.start()]
        + _debug_block(indent, "BEFORE")
        + before_match.group(0)
        + text[before_match.end() :]
    )

    after_pattern = re.compile(
        r"^(?P<indent>[ \t]+)var won_after_vessel: bool = _check_win\($",
        re.MULTILINE,
    )
    after_matches = list(after_pattern.finditer(text))

    if len(after_matches) != 1:
        raise RuntimeError(
            "REFUSED: expected the post-Vessel victory boundary exactly once, "
            f"found {len(after_matches)}"
        )

    after_match = after_matches[0]

    if after_match.group("indent") != indent:
        raise RuntimeError("REFUSED: Vessel boundary indentation does not match")

    return (
        text[: after_match.start()]
        + _debug_block(indent, "AFTER")
        + after_match.group(0)
        + text[after_match.end() :]
    )


def main() -> int:
    if not PATH.is_file():
        raise RuntimeError(f"REFUSED: missing required file: {PATH}")

    data = PATH.read_bytes()
    newline = "\r\n" if b"\r\n" in data else "\n"
    text = data.decode("utf-8").replace("\r\n", "\n")
    updated = patch(text)
    temporary = PATH.with_name(PATH.name + ".vessel_probe.tmp")

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

    print("Installed temporary Deimos-vs-Kroni Vessel boundary probe.")
    print(
        "Simulation behavior, Python oracle, golden data, retained batch, "
        "and Git refs were unchanged."
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
