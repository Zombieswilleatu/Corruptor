# Corruptor — Post-Green Roadmap
**What happens after 81/81 `game:end` matchups are green**
*v1 · July 2026 · companion to the Devlog (v1.1) and the Tell System spec*

This document assumes the current sweep succeeds: every ordered Lord pairing
(9 × 9 = 81, mirrors included — ordered pairs are required because seating
changes deal order from the same shuffle) reaches the oracle's terminal state
under `SIM_VERSION 6.0` / `AI_POLICY softmax-2026.07-v1-golden`. Everything
below is sequenced. Do not reorder without a reason you can write down.

---

## Definition of done for the current sweep (read before declaring green)

Green is 81/81 `game:end` matches — but one seed per matchup validates one
*trajectory*, not one *kit*. Rare branches (Kroni's Ravenous, vessel offers,
Odradek steal, Kanifous high-invoke) may simply never fire at seed 1 in a
given pairing, and a branch that never executed is a branch that never got
validated.

**Hardening step before closing Phase 1:** run a coverage audit. Count, per
Lord ability, how many of the 81 games actually exercised it (the sim's
existing stat counters cover most; add counters where they don't). For any
ability with zero firings across the whole sweep, add a second seed to one
matchup that plausibly triggers it, generate that trace, and green it too.
Cheap insurance: an hour of counter-reading versus a silent unvalidated code
path shipping into Phase 2.

---

## Step 0 — Freeze the milestone

Tag the repo. Archive the full trace set, both sims, and the manifest under
an explicit label (`parity-6.0-golden`). This is the known-isomorphic
baseline and the permanent rollback point: from here forward, any divergence
after a change is attributable to that change alone. This is the entire
payoff of finishing validation before surgery — don't skip the thirty
seconds it takes to bank it.

Also update Devlog §12/§13: Phase 1 closed, current frontier moves to the
balance axis.

---

## Step 1 — The Odradek rework (rules axis, SIM_VERSION bump)

The finding, compressed: Odradek wins 87.7% in locked 1v1 while playing Ward
on 100.0% of decisions. He carries **two redundant passive win engines** —
the soul engine (Recoil pays him a soul per first attack per round, on Hunts
*and* Sieges, plus ward souls on sigil breaks) and the tear engine
(Reconfiguration tokens accrue whenever he isn't heavily attacked). The
lever table proved no dial fixes him: zero his tears (O7) and he wins 86.9%
by converting Dominion wins into FinalCollapse wins; gut the soul engine
(O1) and Dominion triples; stack both recoil levers and he still sits at
68.5%. Strangle either organ and the other grows.

**The amended Odradek Law** (supersedes the original in the Design
Companion): *passive win-condition income must be deniable AND
non-fungible.* Deniability alone failed — income that converts freely
between the soul race, the tear race, and the collapse clock cannot be
denied by attacking any one track. The rework must satisfy both clauses.

Acceptance criteria for the redesign (test before accepting):
- Locked 1v1 win rate inside the 38–62% band against the field.
- Section 10 Ward share meaningfully below collapse (a Lord above ~85%
  single-action share is still degenerate whatever his win rate).
- A denial test passes: an opponent strategy that attacks him must
  measurably reduce his total income, and one that ignores him must not be
  strictly better than one that fights him.
- No income stream converts across win tracks without an *action* spent.

Process, in your own standing order: design on paper → implement in the
Python oracle → titrate (one change per run, locked mode, Section 10 on) →
when accepted, bump `SIM_VERSION`, regenerate **all** golden traces, port
the kit change to Godot, and re-green — targeted matchups first (the 17
ordered pairs involving Odradek), then the full 81 as the closing gate.

---

## Step 2 — The doctrine pass (policy axis, AI_POLICY bump — separate from Step 1)

Keep this on its own axis and its own bump; do not fold it into the kit
change or you lose attribution. Contents, from the same investigation:

- **The Ward-collapse trio.** Humbaba (99.8% Ward) and Kanifous (96.4%) are
  not dominant — their degeneracy is boredom, not power — but a Lord that
  makes one choice is not a character, and the softmax layer cannot fix an
  evaluation whose argmax is always Ward. The fix lives in
  `_score_ward`/`_score_hunt`/`_score_siege`, not in temperature.
- **Humbaba's `_ai_pick_lord` entry.** He has no scoring line, so pool mode
  essentially never fields him (538 decisions across ~43k games). All
  historical pool-mode validation of "DE v2 + Humbaba" happened while
  Humbaba sat out. Add the entry, then treat prior Humbaba pool data as
  void and re-run.
- **The attack/turtle balance.** Lock mode revealed win rate tracking Ward
  share almost monotonically — attacking is systemically unprofitable under
  this doctrine. Open question to resolve here: is that true game structure
  or bad attack evaluation (over-whiffing feeds ward souls)? Instrument
  attack success rate per Lord before concluding.

Each doctrine change is a balance change (Law 5): AI-dependent traces
regenerate, balance grids re-run.

---

## Step 3 — The re-validation regime (make the new instruments permanent)

The old regime missed a 100%-Ward Lord because it only looked at win rates
in pool mode. Codify what this investigation proved necessary:

- **Dual-mode gates**: every balance run happens in *both* pool and lock
  mode. Lock is the per-Lord signature; pool is the metagame. Neither
  substitutes for the other.
- **Section 10 as a standing gate**: the action-distribution check runs on
  every balance pass, with explicit thresholds (flag any Lord over ~85%
  single-action share; flag avg spread under ~8 pts as reskin signature).
- **Known open items carried on the board**: Kroni 67.7% locked (same
  turtle family, 78.6% Ward), Valak-vs-Kroni 32.2% timeout stall (CRITICAL
  flag), Deimos 20.5% locked (weakest seat). Titrate through them *after*
  Odradek — one at a time, re-measuring between.

---

## Step 4 — Phase 2: the loop on screen

Only now. Wire human input into one seat; the proven bots take the other.
The build targets, in order of what the "is it fun" test actually needs:
the commitment interaction (note: the Tell System spec's §12 flags that the
commit UX — discrete confirm vs single tap — should be decided *before* the
loop is locked, even though tells themselves stay parked), the simultaneous
reveal as a staged, suspenseful beat, and the three clocks visible enough
that telegraphing works on a human the way the fairness metrics assume.

The softmax selection layer ships here with temperature as the difficulty
dial — built aware it is also the tells foundation and the boss-identity
foundation, per the parked spec.

### 4a — UI built in code, guarded by layout invariants (not golden images)

**Decision: build the UI in code, not by hand-anchoring in the editor** — and
because it's code, apply the harness discipline to it. But test *layout
invariants*, not pixels. This distinction is the whole point; getting it wrong
in either direction wastes the effort.

Why invariants and not golden-image diffing: pixel snapshots catch
*regressions* (it changed from what it was), not *bugs* (it was wrong from the
start) — a snapshot test blesses whatever the first run produced, so a day-one
mistake gets enshrined green. They're also brittle in the wrong direction:
antialiasing, font hinting, driver updates, and one-pixel shifts all red an
exact pixel diff while being visually irrelevant, which trains you to ignore
the suite (the burned-vocabulary failure mode). And they need a stable target
to regress from — pre-Phase-2 UI is the least stable code in the project by
design, so pixel goldens over it are ballast, not insurance.

Code-built layout changes what's being tested, and that's what makes it worth
doing. Layout becomes the *output of functions* — "given panel width W and
card count N, compute these rectangles" — which is structured data, diffable
the way sim traces are, with none of the pixel brittleness. Crucially, it has
an oracle that pixel-blessing lacks: **math.** These are computable truths,
assertable from first principles, catching bugs on day one rather than
recording day-one's mistake:

- No two cards overlap; every card sits inside its container's bounds.
- N slots are evenly spaced across available width
  (`slot[i+1].x − slot[i].x` constant).
- The reveal panel is centered; the three clocks occupy their declared
  regions; nothing is placed off-screen at any supported resolution.
- Every element the state says should exist is placed, and placed by the rule.

Make them **property tests, not single cases**: assert the invariant holds for
*any* hand size 0–10, any castle count, any supported resolution — not just the
one layout you eyeballed. This is the exact move already proven this cycle:
the card-conservation assertion (`total == 60` every round) tested the
invariant, not the instance, and caught the *class* of bug. Same here — test
the geometric rule, not the screenshot.

The boundary, stated so it isn't mistaken for more than it is: invariants prove
the layout is *structurally correct* (nothing overlaps, everything placed by
rule, state maps to the right elements). They cannot prove it's *good* —
pleasing spacing, a reveal that lands, readability under pressure. Those stay
human (Phase 2 feel-test). The division is clean and correctly placed: the
invariants cover what the eye misses (a card three pixels off-container at an
untested resolution); the eye covers what invariants can't reach (whether it
feels right). No overlap, no false comfort.

Optional adjacent layer, low cost, real risk: a dozen **view-model
assertions** on the non-obvious state→display *logic* — is the Cataclysm
warning showing at the right threshold, are the right cards marked playable
given hand + castles + threat. Build the `GameState → view_model → pixels` seam
for architecture reasons regardless (it makes code-built UI sane to work with);
if it exists, these assertions come nearly free and target genuine display-logic
risk the eye won't reliably catch.

Sequencing guardrail (the anti-runaway rule, since that's the stated worry):
**write each invariant in the same sitting as the layout function it guards** —
when the rule is clearest and cheapest to encode — a handful of assertions per
component, accreting as the UI is built, never a big retrofitted suite. This
scales the guard *with* the UI instead of front-loading infrastructure against
UI that's still supposed to move. Do NOT build a comprehensive pixel-golden
harness across trace snapshots now; defer any pixel-level layer (tolerant
perceptual threshold, not exact match) to *after* Phase 2 proves the loop and
the UI stops changing.

---

## Horizon (unchanged, pointers only)

Async backbone (commit-reveal protocol), roguelike solo spine with per-Lord
boss identities, then the Read/tell system — still parked, still gated on a
proven-fun loop and repeated-opponent data. Soundtrack direction noted and
deliberately deferred (reference palette: ISN / raison d'être; adaptive
Veil-bed architecture, not per-Lord album tracks).

---

## Standing disciplines (the ones this cycle re-earned)

Diagnose before acting. Titrate — one lever per run. Two axes, versioned
separately, moved atomically with their traces. Read the checkpoint
sequence, not the field name. Verify the instrument before trusting the
result — and when a result is impossible (byte-identical games across a
rules change), believe the impossibility, not the result. Green means
validated trajectories, not validated code: coverage is a separate claim.
Test the invariant, not the instance — assert the computable rule
(conservation == 60, no card overlaps, slots evenly spaced) across the input
range, never bless a single recorded output. Write the guard in the same
sitting as the thing it guards, so it accretes instead of front-loading.
