#!/usr/bin/env python3
"""Route Gremory's Prelude draw through canonical DrawEngine recycling."""

from __future__ import annotations

import os
from pathlib import Path
import re
import sys
from typing import Callable, Match


PRELUDE_PATH = Path("Scripts/Sim/ResolutionPreludeEngine.gd")
RESOLUTION_PATH = Path("Scripts/Sim/ResolutionEngine.gd")
INSTALLED_MARKER = "DrawEngineData.draw_to_hand("


Replacement = str | Callable[[Match[str]], str]


def replace_regex_once(
    text: str,
    pattern: str,
    replacement: Replacement,
    label: str,
    *,
    flags: int = 0,
) -> str:
    expression = re.compile(pattern, flags)
    count = len(list(expression.finditer(text)))

    if count != 1:
        raise RuntimeError(
            f"REFUSED: expected {label} exactly once, found {count}"
        )

    return expression.sub(replacement, text, count=1)


def patch_prelude(text: str) -> str:
    if INSTALLED_MARKER in text:
        raise RuntimeError(
            "REFUSED: Gremory Prelude recycling fix is already installed"
        )

    def add_draw_preload(match: Match[str]) -> str:
        indent = match.group("indent")
        return (
            match.group(0)
            + "\n\nconst DrawEngineData = preload(\n"
            + indent
            + '"res://Scripts/Sim/DrawEngine.gd"\n)'
        )

    text = replace_regex_once(
        text,
        (
            r'^const LordMathData = preload\(\n'
            r'(?P<indent>[ \t]*)"res://Scripts/Sim/LordMath\.gd"\n'
            r'\)'
        ),
        add_draw_preload,
        "Prelude LordMath preload",
        flags=re.MULTILINE,
    )

    text = replace_regex_once(
        text,
        (
            r'^(?P<prefix>static func resolve\(\n'
            r'[ \t]*game,\n'
            r'[ \t]*rules: RuleConfig,\n)'
            r'(?P<indent>[ \t]*)tie_first_player: int = -1'
            r'(?P<suffix>\n[ \t]*\) -> Dictionary:)'
        ),
        lambda match: (
            match.group("prefix")
            + match.group("indent")
            + "tie_first_player: int = -1,\n"
            + match.group("indent")
            + "random_source = null"
            + match.group("suffix")
        ),
        "Prelude resolve signature",
        flags=re.MULTILINE,
    )

    text = replace_regex_once(
        text,
        (
            r'^(?P<prefix>[ \t]*var scorch_event: Dictionary = '
            r'_apply_persistent_scorch\(\n'
            r'[ \t]*game,\n)'
            r'(?P<indent>[ \t]*)rules'
            r'(?P<suffix>\n[ \t]*\))'
        ),
        lambda match: (
            match.group("prefix")
            + match.group("indent")
            + "rules,\n"
            + match.group("indent")
            + "random_source"
            + match.group("suffix")
        ),
        "persistent Scorch call",
        flags=re.MULTILINE,
    )

    text = replace_regex_once(
        text,
        (
            r'^(?P<prefix>static func _apply_persistent_scorch\(\n'
            r'[ \t]*game,\n)'
            r'(?P<indent>[ \t]*)rules: RuleConfig'
            r'(?P<suffix>\n[ \t]*\) -> Dictionary:)'
        ),
        lambda match: (
            match.group("prefix")
            + match.group("indent")
            + "rules: RuleConfig,\n"
            + match.group("indent")
            + "random_source = null"
            + match.group("suffix")
        ),
        "persistent Scorch signature",
        flags=re.MULTILINE,
    )

    text = replace_regex_once(
        text,
        (
            r'^(?P<prefix>[ \t]*gremory_trigger = '
            r'_trigger_gremory_lord_guard\(\n'
            r'[ \t]*game,\n)'
            r'(?P<indent>[ \t]*)rules'
            r'(?P<suffix>\n[ \t]*\))'
        ),
        lambda match: (
            match.group("prefix")
            + match.group("indent")
            + "rules,\n"
            + match.group("indent")
            + "random_source"
            + match.group("suffix")
        ),
        "Gremory trigger call",
        flags=re.MULTILINE,
    )

    text = replace_regex_once(
        text,
        (
            r'^(?P<prefix>static func _trigger_gremory_lord_guard\(\n'
            r'[ \t]*game,\n)'
            r'(?P<indent>[ \t]*)rules: RuleConfig'
            r'(?P<suffix>\n[ \t]*\) -> Dictionary:)'
        ),
        lambda match: (
            match.group("prefix")
            + match.group("indent")
            + "rules: RuleConfig,\n"
            + match.group("indent")
            + "random_source = null"
            + match.group("suffix")
        ),
        "Gremory trigger signature",
        flags=re.MULTILINE,
    )

    direct_draw_pattern = (
        r'^(?P<base>[ \t]*)var drawn_card = null\n\n'
        r'[ \t]*if \(\n'
        r'(?P<child>[ \t]*)player\.hand\.size\(\) < rules\.hand_limit\n'
        r'[ \t]*and not game\.deck\.is_empty\(\)\n'
        r'[ \t]*\):\n'
        r'[ \t]*drawn_card = game\.deck\.pop_back\(\)\n\n'
        r'[ \t]*player\.hand\.append\(\n'
        r'(?P<deep>[ \t]*)drawn_card\n'
        r'[ \t]*\)\n\n'
        r'[ \t]*player\.kanifous_outside_draws \+= 1\n\n'
        r'[ \t]*if game\.breach == "Kanifous":\n'
        r'[ \t]*player\.threat = min\(\n'
        r'[ \t]*rules\.max_threat,\n'
        r'[ \t]*int\(\n'
        r'[ \t]*player\.threat\n'
        r'[ \t]*\) \+ 1\n'
        r'[ \t]*\)\n'
    )

    def canonical_draw(match: Match[str]) -> str:
        base = match.group("base")
        child = match.group("child")
        deep = match.group("deep")
        return (
            f"{base}var drawn_card = null\n\n"
            f"{base}var draw_result: Dictionary = (\n"
            f"{child}DrawEngineData.draw_to_hand(\n"
            f"{deep}game,\n"
            f"{deep}player,\n"
            f"{deep}rules,\n"
            f"{deep}random_source,\n"
            f"{deep}true\n"
            f"{child})\n"
            f"{base})\n\n"
            f"{base}if bool(\n"
            f"{child}draw_result.get(\n"
            f'{deep}"drawn",\n'
            f"{deep}false\n"
            f"{child})\n"
            f"{base}):\n"
            f"{child}drawn_card = player.hand.back()\n"
        )

    text = replace_regex_once(
        text,
        direct_draw_pattern,
        canonical_draw,
        "direct Gremory draw block",
        flags=re.MULTILINE,
    )

    return text


