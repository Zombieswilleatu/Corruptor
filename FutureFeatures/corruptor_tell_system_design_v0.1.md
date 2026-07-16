# Corruptor — The Read (Tell System)
**Design capture · v0.1 · status: PARKED / earmarked for later**

---

## 0. Status & scope

This document defines a capability, not a task. **Do not build this now.** It is
gated behind two things that do not yet exist: a playable core loop that has
passed the Phase 2 "is the loop fun on screen" test, and real repeated-opponent
play data to calibrate against. Until both exist, this system is a multiplier on
an unproven core, and a multiplier on zero is zero.

It is written down now for one reason: two decisions being made *today* — the
softmax selection layer and the per-boss identity profiles — are the foundations
this system stands on. If those are built aware of this document, the AI half of
the tell system falls out almost for free later. If they're built blind to it,
this becomes a from-scratch subsystem. So: build those two things *as* foundations,
and shelve the rest here.

The core mistake this document exists to prevent: shipping the trivial version.
Drawing a "!" when a number crosses a threshold is an afternoon of work and is
*negative* value — it trains players that the cues are meaningless, and once the
glyph vocabulary is burned, every richer version is dead on arrival. A
miscalibrated tell system is worse than no tell system.

---

## 1. Core thesis

**It is one system, not two.** Pattern recognition and live tempo are not two
parallel tell systems; they are one confidence-weighted read. Pattern is a
high-confidence prior. Live tempo is a low-confidence update layered on top of it.

This framing is what mitigates the risk that live behavioral tells are just noise.
A raw hover-time asked to carry meaning alone is unanswerable — is 40 seconds a
bluff or a coffee break? But 40 seconds *conditioned on* a trusted pattern prior
is a weak signal agreeing or disagreeing with a strong one. The live channel never
needs to be reliable on its own. It only needs to be reliable enough to nudge a
prior we already trust. When the live signal is garbage — lag, async gaps, someone
walking away — the prior simply dominates and the system degrades gracefully to
pure-pattern. That graceful degradation is the whole trick.

---

## 2. Where this attaches (the three-layer AI)

The broader bot is being restructured into three separable layers. The tell system
is a readout of the middle one; it is not a new subsystem.

- **Evaluation** — the scoring function (`_score_hunt/siege/ward`, LORD_AI weights,
  defense estimation). Where "intelligence" lives. Shared across all difficulties.
- **Selection** — how a move is chosen from the scored options. Softmax (Boltzmann)
  sampling over move scores, with a temperature `τ`. `τ→0` is deterministic argmax;
  moderate `τ` mixes at the margins (a real mixed strategy — the boss that actually
  bluffs); high `τ` is easy/erratic. **This is the difficulty dial AND the bluff.**
- **Error model** — deliberate degraded evaluation for lower tiers (an epsilon chance
  to misread Recoil, mis-value a castle). Genuine "flaws," kept separate from
  selection noise because noise reads as *deranged*, not *easy*.

The AI's own tells are a **readout of the selection layer's sample margin**: a move
sampled from far down the softmax distribution is, by definition, a move the bot
"hesitated" on. Surface that as a cue. Its truthfulness is tuned by the same `τ`
that sets difficulty — so the tell system and the difficulty system are literally
the same dial (see §6).

---

## 3. Channel architecture

### 3.1 Pattern channel (the prior — high confidence, ships first)

Per-opponent action distributions conditioned on board state: "this player wards
their Lord 80% of the time at 5+ Souls," "they've opened bluff-Profane three matches
running." This is *pattern*, not *tempo* — it reads habit, not hesitation. It works
async, survives lag, and is actual information rather than possibly-noise. It
composes directly with the per-lord action stats the balance sim already tracks.

This is the spine. It is what the roguelike bosses carry as stable, learnable,
*individual* tell-profiles — which is what makes the solo campaign partly about
learning to read each Lord's specific liar's face.

Requires **sample-size gating**: a glyph must not fire confidently off three
observations. Under-sampled buckets stay silent.

### 3.2 Live tempo channel (the update — low confidence, second pass)

The live channel's job is **not** independent bluff detection. Its job is to flag
**deviation from the player's own tempo norm**. Pattern tells you what a player
*usually* does; tempo is the one channel that can whisper "…but not this time." A
player who bluffs 70% from this state but this time locks in *instantly* where they
normally stew — that break from their own baseline is the highest-information event
in the system, precisely because it *contradicts* the prior. Pattern-matching
structurally cannot see this. Tempo is the only channel that can.

