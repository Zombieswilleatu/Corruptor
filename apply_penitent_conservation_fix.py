#!/usr/bin/env python3
"""Apply the bilateral Kanifous Penitent card-conservation correction.

Run from the Corruptor repository root. Every existing-file edit is guarded by
an exact source-shape check. All checks complete before any file is replaced.
"""

from __future__ import annotations

import os
from pathlib import Path
import re
import sys


EXPECTED_POPULATION = 60


def read_text(path: Path) -> tuple[str, str]:
    data = path.read_bytes()
    newline = "\r\n" if b"\r\n" in data else "\n"
    return data.decode("utf-8").replace("\r\n", "\n"), newline


def require_count(text: str, needle: str, count: int, label: str) -> None:
    actual = text.count(needle)
    if actual != count:
        raise RuntimeError(
            f"REFUSED: expected {label} {count} time(s), found {actual}"
        )


def patch_python_sim(text: str) -> tuple[str, str]:
    old = """            for g in temp:
                if g in pl.lord_guards:      pl.lord_guards.remove(g)
                elif g in pl.castle_guards:  pl.castle_guards.remove(g)
                self._discard([g])
            pl.penitent_temp_guards = []
"""
    new = """            for g in temp:
                if g in pl.lord_guards:
                    pl.lord_guards.remove(g)
                    self._discard([g])
                elif g in pl.castle_guards:
                    pl.castle_guards.remove(g)
                    self._discard([g])
            pl.penitent_temp_guards = []
"""

    if new in text:
        raise RuntimeError("REFUSED: Python Penitent fix is already installed")
    require_count(text, old, 1, "Python Penitent cleanup block")
    text = text.replace(old, new, 1)

    version_pattern = re.compile(
        r'(?m)^(?P<prefix>SIM_VERSION\s*=\s*")'
        r'(?P<version>\d+\.\d+(?:\.\d+)?)'
        r'(?P<suffix>"[^\n]*)$'
    )
    matches = list(version_pattern.finditer(text))
    if len(matches) != 1:
        raise RuntimeError(
            "REFUSED: expected exactly one numeric SIM_VERSION assignment, "
            f"found {len(matches)}"
        )

    current = matches[0].group("version")
    parts = [int(part) for part in current.split(".")]
    if len(parts) == 2:
        parts.append(1)
    else:
        parts[-1] += 1
    updated = ".".join(str(part) for part in parts)

    text = version_pattern.sub(
        lambda match: (
            match.group("prefix") + updated + match.group("suffix")
        ),
        text,
        count=1,
    )
    return text, f"SIM_VERSION {current} -> {updated}"


def patch_godot_cleanup(text: str) -> str:
    if "Penitent Guard already left both Guard zones" in text:
        raise RuntimeError("REFUSED: Godot Penitent fix is already installed")

    pattern = re.compile(
        r"(?m)^(?P<indent>[ \t]+)game\.discard\.append\(\n"
        r"(?P<argument_indent>[ \t]+)temporary_guard\n"
        r"(?P=indent)\)"
    )
    matches = list(pattern.finditer(text))
    if len(matches) != 1:
        raise RuntimeError(
            "REFUSED: expected exactly one temporary-guard discard append, "
            f"found {len(matches)}"
        )

    match = matches[0]
    indent = match.group("indent")
    argument_indent = match.group("argument_indent")
    if not argument_indent.startswith(indent):
        raise RuntimeError("REFUSED: unable to infer Godot indentation")
    unit = argument_indent[len(indent):]
    if not unit:
        raise RuntimeError("REFUSED: empty Godot indentation unit")

    original = match.group(0)
    replacement = (
        f'{indent}# A defeated temporary Guard is already in discard.\n'
        f'{indent}if source_zone == "Missing":\n'
        f"{indent}{unit}continue\n\n"
        f"{original}"
    )
    return text[:match.start()] + replacement + text[match.end():]


