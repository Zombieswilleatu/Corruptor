# U13 PySim — isolated Marching parity and performance spike

**Windows Godot 4.7.2 acceptance passed at clean `e8cc3f9`.** The uploaded gate
passed 394 Godot checks, 28 isolated phases, all 5,600 tick frames and their
ordered events, 46 Python tests and 14 deliberate evidence corruptions.
Independent replay reproduced the complete Windows summary without a diagnostic
override. The [accepted record](evidence/U13_PYSIM_MARCHING_e8cc3f9.json) also
retains the target-machine phase timings. This completes the early spatial gate
from the [policy/performance plan](U13_PYSIM_POLICY_AND_PERFORMANCE_2026-09-15.md).

The existing `ResolutionMatch` still stops after nine fresh-game hooks, before
`post_resolution_spawns`. This new subsystem does not advance that match cursor
or establish complete-round, full-match or complete Lord-effect parity.

## Authority and boundary

`U13Marching.resolve` and `regenerate` remain the Godot authority. The new
`marching.py`, `marching_columns.py` and `marching_spatial.py` independently
resolve explicitly prepared worlds containing Marchers and phase data. The
existing conductor, gameplay rules, UI, U12, legacy Python and shipping doctrine
are unchanged. The preceding resolution acceptance at clean `e51588d` retains
its [exact Windows evidence and scope](U13_PYSIM_RESOLUTION_2026-09-15.md).

| Mirrored subsystem | Directed coverage |
| --- | --- |
| Movement and queues | 200 integer ticks per phase; ready/birth holds, ID-ordered seek and allied spacing, detours, field edges, friendly gate queues and hostile gate contact. |
| Contact and melee | Stable ID candidate order, earliest contact ticket, keyed `CONTACT_TIE`, lane order, simultaneous damage/armor, eight-tick exchanges, surviving duels across phases, participant retirement/allegiance changes and atomic 64-exchange rejection. |
| Ranged Vultures | Current profile, 800-unit range edge, movement readiness, 32-tick shot clock, eight-tick melee recovery, shared volley selection, reciprocal lethal shots and overkill without duplicate deaths. |
| Prepared spatial modifiers | Rout retreat/recovery, Web field and lane-aura lifetime/boundaries, regeneration and exact combined speed rounding. These are prepared effect inputs, not simulated declarations or central effect-registry admission. |
| Prepared Gravity Orbs | Stable nearest-orb ties, pre-movement positions, pull and swept destruction, waiting/held units, consumption/Tear counters and Collapse/Web interactions. |
| Ownership and rejection | Detached caller state and result views; unsupported full worlds/Kroni/Wishmaster actors fail explicitly; rejected or exceptional callbacks cannot publish partial tick work. |

Normal fixture worlds use the current ranged profile. One explicitly named frozen
U13 subsystem case checks the older non-ranged armor-bypass fallback; it does not
change U12 or claim the old profile is the shipping game.

The subsystem exposes an explicit reaction callback boundary, but the corpus
uses no-op Lord reactions plus a forced-rejection case. Actual Marcher-death Lord
reactions, Kroni/Wishmaster actors, power declaration/activation, the complete
persistent-effect lifecycle, Post-Resolution, cleanup and victory still need
integration. Three named `fixture_*` operations prepare retirement, allegiance
or invalid-HP states between isolated calls. They are not production operations
and must never bridge missing rules in a claimed full game.

## Phase data and ordering

Mutable Marcher fields use parallel Python lists with stable ID-sorted indices
and live flags. Retiring a Marcher preserves its used ID; slots are not recycled.
Unknown non-rule attributes use an optional sidecar. Canonical dictionaries are
materialized at event/snapshot/reaction boundaries, rather than serving as the
mutable per-tick unit representation. This is ordinary CPython, without NumPy,
native extensions or a vectorization claim.

Spatial grids accelerate nearby searches, but they do not determine contact
order. Candidate construction explicitly follows stable IDs, uses the earliest
joint arrival ticket, then applies Godot's keyed tie selection. The corpus
includes the same IDs/seed in reversed registry order, requiring identical full
records, and 33 direct contact probes with the selected native Godot pair and
candidate/key information.

`capture_ticks=False` suppresses only `MARCHING_TICK` presentation records.
Every rule event and its public views remain; the verifier reruns every operation
in this mode and checks the exact final world and ordered non-tick events against
the fully recorded result. This is the first measured batch path, with the exact
trace path retained as its reference.

## Exact evidence

`marching_inputs.json` contains setups and explicit operations, not expected
states or outcomes copied from either engine. Declared expected action labels
check fixture intent. Godot and Python independently construct the opening
isolated worlds from these inputs. The manifest has its own normalized SHA-256,
separate from the broad Godot/Python source fingerprint.

