# Directed doctrine V2

This patch addresses the nine-game 83b89cc campaign review. Its scope is hidden
guard information, redundant Projection/Inevitable Ruin choices, repeated
planning setup, and measurements of the remaining resolution cost.

## Information available to the doctrine

The V1 presentation projection exposed enemy guard faces, and V1 scorers used
those values. V2 adds a bot-only input boundary. Enemy guards expose occupied
owner/lane/slot positions, without value, suit, physical origin/ordinal, or the
card ID's suit/tier metadata. Public slot handles are translated back to actual
targets only by the authority facade. Own cards retain their known values.

The current belief model estimates each concealed guard at strength 3. It does
not know the actual face or learn it by probing damage outcomes. It currently
forgets previously observed faces rather than maintaining a card-tracking model.
Metamorphic tests vary hidden values and suits while requiring identical bot
inputs and plans. Target translation is tested through real legality checks.

This boundary applies to BasicDoctrine V2. The legacy Random-Legal stress policy
and the presentation/UI projection are separate paths and are not converted by
this patch. Do not interpret old V1 campaign wins as evidence of fair-information
strategic strength.

## Power coordination

Projection values one guard rather than the sum of the zone. For concealed guards
it banks toward the fixed estimate instead of using an exact hidden threshold.
It reassesses a lane its own chosen attack is expected to clear. Inevitable Ruin
similarly reassesses a castle its own Siege is expected to destroy, accounting
for the public sigil and interposing Bastion plus estimated guards.

The selected power gets one bounded opportunity to retarget or use another power.
If none is useful and legal with the existing cart, drop the power and replan
development/combat with the released payment. Candidate batches remain capped at
32, with at most four whole-cart previews per power selection. These are estimates
under simultaneous play; hidden guards, new deployments, and Ward can still make
a reasonable choice miss. No combat rule, power timing, or target legality changes.

Odradek's expensive-power priorities and Kanifous's Wish mix remain follow-ups;
their frequencies in nine matches alone do not establish a scoring defect.

## Validation lifetime

Each player plan creates one checked, detached planning session. It reuses staged
declaration transactions keyed by lossless Variant bytes. Candidate order execution
always happens on a separate fork; no candidate or returned projection may mutate
the session baseline. Missing/malformed bulk adapters retain full-preview fallback.
The session cannot submit or advance the live match, and is discarded after the
plan. Live submission still runs the original authoritative validation. A retained
session represents its original snapshot, never authority to commit stale actions.

Cached and uncached V2 plans are compared across all nine opening Lord pairings,
including whole-round save/replay. Tests also cover malformed candidates, isolated
views, staged costs, adapter fallback, and rejection of new sessions after sealing.

## Timing fields

Reports keep the existing top-level round phase totals for compatibility.
`resolution_detail_ms` splits primary execution, independent replay execution,
snapshot comparison, save encoding, restore, and post-restore comparison.
`resolution_hooks` and `replay_resolution_hooks` contain each hook's total time,
validation/clone time, and dispatch time. These are submeasurements of resolution,
not additional time to add to the top-level total. Periodic checkpoint time is
also explicit. Timings are diagnostics and are excluded from authoritative state,
event records, replay equality, and save payloads.

The doctrine profile now runs uncached and cached V2 against the same state and
requires identical plans. On the uploaded game-079 round-15 checkpoint, the local
Godot 4.5.1 diagnostic measured both seats at 1326 ms uncached versus 1010 ms cached
(about 24% less planning time), with unchanged plans. One world copy was 0.365 ms;
one validated match clone was 25.112 ms. This is not a Windows 4.7.2 acceptance
result or a promise of equivalent whole-game speedup.

The first local V2 game-079 diagnostic finished naturally at round 19. Of 38.535 s
in resolution, 13.204 s was hook validation/cloning; the entire Marching hook was
7.274 s. Remaining resolution work is spread across hooks, not solely Marching.
Different strategy and hardware make this unsuitable for a V1/V2 speed ratio.

Local diagnostics also passed the expanded basic-doctrine and committed-Hunt
suites. Game-009 finished at round 9 with independent planning and save/replay
verification passing. Game-079 was single-conductor legality verification. Report
checks confirm one execution per resolution hook and consistent timing totals.

Run the existing `Scripts/Sim/run_u13_doctrine.sh` with Godot 4.7.2 stable to repeat
the same nine seeds (two workers; 40-round cap; independent replay on games 1/6).
The expanded basic-doctrine preflight includes the new regressions. Campaign
identity records `U13_BASIC_DOCTRINE_V2` and `U13_BOT_GUARD_SLOTS_V1`.
