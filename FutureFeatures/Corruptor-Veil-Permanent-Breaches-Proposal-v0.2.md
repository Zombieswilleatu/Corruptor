# Corruptor — The Eroding World: Permanent Breach Proposal v0.2

Date: 2026-09-16
Status: Initial mechanical implementation added 2026-09-17. This document remains
the design record; see [implemented defaults and validation](../docs/U13_PERMANENT_BREACHES_2026-09-17.md).
The victory-outro art direction remains a later presentation pass.

Supersedes v0.1. Updated 2026-09-16 to prefer the cascade's combined Veil and round gate; the ungated version remains a test alternative.

## Substantive design change: the finale proposal is withdrawn

**This document replaces** ***Final Blows and the Final Rite*** **(v0.1, 2026-09-16) in
full.** Withdrawn from that proposal:

- The four-suit payment and the ritual-circle defensive layer.
- The prepare → reveal → defend → complete Dominion sequence.
- The requirement that Ritual be closed by a banishing Hunt in the same round.
- Banishment postponing a pending rite, and the associated recovery-loop concerns.

Nothing from that design is carried forward. It is recorded here as a
deliberate reversal rather than an omission, so the withdrawal is not mistaken
for an oversight later.

**The reason:** the finale existed to make endings momentous. Under this system
the ending already is — by the time a game approaches its conclusion the board
carries several absent Lords' effects and the world is visibly failing. That is
a stronger ending than a ceremony, and it costs no new mechanics.

**Unchanged by this document:** victory precedence, and the existing Ritual and
Dominion conditions.

---

# Purpose

The Veil should show the world eroding. As it advances, absent Lords
permanently enter the Breach and impose their existing Breach effects on the
match. The growing combination changes the battlefield, defenses and card
economy.

Reuse the established Lord effects and their recognizable identities. The older
physical-rift idea — a widening region that slows Marchers — is set aside.
Breach effects supply enough escalation by themselves.

This concerns individual battles. Campaign-wide persistence is not specified.

## What this restores

It also restores something that was lost. Personal Tears were originally
desirable because they granted immunity to Veil threshold effects. Those
thresholds were disabled, leaving personal Tears with no motive outside
Dominion — reducing the appeal of spending five waiting Marchers for a Tear outside a Dominion strategy. This
proposal puts the motive back in a stronger form: not exemption from a generic
penalty, but immunity to a specific named Lord tearing up the board.

---

# Core direction

- Only Lords **not participating** in the match are eligible for permanent arrivals.
- Arrival identities and order remain **hidden** until arrival. The intended experience is "oh fuck, what's next?"
- Once admitted, an intruder **remains for the rest of the battle**. Earlier effects continue as later Lords arrive.
- Reuse each existing Breach effect **according to its actual timing**. Permanent presence does not mean re-applying a maximum-Integrity reduction as fresh damage every round.
- **Personal Tears grant immunity by arrival position.** Full negation is the preferred approach for harmful effects; beneficial effects instead deny or reduce the enemy's benefit.
- **Every Lord participates in the Veil track**, including players pursuing Ritual. A Ritual player who ignores Tears does not merely forgo Dominion — they take the full force of an eroding world while a Tear-invested opponent walks through it.

---

# Thresholds and protection — provisional

The current U13 victory track ends at Veil 26; Dominion eligibility begins at
Veil 12. Both are retained as the initial frame.

| Veil | Event | Personal Tears for protection |
| ----------------------------------------- | -------------------------------------------------------- | ----------------- |
| 5 | First absent Lord enters | 1 |
| 9 | Second absent Lord enters | 2 |
| 12 | *Existing Dominion eligibility* | — |
| 13 | Third absent Lord enters | 3 |
| 17 | Fourth absent Lord enters | 4 |
| 21+ and round 21+ | **Cascade — all remaining eligible Lords enter at once** (preferred gated option) | *not protectable* |
| 26 | *Existing Final Collapse* | — |

Protection follows **arrival position, not Lord identity**. Two personal Tears
protect against the first two arrivals, whichever Lords they turn out to be.

The thresholds and the 1–4 ladder are playtest defaults, not settled balance.

