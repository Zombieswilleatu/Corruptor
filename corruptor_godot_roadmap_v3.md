# CORRUPTOR — Godot Development Roadmap v3.0
**Supersedes v2.0 · Multiplayer-at-heart, async-backbone · Reflects current progress (round-loop port underway, golden harness green)**

---

## 0. What Changed Since v2.0

v2.0 treated the game as campaign-first with multiplayer as a demoted afterthought (old Phase 7, vague). That framing is now corrected:

1. **Corruptor is a multiplayer game at heart.** The 2-player asymmetric bluffing duel is the core product. The roguelike campaign is the on-ramp, the solo option, and — critically — the thing the player still owns when no human is available.
2. **The two modes cover each other's mortal weaknesses.** The roguelike's ceiling risk (AI reads can eventually be pattern-matched) is cured by human opponents, who never stale. Multiplayer's death risk (player-liquidity collapse — the exact failure that killed digital Yomi/BattleCON) is cured by a *complete, satisfying standalone roguelike*, so a quiet lobby is never a dead product. This reciprocity is the core commercial thesis.
3. **Async is the multiplayer backbone**, not realtime. Commit → close app → notified on reveal. Multi-game carousel (Words With Friends model). Async defuses liquidity because nobody waits in a lobby; it fits the game's simultaneous-reveal loop better than realtime (the delay *charges* the reveal); and its commit-reveal-hash protocol needs almost no server-side game logic, making the backend hobbyist-cheap. Realtime is a bonus for friends online together, never the backbone.
4. **Build order is still solo-first** — for engineering reasons, not product reasons. You prove the engine with bots (validated by the golden harness), then wire human input, then wire async. The order you *build* and the thing the product *is* are different axes, exactly as engine-before-UI.
5. **Progress since v2:** the golden-master harness is built and green (20 cross-language traces), the sim is versioned (SIM_VERSION 6.0 / AI_POLICY, two independent axes), `game:deal` parity is proven, and the round-loop port is underway (mid Reflex-Bid). Phases 0–1 are largely done; this roadmap reflects that.

---

## 1. The Product, In One Breath

A 2-player asymmetric bluffing duel — sealed orders, simultaneous reveal, deterministic resolution — delivered three ways that reinforce each other:

- **Async multiplayer (the heart):** correspondence-style duels against humans. Infinite replay; humans never stale. The mode the whole design is centered on.
- **Roguelike campaign (the on-ramp + solo spine):** climb a ladder of AI Lords, each a boss that bluffs. Complete and satisfying on its own so that a quiet multiplayer lobby is never a dead product. Also the teacher that hands players to multiplayer once they've mastered the reads.
- **Realtime multiplayer (the treat):** for two friends online at once. Explicitly not the backbone the playerbase is bet on.

Pitch line: **"An eldritch abomination simulator you play with friends — a roguelike where the bosses bluff."**

---

## 2. Architecture

```
┌────────────────────────────────────────────────────┐
│ PRESENTATION (Godot scenes)                        │
│ table · cards · reveal choreography · run map ·    │
│ harvest report · match carousel · meta screens     │
└──────────────▲─────────────────────────────────────┘
               │ Events / Actions
┌──────────────┴─────────────────────────────────────┐
│ SIMULATION (headless GDScript — THE canon)         │
│ GameState · round loop · combat layers · EventBus  │
│ (9 timing windows) · Lord ability listeners ·      │
│ RuleConfig (= Python VARIANT; DE v2 default)       │
└──────────────▲─────────────────────────────────────┘
               │ same API, deterministic, serializable
┌──────────────┴─────────────────────────────────────┐
│ AGENTS & MODES                                     │
│ Boss AI (versioned) · campaign run manager ·       │
│ meta store · hotseat · ASYNC NETCODE (commit-      │
│ reveal hash) · realtime · replay                   │
└────────────────────────────────────────────────────┘
```

