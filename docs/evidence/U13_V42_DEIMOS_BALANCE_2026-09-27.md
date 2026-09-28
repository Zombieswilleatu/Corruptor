# Deimos: final-castle Spoils and Orias survival

## Result

| Cohort | V41 control | Extra Tear only | Extra Tear + Orias doctrine |
| --- | ---: | ---: | ---: |
| 20 saved Orias matchups | 5/20 | 7/20 | 10/20 |
| 8 fresh Orias matchups | 2/8 | 4/8 | 6/8 |
| 14 other-Lord matchups | 5/14 | 7/14 | Only four regression cases rerun |

These are paired small samples, not an estimate of Deimos's full-roster win
rate. The saved Orias set is the complete 20-game matchup from V41. The other
set uses one seed in each seat against all seven other Lords. Fresh Orias uses
four new seeds in both seats; it was not used to retune the scoring.

The extra Tear fired 12 times in the 20 saved Orias kit-only games, and 15 times
with the survival doctrine. Fresh games: 6/8 and 8/8 respectively. No game paid
the milestone more than once. Alive for planning against Orias increased from
63.8% (control) to 74.0% (combined) in the saved set, and from 73.8% to 83.0% in
fresh games. These are descriptive outcomes of changed trajectories.

## Exact behavior

- Preserve ordinary Spoils: first attributed castle ruin gives an extra Personal
  Tear; later ruins give an extra Neutral Tear.
- Add one extra Personal Tear, once per game, when living Deimos ruins the last
  targetable enemy castle. Defunct castles still count as surviving castles.
  Unbuilt/uncommissioned slots do not block the milestone. The extra reward stacks
  with ordinary Spoils and does not repeat after reconstruction, resummon, or reload.
  A banished Deimos does not earn it, matching the existing passive's activation gate.
- Fear Aura already applies to Pillage in both native and Python resolution. Its
  guard return happens before the guard layers are resolved; it does not count as
  defeating those guards. No extra proc or mechanical change was added. The tooltip
  now explicitly says Siege or Pillage.
- Only Deimos-versus-Orias receives new survival utility. The last three publicly
  revealed Hunt strengths determine three bounded probes (mean minus six, mean,
  mean plus six; default mean 15, clamped 9–30). Preventing banishment earns 72 and
  preserving the Keep earns 18, averaged across probes. Maximum positive bonus 90.
  No forced Ward, hidden enemy hand, new candidates, or castle-loadout change.
  Existing resummon, Profane, and terminal-plan exclusions remain.

## Validation

82 new complete simulations, zero failures and zero rejected previews; 34 V41
control records reused after hash verification. Sources were frozen before the
run and matched their recorded hashes afterward. All four kit-versus-combined
non-Orias regression cases (Kalligan and Valak, both seats) had identical operation
streams and final-state hashes.

19 focused Python tests passed. They cover both reward seats, Defunct blockers,
duplicate events, reconstruction/reload state, inactive/wrong Lords, real Pillage
guard return and combat, engine-first/mandatory War Machine, and matchup-scoped
survival. The Pillage test also passes against unchanged V41 source.

The broader Deimos suite has one legacy replay test with two failing fixture
subcases. Both fail in the unchanged V41 control while replaying their prefix;
these failures are not new. Logs are included.

The GDScript rule and tooltip are included in the patch, and the old native Spoils
assertion is updated for the extra last-castle reward. Godot was not available in
this execution environment, so the native port has NOT been runtime-validated.
Five exact native/Python cases and a 126-check native runner are prepared; the
Python generation and case assertions passed. Do not describe those 126 checks
as passed until the native runner has been executed.

Accepted for integration on u13-resolution-theater atop V41 (24f9d4f).
The published doctrine identifier is U13_COMMON_SMART_CORE_ALPHA_V42_DEIMOS_FINAL_SPOILS.
The experimental records retain their frozen V41 identifier; arm source hashes
identify the compared variants. The identifier update does not alter scoring.
The overnight runner now defaults to a separate u13-unified-v42-overnight output
folder, preserving prior V41 results. The seed namespace remains V41 for paired
comparisons. No new overnight run was started as part of publishing.


Generate the native parity fixture with `python Scripts/Sim/generate_u13_deimos_parity.py deimos-parity.json`, then run Godot with `--headless --path . --script res://Scripts/Sim/U13DeimosFinalSpoilsParityTestRunner.gd -- deimos-parity.json`.