def godot_test_function(unit: str) -> str:
    i = unit
    lines: list[str] = []

    def add(level: int = 0, value: str = "") -> None:
        lines.append(i * level + value)

    add(0, "static func _test_penitent_defeated_guard_conservation(")
    add(1, "rules: RuleConfig")
    add(0, ") -> Dictionary:")
    add(1, "var fixture: Dictionary = _build_fixture(")
    add(2, "rules")
    add(1, ")")
    add()
    add(1, 'if fixture.has("error"):')
    add(2, "return _fail(")
    add(3, "PENITENT_DEFEATED_TEST_NAME,")
    add(3, 'String(fixture["error"])')
    add(2, ")")
    add()
    add(1, 'var game = fixture["game"]')
    add(1, 'var player = fixture["p0"]')
    add()
    add(1, "_prepare_game(game)")
    add()
    add(1, 'var defeated_guard = _card_from_id("Vulture:4")')
    add()
    add(1, "# Combat already removed this temporary Guard from its Guard zone.")
    add(1, "game.discard = [defeated_guard]")
    add(1, "player.penitent_temp_guards = [defeated_guard]")
    add()
    add(1, "var result: Dictionary = (")
    add(2, "ResolutionCleanupEngineData.resolve(")
    add(3, "game,")
    add(3, "rules")
    add(2, ")")
    add(1, ")")
    add()
    add(1, "if game.discard.size() != 1:")
    add(2, "return _fail(")
    add(3, "PENITENT_DEFEATED_TEST_NAME,")
    add(3, '"Cleanup duplicated an already-defeated temporary Guard."')
    add(2, ")")
    add()
    add(1, "if game.discard[0] != defeated_guard:")
    add(2, "return _fail(")
    add(3, "PENITENT_DEFEATED_TEST_NAME,")
    add(3, '"Cleanup replaced the defeated Guard object."')
    add(2, ")")
    add()
    add(1, "if not player.penitent_temp_guards.is_empty():")
    add(2, "return _fail(")
    add(3, "PENITENT_DEFEATED_TEST_NAME,")
    add(3, '"Cleanup retained defeated-Guard tracking."')
    add(2, ")")
    add()
    add(1, "var event: Dictionary = _first_event(")
    add(2, "result,")
    add(2, '"penitent_events"')
    add(1, ")")
    add()
    add(1, 'if not _string_array(event.get("cards", [])).is_empty():')
    add(2, "return _fail(")
    add(3, "PENITENT_DEFEATED_TEST_NAME,")
    add(3, '"Cleanup event re-recorded a previously defeated Guard."')
    add(2, ")")
    add()
    add(1, "return _pass(PENITENT_DEFEATED_TEST_NAME)")
    add()
    add()
    return "\n".join(lines)


def patch_godot_cleanup_tests(text: str) -> str:
    constant = (
        'const PENITENT_DEFEATED_TEST_NAME := '
        '"unit_cleanup_penitent_defeated_guard_conservation"'
    )
    if constant in text:
        raise RuntimeError("REFUSED: Godot Penitent regression already exists")

    constant_marker = (
        'const PENITENT_TEST_NAME := "unit_cleanup_penitent_guards"\n'
    )
    require_count(text, constant_marker, 1, "Penitent test-name marker")
    text = text.replace(
        constant_marker,
        constant_marker + constant + "\n",
        1,
    )

    run_pattern = re.compile(
        r"(?m)^(?P<indent>[ \t]+)_test_penitent_cleanup\(\n"
        r"(?P<inner>[ \t]+)rules\n"
        r"(?P=indent)\),"
    )
    run_matches = list(run_pattern.finditer(text))
    if len(run_matches) != 1:
        raise RuntimeError(
            "REFUSED: expected one Penitent run-list entry, "
            f"found {len(run_matches)}"
        )
    run_match = run_matches[0]
    indent = run_match.group("indent")
    inner = run_match.group("inner")
    run_addition = (
        run_match.group(0)
        + "\n"
        + f"{indent}_test_penitent_defeated_guard_conservation(\n"
        + f"{inner}rules\n"
        + f"{indent}),"
    )
    text = text[:run_match.start()] + run_addition + text[run_match.end():]

    signature_pattern = re.compile(
        r"(?m)^static func _test_penitent_cleanup\(\n"
        r"(?P<unit>[ \t]+)rules: RuleConfig\n"
        r"^\) -> Dictionary:"
    )
    signatures = list(signature_pattern.finditer(text))
    if len(signatures) != 1:
        raise RuntimeError(
            "REFUSED: unable to infer ResolutionCleanupTests indentation"
        )
    unit = signatures[0].group("unit")

    function_marker = "static func _test_profane_tears("
    require_count(text, function_marker, 1, "Profane test function marker")
    text = text.replace(
        function_marker,
        godot_test_function(unit) + function_marker,
        1,
    )
    return text


