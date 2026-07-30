#!/usr/bin/env python3
"""Stop Godot Resolution when its Prelude has already produced a winner."""

from __future__ import annotations

import os
from pathlib import Path
import re
import sys


PATH = Path("Scripts/Sim/ResolutionEngine.gd")
MARKER = "# Python exits Resolution when a Prelude effect wins."


def patch(text: str) -> str:
    if MARKER in text:
        raise RuntimeError(
            "REFUSED: post-Prelude winner stop is already installed"
        )

    pattern = re.compile(
        r'^(?P<base>[ \t]*)var raw_order = prelude_result\.get\(\n'
        r'(?P<child>[ \t]*)"order",',
        re.MULTILINE,
    )
    matches = list(pattern.finditer(text))

    if len(matches) != 1:
        raise RuntimeError(
            "REFUSED: expected Prelude order boundary exactly once, "
            f"found {len(matches)}"
        )

    match = matches[0]
    base = match.group("base")
    child = match.group("child")

    if not child.startswith(base) or len(child) <= len(base):
        raise RuntimeError(
            "REFUSED: could not infer existing Resolution indentation"
        )

    unit = child[len(base):]
    deep = child + unit
    stop = (
        f"{base}{MARKER}\n"
        f"{base}if int(\n"
        f"{child}game.winner\n"
        f"{base}) >= 0:\n"
        f"{child}return _finish_result(\n"
        f"{deep}game,\n"
        f"{deep}prelude_result,\n"
        f"{deep}[],\n"
        f"{deep}{{}},\n"
        f"{deep}{{}},\n"
        f"{deep}{{}},\n"
        f'{deep}"prelude"\n'
        f"{child})\n\n"
    )

    return text[: match.start()] + stop + text[match.start() :]


def main() -> int:
    if not PATH.is_file():
        raise RuntimeError(f"REFUSED: missing required file: {PATH}")

    data = PATH.read_bytes()
    newline = "\r\n" if b"\r\n" in data else "\n"
    text = data.decode("utf-8").replace("\r\n", "\n")
    updated = patch(text)
    temporary = PATH.with_name(PATH.name + ".prelude_stop.tmp")

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

    print("Installed post-Prelude winner stop in ResolutionEngine.")
    print("No Python oracle, golden file, retained batch, or Git ref was changed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
