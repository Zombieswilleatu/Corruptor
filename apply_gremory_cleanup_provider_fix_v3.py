#!/usr/bin/env python3
from pathlib import Path
import os
import re


ROOT = Path(__file__).resolve().parent


def replace_once(
    data: bytes,
    old_lf: bytes,
    new_lf: bytes,
    label: str,
) -> bytes:
    def line_pattern(part: bytes) -> bytes:
        stripped = part.strip(b" \t")

        if not stripped:
            return b"[ \t]*"

        return b"[ \t]*" + re.escape(stripped) + b"[ \t]*"

    pattern = re.compile(
        b"\r?\n".join(
            line_pattern(part)
            for part in old_lf.split(b"\n")
        )
    )
    matches = list(pattern.finditer(data))
    count = len(matches)

    if count != 1:
        raise SystemExit(
            f"REFUSED: expected {label} exactly once, found {count}"
        )

    match = matches[0]
    matched = match.group(0)
    newline = (
        b"\r\n"
        if matched.count(b"\r\n") * 2 >= matched.count(b"\n")
        else b"\n"
    )
    new = new_lf.replace(b"\n", newline)

    return data[:match.start()] + new + data[match.end():]


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

if b"gremory_provider_result_not_dictionary" in originals[engine_path]:
    raise SystemExit("REFUSED: Gremory cleanup provider fix is already installed")

updated = dict(originals)

updated[doctrine_path] = replace_once(
    updated[doctrine_path],
    b'''        return decisions


static func action_choices(
''',
    b'''        # The preview remains useful for inspection, but its payment can be
        # stale after Resolution mutates Gremory's hand. Bot games therefore
        # reevaluate at the exact pre-Cleanup boundary.
        decisions["gremory_provider"] = Callable(
                BotResolutionDoctrineData,
                "current_gremory_choices"
        )

        return decisions


static func action_choices(
''',
    "Gremory decision-build return anchor",
)

updated[doctrine_path] = replace_once(
    updated[doctrine_path],
    b'''static func _preview_gremory_choices(
''',
    b'''static func current_gremory_choices(
        game,
        rules: RuleConfig
) -> Dictionary:
        assert(
                game != null,
                "Current Gremory doctrine requires a GameState."
        )

        assert(
                rules != null,
                "Current Gremory doctrine requires RuleConfig."
        )

        var choices: Dictionary = {}

        if int(
                game.winner
        ) >= 0:
                return choices

        for player in game.players:
                var player_id: int = int(
                        player.pid
                )

                if (
                        player.lord != "Gremory"
                        or not player.alive
                        or player.gremory_inevitable_ruin_done
                ):
                        continue

                var opponent = game.get_opponent(
                        player_id
                )

                if opponent == null:
                        continue

                var target_castle: String = String(
                        opponent.last_sieged_castle
                )

                if (
                        not opponent.was_sieged
                        or target_castle.is_empty()
                        or not opponent.castles.has(
                                target_castle
                        )
                ):
                        continue

                # Inevitable Ruin must retain two cards after payment.
                if (
                        player.hand.size()
                        + player.garrison.size()
                        < 4
                ):
                        continue

                # Committed and Reflex cards have already left these zones at
                # this boundary, so no prediction-time exclusions are needed.
                var payment: Array = (
                        _select_gremory_payment(
                                player,
                                []
                        )
                )

                if payment.size() != 2:
                        continue

                choices[player_id] = {
                        "payment": payment,
                }

        return choices


static func _preview_gremory_choices(
''',
    "Gremory preview function anchor",
)

updated[engine_path] = replace_once(
    updated[engine_path],
    b'''    var raw_reflex_provider = decisions.get(
            "reflex_provider",
            null
    )

    var gremory_choices: Dictionary = (
''',
    b'''    var raw_reflex_provider = decisions.get(
            "reflex_provider",
            null
    )

    var raw_gremory_provider = decisions.get(
            "gremory_provider",
            null
    )

    var gremory_choices: Dictionary = (
''',
    "Resolution provider extraction block",
)

updated[engine_path] = replace_once(
    updated[engine_path],
    b'''    var cleanup_result: Dictionary = (
            ResolutionCleanupEngineData.resolve(
                    game,
                    rules,
                    gremory_choices
            )
    )
''',
    b'''    if typeof(
            raw_gremory_provider
    ) == TYPE_CALLABLE:
            var gremory_provider: Callable = (
                    raw_gremory_provider
            )

            if not gremory_provider.is_valid():
                    return _invalid_result(
                            game,
                            "cleanup",
                            "gremory_provider_invalid",
                            prelude_result,
                            action_events,
                            reflex_result,
                            finale_result,
                            {}
                    )

            var raw_gremory_choices = gremory_provider.call(
                    game,
                    rules
            )

            if typeof(
                    raw_gremory_choices
            ) != TYPE_DICTIONARY:
                    return _invalid_result(
                            game,
                            "cleanup",
                            "gremory_provider_result_not_dictionary",
                            prelude_result,
                            action_events,
                            reflex_result,
                            finale_result,
                            {}
                    )

            gremory_choices = raw_gremory_choices

    var cleanup_result: Dictionary = (
            ResolutionCleanupEngineData.resolve(
                    game,
                    rules,
                    gremory_choices
            )
    )
''',
    "Resolution Cleanup call block",
)