## Protection tops out at four

This is deliberate, and it resolves the overlap between protection and
Dominion.

- **1–4 personal Tears** buy protection, one arrival at a time.
- **5 personal Tears** meets the Personal Tear requirement for Dominion, subject to Veil 12+, a strict Tear lead and victory precedence; it adds no fifth protection tier.
- **The cascade at 21 is unprotectable by design.** There are more effects arriving at once than any investment could have shielded against.

A Ritual player therefore has a real reason to reach four Tears without
accidentally qualifying for Dominion. The two investments overlap without
collapsing into each other.

## The cascade

Under the preferred rule, every remaining eligible absent Lord enters simultaneously once **both Veil 21+ and round 21+** are reached, provided the match is still ongoing.

With nine Lords and two participating, seven are eligible; four arrive at the
earlier thresholds, so the cascade is consistently **three at once** regardless
of matchup.

The escalation curve is therefore: one, one, one, one, **everything**. Four
arrivals are the Veil tearing. The cascade is the Veil failing in a battle that has run long. Final
Collapse remains at Veil 26, independently of whether the cascade has fired.

### Cascade trigger: preferred gate and test alternative

Automatic Neutral Tears in `U13Victory.gd` provide the timing boundary:

| Round | Automatic Neutral Tears |
|---|---:|
| 1–12 | 0 |
| 13–20 | +1 per round |
| 21 onward | +2 per round |

**Veil 21 and round 21 are different conditions.** Prefer Option B for the
initial proposal; retain Option A for a controlled comparison if useful.

#### Option B — gated: Veil 21+ AND round 21+ (current preference)

Both conditions must hold:

- Reach Veil 21 before round 21: the first four Breaches remain active; the cascade waits.
- Reach round 21 with Veil below 21: the cascade waits for the Veil threshold.
- Meet both conditions while the game remains ongoing: all remaining absent Lords enter without protection.

The +2 automatic rate is active when the cascade begins. From Veil 21,
automatic pressure alone advances 21 → 23 → 25 → 27: **at most three further
round-end checks**, often fewer with other Tears, a higher starting Veil,
or another victory route.

**Final Collapse stays at 26.** An early, high-Tear game can reach it without
ever triggering the cascade. Accept that outcome; do not delay victory or
force extra playable rounds to guarantee the spectacle. The cascade is an
escalation for battles that run long, not a required ending for every match.

The precise activation hook remains an implementation decision. It must
respect existing victory timing and must not schedule new gameplay after a
match has finished. In particular, a jump to Veil 26 must not create a
mandatory extra cascade round.

#### Option A — ungated: Veil 21+ only (comparison alternative)

The cascade fires upon reaching Veil 21, at any round.

At round 21+, it has the same three-check maximum from automatic pressure.
Around rounds 14–16, the +1 rate closes the five-point gap in **at most five
round-end checks from automatic pressure alone**. Other Tears, or reaching
the later +2 rate, shorten that window. Before round-pressure generation
begins, the bound differs; this is not an indefinitely unbounded system.

An early cascade could last longer, but need not. The working hypothesis is
that reaching Veil 21 early indicates rapid Tear generation, and those sources
will often finish the game quickly too. Their continuation is not guaranteed.
Test duration rather than assuming a prolonged cascade or compressing
thresholds in advance.

Heavier Breach Wish Prices can accelerate the Veil under either option.
Under B, they may bring forward the time at which the Veil condition is met,
but cannot bypass the round gate.

#### What to measure

Record the Veil-21 crossing round, actual cascade activation round, and time
from activation to game end. Under B, time waiting above Veil 21 before
round 21 is **not** cascade exposure. Track how often games end without a
cascade; rarity alone is not a reason to change the gate.

Compare typical durations and longest cases, split by early and late Veil
crossings. Keep the existing proposed thresholds for the first tests.

Earlier victories will experience fewer arrivals. A game ending in the Veil
12–15 band sees **two or three**, since the third arrival enters at 13.

---

# The victory outro

When a game resolves, do not cut to the summary screen. Play the accumulated
Breach effects out over a 5–10 second fade:

