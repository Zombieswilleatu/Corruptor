# CORRUPTOR — DESIGN ADDENDUM

Covers the Veil economy, Pillage, the Siege Engine rework, and passive Construction.
Supplements the Lord Action Windows document.

---

# 1. THE VEIL ECONOMY

## 1.1 Why this section exists

Dominion is structurally unreachable in the current build.

`dominion_requirement` is 5 personal Tears. `dominion_track` is 12 total Veil.
The Veil is fed by both players' personal Tears plus the Neutral pool.

Because 5 is less than half of 12, a player racing Dominion alone cannot fill the
track. They need roughly 7 Tears from the opponent or from the Neutral pool.

Observed in `seed2035957351`: Kanifous reached 5/5 personal Tears at round 11 and
held there for three rounds. Valak generated 0 Tears all match. The Neutral pool
supplied 3. The Veil finished at **8/12** and the match ended by Ritual.

Kanifous had met its win requirement and had no path to convert it.

## 1.2 Current Neutral faucets

Live:

* `castleless_tear_neutral`
* `kani_neutral_tear`
* `reconfig_neutral` (Odradek only)

Disabled:

* `neutral_tear_on_banish = False`
* `resummon_tear_mode = "none"`
* `veil_drift = 0`, `veil_drift_rate = 0` (`veil_drift_after = 15`, past normal match length)
* `veil_on_permanent_loss = False`
* `castle_tear_uncapped = False`

The Marching arrival Tear was removed by the Marcher rework. `march_threshold = 3`
remains in config but arrival now produces a waiter instead of a Tear.

## 1.3 RESUMMON TEARS — new

**When a Banished Lord is resummoned, place 1 Neutral Tear.**

Fiction: the Lord being torn out and dragged back through damages the Veil.

Implementation note: the plumbing already exists. The summon phase result carries
a `neutral_tear_gain` field currently sitting at 0. This is a `resummon_tear_mode`
value, not new code. Confirm what modes that key accepts before writing anything.

### Rate check

`seed2035957351` had 5 Banishments across 13 rounds. At 1 Neutral Tear per
resummon that takes the Veil from 8 to 13, past the track. This single change
flips that match.

This is a strong lever, not a nudge. Verify against a match where a Lord dies
early and often before adding further faucets.

### Why resummon and not Banish

Banish fires on the attacker's success. Resummon fires on the victim's recovery.
The player who most needs the Veil to fill is the one being beaten down, and
resummon is the trigger they actually reach.

### Coupling property

Hunting now advances two clocks at once. Each Banishment gives the attacker
roughly +2 Souls toward `win_souls = 12` and puts 1 Tear in the Veil toward
the victim's Dominion at 12. Ritual still wins that race about 2:1, which is
close to the observed 588/126 split — but a Ritual rush can no longer outrun
the Veil indefinitely.

### Not a decision for the victim

Vacant Throne compounds (1 Soul, then 2, then 3), so refusing to resummon
concedes ~6 Souls over three rounds. Nobody eats that to deny one Tear.
Treat resummon Tears as a tax on being Banished, not a choice.

The grace window before the escalator engages is where any real decision lives.

**To verify:** `vacant_throne_rounds` read 0 at the end of a match where the Lord
died five times, and the attacker's Soul gains came in flat +2s rather than an
escalating +1/+2/+3. The Lord may be dying and returning within the same round,
meaning the escalator never engages. If so, the deterrent isn't doing any work.

## 1.4 CONSUME THE HUNT — retained

Keep alongside resummon Tears. They are not substitutes.

| | Consume the Hunt | Resummon Tear |
|---|---|---|
| Trigger | Attacker's success | Victim's recovery |
| Currency | Personal Tear | Neutral Tear |
| Counts toward `dominion_requirement` | Yes | No |
| Available to a losing player | Rarely | Always |
| Is a decision | Yes | No |

Consume is the tradeoff — give up a Banishment's Souls for a Tear.
Resummon is what stops a match stalling at 8/12 when neither player wants to
spend on Tears.

Both were `false` in every terminal snapshot examined. Neither player has
exercised Consume yet.

## 1.5 PERSONAL vs NEUTRAL — roster policy

**Open decision. Settle before the remaining six Lord passes.**

