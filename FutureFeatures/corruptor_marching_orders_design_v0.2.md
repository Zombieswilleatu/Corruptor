# Corruptor — MARCHING ORDERS
**v0.2 · July 2026 · design spec with measured balance data**

Supersedes v0.1 (design-only). Supersedes the parked concept in Post-Green
Roadmap **Appendix A.1 (Lane Clash)**.

**What changed at v0.2:** the system was implemented in the experimental lab and
run against the Vanilla structural testbed. **§9.1 (the launch rule) is resolved
by measurement.** §9.2 and §9.4 are resolved. The suit cycle and the exception
pair moved from "probably load-bearing" to *measured* contributions. One
implementation finding — the interceptor role — turned out to be the entire
balancing mechanism and is promoted to a first-class section (§6).

**Status: implemented in the lab, flag-gated, not landed.** Nothing here is in
the canonical sim, and none of it has been costed against parity.

---

## 1 · Test conditions — read before trusting any number

Every figure below was measured **on top of the ward/decay experimental pass**,
not on stock 6.1.0. The base configuration is:

`fix_a` (doctrine rebalance) · `fix_b` (Profane denial removed) ·
`castle_scarring` + `castle_permanent_loss` + `veil_on_permanent_loss` +
`lord_threat_retention` (the decay pass) · `ward_threshold` + `ward_commit_any` +
`ward_read` with `ward_anti_repeat` off.

Structural runs are **Vanilla mirror, n=300**. Roster figures are a **6-matchup
smoke test, n=100 each** — a sanity check, not a balance grid.

**All of it is measured against deterministic doctrine.** Both players run
identical policy, which is the correlation-artifact class the roadmap already
warns about. Treat directional findings as solid and exact values as provisional
until mixed/softmax selection exists.

---

## 2 · What it is

Two lanes — **Lord** and **Castle**. During Deployment you may commit one Guard
from your own Lord or Castle zone into a lane, face up. It marches toward the
enemy gate over three rounds. Arriving with **value 3 or more** grants its owner
**1 personal Tear**.

**Marching does not cost your Order.** It runs parallel to Hunt / Siege / Ward /
Profane. **Profane is not replaced** — it remains the fast risky conversion; the
lane is the slow committed one.

**One marcher in flight at a time.** See §7.

---

## 3 · The cost, and why it is the good part

Committing a marcher removes a Guard from a named zone. That zone is down one
Guard **for that round only** — refill from hand next Deployment regardless of
how far the marcher has travelled.

The defensive loss is **temporary but visible**:

- **Authored** — you chose which zone to thin
- **Public** — the opponent sees which door got softer
- **Falsifiable** — march out of the Lord zone to invite a Hunt you are ready for

This is the costly, self-chosen, deniable signal the game has been missing.
Face-down Guards produced error bars; this produces a statement that can be a lie.

---

## 4 · Clash

Marchers of opposing players sharing a lane meet and clash. Damage is
**simultaneous**.

- Base clash damage: **2**
- Suit advantage: **+1** (3 total)
- Reduced to **0 or less** → destroyed, to discard
- A survivor continues with its **reduced value**, which is what must clear the
  threshold on arrival

**Suit cycle:** Butcher → Wright → Penitent → Vulture → Butcher.
Cross-cycle and mirror pairings are neutral.

Marchers are **physical cards**, not tokens. Damage degrades the card's value in
the lane; on death or arrival it goes to discard. **Card conservation verified**
— end-of-game totals are identical with lanes on and off.

---

## 5 · The arrival threshold — confirmed at X = 3

**Derived** from the clash math:

| marcher | unopposed | after one neutral clash (−2) | after one suited clash (−3) |
| --- | --- | --- | --- |
| 5 | scores | **3 — still scores** | 2 — denied |
| 4 | scores | 2 — denied | 1 — denied |
| 3 | scores | 1 — denied | 0 — destroyed |
| 2 | denied | — | — |
| 1 | denied | — | — |

Three jobs off one number: it kills the chump-blocking arbitrage that sank
Appendix A.1; it makes the 5 the *only* card that survives a clash and still
delivers, with opportunity cost scaling exactly to payoff; and it gives the suit
cycle a real job, since suit advantage is the only thing that stops a 5.