def population_helper(unit: str) -> str:
    i = unit
    lines: list[str] = []

    def add(level: int = 0, value: str = "") -> None:
        lines.append(i * level + value)

    add(0, "static func _card_population_failure(game) -> String:")
    add(1, "var zones: Array = [")
    add(2, '{"name": "deck", "cards": game.deck},')
    add(2, '{"name": "discard", "cards": game.discard},')
    add(2, '{"name": "market", "cards": game.market},')
    add(1, "]")
    add()
    add(1, "for player in game.players:")
    add(2, "var player_id: int = int(player.pid)")
    for zone in ("hand", "garrison", "castle_guards", "lord_guards", "committed"):
        add(2, "zones.append({")
        add(3, f'"name": "p%d.{zone}" % player_id,')
        add(3, f'"cards": player.{zone},')
        add(2, "})")
    add()
    add(1, "var seen: Dictionary = {}")
    add(1, "var total: int = 0")
    add()
    add(1, "for zone_data in zones:")
    add(2, 'var zone_name: String = String(zone_data.get("name", ""))')
    add(2, 'var cards: Array = zone_data.get("cards", [])')
    add()
    add(2, "for card_index in range(cards.size()):")
    add(3, "var card = cards[card_index]")
    add(3, "total += 1")
    add()
    add(3, "if card == null:")
    add(4, 'return "null card at %s[%d]" % [zone_name, card_index]')
    add()
    add(3, "var instance_id: int = int(card.get_instance_id())")
    add(3, 'var location: String = "%s[%d]" % [zone_name, card_index]')
    add()
    add(3, "if seen.has(instance_id):")
    add(4, 'return "duplicate physical card %s:%d#%d first=%s second=%s" % [')
    add(5, "String(card.suit),")
    add(5, "int(card.value),")
    add(5, "instance_id,")
    add(5, "String(seen[instance_id]),")
    add(5, "location,")
    add(4, "]")
    add()
    add(3, "seen[instance_id] = location")
    add()
    add(1, "if total != EXPECTED_CARD_POPULATION:")
    add(2, 'return "card population mismatch: want=%d got=%d" % [')
    add(3, "EXPECTED_CARD_POPULATION,")
    add(3, "total,")
    add(2, "]")
    add()
    add(1, 'return ""')
    add()
    add()
    return "\n".join(lines)


def population_check(
    unit: str,
    variable: str,
    checkpoint: str,
    base_level: int,
) -> str:
    base = unit * base_level
    child = unit * (base_level + 1)
    grandchild = unit * (base_level + 2)
    return "\n".join([
        f"{base}var {variable}: String = _card_population_failure(game)",
        "",
        f"{base}if not {variable}.is_empty():",
        f"{child}return _fail(",
        f"{grandchild}scenario_name,",
        f'{grandchild}"Card conservation failure at {checkpoint}: %s"',
        f"{grandchild}% {variable}",
        f"{child})",
        "",
    ])


def patch_matrix_tests(text: str) -> str:
    if "EXPECTED_CARD_POPULATION" in text:
        raise RuntimeError("REFUSED: matrix population invariant already exists")

    constant_marker = "const EXPECTED_SCENARIO_COUNT: int = 81\n"
    require_count(text, constant_marker, 1, "matrix constant marker")
    text = text.replace(
        constant_marker,
        constant_marker
        + f"const EXPECTED_CARD_POPULATION: int = {EXPECTED_POPULATION}\n",
        1,
    )

    function_pattern = re.compile(
        r"(?m)^static func _run_scenario\(\n"
        r"(?P<unit>[ \t]+)scenario: Dictionary,"
    )
    functions = list(function_pattern.finditer(text))
    if len(functions) != 1:
        raise RuntimeError("REFUSED: unable to infer LordMatrixTests indentation")
    unit = functions[0].group("unit")

    deal_marker = f"{unit}var snapshots: Array = ["
    require_count(text, deal_marker, 1, "matrix deal snapshot marker")
    text = text.replace(
        deal_marker,
        population_check(
            unit,
            "deal_population_failure",
            "game:deal",
            1,
        ) + deal_marker,
        1,
    )

    round_marker = f"{unit}{unit}snapshots.append("
    require_count(text, round_marker, 1, "matrix round snapshot marker")
    round_check = population_check(
        unit,
        "round_population_failure",
        "round:end",
        2,
    )
    text = text.replace(round_marker, round_check + round_marker, 1)

    terminal_marker = f"{unit}var terminal_failure: String = ("
    require_count(text, terminal_marker, 1, "matrix terminal marker")
    terminal_check = population_check(
        unit,
        "terminal_population_failure",
        "game:end",
        1,
    )
    text = text.replace(terminal_marker, terminal_check + terminal_marker, 1)

    helper_marker = "static func _terminal_failure("
    require_count(text, helper_marker, 1, "matrix helper marker")
    text = text.replace(
        helper_marker,
        population_helper(unit) + helper_marker,
        1,
    )
    return text


