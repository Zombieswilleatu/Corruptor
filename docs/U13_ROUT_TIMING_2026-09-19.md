# Rout timing and current marcher replay integration

**2026-09-19 · V12 retained · local CPython verified**

Rout has a measurable emergency-stall benefit. These diagnostics do not identify
a better activation rule, so production doctrine remains
`U13_COMMON_SMART_CORE_ALPHA_V12_HUMBABA_PRESSURE`. Game rules, weights, search
limits and greedy selection are unchanged.

The user's intended use is explicit: when the hand cannot answer a large
advancing line, Rout buys another draw, deployment window or cooldown. A future
preference should value that time and the availability of an answer. Nearby
head count alone does not establish that the delay is useful; conversely, zero
direct damage does not make Rout worthless. This records the intended role,
not a newly implemented emergency-only restriction.

## Controlled timing results

Nine fresh frozen-V12 games use the current marcher rules at `2cf3bbb`, including
`b61393f`'s footprints and Vulture/Butcher change: **172 rounds / 4,339 operations**.
The fixed namespace is `u13-rout-current-rule-diagnostics-2026-09-19`. Loadouts are
the ordinary five castles, with Deimos mirrored and in both ordered seats against
Gremory, Humbaba, Kalligan and Valak.

The first cohort takes the earliest eligible held/fired position per game and
selects six of each by stable source/seat/round hash, without outcomes. Each
pair changes only the selected Rout decision, with the ordinary order and
opposing sealed plan fixed. Frozen V12 responds normally afterward.

| Cast compared with hold | Positions | Gained wins | Lost wins | Same winner |
| --- | ---: | ---: | ---: | ---: |
| Force an originally held round-two Rout | 6 | 0 | 2 | 4 |
| Retain an originally fired early Rout | 6 | 0 | 0 | 6 |

All twelve original controls won. This cohort cannot establish rescue behavior
or general playing strength. In all six early-hold controls V12 instead casts
on round three. Forcing round two blocks that opportunity: the routed survivors
initially fall behind but are farther advanced by the end of round three than
in the hold-then-cast branch. An earlier visible wave is not enough reason to
spend the cooldown earlier.

## Outnumbered-lane follow-up

After the user's clarification, a separate selection takes the largest visible
mobile-enemy HP surplus per source/seat in rounds 4–15 where V12 already casts
Rout, then the six largest surpluses. Eligibility requires at least four mobile
enemies, reachable public pressure and more enemy than allied lane HP. Outcomes
do not enter this selection. Planned recruits and monsters are recorded too.
These are pressured positions, not a proof that every possible hand response
has been exhausted; bodies and HP are not interchangeable with fighting strength.

All six retained the same eventual winner: five original wins, one original
loss. In every case the routed cohort's first ordinary attack moved to at least
the following round. End-of-cast-round allied lane HP increased by **10–74**.
The clearest preservation case, Deimos/Humbaba round 15, ended that round with
**twelve more allies alive**, and still had four more two rounds later.

The table uses zero-based seats and reports Deimos's result/finishing round.
The bodies column is visible mobile enemies versus all living allied lane units
at the decision, before the recorded ordinary recruitment.

| Ordered Lords | Deimos seat | Round | Enemy / allied bodies | Immediate allied HP difference | Hold / cast outcome |
| --- | ---: | ---: | ---: | ---: | --- |
| Valak / Deimos | 1 | 15 | 83 / 5 | +15 | W21 / W21 |
| Deimos / Humbaba | 0 | 15 | 90 / 33 | +74 | W22 / W21 |
| Kalligan / Deimos | 1 | 11 | 70 / 18 | +10 | W20 / W19 |
| Deimos / Valak | 0 | 7 | 30 / 8 | +12 | W21 / W22 |
| Deimos / Deimos | 1 | 15 | 64 / 54 | +13 | L20 / L20 |
| Humbaba / Deimos | 1 | 15 | 57 / 45 | +31 | W24 / W23 |

