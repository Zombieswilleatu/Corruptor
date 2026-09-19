# Monster balance and charm feedback — September 19, 2026

All ten monster powers activate in the current lane environment. Two game bugs were confirmed and fixed: Kurchin's taunt could strand an already engaged fighter, and the sandbox restored charmed ownership too late for its next deployment decision. Charmed units now display three floating pink hearts and a tooltip explaining temporary control.

The balance concern is uneven recipe value. Kurchin is the strongest supported recipe in this sample. Several other monsters struggle against the immediate ordinary-unit conversion of their cards. Sinodek deserves particular attention: its continuous-battle portals banished allies exclusively in this small sample. No monster stats, recipes, ranges, or proc chances were changed in this patch.

## What was tested

- **4,704 controlled battles:** 147 scenarios × 16 seeds × two reflected seats; 15,758 resolved intervals. Scenarios include every distinct single-summon matchup, ordinary 4-v-4 squads, same-card recipe comparisons, and three mixed-army benchmarks per monster.
- **16 native continuous battles:** eight seeds, each replayed from both seats, for 30 intervals each: **480 intervals**. These include both supplied screenshot seeds, real independent card streams, saved cards, protected reserves, and Auto release decisions.
- Vulture range **400**, tower range **600**, Vulture **+1 damage only against Butchers**, goal-distance advancing fire enabled, **15 protected staging slots**, normal birth hold, current spacing/navigation, and actual monster profiles.
- Controlled forces start at their first legal release using native staging deployment. A Varn summon is its actual seeded **3–5 bodies**. No inflated health or forced ability rolls are used for balance outcomes; directed ability tests use fixtures separately.

Seats were reflected in the simulation, including identities, ownership, structures, and nested effect state. All 2,352 controlled seed pairs agreed on the outcome after reflection. All eight continuous pairs also reproduced the corresponding results. Paired seats are checks for directional bias, not additional independent random samples.

These are lane outcomes, not full-game win rates. Controlled battles have no new card draws after deployment and no Lord powers. A resolved outcome considers goals and remaining forces; empty lanes containing only abandoned structures end as draws when goals are tied. No final run reached the 16-interval cap.

## Are the powers working?

The counts below come from the **native 480-interval continuous batch**, including both seats. A summon near the end of a run can still be staged and never get an active turn.

| Monster | Summons | Observed ability activity | Assessment |
|---|---:|---|---|
| Lemek | 206 | 166 deaths produced 166 pools | Death trigger works; directed tests confirm slowing, duration, flight and Lemek immunity. |
| Varn | 232 | 940 bodies, 106 poison applications, 34 later poison damage ticks | Poison works; applying it does not guarantee a victim survives to take later ticks. |
| Fyra | 52 | 12 charms from 10 distinct Fyra | Working but easy to miss. Most summoned Fyra never produced a charm in this sample. |
| Kopita | 50 | 112 heal pulses, 84 harm pulses; 40 heals affected damaged allies, restoring 68 HP | Both modes work. Nearly two thirds of heal pulses healed nobody. |
| Tumler | 76 | 606 evaded attacks out of 1,100 incoming; 76 melee retargets | Evasion and interception work; directed tests check support pursuit and contact behavior. |
| Kurchin | 18 | 130 deflected attacks; taunt regression now passes | Taunt works after the navigation fix. Armor eligibility matters, so total incoming attacks are not the deflection-roll denominator. |
| Muno | 36 | 82 free-strike events | Dash/strike timing and replay effects work. |
| Dotra | 30 | 32 hidden round states, 22 ambush attacks | Concealment and ambush work. Hidden round states include persistent concealment, not just new successful rolls. |
| Sooge | 14 | 12 rooted; 100 beams fired and 100 detonated | Rooting and beams work. Beams recorded 436 enemy contacts and 518 ally contacts, with 236 reported friendly HP damage. |
| Sinodek | 10 | 8 portals, 16 banishments — **all allies** | The mechanic works but placement is dangerous to its own army in these runs. |

