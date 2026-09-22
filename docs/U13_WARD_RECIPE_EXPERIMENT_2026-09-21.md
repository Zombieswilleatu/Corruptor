# Ward / attack recipe experiment

Base: `0d964b322fb4e0aa3fb2020cc67bfe10cdf302b8`, branch `u13-basic-doctrine`.
Candidate policy: `U13_COMMON_SMART_CORE_ALPHA_V28_ATTACK_RECIPES`.

## Change

Ward keeps its existing screening, Sigil/threat effects, and normal recruits
at floor(printed suit total / 2). It cannot declare a new recipe monster.
Hunt and Siege keep normal recruits at floor(printed suit total / 3) and
their recipe access. Existing field and staged monsters are unaffected.

Python and Godot enforce the action restriction in order shape, recipe
admission, and recruitment reveal. Godot snapshot validation also rejects
invalid pending recipe orders. The playable picker clears a selected recipe
when switching to Ward and its help text explains the restriction. The
legacy native bot attaches recipes only to attacks.

The Python doctrine no longer attaches recipes to Ward. For each available
exact recipe, it scores legal Hunt and Siege targets using the same
recruit/guard/damage/banishment/destruction/pillage terms as ordinary attacks,
plus the monster's lane value. It keeps the better attack per recipe with
deterministic ties. At most ten dedicated recipe candidates fit the unchanged
16-generation / 4-retention monster budget. A banished enemy Lord removes
Hunt; castleless Siege uses the existing pillage target. Shared-card admission,
limited-copy accounting, and final native preview remain in force.

## Focused checks

New Python tests cover all ten recipes on both Ward lanes, atomic rejection,
ordinary Ward recruits and Sigils, all ten recipes on both attacks, attack
scoring, absent enemy Lords, existing field monsters, and staged release.
The existing reserved-recipe test now checks attachment to Hunt, so it still
tests the living-copy restriction rather than succeeding merely because
Ward is forbidden. Monster admission parity inputs include rejected Wards
and use Hunt for successful summons. Full-game fixture attachment also
respects the action restriction.

The native focused runner checks recipe admission and reveal, both recruit
ratios, field-monster preservation, and the playable picker.

Runtime status at preparation: **not run**. The authoring session exposed
GitHub tools but no shell, Python, or Godot runtime. Source checks are not
runtime tests or native parity evidence.

Follow-up baseline compatibility fix: 24 Python tests now pass locally,
including the 20 focused Ward/recipe tests and four runner regression tests.
Godot checks and the paired comparison still await execution.

## Bounded paired comparison

`Scripts/Sim/run_u13_ward_experiment.py` first runs focused Python tests and
the native Ward runner. A failed check prevents simulation. It then freezes
the candidate source and runs **18 fresh games with exactly two workers**,
recycling the pool after four games. No full 810-game survey is launched.

The fixed matchup ring is Gremory → Humbaba → Kroni → Odradek → Valak →
Kalligan → Deimos → Orias → Kanifous → Gremory, with both seat orders for
each edge. Candidate cases reuse the archived baseline's exact seeds,
loadouts, seats, and weights. Baseline simulation/policy Python is checked
against either the complete `f89384d` original campaign source or the complete
`0d964b3` optimized pre-change source. The former predates `process_memory.py`
and the parity-checked memory optimization documented in
`U13_SIM_MEMORY_PERFORMANCE_2026-09-21.md`. No missing-file exception is used:
missing, added, modified, and mixed-version Python sources still fail closed.
The matched baseline revision is recorded in the config and comparison.
Incomplete or mismatched records also fail closed. The archived 18 games are
reused, not rerun.

This compares the combined rules/doctrine change in self-play. It does not
isolate the rule effect from the doctrine effect, establish policy strength,
or provide a balance verdict. Reports include per-case outcomes, round
deltas, Ward share deltas, action counts, recipe action counts, event counts,
rejected previews, source identities, and worker memory. Failed games stay
explicit; any selected Ward recipe fails the candidate screen.

From the repository root in Git Bash:

```bash
bash Scripts/Sim/run_u13_lord_balance.sh --ward-experiment \
  --godot "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
```

The launcher selects PyPy and prints its executable/version. Candidate games
use the optimized current source, two workers, and four-game pool recycling;
the legacy baseline is only read for comparison, never used to run new games.

The latest pre-change report under Downloads/Corruptor/Balance is selected
by default. Supply `--report "/path/to/report-folder"` if necessary.
`--prepare-only` validates baseline records, runs focused Python checks,
and freezes the source without starting workers; pass `--godot` to include
native checks in preparation. Outputs and a ZIP go under
Downloads/Corruptor/Balance/ward-experiment-TIMESTAMP.

Old snapshots containing a pending Ward recipe order do not satisfy the new
rules. Existing monsters themselves remain valid. Use fresh games for this
experiment.
