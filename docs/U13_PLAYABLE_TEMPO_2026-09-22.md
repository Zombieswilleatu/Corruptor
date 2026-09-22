# Promoted playable: split Ward and round-20 tempo

New games in the main U13 playable now use the round-20 arm. The earlier round-18
comparison remains historical experiment evidence; it is not the live default.
The performance improvements already present on the doctrine branch are retained.

## Rules

- One paid Ward alone, or one paid Ward alongside Hunt or Siege. Payments are
  disjoint across combat, guards, resummoning, powers, work and invocation.
- Ward recruits at 2:1 printed suit value and protects its chosen lane only.
  Hunt/Siege retain 3:1 recruits and recipe summons. Ward cannot summon recipes;
  existing battlefield and staged monsters retain their normal behavior.
- No Sigils, free Ward defense, or Sigil-based threat reduction in this profile.
  A real attack prevented by the chosen-lane Ward earns its defender one Soul,
  capped at one per round. The authority replays that attack on an isolated world
  without the Ward screen, preserving the keyed randomness and discarding all
  counterfactual state and events. Merely reducing damage does not earn a Soul.
- Veil 13/17/21 adds +1/+2/+3 to committed Hunt/Siege strength, not every unit.
- From round 20, an actual Hunt banishment or Siege target destruction earns
  one additional Soul per player per round. Pillage and artillery do not qualify.
- Ritual remains 12 Souls with a living Lord. Dominion remains Veil 12+, at
  least five personal Tears and a strict Tear lead. Ritual is checked first.
- Veil no longer triggers Final Collapse. After normal victory checks, round 25
  ends the game by Souls; the existing seat-zero Soul-tie rule remains.

In Combat, select Ward, its lane and cards, then **RESERVE WARD**. Select Hunt or
Siege using the remaining hand. The reserved cards appear on their lane and can
be returned individually or with **CLEAR RESERVED WARD**. A reserved Ward can
also resolve alone. Profane cannot accompany a reserved Ward.

Forecasts, Veil milestones, rules text, the aftermath ledger and the round-limit
result describe the promoted rules. New playable saves retain the explicit
profile flags. Existing saves and old replay setups keep their recorded legacy
profile; loading an old game does not silently migrate its rules.

## Why round 20

The 162-game roster screen averaged 14.56 rounds: 88 games below 15, 64 in 15–20,
and ten above 20. Endings were 95 Dominion and 67 Ritual, with no round-limit
finish. The paired round-18 comparison saved only five rounds across the same
162 cases (mean 14.52), while doubling extra decisive Souls from 20 to 40.

This is a playable baseline, not a claim that the 15–20-round target is achieved.
Early endings remain common and Lord balance needs attention; Kroni won 29 of
32 nonmirror games. Nonmirror seat-zero wins were 70/144 (48.6%); Reflex order
and terminal ties have not been changed by this promotion.

See the roster and timing reports for sample scope, reuse methodology and
individual results. No 810-game rerun was performed for this integration.

## Focused verification

Godot 4.7.2 stable, official Linux build, SHA-256
`cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`.

- 46 Python rule, recipe, bot-diagnostic and baseline-runner tests.
- Native Ward recipe, playable board, staging, action forecast, Veil wheel,
  legacy Sigils and legacy victory suites, plus the playable session suite.
- Four fresh two-round parity games, two seeds with reversed seats, two workers:
  204 operations, 507 semantic events. Every complete world, event addition and
  native snapshot restoration matches. Both sides start independently from
  setup; expected worlds are never installed into game authority.
- 26 directed Python/Godot parity fixtures cover causal Ward saves, overpowered
  and already-stopped attacks, wrong-lane Ward, guard interception, all Veil
  attack thresholds, the 19/20 Soul boundary, reward caps and exclusions,
  Ritual/Dominion priority and round-25 Soul ties.
- UI coverage includes reserving a Ward, separate Hunt payment, returning cards,
  duplicate-payment rejection, recipe rejection and combined-cart save/restore.

Several inherited fixtures predated recent rules: staging still attempted Ward
summons, forecast fixtures did not draw their cards, and the legacy victory test
asserted that Veil effects were disabled. These fixtures now exercise legal
summons, explicitly drawn hands, and the configured Veil profile. The gate
rejects GDScript errors even when a test runner exits zero.

Reproduce the focused gate from the repository root:

```sh
PYTHONPATH=Scripts/Sim python -m unittest u13_doctrine.test_split_ward u13_doctrine.test_ward_recipes u13_doctrine.test_diagnostics test_u13_ward_runner -q
python Scripts/Sim/check_u13_playable_tempo.py --godot /path/to/Godot_v4.7.2-stable
```

The checked-in CI workflow runs these same checks. Historical round-18 replay
comparisons should use their frozen round-18 source, not this promoted round-20
source.
