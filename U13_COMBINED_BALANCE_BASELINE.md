# Combined theater balance baseline — 2026-09-24

Built on remote u13-basic-doctrine 8dee0ab, retaining opponent-memory doctrine, plus the saved Ward/Embolden playable patch.

## Selected rules

- Embolden: staged 10/15/20% per empty enemy guard slot, with newly empty slot grace; fractional stats preserve wounds.
- Successful Ward converts the attacking cohort's newly recruited regular marchers; monsters are excluded.
- Ritual: 15 Souls and a living Lord. Dominion: 7 personal Tears, strict lead, Veil 12. Attack bonus thresholds: Veil 15/19/23. Round limit: 25.
- Kroni's full kit and Hunger-aware opponent Hunt doctrine remain enabled.
- Orias retains Hunt/Mark doctrine.
- Kalligan: Forge restores 2 Integrity; Pyroclasm deals enemy damage 2/3/2 by Inferno stage, while Inferno deals 1/2/1. Friendly damage is 0/1/0 for both. Base defense remains 4. A castle reaching 1–6 Integrity can earn a personal Tear on full repair, then rearm on a new defunct episode. Ruined castles cannot repair. Repair/Wright doctrine is enabled.
- Gremory: support-aware Predator placement, two Vultures. Each individual Predator Vulture earns at most one lifetime personal Tear after two qualifying enemy marcher combat kills while Gremory is alive. No pair pooling; at most one payout per player per round. A blocked unit must kill again later. Ordinary Vulture once-per-round card draw remains separate; no neutral Tear payout.
- Humbaba is unchanged. No experimental performance patch or unselected lord buffs are included.

## Verification

116 focused Python checks passed across Gremory, Embolden, conversion, victory, shared balance, marching, split Ward, Orias, opponent memory, and Kalligan tactics. Four complete smoke games finished with 14 Ward conversion events and no invalid actions. These are integration checks, not a balance sample.

Godot was unavailable, so native runtime verification remains outstanding. Older native Gremory/Kalligan test runners still contain pre-change reward expectations. The archived Python Kalligan replay suite also contains obsolete pre-split-Ward fixtures and damage expectations; it is not included in the 116 passing checks.

The next large balance run has NOT been launched. Old win rates were measured without this combined defensive-pressure environment and must not be treated as predictions for it.

## Humbaba audit lead

In the previous balanced 96 non-mirror games, Humbaba won 32. Muster was selected on 659/690 available opportunities (95.5%). Endurance paid 90 neutral Tears across 1,547 round-end checks (0.94/game); Breath healed 470 HP over 358 casts. Investigate effective placement and movement value before increasing cast frequency. No Humbaba change is included.
