# Corruptor — Post-Green Roadmap
**v2 · July 2026 · companion to the Devlog and the Tell System spec**

Supersedes v1 (archived). The major change: **Phase 1 parity is complete**, and
balance work has been re-ordered. Lord balance is now explicitly *downstream* of
structural balance, because the vanilla testbed proved the base game's structure
was broken independently of any kit.

---

## STATUS

**Phase 1 — COMPLETE.** 8,100-game randomized parity soak passed: 100 seeds x
81 ordered matchups, every round-end hash and terminal state matched, zero
divergences. Permanent golden suite also clean. The Python oracle and the Godot
engine are bit-for-bit isomorphic.

Bugs found and fixed during the soak grind (all oracle-side, all bilateral):
Penitent temp-guard double-discard (phantom card duplication), blocked-Profane
stale `pending_profane` awarding an invalid Tear, the Consume fix, the Vessel
aftermath regression, and the Kanifous cluster.

**Parity: TAGGED.** `parity-6.0-golden` is committed, including the Kroni/finale
timing correction that made the second lineage pass. Balance tooling committed
separately so the parity milestone stays free of experimental work.

**Two independent lineages passed — 16,200 games total** (masters `20260719` and
`20260722`), each with an oracle branch-coverage audit. All **18** tracked
semantic events fired broadly. Permanent golden suite passes.

**Godot infrastructure: built.** The canonical Godot balance runner exists, as
does the disposable Experimental Balance Lab. The next construction task is not
infrastructure — it is turning the lab into a **Vanilla structural testbed with
experimental policy injection**.

---

## The methodological unlock: the VANILLA LORD

The single most valuable thing built this cycle. A synthetic Lord — `Vanilla`,
s6/d5/r1, **zero abilities**, neutral AI profile, excluded from `ALL_LORDS` so
it never pollutes balance grids.

Why it matters: every structural measurement taken across the nine real Lords is
contaminated by their kits. Humbaba's castle-scaling defense, Odradek's income
engines, Kroni's hunger — these distort action matrices and the tear economy so
badly that the base game's actual structure was invisible. Vanilla mirror
matches give clean readings of the *rules*, with zero kit interference.

**Rule going forward: structural questions are answered vanilla-vs-vanilla. Kit
questions are answered on the real roster. Never mix the two.**

---

## What the vanilla testbed revealed (why the roadmap re-ordered)

Measured on vanilla mirrors, three compounding failures appeared. **Read the
evidence classes separately** — two are doctrine artifacts, one is a rules-level
finding, and conflating them risks rewriting rules to fix a bot:

**1. [DOCTRINE] The game did not resolve.** 73–76% of vanilla games hit the
60-round Timeout; ~49 rounds average; Ritual only ~24–27%. Cause traced to the
deterministic doctrine overvaluing Ward.

**2. [DOCTRINE] Dominion was unreachable.** Personal tears averaged **0.02 per
game** against a 3+ requirement. The path existed on paper (Profane and
Cataclysmic Invocation are base Rites available to all) but the doctrine never
chose it — `_plan` could only return `race_dominion` if you *already* had tears.

**3. [RULES] One action dominated absolutely.** The vanilla **forced
pure-strategy** matrix showed **Siege beating Hunt 96–7**. This is the strongest
finding of the three: forced policies bypass doctrine action-choice entirely, so
the asymmetry is mechanical, not behavioural.

**What this does and does not prove.** Findings 1 and 2 prove *the current AI
doctrine produces structurally broken play*. They do **not** prove humans or
mixed-strategy bots would fail the same way. Finding 3 is genuine rules-level
evidence and survives any doctrine change.

Causal chain: **Ward overvalued in doctrine -> everyone wards -> every Profane
blocked by Fresh-Sigil denial -> no personal tears -> Dominion unreachable ->
games never end -> Timeout.** One doctrine flaw cascading into a dead win
condition and a stalling game.

---

## Structural fixes validated (vanilla-vs-vanilla, experimental branches)

**Experimental findings, not shipped changes.** Each was measured; none has been
committed to the repo or re-validated for parity.

### FIX A — Doctrine rebalance (policy axis)
Action score bases equalized to **0.333 each** (were Hunt 1.8 / Siege 1.0 / Ward
0.6), and Ward's unconditional accumulators tamed: `souls x 0.55 -> 0.12`,
`castles x 0.30 -> 0.08`, `threat x 0.35 -> 0.20`.