This supports Rout as breathing room, not a demonstrated win-rate upgrade.
Five hold branches cast next round; one casts two rounds later. Later orders,
casualties and cooldowns diverge, and the initial HP advantage sometimes reverses.
The losing mirror remains a loss. There is no evidence here for making the bot
fire earlier automatically, nor for a general emergency-only restriction.

## Verification and limits

The two cohorts reuse the same nine source games. Across **18 paired positions**,
all **36 final continuations** complete: **702 rounds / 17,716 operations**,
including replayed prefixes. All **18 original-choice controls** reproduce the
entire source operation stream and final state exactly. All final continuations
have legal submissions, zero rejected policy previews and bounded decisions.
These are selected diagnostics, not 36 independent policy-comparison games.

Three initial pressure omissions were rejected by the diagnostic serializer:
removing Rout from slot zero left War Machine at slot one. The helper now
resequences the required declaration identities while preserving every semantic
field and relative order of remaining powers. Only those three rejected variants
were rerun; the failed records are retained. Artillery targets and damage before
Rout are identical within every pair. No game authority was changed to permit an
otherwise illegal intervention.

Measured attack timing includes only ordinary melee/ranged attacks by the
routed cohort over three rounds, not monster specials. Positional delay compares
only units alive in both branches, with survivor counts alongside it. Later HP,
castle and outcome differences are conditional on both reacting policies.

The local CPython 3.12.14 gate passes **168 tests and five games / 93 rounds /
2,329 operations**, with no failures or rejected previews. This is the updated
marcher-rule behavior gate, not a new native-parity or Windows/PyPy acceptance.
The accepted Windows V12 result at `77ff661` remains scoped to that earlier
revision. There is no new candidate policy requiring a matched A/B comparison.

## Compatibility fixes

Twelve historical replay cases were reviewed from the original inputs on both
`77ff661` and the current engine. Eight public observations changed, and two
selected plans changed. The [before/after evidence](evidence/U13_ROUT_REPLAY_INTEGRATION_2026-09-19.json)
records input fingerprints and executed tactical outcomes.

- One old Deimos/Humbaba artillery example now has illegal recorded targets
  after earlier combat. Its exact historical source is pinned in `retired_cases`.
  A fresh recorded Deimos mirror replaces it: changing only the selected Siege
  target back to the castle destroyed by its own artillery makes it fizzle;
  the selected retarget deals **10 damage** against the same opposing order.
- The historical Humbaba Lord-lane support example now recruits in Castle and
  supports existing Lord-lane units. It is retained as that distinct assertion.
  A fresh natural Castle-lane case preserves positive planned-recruit support
  coverage: ten recruits, visible reachable pressure, one immediate pulse and
  zero healing on that pulse.
- The historical heal case now has one eligible wounded recipient, so actual
  healing is one rather than two. The one-HP-per-recipient rule is unchanged.
- Retained prefixes/opposing plans, defensive survival, Kalligan's friendly-fire
  checks, and the remaining artillery fizzle-to-damage assertion are preserved.

There are now thirteen active cases in these four fixture files. Expectations
follow reviewed current states; historical fingerprints remain recorded.

## Reproduction and evidence

`Scripts/Sim/audit_u13_rout_timing.py` provides `collect`, `replay` and `pressure`
phases. `Scripts/Sim/summarize_u13_rout_timing.py` audits each pair, with
`--pressure` selecting the second cohort. Use a fresh `--output` directory for
collection; `--resume` can reuse matching complete continuations. The archive
README contains complete commands. Freeze/source identities and file hashes are
recorded in [compact evidence](evidence/U13_ROUT_TIMING_2026-09-19.json).

Archive: `Corruptor-Rout-Timing-Evidence-2026-09-19.zip` (10901508 bytes).
SHA-256: `84a5640c066f6375a8a677a13f09ef974222680e646d53fd2735f6939157027c`.

Next hypothesis, not a production change: distinguish an unanswered advancing
wave from a fight the current plan can already handle, then test a bounded
reservation preference against unchanged V12. Preserve both these useful-delay
examples and the early-cast counterexamples when evaluating it.
