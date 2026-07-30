#!/usr/bin/env python3
from pathlib import Path
import os


ROOT = Path(__file__).resolve().parent


def newline_for(data: bytes) -> bytes:
    crlf = data.count(b"\r\n")
    lf = data.count(b"\n")
    return b"\r\n" if crlf * 2 >= lf and lf > 0 else b"\n"


def line_start(data: bytes, position: int) -> int:
    previous = data.rfind(b"\n", 0, position)
    return 0 if previous < 0 else previous + 1


def positions(data: bytes, token: bytes, start: int = 0, end=None):
    if end is None:
        end = len(data)

    found = []
    position = start

    while True:
        position = data.find(token, position, end)

        if position < 0:
            return found

        found.append(position)
        position += len(token)


def replace_region(
    data: bytes,
    start_token: bytes,
    end_token: bytes,
    replacement_lf: bytes,
    label: str,
    search_start: int = 0,
) -> bytes:
    starts = positions(data, start_token, search_start)

    if not starts:
        raise SystemExit(
            f"REFUSED: missing {label} start anchor"
        )

    start = line_start(data, starts[0])
    ends = positions(data, end_token, starts[0] + len(start_token))

    if not ends:
        raise SystemExit(f"REFUSED: missing {label} end anchor")

    end = line_start(data, ends[0])

    if len(starts) > 1 and starts[1] < ends[0]:
        raise SystemExit(f"REFUSED: ambiguous {label} start anchor")

    if end <= start:
        raise SystemExit(f"REFUSED: invalid {label} region")

    replacement = replacement_lf.replace(b"\n", newline_for(data))
    return data[:start] + replacement + data[end:]


doctrine_path = ROOT / "Scripts/Sim/BotResolutionDoctrine.gd"
engine_path = ROOT / "Scripts/Sim/ResolutionEngine.gd"
tests_path = ROOT / "Scripts/Sim/BotResolutionDoctrineTests.gd"

paths = [
    doctrine_path,
    engine_path,
    tests_path,
]

for path in paths:
    if not path.is_file():
        raise SystemExit(f"REFUSED: missing expected file: {path}")

originals = {
    path: path.read_bytes()
    for path in paths
}

if b"gremory_provider_result_not_dictionary" not in originals[engine_path]:
    raise SystemExit("REFUSED: installed Gremory provider marker is missing")

if b"Late Gremory provider ignored the current Cleanup state." not in originals[tests_path]:
    raise SystemExit("REFUSED: installed Gremory regression marker is missing")

updated = dict(originals)

updated[doctrine_path] = replace_region(
    updated[doctrine_path],
    b"static func build_decisions(",
    b"static func action_choices(",
    b'''static func build_decisions(
\tgame,
\trules: RuleConfig,
\tcommitment_choices: Dictionary = {},
\trandom_source = null,
\tpolicy = null
) -> Dictionary:
\tassert(
\t\tgame != null,
\t\t"Bot Resolution doctrine requires a GameState."
\t)

\tassert(
\t\trules != null,
\t\t"Bot Resolution doctrine requires RuleConfig."
\t)

\tvar effective_policy = _policy_or_default(
\t\tpolicy
\t)

\tvar reflex_provider: Callable = Callable(
\t\tBotReflexDoctrineData,
\t\t"build_decisions"
\t).bind(
\t\trandom_source,
\t\teffective_policy
\t)

\tvar decisions: Dictionary = {
\t\t"actions": action_choices(
\t\t\tgame,
\t\t\trules,
\t\t\tcommitment_choices
\t\t),
\t\t"vessels": vessel_choices(
\t\t\tgame,
\t\t\trules
\t\t),
\t\t"reflex": {
\t\t\t"pass": true,
\t\t},
\t\t"odradek_breach": {},
\t\t"reflex_provider": reflex_provider,
\t\t"gremory": {},
\t\t"tie_first_player": int(
\t\t\tgame.first_player
\t\t),
\t}

\tdecisions["gremory"] = (
\t\t_preview_gremory_choices(
\t\t\tgame,
\t\t\trules,
\t\t\tdecisions,
\t\t\trandom_source
\t\t)
\t)

\t# The preview remains useful for inspection, but its payment can be
\t# stale after Resolution mutates Gremory's hand. Bot games therefore
\t# reevaluate at the exact pre-Cleanup boundary.
\tdecisions["gremory_provider"] = Callable(
\t\tBotResolutionDoctrineData,
\t\t"current_gremory_choices"
\t)

\treturn decisions


''',
    "Bot doctrine build_decisions",
)

