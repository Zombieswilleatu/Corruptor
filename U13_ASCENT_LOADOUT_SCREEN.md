# Ascent castle-loadout screen

Prepared 2026-09-29. This branch adds an experiment runner, not gameplay changes.

**Execution status:** the preparation environment could access GitHub but had no functioning execution workspace. The Python runner has been reviewed against the published simulator interfaces but has NOT been executed here. Run the local preparation checks and the 12-game smoke check before starting the long screen.

## Question and scope

Which opening castle combinations help each Lord use their existing kit?

This is a controlled five-slot self-play screen to shortlist Ascent enemy loadouts. It is not the final Ascent difficulty test. Both players retain one of each castle, with three starting active. Only the focal Lord's castle order changes; the opponent keeps the control. No stat, resource, victory, or doctrine changes are introduced by the runner.

| Profile | Active slots 1–3 | Unbuilt slots 4–5 |
| --- | --- | --- |
| control | Keep, Stockpile, SummoningCircle | SiegeEngine, Bastion |
| stock_engine | Keep, Stockpile, SiegeEngine | SummoningCircle, Bastion |
| stock_bastion | Keep, Stockpile, Bastion | SummoningCircle, SiegeEngine |
| circle_engine | Keep, SummoningCircle, SiegeEngine | Stockpile, Bastion |
| circle_bastion | Keep, SummoningCircle, Bastion | Stockpile, SiegeEngine |
| engine_bastion | Keep, SiegeEngine, Bastion | Stockpile, SummoningCircle |

Keep stays in slot 1; other castles keep their canonical relative order within active and unbuilt groups. This does not isolate every positional effect. Duplicate castles and all slot permutations are out of scope.

Deimos with an active Siege Engine is the first known hypothesis; other Lords' best combinations remain to be measured.

## Size and pairing

- Nine Lords, eight nonmirror opponents, both seats.
- One seed per unordered matchup per repeat, held constant across loadout treatments and seat swaps.
- 72 unique control games reused across the focal-Lord comparisons.
- 720 treatment games: five alternate profiles × nine Lords × eight opponents × two seats.
- **792 unique games per repeat**, giving each Lord/profile 16 paired observations.
- Matchup blocks have a control followed by treatments. Blocks are deterministically mixed across matchups rather than running one Lord's whole campaign first.
- Shared controls and paired seats are correlated; do not pool them as independent observations or treat the best screening result as a proven optimum.

The smoke check is a separate 12-game output: Deimos vs Orias, six profiles, both seats. It checks execution, not balance.

## Install only the runner

Use the current working tree that contains your installed Ascent patches. Do not switch to this experiment branch: its base may predate your local cumulative patches.

In Git Bash:

~~~bash
cd "/c/Users/jerem/OneDrive/Documents/Corruptor-U13-Theater" &&
git fetch origin u13-ascent-loadout-screen-20260929 &&
test ! -e Scripts/Sim/run_u13_ascent_loadouts.py &&
git show FETCH_HEAD:Scripts/Sim/run_u13_ascent_loadouts.py > Scripts/Sim/run_u13_ascent_loadouts.py
~~~

The existence check intentionally stops if the runner is already present.

## Prepare without playing

~~~bash
python Scripts/Sim/run_u13_ascent_loadouts.py \
  --output "$HOME/Downloads/Corruptor/Balance/ascent-loadout-screen" \
  --workers 3
~~~

Default behavior is preparation only. This freezes the installed simulation source, including uncommitted Python/GDScript changes, and constructs every opening through PowerMatch. It checks castle order, three active/full-integrity castles, two unbuilt castles, paired seeds and unchanged opening card shuffles.

A changed roster or control loadout causes an explicit stop rather than silently changing the experimental question. Failed preparation is not safe to resume; use a new output directory after resolving the error.

The snapshot uses the existing balance runner's source selection. It is not a complete game build and does not freeze art, sound or Godot presentation scenes.

## Smoke check, then long run

~~~bash
python Scripts/Sim/run_u13_ascent_loadouts.py --smoke --run --workers 3
~~~

Check that it exits successfully with 12/12 saved games and no failures or unresolved outcomes. The report location is printed. Do not choose loadouts from these smoke results.

Then start the prepared snapshot:

~~~bash
python Scripts/Sim/run_u13_ascent_loadouts.py \
  --resume "$HOME/Downloads/Corruptor/Balance/ascent-loadout-screen" \
  --run --workers 3
~~~

Three workers are the default, recycled after 12 games total. No runtime estimate is assumed; use the smoke run to judge local speed. Keep the computer awake if you want continuous overnight progress.

Resume with the same command. It verifies saved per-game records and reuses the frozen source, not subsequent changes in the checkout. Use the same Python installation when resuming. Only run one process against a given report directory.

Failed game records remain visible and are not silently retried. Do not delete evidence to turn a failed screen into a clean result; inspect errors and prepare a separate run after fixing the cause.

## Reports and partial results

The output includes:
- Frozen source and hashes.
- loadout-config.json with cases, profiles and exact control/treatment pairings.
- loadout-preflight.json with opening-check counts.
- manifest.json with installed policy, source and victory requirements.
- Compressed per-game outcomes, operations and decision traces.
- loadout-report.md and loadout-report.json.
- A ZIP beside the output folder after execution or summarization.

To summarize/package a stopped run:

~~~bash
python Scripts/Sim/run_u13_ascent_loadouts.py \
  --resume "$HOME/Downloads/Corruptor/Balance/ascent-loadout-screen" \
  --summarize
~~~

Paired reports use only complete, resolved control/treatment pairs. Missing, failed, and unresolved games are listed explicitly. Control wins are recalculated on the exact paired subset, so partial treatment results are never compared against all control games.

Metrics include wins gained/lost, paired win-rate difference, rounds, both seats, opponent breakdowns, declared powers, selected actions, rejected previews and win routes. Power declarations do not prove successful resolution; inspect traces when that matters. The generic survey summary is not a castle-loadout ranking.

## Decision after the screen

Shortlist sensible, kit-supporting loadouts; check whether gains persist across opponents and seats and whether they worsen pacing. Validate finalists on fresh seeds before adoption. Then test them in native Ascent against actual three-castle player starts and relevant retinue/inheritance progression. This screen alone cannot establish the final stage difficulty curve.

No gameplay values are changed automatically, and no loadout is selected or shipped by this runner.
