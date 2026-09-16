# Corruptor — The Eroding World: Permanent Breach Proposal v0.1

> **Superseded:** See [Permanent Breaches v0.2](Corruptor-Veil-Permanent-Breaches-Proposal-v0.2.md). This version is retained as design history; its five-arrival schedule and references to the separate finale proposal are no longer the current proposal.

Date: 2026-09-16  
Status: Design proposal only. No game rules are implemented by this document.

## Purpose

The Veil should show the world eroding. As it advances, absent Lords permanently enter the Breach and impose their existing Breach effects on the match. The growing combination changes the battlefield, defenses and card economy.

Reuse the established Lord effects and their recognizable identities. The older physical-rift idea—a widening region that slows Marchers—is set aside for this proposal. Breach effects may provide enough escalation by themselves.

This concerns individual battles. Campaign-wide persistence is not specified.

## Direction established in discussion

- Only Lords not participating in the match are eligible for these permanent arrivals.
- Arrival identities and their order remain hidden. The intended experience is “oh fuck, what’s next?”
- Once admitted, an intruder remains for the rest of the battle. Earlier effects continue as later Lords arrive.
- Reuse each existing Breach effect according to its actual timing. Permanent presence does not mean repeating a maximum-Integrity reduction as fresh damage every round.
- Personal Tears mitigate the effects. Full negation is the preferred simple approach for harmful effects; beneficial effects may instead deny or reduce the enemy’s benefit.
- Humbaba retains his entry damage and gains ongoing erosion afterward. Applying that revision to his ordinary Breach is also proposed.
- World erosion and accumulating pressure are intentional. Balance should preserve that purpose.

## Starting numbers — provisional

The current U13 victory track ends at Veil 26; Dominion eligibility begins at Veil 12. These are retained as the initial frame, not newly balanced by this proposal.

Five arrivals were suggested as a starting point. With two distinct participating Lords, seven Lords are eligible, leaving two unused in a five-arrival battle.

| Veil | Proposed event | Proposed Personal Tear protection requirement |
|---:|---|---:|
| 5 | First absent Lord enters | 1 |
| 9 | Second absent Lord enters | 2 |
| 12 | Existing Dominion eligibility threshold | — |
| 13 | Third absent Lord enters | 3 |
| 17 | Fourth absent Lord enters | 4 |
| 21 | Fifth absent Lord enters | 5 |
| 26 | Existing Final Collapse | — |

The exact five thresholds and the 1–5 protection ladder are assistant-proposed playtest defaults, not settled balance. They distribute pressure across the track and leave five points between the final arrival and collapse. Earlier victories should experience fewer than five intruders.

Protection follows arrival position, not Lord identity: under this starting ladder, two Personal Tears protect against the first two arrivals, whichever Lords they are.

## Hidden arrivals and player information

Keep arrival thresholds visible but conceal both the identities and their order until arrival. The earlier suggestion to preview the full sequence was explicitly rejected.

After an arrival, show the Lord, its effect, and each player’s protection requirement and current status. Players can then adapt to a known ongoing threat while later arrivals remain uncertain.

A suggested implementation is a seeded selection without replacement from eligible absent Lords. Whether the sequence is sampled at setup or on arrival is an implementation choice; neither player nor bot should receive unrevealed identities through ordinary observations. Saves and replays must preserve outcomes without exposing hidden information to decision-making.

Personal Tears become insurance against unknown danger. After arrival they also offer a path to escape recurring pressure. One-time arrival damage cannot be undone by acquiring protection later.

## Existing effects and proposed protection

Baseline wording was checked against U13LordRules.gd on branch u13-basic-doctrine at a7544d620376a0a4339825dd5ab85fcdf194dcec. Humbaba’s current 4-damage entry was also checked in U13Humbaba.gd.

The protection column is proposed behavior, not existing implementation.

| Lord / effect | Existing Breach behavior | Proposed protection |
|---|---|---|
| Gremory — Gem Dagger | The first Guard defeated each round makes both players draw 1 card. | A protected player denies the opponent that bonus card. Protection does not remove their own draw. |
| Deimos — Cracked Foundations | All Castles have 5 less maximum Integrity. Ending the ordinary Breach restores the ceiling without healing damage. | Your Castles ignore the maximum-Integrity reduction. Gaining protection should restore the ceiling without healing lost Integrity; confirm in implementation design. |
| Humbaba — The Stones Forget | On entry, deal 4 damage to every exposed Castle, once per entry. | Your Castles ignore both the entry damage and the proposed ongoing damage while protected. |
| Kalligan — Rapid Construction | At round start, both players’ damaged standing Castles restore 2 Integrity. Ruined and Profaned Castles are unaffected. His ordinary Forge-Repair does not stack while he is Banished. | Deny the enemy’s Breach restoration. Alternative raised by the user: reduce their restoration to 1 per Castle per round. Exact choice remains open; full denial is the simpler initial recommendation. |
| Orias — Entanglement | Players at Threat 2+ may deploy no more than 2 Guards total during Development, when the Breach is active before submission. | You ignore the deployment restriction. |
| Odradek — Paradox Geometry | Once per round after combat, randomly change allegiance of one Lord Guard, one Castle Guard, or all Marchers in a small circle around a random Marcher. Only legal transfers are chosen; either side can benefit. | Your units cannot be taken; enemy units may still transfer to you. Mixed-circle selection and legal targeting need explicit rules. |
| Kroni — Insatiable Hunger | Once each Marching phase, manifest at a random field point, move briefly in a random direction and devour Marchers touched from either side, then disappear. Grants no Hunger, Souls, Tears or Ravenous progress. | Your Marchers cannot be devoured by the Breach manifestation. |
| Valak — Gravitational Collapse | All Marchers move at 50% speed while the Breach is active. | Your Marchers ignore this slowdown. |
| Kanifous — The Void | The board loses visual precision; rules and authoritative state remain exact. | Your view remains clear. |