The single piece of infrastructure that converts this channel from noise to signal:
a **self-referenced, state-bucketed tempo baseline with outlier rejection.**

- **Self-referenced** — measure "is this slow *for them*," not "is this slow."
  Absolute tempo is noise; relative tempo is signal.
- **State-bucketed** — people are slow on hard boards regardless of intent, so
  "slow" only means something relative to how slow they usually are *on boards like
  this*.
- **Outlier rejection** — clip the tails. A 6-hour async gap is not a deviation in
  a meaningful direction; it's an outlier to discard, not a read. Keep only the
  *near* deviations, in human-decision range.

No baseline, no live tells. With a baseline, a live tell is simply: how far is this
commit from where this player usually sits, on a board like this, clipped for
outliers.

### 3.3 Confidence weighting (how the two combine)

The soft (live) glyph is not a weaker *kind* of glyph — it is a visual encoding of
**confidence**. Same glyph vocabulary, different visual weight, and the weight *is*
the honesty rating:

- Pattern-derived cues render **solid, saturated, stable**.
- Live-derived cues render **faint, thin, brief** — a ghost of a glyph.

A player learns fast that a bold "!" is worth acting on and a faint flicker of "!"
is worth only a raised eyebrow. Confidence becomes a visual property the player can
*feel*, not a hidden number.

---

## 4. Glyph grammar

The glyph vocabulary ("!", "?", "*", etc.) encodes **categories of signal, never
meanings.**

- A glyph tells the player *that* something happened (an unusually long hover, a
  re-selection, an instant lock-in), never *what it means*.
- Meaning is **learned per-opponent by the player**, because the correlation between
  "long hover" and "bluff" is different for every human. That learning is the read.
  That is the skill. The game surfaces the signal; it never interprets it.

**Interpretation lives in a per-opponent history layer that the player reads — the
game never interprets.** Track, per opponent, what each glyph *has correlated with*
in past reveals ("when they showed '!', it was a bluff 6 of 9 times"). Now the glyph
has earned meaning through the player's own observation, grounded in that specific
opponent rather than a global rule. This is also the piece that makes the roguelike
bosses work: fixed identities with stable, learnable, individual tell-profiles.

**Hard rule: never surface a glyph the player cannot, in principle, eventually
explain.** A cue tied to a rule the player can never reverse-engineer is not
mysterious — it's noise wearing a read's costume, and players tune noise out
permanently (same reason uniform score-jitter reads as "deranged," not "hard").
Mysterious-but-learnable is a read. Mysterious-but-random is static.

---

## 5. Why reliability is the enemy (the false tell)

The instinct is to build a clean, reliable vocabulary where "!" means bluff. That
is a **telegraph**, and it fails for a mechanical reason, not an aesthetic one:
the moment a tell reliably means something, it stops being information the reader
*earns* and becomes information the reader simply *has* — they best-respond to it,
and now the signaler is solved. This is the exact failure mode as a deterministic
bot in a hidden-commitment game (see §6): a fully predictable signal is a fully
exploitable one.

What keeps a tell alive as skill expression is that it is **probabilistic and
exploitable in both directions.** The interesting design object is therefore not
the tell — it's the **false tell.**

---

## 6. The AI side & symmetry

The system is symmetric: the AI reads the human's tempo/pattern, and the human reads
the AI's. The AI's tells are generated as a readout of softmax sample margin (§2) —
a move the bot *nearly didn't pick* can flash a "?".

Because reliability is tunable via `τ`, the AI's tell profile becomes a difficulty
expression:

- **Low `τ` boss** — rare, reliable tells. Reads as disciplined, hard to exploit,
  an honest face. Mixes only at true margins.
- **High `τ` boss** — frequent, noisy tells. Reads as twitchy, exploitable, a bad
  poker face.

The bot's temperature *is* its tell-generator, and its reliability *is* a difficulty
knob. Bosses can even tighten `τ` as the player climbs a run.

---

## 7. The counter-tell (the ceiling)

This is what separates a cute UI feature from an actual bluffing game. Once a player
knows a boss reads their tempo, they can **break their own baseline deliberately** —
stew on a snap-call, snap a decision they'd normally stew on — to spoof a false tell.

Critically, this only works *because the baseline is self-referenced* (§3.2). The
player isn't faking a global tell; they're faking **their own signature**, which is a
more intimate and satisfying bluff. The naive absolute-tempo version cannot be
counter-played interestingly. The self-referenced version can. The counter-tell
falls out of both layers for free — it is not extra work, it is a consequence of
building the baseline correctly.