The accumulators were the real culprit, not the base — Ward's base was already
*lowest* of the three, but `souls x 0.55` at 6 souls added +3.3 unconditionally,
letting Ward drift to 6–8 while Hunt sat near 2–3.

**Result:** Timeout 75.9% -> 17.5%. Rounds 49.7 -> 17.6. Ward share 88.9% ->
52.1%. Personal tears 0.04 -> 0.45.

### FIX B — Profane denial removed (rules axis) — **HYPOTHESIS, NOT LANDABLE**
The rule "a Fresh Sigil in ANY opponent zone cancels Profane" deleted outright.
Rationale: sacrificing your own castle is self-destruction; an enemy ward has no
bearing on it.

**Result:** Dominion 0.7% -> **17.2%**. Personal tears 0.45 -> **2.49**. Timeout
17.5% -> **0.2%**. Rounds 17.6 -> 8.9. Profane *usage* dropped 32.4% -> 10.2% —
making it work made the AI stop spamming it.

**Note on the 97.7% denial rate that motivated this — it was NOT a bug.** Sigil
decay works correctly (Fresh ~50% of rounds, as expected). The 97.7% was a
**correlation artifact of deterministic mirrored bots**: board states that make
Profane attractive to one player simultaneously make Ward attractive to the
other, so Ward ran ~98% *conditional on* the opponent profaning. Two humans or
mixed-strategy bots would decorrelate substantially; real denial would sit
nearer 50%.

**Therefore FIX B must NOT be landed yet.** An earlier draft of this roadmap
both flagged the artifact *and* scheduled the fix — a contradiction. A rules
change cannot be justified by a measurement that is an artifact of the policy.
Correct order:

1. Implement mixed/softmax selection.
2. Re-run Vanilla with denial **unchanged**.
3. Measure the *real* conditional denial rate.
4. Only then decide: remove, weaken, or leave alone.

FIX A is a justified AI-policy correction and can land. FIX B stays an
experimental rules hypothesis until step 3 above produces a number.

### Resulting structure (vanilla, both fixes applied)
```
            vs Hunt   vs Siege   vs Ward   vs Profane
Hunt         48.0       7.5       88.5       93.5
Siege        95.0      40.0       61.5       83.5
Ward          6.0      38.0       46.0       80.5
Profane       9.0      16.0       21.0       51.5
```
A real cycle now exists: **Siege -> Hunt -> Ward -> Siege.** Profane is strictly
dominated as a *pure* strategy, which is acceptable and probably correct — it is
a **conversion action**, not a strategy. It performs correctly in mixed play
(10.2% usage, 17.2% Dominion) while being terrible as a monoculture.

---

## STRUCTURAL DEFECTS STILL OPEN

**1. Siege crushes Hunt 95–7.5.** The largest remaining asymmetry, and **not a
numbers problem** — it survived halving every castle defense. Cause is **target
selection**: `_pick_siege_target` picks the weakest of five castles (hard-ordered
Stockpile -> SummoningCircle -> SiegeEngine -> Bastion -> Keep), while a Hunt has
exactly one target and no choice. Measured: Siege destroys 95.6% facing an
average wall of 11.8; Hunt destroys 9.6% facing a wall of 14.8. Hunt's wall is
*taller* despite Lord structure being lower, because the AI defends its Lord
preferentially and Siege gets to pick its fight.

Candidate fixes (untested): give Hunt comparable target selection (Lord *or* a
named guard zone); remove Siege's free pick (defender chooses, or must target the
strongest); decouple castle destruction from full Ritual scaling.

**2. Hunt is self-limiting by design.** `_lord_killed` **resets the victim's
Threat to base**, and a dead Lord cannot be hunted until resummon. A successful
Hunt *cures* the condition that made the target killable and grants temporary
immunity. Siege has no equivalent — destroyed castles stay destroyed. Siege is a
ratchet; Hunt is a reset button. Decide whether this is intended flavor or a
defect.

**3. Lord vs castle defense gap.** Lords 4–6 (Humbaba 2+castles); castles were
7–13. The weakest castle out-defended the toughest Lord. **Lowering castles
13/11/9/8/7 -> 8/7/6/5/4 changed almost nothing** — destruction was already
95%+, so castle defense was never the binding constraint. Do not re-run this
lever.