**Measured — X=4 is worse.** Raising the threshold produced Ritual 73.7 /
Dominion 23.7 against X=3's 56.0 / 40.7. Fewer cards qualify (7.9 launches per
game vs 10.3), clashes fall to 3.4, and the lane stops being a real path. **X=3
holds.**

**Deck context** (`CARD_DIST` {1:4, 2:4, 3:4, 4:3, 5:3} per suit × 4 suits, 12
removed at setup → 60): values run roughly 22 / 22 / 22 / 17 / 17 percent. A 5 is
about one card in six.

---

## 6 · The interceptor role — the balancing mechanism

**Promoted from a flavor note in v0.1 to the load-bearing mechanic.**

Sub-threshold cards (1s and 2s) can never score. They exist to **deny**. In the
first implementation the launch doctrine filtered them out entirely — only
threshold-capable cards could be committed — which made denial structurally
impossible. The difference is not subtle:

| | score rate | clashes/game | Dominion |
| --- | --- | --- | --- |
| interceptors disabled (bug) | 64.5% | 1.1 | 73.3% |
| **interceptors enabled** | **19.1%** | **4.6** | **40.7%** |

With no cheap bodies to spend, every march ran unopposed and the lane became the
dominant win condition. **The lane is only balanced because low cards have a job.**

Doctrine consequence: interceptors must be launched **into** the enemy's lane,
and only when an enemy marcher is in flight that can still score. Spending a
Guard to deny nothing is strictly worse than not marching.

This also completes the role differentiation across the value curve: 1s and 2s
deny, 3s and 4s score only if unopposed, 5s score through a clash.

---

## 7 · §9.1 RESOLVED — one marcher in flight

The largest open number in v0.1. Measured:

| launch rule | rounds | Ritual | Dominion | launches | clashes |
| --- | --- | --- | --- | --- | --- |
| **one in flight (max = 1)** | **13.1** | **56.0%** | **40.7%** | 10.3 | 4.6 |
| staggered (max = 3) | 9.9 | 39.7% | 58.3% | 16.5 | 7.6 |
| control, no lanes | 14.8 | 81.3% | 15.0% | — | — |

Design target is **Ritual ~60 / Dominion ~35**. One-in-flight lands at 56 / 41 —
the closest the game has come to its own target. Staggered overshoots badly and
compresses rounds to 9.9.

**Ruled: one marcher in flight per player at a time.**

---

## 8 · Both exception mechanics measured, both load-bearing

**The suit cycle is a denial mechanism.** Disabling it makes the lane *stronger*,
not weaker — Dominion rises 40.7% → 48.0%, because suit advantage is the only way
a cheap interceptor drops a 5 below threshold.

**The Marshal/Spy pair is a significant Dominion driver.** Removing it costs
12 points — Dominion 40.7% → 29.0%, score rate 19.1% → 8.5%.

| variant | Ritual | Dominion | score rate |
| --- | --- | --- | --- |
| full system | 56.0% | 40.7% | 19.1% |
| RPS off | 49.3% | 48.0% | 22.6% |
| no Marshal/Spy | 66.3% | 29.0% | 8.5% |

Note both read as inert in the first (buggy) pass, because nothing was clashing.
A mechanic that only fires on contact cannot be evaluated in a system with no
contact — worth remembering as a general instrument-check.

**Vulture:5** ignores collision. No other Vulture is exempt.
**Butcher:1** is the only answer — both are destroyed on meeting.

Butcher is deliberately the suit the cycle says Vulture *beats* — the prey biting
back. Value 1 rather than 3 so the counter is cheap to hold: an expensive Spy
becomes insurance you never spend, a permanent drag on flexibility. Mutual
destruction is specified rather than survival so the rule stays correct if the
value ever moves.

**Exception budget: spent.** Lane-manipulation Lord powers must **move, block, or
redirect** — never add further "X ignores Y" clauses.

---

## 9 · §9.4 RESOLVED — lanes *reduce* read accuracy