---

## 8. Where the value actually is

**Value is proportional to rematch density.** A tell read over many games against
the *same* mind is the deepest expression of a bluffing game. A tell against a
stranger you play once is nothing — no history for a prior, no baseline, no pattern
to learn.

Ranked by fertility:

1. **Solo roguelike spine — richest.** Fixed boss identities fought repeatedly across
   runs is *exactly* the "same mind over many games" condition, handed over for free.
   This is where the feature lives first and matters most.
2. **Friend-group async — moderate.** Repeated pairings build real profiles.
3. **Anonymous ladder — near-zero.** One-off matchups are barren ground for tells.

Implication: this is a single-player-forward feature, not a multiplayer one.

---

## 9. What is actually non-trivial

The glyph is trivial. The glyph is not the feature. Three pieces underneath it are
real work:

1. **State-bucketed pattern model** — per-opponent action distributions conditioned
   on board state, persisted across matches, with sample-size gating so cues don't
   fire off a mirage. A data-collection and storage problem.
2. **Self-referenced tempo baseline with outlier rejection** — the thing that makes
   the live channel signal instead of noise. Rolling, state-bucketed, tail-clipped.
3. **The calibration loop** — ongoing, never fully done. You cannot eyeball whether a
   glyph is "faint but real" vs "static." You must measure whether each cue actually
   correlates with what it claims to, tune the firing threshold, and re-measure. This
   is the tell-system equivalent of the 400k-game balance run.

Rough estimate: the valuable version is ~2 weeks of real work sitting on infrastructure
(persistent per-opponent profiles, tempo baselines) that has to exist regardless.

---

## 10. Dependencies & sequencing

**Downstream of (must exist first):**
- `game:end` green, bots ported, Phase 1 complete.
- A playable core loop that has passed the Phase 2 "is the loop fun" test.
- The softmax selection layer (§2).
- Per-boss identity profiles (§4).
- Real repeated-opponent play data to calibrate against — which cannot exist until
  after there is a playable build with people playing it repeatedly. The tell system
  is downstream of things that don't exist yet by definition.

**Build-aware NOW (cheap insurance, no tell-system work):**
- Build the **softmax selection layer** so sample margin is inspectable — that is the
  AI's future tell generator.
- Build **boss identities** as first-class, persistent profiles — that is the future
  home of per-opponent pattern models.

Do these two, aware they are foundations, and the AI half of the tell system is
nearly free later. Do not build anything else here yet.

---

## 11. Failure modes / hard cautions

- **Miscalibration burns the vocabulary permanently.** Once players learn the glyphs
  are noise, they ignore all of them, and every richer layer built on top (especially
  the counter-tell) dies — a spoof nobody reads is not a bluff. A bad version is worse
  than none.
- **Faint must mean genuinely-less-certain, not decoratively-mysterious.** If live
  sensitivity is ever dialed up to feel "more alive," noise returns and faint glyphs
  get tuned out wholesale. Keep the faint channel *calibrated*, not *loud*.
  Faint-but-real is a whisper worth leaning in for. Faint-but-random is static.
- **A reliable tell is a telegraph is an exploit.** Keep cues probabilistic and
  two-way exploitable (§5).
- **Every glyph must be in-principle learnable** (§4).

---

## 12. Open questions

- **Commit interaction / timing surface.** The live tempo channel needs something to
  time against. Is there a discrete confirm step (select → confirm) that can be timed,
  or is commitment a single tap with nothing to measure? If the latter, the live
  channel may need a deliberate confirm affordance — which is a core-loop UX decision
  that should be made *before* the loop is locked, even though the tell system itself
  is parked.
- Glyph count and grammar: how many distinct signal categories before the vocabulary
  is too noisy to learn?
- Where does per-opponent history surface in the UI without becoming a spreadsheet the
  game reads *for* the player (which would collapse the read back into a telegraph)?
- Cross-run persistence model for the solo spine: do boss profiles reset per run, or
  does the meta-progression include "learning" a boss across runs?

---

## 13. The bet, in one line

A confidence-weighted read where pattern is the prior, self-referenced tempo is the
update, glyph grammar is shared, visual weight encodes honesty, and counter-play
falls out of both layers for free — valuable in exact proportion to how often players
face the same mind, and therefore a solo-spine feature first. Not trivial in the
version worth having. Parked until the core loop is proven fun and there is data to
calibrate against; its two foundations (softmax selection, boss identity profiles)
built now so it is cheap when its time comes.
