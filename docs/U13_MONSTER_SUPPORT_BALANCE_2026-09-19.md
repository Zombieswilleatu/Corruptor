# Responsive monster powers — September 19, 2026

This is the combined **V13 build**: conditional, twice-per-round Kopita pulses and full-speed concealed Dotra, together with the earlier Sinodek targeting, Fyra charm, and Tumler hunt-damage changes. Kopita no longer wastes healing pulses. Dotra reaches enemies faster, but his supported matchup results remain poor. Fyra still averages approximately one charm per summon.

## Current rules

| Monster | Behavior |
|---|---|
| Kopita | Pulses at the start and about **10 seconds** into each active round. Each pulse checks current health: if any ally within **360**, including herself, is wounded, nearby allies recover **1 HP**; otherwise nearby enemies take **1 damage**. Healing and damage are separate choices. |
| Dotra | Keeps his full base movement speed while concealed. Ordinary slows, obstacles and movement restrictions still apply. His 25% hide chance, persistent concealment, reveal on ambush, and 5-damage ambush within 240 remain. |
| Sinodek | One 25% portal attempt per active round, aimed at the nearest visible enemy marcher within **600**. Waits for an enemy in range. Lingering portals still affect allies; their creator remains immune. |
| Fyra | **30% charm chance** per hit against a surviving eligible target, with temporary control and floating pink hearts. |
| Tumler | **3 damage against his marked individual, 2 against others**, before Armor. Interception transfers the mark and its bonus; structures and unmarked taunts get normal damage. |

Kopita's opportunities are simulation ticks **0 and 133 of 200**, which places the second pulse near ten seconds on the 15-second test clock. They scale with playback speed. Both opportunities respect birth hold. A saved pulse clock prevents duplicate casts after repeating a tick or loading a save. Each pulse rechecks current wounds, so she can heal then harm, harm then heal, or repeat the same mode.

The launcher identifies **responsive monster powers V13**. Both engines use `U13_MONSTERS_V13_RESPONSIVE_SUPPORT`. The existing Vulture/tower ranges, protected staging, goal-distance advancing fire, seat swap, and 3×/5× playback remain.

## Results

The final build was run through **4,704 controlled battles**, resolving **15,592 intervals** with no round-cap outcomes, plus **16 native continuous games / 480 intervals**. It uses the same 147 scenarios and seeds as the [previous three-monster checkpoint](U13_MONSTER_TARGETING_BALANCE_2026-09-19.md), with normal profiles and real staging deployment. The continuous games include both supplied screenshot seeds and actual card draws with Auto release decisions.

| Native continuous measure | Before Kopita/Dotra changes | Combined V13 |
|---|---:|---:|
| Kopita summons | 50 | 50 |
| Healing pulses that restored HP | 38 of 118 | **172 of 172** |
| Empty healing pulses | 80 | **0** |
| HP healed | 76 | **322** |
| Damage pulses | 88 | **248** |
| Dotra ambushes | 14 | **16** |
| Dotra deaths | 22 | **26** |

These continuous changes are combined outcomes, not isolated causal estimates. Kopita can still damage an empty area when nobody nearby needs healing; that does not consume a future healing opportunity. A unit dying before the second pulse naturally casts fewer than twice that round.

Recipe comparisons use the same sampled cards converted either into the monster or ordinary bodies. Supported teams also receive one Penitent, Butcher, Vulture and Wright. Each cell below represents 32 fights from 16 paired seeds.

| Monster | Alone versus its cards: previous → current W–L–D | With common support: previous → current W–L–D |
|---|---|---|
| Kopita | 6–26–0 → **8–24–0** | 0–32–0 → **0–32–0** |
| Dotra | 0–32–0 → **0–32–0** | 4–28–0 → **0–32–0** |

Kopita's useful healing improves substantially, but her recipe still underperforms in this supported composition; she continues to win 32–0 against the separate mixed-army benchmark. Dotra's speed change is not a sufficient balance fix: against the screen his supported wins fell from 8 to 0, and against the mixed benchmark from 16 to 10. Directed tests confirm the intended faster approach and earlier ambush. Those outcomes do not establish why his teams lose; no extra stealth, damage, or durability changes were added.

**Fyra remains on target:** 48 charms across 48 completed lifetimes, **1.00 per completed summon**. Including four still alive at the cutoff gives 48/52, or 0.92 per observed summon. Twenty-eight summoned Fyra charmed at least once; an average of one is not a guarantee for each unit.

Remaining concerns include **Sinodek's friendly collateral** (six enemy and 20 allied banishments across four portals in the native sample), **Sooge's immediate recipe value**, and Dotra's weak supported results. Sooge produced 116 beams in sustained play, so his established contribution and vulnerable startup deserve separate consideration. Sinodek's targeting is correct, but allies can march into his lingering field. No collateral or recipe changes were made here.

## Verification

**1,046 native checks** passed: 58 responsive-pulse checks, 644 monster checks, 234 support/hunt checks, and 110 targeted-power checks. **40 Python unit tests** passed. Exact native/Python comparisons matched complete worlds, event tapes and tick snapshots across **284 phases / 56,800 ticks**, including the crowded-navigation regression, both new pulse modes, concealed movement, and sampled controlled and continuous battles.

All **2,352 controlled reflected pairs** agreed on outcomes, and all **eight continuous seat pairs** agreed on goals, totals and ability counts. Reflections verify seat symmetry and do not double the number of independent random samples. These are lane tests without Lord powers, not full-game win rates.

Native checks ran on **Godot 4.5.1 Linux headless**. The user's runner targets **Godot 4.7.2 Windows**; a Windows visual review was not performed here. The [verification manifest](evidence/U13_MONSTER_SUPPORT_2026-09-19/verification.json) records sources and evidence. [Controlled results](evidence/U13_MONSTER_SUPPORT_2026-09-19/controlled.json.gz), [continuous results](evidence/U13_MONSTER_SUPPORT_2026-09-19/continuous.json.gz), charm lifetimes, replay inputs/hashes and check logs are saved alongside it.

Use the [original audit's reproduction commands](U13_MONSTER_BALANCE_AUDIT_2026-09-19.md#reproduce) with the current source. The additional pulse runner is:

```bash
"$GODOT" --headless --path . --script Scripts/Sim/U13MonsterSupportPulseTestRunner.gd -- "$AUDIT/pulse-phases.jsonl"
PYTHONPATH=Scripts/Sim "$PYTHON" -m u13_pysim.verify_monsters "$AUDIT/pulse-phases.jsonl"
```