Neutral Tears fill the Veil. Personal Tears fill the Veil *and* count toward
`dominion_requirement` *and* grant threshold immunity.

Current Lord-pass Tear lines are almost all Neutral: Orias's Mark, Valak's Orb,
Deimos after his first Ruin. Under that, those Lords still cannot qualify for
Dominion without Profane, and Dominion stays "the Profane strategy" for the
whole roster.

Decide per-Lord: personal line, Neutral line, or both. Build the last six
against the rule rather than case by case.

## 1.6 Threshold immunity — retain

The existing rule where N personal Tears exempt you from the first N Veil
threshold effects should **not** be retired.

It is what makes personal Tears universally desirable rather than a
Dominion-only concern. Every Lord wants one or two as insulation against the
world they are helping to degrade. That is the motive that makes a universal
personal-Tear line worth building.

It also retroactively explains Profane-heavy play: wrecking your own
infrastructure buys immunity while everyone else plays in the degraded world.

### Open questions

* Is immunity retroactive? If an effect fires at Veil 4 and you reach 3 personal
  Tears at Veil 6, are you covered for the earlier ones? This decides whether
  Tears are worth banking early or grabbing late.
* Do threshold effects punish the board leader? If they scale with castles,
  Souls, or Guards, then insulation matters less to whoever is ahead and the
  system self-corrects. If they are flat, immunity compounds an existing lead.

---

# 2. WAITERS → PERSONAL TEAR

## 2.1 Rule

**Consume 5 waiting Marchers in a single lane to place 1 personal Tear.**

Five in one lane, not five across both. Numbers tweakable.

## 2.2 Why this shape

Universal across the roster without a new subsystem. The cost is a force you
visibly built and protected, and it requires actually reaching the enemy gate.

It also gives waiters a second use. Banking is currently monotonic — accumulate,
cash into the next Hunt or Siege. Now a stack is a fork: attack support, or a
personal Tear and its immunity. What a stack is worth changes depending on where
the Veil sits.

## 2.3 Things to watch

**Scarcity in contested lanes.** The 12-waiter stack observed in
`seed74143939` was built against an opponent producing zero Marchers. With both
sides spawning, most waiters die en route. Reaching 5 may be rare — and the
player losing the Marcher war is exactly the one who most needs insulation.
Check that this doesn't pay out only to whoever is already winning.

**Exchange rate against attack support.** Five waiters spent on a Tear are five
points of attack forgone. If the Tear is clearly better, nobody ever cashes
waiters into Hunt/Siege and the support mechanic goes unused. If clearly worse,
the Tear line is dead. This is the number to tune first.

## 2.4 Composes with

Humbaba's **Muster the Faithful** — 2 free Penitent Marchers per round is a Tear
every few rounds if they survive. That gives Muster a real identity rather than
a stray power.

---

# 3. PILLAGE

## 3.1 Rule

**If the enemy has no active Castles, choosing Siege becomes Pillage.**

* Commit cards normally.
* Targets the Castle zone even though no structure remains.
* Existing Castle Guards defend it. Guards may still be placed in the zone.
* A Castle Ward may defend against it.
* Castle-lane waiters contribute normal support and are consumed.
* On success: **1 Soul.** No Integrity damage. No bonus for excess.
* Counts as `Siege` for bot planning, history, and `was_sieged`. "Pillage" is
  presentation.
* One Soul per round maximum.
* Not available while any active Castle stands.

UI: the Siege button reads **PILLAGE** when the enemy has no active Castles.

## 3.2 Rationale

A player must not be able to close off an entire attack path. Zero Castles means
the Castle lane is still attackable. How they reached zero is their business.

This explicitly does **not** distinguish Ruined from self-Profaned. Making
self-Profaned Castles Pillage-immune would turn Profane into a defensive
ability — spend your Castles, gain Dominion progress, and permanently shut down
half the enemy's attack surface. That is a worse distortion than the one it fixes.

It also gives orphaned Castle Guards a coherent reason to exist. Observed state:
0 active Castles, 3 Castle Guards. The Castles are gone; the defenders are still
guarding the ruins.

## 3.3 Before building

