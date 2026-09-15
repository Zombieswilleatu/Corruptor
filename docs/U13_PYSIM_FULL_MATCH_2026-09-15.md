# U13 PySim — first complete-game reference

**Windows Godot 4.7.2 acceptance passed at clean `d059b95`.** Independent Python
replay reproduced the complete uploaded summary: two complete games, 30 rounds,
767 operations, eight settlement components and one 200-tick probe. All 8,586
Godot checks, 56 Python tests and 13 corruption rejections passed. The
[accepted record](evidence/U13_PYSIM_FULL_MATCH_d059b95.json) preserves the
Windows evidence and measured 11.34 / 19.07 second match means.

The subsequent [Windows PyPy 7.3.23 run](U13_PYSIM_PYPY_2026-09-15.md) matched
the same complete verifier summary and measured 3.73 / 6.53 seconds at unchanged
source/input fingerprints. This runtime result preserves the CPython baseline.

The subsequent [rollback copying optimization](U13_PYSIM_FULL_MATCH_COPYING_2026-09-15.md)
passed Windows acceptance at clean `c228d85`: 63 tests and the full replay under
both CPython and PyPy, including 13 corruption checks. Matched sustained means
fell 12.92 → 2.71 seconds under CPython and 7.83 → 1.45 under PyPy. That later
record is separate; the original accepted evidence below remains at `d059b95`.

This is the first independent Python setup-to-victory path, with a deliberately
bounded rules domain. It is not complete nine-Lord parity or balance evidence.

## Scope and authority

`FullMatch` independently creates a production opening, accepts explicit choices,
runs all 20 hooks, advances subsequent rounds and settles actual victory. Godot
`U13GameConductor` remains authority. The existing five-, six- and nine-hook
adapters retain their boundaries; the accepted isolated Marching API retains its
own boundary too.

The first path admits Gremory, Deimos, Humbaba and Kalligan with ordinary army
orders, public Guards and stable pairs, Work/commission, Stockpile/Slaver,
ordinary combat and required automatic reactions. It includes Marcher regeneration,
Gremory's Picking the Bones, Kalligan upkeep/Rekindle, Humbaba's Endurance,
commitment cleanup, Vacant Throne, round pressure and victory precedence.
Declared Lord powers, paid Rites and Resummon raise an explicit unsupported error;
the other five Lords and active spatial actors/effects remain outside this adapter.
Empty declarations are legal decisions in the native game, not disabled rules.
Matching the two chosen paths does not certify every possible decision by these
four Lords.

The shared Marcher column kernel now has an explicit full-world integration mode.
Cards, Castles, Lords and used IDs remain in the registry through every reaction.
Mutable Marcher fields stay in flat columns, and contact construction retains
the accepted ID ordering, earliest-arrival and keyed-tie semantics.

The full-match gate exposed a repeated-round economy bug in the Python mirror:
Stockpiles below seven Integrity were incorrectly providing draws. The mirror now
uses the native operational floor. Existing Guard-slot occupancy, castleless Siege
admission and the living-Lord Profane condition are enforced. Shared Work admission
also uses the existing Deimos reconstruction rule and the latest commission rule.
These are mirror corrections, not changes to Godot balance.

The second complete game also exposed an exact ranged-selection edge at round 3:
native `U13RangedMarching.nearest` accepts a first target tied with its initial
squared-distance sentinel `800² + 1`. Python had required a strictly smaller
distance. A native shot at tick 172 was therefore delayed, and the attacker moved
four fixed-point units farther before firing. The mirror now preserves the native
tie exactly. All 200 rich tick records and the complete result of that isolated
diagnostic phase then matched. A directed regression checks the ordinary range,
the sentinel tie and a point beyond it. Godot's range rule was not changed.

## Explicit inputs and exact comparison