- Kroni manifesting and devouring the field.
- Paradox Geometry flipping allegiances that no longer matter.
- Castles eroding, Marchers slowing, fire spreading.

**The winning player's units are untouched.** They should not fight back, react
or celebrate. They stand still while everything around them is destroyed.
Invulnerability reads far stronger as stillness than as a victory pose.

## Every route, not only Dominion

The imagery represents **the victory itself**, whatever produced it. A Ritual
winner may hold no personal Tears at all, and their survival should read the
same way: the world comes apart and they are still standing.

Where the winner *does* hold protection, the sequence can show it specifically
— their marchers ignoring Kroni, their castles not eroding — but protection is
not a prerequisite for the imagery.

**To be explicit: the fifth personal Tear does not win the game.** Dominion
still requires Veil 12+, at least 5 personal Tears, and a strict lead over the
opponent at the victory check. Nothing in this proposal changes that.

## Why it closes the loop

Aldric stood beneath Kanifous and nothing looked down at him. The player who
wins stands in the same storm and comes out the other side — not because
anything noticed them, but because they got there first.

This is presentation, not a mechanic. Nobody makes a decision during it and
nothing is balanced by it. Final visual treatment can be settled during the
presentation pass.

---

# The Veil track display

Both players’ Personal Tear counts already appear publicly on the score cards. **That is not
sufficient.** A number is comparative and abstract; a mark on the track is
positional.

**Stamp each player's personal Tears directly onto the Veil track at the
thresholds they cover**, prominently.

The track then reads three things at once, in one place, with no tooltip:

- Progress toward Dominion and Final Collapse.
- Distance to the next arrival.
- **The protection differential** — whose marks sit on the arrivals ahead and whose do not.

The intended read is immediate and hostile: *this guy is covered through
arrival three and I'm not. He's going to win if I don't act.*

Show both players’ stamps using the existing public Personal Tear counts.

After an arrival, show the Lord, its effect, and each player's protection
status against it. Under Option B, label the cascade's two requirements
clearly, including when Veil 21 has been reached but the round gate is pending.

---

# Hidden arrivals and player information

Thresholds are **visible**. Identities and order are **concealed** until
arrival. The earlier suggestion to preview the full sequence was explicitly
rejected.

Suggested implementation: seeded selection without replacement from eligible
absent Lords. Whether the sequence is sampled at setup or on arrival is an
implementation choice; **neither player nor bot may receive unrevealed
identities through ordinary observations.** Saves and replays must preserve
outcomes without exposing hidden information to decision-making.

Personal Tears become insurance against unknown danger. After an arrival they
also offer an escape from recurring pressure. One-time arrival damage cannot be
undone by acquiring protection later.

**Do not weight the draw.** Ordering some Breaches earlier because their effects
need time to matter was considered and set aside; an unweighted draw keeps the
uncertainty honest and produces more varied battles.

---

# Existing effects and proposed protection

Baseline wording checked against `U13LordRules.gd` on branch
`u13-basic-doctrine` at `a7544d620376a0a4339825dd5ab85fcdf194dcec`. Humbaba's
4-damage entry checked in `U13Humbaba.gd`.

The protection column is proposed behavior, not existing implementation.

