# Corruptor — Final Blows and the Final Rite

> **Withdrawn in full — 2026-09-16:** [Permanent Breaches v0.2](Corruptor-Veil-Permanent-Breaches-Proposal-v0.2.md) supersedes this proposal. The finishing-Hunt requirement, final rite, four-suit ritual circle and banishment/postponement sequence are no longer pending designs. The text below is retained as history only.
**Theoretical design v0.1 · 2026-09-16**

**Status: discussion proposal only. Not implemented or approved for balance.** This document records the proposed endings for Ritual and Dominion, including the latest four-suit defensive payment. It does not change the current rules, authorize implementation, or interrupt the existing PySim/doctrine work. “Final rite” and “ritual circle” are working descriptions; the final name is undecided.

## Purpose

Victory should have an identifiable final confrontation. Accumulating resources should create an opportunity to finish the battle, with a visible action that the opponent can understand and contest.

A roughly 15–20-minute battle remains acceptable. Five battles can make a 75–100-minute campaign, supported by save-and-quit. These proposals are about making endings more satisfying, not forcing shorter games.

## Current rules versus proposed endings

| Route | Current implemented ending | Proposed ending |
|---|---|---|
| Ritual | At the end-of-round check, have at least 12 Souls and your Lord present. | Retain those requirements and require your successful Hunt to banish the enemy Lord that round. |
| Dominion | At the end-of-round check, Veil is at least 12; you have at least 5 Personal Tears and more than your opponent. | Those resources qualify you to prepare a paid, telegraphed final rite. Survive the response round and complete it while still qualified. |
| Final Collapse | At Veil 26, the player with more Souls wins; seat 0 wins a Soul tie under current rules. | No replacement proposed here. Its timing against a pending final rite remains an explicit question. |

Current victory precedence is Ritual, then Final Collapse, then Dominion. That is an implementation baseline, not a settled answer for every new simultaneous-finale case.

## Ritual: the finishing Hunt

Keep the Soul threshold at **12 after resolution**. A successful Hunt already grants its attacker 2 Souls and removes 1 from the banished opponent, floored at zero.

The intended example is:

1. Enter the round with 10 Souls.
2. Successfully Hunt and banish the opposing Lord.
3. Receive 2 Souls, reaching 12.
4. Win at the end-of-round check if your own Lord remains present and you still have at least 12 Souls.

No numerical threshold reduction is needed. Lowering the post-Hunt threshold to 10 would allow qualification from only 8 beforehand.

Reaching 12 through Siege, artillery or another source would set up a finishing Hunt instead of winning automatically. The arithmetic is preserved, but the added requirement can lengthen games and change matchup balance.

**Proposed starting interpretation:** the banishment must come from that player's Hunt in the current round. An already-absent enemy Lord does not satisfy it. Whether any other banishment source should count remains open.

## Dominion: prepare, reveal, defend, complete

A final rite fits Dominion's flavor without relying on surviving Castles. Many matches exhaust the Castle supply through destruction or Profaning, so Castle destruction is not a reliable mandatory finishing action. A Castle/Pillage finish was considered and set aside in favor of the rite.

### Timing direction

| Time | Intended behavior |
|---|---|
| Commitment in round N | Prepare the final rite alongside the other rites. Reserve/pay its cards through the normal sealed commitment flow. |
| End of round N | Reveal preparation publicly. Do not award Dominion victory that round from the new preparation. |
| Entire round N+1 | Display the pending rite. The opponent has the whole round to win on their own terms, remove qualification, or banish the caster to postpone completion. |
| End of round N+1 | After both players' actions and Marching settle, complete the rite if its conditions are met. |

This replaces the earlier suggestion to announce preparation at the start of planning. The chosen discussion direction is commitment in the previous round, with the explicit warning at that round's end.

**Starting assumption to test:** preparing requires the usual Dominion qualification and a present Lord. Completion rechecks Veil 12+, at least 5 Personal Tears, a strict Personal Tear lead, and the caster's Lord being present. Exact admission timing and what happens if the Lord is banished between commitment and preparation reveal are not yet settled.

Preparation is not victory by itself. It is a public threat that asks the opponent to respond.

## Four-suit payment: cards defend the caster

The latest proposal is to pay **four cards: one Penitent, one Wright, one Vulture and one Butcher**. Those particular cards become temporary, individually destroyable defenses for the Lord.

The payment has two purposes:

- It makes the finale a deliberate investment rather than a free confirmation button.
- It gives the preparing player a defensive layer against the full round of telegraphed counterplay.

The paid cards cannot simultaneously be committed to attacks, ordinary Guard placement, other rites or saving. Their exact identities and remaining defenses must be tracked; the protection must not duplicate cards still usable in hand.