`full_match_inputs.json` contains seeds, loadouts and decisions. It contains no
expected world snapshots or injected state transitions. A separate, replaceable
Python reference policy produced the decisions; Godot must accept all of them.
The policy can be passed to `next_operation(match, policy, weights)`. Its detached
observation contains only its own hand and public board/player information.
Neither simulator imports the other's rule output to advance a complete game.

The reference policy is deterministic and intentionally simple. Its ID and
parameters are recorded with the inputs; it is not shipping BasicDoctrine and
has no strength claim or required Godot counterpart. This is a first injection
boundary, not a finished experiment harness: a complete legal-action interface,
policy RNG, exposure counters, configuration loading, matchup scheduling and
shipping-doctrine decision parity remain later work.

Godot exports an exact-data JSONL stream. Each operation records its result,
complete state outside event history, outcome, the prior event count and every
new event envelope/view. All earlier event rows must remain identical; the prefix
and appended rows reconstruct the complete snapshot exactly. No world field is
omitted. Godot starts each game again from setup and compares each exact encoded
record digest against the first pass. Python independently creates its opening
and compares every operation, field, event/view and outcome.

The full-game records use native `U13_BATCH_EVENTS_V1`: only `MARCHING_TICK` and
`KRONI_ACTOR_TICK` presentation samples are absent. All semantic events remain.
One directed probe reruns the Deimos/Kalligan round-3 Marching phase on a detached
copy of the independently reached world and compares all 200 tick records as
well as its complete result. It never changes the live game. This is not a claim
to compare every tick frame in all 30 rounds; the earlier isolated 5,600-frame
gate retains its exact source/runtime scope. A mismatch reports game, operation,
round, hook, event/tick where available, and field.

The complete games have zero fixture mutations. Eight separate settlement
component cases exercise Ritual/Collapse/Dominion precedence, the living-Lord
gate, the third absent round's Soul, banishment-round presence, the second-round
grace and pressure boundaries. Their prepared states never enter a complete game.
Each full game also rejects further round advancement and stepping after victory.

## Preserved reference and current rules