updated[doctrine_path] = replace_region(
    updated[doctrine_path],
    b"static func action_choices(",
    b") -> Dictionary:",
    b'''static func action_choices(
\tgame,
\trules: RuleConfig,
\tcommitment_choices: Dictionary = {}
''',
    "Bot doctrine action_choices signature",
)

updated[doctrine_path] = replace_region(
    updated[doctrine_path],
    b"static func current_gremory_choices(",
    b"static func _preview_gremory_choices(",
    b'''static func current_gremory_choices(
\tgame,
\trules: RuleConfig
) -> Dictionary:
\tassert(
\t\tgame != null,
\t\t"Current Gremory doctrine requires a GameState."
\t)

\tassert(
\t\trules != null,
\t\t"Current Gremory doctrine requires RuleConfig."
\t)

\tvar choices: Dictionary = {}

\tif int(
\t\tgame.winner
\t) >= 0:
\t\treturn choices

\tfor player in game.players:
\t\tvar player_id: int = int(
\t\t\tplayer.pid
\t\t)

\t\tif (
\t\t\tplayer.lord != "Gremory"
\t\t\tor not player.alive
\t\t\tor player.gremory_inevitable_ruin_done
\t\t):
\t\t\tcontinue

\t\tvar opponent = game.get_opponent(
\t\t\tplayer_id
\t\t)

\t\tif opponent == null:
\t\t\tcontinue

\t\tvar target_castle: String = String(
\t\t\topponent.last_sieged_castle
\t\t)

\t\tif (
\t\t\tnot opponent.was_sieged
\t\t\tor target_castle.is_empty()
\t\t\tor not opponent.castles.has(
\t\t\t\ttarget_castle
\t\t\t)
\t\t):
\t\t\tcontinue

\t\t# Inevitable Ruin must retain two cards after payment.
\t\tif (
\t\t\tplayer.hand.size()
\t\t\t+ player.garrison.size()
\t\t\t< 4
\t\t):
\t\t\tcontinue

\t\t# Committed and Reflex cards have already left these zones at
\t\t# this boundary, so no prediction-time exclusions are needed.
\t\tvar payment: Array = (
\t\t\t_select_gremory_payment(
\t\t\t\tplayer,
\t\t\t\t[]
\t\t\t)
\t\t)

\t\tif payment.size() != 2:
\t\t\tcontinue

\t\tchoices[player_id] = {
\t\t\t"payment": payment,
\t\t}

\treturn choices


''',
    "current Gremory doctrine function",
)

updated[doctrine_path] = replace_region(
    updated[doctrine_path],
    b"static func _preview_gremory_choices(",
    b") -> Dictionary:",
    b'''static func _preview_gremory_choices(
\tgame,
\trules: RuleConfig,
\tbase_decisions: Dictionary,
\trandom_source = null
''',
    "Gremory preview signature",
)

updated[engine_path] = replace_region(
    updated[engine_path],
    b"var raw_gremory_provider = decisions.get(",
    b"var tie_first_player: int = int(",
    b'''\tvar raw_gremory_provider = decisions.get(
\t\t"gremory_provider",
\t\tnull
\t)

\tvar gremory_choices: Dictionary = (
\t\t_nested_dictionary(
\t\t\tdecisions,
\t\t\t"gremory"
\t\t)
\t)

''',
    "Resolution Gremory provider extraction",
)

