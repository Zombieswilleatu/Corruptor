# Kanifous — U13 power list

**Status:** Design reference; Kanifous implementation pending.
**Amended:** 2026-09-09.

Carried forward from Section 5.9 of the 2026-09-08 U13 Astra handoff, with
only the passive battlefield-object entry replaced by the accepted addendum.
The active Wish system, delayed Prices and Breach entry below are retained.
The catastrophic Price also called The Wishmaster remains a separate Price outcome.

Core:

- Wish is umbrella active system.
- Invoke is dead.
- Kanifous is roster's primary genuine RNG Lord.
- Price delay is random 1–3 rounds.
- Multiple outstanding Prices are allowed.
- Heavy Prices create Neutral Tears.

### WISH — Lord System

**DECLARE:** choose one Wish and all required targets during normal submission.

Maximum **1 Wish per round**.

Each Wish has its own deterministic firing point.

On a **successful** Wish:

1. create a Price;
2. randomly schedule due 1–3 rounds later;
3. publicly show due round;
4. keep actual Price hidden.

Multiple Prices may coexist and may come due together.

### WISH — POWER

**DECLARE:** choose lane.  
**FIRES:** Step 10A.

Spawn **3 random-suit Marchers** in selected lane.

Weights tunable.

### WISH — LONGEVITY

**DECLARE:** choose Castle not Ruined/Profaned.  
**FIRES:** Step 10F after combat.

Restore Castle to **full Integrity**.

May restore from 1 Integrity.

May restore a **Defunct Castle** to full and standing.

Cannot restore Ruined or Profaned.

If target becomes Ruined/Profaned before fire: Wish fails, no Price.

### WISH — RESURRECTION

**DECLARE:** choose Lord Guard zone or Castle Guard zone.  
**FIRES:** Step 10F after combat.

Restore every Guard from selected zone Defeated **this round**.

Normal printed values/ownership.

No previous-round losses.

If no eligible Guards: Wish fails, no Price.

### WISH — DEATH

**DECLARE:** targeting circle on Marching field.  
**FIRES:** Step 10F.

Destroy **every Marcher** inside, friendly/enemy.

Outright destruction, not ordinary damage.

Radius tunable.

### WISH — WEALTH

**FIRES:** Step 10F / Post-Resolution.

Draw **2 cards**.

### THE PRICE OF WISHES

Every successful Wish creates a delayed Price.

When due:

1. determine currently valid outcomes;
2. randomly select using weighted table;
3. resolve automatically;
4. if Price is **Stone, Soul, Ruin, or The Wishmaster**, place 1 Neutral Tear.

Invalid outcomes are excluded/rerolled among valid pool.

No Price asks for input.

#### COMMON — CARDS

Discard **2 cards**. If fewer, discard as many as possible. No Tear.

#### COMMON — BLOOD

Destroy **2 of Kanifous's Marchers** randomly. No Tear.

#### UNCOMMON — GUARDS

Defeat one random eligible Kanifous Guard. **No Tear.**

#### UNCOMMON — STONE

One random standing Kanifous Castle loses **5 Integrity**. **+1 Neutral Tear.**

#### RARE — SOUL

Lose **1 Soul**. **+1 Neutral Tear.**

#### RARE — RUIN

Set one random valid standing Kanifous Castle **Defunct**. **+1 Neutral Tear.**

#### CATASTROPHIC — THE WISHMASTER

**Banish Kanifous. +1 Neutral Tear.** Very rare.

Working weight hierarchy:

- most common: Cards / Blood
- less common: Guards / Stone
- rare: Soul / Ruin
- very rare: Wishmaster

Exact probabilities tunable.

### MULTIPLE PRICES

Each due Price resolves independently. Multiple qualifying Prices due together may generate multiple Neutral Tears.

### THE WISHMASTER — Passive battlefield objective

Once per round, create a public Smoke Marker at an authoritative position. It
telegraphs the region in which a Lamp will appear one round later. Players see
its center and possible spawn radius before choosing submissions that can contest
that Lamp.

At **Step 11: Marching Start** of the following round, materialize the Lamp at a
keyed deterministic-random valid point within radius `R`, in the telegraphed
lane/region, and remove the Smoke Marker.

At **Step 12: Marching**, the first Marcher of either player to make authoritative
contact claims it. Resolve once and remove it immediately. There is no player
prompt and no second claimant.

- **10% rejection:** destroy the claimant outright; grant no Wish.
- **Otherwise:** apply the claimant's suit-specific Wish.

| Claimant | Wish |
|---|---|
| Butcher — Blood Wish | Next actual attack deals ×2 normal damage; consumed once, not a second attack. |
| Penitent — Iron Wish | Add +2 current Armor, depleted by normal combat. |
| Vulture — Ghost Wish | Bypass the next two enemy Marchers it would otherwise engage; neither side attacks on those contacts. |
| Wright — Mirror Wish | Spawn one additional base Wright at/adjacent to the claimant through shared valid spawning, with current allegiance and a fresh stable ID. No copied damage, buffs, Wish charges or transient state. |

An unclaimed Lamp expires at **Step 13: End-of-Marching Checks**. Wish state,
Smoke/Lamp identities and positions serialize exactly. Unrelated RNG draws cannot
change spawn or rejection outcomes. Tie ordering must be explicit and deterministic.

This replaces the immediate random Chest and its **draw 1 card** reward.
The complete rules, timing requirements, tuning knobs and 22 acceptance cases are
in [The Wishmaster addendum](U13_KANIFOUS_THE_WISHMASTER_2026-09-09.md).
Exact Smoke creation hook, radius and simultaneous-contact tie rule remain
implementation decisions; this amendment does not invent their values.

### BREACH — THE VOID

While Kanifous is in the Breach, board is presented as though viewed from other side of Veil.

Authoritative state remains exact. Presentation obscures precision rather than lying with false exact numbers.

Examples:

- Castle Integrity -> HEALTHY / DAMAGED / CRITICAL;
- Marcher exact HP/Armor hidden -> approximate bars/states;
- Guard info partially obscured/unstable (degree still presentation tuning).

Possible visuals: unstable numerals, spatial distortion, displaced/reversed depth, glyph substitution, Veil interference.

The Void attacks certainty, not rules state.

**Identity:** bargains, random gifts/debts, heavy prices tearing reality, unstable Void.