updated[tests_path] = replace_once(
    updated[tests_path],
    b'''  if _card_ids(
          gremory.committed
  ) != [
          "Butcher:1",
  ]:
          return _fail(
                  GREMORY_TEST_NAME,
                  "Preview consumed the real Commitment."
          )

  var result: Dictionary = (
          ResolutionEngineData.resolve(
''',
    b'''  if _card_ids(
          gremory.committed
  ) != [
          "Butcher:1",
  ]:
          return _fail(
                  GREMORY_TEST_NAME,
                  "Preview consumed the real Commitment."
          )

  # The provider must supersede a stale pre-resolution choice.
  decisions["gremory"] = {
          0: {
                  "pass": true,
          },
  }

  var result: Dictionary = (
          ResolutionEngineData.resolve(
''',
    "Gremory preview Resolution call anchor",
)

updated[tests_path] = replace_once(
    updated[tests_path],
    b'''  return _pass(
          GREMORY_TEST_NAME
  )


static func _build_fixture(
''',
    b'''  var late_fixture: Dictionary = _build_fixture(
          rules
  )

  if late_fixture.has(
          "error"
  ):
          return _fail(
                  GREMORY_TEST_NAME,
                  String(
                          late_fixture["error"]
                  )
          )

  var late_game = late_fixture["game"]
  var late_gremory = late_fixture["p0"]
  var late_defender = late_fixture["p1"]

  _prepare_game(
          late_game
  )

  late_game.first_player = 0

  late_gremory.lord = "Gremory"
  late_gremory.alive = true
  late_gremory.action = ""
  late_gremory.gremory_inevitable_ruin_done = false
  late_gremory.hand = _cards_from_ids([
          "Butcher:5",
  ])
  late_gremory.garrison.clear()

  late_defender.lord = "Valak"
  late_defender.alive = true
  late_defender.action = ""

  _set_castles(
          late_defender,
          [
                  "Keep",
          ]
  )

  late_defender.was_sieged = false
  late_defender.last_sieged_castle = ""

  var late_decisions: Dictionary = (
          BotResolutionDoctrineData
          .build_decisions(
                  late_game,
                  rules,
                  {},
                  null,
                  BotPolicyData.golden_core()
          )
  )

  var stale_gremory_choices: Dictionary = (
          _nested_dictionary(
                  late_decisions,
                  "gremory"
          )
  )

  if not _decision_for_player(
          stale_gremory_choices,
          0
  ).is_empty():
          return _fail(
                  GREMORY_TEST_NAME,
                  "Pre-resolution Gremory choice was unexpectedly available."
          )

  # Simulate the exact state transition exposed by soak seed
  # 1493006176: resolution supplies enough cards and creates a valid
  # surviving Siege target after the original bundle was built.
  late_gremory.hand = _cards_from_ids([
          "Butcher:1",
          "Wright:2",
          "Vulture:3",
          "Butcher:5",
  ])

  late_defender.was_sieged = true
  late_defender.last_sieged_castle = "Keep"

  var raw_gremory_provider = late_decisions.get(
          "gremory_provider",
          null
  )

  if typeof(
          raw_gremory_provider
  ) != TYPE_CALLABLE:
          return _fail(
                  GREMORY_TEST_NAME,
                  "Gremory cleanup provider was not installed."
          )

  var gremory_provider: Callable = raw_gremory_provider

  if not gremory_provider.is_valid():
          return _fail(
                  GREMORY_TEST_NAME,
                  "Gremory cleanup provider was invalid."
          )

  var raw_current_choices = gremory_provider.call(
          late_game,
          rules
  )

  if typeof(
          raw_current_choices
  ) != TYPE_DICTIONARY:
          return _fail(
                  GREMORY_TEST_NAME,
                  "Gremory cleanup provider returned the wrong type."
          )

  var current_choices: Dictionary = raw_current_choices
  var current_decision: Dictionary = (
          _decision_for_player(
                  current_choices,
                  0
          )
  )

  if _payment_signatures(
          current_decision.get(
                  "payment",
                  []
          )
  ) != [
          "Hand>Butcher:1",
          "Hand>Wright:2",
  ]:
          return _fail(
                  GREMORY_TEST_NAME,
                  "Late Gremory provider ignored the current Cleanup state."
          )

  return _pass(
          GREMORY_TEST_NAME
  )


static func _build_fixture(
''',
    "Gremory preview test return anchor",
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

print("Installed late-bound Gremory Cleanup doctrine and regression coverage.")
print("No Python oracle, golden file, policy/version string, or Git ref was changed.")
