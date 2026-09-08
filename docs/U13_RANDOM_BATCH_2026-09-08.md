# U13 Gremory random-legal frequency batches

## Checkpoint

The user accepted the responsive worker-board performance pass on Godot 4.7.2.
This change resumes the next open requirement: the random-legal tier and measured
Gremory batches. Implementation is ready for local engine verification. Do not
start another Lord until the full foundation wrapper and these batches are green.

These are bounded trials of the current combat slice, not complete games or
balance evidence. Both players use the same chooser and can spawn Marchers. The
opening is the existing SmokeSession world: four cards, two Wright guards and a
damaged plain Integrity Castle per player. It does not use the dense 48-unit test
fixture. Development, normal round draws, Hunt, victory, personal Tear/Veil
progression, waiter spending and other Lords remain absent. The small opening Hand
can deplete; reports retain those later rounds rather than silently replenishing it.

## Choice contract

`U13GremoryCandidates` enumerates the finite Gremory payload vocabulary from the
choosing player's projection. `U13Legality` filters every complete candidate
through `U13Match.preview_submission`. It canonicalizes unordered physical-card
payments and deduplicates equivalent candidates before any lottery.

`U13RandomLegal` selects a legal power name uniformly, then a complete payload for
that power uniformly. Gremory payloads are the two Predator lanes and each enemy
Castle paired with each unordered two-card Ruin payment. Choosing power names
first prevents Ruin's larger payment domain from giving it more power-choice
weight. At most one power is selected by this policy each round. If none is legal,
the power list is empty. The policy then selects uniformly from legal single-card
or unordered-pair Siege/Ward orders, validated with the chosen power payment.
With no legal combat order it passes combat. Final whole-plan validation and normal
`submit`/joint lock still own costs, cooldowns, targets and conflicts.

The keyed RNG uses the actual match seed, round, player, policy version, decision
identity and purposes `BOT_POWER_CHOICE`, `BOT_POWER_TARGET`, `BOT_COMBAT_CHOICE`.
There is no sequential random stream. Changing a candidate domain can change that
choice, but cannot consume or shift another decision's draws. A supplied real
doctrine callback owns the decision, including intentional pass; an invalid real
doctrine result is an error, not a reason to silently use random fallback.

The board now delegates to this same chooser. `U13_RANDOM_LEGAL_V1` pins the new
canonical ordering and keys; individual opponent choices may differ from the old
board-only chooser. Spatial/amount payload policies must be specified when content
requiring them arrives; this implementation does not pretend to enumerate them.

## Measurement contract

Each round retains:

- Marcher counts at `MARCHING_STARTED` and `MARCHING_FINISHED`, by owner and total;
  peak total and owner counts at hook boundaries and every Marching tick.
- Spawns by owner, arrivals by owner/lane, waiter peak and time present, and time
  with at least five waiters. Duration is measured in the 200 fixed Marching ticks
  per round, not wall time. Existing waiters are not counted as new arrivals.
- Power declaration, resolution and fizzle counts; fizzle reasons; named Gremory
  passive events; Tear amounts by source; Castle destruction count; Neutral Tears
  at round end.
- Positive net Soul changes per hook and player. These are explicitly hook-level
  resource deltas, not invented per-power attribution or gross transaction totals.
- Both-player pass rounds. Each trial also reports unchanged public-world rounds
  and outstanding delayed effects at its fixed round limit. Neither is a proof of
  a stall; ending at the limit can censor a delayed power's eventual result.

Compact Marching tick rows are decoded against the phase-start unit, preserving
unchanged attributes such as waiting status. Counts include zero-density rounds.
Summaries provide sample size, min/max/mean and full histograms separately for
start, end and peak density, plus raw frequency totals. Per-round owner counts and
spawn flags allow the both-sides-spawning subset to be inspected without hiding
rounds where one side could not spawn.

Personal Tears and threshold-power ratios are `null`, not zero: those systems or
counted-threshold active powers are absent in this Gremory slice. Waiter >=5 counts
are observations only; no waiter conversion mechanic is implied. When threshold
powers arrive, report declared count, threshold-met count and their ratio, retaining
an undefined ratio when the denominator is zero. No win rates are reported and no
threshold is tuned from these trials.

## Determinism and failure handling