The initial implementation is preserved at
[`67a30fa` on `u13-pysim-first-full-match-reference`](https://github.com/Zombieswilleatu/Corruptor/commit/67a30fa8a09deeaca2b1074592bd83e93565914a),
with its [original local evidence](evidence/U13_PYSIM_FULL_MATCH_4d778a4_LOCAL.json).
That reference used the rules at `4d778a4` and measured 8.57 / 17.66 seconds for
the two games. Its evidence has not been relabeled as a later revision.

The development integration also preserves the parallel `550f39c` rule change:
artillery Castle destruction grants its owner two Souls, and every public
`ARTILLERY_FIRED` event includes `soul_gain`. The ordinary Python port already
mirrors that change. Regenerating the explicit game inputs produced identical
bytes. The current source has its own fresh native export, replay, Python
comparison and timing report below. A difference between these timing runs is
not an optimization result.

## Local verification and timing

Independent Python replay matched two complete games: 13 rounds for
Gremory/Humbaba (Gremory wins by Ritual) and 17 for Deimos/Kalligan (Kalligan wins
by Ritual), with peak populations of 63 and 66 Marchers. The corpus has 767 game
operations, four terminal rejections, eight settlement components and one
200-tick full-world probe. All 56 Python tests and 13 evidence-corruption probes
passed. The preserved `4d778a4` checkpoint separately replayed the immutable
accepted `e8cc3f9` isolated tape and matched all 28 phases / 5,600 tick frames
with the corrected Python kernel. That historical regression retains its own
validation identity and was not rerun for the artillery change.

The complete games expose 84 contacts, 74 clashes, 226 Marcher deaths, 504 ranged
attacks, 40 regeneration events, 101 arrivals, nine Picking the Bones triggers,
30 Guard pairs, 57 Work resolutions, eight Castle activations, 47 artillery shots,
two banishments and 60 Vacant Throne settlements. These are coverage counts, not
claims that every Lord passive or action branch fired. Both full games end by
Ritual; the separate components cover Dominion and Final Collapse.

The current full games include 47 artillery shots, one Castle destruction
and its two-Soul award, with exact matching events and resulting state. The
focused native Deimos gate (97 checks, zero failures) and the Python ordinary
resolution test separately cover directed reward boundaries. These focused
checks also remain local Linux diagnostics.

The native gate passed 8,586 checks and both independent replays, with zero
failures or script errors. Its export/check/replay wall time was 906 seconds;
the separately logged Python comparison took 141 seconds while the native replay
was still running. These are gate costs, not game-throughput measurements.
Actual match timings are collected after both stages exit. Linux Godot 4.5.1
results are diagnostic only; replaying an older Windows tape does not grant the
new full-match adapter Windows acceptance.

Verification source: the uncommitted implementation based on
`550f39ccd20c6910bbb4dc4eed0ed1546303ed80`, including the parallel playable fixes
and artillery reward change.
The native Inevitable Ruin correction is preserved; its declared power remains
outside `FullMatch`'s current domain. Commission is mirrored and exercised.

- Source fingerprint: `b25bdf65d1f1689f7e0b5e35cee748e810bd1bf409f2084ee55b0b280ad7358e`.
- Input fingerprint: `c811aa29dd34c2e8c6cf7cc710693483340c067415aaae0b94c55cc8f8fb3865`.
- Reference runtime: Godot `4.5.1.stable.official.f62fdbde1`, Linux.

The [local evidence](evidence/U13_PYSIM_FULL_MATCH_LOCAL.json) retains complete
parity and timing reports, test names, the prior isolated-tape regression and
artifact hashes. Earlier Windows acceptance records retain their original scope.

The timing harness requires a passing parity report with matching source and input
identities. It measures fresh setup-to-victory matches with one warmup and three
trials per input, retaining transactions and the full semantic event history.
Decision replay is timed; policy selection, input loading, comparison snapshots,
digesting, export and Godot are excluded. Separate full-game profiles and hook
totals include instrumentation overhead and are not added to the timing samples.
Every timed/profiled final snapshot must match its verified reference digest.

| Reference game | Rounds | Mean wall time | Median | Mean CPU time |
| --- | ---: | ---: | ---: | ---: |
| bones_endurance | 13 | 9.32 s | 9.30 s | 9.32 s |
| spoils_rekindle | 17 | 19.40 s | 19.68 s | 19.39 s |

On this Linux CPython 3.12.14 worker, the equal-weight mean across the two inputs
is **14.36 seconds per complete match**. The proposed 50 ms target is not close;
this is not yet a practical large-sweep engine. These are fixed ordinary inputs,
not a measured nine-Lord policy workload or a 50,000-game capacity estimate.

The separate full-game profiles identify transaction copying as the first target:
`copy_data` occupies 17.76 of 23.67 profiled seconds in the 13-round game and
34.51 of 43.97 in the 17-round game (about 75% and 78% cumulative). `apply()`
currently snapshots the entire retained semantic event history for rollback at
every operation. Marching is also material, but optimizing movement alone cannot
remove the dominant full-match cost. Profile times include instrumentation and
must not be treated as uninstrumented throughput or summed across nested calls.
Preserve exact event views, state ownership and rollback when changing that path.

Two fixed games do not establish population throughput, worker scaling or the
cost of shipping doctrine. The 50 ms suggestion is a target, not a passed gate.
Do not extrapolate a 50,000-game schedule from the earlier partial/isolated timing.

## Windows acceptance at `d059b95`

Accepted archive:
`u13-pysim-full-match-5KQlDr-2026-09-15_09-51-19-3GTYb8.zip`.

- Archive SHA-256: `abcca4a1474faf85501af9d7a7004021e1b7d48e25acaaa7d45e8f26123dae07`.
- Revision: `d059b9560a95c32779597260d99829f9f1534f22`; empty working diff.
- Source fingerprint: `b25bdf65d1f1689f7e0b5e35cee748e810bd1bf409f2084ee55b0b280ad7358e`.
- Input fingerprint: `c811aa29dd34c2e8c6cf7cc710693483340c067415aaae0b94c55cc8f8fb3865`.
- Runtime: `4.7.2.stable.official.ed1daf0bf`, Windows 11, CPython 3.14.7.
- Exit status 0, 13 unique archive members, valid CRCs, zero failures/script errors.

The Windows gate passed all counts listed above and independently replayed both
native games. A separate Python replay of the uploaded exact stream reproduced
the entire verifier summary without a diagnostic override, including all 13
corruption rejections. Benchmark input hashes and final-state digests also match
the accepted cases and replay results. This verification does not claim local
execution of Windows Godot or remeasurement of the user's hardware.

Windows timings use one worker, normal garbage collection, one warmup and three
fresh measured games per input; profiling is a separate run. The included and
excluded work is unchanged from the local timing contract above.

| Reference game | Rounds | Mean wall time | Median | Observed range |
| --- | ---: | ---: | ---: | ---: |
| bones_endurance | 13 | 11.34 s | 11.23 s | 8.41–14.38 s |
| spoils_rekindle | 17 | 19.07 s | 18.96 s | 18.59–19.67 s |

The equal-weight mean is **15.21 seconds per complete reference game**. The first
case varies substantially across three samples; this report does not establish
the cause. Different hardware and Python versions prevent treating the difference
from Linux as an optimization or regression. The 50 ms target remains unmet;
these two inputs do not establish policy throughput or worker scaling.

The separate Windows profiles place `copy_data` at 18.87 of 24.81 seconds and
31.68 of 40.84 seconds (76% and 78% cumulative). Transaction `snapshot()` alone
accounts for 18.47 and 31.01 profiled seconds. The native gate's 605 seconds
include export, checks and replay; they are not a Godot pure-match timing.
No matched Godot-versus-Python speedup has been measured. See the
[audited optimization priorities](U13_PYSIM_POLICY_AND_PERFORMANCE_2026-09-15.md#first-complete-game-profile-and-next-optimization).

The [acceptance record](evidence/U13_PYSIM_FULL_MATCH_d059b95.json) retains the
complete Windows parity and timing reports, test names, source/runtime identity,
independent replay result and all archive-member hashes. Earlier local evidence
and the preserved first reference remain unchanged.

## Reproduction and next work

The command is retained for reproduction. Recording this accepted evidence does
not require another run. Use the U13 performance checkout at the accepted source
revision when reproducing its exact identity:

```bash
bash Scripts/Sim/run_u13_pysim_full_match.sh "C:/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
```

The runner requires Windows Godot 4.7.2 stable and Python 3.10+, emits heartbeat
progress, checks tests/native replay/Python parity and corruption rejection, then
measures matches and packages the reports in Downloads. The native gate runs two
complete reference games twice, not a new 100-game campaign. Its bounded watchdogs
are 40 minutes for native export/replay and 15 minutes per Python stage.

The [copying pass](U13_PYSIM_FULL_MATCH_COPYING_2026-09-15.md) is now accepted
against this reference with exact event views, state ownership and rejection
rollback retained. Profile that optimized source to locate the remaining cost,
and collect a matched Godot/Python pure-match comparison before extending the
port further.
Retain the separately [verified and measured PyPy runtime](U13_PYSIM_PYPY_2026-09-15.md)
alongside the CPython baseline when comparing code changes, so runtime and code
gains remain distinct.
Then extend explicit power/effect, Rites/Resummon and remaining Lord coverage;
grow the reference corpus only when those dependencies justify it. Common Smart
Core/Lord doctrines and serious balance sweeps follow trustworthy rules and a
measured practical experiment budget. The accepted UI and U12 are unchanged by
this PySim implementation.
