# U13 PySim parity — inspected baseline and first milestone

Status update: the first foundation slice passed Windows Godot 4.7.2 acceptance
at clean revision `4e485b1`: 14 exact Python opening snapshots, 49 Godot-replayed
operations, and ten rejected evidence corruptions. See
[foundation implementation and accepted evidence](U13_PYSIM_FOUNDATION_2026-09-15.md).
The [planning slice](U13_PYSIM_PLANNING_2026-09-15.md) now implements the first
five game hooks, sealed submissions and opening-round economy. Windows Godot
4.7.2 acceptance passed at clean `f318d6d`, including 222 exact game operations
and eleven rejected evidence corruptions. The
[Development slice](U13_PYSIM_DEVELOPMENT_2026-09-15.md) now extends through
Guard deployment and Work/pairs, with Windows 4.7.2 acceptance passed at clean
`108fc15`: 90 exact match snapshots, 217 component operations and 14 rejected
evidence corruptions. The separate Windows timing probe measured 31.35 ms mean
per opening-through-Development cycle; it is not a full-match speed measurement.
The subsequent [resolution slice](U13_PYSIM_RESOLUTION_2026-09-15.md) now extends
through artillery, commitment and ordinary combat, including immediate reactions;
its focused Windows 4.7.2 acceptance passed at clean `e51588d`: 1,632 Godot
checks, 252 exact snapshots, 241 component operations, 36 Python tests and 16
rejected evidence corruptions. Independent Python replay reproduced the complete
uploaded summary. It stops before Post-Resolution and Marching, and does not
implement subsequent rounds or full matches.
The [copying optimization](U13_PYSIM_COPYING_2026-09-15.md) passed its combined
planning/Development Windows 4.7.2 gate at clean `88ef438`: 926 Godot checks,
321 exact snapshots, 27 Python tests and 25 rejected evidence corruptions.
The matched Windows partial comparison measured 20.31 to 7.98 ms (2.54×), with
identical exact results. It changes no parity boundary or full-match speed claim.
This document retains the initial inventory and subsequent implementation
boundaries. The [accepted checkpoint](U13_ACCEPTED_CHECKPOINT_2026-09-15.md) clears
the pending mechanics-validation bookmark.

Reviewed the original `CORRUPTOR_U13_ASTRA_HANDOFF_2026-09-08.md` (authority
precedence, Implementation Plan v3, doctrine tiers and determinism gate), the
repository's [post-overhaul roadmap](U13_POST_OVERHAUL_ROADMAP.md), and existing
Python/Godot code. The latest authorized mechanics supersede older design
notes. Godot U13 is the authority; PySim is its behavioral mirror.

## What already exists

| Existing component | Finding | Reuse decision |
| --- | --- | --- |
| `corruptor_sim.py` | `SIM_VERSION = 7.6.2-defunct-repair-lock`; legacy `Player` / `Game`, paid repairs, live repair tokens, older Lord kits and lane-step Marching | Preserve as the legacy simulator. Reuse audited arithmetic/ideas only; it is not a U13 engine with a few missing flags. |
| `golden_serializer.py` | Schema 4; face tokens such as `Butcher:4`, sorted Guard multisets, legacy player flags | Reuse the explicit versioned-schema approach. Face tokens cannot replace U13 physical IDs or ordered Guard slots/bonds. |
| `golden_master.py`, `golden/`, `GOLDEN_HARNESS_README.md` | Existing deterministic traces, drift/identity checks and structural comparison contract; historically Python is oracle | Keep these legacy contracts intact. New U13 traces must explicitly reverse authority to Godot; do not regenerate old goldens as U13 evidence. |
| `lord_matrix_master.py`, `lord_matrix_soak_master.py`, `corruptor_softmax_policy.py` | Existing matchup/measurement and policy harnesses | Reuse scheduling/reporting concepts later. Legacy bot action equality is already an optional diagnostic, not mechanics parity. |
| `tests/` | Existing Python mechanics/conservation/identity tests | Retain as legacy regression coverage. They cannot certify absent U13 rules. |
| `U13GameConductor.gd` | Public start, step, setup choices, submit, finish-round, snapshot and restore boundaries | Source for a separate trace exporter; preserve the live conductor's authority. |
| `U13Match.gd` | Versioned snapshot includes world, presentation baseline, sealed orders, timeline, pending/persistent effects, cooldowns, RNG identity and event history | Inventory every outcome-relevant field before choosing a comparison projection. |
| `U13FullMatchBatch.gd` | Replay checks at planning/resolution, per-round plans and full-state hashes | Reuse chosen setups/plans as inputs; batch hashes alone do not expose the first differing field. |
| `U13KeyedRng.gd`, `U13EntityIds.gd`, `U13EffectData.gd` | Explicit stable identity and SHA-256 keyed rejection RNG; RNG framing counts UTF-8 bytes while entity/effect ID framing counts Unicode characters | First exact Python primitives, checked against existing Godot vectors. Legacy sequential Python RNG is not equivalent. |