**Load-bearing rules (unchanged, now doubly important because async depends on them):**
- Sim layer is pure GDScript, zero scene dependencies, `(GameState, Action) → (GameState, EventList)`, fully serializable. Serializability is what makes saves, replays, AND async netcode all free — the same snapshot the golden harness validates is the packet async sends.
- **The sim runs identically client-side.** Async needs no server-side game logic — the server escrows two commit-hashes, verifies a reveal, relays state, fires notifications. That's the whole backend.
- RuleConfig mirrors the Python VARIANT 1:1; DE v2 is default. Campaign modifiers (Breach stacks, boss abilities, rank handicaps) are config-layer, never kit edits.
- AI is versioned (`AI_POLICY`). Balance data is invalid across policy versions (Law 5).

---

## 3. Phase Plan

Part-time (~10–15 hr/wk), AI-assisted. Each phase ends in a gate. Phases 0–1 reflect real current progress.

### PHASE 0 — Audit & Retrofit ✅ substantially complete
Scaffolding sorted into `/sim`, `/ui`, `/agents`, `/data`, `/campaign`. GameState + EventBus + RuleConfig in place. Card/castle/9-Lord tables ported as data. Campaign shell runs on evented fake resolution.

### PHASE 1 — Headless Rules Engine + Golden Harness ⏳ underway
Full DE v2 rules behind the fake resolver, validated as each piece lands.
- **Golden-master harness: DONE and green** — 20 cross-language traces (combat layers, sigils, Humbaba defense/seal/gate, Development-phase ordering, deploy restrictions, Dominion rites). `game:deal` parity proven.
- **Round loop: in progress** — Reflex Bid → Commitment → Reveal → Resolution being ported, each phase golden-validated.
- **Remaining Phase 1 gate:** a full fixed-seed bot-vs-bot game reproduces the oracle's terminal state (`game:end` trace green). That single green trace proves the *entire* engine, not just its pieces. **Finish the loop bot-vs-bot before wiring any human input** — so a divergence is unambiguously a rules bug, not an input bug.