def patch_resolution(text: str) -> str:
    already_threaded = re.compile(
        r'ResolutionPreludeEngineData\.resolve\(\n'
        r'[ \t]*game,\n[ \t]*rules,\n'
        r'[ \t]*tie_first_player,\n[ \t]*random_source\n'
    )

    if already_threaded.search(text):
        raise RuntimeError(
            "REFUSED: Resolution already threads RNG into Prelude"
        )

    pattern = (
        r'^(?P<prefix>[ \t]*ResolutionPreludeEngineData\.resolve\(\n'
        r'[ \t]*game,\n[ \t]*rules,\n)'
        r'(?P<indent>[ \t]*)tie_first_player'
        r'(?P<suffix>\n[ \t]*\))'
    )

    return replace_regex_once(
        text,
        pattern,
        lambda match: (
            match.group("prefix")
            + match.group("indent")
            + "tie_first_player,\n"
            + match.group("indent")
            + "random_source"
            + match.group("suffix")
        ),
        "Resolution-to-Prelude call",
        flags=re.MULTILINE,
    )


def read(path: Path) -> tuple[str, str]:
    data = path.read_bytes()
    newline = "\r\n" if b"\r\n" in data else "\n"
    return data.decode("utf-8").replace("\r\n", "\n"), newline


def main() -> int:
    for path in (PRELUDE_PATH, RESOLUTION_PATH):
        if not path.is_file():
            raise RuntimeError(f"REFUSED: missing required file: {path}")

    prelude, prelude_newline = read(PRELUDE_PATH)
    resolution, resolution_newline = read(RESOLUTION_PATH)
    updates = {
        PRELUDE_PATH: (patch_prelude(prelude), prelude_newline),
        RESOLUTION_PATH: (patch_resolution(resolution), resolution_newline),
    }
    temporaries: dict[Path, Path] = {}

    try:
        for path, (content, newline) in updates.items():
            temporary = path.with_name(path.name + ".gremory_recycle.tmp")

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

    print("Applied canonical Gremory Prelude recycling fix.")
    print("Threaded deterministic Resolution RNG into Prelude.")
    print("No Python oracle, golden file, retained batch, or Git ref was changed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
