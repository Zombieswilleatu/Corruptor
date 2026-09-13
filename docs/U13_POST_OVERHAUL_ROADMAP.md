# CORRUPTOR U13 — POST-LORD-OVERHAUL PROGRESSION PLAN

**Status:** Working roadmap / engineering addendum
**Date:** 2026-09-10

**2026-09-13 resumed simulation work:** The Windows submission performance gate
passed on `5b7dffbb`: 317 checks, 176 exact hooks, no failures. A fresh local V3
campaign completed nine wins in 146 rounds, no caps/failures, with 20/23 active
powers used. Directed fixtures cover the three absent powers. V4 addresses the
observed construction switching by keeping an active project focused while
retaining Repair and commissioning choices. See
`U13_DOCTRINE_COVERAGE_2026-09-13.md` for scope and the new fixture-only command.
Next acceptance is the short Windows doctrine fixture gate. The V4 seed 19
diagnostic exposed repeated Ward versus ineffective Siege and was deliberately
stopped during round 28; keep that longer-game regression as the next directed
case, using only public observations. Keep the larger throughput work
for PySim and the Action Window / Resolution Theater as a later milestone.

The uploaded earlier random-legal summary completed 100 games: 92 wins, 8 censored
at the round cap, zero failed/missing. Its own `gate_passed` is false because of
the capped games; it is neither current V3 balance evidence nor a clean full-win
gate. The playable build has since been exercised in two uploaded Windows games.

**2026-09-13 playable steering:** User clarified that the requested next runner
is a visible human-versus-doctrine game. `run_u13_playable.sh` now connects the
existing board to the production conductor, human draw/Slaver choices, complete
sealed plans, Tear rites, save/load and terminal victory. Doctrine V3 also fixes
Odradek saving and Kanifous wish valuation. Local engine and widget checks pass;
See `U13_PLAYABLE_RUNNER.md` for the subsequent Windows feedback and fixes. Keep the
Action Window / Resolution Theater and Action Forecast work as later milestones.

**2026-09-12 doctrine steering:** User authorized an early, bounded common planner
and Tier 1A targeting now, using the originating Astra handoff/Implementation Plan
v3 and individual ideas from legacy doctrine. Do not port the old Smart Core.
The `u13-basic-doctrine` branch adds a short simulation loop with explicit fast
versus independent replay scope; do not wait for the running 100-game campaign
before developing this pass. See `U13_BASIC_DOCTRINE_2026-09-12.md`.

**2026-09-12 steering:** Veil threshold effects and automatic drift are disabled
pending a dedicated design pass. Keep Tear accumulation and Lord Breach powers.
Victory resolution is now implemented after Aftermath; see
`U13_VICTORY_2026-09-12.md`. Next: autonomous matches through real termination
and the remaining candidate coverage audit. The separate 100-game runner is
now available in `U13_FULL_MATCH_BATCH_2026-09-12.md`; Windows batch acceptance
is pending.
This decision supersedes references below to implementing Veil effects before
the full-game and playable-UI milestones.

## Next engineering priority: simulation performance

User steering: the slow batch was canceled for a targeted performance pass.
Multi-hour batches are not acceptable as the routine test loop. Do not require
another 100-game run for every change. Keep extensive throughput work for the
later PySim parity rebuild.

Before the next large campaign:

- Profile legal-plan generation, ordinary resolution/Marching, snapshot encoding
  and restoration, and complete-state/history comparisons separately.
- Measure growing event-history cost and compare one versus four workers using
  the same seeds and runtime. Separate per-game CPU cost from wall-clock contention.
- The uploaded round-7 checkpoint confirmed expensive power previews and history
  copying. The targeted fix removes redundant temporary order transactions and
  entity copies; batch mode omits position samples. Full-trace gameplay state and
  plans match the prior implementation; compact/full gameplay also matches.
  See `U13_SIM_PERFORMANCE_2026-09-12.md` for evidence and scope.
- Establish a fast targeted regression loop and a separate lightweight simulation
  throughput benchmark. Keep the full 100-game replay batch as an occasional
  integration gate, with explicit scope for each tier.
- Record before/after timings, hardware/runtime, game rounds and validation scope;
  select practical time budgets from measurements rather than inventing a target.

