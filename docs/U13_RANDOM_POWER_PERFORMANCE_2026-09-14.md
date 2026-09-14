# Random-Legal power planning performance

The Windows a0b774c 20-game diagnostic stopped on game 0's 1,200-second watchdog
in round 14. Games 1, 2 and 3 completed with independent exact replay; games 4–6
were interrupted by the scheduler. This is not a passed 20- or 100-game gate.
Game 0 round 10 spent 332 seconds planning versus 13 seconds resolving/comparing.
Increasing the watchdog or capping at round 12 would not fix this cost.

## Profile and bounded change

The supplied round-14 snapshot reproduces expensive power enumeration. Local
instrumentation measured 182 and 227 power candidates for the two Gremory seats;
legality took about 2.8 and 4.5 seconds. The ordinary combat/Castle domains contained
hundreds of candidates but took only about 60–170 ms per batch in that diagnostic.
The initial probe is diagnostic timing, not Windows acceptance.

For domains over 64 raw powers, Random-Legal now finds a legal witness for each
power group in growing chunks, retaining checked candidates. It then makes the
same keyed group-or-Pass draw. Only the selected group's remaining targets need
validation. That complete selected domain is normalized, deduplicated and sorted
exactly like U13Legality.legal_power_groups before the unchanged target draw.
Small lists retain the original implementation.

No candidate is declared legal without the existing authoritative predicate.
No target truncation, heuristic scoring, new RNG draw, or altered probability is
introduced. If a group has no legal member, its full list still has to be checked.
Selecting an expensive power also still requires its full legal target list.
Keep U13_GAME_RANDOM_LEGAL_V5 because that version is part of the keyed RNG domain;
revision metadata identifies the implementation change separately.

This optimization is in the Random-Legal test policy. It does not directly speed
up the production doctrine bot or rendering. The prior a0b774c shared-flow changes
remain in effect. Random-Legal remains useful for reachability/regression testing.

## Verification and scope

The differential suite uses the frozen a0b774c Random-Legal implementation, all
nine lords in both seats, complete sorted legal domains, malformed/duplicate
sources, unchanged planning state, identical seeded complete plans, per-hook
resolution equality, outcomes and lossless saves. Supplied checkpoints cover
Gremory round 14, Orias round 9, Odradek round 5 and Kroni round 4.

Initial local Linux Godot 4.5.1 comparisons passed 18 opening plans and 8 saved-case
plans. Across the saved cases planning took 14.43 seconds versus 17.72 seconds
(about 18.5% less); the stalled game's two seats took 4.06 seconds versus 6.05
seconds (about 33% less). These measurements precede the small-domain fallback
refinement, are subject to local timing noise, and are not Windows or whole-batch
speedup claims. Windows Godot 4.7.2 acceptance is pending.

Run run_u13_random_planning_perf.sh with the engine executable and the original
Downloads/u13-random-a0b774c-r40/game-000-checkpoint.json. It compares the old and
new planners, resolves that checkpoint round, and packages timing/equality logs.
Use the dedicated Perf checkout; sprite work may continue elsewhere.

The final small-domain fallback and reversed-discard duplicate cases passed the
opening differential suite again. A full local game 0 then completed at round 15
with a Final Collapse victory and independent replay verification (146.3 seconds
on Linux 4.5.1). This is one diagnostic completion, not Windows throughput or a
100-game acceptance claim.

## Testing sequence

A 12-round run is a useful smoke test, not exhaustive coverage or a completed
match gate. It misses neutral Tear pressure beginning after round 12, extended
persistent/return/debt interactions and real game termination. Preserve the
40-round diagnostic cap for the staged full-match gate. Do not launch another
100-game campaign before the focused Windows comparison passes. Old revision
reports must not be relabeled as results of this change.