**4. Ward-vs-Hunt is 6.0/88.5** — steepest edge in the matrix. Ward counters
Siege but collapses against Hunt. Sigil value cannot fix this: +2 on a Lord wall
of ~5 against an 18-strength commit is noise. If Ward should resist Hunt, the fix
must be **categorical** (cap damage, force a re-commit, cancel the first attack),
not additive.

**5. Mirror matches run below 50%** (Hunt 48.0, Siege 40.0) — suggests a
second-player advantage worth isolating separately.

---

## Levers TESTED AND REJECTED (do not re-run)

- **Golden Rule flip (equality favors attacker).** Rejected on evidence: only
  **3.9%** of failed attacks fall <=1 short, so the flip would rescue almost
  nothing while detonating the balance baseline. Attacks succeed ~80% of the
  time; whiffing was never the problem.
- **Ward commit cost (2 / 3 / 4 committed value).** Rejected. Cost 4 gave four
  imbalanced Lords (vs three at baseline) and **killed Dominion (1.5%)**; cost 3
  was worse (five outliers, Dominion 1.3%). Pricing the ward destroys the tear
  economy at every setting, because turtling was how Dominion got played.
  Humbaba collapsed to ~30% at every cost **even with a full exemption** —
  proving his problem was ward *effectiveness*, not ward cost.
- **Castle defenses lowered into Lord range.** No meaningful effect (Defect 3).
- **Siege feeds the tear economy (personal tear on castle destruction).**
  Promising — revived Dominion to 8.0% lock / 4.7% pool, tightest pool spread
  seen — but handed Odradek a third income stream (89.4%) and did not lift the
  dedicated attackers. Shelved, not dead.

---

## Step 0 — Freeze the milestone   [COMPLETE]

`parity-6.0-golden` is tagged, including the Kroni/finale timing correction that
made the second lineage pass. Balance tooling committed separately, so the parity
milestone stays uncontaminated by experimental work.

**Pin three permanent regression seeds** (corrected — the earlier single-seed
claim was scoped to a 10-branch tool, not the 18-event audit):

| Seed | Purpose |
| --- | --- |
| `2052353491` | Historical pathology / parity regression (caught 3 bugs during the grind) |
| `361542937` | Complete 18-event semantic cover, lineage `20260719` |
| `860794004` | Complete 18-event semantic cover, independent lineage `20260722` |

Plus both 100-seed soak sets.

**Coverage audit: COMPLETE.** The permanent tool is `oracle_branch_coverage.py`
(the earlier `branch_coverage.py` was the 10-branch prototype). All 18 events
fire. Do not rebuild.

---

## Step 0b — The Experimental Balance Lab (next construction task)

Infrastructure exists; capability does not. `RuleConfig` overlay handles
thresholds, costs, flags, and numeric tuning — enough for dial-turning, not
enough for the structural experiments this roadmap requires. Five seams needed:

| Roadmap need | Experimental capability required |
| --- | --- |
| Vanilla Lord | Experimental Lord definition + locked matchup support |
| FIX A | Experimental doctrine-scoring profile |
| FIX B | Experimental Profane-denial behaviour toggle |
| Softmax check | Policy temperature + deterministic seed control |
| Pure-action matrix | Forced-action policy profiles + matrix report |

**Isolation rule:** all of it lives under `Experiments/BalanceLab`. Canonical
simulation files must never import from it. Deleting the folder must erase the
entire experimental system harmlessly.

**Build order:** Vanilla support -> reproduce the Python Vanilla baseline in
Godot -> reproduce FIX A -> add softmax -> re-run with *original* Profane denial
-> only then evaluate FIX B against that mixed-policy control.

---

## Step 1 — Structural balance   (was Step 2; now FIRST)

Lord balance is meaningless while the base structure is broken. Every kit-level
lever tried this cycle "sloshed" — helping two Lords, breaking two others —
because they were all refracted through a structure that didn't work.

1. Land **FIX A only** (doctrine) — versioned, traces regenerated.
2. Implement **mixed/softmax selection**, then re-run Vanilla with Profane denial
   *unchanged* to get the real conditional denial rate. Decide FIX B from that
   number, not from the deterministic-bot artifact.
3. Attack **Defect 1** (Siege 95–7.5 over Hunt) — the one finding that is
   rules-level rather than doctrine-level, so it is safe to act on now.