Every seed is run twice from the same opening. The runner compares the complete
trial result, including all per-round telemetry and SHA-256 digests of decisions
and the authoritative state/event snapshot. Only the first run contributes samples.
Reports include seeds, policy/model versions, round limit and missing systems.
Each round must observe exactly 200 Marching ticks and both boundary events.
A bounded hook counter and launcher watchdog surface non-progress.

The launcher writes a temporary report and publishes it only after a zero exit,
nonempty report, exact completion footer and no logged engine/test errors. Failure
preserves the previous successful JSON and retains the current log. Its default
300-second limit is for the entire batch including replay, not the 30-second
per-suite foundation gate.

## Local acceptance

From the U13 checkout in Git Bash:

```bash
u13_godot="/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
git pull --ff-only origin u13-lord-overhaul &&
bash Scripts/Sim/run_u13_foundation_tests.sh "$u13_godot" &&
bash Scripts/Sim/run_u13_random_batch.sh "$u13_godot"
```

Expected footers: `U13 foundation runners passed: 16/16` and
`U13 random-legal batch completed: OK`. The default batch has four seeds and six
rounds per seed (24 measured rounds, plus 24 replay rounds). Share
`~/Downloads/u13_random_legal.json` and `~/Downloads/u13_random_legal.log`.
Run only the batch again with the last command; no visual board launch is needed.

Optional launcher arguments are `--trials=4`, `--rounds=6`, and
`--seed-prefix=u13-frequency-v1`. `U13_RANDOM_REPORT` and `U13_RANDOM_LOG` override
output paths; `U13_BATCH_TIMEOUT_SECONDS` overrides the batch watchdog. Use a new
seed prefix for an independent sample, and keep the pinned opening/sampling scope
when comparing reports.

## Verification available in the implementation environment

GDScript grammar parsing and Bash syntax checks were run. A simulated executable
checked launcher success, logged engine errors with exit zero, missing footer,
nonzero exit, timeout, paths with spaces and preservation of prior reports. These
checks do not execute Godot or validate its compiler. Godot 4.7.2 runtime acceptance
and the first real frequency report remain pending on the user's machine.

`U13RandomLegalTestRunner` covers candidate deduplication, equal power-choice
weight domains, enemy Ruin targets, whole-plan payment legality, both-player
submission, real-doctrine precedence, deterministic selection, compact-event
telemetry, zero/absent metrics and independent two-round replay. The full wrapper
adds this as suite 16 and retains the 30-second per-suite gate.


## Accepted Gremory report and Deimos extension

The user verified the four-seed/six-round Gremory batch on Godot 4.7.2 and approved
proceeding. All replays matched, all rounds included 200 ticks, both sides spawned
48 units, and all 34 power declarations resolved (24 Predator, 10 Ruin). Start
density was mean 9.08, median 8.5, range 3–16. Both sides spawned in 11/24 rounds.
This is an accepted measurement-path checkpoint, not shipping-roster balance data.

The [Deimos artillery slice](U13_DEIMOS_ARTILLERY_2026-09-08.md) adds an explicit
second profile and optional `--roster=mixed` / `--roster=deimos` batches, each with
its own Downloads report name. The full foundation suite is now 17 runners.
Personal Tear counters in the new profile cover Spoils of War only; Veil and the
rest of the economy remain absent. Existing sections above describe the original
Gremory profile and its historical 16-suite acceptance command.


## Construction/activation exercise mode

`--roster=construction` adds protected Construction, optional activation at seven,
Repair and War Foundry to the mixed fixture. It writes
`u13_random_construction.json` and `.log` in Downloads. Reports pin the Construction
and Castle chooser policies, count Castle actions/reconstruction, and include the
distribution of Integrity when Castles activate. See
[the Construction contract and 18/18 gate](U13_CONSTRUCTION_2026-09-08.md).
This new mode awaits authoritative local Godot 4.7.2 verification.

## Castle loadout / Rout mode

`--roster=loadout` exercises two commissioned Siege Engines per side plus three
unbuilt Castle instances, using five chosen slots with at most two per type and
one shared Castle Guard zone per player. It uses the same 300-second batch
watchdog and saves `u13_random_loadout.json` / `.log` in Downloads. Deimos's
candidate domain now includes Rout in all Deimos-enabled modes. Reports include
per-Engine shot counts and Rout cohort/recovery counters. See
`U13_CASTLE_LOADOUT_ROUT_2026-09-08.md` for fixture limitations and local gates.
