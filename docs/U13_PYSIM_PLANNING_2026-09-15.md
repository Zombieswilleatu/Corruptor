# U13 PySim planning — round opening, choices and sealed submissions

Status: **Windows Godot 4.7.2 acceptance passed at clean revision `f318d6d`**.
The focused command below is retained for reproduction. This extends the
[accepted foundation at 4e485b1](U13_PYSIM_FOUNDATION_2026-09-15.md).

## Implemented boundary

Python now independently advances a fresh U13 game through these five hooks:

1. `round_start_scheduled`
2. `persistent_advancement`
3. `round_start_automatic`
4. `present_public_state`
5. `submission_lock`

Each comparison includes the complete match snapshot: both world copies,
physical entities and used-ID history, card piles, every clock/queue, ordered
events and their two player views, staged submissions and committed orders.
The mirror starts from its own setup implementation. It never replaces its
state with an expected Godot checkpoint after a transition.

Opening upkeep includes the existing empty-registry clocks, Kroni's initial
Cannibal Hunger event, Kalligan's repair of an opening Circle offering,
Odradek's Reconfiguration gain and Kanifous's keyed first-round smoke target.
These first-round cases do not implement their later powers or spatial effects.

Round draws preserve the ten-card hand limit, private draw identities and
bottom-to-top physical pile order. Stockpile uses the first operational slot;
duplicates do not stack. A full hand or exhausted pile can leave fewer than
two offers, requiring no selection. When two offers exist, the engine pauses
before drawing for the next player. The Stockpile discard can then be recycled
into that player's draw. Slaver first-visitor order, swaps, passes and public
stock identities are reproduced exactly.

Submissions accept power-free Pass, Ward, Hunt, Siege and Profane orders,
including Guard-move and Work-target reservations. Staging stores detached
inputs without paying, moving cards, changing either world or appending events.
The lock hook applies reservations and combat commitments in player order.
Private sealed-order events remain visible only to their owner. Guard cards
remain in Hand until Development; Work targets are reserved without executing
Work. A bad second plan leaves the first unsubmitted, and a duplicate single
submission or a lock with only one submitted player rejects atomically.

The fresh-game adapter deliberately stops **before Development**. It raises an
explicit unsupported-boundary error for later hooks, Lord power declarations,
Resummoning, paid Rites or an active-effect/deployed-unit input. This is distinct
from a supported operation rejected by Godot's rules. It has no external match
restore API. Work settlement, Guard deployment/pair formation, combat, Marching,
later Lord reactions and complete Python round/match parity remain future work.

## Focused evidence and its limits

Accepted Windows **Godot 4.7.2** results (also previously green in local
Godot 4.5.1 diagnostics):

| Comparison | Result |
| --- | --- |
| Godot fixture checks, including decoded export replay | 429 checks, zero failures |
| Fresh-game Lord cases | 9; every Lord in both seats |
| Full game snapshots compared with independent Python state | 231, including nine initial snapshots |
| Recorded game operations | 222: 82 accepted and 140 rejected |
| Isolated economy component transitions | 21 across seven directed cases |
| Standalone timeline transitions | 52, including all 20 hooks in each of two rounds and rejected attempts |
| Python unit tests | 13, including the six foundation tests |
| Deliberately corrupted evidence rejected | 11 |

The seven economy cases cover recycle-before-hand-limit, discard-only draws
without recycling, empty piles, Stockpile discard recycling between seats,
a single Stockpile offer, exhausted Slaver stock reuse, and refresh drawing
from a recycled discard before returning old offers to the deck bottom.

Component fixtures repack known physical cards into explicit piles, keeping
unused cards in a committed reserve. Those inputs are checked by the Godot card,
economy and market validators, and are independently reconstructed in Python.
They isolate pile behavior; the large committed reserve is not a legal player
plan or a claim about an attainable whole-game state.

