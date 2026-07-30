#!/usr/bin/env python3
"""Move Vessel reevaluation after Kroni Consume and remove its temp probe."""

from __future__ import annotations

import os
from pathlib import Path
import re
import sys


PATH = Path("Scripts/Sim/ResolutionActionAftermathEngine.gd")
PROBE_MARKER = "DEBUG SOAK DEIMOS KRONI R9 VESSEL"
FIX_MARKER = "Python reevaluates Vessel after action aftermath and Kroni Consume"


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
            f'{deeper}"{PROBE_MARKER} BEFORE winner=%d win_by=%s veil=%d neutral=%d breach=%s decision=%s validation=%s action_result=%s kroni_events=%s players=%s"',
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
            f'{deeper}"{PROBE_MARKER} AFTER winner=%d win_by=%s veil=%d neutral=%d breach=%s event=%s players=%s"',
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


def _remove_probe(text: str) -> tuple[str, str]:
    if text.count(PROBE_MARKER) != 2:
        raise RuntimeError(
            "REFUSED: expected the temporary Vessel probe marker twice, "
            f"found {text.count(PROBE_MARKER)}"
        )

    boundary = re.compile(
        r"^(?P<indent>[ \t]+)var vessel_event: Dictionary = \($",
        re.MULTILINE,
    )
    matches = list(boundary.finditer(text))

    if len(matches) != 1:
        raise RuntimeError(
            "REFUSED: expected the Vessel resolution boundary exactly once, "
            f"found {len(matches)}"
        )

    indent = matches[0].group("indent")
    before_probe = _debug_block(indent, "BEFORE")
    after_probe = _debug_block(indent, "AFTER")

    if text.count(before_probe) != 1:
        raise RuntimeError(
            "REFUSED: temporary pre-Vessel probe does not match exactly"
        )

    if text.count(after_probe) != 1:
        raise RuntimeError(
            "REFUSED: temporary post-Vessel probe does not match exactly"
        )

    cleaned = text.replace(before_probe, "", 1)
    cleaned = cleaned.replace(after_probe, "", 1)
    return cleaned, indent


def _move_reevaluation(text: str, indent: str) -> str:
    if FIX_MARKER in text:
        raise RuntimeError(
            "REFUSED: Vessel-after-Consume timing fix is already installed"
        )

    start_pattern = re.compile(
        rf"^{re.escape(indent)}var effective_vessel_decision: Dictionary = \($",
        re.MULTILINE,
    )
    start_matches = list(start_pattern.finditer(text))

    if len(start_matches) != 1:
        raise RuntimeError(
            "REFUSED: expected the early Vessel reevaluation block once, "
            f"found {len(start_matches)}"
        )

    end_pattern = re.compile(
        rf"^{re.escape(indent)}var destruction_recorded: bool = \($",
        re.MULTILINE,
    )
    end_matches = list(end_pattern.finditer(text))

    if len(end_matches) != 1:
        raise RuntimeError(
            "REFUSED: expected the destruction boundary once, "
            f"found {len(end_matches)}"
        )

    start = start_matches[0].start()
    end = end_matches[0].start()

    if start >= end:
        raise RuntimeError(
            "REFUSED: Vessel reevaluation is not before destruction handling"
        )

    decision_block = text[start:end]

    required_fragments = [
        "_post_action_vessel_decision(",
        '"reevaluate_after_action"',
        "var vessel_validation: Dictionary = (",
        "_validate_vessel_decision(",
        '"invalid_vessel_decision"',
    ]

    for fragment in required_fragments:
        if decision_block.count(fragment) != 1:
            raise RuntimeError(
                "REFUSED: unexpected Vessel reevaluation block; "
                f"expected {fragment!r} once, found "
                f"{decision_block.count(fragment)}"
            )

    old_comment = (
        f"{indent}{indent}# Hunt/Siege engines may already have recorded Ritual. Python's\n"
        f"{indent}{indent}# golden order evaluates Vessel before that victory checkpoint.\n"
    )
    new_comment = (
        f"{indent}{indent}# {FIX_MARKER},\n"
        f"{indent}{indent}# before the next victory checkpoint.\n"
    )

    if decision_block.count(old_comment) != 1:
        raise RuntimeError(
            "REFUSED: expected the existing Vessel timing comment once, "
            f"found {decision_block.count(old_comment)}"
        )

    moved_block = decision_block.replace(
        old_comment,
        new_comment,
        1,
    )
    without_early = text[:start] + text[end:]

    vessel_pattern = re.compile(
        rf"^{re.escape(indent)}var vessel_event: Dictionary = \($",
        re.MULTILINE,
    )
    vessel_matches = list(vessel_pattern.finditer(without_early))

    if len(vessel_matches) != 1:
        raise RuntimeError(
            "REFUSED: expected the cleaned Vessel resolution boundary once, "
            f"found {len(vessel_matches)}"
        )

    insert_at = vessel_matches[0].start()
    return (
        without_early[:insert_at]
        + moved_block
        + without_early[insert_at:]
    )


def main() -> int:
    if not PATH.is_file():
        raise RuntimeError(f"REFUSED: missing required file: {PATH}")

    data = PATH.read_bytes()
    newline = "\r\n" if b"\r\n" in data else "\n"
    text = data.decode("utf-8").replace("\r\n", "\n")
    cleaned, indent = _remove_probe(text)
    updated = _move_reevaluation(cleaned, indent)
    temporary = PATH.with_name(PATH.name + ".vessel_timing_fix.tmp")

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

    print("Moved Vessel reevaluation after action aftermath and Kroni Consume.")
    print("Removed temporary Deimos-vs-Kroni Vessel probe.")
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
