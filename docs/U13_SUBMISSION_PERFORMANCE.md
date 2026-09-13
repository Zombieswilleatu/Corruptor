# U13 joint-submission performance

2026-09-13. Resumes the doctrine/simulation work after the playable build.
Reference: `e680d28673a7a30d26cf8f2ff3c5de97b807adbe` on
`u13-basic-doctrine`.

## Measured problem and change

`U13GameConductor.submit()` constructed a new content owner and loaded a complete
snapshot before accepting the two plans. This walked, normalized and checked the
entire event history every round, even though that history was already owned and
validated. Its cost grew with prior rounds, independently of candidate count.

The conductor now creates its temporary transaction through `U13Match._clone()`,
the existing internal path used by hooks and previews. It checks live temporal
consistency, copies mutable world/queues/orders/registries, and shares immutable
past event rows through separate outer arrays. Both seats still use the normal
submission validator. The live owner is replaced only after both succeed.

No save format, game rule, doctrine score or information policy changes. External
`restore()` / `restore_json()` still validate the full supplied save. Hidden guard
faces remain outside the bot facade. This removes a redundant internal reload;
it does not remove independent save/replay checks from the campaign runners.

The original joint-submission function is preserved in
`U13SubmissionReference.gd`. The comparison runs both paths with the same current
content, plans, input state and engine. It checks exact state after submission and
after every subsequent hook, both player histories, and external save restoration.
Timing covers joint submission only; planning, setup, replay and equality checks
are outside the measured interval. Execution order alternates between cases.

## Directed acceptance

Run from the doctrine worktree:

```bash
bash Scripts/Sim/run_u13_submission_perf.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
```

The Windows 4.7.2 gate covers nine Lord pair openings, plus two fixtures with
2,000 prior public/private events (compact and full trace). These extra histories
are explicitly synthetic; they isolate history size without claiming to recreate
a late-game board. It also checks invalid first/second plans, retry and duplicate
submission, original-owner isolation, concealed history, temporal inconsistency,
and malformed external saves. No long campaign is launched. A fresh ZIP appears
directly in Downloads and the runner prints `UPLOAD THIS FILE:`.

For developer profiling, the GDScript runner also accepts repeatable
`--checkpoint=/path/to/game-NNN-checkpoint.json` arguments. Each campaign
checkpoint is independently restored for three alternating-order comparisons.
The report identifies engine, OS, processor, round, history size and timing scope.

## Local evidence

Diagnostic engine: Godot 4.5.1 stable on Linux, AMD EPYC 7763 host. One comparison
process; these are not Windows 4.7.2 acceptance results. The saved-state cases use
the uploaded game-079 round-15 and game-039 round-25 campaign checkpoints.

| Joint submission | Previous path | Internal transaction | Reduction |
| --- | ---: | ---: | ---: |
| Nine openings, summed | 1,768 ms | 1,414 ms | 20.0% |
| Round 15, median of three | 457 ms | 204 ms | 55.3% |
| Round 25, median of three | 881 ms | 257 ms | 70.9% |

The two synthetic history cases measured 275→159 ms (compact) and 271→148 ms
(full trace). Across 17 cases, 481 correctness checks passed, including 272 exact
hook comparisons. The report-file open check also passed. No failures or script
errors were reported. The existing playable-session fixtures also passed, covering production
submission, worker/session isolation and exact independent replay.

The gain applies to submission, not the whole simulation. Planning, actual
Marching, resolution validation and explicitly requested replay/save work remain.
Do not extrapolate these numbers into a promised full-campaign speedup. Use the
short Windows comparison first, then the current doctrine campaign for action
coverage and termination. Avoid turning the 100-game random-legal campaign into
the routine regression gate.