The standalone timeline fixture checks cursor order, handler rejection,
completion and reset across two rounds. It uses empty handlers. It therefore
certifies the cursor contract, not the game mechanics of the fifteen later
hooks. The nine game traces provide actual authoritative behavior for the first
five hooks and stop at the Development cursor.

Negative probes alter source identity, rollback state, cursor round, the final
lock record, order fields, Guard slots, private event views, deck/market order
and timeline execution rows. Each must fail at the changed field or the missing
coverage boundary. Missing/extra fields and numeric/type differences still use
the foundation's exact comparator without rounding tolerances.

The original 100-game Random-Legal campaign at `357d793` and Windows foundation
gate at `4e485b1` retain their original identities. This subsequent slice has
its own Windows acceptance evidence at `f318d6d`.

## Trace and implementation identity

- Suite: `U13_PYSIM_PLANNING_SUITE_V1`.
- Game trace: `U13_PLANNING_TRACE_V1`; producer `U13_PYSIM_PLANNING_EXPORT_V1`.
- Mirror: `U13_PYSIM_PLANNING_V1`.
- Transport: existing `U13_EXACT_DATA_V1`.

Planning traces include rejected attempts and direct single-player submissions,
so they have a distinct identity from the foundation's successful-operation
trace contract. Godot replays every accepted and rejected operation after the
exact export is decoded. Python independently checks the full resulting state,
return value and outcome after each operation, including rollback.

Code lives in `Scripts/Sim/u13_pysim/{timeline,economy,planning,verify_planning}.py`.
`U13PySimPlanningTestRunner.gd` supplies the authoritative fixtures; the existing
CLI dispatches the new `verify-planning` and `self-test-planning` commands. The
foundation trace validator retains its original defaults and accepts an explicit
schema/producer for this separate corpus. No live Godot rules, playable UI,
sprites, U12 files, legacy Python simulator or old goldens are changed.

## Windows acceptance

Accepted archive, reviewed on 2026-09-15:
`u13-pysim-planning-LLBxFN-2026-09-14_22-55-12-IV7Deo.zip`.

- Clean source revision: `f318d6d775901c86c3bdb27c966bfb6e649256b6`;
  packaged working diff is empty.
- Simulation/tool source SHA-256:
  `3ba32423b5f95c880185744430ba1788aa100d6d4e12c5cf875a03afde4f0838`.
- Runtime: Windows `4.7.2.stable.official.ed1daf0bf`; Python `3.14.7`.
- Runner exit status zero, `diagnostic_only=false`, zero failures or script
  errors. All results in the table above passed, including nine decoded Godot
  trace replays and eleven deliberate corruption rejections.

The attached export was decoded and all Python result/state/outcome comparisons
and corruption probes rerun against the pinned source. They agree exactly with
the supplied Windows summary. [Machine-readable evidence](evidence/U13_PYSIM_PLANNING_f318d6d.json)
records the cases, provenance, archive hash and every member hash. This closes
the planning gate; no repeat run is needed for this documentation update.

Requires Git Bash, **Godot 4.7.2 stable on Windows** and Python 3.10+; no pip
packages are needed. The runner discovers Python or accepts its executable as
an optional second argument.

```bash
cd "/c/Users/jerem/OneDrive/Documents/Corruptor-U13-Perf" &&
git pull --ff-only origin u13-basic-doctrine &&
bash Scripts/Sim/run_u13_pysim_planning.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
```

The runner has the existing 180-second per-stage watchdog and 15-second progress
heartbeat. It checks process exit, script errors and completion footers, then
packages one ZIP in Downloads with exact traces, source identity, working diff,
runtime/Python versions, logs and summary. Acceptance verifies the actual
Windows platform/runtime and recomputes the checkout's revision and source hash.
Local diagnostic mode remains explicitly separate.

Next, extend from the established lock boundary through
Development: Guard deployment, Work settlement and stable pair identity, with
their directed timing/repair-lock cases. Full-round reference games, Common
Smart Core/Lord doctrines, balance and roguelite work remain later milestones.
