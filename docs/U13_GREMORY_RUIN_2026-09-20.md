# Gremory V19: delayed Ruin and competing card commitments

V19 updates the experimental Python doctrine for Inevitable Ruin. Predator of
Ruin, Orias V18, game rules and native Godot behavior are unchanged. This is a
decision-quality pass, not a win-rate or native acceptance claim.

## What changed

Inevitable Ruin costs two discarded cards and fires at next round's scheduled
hook, reducing a still-eligible Castle to eight Integrity. Its old proposal
valued the target's current Integrity and always offered the two lowest-value
cards. That could overstate damage after our own attack or make Ruin compete
unnecessarily with a recipe using those exact cards.

The revised forecast follows own Development, known normal artillery, and own
Hunt/Siege before estimating Ruin's remaining damage. Hunt damage absorbed by
a Keep and Siege damage absorbed by a Bastion count. Artillery uses the
existing public locked-target/singleton-acquisition projection; unknown random
acquisitions stay unknown. An attack whose Castle target has already fallen to
artillery is handled by the existing attack-after-artillery helper.

Only damage above eight is credited. If own projected damage consumes that
opportunity, the coordinated Ruin score loses its standalone credit. A current
settlement or an already-pending Ruin on the target earns no additional delayed
damage. The existing coefficient of five points per projected Integrity damage
is preserved; this pass does not tune that weight.

Two bounded payment patterns compete: the cheapest two cards, and the cheapest
two outside the best saved recipe. Payment ranking considers face-value cost
and recipe-saving loss. Shared complete-plan assembly still scores payments,
recruitment, defense and recipe opportunity once; the new payment ranking does
not add another penalty to the complete-plan score.

Up to four additional complete-plan candidates can add or retarget Ruin while
preserving an existing plan's combat, Guards, Work, Rites, other powers and
monster commitment. Their discards come only from uncommitted cards, including
cards released by replacing an earlier Ruin. They can therefore discover a
different healthy target or spend spare cards without dismantling the original
plan. The ordinary no-power plans and coordinated omission alternatives remain
available, so holding Ruin still competes with casting it.

The new source has a maximum of sixteen generated target/payment candidates
and four retained alternatives, inside the existing **32 complete plans / eight
legality previews**. Duplicate bundles are removed. No alternative slots are
reserved when there are no currently eligible Castle targets. This is a fixed
search over a few patterns, not a full subset search or game rollout.

## Forecast limits

The scenario does not know opposing Guards, Ward, repair orders, intervening
spatial combat, random reactions or future draws. Own Resummon/Conduit changes
are marked unprojected rather than promising an artillery result. A predicted
fizzle is conditional on this public scenario, not proof that the opponent
cannot repair the target. No legality rule or hard veto is added.

## Verification

The final focused PyPy run passes **80 methods** covering Gremory, common
planning, coordination, directed Deimos artillery, Orias and Snare follow-up.
The **eleven new Gremory methods also pass under CPython**. They cover delayed
damage, Keep absorption, known/unknown artillery, a destroyed attack target,
recipe preservation, disjoint attack/Guard payments, retargeting, pending
duplication, settlement, input immutability, deterministic registry ordering
and bounded planning.

Two directed authority continuations cast Ruin alongside a Siege, finish the
current round, then execute the next scheduled hook. The measured damage
matches the forecast: a 17-Integrity target takes four Siege damage then five
Ruin damage; an 11-Integrity target takes four Siege damage and Ruin does no
damage because it is already below eight. Both submitted plans pass the actual
game legality preview.

One older Deimos replay method is tracked separately. Its two saved public-view
hash assertions fail before any policy decision. The engine, observation
code, test and fixture are unchanged from V18. The frozen V18 test reproduces both exact expected/observed hash mismatches.
No fixture hashes or tactical expectations were changed to make this pass green.
The full selection is therefore not described as an entirely passing suite.

## Same-board comparison with V18

The audit takes every distinct Gremory public view from the four Gremory games
in the preceding sixteen-game Orias/Snare cohort. It freezes V18 at
`3aea19d43d840d6ea3c05287d9f8dd4832b6965b` and compares both policies on all
**49 distinct boards**, with no result-based board selection.

| Measurement | V18 | V19 |
| --- | ---: | ---: |
| Ruin selections | 9 | 21 |
| Conditional projected Ruin damage | 66 | 157 |
| Selected Ruins with zero projected damage | 0 | 0 |
| Orders retaining a monster recipe | 49 | 49 |

The complete plan changes on 23 boards. Thirteen boards gain a Ruin cast, one
loses a cast, eight cast in both versions and 27 cast in neither. Three of the
thirteen newly casting boards preserve the entire previous order exactly;
others choose a different complete plan. No jointly casting board changes its
Ruin target in this sample, so retargeting is exercised by directed tests.

The evidence here primarily supports finding compatible card payments. It does
not show a reduction in natural fizzles, since neither policy selected a
zero-damage Ruin under the public forecast on these boards. Projected damage is
conditional, not observed damage from a counterfactual match. Saved-view
re-decisions use a permissive preview stub to isolate policy scoring.

All other eight Lords retain identical opening plans, scores and work budgets
against frozen V18, checked with authoritative legality previews. This is an
opening regression check, not a claim of exhaustive decision parity.

## Disposition and reproduction

Keep V19 as the Gremory doctrine pass. No full win-rate comparison ran. The
next planned Lord pass is Kanifous's Wish/Price choices; the legacy Deimos
replay expectations need a separate review before a full acceptance gate.

Run the saved-board audit from the repository root with PyPy:

```bash
PYTHONPATH=Scripts/Sim pypy3 -m u13_doctrine.gremory_audit \
  --source SOURCE_SNARE_CAMPAIGN --output OUTPUT_DIRECTORY
```

The evidence archive includes the frozen V18 policy and replay fixture,
candidate policy, four source game records and their manifest, audit, source
identities, test logs and publication identity. The manifest revision identifies
the pre-edit base; the harness hash and frozen candidate identify measured V19.

Machine-readable summary: `docs/evidence/U13_GREMORY_RUIN_V19_2026-09-20.json`.