def patch_soak_master(text: str) -> str:
    if "validate_snapshot_card_population" in text:
        raise RuntimeError("REFUSED: soak population census already exists")

    constant_marker = "MAX_GAME_SEED = 2_147_483_647\n"
    require_count(text, constant_marker, 1, "soak constant marker")
    text = text.replace(
        constant_marker,
        constant_marker
        + f"EXPECTED_CARD_POPULATION = {EXPECTED_POPULATION}\n",
        1,
    )

    helper = '''def validate_snapshot_card_population(
    snapshots: list[dict[str, Any]],
    scenario_name: str,
) -> None:
    top_level_zones = ("deck", "discard", "market")
    player_zones = (
        "hand",
        "garrison",
        "castle_guards",
        "lord_guards",
        "committed",
    )

    for snapshot in snapshots:
        total = sum(
            len(snapshot.get(zone, []))
            for zone in top_level_zones
        )

        for player in snapshot.get("players", []):
            total += sum(
                len(player.get(zone, []))
                for zone in player_zones
            )

        if total != EXPECTED_CARD_POPULATION:
            raise RuntimeError(
                "Card population failure for %s at %s: want=%d got=%d"
                % (
                    scenario_name,
                    snapshot.get("checkpoint", "?"),
                    EXPECTED_CARD_POPULATION,
                    total,
                )
            )


'''
    helper_marker = "def _checkpoint_rows("
    require_count(text, helper_marker, 1, "soak checkpoint helper marker")
    text = text.replace(helper_marker, helper + helper_marker, 1)

    snapshot_marker = "    snapshots = gm._play_game_with_round_snapshots(game)\n"
    require_count(text, snapshot_marker, 1, "soak snapshot-build marker")
    validation = '''    scenario_name = (
        "soak_%s_vs_%s_s%d"
        % (
            player_zero_lord.lower(),
            player_one_lord.lower(),
            seed,
        )
    )
    validate_snapshot_card_population(
        snapshots,
        scenario_name,
    )
'''
    text = text.replace(
        snapshot_marker,
        snapshot_marker + validation,
        1,
    )

    old_name = '''        "name": (
            "soak_%s_vs_%s_s%d"
            % (
                player_zero_lord.lower(),
                player_one_lord.lower(),
                seed,
            )
        ),
'''
    new_name = '        "name": scenario_name,\n'
    require_count(text, old_name, 1, "soak scenario-name block")
    text = text.replace(old_name, new_name, 1)
    return text


def remove_resolution_diagnostic(text: str) -> str:
    required = (
        "DEBUG SOAK REFLEX BEFORE",
        "DEBUG SOAK REFLEX AFTER",
        "var debug_reflex_case: bool = (",
    )
    for marker in required:
        require_count(text, marker, 1, f"temporary Resolution marker {marker}")

    lines = text.splitlines(keepends=True)

    first_start = next(
        index
        for index, line in enumerate(lines)
        if "var debug_reflex_case: bool = (" in line
    )
    provider_start = next(
        index
        for index in range(first_start + 1, len(lines))
        if "var raw_reflex_bundle = reflex_provider.call(" in lines[index]
    )
    del lines[first_start:provider_start]

    provider_start = next(
        index
        for index, line in enumerate(lines)
        if "var raw_reflex_bundle = reflex_provider.call(" in line
    )
    second_start = next(
        index
        for index in range(provider_start + 1, len(lines))
        if lines[index].strip() == "if debug_reflex_case:"
    )
    second_end = next(
        index
        for index in range(second_start + 1, len(lines))
        if lines[index].lstrip().startswith("if typeof(")
    )
    del lines[second_start:second_end]

    updated = "".join(lines)
    if "DEBUG SOAK REFLEX" in updated or "debug_reflex_case" in updated:
        raise RuntimeError("REFUSED: Resolution diagnostic removal was incomplete")
    return updated


def remove_game_state_diagnostic(text: str) -> str:
    required = (
        "DEBUG SOAK FIRST PHYSICAL DUPLICATE",
        "func _debug_soak_card_identity() -> void:",
    )
    for marker in required:
        require_count(text, marker, 1, f"temporary GameState marker {marker}")

    lines = text.splitlines(keepends=True)
    call_indexes = [
        index
        for index, line in enumerate(lines)
        if line.strip() == "_debug_soak_card_identity()"
    ]
    if len(call_indexes) != 1:
        raise RuntimeError(
            "REFUSED: expected one temporary GameState diagnostic call, "
            f"found {len(call_indexes)}"
        )
    call_index = call_indexes[0]
    del lines[call_index]

    helper_start = next(
        index
        for index, line in enumerate(lines)
        if line.startswith("func _debug_soak_card_identity() -> void:")
    )
    helper_end = next(
        index
        for index in range(helper_start + 1, len(lines))
        if lines[index].startswith("func duplicate_state() -> GameState:")
    )
    del lines[helper_start:helper_end]

    updated = "".join(lines)
    if "_debug_soak_card_identity" in updated or "DEBUG SOAK FIRST" in updated:
        raise RuntimeError("REFUSED: GameState diagnostic removal was incomplete")
    return updated