### PHASE 2 — Human Input + Hotseat "Does It Sing?" 🎯 the whole ballgame
Replace one bot seat with human input; make the reveal visible and suspenseful.
- Card commit UI (the genuinely new code — the sim *decided*, the game must *ask*), privacy screen, simultaneous reveal choreography, resolution playback with combat-math readout.
- The AI opponent is *free here* — the debugged bots become the other seat.
- **Gate:** 10+ human games (hotseat). Does the commit/reveal loop generate tension between two humans? **Note the reframed, lower risk:** hidden-commitment bluffing is a *proven-fun* engine in human-vs-human (that's why the tabletop games exist). You're proving a known-fun loop survives digitization, not inventing one. Fail → diagnose reveal/pacing/info-display before proceeding. Sunk cost at this gate: ~3 months.

### PHASE 3 — Boss AI, Tier A
Port the sim's heuristic AI (60% translation of debugged doctrine, incl. chip/alternating lines). Per-Lord personality *tells* on top of competence — bosses should be learnable and slightly exploitable on purpose ("the bosses bluff" is the hook; the tells are the content). Tutorial AI = Prologue waves, readable.
- **Gate:** designer-blind player reports each Lord "feels like a different opponent" across 5 games.

### PHASE 4 — THE RUN (campaign core)
A single climb, no meta-persistence yet.
- **Run structure:** accept a patronage (pick an unlocked Lord) → climb 4–6 boss Lords (draft order varies) → Humbaba as the final wall.
- **Within-run persistence (push-your-luck spine):** castle damage carries between fights (repairs cost banked Souls); the Veil runs across the *whole* climb (Cataclysm mid-run ends it — "one more fight before the world ends"); **Breach stacking** — every fallen boss's Breach stays active for the rest of the run (the lore's rules-mutation text, implemented literally; all RuleConfig layers).
- **Boss-layer abilities** enter as config modifiers (Humbaba's final-boss form gets Withdraw Behind the Gate + World-Turtle shells + stacked handicaps — diegetically unfair, kit untouched).
- **Gate:** a full run is completable and losable; 45–90 min; playtesters *voluntarily start a second run*.

### PHASE 5 — META-PROGRESSION ("one more run")
Law: **breadth and knowledge, never bought power** (StS/Balatro model; protects the multiplayer kits for free since nothing touches them).
- **Souls = tribute** (currency; every failed run pays — spent on unlocks, never stats).
- **The Veil = world odometer** (persistent across all runs; `WORLD INTEGRITY: DECLINING` is a real number; milestones unlock world-states and the campaign terminus).
- **Boss-defeat unlocks that Lord as playable** — curated ladder (Gremory-class opener → hunters → the weird ones → Humbaba as final unlock). Each unlock lands on a player who now understands the game well enough to appreciate what's different.
- **Five unlock systems, all reusing shipped mechanics:** Lords (patrons who've noticed you) · Castle blueprints (relic loadout) · Rites (unlockable verbs) · Signature Subjects (recruitable cards) · Mastered Breaches (the single sidegrade-shaped power lever).
- **Designation rank ladder** (Subject → Vessel → Corruptor → Lord → Cataclysm) as ascension.
- **The harvest report** carries the game's cold tone at every run boundary.
- **Gate:** blind playtester plays 5+ runs unprompted, can articulate what they're working toward.

### PHASE 5.5 — THE PROLOGUE ("The First Rite")
A distinct, scripted, unwinnable ~5–10 min opener. **You are Aldric**, powerless, working the rite against **Kanifous**, who idly unmakes it — teaching the verbs from the receiving end. Ends on the scripted beat: *"Where is my wife, you monster!"* → the cold snap → the Breach. His destruction *is* the first cause of the game; the next vessel's power is the consequence.
- Its own `PrologueRun` type (fixed boss, fixed loss, scripted terminal beat — almost nothing procedural). Built after the run/meta systems exist because it *reskins* them into a scripted sequence.
- **Gate:** a new player finishes it in <10 min, loses, and *understands the verbs* — measured by how they open their first real run.

### PHASE 6 — Presentation & Juice
Commissioned art (9 Lord portraits, castle pieces, suit iconography, run-map — brief from the narrative bible, $8–20k). Reveal choreography as the emotional core. Banishment/Breach/Veil ambience + sound. Tutorial = Prologue. Keyword tooltips, combat-preview calculator, full log, undo-before-commit.
- **Gate:** a stranger installs, finishes the Prologue, wins a Prologue-rules fight vs AI, starts a run — zero help. Every confusion is a ticket.

### PHASE 7 — ASYNC MULTIPLAYER (the heart, built last for engineering reasons)
Now a first-class pillar, not a demoted afterthought.
- **Commit-reveal hash protocol:** each client submits `hash(sealed_commitment + salt)`; both hashes land; both reveal; server verifies against the hash. Trustless simultaneity — nobody sees the other's orders early, nobody can change theirs after, no server-side game logic. The sim runs identically client-side; the server only escrows hashes, verifies reveals, relays state, fires notifications. Backend is hobbyist-cheap.
- **Async-first / multi-game carousel:** the Words With Friends retention engine. "Your reveal is ready" notifications are the engagement loop. A player with 3–6 games in flight always has a move, opens the app daily, keeps the whole graph warm on a fraction of realtime's concurrency. **This is the mechanism that defuses liquidity** — the exact death that killed this genre's ancestors.
- **Persistence implication (bank this early — see §5 note):** the model must support *many concurrent games per player*. A lightweight "my active contests" list (renders the carousel — "Deimos, reveal ready") sits separate from deep per-match state (loaded on open). Anticipate this in the save layer now, not as a retrofit.
- **Loose matchmaking is fine:** async lowers the emotional cost of a game to a 30-second move in a grocery line, so "start a game with a random opponent" is nearly free and a skill mismatch is just a game you win/lose slowly over a week — no tight realtime skill-queue needed. Relaxes both liquidity *and* matchmaking engineering.
- **Abandonment/timeout policy (the one async-specific design question):** async's dark side is the game that dies because someone stops taking turns. Needs a humane resolution — grace period → nudge notification → non-punishing timeout forfeit. Decide the *feel* before it's a support complaint.
- **Realtime mode:** a thin bonus layer on the same commit-reveal core for two friends online together. Not the backbone.
- **Gate:** 20-game closed async test across real networks, zero desyncs; the carousel loop feels alive with only a handful of testers (proving the liquidity thesis).

### PHASE 8 — Beta & Ship
Closed beta (50–200 keys), telemetry consent, funnel analytics. Balance cross-checked human-vs-Python-lab (the lab keeps running as the design tool; Godot telemetry feeds questions back into overnight Python grids). **Next Fest demo = the Prologue** (a tight, authored, emotionally-loaded 5-minute cold open is a genuine wishlist weapon most card roguelikes lack). Devlog running since Phase 4.
- **Launch scope:** async 1v1 (the heart), roguelike campaign (9 bosses, meta-progression, rank ladder), the Prologue, hotseat, realtime 1v1, tutorial.
- **Post-launch, pre-ordered:** ranked ladder · new Lords (DLC-shaped by the data pipeline) · 2v2 · leakage narrative arc · mobile (async + touch is a natural fit — the WWF model *is* mobile).

---

## 4. Timeline & Spend

| Milestone | Cumulative (part-time) | Cash |
|---|---|---|
| Rules engine + golden harness (P0–1) | **~now** | $0 |
| Human input + fun-test hotseat (P2) | ~1 month from now | $0 |
| Boss AI (P3) | ~2.5 months | $0 |
| First full run (P4) | ~5 months | $0 |
| Meta + Prologue (P5–5.5) | ~7.5 months | $0 |
| Art & polish (P6) | ~10.5 months | $8–20k |
| **Async multiplayer (P7)** | ~13 months | $0–15k (cheap backend; relay + notifications) |
| Ship (P8) | ~16 months | +$100 Steam |

Full-time roughly halves it. Nothing mandatory is spent before the P2 fun gate. Async's cheap backend is a direct consequence of the commit-reveal architecture — the design-optimal choice is also the cheapest to run.

## 5. Risk Register (delta from v2)

| Risk | Mitigation |
|---|---|
| **Player-liquidity collapse (the genre-killer)** | Async multi-game carousel defuses it (no lobby waiting); AND a complete standalone roguelike means a quiet lobby is never a dead product. The reciprocal structure IS the mitigation. |
| Bluffing loop doesn't survive the screen | P2 gate — but risk is *lower* than v2 assumed: human-vs-human bluffing is proven-fun (tabletop precedent), not novel. |
| AI reads pattern-matched / stale at high end | Cured by multiplayer (humans don't stale); roguelike breadth (9 Lords × stacked Breaches) carries solo replay, not the bluff alone. |
| Async abandonment (games that die mid-turn) | Humane timeout policy (grace → nudge → non-punishing forfeit); decide the feel early. |
| Bot-policy drift invalidating balance data | `AI_POLICY` version on every run; Law 5 institutionalized. |
| Persistence not built for many concurrent games | Bank the "active contests" vs "deep match state" split now (§P7); anticipate N games/player. |
| Run length (45–90 min) long for genre | P4 gate measures; levers: shorter ladders, mid-run saves, expedition short mode. |
| Solo-dev burnout | P2 and P4 each end in a complete playable thing; devlog audience as accountability. |
| Discovery (the true final boss) | Prologue-as-demo wishlist weapon; devlog from P4; "roguelike where the bosses bluff" hook. |

## 6. Standing Questions (thinking queue, not blockers)

1. Async abandonment/timeout *feel* (decide before P7 backend).
2. Leakage vs airtight machine — the narrative fork (decide before P5 content).
3. Run ladder length & draft rules (P4 playtest question).
4. Campaign terminus scene — what kneels at the bottom (decide anytime; nothing upstream blocks).
5. Kroni's missing lore passage (narrative bible gap).
6. Humbaba–Odradek PvP hole (parallel Python-lab track; irrelevant to campaign since boss fights are one-sided).
