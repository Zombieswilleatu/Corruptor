# CORRUPTOR — IMPLEMENTATION PLAN ADDENDUM

## RANDOM-LEGAL DOCTRINE TIER

User-supplied plan amendment, accepted 2026-09-08. Supplements the Lord Power
Implementation Plan V2. Amends **BOT DOCTRINE — DELIBERATELY LATE** and
**PROJECT MILESTONES**. The implementation status and API notes after the addendum
distinguish requirements from completed code.

# 1. THE GAP

V2 defines two doctrine states:

**Now** — `PASS / DO NOT DECLARE` fallback for unimplemented powers.

**Milestone 9** — shared evaluators, lane value, area value, candidate
generation, spatial scoring.

There is nothing between them.

That is correct for rules *correctness*. It is wrong for rules *tuning*,
because a bot that always passes generates no evidence about any power it
declines to use.

Under V2 as written, Milestones 5 through 8 produce a fully implemented,
fully deterministic, fully replayable nine-Lord roster about which we know
nothing.

# 2. NUMBERS CURRENTLY UNTESTED

Every one of these was set by design judgment and has never been measured.

## Thresholds

- Ravenous — 6 Marchers Devoured per activation
- Gravity Orb — 4 Marchers destroyed per Orb
- Waiters → personal Tear — 5 waiters in a single lane
- Endurance of the Faithful — exactly 1 HP at end of Marching
- Kroni Hunger bands — 4 / 6 / 8 Defense at 0 / 1–2 / 3+

## Rates

- Scorch lane damage — 1 / 2 / 1
- Pyroclasm — one extra pulse at current Intensity
- Siege Engine — 2 damage per round, persistent target
- Passive Construction — 3 or 4 Integrity per round (unresolved)
- Pillage — 1 Soul per round
- Predator of Ruin / Muster the Faithful — 3 Marchers on a 1-round cooldown

## Economies

- `resummon_tear_mode` — Neutral Tear per resummon
- Kanifous Price weighting, and the Stone-and-above Tear threshold
- Odradek Reconfiguration ladder — is Redirect at 1 strictly better value than saving for Inversion at 4
- Veil fill rate against `dominion_track = 12` with all new faucets live

## Frequencies

These are the ones that determine whether several of the above are
reachable at all.

- Average Marchers on field per round, both sides spawning
- Distribution, not just mean — a mean of 8 with high variance means Ravenous at 6 fires rarely and unpredictably
- How often a lane holds 5+ waiters
- How often a Castle is destroyed in a round (gates Sifting the Ruins)
- Breakthrough / arrival rate per match

One measurement answers the last group, and the last group sets most of
the first group.

# 3. THE TIER

Insert between the pass fallback and Milestone 9 doctrine.

## RANDOM-LEGAL DECLARATION

For any power without real doctrine:

1. Ask `U13Legality` for the set of legal declarations available to this Lord this round.
2. If the set is empty, pass.
3. Otherwise select uniformly at random from the set using the keyed RNG.
4. Fill any required payload — lane, zone, target, position, resource amount — by the same keyed selection over legal values.

The bot does not evaluate. It does not prefer. It fires.

## PROPERTIES THIS PRESERVES

**Determinism.** Selection is driven by `U13KeyedRng` under a dedicated
purpose key, so a random-declaration match replays exactly like any other.

Suggested purposes:

- `BOT_POWER_CHOICE`
- `BOT_POWER_TARGET`
- `BOT_POWER_POSITION`
- `BOT_POWER_AMOUNT`

Keyed rather than sequential, per V2 — adding a power later must not shift
every prior random decision in the batch.

**Legality ownership.** The bot still asks the simulation what is legal.
It does not implement a second copy of the rules. This is the same
contract V2 already requires under **COMMON VALIDATION**.

**No new engine surface.** Declarations already serialize. Legality is
already centralized. The keyed RNG already exists and has golden tests.
This tier is a chooser, not a system.

# 4. WHAT IT IS AND IS NOT FOR

## GOOD FOR

- Frequency data — does this trigger condition ever occur
- Reachability — can 5 waiters accumulate in a contested lane at all
- Interaction discovery — unplanned combinations across 10A–10G
- Stalls, loops, and runaway Tear generation
- Crash and fizzle coverage across states no authored fixture would build
- Determinism soak testing at match scale

## NOT GOOD FOR

- Win rates
- Lord balance
- Whether a power is *strong*
- Anything requiring competent play

A random bot fires Ravenous into an empty lane and Snares an opponent
holding no cards. Its win rates are noise.

**The distinction to hold:** this tier measures whether the *game state*
required by a mechanic ever arises. It says nothing about whether a
mechanic is good.

Treat every output as a frequency, never as a verdict.

# 5. WHERE IT LANDS IN THE PLAN

## AMEND: DEFINITION OF DONE FOR A LORD POWER

Add one item to the existing list:

- a legal random-declaration path exists and produces valid submissions

A power that cannot be declared randomly is a power the bot cannot
exercise, which means it will not appear in any sim until Milestone 9.

## AMEND: MILESTONE 3 — CORE LORD ALPHA

Milestone 3 currently reads as a "playable checkpoint." Make its scope
explicit:

