# Castle Integrity and Castle Rules — Canonical Python Oracle Contract

**Rules version:** `7.5.0-suit-identities`
**AI policy:** `heuristic-2026.08-castle-contextual-v3`
**Canonical runtime:** Godot `RuleConfig.lab_v6_5()` and Python `activate_ruleset("lab-v6.5")` describe the same locked profile.

The Python balance oracle additionally uses the contextual-v3 doctrine/measurement layer: deterministic named RNG streams, simultaneous commitment snapshots, strategy-aware Castle targeting/maintenance, shared contextual attack-defense estimation, and paired crossed-seat ADD/REMOVE Castle experiments. These are AI/measurement policy, not extra gameplay rules.

The v7.5 suit-identity lock makes the measured Ward tax canonical: non-Penitent cards committed to Ward lose 1 Strength (minimum 1), while Penitent cards Ward at printed value. The global resummon delay remains retired (`resummon_delay_rounds = 0`).

## Starting loadout and Integrity

- Each player starts with any three of the five unique Castle types.
- Construction may later expand the board to all five types.
- Every Castle has **14 maximum Integrity**.
- Integrity is structural HP: once an attack reaches the structure, arriving Strength removes Integrity directly.
- `Operational`: Integrity **7–14**. Printed/identity power is active.
- `Defunct`: Integrity **1–6**. The structure still exists, but its printed/identity power is off.
- `Ruined`: Integrity **0**. The Castle leaves play and is irreparable in this profile.
- **Bastion is the exception to the power gate only in its physical role:** a standing Bastion screens rear Castles even while Defunct.

## Combat layer order

### Hunt

`Ward reinforcements -> Lord Guards -> Sigil -> Lord Defense -> Keep Sanctuary`

### Normal Siege

`Ward reinforcements -> Castle Guards -> Sigil -> Bastion wall (when screening) -> chosen Castle`

The historical Siege Engine structure-first bypass is disabled in the locked profile. Siege Engine now grants Forge Discipline instead.

Ward is no longer a binary pre-combat cancel. Committed Ward cards are temporary reinforcements and remain in place through **both primary actions**, then are discarded before Reflex resolution.

## Castle identities

### Keep — Sanctuary

When a Hunt would Banish the Lord, an **Operational** Keep may Exert the exact lethal excess. If Keep can pay that Integrity without self-Ruining, the Lord survives.

- Equality already survives and costs nothing.
- A one-point lethal excess costs 1 Keep Integrity.
- Exertion may make Keep Defunct but may never self-Ruin it.

### Bastion — physical wall

- Bastion is always a legal direct Siege target.
- While Bastion Integrity is above 0, a Siege aimed at another Castle hits Bastion first.
- Excess Strength carries through Bastion into the chosen rear Castle.
- A direct Siege on Bastion wastes overflow rather than redirecting it to a rear Castle.
- Bastion screening persists while Defunct.
- If Bastion Ruins while screening, it receives the complete normal Castle-Ruination consequence chain before any rear-Castle Ruination is resolved.
- Bastion grants **no Lord DEF bonus** in v7.4.

### Stockpile — Selective Stores

During the normal Draw Step, an **Operational** Stockpile replaces the old raw +1 draw with:

`draw 2 -> keep 1 -> discard 1`

The player still nets one extra card, but gains selection rather than raw volume. The bot values a missing Wright highly and otherwise recognizes Butcher's attack-tax value.

### Summoning Circle — Blood Conduit / Blood Offering

**Blood Conduit:** when positive Threat gain would cross into Threat 2 or higher, an **Operational** Circle may Exert 3 Integrity to prevent 1 Threat. A 0 -> 1 gain does not trigger it.

**Blood Offering:** when Summoning, an **Operational** Circle may Exert 3 Integrity to reduce Summon cost by 3. This applies to the opening Summon and later resummons.

- The old free Circle Summon discount is retired.
- The old resummon-delay exemption is retired.
- **Resummoning places no Tear.**

