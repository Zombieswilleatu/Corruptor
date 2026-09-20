# Orias V17: Web activation hits with bounded control credit

V17 changes Web only. Snare's scoring and supporting functions remain identical
to V16, verified by AST hashes and identical results on fourteen saved boards.
Game rules, loadout, candidate generation/retention limits and legality-preview
limits are unchanged. This is the experimental Python doctrine, not a new native
Godot acceptance gate.

## Why change it

The stopped V15/V16 comparison exposed a six-target cap on Web's ordinary
activation-hit score. Six and twenty targets could receive the same 18-point
immediate-hit component while the control component could contribute 48.
In the completed matched subset, activation hits per Web fell from 18.32 to
10.90. That is a measured hit count, not total tactical value or proof that Web
caused each loss. Both powers changed in that experiment, motivating this
Web-only test.

## Changes

- Every ordinary activation hit contributes three points; no six-target cap.
- The existing kill bonus remains six points per potential kill, capped at three.
- Control credit is capped at twelve points, equivalent to four ordinary hits.
  Gate delay, firing coverage, relief and delayed reinforcements retain their
  existing spatial/timing checks. The six-point holding cost is unchanged.
- The existing best-current-cluster target is generated first in each lane.
  Current and forward alternatives remain available within six targets per lane.
- Normal four-slot power retention preserves Snare and the current cluster in
  each lane, with the remaining slot available to additional ranked powers or
  placements. No extra planning or preview slots are created.

The score is a planning heuristic; twelve control points are not a claim of
four measured extra hits.

## Verification

PyPy passes 42 focused tests: 24 Orias methods (including three new regression
cases), eleven coordination methods, five existing focal-comparison methods,
one new Web-only routing method and the all-nine-Lord opening method.
The regression cases verify value beyond six hits, a dense twenty-target group
outscoring six targets with maximum control credit, and cluster retention even
when nearer scattered enemies consume the ordinary anchor search.
All previous Orias checks still pass, including future-wave placement, gate
urgency, no imaginary attack-speed suppression, private-information exclusion,
source immutability, budgets and actual Web/Snare timing.

A same-board audit selects one dense saved decision per completed V16 game,
using the largest original Web-hit forecast as the fixed selection rule. On
fourteen identical public boards, standalone revised target ranking finds more
initial hits on thirteen and ties on one: **329 versus 238** forecast activation
hits. Snare results match on all fourteen and every input view is unchanged.
These deliberately dense regression boards are not a random match sample, nor
are these standalone rankings admitted complete-plan choices or measured kills.

## Predeclared matched experiment

Before launch, the manifest freezes all sixteen cases and source hashes:

- Focal previous policy: V16, commit `9659d8fc70466b98f95a47ee8a20bef9416f8570`.
- Focal candidate: V17 Web-only revision described above.
- Opponent policy in both arms: V15, commit
  `c92181268fae026f30d76d97c2c5b822185848ca`.
- Four diagnostic opponents: Gremory, Deimos, Humbaba and Kalligan.
- One fresh seed per opponent, Orias in both seats, previous and revised arms:
  **16 games / 8 matched pairs / 4 seed-opponent blocks**.
- Namespace `u13-orias-web-only-v17-2026-09-20`; default ordinary five-Castle
  loadout, fixed weights, greedy selection and common engine authority.
- Forty-round cap. Failed/censored games remain explicit and are not defeats.
- Initially eight independent PyPy workers. After four games completed, a
  worker terminated abruptly and the runtime reported an OOM kill. The same
  manifest and byte-for-byte completed records were resumed with three workers.
  Worker count is operational, not a policy parameter. No scoring changes
  occurred during the experiment; interrupted cases were not recorded as losses.

The two seats within each seed are related observations. This is a small,
focused check on the four previously examined opponents, not a general roster
balance result. It compares against V16, not the original V15 Orias.

Run with `Scripts/Sim/run_u13_web_comparison.py --output DIRECTORY --workers 3`.
The older 72-game campaign remains stopped.

## Match results

All **16/16** games completed: 328 rounds, zero game-level failures/censors,
zero rejected legality previews and all eight pairs complete. The operational
worker interruption described above did not remove or alter any declared case.
The launcher default was lowered to three workers after completion; its original
source is preserved with the records. The policy and simulation harness are the
same sources used throughout the measurement.

| Measurement | Previous V16 | Revised Web V17 |
| --- | ---: | ---: |
| Wins | 2/8 | 2/8 |
| Mean rounds | 20.38 | 20.63 |
| Web casts / activations | 53 | 53 |
| Web activation-hit events | 560 | 908 |
| Hits per Web activation | 10.57 | 17.13 |
| Snare activations | 12 | 16 |
| Hunt/Siege in Snare's effective round | 3/12 (25%) | 4/16 (25%) |

V17 gains two old losses, loses two old wins, and shares four losses. Neither
version wins both arms of any pair. Each seed-opponent block has equal win
counts when both seats are combined. This shows changed outcomes but **no win
advantage in the fixed sample**.

| Opponent | V16 wins | V17 wins |
| --- | ---: | ---: |
| Gremory | 1/2 | 1/2 |
| Deimos | 0/2 | 0/2 |
| Humbaba | 1/2 | 1/2 |
| Kalligan | 0/2 | 0/2 |

Activation hits increase **62.1%** with the same number of casts. These are hit
events, not measured HP damage, kills or the total value of slowing. Divergent
games contain different boards and targets after the first changed decision.
The same-board audit independently verifies that the revised target search and
scoring prefer more immediate hits in its fourteen dense regression cases.

The Gremory focal-seat-one pair is illustrative: V16 wins and V17 loses despite
V17 recording 57 versus 26 Web hits in four casts each. Its first changed
round-two Web is selected on the same public board with the same combat order;
both initial choices score two hits and nine control points, but their positions
differ. Later extra hits do not by themselves establish strategic improvement.

## Disposition and next step

Retain V17 as the correction to Web's six-hit cap and omitted cluster candidate,
with no claim of a demonstrated strength increase. Snare's logic remains V16;
its follow-through is 25% in both arms. A separate Snare revision should compare
the supported future attack against competing complete plans rather than only
showing that the attack is feasible. Do not force the subsequent attack after
the board changes. The earlier 72-game V15/V16 campaign remains stopped.

The evidence JSON includes the fixed manifest, all per-game outcomes and
measurements, the saved-board audit, baseline source hashes and operational
retry notes. The companion evidence archive preserves complete compressed
records, frozen policy packages, logs and the launcher used at measurement.
