# Lane simulator balance adoption — September 19, 2026

The selected balance settings are now used by Lane Balance Sandbox and the
shared Marching engine on `u13-basic-doctrine`. Start a fresh game or arena
after updating; the ranged and monster rules have new version fingerprints.

## Adopted settings

Ordinary melee uses a 34-tick cooldown, giving at most six attacks per 200-tick
round. Vultures and towers use 50 ticks, giving four shots. Cooldowns carry
between rounds. Monster power timings and regeneration remain unchanged.

| Monster | HP | Attack | Armor | Change |
| --- | ---: | ---: | ---: | --- |
| Lemek | 10 | 4 | 4 | HP and Attack increased |
| Varn, per body | 4 | 1 | 0 | HP increased; normal 3–5-body summon |
| Fyra | 10 | 2 | 1 | HP increased |
| Kopita | 10 | 2 | 1 | HP increased |
| Tumler | 10 | 2 | 1 | HP increased; constant 50% direct-attack evasion |
| Kurchin | 15 | 1 | 6 | HP increased; 75% deflection while armored; engaged taunt |
| Muno | 10 | 3 | 1 | HP increased |
| Dotra | 10 | 2 | 2 | HP increased |
| Sooge, mobile | 5 | 1 | 2 | Unchanged; rooted form remains 3 Attack / 6 Armor |
| Sinodek | 5 | 1 | 3 | Unchanged |

Nearby Butchers and advancing Wrights give Penitents a 90-unit lead, then
resume full speed when their leader engages. Wright construction, guarding
and repair retain their normal behavior. Existing support pacing, synchronized
random spawns, round/goal counters, Wright repair and Tumler cluster pursuit
are retained.

## Kurchin and Tumler

Kurchin's taunt now changes the contact target before movement can stop, and
also changes ordinary melee attack selection. Enemies within 360 units leave
an existing opponent and approach Kurchin. It takes priority over approach
formation and Wright guard movement, while hostile walls, fear, retreat and
immobility retain their effects. The taunt cannot cross lanes or select hidden
units. It remains active without Armor and ends when no eligible Kurchin is
in range. It does not teleport enemies or grant attacks beyond melee reach.

Each direct hit checks current Armor. At positive Armor, 75% are deflected
without consuming Armor or HP; landed hits use ordinary absorption, overflow
and bypass rules. At zero Armor there is no deflection, including later hits
within the same volley. There is no additional flat damage reduction or
regeneration buff. A shield glint displays successful deflection.

Tumler's 50% evasion applies at contact and during hold, retreat and fear.
Hunting remains a separate state: a landed melee hit while pursuing changes
his prey; ranged hits do not. Both defenses exclude ongoing poison.

## Verification

Godot 4.5.1 official Linux passed 1,688 directed native assertions, including
245 sandbox checks. Six exported suites matched independent Python replay
across **206 complete phases / 41,200 ticks**, including complete worlds,
combat events and visual tick snapshots. The native suites cover taunt on both
sides, three engaged attackers, range/lane limits, wall blocking, retreat,
deflection roll boundaries, immediate Armor depletion, poison, shield feedback,
multi-round cadence, formations, Wright repair, monster powers and sandbox UI.
The focused Python combat/power suite passed 33 tests. The five affected
doctrine modules passed all 66 tests after the replay updates below.

The shared branch advanced to `89a8c8c` during this work. Its doctrine replay
integration was incorporated before publication. All six unchanged recorded
operation prefixes replay successfully under the adopted rules. Earlier
fingerprints are retained in each fixture's history, and before/after public
observations are archived for review.

Two tactical expectations change with the new survivor distribution and monster
stats. The Deimos mirror still retargets its Siege and preserves its combat
cards, but chooses Varn instead of the historical Fyra. The Kalligan–Deimos
scenario now omits Pyroclasm: more friendly troops remain exposed in Castle
lane. A separate explicit counterfactual moves those friendly troops to Lord
lane and verifies that a beneficial pulse is retained, reducing friendly
exposure from 10 to 3 bodies while hitting the same 28 enemies. Doctrine
scoring and selection code are unchanged.

These are implementation and regression checks. The earlier 8,640-trial Armor
sweep did not include the stronger taunt or this combined package, so its
pooled win rates are not claims about the adopted build. Full-game balance and
Godot 4.7.2 Windows acceptance remain separate.

Evidence: [verification summary](evidence/U13_LANE_BALANCE_ADOPTION_2026-09-19.json)
and [before/after doctrine replay observations](evidence/U13_LANE_BALANCE_REPLAYS_2026-09-19.json.gz).

## Windows update

From the `Corruptor-U13-Doctrine` checkout on `u13-basic-doctrine`:

```bash
git pull --ff-only origin u13-basic-doctrine
```

Launch the game normally and open **Lane Balance Sandbox**. The existing
`run_u13_new_rules_quick.sh` also includes the new balance and cadence checks
and their Python parity stages.
