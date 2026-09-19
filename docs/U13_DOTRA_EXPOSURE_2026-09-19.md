# Dotra's emergence vulnerability — V15

Historical checkpoint at `b627641`. [V16 replaces the concealment rolls with one guaranteed hide after the first field interval](U13_DOTRA_TIMED_HIDE_2026-09-19.md); the exposure rules below remain in effect.

This replaces the three-hole experiment with an **exposure pulse**. Dotra again approaches at full speed while concealed and emerges with his existing 5-damage ambush. Nearby enemies then take **one extra point of incoming damage per hit, before Armor**, for one full marching round. The effect helps his army focus down an exposed group, but the current results still leave Dotra weak in most army matchups.

## Rules

| Setting | V15 behavior |
|---|---|
| Concealment | Existing 25% chance each eligible active round. Dotra remains hidden until he can deliver an ambush. |
| Approach | Full base movement speed while hidden, with ordinary movement restrictions and slows. |
| Opening strike | Existing 5 damage within 240; the new pulse follows this hit, so it does not amplify its own opening strike. Existing exposure from another Dotra can amplify a subsequent ambush. |
| Exposure radius | 360 around Dotra when he emerges. Enemy marchers only; includes the radius boundary and excludes other lanes. Protected staging remains outside the field. |
| Incoming damage | +1 to each positive damage packet, before Armor. Applies to melee, Vultures, towers, monster abilities, poison, hazards, Web, reflected damage and Fracture damage. Existing Armor bypass remains bypass. |
| Defenses | A block or evasion still prevents the whole hit. Zero damage does not become damage. Healing, banishment and direct execution do not become damage packets. |
| Duration | 200 simulation ticks, expiring at the same tick in the next marching round. Survives Dotra's death. |
| Reapplication | Refreshes the duration; multiple Dotras never increase the bonus beyond +1. |
| Feedback | An expanding emergence pulse and small cracked-shield markers on exposed units, with an explanatory tooltip. Hidden units remain visually concealed. |

The pulse occurs even if the ambush is evaded or kills its primary victim. A queued ambush whose victim has already died does not reveal Dotra or emit the pulse. Damage producers apply the modifier before handing resolved HP damage to the battle event layer, preventing double application.

Both engines use `U13_MONSTERS_V15_DOTRA_EXPOSURE`. The old burrow implementation and its runtime test runner are removed. Its [V14 report](U13_DOTRA_BURROWS_2026-09-19.md) remains a historical checkpoint at commit `174680c`.

## Balance comparison

**576 controlled fights**, using the same 18 Dotra scenarios and 16 seeds with both reflected seats, resolved **1,694 intervals** without a round-cap outcome. All **288 paired seats** matched on outcome, goals and duration. Each row below contains 32 fights, from Dotra's side.

| Scenario | V13 before experiments: W / L / D | V14 holes: W / L / D | V15 exposure: W / L / D |
|---|---:|---:|---:|
| Dotra versus ordinary units from his recipe cards | 0 / 32 / 0 | 0 / 30 / 2 | 2 / 30 / 0 |
| Same-card comparison with support on both sides | 0 / 32 / 0 | 0 / 32 / 0 | 0 / 32 / 0 |
| Supported versus six Butchers | 0 / 32 / 0 | 0 / 32 / 0 | 0 / 32 / 0 |
| Supported versus three Penitents and three Vultures | 0 / 32 / 0 | 4 / 28 / 0 | 0 / 32 / 0 |
| Supported versus mixed army | 10 / 22 / 0 | 2 / 30 / 0 | 12 / 20 / 0 |

Support is one of each ordinary marcher. The mixed opponent is one of each ordinary marcher plus two additional Butchers. These are paired experiments with only 16 independent seeds per scenario; the small improvement over V13 does not establish that Dotra is balanced. The controlled batch recorded **264 ambush/exposure pulses and 446 affected-enemy instances**.

Eight native continuous games ran **240 intervals**, using the two supplied screenshot seeds plus `monster-mixed:2` and `monster-mixed:3`, each with swapped seats. All four seat pairs produced mirrored final session totals.

| Dotra measure in the same eight games | V13 | V14 holes | V15 exposure |
|---|---:|---:|---:|
| Summons | 18 | 18 | 18 |
| Ambushes | 10 | 6 | 8 |
| Dotra's own recorded HP damage | 190 | 90 | 164 |
| Kills credited to Dotra | 30 | 12 | 26 |

V15's **eight pulses exposed 44 enemy instances**; six pulses affected multiple enemies. Eight distinct Dotras activated the power. Damage gained by allied attackers is credited to those attackers, so Dotra's own damage total does not measure the whole debuff benefit.

The next tuning candidate is a more reliable first concealment, such as a guaranteed first hide. Only eight of the 18 continuous-game summons delivered an ambush. That change has **not** been applied in V15; the trigger remains 25%.

## Verification

- **890 native assertions passed**: 644 monster, 79 exposure, 49 Odradek, 22 hazards, 26 Web, and 70 Fracture checks.
- **195 complete native/Python phase comparisons passed**, covering **39,000 ticks**, complete resulting worlds and events: 84 general monster phases, three exposure phases, 90 preview/navigation phases, two controlled samples and 16 continuous samples.
- **17 additional exact native/Python damage-adapter cases passed**: monster packets, zero damage, melee, ranged damage, blocks, evasion, towers, exposure expiry during Psychic Interlock, Inferno and Web.
- **40 Python unit tests passed**, along with launcher syntax validation and source hash verification.
- Dedicated exposure checks cover both seats, boundary targeting, no friendly or cross-lane marking, the initial 5-damage strike, duration refresh without stacking, save/load, exact next-round expiry, reveal timing, both lane drawings, reset cleanup, and concealed-unit presentation.

Tests used **Godot 4.5.1 Linux headless** and **PyPy 3.11 v7.3.20**. The Windows launcher continues to require **Godot 4.7.2 stable**. Native behavior and drawing calls were exercised; Windows visual acceptance was not performed here.

The [evidence folder](evidence/U13_DOTRA_EXPOSURE_2026-09-19/) contains the battle summaries, pulse records, native check logs, compressed replay inputs, exact parity hashes and a source SHA-256 manifest in `verification.json`. The audit summaries' inherited `revision` field names the starting V14 commit; the manifest identifies the tested V15 sources.

## Updated runner

From Windows Git Bash, in the project folder:

```bash
git pull --ff-only origin u13-basic-doctrine
bash Scripts/Sim/run_u13_vulture_balance.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
```

The launcher prints **Dotra exposure V15** and the arena title includes **exposure V15**. Use the unit chooser to spawn Dotra for a manual test.