This bookmark does not authorize replacing correctness checks with approximate
comparisons or declaring capped games victories. Veil effects and drift stay off.

## 1. Immediate Objective

Once all nine Lords are mechanically complete, the next goal is:

> **Make U13 capable of autonomously playing an entire legitimate match from setup to victory.**

The work should proceed in this order:

1. Full U13 game runner
2. Full-game Random-Legal bot
3. Full playable U13 runner/UI
4. Action Window + Resolution Theater presentation pass
5. U13 Action Forecast
6. PySim parity rebuild
7. Smart Core doctrine rebuild
8. Serious balance campaign
9. Roguelite/meta-progression layer

---

## 2. Full U13 Game Runner

Wire the existing U13 systems into one complete authoritative match.

Required systems include:
- opening setup / deal
- normal round draws
- Development
- Construction / Commission / Repair / Reconstruction
- duplicate Castle support
- shared Castle Guard zone
- Siege / Ward / Hunt
- Pillage where applicable
- Lord Banishment and resummoning
- Vacant Throne behavior
- waiter support
- waiter-to-personal-Tear spending
- Souls, personal Tears, Neutral Tears
- Veil accounting; threshold effects and automatic drift disabled pending redesign
- Dominion / victory
- Castle picker/loadout state
- complete save/load and replay

**Acceptance:** setup → rounds → submissions → combat → Marching → Veil/victory, with no fixture intervention.

---

## 3. Full-Game Random-Legal Bot

Before teaching the bot to play well, make it capable of always producing a **complete legal submission**.

It must handle:
- combat action and commitments
- Castle action
- Construction / Commission / Repair / Reconstruction
- Lord powers and targets
- spatial targets
- resource payments
- waiter spending
- resummoning
- every other required round choice

Random-Legal exists for reachability and stability, not balance.

**First serious gate:** 100–1,000 complete games with:
- no crashes
- no deadlocks
- no illegal prompts after submission lock
- no orphaned pending effects
- deterministic replay
- legitimate game termination

---

## 4. Full Playable U13 Runner / UI

Once the authoritative game runner is stable, connect it to the actual board.

The UI must use the same authoritative legality and submission path as bots and tests.

Goals:
- human vs bot full matches
- all nine Lords
- Castle picker
- duplicate Castle rules
- Construction / Commission states
- Lord targeting
- Marching visuals
- persistent effects
- Veil and victory flow
- complete save/replay

At this point U13 becomes **the game**, not a collection of subsystem runners.

---

---

## 4A. Presentation Pass — Action Window / Resolution Theater

The next phase should also deliberately restore the presentation layer that made the playable build feel like a game rather than only an authoritative simulation.

These systems are **not blockers for mechanical correctness**, but they should be included in the immediate post-overhaul phase rather than deferred indefinitely.

### Existing reference systems

Relevant existing presentation code includes:

```text
Prototype/UI2/ActionZone.gd
Prototype/UI2/ResolutionTheater.gd
Prototype/U13/U13ActionZone.gd
```

These should be treated as presentation references and reusable components where appropriate, not as alternate authorities for gameplay rules.

### Action Window

Restore the Action Window as the primary presentation surface for:
- selected action
- target
- committed cards
- projected/forecast pressure
- Lord-power additions that materially modify the action
- submission state / confirmation
- concise explanation of what the player is attempting

The Action Window should consume authoritative U13 state and legality. It must not invent or own game rules.

It should integrate cleanly with the planned `U13ActionForecast.gd` so that Hunt/Siege/Pillage odds can be shown in the same place the player is making the decision.

### Resolution Theater

Restore the Resolution Theater for important resolved confrontations.

Its job is presentation, not simulation.

It should visualize major events such as:
- Hunt resolution
- Siege resolution
- Guard clashes
- Lord confrontations
- significant Castle attacks
- other high-value battle moments where a focused presentation improves readability

The underlying result must already be decided by the authoritative U13 engine. The theater receives a resolved event/result package and plays the corresponding visual sequence.

### Architectural rule

> **Authority resolves first. Presentation observes and dramatizes second.**

Neither the Action Window nor Resolution Theater should be able to change the authoritative result.