3. Re-measure the vanilla matrix. Target: **no core combat action — Hunt, Siege,
   or Ward — is strictly dominated**, and no single edge steeper than roughly
   70/30. Profane is explicitly excluded from this test: it is a *conversion
   action*, judged by conversion value and mixed-policy usage, not by
   pure-strategy win rate. (The earlier "no action strictly dominated" phrasing
   contradicted the Profane conclusion below.)
4. Then victory-path tuning. Current vanilla: Ritual 82.7% / Dominion 17.2% —
   **but measured with FIX B applied**, so treat as provisional until the denial
   question resolves. Design target ~60/35.

**Pacing watch:** vanilla games now run **8.9 rounds**, down from 48.6. That may
be too fast — a 9-round game may not leave room for three-clock tension or the
reveal-and-read loop the bluffing premise depends on. Verify this is pleasant
brevity and not a new defect.

---

## Step 2 — Lord balance   (was Step 1; now SECOND)

Only after the structure holds. Findings so far, to be **re-validated against the
fixed structure** — most were measured on the broken one:

**Odradek** — 88.0% lock on the current parity-proven oracle, **100.0% Ward**,
confirmed *unchanged* by all parity bug fixes, so his dominance is fully
structural. Note the lock/pool split: 88% locked vs ~54–60% pool, because the
pool AI can counter-pick him. Work done (experimental):
- *Psychic Recoil -> Psychic Link mirror.* Declared openly in Development,
  persistent, free, re-declarable; links Odradek's Lord zone to one enemy zone
  (Lord/Castle/Garrison); damage to his Lord guards mirrors into that zone. No
  Soul, no pre-combat strength interference. Post-combat: **the attack lands,
  then it costs.** Result: 88% -> 68–69%, but Ward stayed at 100%.
- *Reconfiguration -> Battle Form.* Tokens accrue as before; at 3 tokens he gains
  a large Siege buff (tested at +6) instead of a free Tear, and a charged siege
  claims its castle-kill tear personally. Result: 57.6%, **first time out of
  DOMINANT**, Siege share 0% -> 7.4%.
- *Dual accrual* (tokens from being left alone OR killing 2+ guards) had **no
  effect** — the offensive path can't bootstrap, and attack rate is pinned by the
  charge cycle (3 tokens / 1 per round ~ a siege every 3 rounds ~ 7.4%). For more
  aggression the lever is `reconfig_tokens_needed` (3 -> 2).

**Humbaba** — the ward-cost experiments proved his weakness was ward
*effectiveness*, not cost. **Stronger sigils (+2 fresh / +1 flipped) moved him
30% -> 45.3%** on a full sample. Keep this. **But** stacking it on top of a
*universal* sigil buff pushed him to 80.7% — the two are redundant; pick one.

**`_ai_pick_lord` Humbaba entry — FIXED.** He had no scoring line, so pool mode
essentially never fielded him (~538 decisions across ~43k games). With the entry
added he reaches ~12.6% of seats. **All historical pool-mode validation of
"DE v2 + Humbaba" is void** and must be re-run.

**Roster interaction (important):** every point of pressure removed from Odradek
gets absorbed by Kroni and Humbaba, who rose to ~70% and ~62% in his absence.
They were always that strong; Odradek was suppressing them. Expect to re-check
both after any Odradek change.

**Starred, deferred:** Valak (~24–30% across every config) and Deimos (~19–25%,
immovable across all six levers — a strong hint his problem is doctrine, not
kit). Kalligan and Kanifous show pool-only weakness (34%, 33%) invisible in lock.

---

## Step 3 — The re-validation regime (permanent instruments)

**Dual-mode gates.** Every balance run in *both* pool and lock. They disagree
sharply and routinely — Odradek reads 88% lock / 54% pool; Kalligan reads fine in
lock and 34% in pool. Neither substitutes for the other.

**Section 10 asymmetry check** as a standing gate: flag any Lord over ~85%
single-action share; flag avg spread under ~8 pts as a reskin signature.

**Tools built this cycle (keep them):**
- `branch_coverage.py` — audits rare-branch firing across a seed set; `--hunt
  <branch>` searches for a seed forcing a dark branch. **Result: all 10 branches
  fire; seed 2052353491 covers every one.**
- `attack_diag.py` — attack profitability: kill%, whiff%, near-miss band,
  overcommit. **Key numbers: 79.9% kill rate, 3.9% near-miss, 3.1 average
  overcommit past the wall.**