Sinodek does banish enemies: the controlled batch recorded **18 enemy and 2 ally banishments** across 478 portals. Its enemy-banishing capability is therefore functioning. The continuous result points toward placement, timing, and friendly-fire value as the next investigation, rather than a missing trigger. Fear and creator immunity also pass directed tests.

Sooge has substantial impact in sustained battles despite weak recipe duels. Its recorded beam damage was 1,156 HP, including 236 friendly HP. These are engine-reported amounts and may include overkill; they are not effective-damage measurements.

Fyra produced another **224 charms** in the controlled batch. The new hearts follow the unit actually under charm in the displayed replay frame; they do not announce future simulation results. They work with chits and sprites, pause with the sandbox, respect concealment, and disappear on death, reset, or ownership restoration.

## Recipe value

Each comparison uses the **same sampled printed cards**: one side summons the monster, the other converts those cards into ordinary units. For the supported column, both sides also receive one Penitent, Butcher, Vulture, and Wright. Each column contains **32 fights from 16 paired seeds**.

| Monster | Ordinary bodies from those cards | Monster alone: W–L–D | With identical support: W–L–D |
|---|---:|---:|---:|
| Lemek | 0–3 | 32–0–0 | 10–22–0 |
| Varn | 0–2 | 28–4–0 | 18–14–0 |
| Fyra | 2–5 | 0–32–0 | 0–32–0 |
| Kopita | 2–6 | 6–26–0 | 0–32–0 |
| Tumler | 1–5 | 22–10–0 | 0–32–0 |
| Kurchin | 1–4 | 14–18–0 | **32–0–0** |
| Muno | 2–4 | 20–12–0 | 12–4–16 |
| Dotra | 2–5 | 0–32–0 | 4–28–0 |
| Sooge | 3–5 | 0–32–0 | 0–32–0 |
| Sinodek | 2–6 | 0–32–0 | 0–32–0 |

Low-value two-card recipes sometimes convert to zero ordinary bodies; those trivial solo outcomes are included explicitly. This experiment measures immediate field value. It does not price the option to save those cards for a later hand or the probability of assembling a recipe.

The supported comparison is useful but composition-specific. Kurchin plus the common core also beat the Penitent/Vulture screen and mixed benchmark in all 32 fights each, but lost all 32 against six Butchers. Kopita lost its same-card comparison yet won all 32 against the mixed benchmark. Those results argue for targeted tuning and counter checks, rather than one global monster ranking.

My next tuning priorities would be Sinodek's useful placement, Fyra's opportunity to deliver charm before dying, and Kopita's empty first/healing pulses. Expensive Sooge and Sinodek recipes also need an economic-value review. Kurchin is the unit to watch for excessive supported efficiency; its clear Butcher counter still matters.

## Ordinary units and recovery

- Vultures beat Butchers in **32/32 solo and 32/32 squad fights**, confirming the requested counter is present in the current build.
- Butchers beat Penitents in **32/32** at both sizes. Penitents beat Vulture squads in **18/32**; the solo comparison was 14/32.
- Wrights beat solo Vultures in **32/32**, but lost the 4-v-4 comparison in **32/32**. Structures and group size matter. No ordinary unit won every matchup.

Four of the eight independent continuous seeds changed goal leader. Examples: `monster-mixed:6` went from **9–0 to 9–28**, and `monster-mixed:5` went from **0–14 to 15–14**. Comebacks are possible under staging. Other seeds remained one-sided, and these eight seeds are insufficient to establish a general comeback rate.

| Seed | Final goals, original seats | Seat swap |
|---|---:|---:|
| `lane-f881e7ec-e3aebe70` | 0–7 | 7–0 |
| `lane-30d27b94-0258ddb4` | 2–50 | 50–2 |
| `monster-mixed:2` | 0–10 | 10–0 |
| `monster-mixed:3` | 0–30 | 30–0 |
| `monster-mixed:4` | 10–12 | 12–10 |
| `monster-mixed:5` | 15–14 | 14–15 |
| `monster-mixed:6` | 9–28 | 28–9 |
| `monster-mixed:7` | 43–0 | 0–43 |

## Fixes and verification