**Check `castleless_siege` (currently `False`) and `castleless_tear_neutral`
(currently `True`).** A castleless Siege path may already exist, in which case
Pillage is a payout change rather than a new mode. Do not build a second
implementation of an existing switch.

## 3.4 Rate interaction — must be set together

Pillage is the attacker's only way to keep scoring Souls **without** feeding the
Veil, because it doesn't force a resummon. Against a castleless Dominion player,
Pillage may become correct not for its speed but because it declines to arm them.

Write both rates down before tuning either:

* Souls per round from Pillage (proposed: 1, contested by Guards)
* Souls per round from the Hunt → Banish → resummon cycle (observed: ~2 per
  Banishment, plus 1 Neutral Tear to the opponent)

If Pillage is meaningfully slower, Hunt stays correct while the throne is
occupied and Pillage is what you do in the gaps. If competitive, Pillage becomes
the safe line and the Veil never fills.

---

# 4. SIEGE ENGINE REWORK

## 4.1 Rule

Replaces the passive **Forge Discipline** modifier.

**At the start of each round, after Repair resolves, the Siege Engine fires for
2 damage against one enemy structure.**

* **Acquisition is random.** The Engine picks its target without player input.
* **Targeting persists.** It fires at the same structure each round until that
  structure is Ruined, then acquires a new target at random.
* Fires only while the Engine itself is operational
  (`castle_operational_floor = 7`).

## 4.2 Why persistence

Random-every-round spreads ~26 damage over a 13-round match across
`max_castles = 3`. That is ~8.7 per structure against 21 Integrity. Nothing is
ever Ruined and nothing crosses the operational floor. It is noise.

Worse, `repair_token_integrity = 3` means one repair action out-heals 2 damage
comfortably, so against any repairing opponent the net contribution is near zero.

Persistence fixes all of that:

* It actually kills. 21 Integrity at 2/round is ~11 rounds — slow, but real, and
  it accelerates as targets run out.
* The defender gets a decision. They can see what it has ranged on and repair
  that, or let it go and spend elsewhere. Random targeting gives them nothing to
  play against.
* It keeps `profane_requires_full_integrity` playable. Under random spread every
  structure sits perpetually off full and Profane is quietly dead. Under
  persistence, one Castle is being chewed and the others can sit at full, so
  Profane becomes a positioning problem instead of an accidental shutdown.

The fiction holds: a siege engine ranges in. It fires wild, corrects, and keeps
hammering the same wall.

## 4.3 Fire after Repair

If the Engine fires before Repair, the defender covers the damage in the same
round and it costs them only a token they were probably spending anyway. Firing
after means the damage sits on the board until next round and they must spend
ahead of it.

With `castle_action_limit = 1`, repairing the Engine's target is the *only*
maintenance the defender does that round. That tax is the primary effect —
larger than the damage number suggests.

## 4.4 Open

* Re-acquire on Ruin only, or also when a target reaches full Integrity
  ("it lost interest")?
* Where does Profane resolve relative to Repair and Engine fire? This decides
  whether the Engine soft-locks Dominion on its target or merely delays it.
* **Deimos — War Machine** was written against a passive modifier. It now grants
  an extra firing of a persistent damage clock. The power's magnitude has moved;
  re-evaluate. Reload state still unformalized.

---

# 5. PASSIVE CONSTRUCTION

## 5.1 Rule

**Construction no longer takes committed cards.**

* Choose one Castle as the build target.
* It gains Integrity automatically each round.
* When it completes, choose another target. It does not auto-advance.
* Optionally accelerate by spending cards at **3 card value : 1 Integrity**,
  matching the Marcher conversion rate.

## 5.2 Repair or build, not both

Reinstate the single castle action. `castle_action_limit = 1` — each round you
either Repair or push the build.

**Repair tokens are exempt from Construction.** Tokens patch; cards accelerate.
Without this, tokens become a universal castle currency and the choice between
the two lines degrades into scheduling rather than a real tradeoff. It also
prevents a banked-token rush skipping most of the build.

## 5.3 Rate

Target shape: **4 of 5 Castles built by game end without intervention, with the
5th reachable by pushing.**

At 21 Integrity, matches running 11–13 rounds:

| Rate | Rounds per Castle | Castles by R13 |
|---|---|---|
| 2/round | 10.5 | 1 |
| 3/round | 7 | 1, with the 2nd landing ~R14 |
| 4/round | 5.25 | 2 |

