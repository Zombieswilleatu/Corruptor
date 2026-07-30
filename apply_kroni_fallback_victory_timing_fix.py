from __future__ import annotations

import os
from pathlib import Path


ENGINE_PATH = Path("Scripts/Sim/ResolutionFinaleEngine.gd")
MATRIX_PATH = Path("Scripts/Sim/LordMatrixTests.gd")
TEST_PATH = Path("Scripts/Sim/ResolutionFinaleTests.gd")


def with_newline(block: bytes, newline: bytes) -> bytes:
    return block.replace(b"\n", newline)


def replace_once(
    data: bytes,
    old_lf: bytes,
    new_lf: bytes,
    newline: bytes,
    label: str,
) -> bytes:
    old = with_newline(old_lf, newline)
    new = with_newline(new_lf, newline)
    count = data.count(old)

    if count != 1:
        raise SystemExit(
            f"REFUSED: expected {label} exactly once, found {count}"
        )

    return data.replace(old, new, 1)


def load(path: Path) -> tuple[bytes, bytes]:
    if not path.is_file():
        raise SystemExit(f"REFUSED: required file is missing: {path}")

    data = path.read_bytes()
    newline = b"\r\n" if b"\r\n" in data else b"\n"
    return data, newline


engine, engine_newline = load(ENGINE_PATH)
matrix, matrix_newline = load(MATRIX_PATH)
tests, tests_newline = load(TEST_PATH)

installed_markers = (
    b"unit_finale_kroni_fallback_victory_timing" in tests,
    b"static func check_win(" in engine,
    b"victory deferred by" in matrix,
)

if any(installed_markers):
    if all(installed_markers):
        raise SystemExit(
            "REFUSED: Kroni fallback victory-timing fix is already installed"
        )

    raise SystemExit(
        "REFUSED: partial Kroni fallback victory-timing installation detected"
    )

engine = replace_once(
    engine,
    b'''\
\t\tif bool(
\t\t\tfallback_event.get(
\t\t\t\t"triggered",
\t\t\t\tfalse
\t\t\t)
\t\t):
\t\t\tfallback_events.append(
\t\t\t\tfallback_event
\t\t\t)

\t\t\tif _check_win(
\t\t\t\tgame,
\t\t\t\trules
\t\t\t):
\t\t\t\tgame.refresh_derived_values()

\t\t\t\treturn _result(
\t\t\t\t\tgame,
\t\t\t\t\tdecay_events,
\t\t\t\t\tfallback_events,
\t\t\t\t\tbreach_events,
\t\t\t\t\treconfiguration_events,
\t\t\t\t\tstate_events,
\t\t\t\t\ttrue
\t\t\t\t)
''',
    b'''\
\t\tif bool(
\t\t\tfallback_event.get(
\t\t\t\t"triggered",
\t\t\t\tfalse
\t\t\t)
\t\t):
\t\t\tfallback_events.append(
\t\t\t\tfallback_event
\t\t\t)

\t\t\t# Python defers the victory checkpoint created by fallback
\t\t\t# Consume until after the completed-round snapshot. Finale must
\t\t\t# still resolve Breach passives and persistent state updates.
''',
    engine_newline,
    "Finale fallback victory block",
)

engine = replace_once(
    engine,
    b'''\
static func _check_win(
\tgame,
\trules: RuleConfig
) -> bool:
''',
    b'''\
static func check_win(
\tgame,
\trules: RuleConfig
) -> bool:
\treturn _check_win(
\t\tgame,
\t\trules
\t)


static func _check_win(
\tgame,
\trules: RuleConfig
) -> bool:
''',
    engine_newline,
    "Finale victory helper anchor",
)

matrix = replace_once(
    matrix,
    b'''\
const BotRoundEngineData = preload(
\t"res://Scripts/Sim/BotRoundEngine.gd"
)

const BotGameEngineData = preload(
''',
    b'''\
const BotRoundEngineData = preload(
\t"res://Scripts/Sim/BotRoundEngine.gd"
)

const ResolutionFinaleEngineData = preload(
\t"res://Scripts/Sim/ResolutionFinaleEngine.gd"
)

const BotGameEngineData = preload(
''',
    matrix_newline,
    "matrix Finale preload anchor",
)

matrix = replace_once(
    matrix,
    b'''\
\t\tsnapshots.append(
\t\t\tGoldenSnapshotSerializerData.snapshot_game(
\t\t\t\tgame,
\t\t\t\t"round:%02d:end"
\t\t\t\t% next_round,
\t\t\t\trules
\t\t\t)
\t\t)

\tif int(
''',
    b'''\
\t\tsnapshots.append(
\t\t\tGoldenSnapshotSerializerData.snapshot_game(
\t\t\t\tgame,
\t\t\t\t"round:%02d:end"
\t\t\t\t% next_round,
\t\t\t\trules
\t\t\t)
\t\t)

\t\t# Python's round-snapshot harness evaluates any victory deferred by
\t\t# end-of-round effects only after recording round:NN:end.
\t\tif int(game.winner) < 0:
\t\t\tResolutionFinaleEngineData.check_win(
\t\t\t\tgame,
\t\t\t\trules
\t\t\t)

\tif int(
''',
    matrix_newline,
    "matrix post-snapshot victory anchor",
)

tests = replace_once(
    tests,
    b'''\
const KRONI_BREACH_TEST_NAME := (
\t"unit_finale_kroni_breach"
)

const ODRADEK_TEAR_TEST_NAME := (
''',
    b'''\
const KRONI_BREACH_TEST_NAME := (
\t"unit_finale_kroni_breach"
)

const KRONI_FALLBACK_VICTORY_TIMING_TEST_NAME := (
\t"unit_finale_kroni_fallback_victory_timing"
)

const ODRADEK_TEAR_TEST_NAME := (
''',
    tests_newline,
    "Finale test-name anchor",
)

