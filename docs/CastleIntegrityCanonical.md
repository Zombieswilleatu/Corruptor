# Castle Integrity — Canonical Python Oracle Contract

**Rules version:** `6.9.0-castle-integrity`
**AI policy:** `heuristic-2026.08-castle-integrity`
**Scope of this slice:** Python oracle, tests, telemetry, and historical-trace compatibility. Godot and playable UI follow after the oracle is accepted.

## Canonical rules

### Starting loadout and expansion

- Each player starts with **any three of the five unique Castle types**.
- No Castle is mandatory.
- Three is an opening-loadout size, **not an active Castle cap**.
- The two unchosen types may be constructed later, allowing a player to control all five types.
- Bots take the first three entries in their Lord-specific `CASTLE_PRIORITIES` until the pregame picker exists.

### Integrity

- Every Castle has **14 maximum Integrity**, regardless of its former printed DEF.
- Integrity is remaining structural strength, not a defense threshold.
- Once combat reaches the structure layer, all arriving Strength is dealt directly as Integrity damage, minimum 1.
- A standing Castle and its power remain active while Integrity is above 0.
- At 0, its type is permanently **Ruined** and cannot be repaired or reconstructed.
- Integrity replaces Castle scarring and the legacy second-destruction permanent-loss system.

### Layer order

- Ordinary Siege: `Guards -> Sigil -> temporary structural screen -> Integrity`.
- Siege Engine bypass: `Sigil -> temporary structural screen -> Integrity -> Guards`.
- In a structure-first attack, Integrity absorbs arriving Strength first. Strength beyond remaining Integrity spills into Guards.
- The resolver records incoming structural Strength, actual Integrity removed, and spill separately.

### Repair

- A player receives one Repair **or** Construction action per round.
- Repair chooses one damaged, standing Castle.
- Any number of cards may be paid from Hand and/or Garrison.
- Restore Integrity equal to paid value, capped at 14; excess restoration is lost.
- Repair modifiers trigger once per action and affect Repair only:
  - Repair Token: `+3`, then consume it.
  - Master Builder: `+2` while living Kalligan repairs.
  - Rapid Construction: `+1` while Kalligan is the Breach.

### Construction

- Construction may target an unowned Castle type that has never been Ruined, Profaned, or otherwise permanently lost.
- Payment may come from Hand and/or Garrison.
- Progress is granular and persists between rounds.
- The requirement is **14 total value**.
- At 14, the Castle enters play at full Integrity and its power becomes active.
- There is no active three-Castle cap; unique type ownership is the natural ceiling.

### Ruination economy

- Partial Integrity damage grants no Souls or Tears.
- An enemy Siege that reduces a Castle to 0 grants **+1 Soul above the existing Siege reward**.
- Profane, Humbaba's Toll, Gremory's Inevitable Ruin, Final Collapse, and other non-Siege or self-Ruination effects do not receive this bonus.
- Complete Ruination retains existing Neutral Tear and Lord-trigger behavior unless separately specified.
- Profane has no standing-Castle-count gate in this profile.

## Doctrine correction

Castle-count doctrine normalizes against all five buildable types:

- 0 Castles = 0.0
- 3 Castles = 0.6
- 4 Castles = 0.8
- 5 Castles = 1.0

The opening loadout count must never be used as the denominator after expansion.

## Required telemetry

The oracle reports:

- Integrity damage and restoration
- Repair actions, cards, and paid value
- Construction actions, completed Castles, and paid value
- Fraction of games with zero construction
- Average round of first construction
- Castles standing at game end
- Complete Ruinations and repair-to-Ruination ratio
- Structure-first bypass frequency
- Momentum triggers
- Ritual, Dominion, Collapse, Lord, and matchup results

## Migration discipline

1. Accept and validate the Python oracle.
2. Port identical state and resolver behavior to Godot.
3. Compare old traces against the new engines and account for every divergence.
4. Regenerate canonical goldens only after Python and Godot agree.
5. Add pregame selection, per-Castle Integrity, Repair, Construction, and narration to the playable UI.
6. Re-baseline lock and pool balance before revisiting Lord kits.

Valak's proposed rework is intentionally excluded from this migration.
