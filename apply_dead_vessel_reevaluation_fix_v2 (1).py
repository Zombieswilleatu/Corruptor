#!/usr/bin/env python3
"""Defer validation of Vessel choices explicitly marked for reevaluation."""

from __future__ import annotations

import os
from pathlib import Path
import re
import sys


ENGINE_PATH = Path("Scripts/Sim/ResolutionActionAftermathEngine.gd")
TEST_PATH = Path("Scripts/Sim/ResolutionActionAftermathTests.gd")

CACHED_MARKER = "Validate the cached Vessel decision before aftermath mutation"
AUTHORITATIVE_MARKER = (
    "Explicit cached Vessel decisions cannot reopen an existing victory"
)
FIX_MARKER = "Doctrine-marked Vessel decisions are validated after reevaluation"
TEST_NAME = "unit_aftermath_vessel_dead_doctrine_refresh"


def indent_block(text: str, indent: str) -> str:
    return "".join(
        indent + line if line.strip() else line
        for line in text.splitlines(keepends=True)
    )


def patch_engine(text: str) -> str:
    if FIX_MARKER in text:
        raise RuntimeError(
            "REFUSED: dead-Lord Vessel reevaluation fix is already installed"
        )

    if text.count(CACHED_MARKER) != 1:
        raise RuntimeError(
            "REFUSED: expected the cached-validation marker once, "
            f"found {text.count(CACHED_MARKER)}"
        )

    if text.count(AUTHORITATIVE_MARKER) != 1:
        raise RuntimeError(
            "REFUSED: expected the authoritative-win marker once, "
            f"found {text.count(AUTHORITATIVE_MARKER)}"
        )

    marker_start = text.index(CACHED_MARKER)
    line_start = text.rfind("\n", 0, marker_start) + 1
    line_end = text.index("\n", marker_start) + 1
    marker_line = text[line_start:line_end]
    indent = marker_line[: len(marker_line) - len(marker_line.lstrip())]

    authoritative_start = text.index(AUTHORITATIVE_MARKER, line_end)
    authoritative_line_start = text.rfind("\n", 0, authoritative_start) + 1
    cached_body = text[line_end:authoritative_line_start]

    required = [
        f"{indent}var vessel_validation: Dictionary = (",
        "_validate_vessel_decision(",
        '"invalid_vessel_decision"',
    ]

    for fragment in required:
        if cached_body.count(fragment) != 1:
            raise RuntimeError(
                "REFUSED: unexpected cached-validation block; "
                f"expected {fragment!r} once, found "
                f"{cached_body.count(fragment)}"
            )

    decision_arguments = re.findall(
        r"^[ \t]+vessel_decision,?[ \t]*$",
        cached_body,
        re.MULTILINE,
    )

    if len(decision_arguments) != 1:
        raise RuntimeError(
            "REFUSED: expected vessel_decision once as a cached-validation "
            f"argument, found {len(decision_arguments)}"
        )

    assignment_body = cached_body.replace(
        f"{indent}var vessel_validation: Dictionary = (",
        f"{indent}vessel_validation = (",
        1,
    )
    deferred_body = indent_block(assignment_body, indent)
    deep = indent + indent
    deeper = deep + indent

    replacement = (
        marker_line
        + f"{indent}var vessel_validation: Dictionary = {{\n"
        + f'{deep}"valid": true,\n'
        + f'{deep}"reason": "",\n'
        + f'{deep}"offer": false,\n'
        + f"{indent}}}\n\n"
        + f"{indent}# {FIX_MARKER}.\n"
        + f"{indent}if not bool(\n"
        + f"{deep}vessel_decision.get(\n"
        + f'{deeper}"reevaluate_after_action",\n'
        + f"{deeper}false\n"
        + f"{deep})\n"
        + f"{indent}):\n"
        + deferred_body
    )

    return (
        text[:line_start]
        + replacement
        + text[authoritative_line_start:]
    )