v0.1 worried that visible Guard removal would over-feed the ward read, which was
already measuring above the healthy band (~67%). The opposite happened:

| | no lanes | lanes on |
| --- | --- | --- |
| Vanilla mirror | 68.0% | **64.2%** |
| real roster | 76.0% | **71.2%** |

Pulling Guards for marches makes zone composition *less* predictable. The lane
adds noise, not signal, and moves read accuracy toward the healthy band rather
than past it. No mitigation needed.

---

## 10 · Real roster smoke test

Six matchups × 100 games:

| | rounds | Ritual | Dominion | Final Collapse |
| --- | --- | --- | --- | --- |
| no lanes | 10.3 | 74% | 15% | 11% |
| **lanes on** | **7.3** | **61%** | **30%** | **9%** |

Three live win conditions on the real roster for the first time.

**Watch item: rounds compress to 7.3.** Faster than the Vanilla mirror's 13.1 and
faster than the roadmap's existing pacing concern. Real kits accelerate the lane
in a way the structural testbed does not show. Needs a full 81-matchup grid
before this is trusted.

---

## 11 · Lane choice is a richer read than it looks

Not plain matching pennies, because **whether you want contact depends on your
card**. A 5 hunts for contact — it kills the interceptor, arrives at 3, still
scores. A 3 evades; any clash denies it. A 1 or 2 *only* wants contact, because
scoring is impossible and denial is the job.

So the read is not "which door" but **"what did they draw."** A lane clash is not
automatically a denial; sometimes it is the aggressor's preferred outcome.

The two lanes are the **same two doors** as Hunt/Siege and Ward — one spatial
vocabulary across the whole game — and the reads are *linked*: marching out of
your Lord zone weakens it for their Hunt **and** signals lane intent, via the
same physical card.

---

## 12 · Still open

**12.1 — Roster pacing.** 7.3 rounds on the smoke test. Verify against a full
81-matchup grid before accepting; may need march_steps 3 → 4.

**12.2 — Per-Lord balance is unmeasured.** Six matchups is not a grid. Expect
polarization (Gremory Law): Humbaba's 4th Guard slot is a marching resource,
Deimos's War Machine already degrades on two axes, and Kanifous's Hand→Garrison
path is the only zone-adjacent mechanic in the engine.

**12.3 — Vulture:5 deniability.** Now measured as worth ~12 points of Dominion
with only Butcher:1 as an answer. This brushes the **Odradek Law** (passive
wincon income must be deniable). Candidates if playtest complains: a Ward on that
lane blocks it, or an extra step of travel.

**12.4 — Launch doctrine is an `AI_POLICY` axis change.** Law 5 applies: the
interceptor heuristic in §6 is a balance change, must be versioned separately
from `SIM_VERSION`, and every number in this document is conditional on it.

**12.5 — Lord powers on the field.** Deferred until the base lane proves fun.
Design toward it: keep lane state simple (position, value, suit, lane) so powers
have clean hooks.

**12.6 — Unrelated, found while testing:** the base sim ends games at **57 cards**
rather than 60, with or without any lab change. Pre-existing; worth its own look.

---

## 13 · Why this version clears Appendix A.1's objections

1. **Forecloses hidden Guards** — *resolved.* Marchers are face-up **by choice**,
   one at a time, in a lane. Zone Guards are untouched and can stay hidden.
2. **Value economy inverts** — *resolved by X=3, and measured.* Cheap cards cannot
   score; they intercept instead, and that role is what balances the system (§6).
3. **Doesn't address order dominance** — *resolved.* Marching is parallel to the
   Order and pulls Guards out of zones, pressuring the defensive allocation that
   drives Defect 1.
4. **Parity cost** — *unchanged and still real.* This invalidates traces and all
   81 matchups. It is a `SIM_VERSION` event.

---

## 14 · Explicitly out of scope for v0.2

No healing. No retreat. No stacking multiple marchers per lane. No direct damage
to objectives — arrival grants a Tear, nothing else. No suit abilities beyond the
matchup bonus and the §8 exception pair. No deliberation clock. No Lord powers.
