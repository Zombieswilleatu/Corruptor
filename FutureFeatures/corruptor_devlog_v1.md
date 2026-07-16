# Corruptor — Development Devlog & Methodology
**v1 · written mid-2026 · purpose: reproducibility for future me**

This is not a changelog. It records *how* Corruptor has been built and *why* each
step was taken, so that a version of me returning cold — or restarting a similar
project — can re-derive the approach rather than reverse-engineer it. The reusable
asset documented here is a method: **oracle-first, cross-implementation parity
development.** The game is the thing it was applied to.

Read §11 first if you only have five minutes — it's the distilled playbook.

---

## 1. Origin (≈ October 2025): a board game, balance-first

Corruptor began as a physical 2-player asymmetric bluffing card game — simultaneous
hidden commitment, deterministic resolution, no dice. The design commitment from the
start was that **balance mattered more than almost anything else**: nine asymmetric
Lords, three live victory clocks (Ritual / Dominion / Final Collapse), and a bluff
core that only works if no single line is dominant.

That commitment created the first problem. A game this asymmetric cannot be balanced
by intuition, and there was **no physical copy to playtest yet**. Hand-testing nine
Lords across every matchup, thousands of times, was not going to happen on a
tabletop.

## 2. The Python sim (`corruptor_sim.py`): balance as an oracle

The response was to build a simulator first, before a physical prototype. The reasons,
in order of weight:

- **No physical version existed**, so simulation was the only way to see matchup data
  at all.
- **Iteration was dramatically faster** in code — a rule change and a 400k-game
  re-run took minutes; the tabletop equivalent was weeks of unavailable playtesters.
- Balance is a **statistical** property. It needs sample sizes a human table cannot
  produce. The sim runs every Lord pairing tens of thousands of times and reports
  win-rates, win-condition distribution, tear economy, timeout/stall rates, and a set
  of "tension" and "telegraphing" metrics that ask not just *who wins* but *whether
  the win felt earned and legible*.

The sim grew to ~3,300 lines and became **the oracle** — the single source of truth
for what the rules *are*. Every rule, dial, and Lord ability is implemented there
first; the rulebook is downstream of it, not the other way around.

## 3. Two-axis versioning discipline (the most important habit)

Early on, a subtle bug in reasoning nearly corrupted the balance data: changing how
the *bots* play changes the win-rates just as much as changing the *rules* does, but
the two are completely different kinds of change. Conflating them makes balance data
meaningless.

The fix was to split versioning into two independent axes, and to treat them as
first-class:

- **`SIM_VERSION`** — the rules/dials axis. Bumping it invalidates golden-master
  traces (the rules changed, so the reference behavior changed). Currently `6.0`,
  codename "DE v2 + Humbaba."