**Milestone 3 proves rules correctness. It does not produce balance data.**

Four Lords is not the shipping roster, and Smart Core was validated
against nine. Any win rate generated at Milestone 3 is against a roster
that will not exist.

What Milestone 3 *can* produce with the random tier: frequency baselines
for Gremory, Deimos, Humbaba and Kalligan mechanics, and the field-density
numbers that several later thresholds depend on.

## AMEND: TESTING PYRAMID

Insert between Level 5 and Level 6:

**LEVEL 5.5 — RANDOM-DECLARATION BATCHES**

Bot-vs-bot matches with random-legal doctrine.

Purpose: frequency, reachability, stalls, unplanned interactions,
determinism at scale.

Not balance. Level 6 remains the balance layer and still requires real
doctrine.

## AMEND: PROJECT MILESTONES

Milestone 9 stays where it is. This tier is not a milestone — it is a
per-power requirement that accumulates as the roster fills.

# 6. INSTRUMENTATION TO ADD ALONGSIDE

The random tier is only useful if the runs are measured. The event log
already exists; these are the counters worth extracting from it.

## PER MATCH

- Marchers on field per round — mean, min, max, distribution
- Waiters banked per lane per round — peak and duration
- Marcher arrivals per lane
- Veil total per round, split by personal and Neutral
- Tear events by source power
- Castles destroyed per round
- Souls per round by source

## PER POWER

- Declaration count
- Fizzle count and cause
- Threshold-met count where a power has one (Ravenous ≥6, Orb ≥4, waiters ≥5, Endurance at 1 HP)

## THE KEY RATIO

For every threshold power, report:

**times declared / times threshold met**

A power declared forty times that never once met its threshold is either
mistuned or unreachable, and that distinction is exactly what this tier
exists to reveal.

# 7. FIRST QUESTION TO ANSWER

Before tuning anything, run random-declaration batches and answer:

**What is the distribution of Marchers on the field per round with both
sides spawning?**

That single number sets:

- Ravenous at 6
- Gravity Orb at 4
- Scorch lane damage relevance
- Death / Redirect / Allegiance Shift circle radii
- whether 5 waiters in one lane is ever reachable

Five tuning decisions off one measurement. It is the cheapest high-value
thing the random tier produces, and it cannot be obtained any other way
without a bot that fires powers.

# 8. WHY NOT JUST WAIT FOR REAL DOCTRINE

Three reasons.

**Ordering.** Real doctrine must be tuned against numbers. If the numbers
are wrong, doctrine optimizes toward a game that is about to change, and
the work is repeated. That is the same mistake as hardening Hunt and Siege
before measuring arrival rates.

**Cost.** Real doctrine for nineteen powers, several needing spatial
reasoning, is plausibly larger than the rules work. Random-legal is a
chooser over an existing legality API.

**Feedback latency.** A roster implemented but unmeasured for the length
of Milestones 5 through 8 means every tuning error found at Milestone 9 is
found on top of eight milestones of accumulated assumptions.

# 9. WHAT NOT TO DO

- Do not report win rates from random-declaration batches
- Do not let random selection bypass `U13Legality`
- Do not use a sequential RNG stream for bot choice — keyed only, or adding a power shifts every prior decision
- Do not let the random tier become the doctrine fallback for a power that has real doctrine
- Do not tune a threshold from a mean without looking at the distribution

# Implementation status and acceptance notes

The shared chooser and Gremory frequency batches are now implemented, pending
local Godot 4.7.2 verification. See [the batch contract and run command](U13_RANDOM_BATCH_2026-09-08.md).
The original smoke scene remains a preset scenario, and the new batches remain
explicitly scoped to the current combat slice. Another Lord stays gated on local
foundation and batch acceptance. The following acceptance requirements still apply.

At the 11/11 checkpoint, `U13Legality` validates individual declarations but does
not enumerate legal sets. Implementation must add data-only candidate generation
at the content/legality boundary and filter complete candidates with the existing
shared validator and `U13Match.preview_submission`. Final selection still enters
`submit`; queue costs, physical discard cards and cooldown reservations must be
checked together. No parallel rules implementation belongs in the chooser.

Before measuring, pin and record the sampling contract: what constitutes a complete
distinct declaration, how equivalent payment/target combinations are deduplicated,
and how finite canonical positions are enumerated when spatial powers arrive.
Uniform complete declarations and independent uniform payload choices are not
interchangeable when payload domains have different sizes. Do not silently weight
a power by duplicate candidate representation. Key decisions by match, round,
player, power/decision identity and dedicated purpose. Adding a candidate may alter
that choice's result; it must not shift unrelated RNG draws.

Reports must retain raw counts and denominators. When threshold-met count is zero,
report `declared=N, threshold_met=0, ratio=undefined` rather than dividing by zero.
Include the distribution and sample size, sampling hook(s), active roster/profile,
seed set, match/round limits and which mechanics are absent. A failure to reach a
threshold in a finite random batch is an observation, not proof of unreachability.
Record peak density as well as fixed-hook density so spawn-then-die rounds are not
mistaken for empty fields. First target remains the per-round Marcher distribution
with both sides generating units. Do not tune numbers or publish win rates from it.
