# CORRUPTOR U13 — KANIFOUS POWER ADDENDUM
## The Wishmaster
**Status:** Accepted U13 design / replaces prior Wishmaster Chest concept; implementation pending  
**Source date:** 2026-09-08  
**Accepted name:** The Wishmaster (2026-09-09)

Power-list entry: [Kanifous powers](U13_KANIFOUS_POWERS.md). The battlefield object remains a Lamp; the power is named **The Wishmaster**.

---

## 1. Replacement

The prior **Wishmaster Chest** concept is removed.

It is replaced by **The Wishmaster**, a telegraphed battlefield objective that appears one round in advance as smoke, then materializes the following round at an uncertain location within that telegraphed region.

The purpose of the change is to make Kanifous’s battlefield object:
- more thematic,
- more interactive,
- meaningfully contestable through lane presence,
- partially controllable without becoming directly targetable,
- and mechanically tied to Marcher suit identity.

---

## 2. Core Rule

### The Wishmaster

Once per round, Kanifous causes a **Smoke Marker** to appear on the battlefield.

The Smoke Marker telegraphs the region where a Lamp will appear on the following round.

On the next round, at **Marching Start**, the Lamp materializes at a deterministic-random valid point within a fixed radius of that Smoke Marker.

The **first Marcher of either player to touch the Lamp** resolves it.

The Lamp then disappears immediately.

If no Marcher touches the Lamp during that Marching phase, it expires at **End of Marching**.

---

## 3. Telegraph / Spawn Sequence

### Round N — Smoke Telegraph
- A Smoke Marker is created at a deterministic authoritative position.
- The Smoke Marker is public information.
- Players can see its exact center before making their next-round submission.
- The marker indicates a **region of possible Lamp appearance**, not the exact Lamp position.
- The marker should visually communicate the possible spawn radius.

### Round N+1 — Lamp Materialization
At **Step 11: Marching Start**:
- The Smoke Marker resolves into a Lamp.
- The Lamp spawns at a keyed deterministic-random valid position within radius `R` of the Smoke Marker.
- The Lamp should remain within the same lane/region as the telegraph unless later testing deliberately changes this.
- The Smoke Marker disappears when the Lamp appears.

This creates a planning problem:
- players know where the opportunity will be approximately,
- they can choose commitments and lane presence accordingly,
- but they cannot know the exact race outcome before Marching begins.

---

## 4. Claim Resolution

The first Marcher to make authoritative contact with the Lamp becomes the **claimant**.

Only one claimant exists.

On first contact:
1. resolve the Lamp outcome,
2. apply either the Wish or the failure result,
3. remove the Lamp immediately.

No second Marcher may claim the same Lamp.

There is no player prompt after contact.

---

## 5. Wishmaster Failure Chance

When a Marcher claims the Lamp, there is a **10% chance** that the Wishmaster rejects the claimant.

### Rejected Wish
- The claimant is destroyed outright.
- The Lamp disappears.
- No Wish is granted.
- No additional Marcher may attempt to claim that Lamp.

### Successful Wish
- The claimant receives the Wish associated with its Marcher suit/type.
- The Lamp disappears.

The rejection roll must use keyed deterministic RNG so save/load, replay, unrelated random events, and simulation order cannot alter the result.

Recommended key inputs:
- match seed,
- Lamp instance ID,
- claimant Marcher instance ID,
- purpose key such as `WISHMASTER_REJECTION`.

The 10% value is provisional tuning.

---

## 6. Suit-Specific Wishes

### Butcher — Blood Wish
The claimant’s **next attack deals double damage**.

Rules:
- applies to the next actual attack the Marcher makes,
- consumed after that attack,
- does not permanently modify base damage,
- should multiply the normal attack result rather than create a second attack,
- exact interaction with other future damage modifiers should use the shared modifier order.

### Penitent — Iron Wish
The claimant gains **+2 Armor**.

Rules:
- Armor is added to current Armor,
- normal Marching combat depletes it,
- no special duration unless future tuning adds one.

### Vulture — Ghost Wish
The claimant **passes harmlessly through the next two enemy Marchers it would otherwise engage**.

Rules:
- each avoided enemy contact consumes one charge,
- no attack is made by either side during a bypassed contact,
- after two bypasses, normal contact/combat resumes,
- charges persist across the current Marching phase and should survive save/load,
- the effect applies to the specific claimant only.

This is a contact-count effect, not a round-count effect.

### Wright — Mirror Wish
The claimant creates **one additional base Wright**.

Rules:
- the new Wright belongs to the claimant’s current owner/allegiance,
- it spawns at or immediately adjacent to the claimant’s authoritative position using the shared valid-spawn rule,
- it receives a fresh stable Marcher instance ID,
- it copies only the base Wright unit profile,
- it does **not** copy the claimant’s:
  - current HP damage state,
  - Armor,
  - temporary buffs,
  - Wish effects,
  - counters,
  - altered movement state,
  - or other transient/runtime state.