PYTHON_REGRESSION = '''"""Regression checks for Kanifous Penitent temporary-Guard cleanup."""

import corruptor_sim as sim


def test_defeated_penitent_guard_is_not_discarded_twice():
    game = sim.Game(
        ["Orias"],
        ["Kanifous"],
    )
    player = game.players[1]

    for participant in game.players:
        participant.action = "Ward"

    defeated_guard = sim.Card(
        "Vulture",
        4,
    )

    # Combat already discarded it, while the temporary-Guard tracker still
    # points at that same physical object until Resolution cleanup.
    game.discard = [defeated_guard]
    player.penitent_temp_guards = [defeated_guard]

    game._phase_resolution([0, 1])

    assert game.discard == [defeated_guard]
    assert game.discard[0] is defeated_guard
    assert player.penitent_temp_guards == []
'''


def write_transaction(updates: dict[Path, tuple[str, str]]) -> None:
    temporary_paths: dict[Path, Path] = {}

    try:
        for path, (text, newline) in updates.items():
            temporary = path.with_name(path.name + ".penitent_fix.tmp")
            if temporary.exists():
                raise RuntimeError(
                    f"REFUSED: temporary path already exists: {temporary}"
                )
            temporary.write_bytes(text.replace("\n", newline).encode("utf-8"))
            temporary_paths[path] = temporary

        for path, temporary in temporary_paths.items():
            os.replace(temporary, path)
    finally:
        for temporary in temporary_paths.values():
            if temporary.exists():
                temporary.unlink()


def main() -> int:
    paths = {
        "python_sim": Path("corruptor_sim.py"),
        "godot_cleanup": Path("Scripts/Sim/ResolutionCleanupEngine.gd"),
        "godot_tests": Path("Scripts/Sim/ResolutionCleanupTests.gd"),
        "matrix_tests": Path("Scripts/Sim/LordMatrixTests.gd"),
        "soak_master": Path("lord_matrix_soak_master.py"),
        "resolution_engine": Path("Scripts/Sim/ResolutionEngine.gd"),
        "game_state": Path("Scripts/Sim/GameState.gd"),
    }
    regression_path = Path("tests/test_penitent_cleanup_conservation.py")

    missing = [str(path) for path in paths.values() if not path.is_file()]
    if missing:
        raise RuntimeError(
            "REFUSED: required files are missing: " + ", ".join(missing)
        )
    if regression_path.exists():
        raise RuntimeError(
            f"REFUSED: regression path already exists: {regression_path}"
        )

    originals: dict[str, tuple[str, str]] = {
        name: read_text(path)
        for name, path in paths.items()
    }

    python_sim, version_note = patch_python_sim(originals["python_sim"][0])
    updates: dict[Path, tuple[str, str]] = {
        paths["python_sim"]: (python_sim, originals["python_sim"][1]),
        paths["godot_cleanup"]: (
            patch_godot_cleanup(originals["godot_cleanup"][0]),
            originals["godot_cleanup"][1],
        ),
        paths["godot_tests"]: (
            patch_godot_cleanup_tests(originals["godot_tests"][0]),
            originals["godot_tests"][1],
        ),
        paths["matrix_tests"]: (
            patch_matrix_tests(originals["matrix_tests"][0]),
            originals["matrix_tests"][1],
        ),
        paths["soak_master"]: (
            patch_soak_master(originals["soak_master"][0]),
            originals["soak_master"][1],
        ),
        paths["resolution_engine"]: (
            remove_resolution_diagnostic(originals["resolution_engine"][0]),
            originals["resolution_engine"][1],
        ),
        paths["game_state"]: (
            remove_game_state_diagnostic(originals["game_state"][0]),
            originals["game_state"][1],
        ),
        regression_path: (PYTHON_REGRESSION, "\n"),
    }

    write_transaction(updates)

    print("Applied bilateral Penitent card-conservation correction.")
    print(version_note)
    print("Added focused Python and Godot regressions.")
    print("Added permanent matrix/soak card-population invariants.")
    print("Removed both temporary card-identity diagnostics.")
    print("No golden files, Git refs, commits, or retained batches were changed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
