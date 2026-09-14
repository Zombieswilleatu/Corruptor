# U13 shared conductor and world-install performance

Scope: targeted performance work authorized after the roadmap review. No balance,
doctrine scores, powers, RNG, candidate ordering, victory thresholds, or U12 changes.

## Evidence and changes

The interrupted Windows e4d9501 V6 doctrine campaign contains 54 completed games
(10 independently replayed, 44 single), four interrupted workers, and no capped
completed games. It is not a completed 100-game gate. The preceding Windows 4.7.2
fixture gate passed seven suites / 759 checks. Random-Legal acceptance is separate.

Across 826 completed-game rounds, recorded phase totals were approximately 57.4%
resolution, 20.3% reaching planning, 14.5% planning, 5.7% submission, and 2.0%
checkpoint/save work. These are summed worker phase times, not elapsed campaign
time; resolution includes replay and round-end verification where applicable.

1. The conductor now obtains only its flow fields instead of building full entity,
   guard, effect and event projections to inspect Stockpile/Slaver choices and
   victory. Returned data is detached and normalized; Stockpile redaction and the
   pre-submission presentation baseline match the existing public projection.
   Player UI and bot full projections remain intact.
2. World installation reuses its canonical normalization after a validation-cache
   miss. The content validator still receives an isolated deep copy, and all raw
   type checks, entity/card/content validation, cache comparisons, and transaction
   boundaries remain in force. External restore retains its validation.

Both production changes are used by the playable U13 conductor and simulation.
They do not speed up sprite animation, rendering, or GPU work.

## Differential verification

Frozen e4d9501 methods provide the comparison implementation. The flow suite
covers all nine lords in both seats, both event profiles, paused choices, exact
Slaver options and ordering, Stockpile visibility, output-mutation isolation,
three complete Random-Legal rounds, each resolution hook, saves, and subsequent
seeded automatic choices. Those three rounds are diagnostic, not completed games.

The world-install suite covers malformed inputs, integer/float normalization,
callback replacement and mutation, cache isolation, sealed loadouts, entity history,
private events, exact per-hook state, player histories, and lossless restore.
A supplied dense round-20 checkpoint (match-042 / seed index 24) was also replayed
three times, alternating which implementation executed first.

Local Linux Godot 4.5.1 diagnostics (not Windows 4.7.2 acceptance):
- Final flow comparison: 569 checks; 2,078 ms versus 2,301 ms reaching planning
  in opening cases (about 10% less phase time), alternating execution order.
- World-install opening comparison: 287 checks, 144 exact hooks; 11,024 ms versus
  11,188 ms measured resolution (about 1.5% less phase time).
- Dense checkpoint plus extended boundaries: 128 checks, 48 exact hooks;
  7,266 ms versus 7,811 ms resolution across three repeats (about 7% less).
- Callback-mutation checks cover both enabled and disabled validation caching.

These are noisy local phase measurements, not a measured 100-game speedup. Do not
multiply them into a promised wall-clock reduction. The Windows gate prints its
own execution timings. Large-volume throughput work remains with later PySim parity.

## Windows acceptance

Run `Scripts/Sim/run_u13_flow_perf.sh` with the Godot 4.7.2 executable. It runs two
focused suites and writes a ZIP in Downloads. Expect minutes, not an instant check;
this does not start a 100-game campaign. Keep the test checkout fixed while running.
After acceptance, profile the staged Random-Legal campaign on a dedicated checkout.
Existing e4d9501 results cannot be relabeled as results for this code revision.