**Pin down what "built" means first.** Reaching `castle_operational_floor = 7`
and filling all 21 are a 3x difference in the answer. If operational-at-7 is the
bar, both rates above are far too fast.

If the bar is 21, **3/round** fits the stated target better than 4 — at 4 both
Castles complete by default and acceleration becomes decoration rather than the
thing that closes the gap.

## 5.4 Why this shape

It fixes `FULL = 100%` by deleting the broken decision rather than repairing it.
The bot cannot dump five cards into a Stockpile if there is nothing to dump.

The accelerator must stay deliberately inefficient. If paying cards is
*efficient*, players do it every round and the removed decision returns with
extra steps. The passive rate is the good deal; paying is what you do when you
need it now.

Compare against `repair_token_integrity = 3` with `repair_exempt_suit = Wright`
untaxed. If acceleration costs 9 card value for the same 3 Integrity a token
gives cheaply, nobody accelerates. Repairing what you have should beat building
what you don't — but not by so much that the accelerator is dead on arrival.

## 5.5 Things to watch

**Card economy shift.** Construction currently competes with Commitment for the
same hand. Removing that drain loosens every hand in the game — bigger
commitments, easier repair, easier summon payment. This is a balance change,
not a UI simplification.

**Construction may stop happening.** Repair is cheaper per point and defends
something you already own. With one action between them, and a Siege Engine
chewing a structure every round, there may never be a quiet round in which to
build. If second Castles stop appearing in play, the passive rate needs to run
*outside* the action and the action reserved for acceleration only.

**Engine owner advantage.** A player under Engine fire who repairs makes zero
construction progress. "4 of 5 by game end" therefore holds only for players who
aren't being sieged.

**`max_castles = 3` contradicts a 4–5 Castle target** while
`castle_type_count = 5` and `starting_castles = 3`. Either the cap is stale or it
means something other than it reads as.

---

# 6. CARRIED-FORWARD DEBT

Not part of this addendum's design, but blocking or distorting it.

* **HIGH — Fracture still damages Marcher legacy `value` rather than HP.**
  Marchers moved to HP/Armor and Fracture did not follow. Live bug in the system
  being designed around. Cheap fix; do it first.
* **Bot doctrine cannot see waiters.** No `battlefield_waiter_*` keys appear in
  any terminal snapshot, so the annotation patch is not in the build. The bot
  cannot see chits parked in the lane it is Warding. Every mechanic in sections
  1–3 is invisible to Smart Core until this lands.
* **Snapshots do not record policy identity.** `policy` serializes as
  `{"class": "RefCounted", "script": "<GDScript>"}` — no name, no temperature.
  Given the measured 27.67% divergence between `standard()` and `golden_core()`,
  and that this format backs the goldens, this is a reproducibility hole.
  `rules` serializes 156 fields; policy serializes nothing.
* **Legacy Marching config still present.** `march_threshold`, `march_damage`,
  `march_steps`, `march_suit_bonus`, `march_exception_pair`, and
  `march_max_in_flight = 1` (against 29 observed on field). Confirm inert.
* **Lord Action doctrine surface.** Two new windows across nine Lords with
  bespoke powers is a large doctrine job on top of the waiter gap. Consider a
  generic default — always pass unless a cheap heuristic fires — so the roster
  can ship before doctrine catches up.

---

# 7. IMPLEMENTATION ORDER

1. Fracture HP fix (blocking, cheap).
2. Waiter awareness annotation into doctrine (blocking for anything measurable).
3. `resummon_tear_mode` — single flag, already wired. Measure the Veil curve
   across a batch before adding any other faucet.
4. Siege Engine persistence + fire-after-Repair.
5. Passive Construction + repair-or-build + token exemption.
6. Pillage — after confirming `castleless_siege`.
7. Waiters → personal Tear.
8. Per-Lord Tear policy, then the remaining six Lord passes.

Turn on one faucet at a time. Resummon Tears alone flip an observed match; the
combination of resummon Tears, waiter Tears, Profane, existing Neutral sources,
and nine per-Lord lines all feeding a track of 12 could easily overshoot into
every match ending by Dominion around round 8.