- the created Wright does not itself receive the Lamp Wish.

This prevents recursive cloning and keeps identity/save-replay semantics clean.

---

## 7. Spatial / Tactical Intent

The Wishmaster is intended to reward **lane presence and preparation**, not direct unit selection.

The player does not choose:
- the exact Lamp position,
- the claimant,
- or the exact path to the Lamp.

The player can influence the outcome by:
- recognizing the Smoke Marker one round early,
- committing Marchers into the relevant lane,
- choosing suit composition,
- and building enough presence to contest the objective.

The opponent receives the same telegraph and may contest it.

The desired play pattern is:

> see smoke → decide whether to contest → commit around the region → Lamp appears with bounded uncertainty → Marching determines the claimant → Wish or rejection resolves

The uncertainty should be enough to prevent deterministic optimization, but not so large that the telegraph becomes misleading.

---

## 8. Timing

Proposed U13 timing:

### Round N
**Public-state phase / appropriate automatic hook**
- Smoke Marker is present and visible before submissions lock for the round that precedes the Lamp appearance.

### Round N+1
**Step 11 — Marching Start**
- Lamp materializes inside the Smoke radius.

### Step 12 — Marching
- Marchers move normally.
- First authoritative contact claims the Lamp.

### Step 13 — End-of-Marching Checks
- If still unclaimed, the Lamp expires.

Exact Smoke creation hook may be attached to Kanifous’s automatic once-per-round battlefield-object system, but must preserve the requirement that players see the Smoke before choosing the submissions that can contest the next Lamp.

---

## 9. Determinism / Identity Requirements

The Lamp system must use stable authoritative identities for:
- Smoke Marker instance,
- Lamp instance,
- claimant Marcher,
- Wright clone if created.

The Lamp spawn offset must use keyed deterministic RNG.

Recommended purpose keys:
- `WISHMASTER_SMOKE_POSITION`
- `WISHMASTER_LAMP_OFFSET`
- `WISHMASTER_REJECTION`

Unrelated RNG calls must not shift Lamp position or rejection results.

All active Lamp/Smoke state and claimant Wish state must serialize and restore exactly.

---

## 10. Event Requirements

Recommended authoritative events:
- `WISHMASTER_SMOKE_CREATED`
- `WISHMASTER_LAMP_SPAWNED`
- `WISHMASTER_LAMP_CLAIMED`
- `WISHMASTER_REJECTED`
- `WISHMASTER_WISH_GRANTED`
- `WISHMASTER_LAMP_EXPIRED`
- `WISHMASTER_WRIGHT_CREATED`
- `WISHMASTER_VULTURE_BYPASS`

Events should identify:
- Lamp instance ID,
- claimant Marcher ID where relevant,
- owner,
- suit/type,
- Wish result,
- authoritative position where useful.

Public event projection must not reveal hidden information before it becomes player-visible.

---

## 11. Recommended Acceptance Tests

At minimum:

1. Smoke appears one round before the Lamp.
2. Smoke center survives save/load exactly.
3. Lamp spawns only within the allowed radius.
4. Lamp remains in the intended lane/region.
5. Lamp position replays identically.
6. First contact wins even when multiple Marchers approach on the same tick.
7. Deterministic tie ordering is explicit.
8. Lamp disappears after first resolution.
9. Unclaimed Lamp expires at End of Marching.
10. 10% rejection destroys claimant and removes Lamp.
11. Rejection replay is deterministic.
12. Butcher double damage applies once.
13. Penitent receives exactly +2 Armor.
14. Vulture bypasses exactly two enemy contacts.
15. Bypassed enemies do not attack the Vulture.
16. Wright clone gets fresh identity.
17. Wright clone receives only base Wright state.
18. Wright clone does not inherit the Wish.
19. Save/load preserves all temporary Wish state.
20. Allegiance changes after receiving a Wish preserve the Wish on that Marcher unless another rule explicitly strips it.
21. Later spawns cannot retroactively claim an already-resolved Lamp.
22. Smoke/Lamp state never creates a post-submission prompt.

---

## 12. Tuning Knobs

Keep these data-driven:
- Smoke-to-Lamp delay: currently 1 round.
- Lamp spawn radius `R`.
- Valid sub-region / lane bounds.
- Rejection chance: currently 10%.
- Butcher damage multiplier: currently ×2.
- Penitent Armor gain: currently +2.
- Vulture bypass charges: currently 2.
- Wright copies created: currently 1.

Do not tune these from small Random-Legal samples alone.

---

## 13. Design Intent Summary

The Wishmaster should feel like **Kanifous planting a temptation into the future battlefield**.

It is not a free Kanifous reward.

Both players:
- see the opportunity coming,
- can prepare to contest it,
- may shape which Marcher suits approach it,
- but cannot fully control who reaches it first or whether the Wishmaster accepts the claimant.

The mechanic should create a small, visible battlefield race that rewards planning while preserving Kanifous’s identity as the Lord of dangerous bargains and uncertain wishes.