| Lord / effect | Breach behavior (Kanifous replacement proposed) | Proposed protection |
| --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| **Gremory — Gem Dagger** | First Guard defeated each round makes both players draw 1 card. | A protected player denies the opponent that bonus card. Their own draw is unaffected. |
| **Deimos — Cracked Foundations** | All Castles have 5 less maximum Integrity. Ending the ordinary Breach restores the ceiling without healing damage. | Your Castles ignore the reduction. Gaining protection restores the ceiling without healing lost Integrity; confirm in implementation. |
| **Humbaba — The Stones Forget** | On entry, 4 damage to every exposed Castle, once per entry. | Your Castles ignore both entry damage and the proposed ongoing damage while protected. |
| **Kalligan — Rapid Construction** | At round start, both players' damaged standing Castles restore 2 Integrity. Ruined and Profaned unaffected. Forge-Repair does not stack while Banished. | Deny the enemy's restoration. Alternative: reduce theirs to 1 per Castle per round. Full denial is the simpler starting recommendation. |
| **Orias — Entanglement** | Players at Threat 2+ may deploy no more than 2 Guards during Development, when active before submission. | You ignore the deployment restriction. |
| **Odradek — Paradox Geometry** | Once per round after combat, randomly change allegiance of one Lord Guard, one Castle Guard, or all Marchers in a small circle. Only legal transfers chosen; either side can benefit. | Your units cannot be taken; enemy units may still transfer to you. Mixed-circle selection and legal targeting need explicit rules. |
| **Kroni — Insatiable Hunger** | Once each Marching phase, manifest at a random field point, move briefly, devour Marchers touched from either side, disappear. Grants no Hunger, Souls, Tears or Ravenous progress. | Your Marchers cannot be devoured by the Breach manifestation. |
| **Valak — Gravitational Collapse** | All Marchers move at 50% speed while active. | Your Marchers ignore the slowdown. |
| **Kanifous — The Unbound Wishmaster** *(proposed replacement for The Void)* | Both players may take an optional Wish each round under the ordinary Wish rules, each creating a Price. | Beneficial effect: a protected player **denies the opponent access to Breach Wishes**. Their own access is unaffected. |

Default for harmful effects is **binary immunity** rather than a bespoke
reduction formula per Lord. Partial mitigation remains available if testing
shows full protection is too strong.

If both players qualify for Gremory protection, both bonus draws are denied.
Under full-denial Kalligan protection, both qualifying players deny each
other's restoration; under the partial alternative, both receive 1 per eligible
Castle.

Protection targets the **Breach contribution**, not unrelated effects with a
similar outcome.

## Kanifous — replacing The Void

**Tentative. The Void is withdrawn in favour of an unbound Wishmaster.**

The Void made the game worse to play rather than harder to play. Every other
Breach puts a new problem on the board — marchers eaten, castles eroding,
guards changing sides. The Void gave the same problems with worse eyesight,
and it was the only effect with no available answer: you can repair against
Humbaba, spread out against Odradek, rush against Valak's slow. Against the
Void you squint.

It was also the most expensive effect to implement correctly — presentation
adapter, masked bot view, PySim parity, save/replay that does not leak — for
the least play value.

### Proposed: The Unbound Wishmaster

While Kanifous occupies the Breach, **both players may take one optional Wish
per round**, resolving under the ordinary Wish rules and creating an ordinary
Price.

The fiction is an unbound Wishmaster: whoever asks pays. A permanent absent-Lord arrival does not require that Lord to have died in the match.

It also behaves well mechanically:

- It is not the only beneficial Breach — Gem Dagger and Rapid Construction already grant benefits. **Its distinction is optional benefit with a delayed cost**: the others apply automatically, while this one is a decision whose price arrives later.
- It produces asymmetry from identical rules — the player better positioned to absorb a Price uses it more freely, so board state decides the value.
- **It reuses machinery that already exists.** Wish and Price are implemented, serialized and replay-safe, and it removes the Void's masked-view, presentation-adapter and hidden-information problems entirely.

**It does not eliminate parity work.** Three behaviors are new and each needs
exact Godot/PySim agreement: **both players holding Wish access** where only
Kanifous had it, the **weighted Price table** for Breach Wishes, and
**protection denying an opponent's access**. Reuse lowers the cost; it does not
remove the gate.

### Protection

Treated as a **beneficial effect**, consistent with Gem Dagger and Rapid
Construction: a protected player denies the opponent access to Breach Wishes
while retaining their own.

That makes this arrival unusually valuable to be protected against. Most
protections restore you to normal; this one makes you the only player who can
use the thing.

### Heavier Prices for Breach Wishes — tentative

Breach Wishes should tentatively draw from a **weighted-worse Price table**
than ordinary Wishes — shifted toward Stone and above.

A wish granted by an unbound Wishmaster with no Lord to constrain him should
cost *more*, not less. It also feeds the loop: Stone-and-above Prices place
Neutral Tears, Neutral Tears advance the Veil, and the Veil brings more
arrivals.

