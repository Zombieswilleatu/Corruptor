# U13 common doctrine V10: Deimos artillery coordination

This follows the accepted [Windows Castle Scorch checkpoint](U13_KALLIGAN_CASTLE_FIRE_2026-09-18.md).
It changes the experimental Python doctrine, its diagnostics and acceptance
tests. Game rules, shared weights, the playable Godot policy and default greedy
selection are unchanged.

## Finding

A current-rule audit ran **17 complete V9 games**, covering Deimos against every
Lord in both seats, with one mirror: **313 rounds / 7,867 operations**, zero
failures or rejected previews. Both players used V9 and the ordinary five-Castle
loadout. These are behavior observations, not a policy-strength comparison.

Across 333 Deimos decisions, War Machine was selected 198 times and dealt
378 attributed Integrity damage, with 22 destruction events. Three declarations
had no targetable enemy Castle at planning. Eight selected Sieges aimed at a
publicly locked artillery target with at most four Integrity. Those eight are
conflict signals: enemy Work, other artillery and reactions can change them.
Rout was selected 84 times; its 2,593 affected-Marcher records do not measure
useful retreat, survival or prevented breaches.

Two original-input cases were replayed through actual combat:

| Recorded V9 decision | V9 result | V10 result against the same opposing order |
| --- | --- | --- |
| Deimos–Humbaba, round 16, seat 0 | Artillery destroys the selected Summoning Circle; Siege fizzles | Siege another surviving Castle and deal damage |
| Deimos mirror, round 11, seat 1 | Artillery destroys the selected Stockpile; Siege fizzles | Siege another surviving Castle and deal damage |

The chosen replacements preserve the original combat cards and monster recipe.
The fixtures retain every original operation before those decisions, the
original simultaneous plans and exact policy-visible observation fingerprints.
Opposing plans are used only in retrospective resolution, never by the planner.
The other six signals are not claimed as corrected. No win-rate gain is claimed.

## Decision model

Deimos's complete plans now project their own known Development changes and
artillery before valuing Hunt/Siege. War Machine fires **before** the normal
artillery shot. The model follows an existing public target lock, or a uniquely
determined reacquisition when only one target remains. It records other
reacquisitions as unknown and never consults the simulation seed.

If a Siege target is gone while another Castle survives, its attack credit is
removed. Recruitment and any summon still receive their normal credit because
they occur before combat. If the last Castle is gone, the existing Pillage
behavior is evaluated instead. Changes to Keep/Bastion interception also use
the projected board.

When both shot sequences have known targets, War Machine replaces its fixed
18-point credit with nine points per additional Integrity compared with normal
artillery alone, capped at the same two damage / 18 points. An unknown
reacquisition retains the previous estimate. With no currently targetable
enemy Castle, a declaration has no current opportunity credit.

The model is conditional. Opposing repairs, new Castle activation, opposing
artillery and reactions remain unknown. A directed real-resolution test repairs
a forecast-to-fall Castle before artillery, demonstrating why the original
Siege remains legal. Scores do not impose a target veto. Resummon plans are
outside the model because Conduit can change infrastructure before Development.

## Bounded alternatives and diagnostics

When a visible artillery lock threatens a Siege target, up to four complete
plans can replace that target while retaining the rest of the plan. Each plan
is reassembled, rescored and submitted to normal authority admission. The
additional target source reserves before evaluation and is capped at **16
generated / four retained** alternatives. Its work appears explicitly under
the `artillery` budget category. The overall **32 complete plans / eight
previews** limits remain unchanged; replacement slots come out of that total.

`artillery_planning` records assessed scenarios, potential target losses,
replacement plans, selected replacements and unresolved shots. These are
planning diagnostics, separate from actual `ARTILLERY_FIRED` damage and
`COMBAT_ORDER_FIZZLED` outcomes. Rout's scoring is unchanged in this checkpoint.

## Verification

Nine focused tests passed locally. They cover both natural replays, exact shot
order and capped incremental damage, an empty board, singleton and unknown
reacquisition, restoring an engine through own Work, Pillage after the final
Castle falls, an opposing-repair counterexample, observation immutability,
registry-order determinism, normal authority admission and reduced work limits.

The complete gate passed **148 tests** and **five complete games / 92 rounds /
2,321 operations**, with zero failures or rejected previews. Tested local
revision `55c17c9` has the identical Git tree published as `7685deb`. The engine
fingerprint remains identical to the accepted Castle Scorch build.

The common-doctrine gate and source fingerprints are recorded in
[local evidence](evidence/U13_DEIMOS_ARTILLERY_LOCAL_2026-09-18.json).
Windows CPython/PyPy acceptance is pending. This adds no native decision-parity,
balance or throughput claim.

Run from the doctrine checkout in Git Bash:

```bash
git pull --ff-only origin u13-basic-doctrine &&
bash Scripts/Sim/run_u13_common_doctrine.sh \
  "C:/Users/jerem/Downloads/pypy3.11-v7.3.23-win64/pypy3.11-v7.3.23-win64/pypy3.exe"
```

The command runs the focused cases, the full common test suite and five complete
games under both runtimes, then compares their reports and packages a ZIP in
Downloads. Castle Scorch's native gate is already accepted; the engine is
unchanged by this doctrine checkpoint.

Next tactical review: measure useful Rout displacement and Humbaba's actual
Breath/Muster benefit before changing their activation preferences.