At initial inventory, no U13 Python package, U13 trace schema or cross-engine
U13 replay adapter was found. Existing legacy Python code has Marching, but its lane-step
representation does not implement the current fixed-step spatial U13 field,
contacts, hazards, waiting queues or spatial Lord actors.

## First implementation slice: trace contract and deterministic foundation

Create an isolated U13 Python namespace and a Godot-owned trace exporter. Keep
the legacy Python simulator, old goldens and U12 untouched. This slice should
finish with exact comparison of deterministic primitives and an opening state;
it must not claim full-match parity.

1. **Pin identity and transport.** Record schema, Godot source revision and
   runtime, match engine/policy/rules identities, RNG version, event profile,
   setup, seed and trace-producer version. Keep any policy used to generate
   inputs as separate provenance, so replaying explicit inputs does not require
   Python to reproduce that bot's decisions.
2. **Capture every external choice.** Record initial Lord/Castle selection,
   Stockpile keep choice, Slaver choices (including pass), complete submissions
   with Rites/Guard placement/Work/powers, and explicit execution order. Advance
   through `to_planning(false)`, the public choice methods and `step()` rather
   than asking a Python bot to guess what the Godot bot did.
3. **Export phase state and events.** Start with setup, planning, each named
   authoritative hook, and terminal outcome. Include IDs and registry history,
   ordered deck/discard/hands/Guard slots, bonds, Work, Castle incarnations,
   resources, Lord state, timeline/queues/clocks, Marcher state and spatial
   effects. Compare gameplay event order and data; explicitly document any
   excluded visual-only samples. Reject unexpected/missing fields rather than
   silently dropping them.
4. **Make number handling lossless.** `snapshot_json()` currently wraps Godot
   Variant bytes in base64 to preserve floating-point bits; its payload is not
   a portable JSON state for Python. Define a separate data-only export with
   exact integer/fixed-point values and an explicit lossless representation of
   remaining floats. Round-trip it on the acceptance runtime before relying on
   it. Do not round spatial values or introduce a tolerance to hide drift.
5. **Port the shared primitives and opening.** Match character-length-prefixed IDs,
   `U13_SHA256_REJECTION_V1` (including Unicode/retry/full-range vectors), deck
   physical IDs, keyed shuffle and initial loadout/opening state. Reuse current
   Godot fixtures as the source; no change to their rules.
6. **Prove the comparator fails usefully.** Exact structural comparison should
   report the first differing phase and field. Directed negative cases must
   reject wrong identity, missing/extra fields, changed card IDs/slots/order,
   changed RNG results and altered numeric values. Repeated export and replay
   of the same explicit inputs must agree, without reading private state into
   a player-facing policy view.

The first gate is a short primitive/opening fixture set on Windows Godot 4.7.2
plus Python, with deliberate mismatch detection. Local 4.5.1 remains diagnostic.
Do not require a 100-game run to develop this boundary.

## Why the accepted ZIP is useful but not a parity corpus yet

The ZIP includes 100 explicit setups, round plans, outcome/coverage data and
round-end state hashes. It proves replay consistency in Godot at 357d793. It
does not include full successful-game state snapshots or explicit Stockpile /
Slaver choice records. The batch's `to_planning(true)` makes those choices
internally. Successful checkpoint save files are removed by the runner.

Preserve this archive as historical evidence. A later exporter can replay its
setups/plans under a pinned revision, while reconstructing and recording the
original deterministic setup-choice policy. It must verify the original hashes
before labeling those exported traces as reproductions of the campaign.
Exports on the integrated public-Guard revision are a distinct corpus identity.
Do not call the original ZIP Python parity evidence or silently relabel it.

## Subsequent parity order

After the first slice, mirror the timeline and sealed submissions, economy and
Guard Work/pairs, ordinary combat/defenses/victory, then fixed-step Marching and
Lord effects in dependency order. Use small directed cases for cooldowns,
delayed effects, pair breakage, reconstruction/repair locks, Supplicant
consumption, allegiance, same-hook ordering and deterministic retargeting.

Only after these pass should the roadmap's approximately 50–100 deterministic
reference games become a full cross-engine gate. Compare identical explicit
inputs and state, not independently selected bot actions. Start performance
measurement during the parity build, including a spatial spike before completing
Marching and throughput measurement of the first supported full-match path.
The current partial timing probe does not establish complete-match speed.
Keep experimental Python policies swappable; only the shipping doctrine needs
Godot decision parity. Follow the
[policy and performance gates](U13_PYSIM_POLICY_AND_PERFORMANCE_2026-09-15.md),
then move into Common Smart Core + per-Lord doctrines. Serious balance
and roguelite progression remain later milestones; no balance edits accompany
this inventory.
