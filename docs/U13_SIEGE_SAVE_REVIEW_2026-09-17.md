# Siege pacing review — 2026-09-17

## Scope and method

Reviewed three locally available saved games, using their recorded events rather than replaying them under changed rules. There are 41 resolved Sieges against castles across both players. One successful Pillage in the September 15 game is excluded; Hunts and automatic Siege Engine shots are separate actions. The two older saves predate permanent Veil breaches and monsters, so this is descriptive evidence, not a controlled balance comparison.

Attack strength comes from `SIEGE_STARTED`. Each consumed Supplicant contributes +1; subtracting their count gives card strength. Card counts come from the matching sealed order. Castle damage includes both the selected target's `SIEGE_RESOLVED.damage` and the defending Bastion's `BASTION_SCREENED.damage`. Counting only the former incorrectly labels Bastion hits as zero-damage attacks.

## Both players, per castle Siege

| Save / match | Sieges | Cards committed | Attack from cards | Attack from Supplicants | Total attack | Castle HP damage | No castle HP damage |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Sep 15 — Kalligan / Valak, round 18 | 14 | 5.21 | 14.14 | 0.00 | 14.14 | 6.43 | 2/14 |
| Sep 16 — Kanifous / Valak, round 12 | 13 | 4.23 | 11.62 | 0.15 | 11.77 | 5.15 | 4/13 |
| Sep 17 — Kalligan / Gremory, round 18 | 14 | 4.00 | 10.86 | 0.50 | 11.36 | 2.43 | 8/14 |
| All three | 41 | 4.49 | 12.22 | 0.22 | 12.44 | 4.66 | 14/41 |

The 41 attacks also defeated 67 Guards. Zero castle HP damage therefore does not necessarily mean no progress. Of the 27 attacks that reached castle HP, the mean hit was 7.07 damage. Total damage was 191: 131 to selected targets and 60 to protecting Bastions. Only nine Supplicants contributed across all 41 attacks.

## Latest game: the human player's attacks

Player 0, Kalligan, made 13 Sieges: 4.15 cards, 11.08 card attack, 0.54 Supplicant attack, and 11.62 total attack on average. Actual castle damage averaged 2.62. Seven of the 13 attacks dealt no castle HP damage; six did. They defeated 21 Guards overall.

The total was 34 castle damage: 18 to the Bastion (6 in round 1, 3 in round 3, 9 in round 11) and 16 to the selected Keep (4 in round 14, 8 in round 15, 4 in round 17). Gremory's only Siege dealt no castle damage; most of that player's attacks were Hunts.

In round 13, three cards provided 4 attack and seven Supplicants added 7, for 11 total. The opposing Ward also provided 11 and stopped the attack before Guards or castle HP. The Supplicants were consumed as automatic attack support, not killed before an accepted Tear conversion.

Repair materially extended the defenses. Kalligan's Keep regained 40 HP: 27 from Forge and 13 from Work. Gremory's Keep regained 14 from Work. These are actual HP gains, excluding construction and capped-away repair. The 40 restored HP supported the Keep against Hunts and other damage as well as any Siege pressure; it is not all attributable to Siege damage. Gremory's Bastion received no repair in this save.

## Interpretation and next balance step

The current baseline is 21 HP per castle. An intact Bastion can absorb another 21 before a Siege reaches a different target. Ward, guard-pair defense, individual Guards and Sigils remove strength before it reaches either building. The latest game also had smaller card commitments than the first saved game and substantially more Ward screening against the human player's Sieges.

A trial at 18 base HP is reasonable, but it would not change the seven human attacks stopped before castle HP. Repeated defense replacement and repair deserve as much attention as maximum HP. These observations do not establish how the same matches would end at a different HP cap, and no HP change is included here.

## Implemented alongside the review

- Gremory's Predator of Ruin now summons two Vultures per use, in both Godot and Python. Its cooldown, timing and lane selection remain the same. Humbaba still summons three Penitents.
- Updated UI wording, smoke instructions, doctrine explanation and regression expectations. The native and Python power rules contain the spawn count and share the updated rules fingerprint, preventing silent continuation with an incompatible rules snapshot.
- Unspent Supplicants already automatically support the matching Hunt/Siege lane. Selecting a group is only required to convert it to a personal Tear before combat.

Supporting event rows and aggregates: [U13_SIEGE_SAVE_REVIEW_2026-09-17.json](evidence/U13_SIEGE_SAVE_REVIEW_2026-09-17.json).

## Validation

Godot 4.5.1 diagnostic checks passed: Gremory (225), marching integration (137), and smoke session/widgets (81). Python's 13 power tests passed, including both lanes for Gremory's two Vultures and Humbaba's unchanged three Penitents. Exported native power rules exactly match Python's rules and the updated full rules fingerprint. `git diff --check` passed. The production launcher still requires Godot 4.7.2 stable; interactive Windows validation remains.

Two stale test assumptions were corrected while running these suites: the delayed Ruin fixture now starts above the existing 14-HP targeting floor, and smoke widget tests explicitly initialize the diagnostic runtime like the existing playable-board tests. Production runtime checks are unchanged.
