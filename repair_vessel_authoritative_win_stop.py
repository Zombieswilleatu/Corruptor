#!/usr/bin/env python3
"""Stop explicit stale Vessel aftermath after an authoritative victory."""

from __future__ import annotations

import os
from pathlib import Path
import re
import sys


PATH = Path("Scripts/Sim/ResolutionActionAftermathEngine.gd")
VALIDATION_MARKER = "Validate the cached Vessel decision before aftermath mutation"
FIX_MARKER = "Explicit cached Vessel decisions cannot reopen an existing victory"


def patch(text: str) -> str:
    if FIX_MARKER in text:
        raise RuntimeError(
            "REFUSED: authoritative-win Vessel stop is already installed"
        )

    if text.count(VALIDATION_MARKER) != 1:
        raise RuntimeError(
            "REFUSED: expected the repaired validation marker once, "
            f"found {text.count(VALIDATION_MARKER)}"
        )

    boundary_pattern = re.compile(
        r"^(?P<indent>[ \t]+)var destruction_recorded: bool = \($",
        re.MULTILINE,
    )
    matches = list(boundary_pattern.finditer(text))

    if len(matches) != 1:
        raise RuntimeError(
            "REFUSED: expected the destruction boundary once, "
            f"found {len(matches)}"
        )

    match = matches[0]
    indent = match.group("indent")
    deep = indent + indent
    deeper = deep + indent
    deepest = deeper + indent

    prefix = text[: match.start()]
    required_before = [
        "var vessel_validation: Dictionary = (",
        "_validate_vessel_decision(",
        '"invalid_vessel_decision"',
    ]

    for fragment in required_before:
        if prefix.count(fragment) != 1:
            raise RuntimeError(
                "REFUSED: unexpected pre-mutation validation shape; "
                f"expected {fragment!r} once before destruction, found "
                f"{prefix.count(fragment)}"
            )

    block = (
        f"{indent}# {FIX_MARKER}.\n"
        f"{indent}if (\n"
        f"{deep}int(game.winner) >= 0\n"
        f"{deep}and not bool(\n"
        f"{deeper}vessel_decision.get(\n"
        f'{deepest}"reevaluate_after_action",\n'
        f"{deepest}false\n"
        f"{deeper})\n"
        f"{deep})\n"
        f"{indent}):\n"
        f"{deep}var stale_vessel_event: Dictionary = (\n"
        f"{deeper}_resolve_vessel(\n"
        f"{deepest}game,\n"
        f"{deepest}acting_player,\n"
        f"{deepest}vessel_validation\n"
        f"{deeper})\n"
        f"{deep})\n\n"
        f"{deep}return {{\n"
        f'{deeper}"action": "resolution_action_aftermath",\n'
        f'{deeper}"reason": "",\n'
        f'{deeper}"player_id": acting_player_id,\n'
        f'{deeper}"destruction_recorded": false,\n'
        f'{deeper}"kroni_events": [],\n'
        f'{deeper}"vessel_event": stale_vessel_event,\n'
        f'{deeper}"vulture_draw": "",\n'
        f'{deeper}"wright_token_gained": false,\n'
        f'{deeper}"discarded_committed": [],\n'
        f'{deeper}"stopped_on_win": true,\n'
        f'{deeper}"winner": int(\n'
        f"{deepest}game.winner\n"
        f"{deeper}),\n"
        f'{deeper}"win_by": String(\n'
        f"{deepest}game.win_by\n"
        f"{deeper}),\n"
        f"{deep}}}\n\n"
    )

    return text[: match.start()] + block + text[match.start() :]


def main() -> int:
    if not PATH.is_file():
        raise RuntimeError(f"REFUSED: missing required file: {PATH}")

    data = PATH.read_bytes()
    newline = "\r\n" if b"\r\n" in data else "\n"
    text = data.decode("utf-8").replace("\r\n", "\n")
    updated = patch(text)
    temporary = PATH.with_name(PATH.name + ".authoritative_stop.tmp")

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

    print("Stopped explicit stale Vessel aftermath after existing victory.")
    print("Bot doctrine reevaluation and post-Consume timing were unchanged.")
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