### Siege Engine — Forge Discipline

While **Operational**, Siege Engine waives the off-suit attack penalty on **Sieges only**. It does not alter combat layer order and does not waive the penalty on Hunts.

## Suit economy

### Ward — Penitent identity

- Penitent cards committed to Ward defend at printed value.
- Every non-Penitent Ward card loses 1 Strength, minimum 1.
- The tax applies to the front-line Ward reinforcement and the Reveal contest; raw printed committed value still determines initiative.
- Keep does not waive the Ward tax.

### Vulture — Reconnaissance

- If one or more Vultures are committed to any primary action, reveal one entire enemy Guard area after Reveal.
- A Hunt scouts Castle Guards first because the attacked Lord Guard area will reveal during combat.
- A Siege scouts Lord Guards first for the same reason.
- Ward and Profane scout the enemy area with more unknown Guards.
- If the preferred area has no unknown Guards, Reconnaissance may fall back to the other area.
- Reconnaissance reveals all Guards currently in the chosen area; Guards added later begin hidden.
- The existing two-Vulture committed-suit bonus remains: two or more committed Vultures draw one card outside the Draw step.

### Attack — Butcher identity

- Butcher attacks at printed value.
- Every non-Butcher attack card loses 1 Strength, minimum 1.
- Operational Forge Discipline waives this penalty on Sieges.

### Repair — Wright identity

- One Repair or Construction action per player per round.
- Repair payment is **strict Wright-only**.
- Restore Integrity equal to legal paid card value plus applicable bounded modifiers, capped at 14.
- Repair modifiers trigger once per action:
  - Repair Token: `+3`, then consume it.
  - living Kalligan Master Builder: `+2`.
  - Kalligan Breach Rapid Construction: `+1`.

### Construction

- Construction targets an unowned type that has never been permanently Ruined/Profaned/lost.
- Progress persists between rounds and requires 14 total progress.
- **At most 5 progress may be gained per Construction action.**
- At 14, the Castle enters play at full 14 Integrity.

### Profane

- A Castle must be at **full Integrity** to be Profaned.
- The old standing-Castle-count gate remains removed in this profile.

## Ruination economy

- Partial Integrity damage grants no Castle-Ruination reward.
- An enemy Siege that Ruins a Castle grants the normal Siege reward plus the locked `+1` Ruination Soul bonus.
- Normal Tear, Gremory, Kalligan, Kroni, scar/loss, and victory hooks all run through the shared Ruination consequence path.
- Bastion screening uses that same path; it is not a special HP-only deletion.

## Doctrine requirements

The Python bot must price the rules it actually resolves:

- Hunt/Siege commitment values use the off-suit attack tax.
- Siege Engine's waiver is priced only for Sieges and only while Operational.
- Rear-Castle Siege estimates include a standing Bastion's Integrity, even when Bastion is Defunct.
- Siege target doctrine normally chooses a rear Castle while Bastion stands so potential overflow is preserved; direct Bastion targeting remains rules-legal.
- Repair doctrine recognizes strict Wright-only legality.
- Construction doctrine honors the 5-progress action cap.
- Summon doctrine sees Blood Offering only when Circle can actually Exert 3.

## Migration and golden discipline

1. Godot `7.4.0-castle-rules-lock` is the locked gameplay target.
2. Python must match the same profile before new balance measurements are trusted.
3. Targeted cross-engine regressions are preferred to blindly blessing whole-game hashes.
4. `golden/lord_matrix.json` may retain older generator-version provenance; that file is a historical DE-v2 deterministic matrix, **not** evidence that the lab-v7.4 Python balance oracle is still 6.9.
5. Regenerate or replace balance goldens only when the specific harness being measured intentionally uses the v7.4 lab profile.

The next balance layer is the full Castle × Lord interaction matrix. Castle powers should not be retuned again before Lord-power interactions are measured on this synchronized foundation.