- **`AI_POLICY`** — the bot-doctrine axis. Bumping it invalidates balance grids but
  *not* golden traces (the rules didn't change, only how the bots exercise them).
  Currently `heuristic-2025.06-doctrine`.

This is codified as **Law 5: a policy change is a balance change.** If you retune the
bots, you must re-run the balance grids, even though not a single rule moved. Keeping
these axes separate is what lets balance data accumulate meaning over time instead of
silently invalidating itself.

## 4. The design laws (hard-won constraints)

Balance iteration surfaced a set of recurring failure patterns, which were codified
as design laws so they wouldn't have to be rediscovered. The canonical list lives in
the **Design Companion**; the load-bearing ones:

- **Passive win-condition income must be deniable** — a clock that ticks no matter what
  the opponent does is un-interactive.
- **Stacks need decay** — anything that accumulates without bleeding off snowballs.
- **Balance polarization, not just means** — a 50% win-rate that's 50% of blowouts is
  not balanced; the *distribution* matters, not the average.
- **Both attack-doors can't be trapped** — if both the Hunt and Siege lines can be shut
  down simultaneously, the game locks.
- **Titrate fixes** — change one dial at a time and re-measure; multi-dial changes make
  causation unrecoverable.
- **Fix doctrine before kit** — if the bots play a Lord wrong, its win-rate lies; fix
  how it's played before you touch what it does.
- **(Law 5) Policy changes are balance changes** — see §3.

The last two are methodology laws, not game-design laws, and they are the ones most
worth internalizing: bad bot doctrine produces false balance signals, and forgetting
that policy is a balance axis produces false confidence.

## 5. The digital port: product framing

With the ruleset validated (DE v2 v2, ~400k+ simulated games), the project turned
toward a digital game in **Godot 4.2 (.mono)**. The product framing that shaped every
architectural decision after this point:

> **multiplayer-at-heart, async-backbone, roguelike-as-solo-spine.**

The two modes cover each other's weaknesses: async multiplayer defuses the
player-liquidity death that kills small multiplayer games, and a complete standalone
roguelike means a quiet lobby is never a dead product. This is a survival-floor
decision, not a ceiling one — it makes the game robust to low population rather than
more impressive at high population.

## 6. Architecture: the layer split

The single architectural rule everything else hangs on: **a pure, headless simulation
layer with zero scene dependencies**, structured as `(GameState, Action) → (GameState,
EventList)`, fully serializable. Around it, two other layers that may *not* leak into
it: presentation and agents.

The sim purity is not aesthetic. It is what makes the whole parity method possible —
a sim with no engine dependencies can be driven headlessly, serialized, and compared
against the Python oracle byte-region for byte-region. The moment presentation logic
leaks into the sim, that comparison dies.

`RuleConfig` (GDScript) mirrors the Python `VARIANT` dict **1:1**, defaulting to DE v2.
The rules exist in exactly one conceptual place, expressed twice, and the two
expressions are held identical by test.

## 7. The golden-master method (the reproducibility engine)

This is the core of the whole approach and the part most worth reusing.

The Python sim is the oracle. It emits **versioned JSON traces**: sequences of state
snapshots at named checkpoints (`game:deal`, `unit:after`, `game:end`, per-phase
markers). The GDScript sim **replays** the same seeded scenario and asserts
state-equality against each snapshot.

Two decisions made this robust rather than fragile:

- **Structural diff is authoritative, not hashes.** Godot and Python serialize JSON
  differently — int-vs-float representation and key ordering both differ. A hash of the
  serialized state would report divergence on cosmetic differences. So comparison walks
  the structure and compares fields.
- **Numeric comparison is type-tolerant.** `3` and `3.0` are equal for the harness's
  purposes everywhere *except* where bit-exactness is specifically required (see §9).

Artifacts: `golden_serializer.py` + `golden_master.py` (Python, emit + validate),
`GoldenMaster.gd` + `GoldenSnapshotSerializer.gd` (GDScript, load + replay + assert),
`GoldenTests.gd` (the test runner), plus a README.

## 8. Porting order: bottom-up, leaf-first

The port proceeds from the most primitive, most-tested mechanics upward, so that any
divergence is localized to the newest layer:

1. **Core combat** (`_combat_layers` — the Golden Rule: equality never destroys),
   proven in isolation with unit traces.
2. **Kit interactions** — sigils, per-Lord abilities (Hunt/Siege doctrine, Humbaba,
   Kroni, Gremory, Odradek, etc.).
3. **Round phases** — Development, Reflex Bid, Commitment, Reveal, Resolution, each
   validated against its own checkpoint.
4. **`game:deal`** — the seeded opening deal reproduces the oracle.
5. **`game:end`** — a full seed-1 bot-vs-bot game reaching the oracle's terminal state.

By the current point this is 81 golden tests passing, covering the entire round loop
and every kit interaction. `game:end` is the final Phase 1 gate.

## 9. The RNG problem and the runtime-parity decision

`game:end` requires a full game to unfold *identically* in both implementations. That
requires identical randomness. Two options existed:

- **Stream injection** — record Python's RNG outputs and feed them to GDScript.
- **Runtime parity** — reimplement Python's RNG algorithm in GDScript so both *generate*
  the same stream from the same seed.

**Runtime parity was chosen** — a full **Mersenne Twister reimplementation** in
`PythonRandom.gd` (backward Fisher-Yates shuffle, `_randbelow` via bit-length +
rejection, exact 53-bit float construction, `init_by_array` seeding). Runtime parity
is more work than injection but it's the correct choice: it makes the GDScript sim
*independently* reproduce the oracle rather than being spoon-fed its answers, which is
what you actually want for a shippable game whose RNG must match the balance model.

The risk: GDScript int64 must survive the Twister's multiplication overflows, and the
float construction must be bit-exact. This is where the harness's type-tolerance is
*suspended* — RNG parity demands exact equality, because an off-by-one-ULP Twister
passes an epsilon check and then desyncs a real game hundreds of draws later.

## 10. The raw-stream gate (proving the Twister before trusting it)

Before any game-level RNG test could be trusted, the Twister itself had to be proven
in isolation. The method: dump Python's `getrandbits(32)`, `random()`, `randint`,
`uniform`, and a `shuffle`, each from a **fresh** `seed(1)` (so a failure in one
stream can't cascade into another — clean localization), and assert `PythonRandom.gd`
reproduces each **bit-for-bit**.

Two refinements that matter:

- **Floats compared by IEEE-754 bit pattern (big-endian hex), not by value.** Dumping
  the raw uint64 would overflow int64 for negative doubles and corrupt on JSON parse;
  hex-string comparison sidesteps that entirely. The signed `uniform(-1000, 1000)`
  range is deliberate — it exercises the sign-bit path.
- **Diagnostic ordering, most-fundamental first.** `getrandbits(32)` is the purest
  core probe (one tempered word, no float math). If it's green, seeding + generation +
  tempering are proven. Then `random()` green isolates the 53-bit float assembly;
  `randint` isolates `_randbelow`; `shuffle` isolates Fisher-Yates order.

All five streams passed bit-exact. The Twister is proven.

## 11. THE PLAYBOOK (if you are picking this up cold)

The reproducible method, distilled. This is the part to copy for the next port or the
next project.

1. **Build a deterministic reference implementation and make it the oracle.** All rules
   live there first. Everything else is validated against it.
2. **Version rules and policy on separate axes.** Never let a policy change masquerade
   as a rules change or vice versa. (Laws 5, "fix doctrine before kit.")
3. **Keep the target's simulation layer pure and headless** — `(state, action) →
   (state, events)`, serializable, zero engine deps. This is the precondition for
   everything below.
4. **Mirror the rules config 1:1** between reference and target.
5. **Emit versioned JSON traces from the oracle; replay and assert in the target.**
   Compare by structural diff, not hashes. Make numeric comparison type-tolerant —
   *except* for RNG, which must be bit-exact.
6. **Port bottom-up, leaf-first**, so divergence always localizes to the newest layer.
7. **For cross-runtime RNG parity, reimplement the reference RNG and prove it in
   isolation with a raw-stream test before any game-level parity test.** Order the
   raw-stream sub-tests from most-fundamental to least, so a failure names its own
   cause. Do not attempt game-level parity until the raw stream is green.
8. **When something diverges, read the checkpoint, not the code.** The golden harness
   tells you the exact `(checkpoint, field)` of first divergence. That location is the
   diagnosis. Fix upstream-most first.

## 12. Current status & the immediate frontier

**81 golden tests green.** The full round loop, every kit interaction, `game:deal`,
the seeded deal, the RNG raw-stream, the bot round/terminal/timeout unit tests — all
passing. The Twister is proven bit-exact.

**`game:end` is the one remaining red**, and it fails in the most diagnostic possible
place:

```
game:end.deck[0]  (want=Butcher:3  got=Penitent:2)
```

Position zero of the deck. This is *upstream of the entire game* — before any bot
decision or round logic runs — which means the bots and the round loop are already
proven by every green test above it. The divergence is inside `make_deck_2p`,
specifically in the deck **construction order or the cull**, not in the shuffles
(those are proven by §10). The pre-shuffle card list must be built suit-major /
value-minor with `CARD_DIST` iterated `1→5`, and the cull must drop the *first three
per suit in shuffled order* — any deviation permutes an identically-shuffled deck into
different seats. Bisect by dumping the deck *between the two shuffles* on both sides.

Fixing this closes Phase 1. Phase 2 is the "is the loop fun on screen" test: wire human
input into one seat, let the proven bots be the opponent, make the reveal visible and
suspenseful.

## 13. Decisions recorded but not yet executed

Two forward decisions are documented so they aren't re-litigated:

- **De-randomize the bot doctrine into a shared evaluator + softmax selection layer,**
  with temperature as both the difficulty dial and the bluff (a mixed strategy, which
  a hidden-commitment game *requires* — a deterministic bot is maximally exploitable).
  This also collapses every scattered RNG draw-site into one, which makes future
  `game:end` parity trivial. **Sequencing: port the current stochastic doctrine
  faithfully to green `game:end` first**, locking the harness against the known oracle,
  *then* de-random as a separate, cleanly-versioned `AI_POLICY` change. Prove parity
  against what exists before changing what exists.
- **The Read (tell system)** — a confidence-weighted read layer (pattern prior + live
  tempo update). Fully specified and **parked** in its own document, gated behind Phase
  2 and behind having repeated-opponent data to calibrate against. Its two foundations
  (softmax selection, per-boss identity profiles) should be built *aware* they are its
  foundations, so it's cheap later.

---

## Appendix: key artifacts

- `corruptor_sim.py` — the oracle (~3,300 lines). Rules + bots + balance runner + self-tests.
- `golden_serializer.py`, `golden_master.py` — Python trace emission & validation.
- `GoldenMaster.gd`, `GoldenSnapshotSerializer.gd`, `GoldenTests.gd` — GDScript replay & assert.
- `PythonRandom.gd` — Mersenne Twister reimplementation (runtime RNG parity).
- `RawStreamTests.gd` + `raw_stream_s1.json` — the bit-exact RNG gate.
- Rulebook (v5.29+), **Design Companion** (the "why", incl. the design laws), Narrative
  Bible, Deprecated Lord Archive, Godot Roadmap v3, and the parked Tell System spec.
- Repo: github.com/Zombieswilleatu/Corruptor
