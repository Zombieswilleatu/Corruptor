# Vulture and tower range comparison — September 19, 2026

## Recommendation and current status

**Next playtest candidate: Vulture range 900; tower range 1,125.** Keep Attack,
HP, Armor, regeneration, movement speed, defense chances and 6/4 attack cadence
at their current values. This restores the intended ordinary-unit counter cycle
in the tested gate-spawn fights and keeps towers able to protect their walls.

**These values have not been adopted. Production remains Vulture 400 / tower
600.** This change records the experiment and makes it reproducible. Python's
duplicated Vulture range literal is now one named constant, with the same live
value. Trial overrides exist only in the experiment process and temporary
native projects; they do not alter saves or production defaults.

The requested initial tower trial was 600 → 750 (+25%). That is insufficient
beside a 900-range Vulture: a stationary tower cannot answer its shots. The
recommended 1,125 is **25% longer than the proposed Vulture range**, but is
**87.5% above the current tower's 600**. Those are different increases. This
larger tower proposal is a recommendation, not an interpretation that the
original instruction already selected 1,125.

## Recovered stopping point

The previous “Recover Missing Conversation” thread reported a finished
14,848-battle marcher suite and an uncommitted 900/750 trial. Its temporary
`Corruptor-lane-live` scripts and full-suite report were absent from this
workspace and the shared branch. Its 59/64 Vulture-versus-Butcher result was
therefore treated as a lead, not imported as fresh evidence or counted below.

This continuation uses shared-branch base `5074b72`, including the adopted
lane balance from `c8efe00`, Sinodek's own-void fix and the later support work.
No doctrine scoring was changed. The new comparison is self-contained.

## Method

- **5,248 primary battles / 16,082 complete Marching phases.** The main matrix
  contains 26 scenarios × 32 seeds × both reflected owner assignments × three
  settings (400/600, 800/750, 900/750): 4,992 battles. A further 256 compare the
  four Wright/tower scenarios at 900/1,125.
- Each cell has 64 played battles from **32 independent seeds and their
  reflected replays**, not 64 independent random samples. Unit IDs and keyed
  rolls are preserved across reflection. All 2,624 mirrored pairs agreed on
  winner and goal totals. Identical initial-state hashes were enforced across
  range settings.
- Production Python Marching, actual recruitment profiles and keyed gate
  placement; 200 ticks per round, normal round-start regeneration, structure
  construction/repair and monster powers. No Lords, castles, card economy,
  reinforcements or doctrine selection. Ordinary units begin ready to move.
- Battles run for up to 12 rounds, ending when a side has no forces or no
  marchers remain. Gate arrivals score and leave alive as in the sandbox.
  More goals decides a goal result; otherwise the surviving force wins.
  Mutual clears are draws. **No primary battle reached the round cap.**
- “Fortified Wrights” means three Wrights already assigned to two complete
  walls and one complete tower, with intact HP/Armor and normal guarding and
  repair. The ordinary 3v3 Wright case starts at the gates and builds normally.
- Pilots explored Vulture 600 and 750 and tower 900 and 1,000 as well. Their
  832 additional executions include overlapping seeds; they are retained in
  the raw evidence but excluded from the 5,248 primary count.

## Ordinary counter cycle

Entries are wins–losses–draws for the **first named side**, out of 64.

| Matchup | Current 400/600 | 800/750 | 900/750 |
| --- | ---: | ---: | ---: |
| Vulture vs Butcher, 1v1 | 0–64–0 | 0–64–0 | **58–0–6** |
| Penitent vs Vulture, 1v1 | 44–20–0 | 36–28–0 | **46–18–0** |
| Butcher vs Penitent, 1v1 | 64–0–0 | 64–0–0 | **64–0–0** |
| Vultures vs Butchers, 4v4 | 0–64–0 | 26–36–2 | **52–12–0** |
| Penitents vs Vultures, 4v4 | 64–0–0 | 58–6–0 | **44–20–0** |
| Butchers vs Penitents, 4v4 | 64–0–0 | 64–0–0 | **64–0–0** |

The 900 setting yields 90.6% Vulture wins against Butchers in duels (the rest
draw), and 81.3% in 4v4. Penitents beat Vultures 71.9% and 68.8% respectively.
Butchers keep their decisive Penitent matchup. These counter cases contain
no towers, so changing tower range from 750 to 1,125 cannot change them.

Range is not a smooth win-rate slider. Which volleys occur before a 200-tick
regeneration boundary matters: simply restoring 800 did not restore the
one-on-one Butcher counter. Results apply to the measured spawn/round setup,
not every possible contact distance or damaged-unit state.