This separation is especially important in U13 because:
- all submissions are locked before resolution,
- replay must remain deterministic,
- Marching and Lord effects may resolve through multiple authoritative hooks,
- presentation timing should never affect gameplay timing.

### Scope for the next phase

The initial goal is not final polish.

A successful first pass only needs:
- Action Window wired to real U13 submission state,
- Resolution Theater receiving and displaying real U13 resolution packages,
- clear handoff between authoritative resolution and presentation,
- no duplicated combat logic,
- no blocking prompts after submission lock,
- replay-safe presentation triggers.

Once those are functioning, animation quality and dramatic polish can continue incrementally.


## 5. PySim Rebuild

Update PySim only after the U13 battle rules stop moving rapidly.

> **Godot U13 = authoritative implementation.**
> **PySim = fast behavioral mirror for large-scale testing.**

PySim should mirror only outcome-relevant mechanics, not UI/presentation.

### Parity before balance

For identical seeds, setups, and submissions, Godot and PySim should agree on:
- Marcher creation and IDs
- movement/contact
- combat and kills
- Guards
- Castle state
- Lord state
- Souls
- personal/Neutral Tears
- Veil
- power outcomes
- winner

Maintain approximately **50–100 deterministic reference games** that both engines reproduce exactly before trusting PySim for balance work.

---

---

## 5A. Player-Facing Action Forecast / Success-Chance System

U12 already had a useful player-facing forecast layer in:

```text
Scripts/Sim/ActionForecast.gd
```

That system exposed modeled **Hunt** and **Siege** outcomes before commitment through functions such as:

```text
forecast_hunt(...)
forecast_siege(...)
forecast_all(...)
```

It was more than a simple attack-versus-defense percentage. The U12 forecast model accounted for hidden Guard uncertainty, opponent hand size / Ward possibility, commitment depth, and other public information to present the player with an estimated chance/pressure picture before choosing an action.

### U13 direction

Do **not** directly port the old implementation unchanged.

Instead, build a clean U13 equivalent after the full authoritative match loop is wired:

```text
U13ActionForecast.gd
```

The U13 forecast should:

- read from the same authoritative public-state representation used by the playable UI and bot doctrine,
- respect the one-complete-submission-per-round structure,
- never reveal hidden information,
- model current U13 Hunt/Siege/Pillage legality,
- account for U13 Guards, Ward, waiter support, Lord modifiers, Castle state, and other relevant known effects,
- present success likelihood / pressure estimates before submission lock,
- remain non-authoritative: it advises the player but never resolves gameplay,
- be deterministic for the same visible state and forecast assumptions,
- expose its calculations in a form that can also be reused by Smart Core.

### Architecture relationship

The forecast layer should become a **shared analysis service**, not UI-only code.

That means:

> **Playable UI uses it to show the player estimated success chances.**
> **Common Smart Core uses the same underlying forecast information for decision scoring.**

This prevents the human UI and bot from maintaining separate interpretations of combat odds.

The old U12 `ActionForecast.gd` should be treated as a valuable reference for proven modeling ideas, just like the old Smart Core: **reuse the useful logic and assumptions that remain valid, but rebuild against U13's authoritative rules and public-state boundaries.**

### Recommended timing

Implement this after the full U13 game conductor and Random-Legal path are stable, and before serious Smart Core tuning.

Suggested sequence:

> full game conductor → Random-Legal full matches → playable U13 → **U13 Action Forecast** → PySim parity → Smart Core doctrine


## 6. Smart Core: Rebuild Architecture, Reuse Proven Ideas

Do **not** port the old Smart Core architecture wholesale.

Too much changed in U13:
- one complete locked submission
- new Lord timing
- spatial Marching
- duplicate/commissioned Castles
- new waiter economy
- new Veil/Tear routes
- persistent effects

However, the old Smart Core remains valuable as a source of proven heuristics:
- card valuation
- combat commitment valuation
- Siege vs Ward reasoning
- Hunt valuation
- target scoring
- forecast shortcuts
- deterministic tie-breaking
- risk evaluation

**Reuse ideas, not the old monolith.**

---

## 7. Recommended Bot Architecture

### Tier 0 — Safe Legal Fallback
Always produces a legal submission.

### Tier 1 — Random Legal
Deterministic random choice among legal complete submissions.