The Godot exporter calls production Marching, round-trips the exact transport and
independently replays all 22 cases. Python compares every exported field, ordered
event envelope/view and complete operation-boundary world, including duel clocks,
used IDs and orb consumption. It compares all 200 production
`attribute_delta_v1` frames per successful phase, not a sample. This does not
claim to expose every internal working variable as a full-world snapshot each
tick. A difference reports case, operation, event ordinal, round, tick and field.

| Local diagnostic result | Count |
| --- | ---: |
| Godot checks, with zero failures/script errors | 394 |
| Independently matched isolated cases | 22 |
| Matched operations, including 3 fixture edits and 5 atomic rejections | 41 |
| Successful Marching phases / exact tick frames | 28 / 5,600 |
| Direct contact probes | 33 |
| Python tests, retaining all 36 earlier tests | 46 |
| Deliberate evidence corruptions rejected | 14 |

Event exposure includes 46 contacts, 35 completed clashes, 91 defeated Marchers,
130 ranged attacks, 10 interrupted duels, 14 regeneration events, three arrivals
and 19 Gravity Orb consumptions. Corruption probes cover identity, missing
records, candidate order/key, tick position/armor/views, duel clocks, orb counters,
used IDs and event order. Matching this bounded corpus is not exhaustive rules
coverage.

The [local evidence record](evidence/U13_PYSIM_MARCHING_LOCAL.json) retains the
complete verifier and timing reports, test names, case inventory and artifact
hashes. Verification ran on the uncommitted implementation based on
`6944a919744493d9d5d7844a055ce5209e55deaa`, with:

- Source fingerprint: `6ce44971808ae9d45815da43e478978022f279259e083d38cc421e99c8898fc4`.
- Input fingerprint: `5baaab5d5a70fbc0c89c633bf7bc043e328f0784f604f821f1a9dd96b539e4de`.
- Godot `4.5.1.stable.official.f62fdbde1`, Linux; CPython 3.12.14.

The approximately 24.93-second Godot export/replay/check duration is gate overhead,
not a Godot phase-throughput measurement. These results are diagnostic only;
they do not replace Windows 4.7.2 acceptance.

## Local diagnostic phase costs

Single worker, normal garbage collection, two warmups per mode/case and 20 fresh
measurements per case, alternating batch/trace order. Wall and CPU distributions
are both retained; CPU means closely track wall means on this machine.

| Prepared case | Initial → final Marchers | Batch phase mean | With all tick records | Batch p95 |
| --- | ---: | ---: | ---: | ---: |
| Ordinary mixed | 12 → 12 | 30.22 ms | 68.84 ms | 34.38 ms |
| Dense contacts | 64 → 8 | 106.19 ms | 208.12 ms | 119.16 ms |
| Gravity pull/consumption/sweep | 14 → 1 | 6.80 ms | 13.46 ms | 7.17 ms |

Each measurement is one isolated 200-tick phase. Batch timings include input
validation, copying/import, rule events and final publication. They exclude
fixture selection, parity comparison, JSON/export, Godot execution, policies,
unported reactions, remaining hooks and victory. The Gravity case consumes 13
units, leaving a much smaller field; its timing is not evidence that adding
Gravity generally makes Marching cheap. The ordinary first phase fires eight
shots without completing a melee clash; the dense case contains 23 contacts,
84 shots and 56 deaths. These cases are not a measured match workload mix.

Separate boundary probes use the same registry validation for owned row
dictionaries and columns. They measure import/publication only; no competing
optimized row-based tick kernel exists, so this experiment cannot establish an
array-loop speedup.

| Layout boundary, mean ms | Ordinary rows / columns | Dense rows / columns |
| --- | ---: | ---: |
| Validated import | 0.279 / 0.329 | 1.110 / 1.644 |
| Final publication of initial units | 0.056 / 0.035 | 0.213 / 0.260 |

Deduplicated reachable Python object sizes were 14,136 / 11,067 bytes for
ordinary rows/columns and 67,572 / 38,871 bytes for dense rows/columns. These are
object-graph sizes, not process RSS or incremental allocator use. The evidence
also retains the Gravity layout costs and all distributions, including outliers.

Phase preparation averaged 0.43 ms ordinary and 1.95 ms dense. The separately
timed prepared work averaged 32.17 and 105.66 ms. These independent sample means
are not additive decompositions of the public phase means. Separate instrumented
profiles place movement and nearby-unit/spacing searches at the top; movement
accounted for about 74% and 81% of profiled cumulative phase time. Profiling
overhead is excluded from the timing samples. Search/grid work is therefore a
concrete optimization candidate; conversion is a small part of these phases.

