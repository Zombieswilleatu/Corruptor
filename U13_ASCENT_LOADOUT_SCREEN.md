# Ascent castle-loadout screen

Updated 2026-09-29 to V2 with duplicate castle starts. This branch adds an experiment runner, not gameplay changes.

**Execution status:** the original six-profile runner passed the user’s local 12-game smoke check: all openings checked, no failures, unresolved games or excluded pairs, exit code 0. The V2 duplicate expansion has NOT been executed here because the execution workspace remains unavailable. Run its local preparation checks and new 20-game smoke check before starting the expanded screen.

## Question and scope

Which opening castle combinations help each Lord use their existing kit?

This is a controlled five-slot self-play screen to shortlist Ascent enemy loadouts. It is not the final Ascent difficulty test. Both players retain five total castle slots, with three starting active. Only the focal Lord's castle loadout changes; the opponent keeps the control. The original six profiles retain one of each type; each duplicate profile replaces one type with a second copy of another. No stat, resource, victory, or doctrine changes are introduced by the runner.

| Profile | Active slots 1–3 | Unbuilt slots 4–5 |
| --- | --- | --- |
| control | Keep, Stockpile, SummoningCircle | SiegeEngine, Bastion |
| stock_engine | Keep, Stockpile, SiegeEngine | SummoningCircle, Bastion |
| stock_bastion | Keep, Stockpile, Bastion | SummoningCircle, SiegeEngine |
| circle_engine | Keep, SummoningCircle, SiegeEngine | Stockpile, Bastion |
| circle_bastion | Keep, SummoningCircle, Bastion | Stockpile, SiegeEngine |
| engine_bastion | Keep, SiegeEngine, Bastion | Stockpile, SummoningCircle |
| double_stock | Keep, Stockpile, Stockpile | SiegeEngine, Bastion |
| double_circle | Keep, SummoningCircle, SummoningCircle | SiegeEngine, Bastion |
| double_engine | Keep, SiegeEngine, SiegeEngine | SummoningCircle, Bastion |
| double_bastion | Keep, Bastion, Bastion | SummoningCircle, SiegeEngine |

Keep stays in slot 1. The six unique-type profiles preserve canonical relative order within active and reserve groups. The duplicate profiles each replace exactly one active castle in a single-copy reference:
- double_stock and double_circle versus control;
- double_engine versus stock_engine;
- double_bastion versus stock_bastion.

Those four comparisons hold both reserve castles fixed. Reports show all nine candidates against the original control, plus extra single-copy-reference rows for double_engine and double_bastion. These extra comparisons reuse existing games.

This covers all ten unordered active pairs with repetition, but not every five-slot inventory, reserve combination or positional permutation. Duplicate builds omit a castle type; the result measures that tradeoff, not a free extra castle.

Deimos with an active Siege Engine is the first known hypothesis; other Lords' best combinations remain to be measured.

## Size and pairing

- Nine Lords, eight nonmirror opponents, both seats.
- One seed per unordered matchup per repeat, held constant across loadout treatments and seat swaps.
- 72 unique control games reused across the focal-Lord comparisons.
- 1,296 treatment games: nine alternate profiles × nine Lords × eight opponents × two seats.
- **1,368 unique games per repeat**, giving each Lord/profile 16 paired observations. There are 1,584 reported pair comparisons including 288 extra single-copy comparisons; those extra rows add no games.
- Matchup blocks have a control followed by treatments. Blocks are deterministically mixed across matchups rather than running one Lord's whole campaign first.
- Shared controls and paired seats are correlated; do not pool them as independent observations or treat the best screening result as a proven optimum.

The smoke check is a separate 20-game output: Deimos vs Orias, ten profiles, both seats, with 22 paired comparisons. It checks execution, not balance.

## Install only the runner

Use the current working tree that contains your installed Ascent patches. Do not switch to this experiment branch: its base may predate your local cumulative patches.

In Git Bash:

~~~bash
(
set -e
cd "/c/Users/jerem/OneDrive/Documents/Corruptor-U13-Theater"
git fetch origin u13-ascent-loadout-screen-20260929
runner="Scripts/Sim/run_u13_ascent_loadouts.py"
if test -f "$runner"; then
  cp "$runner" "$HOME/Downloads/run_u13_ascent_loadouts-before-duplicates-$(date +%Y%m%d-%H%M%S).py"
fi
git show "FETCH_HEAD:$runner" > Scripts/Sim/run_u13_ascent_loadouts_next.py
python -m py_compile Scripts/Sim/run_u13_ascent_loadouts_next.py
mv Scripts/Sim/run_u13_ascent_loadouts_next.py "$runner"
)
~~~

The update backs up the existing runner in Downloads and checks Python syntax before replacing it. It changes only the runner. Existing report folders remain intact.

## Prepare without playing

~~~bash
python Scripts/Sim/run_u13_ascent_loadouts.py \
  --output "$HOME/Downloads/Corruptor/Balance/ascent-loadout-duplicates" \
  --workers 3
~~~

Default behavior is preparation only. This freezes the installed simulation source, including uncommitted Python/GDScript changes, and constructs every opening through PowerMatch. It checks castle order, three active/full-integrity castles, two unbuilt castles, paired seeds and unchanged opening card shuffles.

The expanded experiment requires a new output directory; an old frozen snapshot keeps running its original code. Existing partial results are preserved but are not imported into the V2 report because its source/manifest identity changed. A changed roster or control loadout causes an explicit stop rather than silently changing the experimental question. Failed preparation is not safe to resume; use a new output directory after resolving the error.

The snapshot uses the existing balance runner's source selection. It is not a complete game build and does not freeze art, sound or Godot presentation scenes.

## Smoke check, then long run

~~~bash
python Scripts/Sim/run_u13_ascent_loadouts.py --smoke --run --workers 3
~~~

Check that it exits successfully with 20/20 saved games and no failures or unresolved outcomes. The report location is printed. Do not choose loadouts from these smoke results.

Then start the newly prepared duplicate snapshot (do not resume the old six-profile folder):

~~~bash
python Scripts/Sim/run_u13_ascent_loadouts.py \
  --resume "$HOME/Downloads/Corruptor/Balance/ascent-loadout-duplicates" \
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
  --resume "$HOME/Downloads/Corruptor/Balance/ascent-loadout-duplicates" \
  --summarize
~~~

Paired reports use only complete, resolved control/treatment pairs. Missing, failed, and unresolved games are listed explicitly. Control wins are recalculated on the exact paired subset, so partial treatment results are never compared against all control games.

Metrics include wins gained/lost, paired win-rate difference, rounds, both seats, opponent breakdowns, declared powers, selected actions, rejected previews and win routes. Power declarations do not prove successful resolution; inspect traces when that matters. The generic survey summary is not a castle-loadout ranking.

## Decision after the screen

Shortlist sensible, kit-supporting loadouts; check whether gains persist across opponents and seats and whether they worsen pacing. Validate finalists on fresh seeds before adoption. Then test them in native Ascent against actual three-castle player starts and relevant retinue/inheritance progression. This screen alone cannot establish the final stage difficulty curve.

No gameplay values are changed automatically, and no loadout is selected or shipped by this runner.