For harmful effects, the default is binary immunity rather than a separate damage or strength reduction formula for every Lord. Partial mitigation remains an option if testing shows complete protection is too strong.

For Gremory, if both players qualify, both bonus draws are denied. Under full-denial Kalligan protection, both qualifying players likewise deny each other’s Breach restoration. Under the alternative partial version, both instead receive 1 restoration per eligible Castle.

Protection targets the Breach contribution, not unrelated effects with a similar outcome.

## Humbaba revision — arrival shock and continuing erosion

Proposed The Stones Forget:

1. On entry, deal **4 damage to every exposed Castle**, preserving the current implemented entry value.
2. On subsequent rounds, deal **1 damage to every exposed Castle** at round start.
3. Do not also apply the recurring 1 damage in the entry round.

The user initially recalled 5 entry damage; the repository confirms 4. This proposal retains 4 rather than silently increasing it.

For an ordinary Breach, recurring damage stops when Humbaba leaves. A later entry triggers a fresh entry hit. For a permanent Veil arrival, the recurring damage continues for the rest of the battle unless a player’s protection shields their Castles.

The ordinary-Breach revision is proposed alongside the new system, not already implemented. Whether Personal Tear protection also applies to ordinary player-Lord Breaches is a separate unresolved scope decision.

The exact round-start position relative to repair and other Breach effects must be set before implementation. Preserve existing exposed-Castle eligibility unless deliberately revised; do not silently include protected construction.

Deimos needs no comparable repeat hit: his reduced Integrity ceiling already lasts while present. It must never become a fresh cumulative subtraction of 5 each round.

## Why this shape

The battlefield becomes less stable as the Veil grows. Lords already familiar to players supply the escalating rules, reducing the need for a second set of unrelated hazards.

Tears serve three connected purposes: advancing the Veil, pursuing Dominion and preparing for the world that is emerging. A player may deliberately accelerate the track while better protected than the opponent, but cannot know exactly which intruder comes next.

Different absent-Lord pools and arrival orders create different battles. Benefits such as Gem Dagger or Rapid Construction also matter: the world changes unevenly, and protection can turn shared relief into an advantage.

Humbaba’s ongoing damage is meant to create real repair pressure. Its interaction with Deimos is part of the eroding-world theme, even though its magnitude must be tested.

## Decisions still needed before implementation

| Question | Current direction / unresolved point |
|---|---|
| Arrival count and timing | Test five at 5/9/13/17/21; numbers remain provisional. |
| Protection ladder | Test 1–5 Personal Tears by arrival order. Decide whether protection tracks current Tears or a permanently earned milestone if Tears can fall. |
| Kalligan protection | Full enemy denial versus reducing enemy restoration from 2 to 1. |
| Ordinary Breach protection | Decide whether Personal Tears protect only against permanent Veil intruders or also against participating Lords’ ordinary Breaches. |
| Trigger boundary | Decide when threshold crossings produce arrivals and whether the threshold-crossing Tear grants protection before an entry hit. Multiple thresholds crossed together need an explicit ordered rule. |
| First recurring trigger | Define when each newly arrived effect starts. Humbaba explicitly has no recurring tick in his entry round. Preserve Orias’s pre-submission legality boundary. |
| Interaction with ordinary Breaches | Permanent intruders may coexist with participating Lords’ temporary Breaches. Define scheduling and source identity without suppressing one accidentally. |
| Odradek protection | Specify legal candidates, protected units in mixed circles and whether immune outcomes are skipped or rerolled. |
| Castle damage and rewards | Retain or deliberately revise ordinary Breach damage consequences, including ruin/defunct behavior, Tears and destruction reactions. Do not assume a neutral intruder awards a player siege credit. |
| Kanifous readability | Decide how visual imprecision remains fair and playable, including bot/public-information treatment, without changing authoritative state. |
| Older Veil penalties | Intended as the new Veil-effects direction, not permission to re-enable disabled legacy penalties on top. |
| Finales proposal | Reconcile timing with the separate theoretical final-rite design if either proceeds. This document does not implement that proposal or alter victory precedence. |

## Focused playtest questions

- How many intruders actually appear before a typical battle ends?
- Does the system make the world feel progressively unstable without making Marching irrelevant?
- Can a player behind in Personal Tears still respond meaningfully?
- Does protection encourage healthy investment, or make Tears mandatory regardless of strategy?
- Does Humbaba plus Deimos eliminate Castles too quickly? Does Kalligan create useful counterpressure or excessive delay?
- Do Kroni and Odradek create dramatic, understandable changes rather than opaque losses?
- Are hidden arrivals exciting enough to justify the inability to prepare for a specific Lord?
- Does accumulated recurring activity materially lengthen resolution time?
- Are ordinary and permanent Breach combinations readable and reproducible?

Record arrival identities/order, round and Veil at arrival, both players’ Tears/protection, damage and units/cards affected, Castle survival, victory route and playtime. Compare ordinary Breaches, permanent arrivals, and the Humbaba revision separately where necessary to identify the cause of a balance shift.

## References and status

- [U13 Lord rules](../Prototype/U13/U13LordRules.gd)
- [Humbaba implementation](../Scripts/Sim/U13Humbaba.gd)
- [Victory rules](../Scripts/Sim/U13Victory.gd)
- [Theoretical final blows and final rite](Corruptor-Finals-Theoretical-v0.1.md)
- [Consolidated roadmap](README.md)

This document records a design proposal. It does not authorize or claim implementation, change current test expectations, or advance this feature ahead of the roadmap’s existing engineering priorities.
