#!/usr/bin/env python3
"""Match Python's winner re-evaluation after each player's resummon."""

from __future__ import annotations

import os
from pathlib import Path
import re
import sys


SUMMON_PATH = Path("Scripts/Sim/SummonEngine.gd")
ROUND_PATH = Path("Scripts/Sim/BotRoundEngine.gd")
FIX_MARKER = "# Python re-evaluates victory after each player's summon."
PROBE_MARKER = "DEBUG SOAK GREMORY KANIFOUS R7"


def patch_summon(text: str) -> str:
    if FIX_MARKER in text:
        raise RuntimeError(
            "REFUSED: Summon winner re-evaluation fix is already installed"
        )

    pattern = re.compile(
        r'^(?P<header>static func _check_win\(\n'
        r'[ \t]*game,\n'
        r'[ \t]*rules: RuleConfig\n'
        r'\) -> bool:\n)'
        r'(?P<base>[ \t]*)if int\(\n'
        r'[ \t]*game\.winner\n'
        r'[ \t]*\) >= 0:\n'
        r'[ \t]*return true\n\n',
        re.MULTILINE,
    )
    matches = list(pattern.finditer(text))

    if len(matches) != 1:
        raise RuntimeError(
            "REFUSED: expected Summon _check_win guard exactly once, "
            f"found {len(matches)}"
        )

    match = matches[0]
    replacement = (
        match.group("header")
        + match.group("base")
        + FIX_MARKER
        + "\n"
    )

    return text[: match.start()] + replacement + text[match.end() :]


def remove_probe(text: str) -> str:
    if text.count(PROBE_MARKER) != 2:
        raise RuntimeError(
            "REFUSED: expected the temporary phase-probe marker twice, "
            f"found {text.count(PROBE_MARKER)}"
        )

    pattern = re.compile(
        r'^[ \t]*if \(\n'
        r'[ \t]*int\(game\.round\) == 7\n'
        r'[ \t]*and game\.players\.size\(\) == 2\n'
        r'[ \t]*and String\(game\.players\[0\]\.lord\) == "Gremory"\n'
        r'[ \t]*and String\(game\.players\[1\]\.lord\) == "Kanifous"\n'
        r'[ \t]*and int\(game\.winner\) >= 0\n'
        r'[ \t]*and String\(game\.win_by\) == "FinalCollapse"\n'
        r'[ \t]*\):\n'
        r'.*?'
        r'^[ \t]*\)\n\n',
        re.MULTILINE | re.DOTALL,
    )
    matches = list(pattern.finditer(text))

    if len(matches) != 1:
        raise RuntimeError(
            "REFUSED: expected temporary phase-probe block exactly once, "
            f"found {len(matches)}"
        )

    return text[: matches[0].start()] + text[matches[0].end() :]


def read(path: Path) -> tuple[str, str]:
    data = path.read_bytes()
    newline = "\r\n" if b"\r\n" in data else "\n"
    return data.decode("utf-8").replace("\r\n", "\n"), newline


def main() -> int:
    for path in (SUMMON_PATH, ROUND_PATH):
        if not path.is_file():
            raise RuntimeError(f"REFUSED: missing required file: {path}")

    summon, summon_newline = read(SUMMON_PATH)
    round_engine, round_newline = read(ROUND_PATH)
    updates = {
        SUMMON_PATH: (patch_summon(summon), summon_newline),
        ROUND_PATH: (remove_probe(round_engine), round_newline),
    }
    temporaries: dict[Path, Path] = {}

    try:
        for path, (content, newline) in updates.items():
            temporary = path.with_name(path.name + ".summon_recheck.tmp")

            if temporary.exists():
                raise RuntimeError(
                    f"REFUSED: temporary path already exists: {temporary}"
                )

            temporary.write_bytes(
                content.replace("\n", newline).encode("utf-8")
            )
            temporaries[path] = temporary

        for path, temporary in temporaries.items():
            os.replace(temporary, path)
    finally:
        for temporary in temporaries.values():
            if temporary.exists():
                temporary.unlink()

    print("Installed Summon winner re-evaluation parity fix.")
    print("Removed temporary Gremory-vs-Kanifous phase probe.")
    print("No Python oracle, golden file, retained batch, or Git ref was changed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