- `degenerate_test.py` — forces pure single-action policies and measures win
  rate. **Use the pure-vs-pure matrix as the core metric**, not pure-vs-doctrine;
  the latter is contaminated by whatever the bot happens to be bad at.

---

## Step 4 — Phase 2: the loop on screen

Wire human input into one seat; the proven bots take the other. Build targets in
order: the commitment interaction (the Tell System spec's section 12 flags that
commit UX — discrete confirm vs single tap — must be decided *before* the loop
locks), the simultaneous reveal as a staged suspenseful beat, and three clocks
legible enough that telegraphing works on a human the way the fairness metrics
assume.

The softmax selection layer ships here with temperature as the difficulty dial —
built aware it is also the tells foundation and the boss-identity foundation.

### 4a — UI built in code, guarded by layout invariants (not golden images)

**Decision: build the UI in code, not by hand-anchoring in the editor** — and
because it's code, apply harness discipline. But test *layout invariants*, not
pixels.

Pixel snapshots catch *regressions*, not *bugs* — a snapshot test blesses
whatever the first run produced, so a day-one mistake gets enshrined green.
They're also brittle in the wrong direction (antialiasing, font hinting, driver
updates all red an exact diff while being visually irrelevant), which trains you
to ignore the suite. And they need a stable target — pre-Phase-2 UI is the least
stable code in the project by design.

Code-built layout has an oracle that pixel-blessing lacks: **math.** Assert
computable truths from first principles — no two cards overlap; every card sits
inside its container; N slots evenly spaced (`slot[i+1].x - slot[i].x` constant);
the reveal panel is centered; nothing off-screen at any supported resolution.
Make them **property tests across the input range** (any hand size 0–10, any
castle count, any resolution), not single cases — the same move as the
`total == 60` card-conservation assertion, which caught a *class* of bug.

Boundary: invariants prove the layout is *structurally correct*. They cannot
prove it's *good* — pleasing spacing, a reveal that lands, readability under
pressure. Those stay human.

**`@tool` scaffolding.** Godot `@tool` scripts run in the editor and materialize
real, inspector-editable nodes — code-driven generation *plus* hand tuning. Use
as a **generate-once scaffolder** for the static shell. Never run a *persistent*
tool script that owns a subtree you also hand-edit; that's the classic footgun
that stomps edits and bloats `.tscn` files.

The seam: **code owns "where things go and what shows"; the editor owns "what it
looks like and how it moves."** Containers are code-owned and positioned;
contents are hand-authored children (`owner` set so they serialize) or
runtime-instanced card scenes. Stock `Container` types already do
resolution-reactive layout live in the editor — custom code only where they fall
short. Guard all tool-time paths with `Engine.is_editor_hint()`; never touch
runtime state (GameState, autoloads) from tool code, or it null-crashes in the
editor.

Sequencing guardrail: **write each invariant in the same sitting as the layout
function it guards.** Accrete; never retrofit a suite. Defer any pixel layer
(tolerant perceptual threshold, not exact match) until after Phase 2 proves the
loop and the UI stops moving.

---

## Horizon (pointers only)

Async backbone (commit-reveal protocol), roguelike solo spine with per-Lord boss
identities, then the Read/tell system — parked, gated on a proven-fun loop and
repeated-opponent data. Soundtrack direction noted and deliberately deferred
(reference palette: ISN / raison d'etre; adaptive Veil-bed architecture, not
per-Lord album tracks).

---

## Standing disciplines

Diagnose before acting. Titrate — one lever per run. Two axes (`SIM_VERSION` /
`AI_POLICY`), versioned separately, moved atomically with their traces. Read the
checkpoint *sequence*, not the field name. Verify the instrument before trusting
the result — and when a result is impossible (byte-identical games across a rules
change), believe the impossibility, not the result. Green means validated
*trajectories*, not validated code: coverage is a separate claim. Test the
invariant, not the instance — assert the computable rule across the input range,
never bless a single recorded output. Write the guard in the same sitting as the
thing it guards.

**New this cycle:** *Structural questions get vanilla answers.* Kit-loaded
measurements hid a base game that timed out 75% of the time and had an
unreachable win condition. Never diagnose structure on the real roster.

**Also new:** *Deterministic mirrored bots produce correlation artifacts.* Two
copies of the same policy make correlated decisions from shared state, which can
inflate a conditional rate to near-certainty (the 97.7% Profane denial). Check
whether a surprising rate is a rule or a correlation before designing against it.