**Watch item.** That loop means a Kanifous arrival is also a Veil accelerant.
Drawn early at threshold 5 or 9, it could pull the later arrivals in
considerably faster than they would otherwise come — which may make it the best
possible first draw, or may compress games too hard. Log **Veil-per-round
separately for games where Kanifous is in the Breach.**

Exact weighting is unspecified. Start by shifting the existing table rather
than authoring a second one.

---

# Humbaba revision — arrival shock and continuing erosion

Proposed **The Stones Forget**:

- On entry, 4 damage to every exposed Castle — preserving the implemented value.
- On subsequent rounds, **1 damage to every exposed Castle at round start**.
- Do not also apply the recurring damage in the entry round.

The 4 is confirmed from the repository; an earlier recollection of 5 was
mistaken and this proposal does not silently increase it.

For an ordinary Breach, recurring damage stops when Humbaba leaves; a later
entry triggers a fresh entry hit. For a permanent Veil arrival, recurring damage
continues for the rest of the battle unless a player's protection shields their
Castles.

The ordinary-Breach revision is proposed alongside the new system, not already
implemented. Whether personal Tear protection also applies to participating
Lords' ordinary Breaches is a separate unresolved scope decision.

Exact round-start position relative to repair and other Breach effects must be
set before implementation. Preserve existing exposed-Castle eligibility unless
deliberately revised.

Deimos needs no comparable repeat hit: his reduced ceiling already lasts while
present. **It must never become a fresh cumulative subtraction of 5 each
round.**

---

# Why this shape

The battlefield becomes less stable as the Veil grows. Lords already familiar to
players supply the escalating rules, so no second set of unrelated hazards is
needed.

Tears serve three connected purposes: advancing the Veil, pursuing Dominion, and
preparing for the world that is emerging. A player may deliberately accelerate
the track while better protected than the opponent — but cannot know which
intruder comes next.

Different absent-Lord pools and arrival orders create different battles.
Beneficial effects such as Gem Dagger and Rapid Construction matter too: the
world changes unevenly, and protection can turn shared relief into an advantage.

---

# Decisions still needed before implementation

| Question | Current direction / unresolved point |
| ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Arrival count and timing | Test 5 / 9 / 13 / 17 with the cascade requiring Veil 21+ and round 21+ under preferred Option B; numbers provisional. |
| Protection ladder | Test 1–4 by arrival order. Decide whether protection tracks *current* Tears or a permanently earned milestone if Tears can fall. |
| Cascade trigger and duration | Prefer B (Veil 21+ AND round 21+); retain A (Veil 21+ alone) for comparison. Under B, at most three further round-end checks from automatic pressure. Measure actual activation separately from Veil crossing; do not delay Final Collapse at 26. |
| Cascade composition | Three simultaneous arrivals is an **untested multi-Breach state.** Author a test rather than discovering it in a campaign. Intended as a short closing stretch; measure actual duration. Some combinations (such as Kroni + Odradek + Valak) need explicit interaction coverage. |
| Kalligan protection | Full enemy denial versus reducing enemy restoration from 2 to 1. |
| Ordinary Breach protection | Do personal Tears protect only against permanent intruders, or also against participating Lords' ordinary Breaches? |
| Trigger boundary | When do threshold crossings produce arrivals? Does the threshold-crossing Tear grant protection before an entry hit? Multiple thresholds crossed at once need an ordered rule. |
| First recurring trigger | Define when each newly arrived effect starts ticking. Humbaba explicitly has no recurring tick in his entry round. Preserve Orias's pre-submission legality boundary. |
| Interaction with ordinary Breaches | Permanent intruders may coexist with participating Lords' temporary Breaches. Define scheduling and source identity without accidentally suppressing one. |
| Odradek protection | Specify legal candidates, protected units in mixed circles, and whether immune outcomes are skipped or rerolled. |
| Castle damage and rewards | Retain or deliberately revise ordinary Breach damage consequences — ruin/defunct behavior, Tears, destruction reactions. Do not assume a neutral intruder awards a player siege credit. |
| Kanifous Breach replacement | **Tentative.** The Void is withdrawn for the Unbound Wishmaster. Confirm the direction, then settle: Breach Wish cadence, whether one Wish per player per round is right, and the weighted Price table. |
| Breach Wish Price weighting | Tentative shift toward Stone and above. Decide whether to reweight the existing table or author a second one — prefer the former. |
| Kanifous as Veil accelerant | Heavier Prices place more Neutral Tears, which accelerates arrivals. Measure Veil-per-round in Kanifous-Breach games before setting weights. |
| Older Veil penalties | This is the new Veil-effects direction, **not** permission to re-enable disabled legacy penalties on top. |
| Tear-count visibility | Counts are already public on the score cards; carry the same information into the track stamps. |