### Tier 2 — Common Smart Core
General Corruptor intelligence independent of Lord identity.

Recommended files:

```text
U13BotPolicy.gd
U13CommonDoctrine.gd
U13CombatDoctrine.gd
U13CastleDoctrine.gd
U13VeilDoctrine.gd
```

Responsibilities:
- `U13BotPolicy`: orchestrates one complete submission
- `U13CommonDoctrine`: scoring utilities, card value, risk, tie-breaking
- `U13CombatDoctrine`: Siege/Ward/Hunt/commitments
- `U13CastleDoctrine`: build/repair/commission/reconstruct/composition
- `U13VeilDoctrine`: waiter spending, Tears, Dominion, Veil pressure

---

## 8. Separate Lord Doctrine Files

Each Lord gets its **own doctrine module**.

Recommended structure:

```text
U13LordDoctrineRegistry.gd
U13GremoryDoctrine.gd
U13DeimosDoctrine.gd
U13HumbabaDoctrine.gd
U13KalliganDoctrine.gd
U13OriasDoctrine.gd
U13OdradekDoctrine.gd
U13ValakDoctrine.gd
U13KroniDoctrine.gd
U13KanifousDoctrine.gd
```

Lord doctrine should evaluate decisions only. It must not execute mechanics or mutate authoritative state.

Typical responsibilities:
- `score_power(...)`
- `choose_targets(...)`
- `score_spatial_region(...)`
- `score_combination(...)`
- `adjust_submission_score(...)`

All legality continues to come from the same authoritative system used by humans and Random-Legal.

### Why this matters

Per-Lord modules prevent a giant `if lord == ...` doctrine file and make it possible to compare:
- Common Smart Core + random Lord behavior
- Common Smart Core + Lord Doctrine v1
- Common Smart Core + Lord Doctrine v2

This helps distinguish **a weak Lord** from **a bot that does not understand the Lord**.

---

## 9. Serious Balance Campaign

Balance work begins only after:
- full U13 game loop is stable
- Random-Legal survives large batches
- PySim parity is established
- Smart Core can play every Lord competently

Recommended analyses:
- all 81 ordered Lord matchups
- crossed seats
- thousands/tens of thousands of seeds
- Castle composition tests
- duplicate-Castle strategies
- Commission timing
- waiter threshold sweeps
- Veil timing
- cooldown/radius/damage parameter sweeps
- Kanifous Price weights
- Orias Web tuning
- Valak Gravity Orb tuning
- Kroni Hunger sustainability
- Kalligan Scorch tuning
- Deimos artillery pressure
- Humbaba survivability
- Odradek doctrine skill ceiling
- power-ablation tests

**Random-Legal proves reachability. Smart doctrine + PySim provides balance evidence.**

---

## 10. Recommended Order After Lord #9

1. Full U13 conductor
2. Full Random-Legal policy
3. 100–1,000 complete Godot games
4. Full playable human-vs-bot U13
5. Wire Action Window + Resolution Theater to authoritative U13 events/state
6. Build U13 Action Forecast
7. Freeze a mechanical checkpoint
8. Update PySim
9. Prove Godot ↔ PySim parity
10. Build Common Smart Core
11. Add one Lord doctrine at a time
12. Run the serious balance campaign
13. Build roguelite/meta progression

---

## 11. Roguelite Layer Comes After the Trusted Battle Core

The roguelite wrapper should build on the completed battle game.

Current direction:
- about five Lords per run
- start weaker than the fully unlocked base game
- progression restores options rather than stacking permanent stat bonuses
- Lord powers can be unlocked
- Castle blueprints can be unlocked
- special Marcher recipes can be unlocked
- approximately 10 special Marcher recipes, with 1 starter and ~9 later unlocks
- fully progressed account eventually reaches the complete battle ruleset

---

## 12. Next Major Milestone

# FULL U13 AUTONOMOUS MATCH

A Random-Legal match must be able to:

1. initialize a legal setup
2. choose complete submissions
3. resolve every round
4. use all base systems
5. interact with all Lord systems
6. save/load deterministically
7. reach a legitimate victory condition
8. finish without manual intervention

When this is green across a large batch, U13 has crossed from:

> **Lord-overhaul architecture**

to:

> **complete game architecture**