## Tower result and the reason for 1,125

Entries are Vulture wins–losses–draws, out of 64.

| Scenario | Current 400/600 | 900/750 | 900/1,125 |
| --- | ---: | ---: | ---: |
| One Vulture vs one unaccompanied tower | 0–64–0 | **64–0–0** | 0–64–0 |
| Three Vultures vs one unaccompanied tower | 64–0–0 | 64–0–0 | 64–0–0 |
| Three Vultures vs three fresh Wrights | 0–64–0 | **64–0–0** | **34–28–2** |
| Three Vultures vs three fortified Wrights | 4–60–0 | **64–0–0** | **0–64–0** |

At 900/750, the towers fired **zero shots** in all four primary Wright/tower
scenarios. This is safe outranging, not merely a modest Vulture advantage.
The same issue occurs with Vultures at 800 against towers at 750.

Tower ranges 900 and 1,000 stopped a lone Vulture from killing a bare tower in
the eight-seed pilot, but the fortified Wright position still lost all 16
reflected battles at each setting. Towers sit 160 forward-distance units
behind their walls. A Vulture firing from 900 beyond a wall can remain outside
a 1,000-range tower's coverage; lateral separation also matters. At 1,125 the
tower can contribute while the walls are being attacked. The primary test
then restored defense of the prepared position and made the fresh Wright
matchup approximately even.

Three Vultures still defeat a bare 1,125-range tower in every trial, so the
candidate does not turn one unsupported tower into a three-unit counter.
The effects of this larger tower buff on other army compositions and full
matches remain a separate playtest question.

## Mixed squads and monsters

The following figures compare 400/600 with 900/750; the 1,125 tower trial
covered the four Wright/tower scenarios above. Range alone does not solve
every formation. Two Penitents plus two Vultures
still lost all 64 fights against four Butchers at both 400 and 900 range.
The Butchers kill the screen quickly enough that this is a different problem
from four ranged units focusing the approaching Butchers. Wright/Vulture and
one-of-each squads likewise did not beat four Butchers in this sample.

Two Butchers plus two Vultures beat four Penitents 32/64 at current range and
48/64 at 900. Two Penitents plus two Vultures beat four Vultures 60/64 at
current range and 50/64 at 900, with two mutual clears at 900. The larger
ranged-only formation gains more from the buff than the screened pair.

The ten monster probes use four Vultures against one named monster, or four
Varn bodies for the explicit middle-size swarm. They are **not equal-cost
matchups** and are not pooled into an “overall Vulture win rate.” Nine probes
were 64/64 Vulture wins at 900; Tumler still won six of 64. At current range,
Fyra won eight and Tumler fourteen. Those probes show how added approach fire
affects monster pressure; they do not establish full monster balance.

## Validation and reproducibility

Native parity results are stored in
`docs/evidence/U13_VULTURE_RANGE_NATIVE_2026-09-19.json`. The verifier copies
the native dependency sources into temporary projects and changes only the
two range constants there. Each variant verifies that the compiled ranges
match the requested values. A combat-heavy complete phase from each of the
26 scenarios is compared for both owners, with eight additional exact-range
boundary cases. **All four settings passed: 240 complete phases / 48,000
ticks, plus 32 boundary assertions, with zero mismatches.** Comparison includes the entire result, events, and all 200
visual ticks. Exact transport preserves integer/float/bool distinctions.

The local runtime is Godot **4.5.1 official Linux**. This diagnostic is not a
Windows Godot 4.7.2 acceptance run or a full-game policy balance claim. The
existing `u13_pysim.test_marching` suite also passed all **19 tests** with
production values unchanged.

From the repository root, use Python or PyPy:

```bash
python Scripts/Sim/run_u13_vulture_range_balance.py --seeds 32 --ranges 400:600,800:750,900:750 --output range-comparison.json
python Scripts/Sim/run_u13_vulture_range_balance.py --seeds 32 --ranges 900:1125 --groups wrights,tower --output tower-comparison.json
python Scripts/Sim/verify_u13_vulture_ranges.py --godot /path/to/godot --output range-native.json
```

Summary: [range review evidence](evidence/U13_VULTURE_RANGE_REVIEW_2026-09-19.json).
All primary and pilot battle records, inputs, per-setting summaries, initial
and final world hashes: [compressed raw trials](evidence/U13_VULTURE_RANGE_TRIALS_2026-09-19.json.gz).
