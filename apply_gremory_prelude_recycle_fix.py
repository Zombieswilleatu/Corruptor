#!/usr/bin/env python3
"""Route Gremory's Prelude draw through canonical DrawEngine recycling."""

from __future__ import annotations

import os
from pathlib import Path
import sys


PRELUDE_PATH = Path("Scripts/Sim/ResolutionPreludeEngine.gd")
RESOLUTION_PATH = Path("Scripts/Sim/ResolutionEngine.gd")
INSTALLED_MARKER = "DrawEngineData.draw_to_hand("


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)

    if count != 1:
        raise RuntimeError(
            f"REFUSED: expected {label} exactly once, found {count}"
        )

    return text.replace(old, new, 1)


def patch_prelude(text: str) -> str:
    if INSTALLED_MARKER in text:
        raise RuntimeError("REFUSED: Gremory Prelude recycling fix is already installed")

    text = replace_once(
        text,
        '''const LordMathData = preload(
        "res://Scripts/Sim/LordMath.gd"
)
''',
        '''const LordMathData = preload(
        "res://Scripts/Sim/LordMath.gd"
)

const DrawEngineData = preload(
        "res://Scripts/Sim/DrawEngine.gd"
)
''',
        "Prelude LordMath preload",
    )

    text = replace_once(
        text,
        '''static func resolve(
        game,
        rules: RuleConfig,
        tie_first_player: int = -1
) -> Dictionary:
''',
        '''static func resolve(
        game,
        rules: RuleConfig,
        tie_first_player: int = -1,
        random_source = null
) -> Dictionary:
''',
        "Prelude resolve signature",
    )

    text = replace_once(
        text,
        '''        var scorch_event: Dictionary = _apply_persistent_scorch(
                game,
                rules
        )
''',
        '''        var scorch_event: Dictionary = _apply_persistent_scorch(
                game,
                rules,
                random_source
        )
''',
        "persistent Scorch call",
    )

    text = replace_once(
        text,
        '''static func _apply_persistent_scorch(
        game,
        rules: RuleConfig
) -> Dictionary:
''',
        '''static func _apply_persistent_scorch(
        game,
        rules: RuleConfig,
        random_source = null
) -> Dictionary:
''',
        "persistent Scorch signature",
    )

    text = replace_once(
        text,
        '''            gremory_trigger = _trigger_gremory_lord_guard(
                    game,
                    rules
            )
''',
        '''            gremory_trigger = _trigger_gremory_lord_guard(
                    game,
                    rules,
                    random_source
            )
''',
        "Gremory trigger call",
    )

    text = replace_once(
        text,
        '''static func _trigger_gremory_lord_guard(
    game,
    rules: RuleConfig
) -> Dictionary:
''',
        '''static func _trigger_gremory_lord_guard(
    game,
    rules: RuleConfig,
    random_source = null
) -> Dictionary:
''',
        "Gremory trigger signature",
    )

    text = replace_once(
        text,
        '''            var drawn_card = null

            if (
                    player.hand.size() < rules.hand_limit
                    and not game.deck.is_empty()
            ):
                    drawn_card = game.deck.pop_back()

                    player.hand.append(
                            drawn_card
                    )

                    player.kanifous_outside_draws += 1

                    if game.breach == "Kanifous":
                            player.threat = min(
                                    rules.max_threat,
                                    int(
                                            player.threat
                                    ) + 1
                            )
''',
        '''            var drawn_card = null

            var draw_result: Dictionary = (
                    DrawEngineData.draw_to_hand(
                            game,
                            player,
                            rules,
                            random_source,
                            true
                    )
            )

            if bool(
                    draw_result.get(
                            "drawn",
                            false
                    )
            ):
                    drawn_card = player.hand.back()
''',
        "direct Gremory draw block",
    )

    return text


def patch_resolution(text: str) -> str:
    old = '''            ResolutionPreludeEngineData.resolve(
                    game,
                    rules,
                    tie_first_player
            )
'''
    new = '''            ResolutionPreludeEngineData.resolve(
                    game,
                    rules,
                    tie_first_player,
                    random_source
            )
'''

    if new in text:
        raise RuntimeError("REFUSED: Resolution already threads RNG into Prelude")

    return replace_once(
        text,
        old,
        new,
        "Resolution-to-Prelude call",
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
        PRELUDE_PATH: (
            patch_prelude(prelude),
            prelude_newline,
        ),
        RESOLUTION_PATH: (
            patch_resolution(resolution),
            resolution_newline,
        ),
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