finale_anchor = updated[engine_path].find(b"var finale_result: Dictionary")

if finale_anchor < 0:
    raise SystemExit("REFUSED: Resolution Finale anchor is missing")

updated[engine_path] = replace_region(
    updated[engine_path],
    b"if typeof(",
    b"var stopped_stage: String =",
    b'''\tif typeof(
\t\traw_gremory_provider
\t) == TYPE_CALLABLE:
\t\tvar gremory_provider: Callable = (
\t\t\traw_gremory_provider
\t\t)

\t\tif not gremory_provider.is_valid():
\t\t\treturn _invalid_result(
\t\t\t\tgame,
\t\t\t\t"cleanup",
\t\t\t\t"gremory_provider_invalid",
\t\t\t\tprelude_result,
\t\t\t\taction_events,
\t\t\t\treflex_result,
\t\t\t\tfinale_result,
\t\t\t\t{}
\t\t\t)

\t\tvar raw_gremory_choices = gremory_provider.call(
\t\t\tgame,
\t\t\trules
\t\t)

\t\tif typeof(
\t\t\traw_gremory_choices
\t\t) != TYPE_DICTIONARY:
\t\t\treturn _invalid_result(
\t\t\t\tgame,
\t\t\t\t"cleanup",
\t\t\t\t"gremory_provider_result_not_dictionary",
\t\t\t\tprelude_result,
\t\t\t\taction_events,
\t\t\t\treflex_result,
\t\t\t\tfinale_result,
\t\t\t\t{}
\t\t\t)

\t\tgremory_choices = raw_gremory_choices

\tvar cleanup_result: Dictionary = (
\t\tResolutionCleanupEngineData.resolve(
\t\t\tgame,
\t\t\trules,
\t\t\tgremory_choices
\t\t)
\t)

''',
    "Resolution pre-Cleanup provider block",
    finale_anchor,
)

preview_test_anchor = updated[tests_path].find(
    b'"Preview destroyed the real Keep."'
)

if preview_test_anchor < 0:
    raise SystemExit("REFUSED: Gremory preview test anchor is missing")

updated[tests_path] = replace_region(
    updated[tests_path],
    b"if _card_ids(",
    b"if String(",
    b'''\tif _card_ids(
\t\tgremory.committed
\t) != [
\t\t"Butcher:1",
\t]:
\t\treturn _fail(
\t\t\tGREMORY_TEST_NAME,
\t\t\t"Preview consumed the real Commitment."
\t\t)

\t# The provider must supersede a stale pre-resolution choice.
\tdecisions["gremory"] = {
\t\t0: {
\t\t\t"pass": true,
\t\t},
\t}

\tvar result: Dictionary = (
\t\tResolutionEngineData.resolve(
\t\t\tgame,
\t\t\trules,
\t\t\tdecisions
\t\t)
\t)

''',
    "Gremory preview provider-override test block",
    preview_test_anchor,
)

