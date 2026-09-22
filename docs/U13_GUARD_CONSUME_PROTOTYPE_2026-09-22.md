# Consume: neutral guard bounce prototype

Implemented locally, not pushed. Activate Consume without choosing a lane,
position or guard. At its existing next-round scheduled hook, Kroni launches
from the center of a fixed logical guard arena. His initial vertical direction
has a 60% chance to favor enemy territory, then ordinary wall bounces and the
first guard collision choose the meal. Horizontal direction and angle are
keyed random choices. Allegiance has no effect after launch.

An enemy guard grants one Hunger; a friendly guard grants none. Either meal
satisfies Cannibal Hunger for that round. The first meal ends the flight. No
guards at declaration means no activation; if all guards disappear before
resolution, the flight misses and normal Cannibal Hunger applies. A banished
Kroni cannot perform the bite. Ravenous retains the eleven-enemy reward rule;
there are no monster prices, stat changes or attack-bonus timing changes.

## Geometry and presentation

The authority uses the two vertical Lord-guard columns and two horizontal
Castle-guard rows in a fixed 1000-by-1000 logical arena. Its center launch is
between the players and between Lord and Castle guards, approximately behind
the usual modal. The visual maps the logical axes to the actual slot centers,
including the central gap; window size cannot alter the chosen victim.

The event records the initial direction, bounce path, elapsed logical ticks
and victim. Board playback follows that recorded path, then plays the existing
chomp. Travel takes 0.6–2.5 seconds, followed by the chomp; skipping restores
slot visibility without repeating gameplay. This has headless board integration
coverage; its visual feel still needs a human playtest.

The path has a deterministic 2048-tick safety bound. All 288 combinations of a
single occupied slot and initial direction found that guard, at most 1178
ticks. Thus the tested discrete direction set always found a meal even on the
sparsest nonempty board. No fallback secretly selects an enemy guard.

One thousand seeded full-board launches produced 582 initial enemy directions
and 539 enemy meals (53.9%). This measures that occupied layout, not a universal
meal probability. Sparse layouts and guard placement affect actual risk.
Mirroring player ownership and physical positions preserves paths and victims;
vertical Lord-slot indices reverse under that physical reflection.

## Rules, bot and compatibility

Python and Godot recognize the new neutral-launch declaration. The main board
and native sample planner emit it, as does the Python doctrine. The bot compares
public possible routes with the 60/40 launch weighting and accounts for friendly
loss, enemy value, pairs and feeding. It has no seed, future guard layout or
promised-victim knowledge. The former opposite-attack-lane restriction does not
apply to a neutral flight.

Existing exact-target declarations remain supported for legacy pending orders
and recorded replays. The current UI and bot do not generate them. This is a
local prototype rather than a final versioned removal of the legacy command.

## One-game probe

Same seed, seats, castle loadout and policy weights as the earlier
`kroni_odradek_00_tempo` probes. Both bots replanned. Both players could summon
free recipe monsters. Exactly one new full game ran.

| Measure (Kroni / Odradek) | Historical exact Consume | Neutral bounce |
|---|---|---|
| Winner | Kroni | Kroni |
| Finish | Round 9, Ritual | Round 14, Dominion |
| Final Souls | 12 / 1 | 6 / 4 |
| Personal Tears | 1 / 1 | 5 / 3 |
| Consume meals: enemy / friendly | 4 / 0 | 3 / 3 |
| Own guards lost to automatic Cannibal Hunger | 4 | 7 |
| Ravenous uses | 1 | 0 |
| Kroni final Siege targets destroyed | 4 | 3 |

Neutral meals, in order: friendly Lord guard value 2; enemy Lord 5; friendly
Lord 5; enemy Lord 2; enemy Castle 4; friendly Lord 5. Kroni lost ten of his own
guards overall: seven automatic meals plus three neutral-Consume meals.

The prior no-Consume experiment ended with Odradek winning by Ritual in round
15. These three results suggest the prototype retains useful power while
introducing consequential risk, but one seed is not a balance verdict. The
historical exact-Consume control used the former Ravenous threshold and bot
scoring; its recorded operations reproduce the same result under the new
threshold, but it is not a freshly replanned matched control. No claim isolates
Consume's effect from every policy adjustment.

## Validation

- 23 focused Python tests passed: routes, ownership, reward limits, doctrine,
  coordination, physical seat reflection and deterministic repeat.
- Native guard-Consume suite: 784 checks, zero failures.
- Cross-runtime parity: 200 keyed routes plus 24 resolved meals. Events and
  their player views, remaining entities, player resources and feeding flags
  matched. The legacy native scenario requires an empty later guard-pair ledger
  on the Python side; this is fixture setup, not installing expected results.
- Existing native Kroni suite: 973/973 checks.
- Updated native Kroni board suite: zero failures, including one-click queue,
  delayed resolution, recorded flight, neutral mapping and safe skip.
- One full game completed with zero rejected previews or invalid submissions.

The unrelated `test_useful_projection_is_still_available` Valak fixture still
fails. Its identical failure was reproduced in an isolated checkout of parent
`927e90c`; it is not counted among the 23 passing checks or silently changed.

[Game evidence](evidence/U13_GUARD_CONSUME_PROBE_2026-09-22.json) and
[decision trace](evidence/U13_GUARD_CONSUME_PROBE_2026-09-22.trace.json.gz).

Reproduce the directed native/Python check:

```sh
godot --headless --path . --script Scripts/Sim/U13GuardConsumeTestRunner.gd -- /tmp/guard-consume.json
PYTHONPATH=Scripts/Sim python Scripts/Sim/verify_u13_guard_consume.py /tmp/guard-consume.json
```

Reproduce the one-game probe with the retained archive:

```sh
python Scripts/Sim/run_u13_guard_consume_probe.py --baseline /path/to/tempo-roster-162-03 --output /path/to/result.json
```