**Kurchin:** navigation respected an obsolete melee contact after taunt selected Kurchin. The fighter could neither leave nor hit its newly selected distant target. Protected taunt movement now releases the old contact while still respecting bodies and walls. The existing lane suite went from **16 failures to 0**, without relaxing its assertions.

**Charm boundary:** `U13LaneSandbox.finish()` now restores surviving charmed units before the next card draw and staging decision. Previously a captured Sooge could incorrectly occupy the captor's living-monster slot after its charm should have expired. Arrivals are credited and retired first, preserving legitimate charmed goals. Four reproduced boundary failures now pass. The native continuous batch was rerun after this fix; the selected seeds happened to retain the same scores and aggregate ability counts.

**Offline parity:** a captured later-round fight exposed stale contact flags in the Python movement snapshot. Godot updates these flags in identity order while retaining snapshot positions. The Python runner now does the same. The initial balance batch was discarded and all 4,704 fights rerun; 74 individual outcomes changed. The report uses only the corrected batch. A saved fixture tests both orientations of a Wright following a Penitent out of contact.

Native checks: **641 monster**, **177 lane**, **100 charm feedback/boundary**, **60 staging**, and **117 continuous-lookahead** checks passed; **19 Python unit tests** passed. Replay validation compares complete worlds and event tapes, including all tick snapshots, rather than just scores. The navigation suite includes the captured crowded arena and unreachable-target recovery.

The exact parity totals and source hashes are in [the verification manifest](evidence/U13_MONSTER_AUDIT_2026-09-19/verification.json). Native execution used Godot **4.5.1 Linux headless**; the user's launcher still targets **4.7.2 Windows**. Geometry, playback timing, status text, pause/reset behavior, and ownership were exercised headlessly; a Windows visual review was not performed here.

## Reproduce

From the repository root, set `GODOT` to a compatible Godot executable and `PYTHON` to Python 3 or PyPy 3. `AUDIT` is an output directory. PyPy was used for the large controlled batch.

```bash
mkdir -p "$AUDIT"
"$PYTHON" Scripts/Sim/audit_u13_monsters.py config --seeds 16 --output "$AUDIT/cases.json"
"$GODOT" --headless --path . --script Scripts/Sim/U13MonsterAuditRunner.gd -- export "$AUDIT/cases.json" "$AUDIT/initials.jsonl"
"$PYTHON" Scripts/Sim/audit_u13_monsters.py controlled --initials "$AUDIT/initials.jsonl" --workers 4 --rounds 16 --output "$AUDIT/controlled.json.gz" --samples "$AUDIT/controlled-parity.jsonl"
"$GODOT" --headless --path . --script Scripts/Sim/U13MonsterAuditRunner.gd -- hashes "$AUDIT/controlled-parity.jsonl" "$AUDIT/controlled-native-hashes.jsonl"
"$PYTHON" Scripts/Sim/audit_u13_monsters.py verify --input "$AUDIT/controlled-parity.jsonl" --native "$AUDIT/controlled-native-hashes.jsonl"
"$PYTHON" Scripts/Sim/audit_u13_monsters.py native-waves --godot "$GODOT" --directory "$AUDIT" --rounds 30 --seeds 8 --workers 4
"$PYTHON" Scripts/Sim/audit_u13_monsters.py waves --directory "$AUDIT" --output "$AUDIT/continuous.json" --samples "$AUDIT/waves-parity.jsonl"
"$PYTHON" Scripts/Sim/audit_u13_monsters.py verify --input "$AUDIT/waves-parity.jsonl"
"$GODOT" --headless --path . --script Scripts/Sim/U13CharmVisualTestRunner.gd
"$PYTHON" Scripts/Sim/verify_u13_vulture_preview.py --godot "$GODOT" --output "$AUDIT/navigation-parity.json"
```

The `replays` runner mode accepts the same inputs as `hashes` and additionally exports full native results for diagnosing a mismatch. [Per-battle results](evidence/U13_MONSTER_AUDIT_2026-09-19/controlled.json.gz), [continuous results and power counts](evidence/U13_MONSTER_AUDIT_2026-09-19/continuous.json.gz), native replay hashes, sampled input worlds, and check logs are saved alongside this report.