The dense phase alone exceeds the suggested 50 ms whole-match target on this
machine. Full-game throughput and 50,000-game wall time remain unknown, not
extrapolations from these three phases. The earlier 7.98 ms Windows and 10.08 ms
Linux measurements cover the same Development-only slice on different systems;
do not add/subtract them as if they established a full-match budget.

## Windows acceptance and next dependency

Accepted archive:
`u13-pysim-marching-zRzlKJ-2026-09-15_02-04-06-YwsZq6.zip`.

- Archive SHA-256: `8b6b39327544352880bfd1dd3a4b2997b27f1e2cf2d7f8ced4d0e16cf423e978`.
- Source revision: `e8cc3f9c236afa2ce4586999913a52e833b5813f`.
- Source fingerprint: `6ce44971808ae9d45815da43e478978022f279259e083d38cc421e99c8898fc4`.
- Input fingerprint: `5baaab5d5a70fbc0c89c633bf7bc043e328f0784f604f821f1a9dd96b539e4de`.
- Runtime: `4.7.2.stable.official.ed1daf0bf`, Windows 11; CPython 3.14.7.
- Empty working diff, exit status 0, 12 unique members and valid archive CRCs.
- 394 Godot checks, 22 cases, 41 operations (three fixture edits and five
  rejections), 28 phases / 5,600 tick frames, 33 contact probes, 46 Python tests
  and 14 corruption rejections; zero failures or script errors.

Independent Python replay against the uploaded Windows reference reproduced the
entire verifier summary, including the batch projection and all corruption
rejections. A separate check independently reconstructed and matched the input,
trace-result and batch-result digests for all three timing cases. Neither check
claims local Godot 4.7.2 execution or remeasurement of the user's hardware.

Windows measurements use the same 20 fresh samples, two warmups per mode/case,
one worker and normal garbage collection as the local probe:

| Prepared case | Batch mean | Batch median | Batch p95 | With all tick records, mean |
| --- | ---: | ---: | ---: | ---: |
| Ordinary mixed, 12 → 12 Marchers | 57.73 ms | 60.11 ms | 76.82 ms | 118.79 ms |
| Dense contacts, 64 → 8 Marchers | 130.52 ms | 96.78 ms | 210.33 ms | 257.01 ms |
| Gravity, 14 → 1 Marchers | 6.37 ms | 6.30 ms | 7.02 ms | 12.08 ms |

These are observed isolated 200-tick phase costs, not a full-match throughput
result or a passed speed target. Ordinary batch samples ranged from 36.58 to
96.52 ms; dense samples ranged from 83.44 to 211.53 ms. The report does not
identify the cause of that variability. Different hardware and Python versions
prevent interpreting the Linux/Windows difference as an optimization or regression.
The Gravity case's much smaller surviving field still limits its interpretation.

Windows CPU samples occur in 15.625 ms increments in this report; zeros for short
import/publication operations do not establish zero CPU cost. Use their wall
distributions for boundary-cost interpretation. Phase preparation averaged
0.64 ms ordinary and 2.06 ms dense; separate instrumented profiles again place
movement and nearby searches at the top. These findings support targeted search
optimization, while full-game speed and worker scaling remain unmeasured.

The [acceptance record](evidence/U13_PYSIM_MARCHING_e8cc3f9.json) preserves the
complete verifier and timing reports, case/test inventory, independent replay
result and all archive-member hashes. The earlier Linux diagnostic record is
unchanged. The command below is retained for reproduction; this documentation
update requires no rerun.

```bash
cd /c/Users/jerem/OneDrive/Documents/Corruptor-U13-Perf &&
git pull --ff-only origin u13-basic-doctrine &&
bash Scripts/Sim/run_u13_pysim_marching.sh \
  'C:/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe'
```

The runner requires Python 3.10+ with no pip dependencies and Windows Godot
4.7.2 stable. It runs the unit suite, exports/replays Godot evidence, independently
verifies Python, then measures the three phases against that verified source.
It packages `u13-pysim-marching-*.zip` in Downloads, with source/runtime identity,
working diff, logs, exact export and timing report. It retains 15-second
heartbeats, a 420-second Godot watchdog and 180-second Python stage watchdogs.
This is a focused fixture gate, not another 100-game campaign.

Next, integrate this accepted kernel with the remaining round lifecycle and
reactions. Preserve the first legitimate independent setup-to-victory reference
as soon as a supported path exists, with no fixture bridges. Optimize measured
search/recording costs against exact references and measure fresh complete
matches before promising a sweep rate. Policies remain injected outside the
rules engine; only the selected shipping doctrine needs Godot decision parity.
Common Smart Core, Lord doctrines, serious balance and roguelite work keep their
later [roadmap positions](../FutureFeatures/README.md).