updated[tests_path] = replace_region(
    updated[tests_path],
    b"var late_fixture: Dictionary = _build_fixture(",
    b") -> Dictionary:",
    b'''\tvar late_fixture: Dictionary = _build_fixture(
\t\trules
\t)

\tif late_fixture.has(
\t\t"error"
\t):
\t\treturn _fail(
\t\t\tGREMORY_TEST_NAME,
\t\t\tString(
\t\t\t\tlate_fixture["error"]
\t\t\t)
\t\t)

\tvar late_game = late_fixture["game"]
\tvar late_gremory = late_fixture["p0"]
\tvar late_defender = late_fixture["p1"]

\t_prepare_game(
\t\tlate_game
\t)

\tlate_game.first_player = 0

\tlate_gremory.lord = "Gremory"
\tlate_gremory.alive = true
\tlate_gremory.action = ""
\tlate_gremory.gremory_inevitable_ruin_done = false
\tlate_gremory.hand = _cards_from_ids([
\t\t"Butcher:5",
\t])
\tlate_gremory.garrison.clear()

\tlate_defender.lord = "Valak"
\tlate_defender.alive = true
\tlate_defender.action = ""

\t_set_castles(
\t\tlate_defender,
\t\t[
\t\t\t"Keep",
\t\t]
\t)

\tlate_defender.was_sieged = false
\tlate_defender.last_sieged_castle = ""

\tvar late_decisions: Dictionary = (
\t\tBotResolutionDoctrineData
\t\t.build_decisions(
\t\t\tlate_game,
\t\t\trules,
\t\t\t{},
\t\t\tnull,
\t\t\tBotPolicyData.golden_core()
\t\t)
\t)

\tvar stale_gremory_choices: Dictionary = (
\t\t_nested_dictionary(
\t\t\tlate_decisions,
\t\t\t"gremory"
\t\t)
\t)

\tif not _decision_for_player(
\t\tstale_gremory_choices,
\t\t0
\t).is_empty():
\t\treturn _fail(
\t\t\tGREMORY_TEST_NAME,
\t\t\t"Pre-resolution Gremory choice was unexpectedly available."
\t\t)

\t# Simulate the exact state transition exposed by soak seed
\t# 1493006176: resolution supplies enough cards and creates a valid
\t# surviving Siege target after the original bundle was built.
\tlate_gremory.hand = _cards_from_ids([
\t\t"Butcher:1",
\t\t"Wright:2",
\t\t"Vulture:3",
\t\t"Butcher:5",
\t])

\tlate_defender.was_sieged = true
\tlate_defender.last_sieged_castle = "Keep"

\tvar raw_gremory_provider = late_decisions.get(
\t\t"gremory_provider",
\t\tnull
\t)

\tif typeof(
\t\traw_gremory_provider
\t) != TYPE_CALLABLE:
\t\treturn _fail(
\t\t\tGREMORY_TEST_NAME,
\t\t\t"Gremory cleanup provider was not installed."
\t\t)

\tvar gremory_provider: Callable = raw_gremory_provider

\tif not gremory_provider.is_valid():
\t\treturn _fail(
\t\t\tGREMORY_TEST_NAME,
\t\t\t"Gremory cleanup provider was invalid."
\t\t)

\tvar raw_current_choices = gremory_provider.call(
\t\tlate_game,
\t\trules
\t)

\tif typeof(
\t\traw_current_choices
\t) != TYPE_DICTIONARY:
\t\treturn _fail(
\t\t\tGREMORY_TEST_NAME,
\t\t\t"Gremory cleanup provider returned the wrong type."
\t\t)

\tvar current_choices: Dictionary = raw_current_choices
\tvar current_decision: Dictionary = (
\t\t_decision_for_player(
\t\t\tcurrent_choices,
\t\t\t0
\t\t)
\t)

\tif _payment_signatures(
\t\tcurrent_decision.get(
\t\t\t"payment",
\t\t\t[]
\t\t)
\t) != [
\t\t"Hand>Butcher:1",
\t\t"Hand>Wright:2",
\t]:
\t\treturn _fail(
\t\t\tGREMORY_TEST_NAME,
\t\t\t"Late Gremory provider ignored the current Cleanup state."
\t\t)

\treturn _pass(
\t\tGREMORY_TEST_NAME
\t)


static func _build_fixture(
\trules: RuleConfig
''',
    "late Gremory provider regression and fixture signature",
)

temporary_paths = {}

try:
    for path in paths:
        temporary = path.with_name(path.name + ".tmp")

        if temporary.exists():
            raise SystemExit(
                f"REFUSED: temporary path already exists: {temporary}"
            )

        temporary.write_bytes(updated[path])
        temporary_paths[path] = temporary

    for path in paths:
        os.replace(temporary_paths[path], path)
finally:
    for temporary in temporary_paths.values():
        if temporary.exists():
            temporary.unlink()

print("Repaired Gremory provider patch indentation and adjacent signatures.")
print("No Python oracle, golden file, policy/version string, or Git ref was changed.")
