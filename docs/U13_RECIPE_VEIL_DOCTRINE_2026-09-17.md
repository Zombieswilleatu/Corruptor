# Common doctrine: recipes and revealed Veil protection

The user paused balance changes and resumed doctrine on September 17. The rules
checkpoint for this pass is `cfee89ae33e7d88eaae865b6d5101ad57bde0361`: castle
Integrity 17, Wright pair Work 3, Forge repair 1, Ruin/Longevity cap 8,
Penitent screen 3 and Butcher retaliation against two distinct Marchers.
These are the user's existing changes. This pass changes no native production
rules, balance, U12, art or playable UI.

The experimental Python policy is now
`U13_COMMON_SMART_CORE_ALPHA_V3_RECIPES_VEIL`. It retains the fresh common
architecture and nine separate Lord files. The earlier U12 review's conservation
and resource-horizon ideas remain useful; the new recipe rules and public-state
boundary govern this implementation. The playable Godot BasicDoctrine is still
a separate policy. This is not a new shipping-policy port or strength result.

## Decisions added

`u13_doctrine/recipes.py` reads the actual ten-recipe table. Recipes require
physical subjects; high face values cannot replace an ingredient. Locked
recipes, living Sooge/Sinodek copies and their original owner's charm-reserved
slots are excluded. A pending limited summon also excludes saving for a second
copy in the same plan.

Every ordinary Hunt/Siege/Ward candidate compares its qualifying recipes before
the complete plan is previewed. A separate bounded source supplies one minimal
Ward commitment per ready recipe, exposing useful ingredient combinations that
a strength-sorted attack prefix could miss. Recipes keep ordinary recruitment
from those cards and compete against Guard pairs, powers, Rites and Resummon in
the same card ledger. The returned plan is exactly the plan authority previewed;
there is no post-preview monster append.

Saving is a soft preference for one best ready or one-subject-short recipe.
Overlapping recipes are not summed, future draws are not predicted, and saving
gets no horizon credit when the existing settlement scenario already ends the
game. An explicit reserve-card candidate can keep those ingredients while doing
other work. Other complete plans may spend them for greater immediate value.
Stockpile and Slaver use this same goal alongside face value and Guard pairs.
The market still selects one give-card before evaluating its bounded offers;
it does not enumerate every give/take pair.

Monster material and ability scores are explicit untuned preferences. They use
the guaranteed three Varn bodies, public lane need, visible support targets,
wounded allies and friendly-fire exposure. They do not predict charm, poison,
rooting, portals, future movement or survival. `monster`, `recipe_save` and
`veil_protection` join the injectable integer weights; no weight sweep occurred.

`u13_doctrine/veil_judgment.py` scores protection newly reached by the complete
paid-choice scenario for already revealed intruders. Harmful effects protect
our side; Gremory/Kalligan/Kanifous protection denies enemy benefits. Ordinary
participating-Lord breaches and unprotectable cascade arrivals grant no such
credit. Restoring an Integrity ceiling is not counted as healing, and acquiring
protection does not undo prior damage or cancel an already armed Wish.

The report exposes pending thresholds and the cascade's round gate while keeping
future arrival identity unknown. Ritual, Final Collapse and Dominion precedence
remain authoritative. Known declared resource costs join the paid scenario;
the current powers spend Reconfiguration rather than Souls. Shared-Veil
advancement remains a scored risk: no blanket Hunt prohibition or speculative
hard veto was added.

## Budgets and diagnostics

Each generation source still reserves at most 16 candidates, retains four,
and stops on exhaustion. The new monster source uses that same cap. Its
proposals occupy the combat action slot, not a second action. Complete plans
remain capped at 32 and authoritative previews at eight; no Cartesian product
or wall-clock cutoff is used.

Combat assessment counts include both ordinary and recipe-derived commitments;
the work-budget report separates the two generation sources. Monster rows
record physical opportunity, generation/retention, the selected recipe and
reasons such as missing subjects, living-copy limits or shared-card competition.
Unchecked legality stays unknown. The observer counts actual summon events and
spawned bodies separately from saving decisions and protection scenarios.
Those scenarios are not measured causal benefits. Later monster ability value
remains unmeasured rather than reported as zero.

## Bugs exposed by complete games

The new trajectories exposed a Kalligan readiness bug: an Inferno relocation
could rank highly even when its delayed firing would be after expiration.
The public readiness check now enforces that boundary. Kalligan's Scorch
exposure also excludes flying Fyra, matching authority. Gremory's explanations
now name the configured Ruin cap instead of the obsolete value 14.

They also exposed a Python Marching crash. A monster kill can rebuild the flat
columns before Gravity Orb resolves, so pre-tick array indices may identify a
different unit or exceed the new length. Gravity now preserves stable entity
IDs, pre-tick positions, lane and movement readiness. It looks up each surviving
ID after reactions. This also preserves native behavior when a monster hit wakes
a new recruit: it can move, but its old readiness still governs that tick's
Gravity pull. Native production behavior is unchanged.

## Verification and continuation

Local verification and exact source/artifact identities are recorded in
[the evidence file](evidence/U13_RECIPE_VEIL_DOCTRINE_LOCAL_2026-09-17.json).
The behavior probe uses five ordinary, unmodified setups covering all nine Lords.
The fixture tests are labeled separately. No hand/board preparation is inserted
into those complete games, and no balance conclusion follows from their wins.

CPython passed **68 tests** and **five games / 98 rounds / 2,473 operations**
with zero rejected plans or previews. All ten monster types were selected,
192 summons in total. Nineteen of the 23 ordinary powers and all five Breach
Wishes were selected. The largest decision assembled 26 plans and required one
preview; all source/category limits held. A second run with `PYTHONHASHSEED=173`
reproduced every decision, final state and complete diagnostic report. The
runner gained its focused-native verification subcommand between probes; that
metadata difference is recorded rather than hidden.

Native suites passed **657 checks**. Python matched five Veil arrival checks,
14 effect checks, eight whole-world resurrection results, and **23 complete
monster/Gravity phases / 4,600 ticks / 5,009 event rows**. The resurrection
exporter now flushes each record, so evidence is not left buffered at exit.

The focused native checks use diagnostic Linux Godot 4.5.1. They are not Windows
4.7.2 acceptance. The original Gravity implementation reproduces the crash on
the new native fixture; the fixed implementation is compared against all four
complete phase/event results, including reversed registry order.

Run the combined Windows check with:

```bash
bash Scripts/Sim/run_u13_common_doctrine.sh \
  "C:/Users/jerem/Downloads/pypy3.11-v7.3.23-win64/pypy3.11-v7.3.23-win64/pypy3.exe" \
  --godot "C:/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
```

It runs focused native Guard/Forecast/Veil/monster/resurrection/Gravity checks,
compares exported mechanic results under both Python interpreters, runs the
directed tests plus five doctrine games per interpreter, and requires identical
decisions, final states and complete diagnostics. One report ZIP is packaged in
Downloads. This does not replay the five new doctrine games in Godot.

Next, inspect that Windows evidence and the named decisions that still need
useful/hold/timing examples. Expand the exact native game corpus at this chosen
mechanics checkpoint before serious shared-weight or balance claims. Preserve
a compatible control for matched-seed, crossed-seat comparisons. Lord-specific
specialization and a selected shipping Godot port follow; optional optimization
remains closed.
