# Kalligan doctrine V25: useful fire and pulse timing

Kalligan now evaluates Scorch's capped Armor/HP damage and kills instead of assigning the same value to every grounded body. This changes bot judgment only; native/Python game rules, damage, targeting, cooldowns and fire lifetime are unchanged.

## Decisions

- Inferno compares both Marching lanes and enemy Castles across its actual 1–2–1 stages. Future benefit is discounted. Damage cannot keep earning value after a target is destroyed.
- Relocation compares moving with leaving the existing fire in place, using only its remaining stages. It does not restart the lifetime. The current lane pulse and any selected Pyroclasm are accounted for before estimating future survivors.
- Castle Scorch has already pulsed when planning begins. Lane Scorch is still due at Marching start, after recruitment. Pyroclasm therefore compares extra-plus-automatic against automatic alone in lanes; a unit that the automatic pulse already kills earns no additional kill credit.
- The low first stage can hold Pyroclasm for the discounted stronger next-stage opportunity. Current extra kills can outweigh waiting. Castle pulses retain immediate damage, destruction and operational-threshold value, after estimated damage from the bot's own attack.
- Complete plans include ordinary recruits, grounded monsters, minimum guaranteed power-spawned bodies and spent Supplicants. Flying units are excluded. Targets that start unattractive can still receive bounded complete-plan evaluation when the bot's commitment changes their value.
- Retention keeps lane alternatives, a Castle alternative and Pyroclasm within the existing four-power target limit. The overall 32-plan/eight-preview limits remain intact.

The packet estimate uses the same incoming-damage modifier as authority and then applies Armor before HP to local copies. Its heuristic weights are 2 per Armor, 4 per HP and 12 per kill. Future stages use a 3/4-per-round discount; public unopposed troops that could reach a gate receive reduced future exposure rather than being assumed gone. Known Forge/Breach repair intervenes between future Castle stages.

This remains a bounded public estimate. Enemy commitments, future draws, combat survival, discretionary repairs, changing protection and death reactions are not simulated. Future damage/kill counts are conditional; no seed or hidden order is read.

## Verification and reviewed replay changes

70 focused Python test methods passed in 16.12 seconds: Kalligan tactics, saved pulse cases, common planner, coordination, recipes/Veil and all nine defense cases. A targeted follow-up also verifies that known Forge repair reduces expected multi-stage destruction value. Directed packet checks compare Armor/HP outcomes with authoritative Scorch, including flying immunity and exposed Dotra damage.

Two four-round smoke games completed in 11.29 seconds: 16 decisions / 203 operations, no invalid actions or rejected previews. Each Kalligan placed Inferno once and used Pyroclasm twice. This is legality and behavior evidence, not a win-rate comparison. No long campaign or new native acceptance run was needed for the unchanged game rules.

Two stale saved-observation pins were reproduced from unchanged parent `6ea2114`. Both full observations matched the V25 working tree exactly. Their original prefixes and recorded opponent plans remain unchanged, and previous hashes are retained in `kalligan_pulse_cases.json`:

| Case | Current observation SHA-256 |
|---|---|
| Kalligan/Gremory round 3 | `7b2ab43b5a8af33b4b66217eadb02ac105040ec6834963582138d87d1af89e30` |
| Second saved pulse case | `dac3e06ed75f45d096029a61507e164bfff90f7fe9ded7e68bcf414946ac28df` |

The first natural case still holds its harmful pulse and keeps its original Kopita/Ward commitment. The second now chooses Pyroclasm with a different Ward/Kurchin commitment. Controlled authoritative continuations of that identical new commitment, with and without Pyroclasm, measured HP damage through the automatic pulse:

| Choice | Friendly HP damage | Enemy HP damage |
|---|---:|---:|
| Hold Pyroclasm | 5 | 7 |
| Fire Pyroclasm | 15 | 26 |
| Extra damage purchased | 10 | 19 |

Neither continuation produced a marcher death in that window. The regression now checks this actual incremental trade rather than requiring the old omission. It does not establish that the new entire plan beats the old Siege over a full game.

The existing counterfactual with friendly troops moved out of the lane now values waiting for the stronger stage. Its positive-pulse case additionally sets the existing enemies to two HP/no Armor, making an immediate extra pulse earn kills. It still verifies that the chosen commitment exposes fewer friendly bodies than the recorded original commitment. Tests also separately verify redundant kills, Armor versus HP, delayed placement, lifetime-preserving relocation, future occupancy, stronger-stage holding, flying immunity and deterministic bounded planning.

## Short runner

From the repository root:

```bash
PYTHONPATH=Scripts/Sim python -m unittest u13_doctrine.test_kalligan_tactics u13_doctrine.test_kalligan u13_doctrine.test_common u13_doctrine.test_coordination u13_doctrine.test_recipes_veil u13_doctrine.test_defensive_plans
python Scripts/Sim/run_u13_kalligan_doctrine_smoke.py
```