def patch_tests(text: str) -> str:
    if TEST_NAME in text:
        raise RuntimeError(
            "REFUSED: dead-Lord Vessel regression test is already installed"
        )

    constant_anchor = (
        'const ATOMIC_TEST_NAME := '
        '"unit_aftermath_vessel_atomic_validation"\n'
    )

    if text.count(constant_anchor) != 1:
        raise RuntimeError(
            "REFUSED: expected the atomic-test constant anchor once, "
            f"found {text.count(constant_anchor)}"
        )

    text = text.replace(
        constant_anchor,
        (
            f'const DEAD_REFRESH_TEST_NAME := "{TEST_NAME}"\n'
            + constant_anchor
        ),
        1,
    )

    run_pattern = re.compile(
        r"^(?P<call_indent>[ \t]+)"
        r"_test_vessel_atomic_validation\(\n"
        r"(?P<rules_indent>[ \t]+)rules\n"
        r"(?P=call_indent)\),\n",
        re.MULTILINE,
    )
    run_matches = list(run_pattern.finditer(text))

    if len(run_matches) != 1:
        raise RuntimeError(
            "REFUSED: expected the atomic-test run call once, "
            f"found {len(run_matches)}"
        )

    run_match = run_matches[0]
    call_indent = run_match.group("call_indent")
    rules_indent = run_match.group("rules_indent")
    dead_refresh_call = (
        f"{call_indent}_test_vessel_dead_doctrine_refresh(\n"
        f"{rules_indent}rules\n"
        f"{call_indent}),\n"
    )
    text = (
        text[:run_match.start()]
        + dead_refresh_call
        + text[run_match.start():]
    )

    function_anchor = "static func _test_vessel_atomic_validation(\n"

    if text.count(function_anchor) != 1:
        raise RuntimeError(
            "REFUSED: expected the atomic-test function anchor once, "
            f"found {text.count(function_anchor)}"
        )

    test_function = f'''static func _test_vessel_dead_doctrine_refresh(
        rules: RuleConfig
) -> Dictionary:
        var fixture: Dictionary = _build_fixture(
                rules
        )

        if fixture.has(
                "error"
        ):
                return _fail(
                        DEAD_REFRESH_TEST_NAME,
                        String(
                                fixture["error"]
                        )
                )

        var game = fixture["game"]
        var player = fixture["p0"]
        var opponent = fixture["p1"]

        _prepare_game(
                game
        )

        player.lord = "Kanifous"
        player.alive = false
        player.vessel_used = false
        player.vessel_offered_lord = ""

        player.lord_guards = _cards_from_ids([
                "Butcher:2",
        ])

        opponent.souls = 1
        game.refresh_derived_values()

        var tears_before: int = int(
                player.tears
        )

        var opponent_souls_before: int = int(
                opponent.souls
        )

        var guards_before: Array[String] = _card_ids(
                player.lord_guards
        )

        var result: Dictionary = (
                ResolutionActionAftermathEngineData.resolve(
                        game,
                        rules,
                        0,
                        {{
                                "action": "pass",
                                "destroyed": false,
                        }},
                        {{
                                "offer": true,
                                "reevaluate_after_action": true,
                        }}
                )
        )

        if String(
                result.get(
                        "action",
                        ""
                )
        ) != "resolution_action_aftermath":
                return _fail(
                        DEAD_REFRESH_TEST_NAME,
                        "Dead-Lord doctrine reevaluation was rejected."
                )

        var vessel_event: Dictionary = result.get(
                "vessel_event",
                {{}}
        )

        if String(
                vessel_event.get(
                        "action",
                        ""
                )
        ) != "pass":
                return _fail(
                        DEAD_REFRESH_TEST_NAME,
                        "Dead-Lord Vessel choice did not refresh to pass."
                )

        if player.alive:
                return _fail(
                        DEAD_REFRESH_TEST_NAME,
                        "Vessel reevaluation revived the dead Lord."
                )

        if (
                player.vessel_used
                or not player.vessel_offered_lord.is_empty()
        ):
                return _fail(
                        DEAD_REFRESH_TEST_NAME,
                        "Dead-Lord reevaluation recorded a Vessel offer."
                )

        if player.tears != tears_before:
                return _fail(
                        DEAD_REFRESH_TEST_NAME,
                        "Dead-Lord reevaluation granted a Tear."
                )

        if opponent.souls != opponent_souls_before:
                return _fail(
                        DEAD_REFRESH_TEST_NAME,
                        "Dead-Lord reevaluation granted an opponent Soul."
                )

        if _card_ids(
                player.lord_guards
        ) != guards_before:
                return _fail(
                        DEAD_REFRESH_TEST_NAME,
                        "Dead-Lord reevaluation discarded Lord Guards."
                )

        return _pass(
                DEAD_REFRESH_TEST_NAME
        )


'''

    return text.replace(
        function_anchor,
        test_function + function_anchor,
        1,
    )


def update_file(path: Path, patcher) -> tuple[bytes, bytes]:
    if not path.is_file():
        raise RuntimeError(f"REFUSED: missing required file: {path}")

    original = path.read_bytes()
    newline = "\r\n" if b"\r\n" in original else "\n"
    text = original.decode("utf-8").replace("\r\n", "\n")
    updated_text = patcher(text)
    updated = updated_text.replace("\n", newline).encode("utf-8")

    if original == updated:
        raise RuntimeError(f"REFUSED: patch made no change: {path}")

    return original, updated


def main() -> int:
    engine_original, engine_updated = update_file(
        ENGINE_PATH,
        patch_engine,
    )
    test_original, test_updated = update_file(
        TEST_PATH,
        patch_tests,
    )

    engine_temporary = ENGINE_PATH.with_name(
        ENGINE_PATH.name + ".dead_vessel.tmp"
    )
    test_temporary = TEST_PATH.with_name(
        TEST_PATH.name + ".dead_vessel.tmp"
    )

    for temporary in (engine_temporary, test_temporary):
        if temporary.exists():
            raise RuntimeError(
                f"REFUSED: temporary path already exists: {temporary}"
            )

    engine_replaced = False

    try:
        engine_temporary.write_bytes(engine_updated)
        test_temporary.write_bytes(test_updated)

        os.replace(engine_temporary, ENGINE_PATH)
        engine_replaced = True
        os.replace(test_temporary, TEST_PATH)
    except Exception:
        if engine_replaced:
            ENGINE_PATH.write_bytes(engine_original)
        raise
    finally:
        for temporary in (engine_temporary, test_temporary):
            if temporary.exists():
                temporary.unlink()

    print("Deferred doctrine-marked Vessel validation until reevaluation.")
    print("Kept explicit Vessel decisions atomically validated before mutation.")
    print("Added permanent dead-Lord Vessel doctrine regression coverage.")
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