### Suggested first-playtest behavior — not yet settled

- Each card defends using its printed value, with no extra flat defense bonus.
- The four cards form a separate ritual-circle layer behind ordinary Lord Guards.
- They can be destroyed individually; destroyed cards stay gone.
- They do not activate defensive pair abilities or supply Work.
- Surviving cards remain while the rite is postponed.
- Losing the ritual cards does not itself cancel the rite. They protect the caster; they are not four mandatory components that must all survive.

This is an additional layer, not an increase in ordinary Guard-slot capacity. Exact damage ordering relative to Sigils, Ward, Keep interception and Lord defense must be specified before implementation. So must card ordering within the circle, damage carryover, and whether ordinary Guard-specific powers can target it.

**Suggested reveal baseline:** the paid cards' suits and values become public with the prepared rite. Activating the layer at that same end-of-round reveal would make it available for the full response round without granting surprise protection earlier in round N. This activation detail remains a proposal.

## Banishment postpones completion

The working proposal requires the caster's Lord to be present when the rite completes. Banishment postpones the attempt rather than deleting its preparation.

Under the initial interpretation:

- Preparation survives banishment.
- Remaining ritual cards stay attached to that pending preparation.
- After the Lord returns, the rite may complete at an eligible end-of-round check; it does not require another full preparation round or another four-card payment.
- Losing the Tear lead or another qualification blocks completion. Retaining preparation during that loss is a suggested baseline to test, not a settled rule.

A possible recovery line is to remain banished for a round, save a useful card, then resummon and commit heavily to Ward.

The concern is a losing loop: repeated banishments and resummon costs could make recovery effectively impossible. The four-card circle is the current proposed answer to test first.

**Fallback experiment only:** banishment delays the rite by one round, after which Lord presence is no longer required. This was discussed as an escape from an indefinite lock; it is not part of the initial model and should not be silently combined with it.

## Counterplay and presentation

The preparing player must balance the four-suit cost, existing Guards, Ward, resummoning needs and the Tear lead. The opponent can attempt a finishing Hunt, pursue another victory, or change the resource position.

The pending rite should be unmistakable:

- A persistent indicator near the caster, with “Completes after this round” or the earliest eligible round.
- Four visible ritual cards showing which defenses remain.
- A clear postponed state and reason, such as “Lord banished” or “Personal Tear lead lost.”
- Forecasts that include the supported defensive layer without claiming certainty about hidden orders.
- Aftermath that states who won, by which route, and the deciding action/conditions.

Sealed preparation must not leak through UI or bot observations before its specified public reveal. Once public, both players must see the same rite state. Save/load must preserve the preparation round, earliest completion, payment identities and surviving defenses.

## Questions to settle before implementation

1. **Admission:** must the player qualify when committing, when the rite resolves, or both? Can gains during round N make an earlier declaration valid?
2. **Banishment during preparation:** does the rite fail, become prepared but postponed, or resolve under another rule? What happens to the payment?
3. **Defense:** precisely where does the circle sit, which card is hit first, how does excess damage carry through, and which powers can affect it?
4. **Persistence:** what happens to the circle while the Lord is absent? Where do destroyed or released cards go? Can a player cancel a rite?
5. **Repeated attempts:** allow only one pending final rite per player? Can its defenses ever be replenished? Suggested starting point: one preparation, no stacking or replenishment.
6. **Simultaneous outcomes:** a qualifying Ritual Hunt during the response round, Final Collapse, or opposing pending rites must have explicit resolution precedence.
7. **Same-round return:** if the caster is banished and returns before the completion check, is presence at that check sufficient?
8. **Naming and effects:** choose the rite's name and presentation after the timing and counterplay work.

## What to measure

Compare the existing automatic endings with the proposed final actions using the same seeds and crossed seats, once the relevant mechanics and competent policies are supported.

Record:

- Time from first qualification to victory.
- Preparation frequency and how often four different suits are available.
- Whether players use low-value payments or hoard high-value cards for the circle.
- Completion on the first eligible round versus postponements.
- Repeated banishments, resummon spending and whether recovery actually happens.
- How often four extra defenses plus Ward make interruption unrealistic.
- Victories through another route during the warning round.
- Games where an absent Lord prevents a finishing Hunt for an excessive duration.
- Match length and Lord matchup changes.

Start with small scenario playtests: low/high-value circles, empty/full ordinary Guard zones, Ward, delayed resummoning, lost Tear leads, and a pending rite near Final Collapse.

If the design is adopted, specify authoritative Godot behavior first, mirror it in PySim, and extend save/replay, doctrine and presentation coverage. This document makes no claim that the proposed finale mechanics exist or have passed those gates.