tests = replace_once(
    tests,
    b'''\
\t\t_test_kroni_breach(
\t\t\trules
\t\t),
\t\t_test_odradek_reconfiguration(
''',
    b'''\
\t\t_test_kroni_breach(
\t\t\trules
\t\t),
\t\t_test_kroni_fallback_victory_timing(
\t\t\trules
\t\t),
\t\t_test_odradek_reconfiguration(
''',
    tests_newline,
    "Finale test registration anchor",
)

new_test_lf = b'''\
static func _test_kroni_fallback_victory_timing(
\trules: RuleConfig
) -> Dictionary:
\tvar fixture: Dictionary = _build_fixture(
\t\trules
\t)

\tif fixture.has(
\t\t"error"
\t):
\t\treturn _fail(
\t\t\tKRONI_FALLBACK_VICTORY_TIMING_TEST_NAME,
\t\t\tString(
\t\t\t\tfixture["error"]
\t\t\t)
\t\t)

\tvar game = fixture["game"]
\tvar gremory = fixture["p0"]
\tvar kroni = fixture["p1"]

\t_prepare_game(
\t\tgame
\t)

\tgame.breach = "Kroni"
\tgame.breach_owner = 1
\tgame.neutral_tears = 8

\tgremory.lord = "Gremory"
\tgremory.action = "Siege"
\tgremory.prev_ward_target = "Castle"
\tgremory.castle_guards = _cards_from_ids([
\t\t"Vulture:2",
\t])

\tkroni.lord = "Kroni"
\tkroni.action = "Hunt"
\tkroni.tears = 2
\tkroni.kroni_hunger = 2
\tkroni.kroni_consume_done = false
\tkroni.kroni_tear_milestone_fired = false
\tkroni.castle_guards = _cards_from_ids([
\t\t"Penitent:1",
\t\t"Butcher:4",
\t])

\tvar result: Dictionary = (
\t\tResolutionFinaleEngineData.resolve(
\t\t\tgame,
\t\t\trules
\t\t)
\t)

\tif int(game.winner) >= 0:
\t\treturn _fail(
\t\t\tKRONI_FALLBACK_VICTORY_TIMING_TEST_NAME,
\t\t\t"Fallback victory was not deferred past Finale."
\t\t)

\tif bool(
\t\tresult.get(
\t\t\t"stopped_on_win",
\t\t\ttrue
\t\t)
\t):
\t\treturn _fail(
\t\t\tKRONI_FALLBACK_VICTORY_TIMING_TEST_NAME,
\t\t\t"Finale stopped before post-fallback passives."
\t\t)

\tif not gremory.castle_guards.is_empty():
\t\treturn _fail(
\t\t\tKRONI_FALLBACK_VICTORY_TIMING_TEST_NAME,
\t\t\t"Kroni Breach did not resolve for Gremory."
\t\t)

\tif not kroni.castle_guards.is_empty():
\t\treturn _fail(
\t\t\tKRONI_FALLBACK_VICTORY_TIMING_TEST_NAME,
\t\t\t"Kroni Breach did not resolve after fallback Consume."
\t\t)

\tif gremory.prev_ward_target != "":
\t\treturn _fail(
\t\t\tKRONI_FALLBACK_VICTORY_TIMING_TEST_NAME,
\t\t\t"Finale skipped the Ward-history update."
\t\t)

\tif _card_ids(
\t\tgame.discard
\t) != [
\t\t"Penitent:1",
\t\t"Vulture:2",
\t\t"Butcher:4",
\t]:
\t\treturn _fail(
\t\t\tKRONI_FALLBACK_VICTORY_TIMING_TEST_NAME,
\t\t\t"Fallback and Breach effects resolved in the wrong order."
\t\t)

\tif not ResolutionFinaleEngineData.check_win(
\t\tgame,
\t\trules
\t):
\t\treturn _fail(
\t\t\tKRONI_FALLBACK_VICTORY_TIMING_TEST_NAME,
\t\t\t"Deferred victory checkpoint found no winner."
\t\t)

\tif (
\t\tint(game.winner) != 1
\t\tor String(game.win_by) != "Dominion"
\t):
\t\treturn _fail(
\t\t\tKRONI_FALLBACK_VICTORY_TIMING_TEST_NAME,
\t\t\t"Deferred checkpoint selected the wrong victory."
\t\t)

\treturn _pass(
\t\tKRONI_FALLBACK_VICTORY_TIMING_TEST_NAME
\t)


'''

tests = replace_once(
    tests,
    b'''\
static func _test_odradek_reconfiguration(
''',
    new_test_lf + b'''\
static func _test_odradek_reconfiguration(
''',
    tests_newline,
    "Finale regression-test insertion anchor",
)

updated = {
    ENGINE_PATH: engine,
    MATRIX_PATH: matrix,
    TEST_PATH: tests,
}

temporary_paths: list[Path] = []

try:
    for path, data in updated.items():
        temporary = path.with_name(path.name + ".tmp")

        if temporary.exists():
            raise SystemExit(
                f"REFUSED: temporary path already exists: {temporary}"
            )

        temporary.write_bytes(data)
        temporary_paths.append(temporary)

    for path in updated:
        temporary = path.with_name(path.name + ".tmp")
        os.replace(temporary, path)
        temporary_paths.remove(temporary)
finally:
    for temporary in temporary_paths:
        if temporary.exists():
            temporary.unlink()

print("Installed Kroni fallback victory-timing parity fix and regression test.")
print("No Python oracle, golden data, retained batch, or Git ref was changed.")