---

# Focused playtest questions

The first question gates most of the others.

**How far up the track do games actually get?** The last accepted campaign
averaged 20.07 rounds; four-Lord data showed CastleDestruction producing 30 of
49 Neutral Tears, so the Veil fills partly outside either player's control.
Record the Veil at game end across a campaign. **If typical games finish around
Veil 12–15, they experience two or three arrivals. That may be the right
pacing: the full cascade can be an exceptional ending.** Keep the current
proposed thresholds for the first tests. Consider compression only if play
evidence shows insufficient escalation, not simply because most games end
before every effect appears.

Then:

- Does the system make the world feel progressively unstable without making Marching irrelevant?
- Can a player behind in personal Tears still respond meaningfully?
- **Does protection encourage healthy investment, or make Tears mandatory regardless of strategy?** This is the main risk. Arrivals come on a clock neither player fully controls, and personal Tears are the only shelter — a strong pull toward identical behavior across nine Lords that are supposed to play differently.
- Does Humbaba plus Deimos eliminate Castles too quickly? Does Kalligan create useful counterpressure or excessive delay?
- Do Kroni and Odradek create dramatic, understandable changes rather than opaque losses?
- Does the Unbound Wishmaster read as an opportunity worth the risk, or do players simply decline every Breach Wish? If declined consistently, the Price weighting is too harsh or the Wishes are not attractive enough.
- Are hidden arrivals exciting enough to justify the inability to prepare for a specific Lord?
- Does accumulated recurring activity materially lengthen resolution time?
- How often is Veil 21 crossed **before** round 21? Under B, distinguish time waiting for the gate from actual cascade exposure. Under A, measure early exposure directly.
- What fraction of games end without a cascade under B? A rare full collapse may be the right pacing; do not treat rarity alone as a defect.
- From actual cascade activation, how long until game end? Measure typical and longest cases. Does the cascade actually overstay its welcome?
- Are ordinary and permanent Breach combinations readable and reproducible?

Record arrival identities and order, round and Veil at arrival, both players'
Tears and protection, damage and units/cards affected, Castle survival, victory
route and playtime. Compare ordinary Breaches, permanent arrivals and the
Humbaba revision separately where necessary to isolate the cause of a balance
shift. Record both rounds from cascade to game end and round-end checks while
the cascade is active; retain the longest cases as well as typical durations.

Start with small authored scenarios: single arrivals at each position, a
protected versus unprotected player against the same arrival, Humbaba plus
Deimos together, and the three-Lord cascade. Include early Veil 21 with the
gate closed, round 21 with insufficient Veil, activation once both conditions
hold, and Final Collapse reached before the gate opens.

---

# References and status

- [U13 Lord rules](../Prototype/U13/U13LordRules.gd)
- [Humbaba implementation](../Scripts/Sim/U13Humbaba.gd)
- [Victory rules and automatic Neutral Tears](../Scripts/Sim/U13Victory.gd)
- [Consolidated roadmap](README.md)
- [Superseded Veil proposal v0.1](Corruptor-Veil-Permanent-Breaches-Proposal-v0.1.md)
- [Withdrawn finale proposal](Corruptor-Finals-Theoretical-v0.1.md)

*Final Blows and the Final Rite* (v0.1, 2026-09-16) is **withdrawn and
superseded by this document in full.** See the withdrawal note at the top; do
not treat its mechanics as pending.

This records a design proposal. It does not authorize or claim implementation,
change current test expectations, or advance this feature ahead of the
roadmap's existing engineering priorities — the PySim coverage gap and doctrine
work come first.
