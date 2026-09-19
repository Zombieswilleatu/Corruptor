# U13 V10 / V11 comparison on the accepted Breath rules

**Completed: V11 90 wins, V10 102 wins in 192 primary games.**
All 200 games completed: 3,846 rounds / 96,734 operations,
zero failures, caps or rejected previews. All four control pairs have identical
complete operation streams and final states. Engine and policy fingerprints
remained identical to the accepted checkpoint throughout the run.

**V11 is not a demonstrated strength upgrade.** It finished behind V10 in all
three repeats on this fixed loadout. The intended support behavior appears,
and actual Breath healing increases, but neither establishes better play.
The next task is to isolate Humbaba's opening lane choice and Breath timing in
the saved losing positions, with a separate Deimos Rout/Work check.

## Results

| Matched primary pairs | Count |
| --- | ---: |
| V11 wins both policy assignments | 10 |
| Split | 70 |
| V10 wins both policy assignments | 16 |

| Seed repeat | V11 wins | V10 wins |
| --- | ---: | ---: |
| 1 | 31 | 33 |
| 2 | 29 | 35 |
| 3 | 30 | 34 |

Against the seven unchanged Lords, compare each changed Lord at the same seat
and seed under each policy:

| Changed Lord | Matched setups | V10 Lord wins | V11 Lord wins | Gained / lost wins |
| --- | ---: | ---: | ---: | ---: |
| Deimos | 42 | 23 | 24 | 5 / 4 |
| Humbaba | 42 | 13 | 11 | 5 / 7 |

An exploratory breakdown locates where the overall difference occurs:

| Matchup group | Games | V11 wins | V10 wins |
| --- | ---: | ---: | ---: |
| Deimos / Humbaba cross-play | 12 | 4 | 8 |
| Deimos mirror | 6 | 1 | 5 |
| Deimos / other Lords | 84 | 43 | 41 |
| Humbaba mirror | 6 | 2 | 4 |
| Humbaba / other Lords | 84 | 40 | 44 |

## Observed behavior

| Measurement in primary games | V10 | V11 |
| --- | ---: | ---: |
| Rout selected | 262 | 251 |
| Rout held while ready | 59 | 113 |
| Selected Rout with no estimated current-round pressure | 37 | 0 |
| Breath selected | 246 | 277 |
| Decisions with Breath ready | 346 | 278 |
| Breath paired with same-lane Muster | 6 | 243 |
| Breath in round one | 0 | 54 |
| Muster placed into an already active Breath | 107 | 5 |
| Actual immediate HP restored by Breath | 271 | 334 |
| Opening Muster in Castle lane, out of 54 | 19 | 53 |

These raw counts come from diverging games; game lengths and opportunities differ.
Rout pressure is the documented public-geometry estimate, not observed damage
prevented. Healing is measured from actual pulse events. Future regeneration
and movement forecasts are kept separate in the full audit.

The existing four pairing/denominator tests passed. The audit verifies every
saved record and each recorded main decision against the 16-generated /
four-retained category limits, 32 complete plans and eight previews.

[Compact evidence](evidence/U13_ROUT_HUMBABA_COMPARISON_2026-09-19.json)
records all source hashes, per-policy measurements, work maxima and the raw
evidence archive checksum. The archive retains all 200 complete replays.

## Next: separate timing, lane choice and ordinary orders

The post-run opening review identifies a concrete hypothesis: V11 almost always
fires Breath when ready (277/278 decisions), always pairs it into the opening,
and puts Muster in the Castle lane in 53/54 openings. V10 opens with Castle-lane
Muster in 19/54. Six of Humbaba's seven lost wins against unchanged Lords begin
with Muster moving from Lord to Castle while Breath is added. That pattern is
an investigation target, not proof that either action caused those losses.

Start with `humbaba_valak_00` and `kalligan_humbaba_02`, round one. Their first
ordinary orders are identical across policies; both Muster's lane and Breath
change. Use the same public view, cards, ordinary orders and opposing submission
to compare the two Muster lanes with and without Breath. Inspect movement,
subsequent regeneration and lane exposure before changing activation preferences.
Keep future movement estimates separate from observed benefit.

Also retain `deimos_deimos_00`, round two, seat zero. V11 holds Rout and Works
the building Siege Engine; V10 casts Rout and starts the Bastion. Cards, Guard
placement and the Dotra recipe are identical. The complete games favor V10 in
both policy assignments, but this first difference cannot be attributed to Rout
alone. Compare the power and Work decisions separately on the original view.

These are exploratory follow-ups on recorded losses. Any resulting policy change
needs a fresh comparison; this campaign must remain the unmodified V11 result.

The campaign compares the experimental Python policies without changing game
rules or weights. The native playable bot is outside this comparison.

## Fixed protocol

- **V10:** the policy package frozen from `c0b2a76fdc1ae33239194a18f9477bbc58fc3d80`.
- **V11:** `U13_COMMON_SMART_CORE_ALPHA_V11_ROUT_HUMBABA` at `d19ee7c`.
- **One engine for both:** the Windows-accepted immediate Breath pulse, current
  lane/monster rules and Sinodek immunity. The old engine is never imported.
- **192 primary games:** all 32 ordered Lord matchups involving Deimos or
  Humbaba, three repeats, two policy assignments per setup. Opposite Lord seats
  share the seed for each unordered matchup/repeat. This gives 96 policy pairs
  and 51 distinct unordered-matchup/seed clusters, not 192 independent trials.
- **Eight separate controls:** both Lord orders and both policy assignments for
  Gremory/Kroni and Kalligan/Odradek, on the first repeat. Controls do not enter
  the primary win total; their full operation streams and final states must match.
- **Same ordinary loadout:** Keep, Stockpile, Summoning Circle, Siege Engine,
  Bastion. Default greedy selection, unchanged shared weights, at most 32 complete
  plans and eight authority previews. Forty-round cap; capped games count as
  failures rather than invented wins or draws.
- Seed namespace: `u13-v10-v11-same-breath-2026-09-19`. The complete case list and
  source fingerprints were saved before the first game. No adaptive stopping or
  selection of favorable seeds.

Engine source SHA-256:
`00dd00f2192f5c5913494b0cb7cea11fc58b04080ab1d8b9216c7760fc6c9c11`.
Policy/observer harness SHA-256:
`873fda69fedfe5c3725607ed4f25d67f912f7454b81ff8d30e49e1087d2ce511`.
Both equal the accepted Windows checkpoint. The new campaign wrapper reuses
the existing frozen-policy loader, game driver, observer and verified record
format; it has its own recorded source fingerprint.

## How to interpret the measurements

Swapping policy assignments within one setup holds seed, seats, Lords, loadout
and engine constant. Subsequent games can diverge, including ordinary orders,
combat, available cards and power opportunities. Power totals therefore describe
the resulting play; they do not isolate which component caused a win.

The per-Lord intervention table excludes mirrors and Deimos/Humbaba cross-play.
In its 42 matched setups per changed Lord, the opponent is one of the seven
other Lords. It compares that Lord's result under V11 with its result under V10
at the same seat and seed. Cross-play changes both Lords' policy versions at
once; mirrors measure direct old/new competition.

Breath's recorded immediate HP restoration comes from executed `BREATH_PULSED`
events under the same new rule in both arms. Forecast healing, movement windows
and Rout pressure remain conditional planning estimates. Neither an affected
Rout body nor a forecast movement window is counted as damage prevented.

## Reproduce

From a checkout containing this runner and the named Git baseline:

```bash
python Scripts/Sim/compare_u13_support_doctrines.py \
  --output /path/to/support-v10-v11-comparison --workers 8
python Scripts/Sim/audit_u13_support_comparison.py \
  /path/to/support-v10-v11-comparison
```

Keep policy and engine files fixed while the campaign runs. Existing records
are reused only when their manifest, case identity, semantic hash, operation hash
and trace hash all verify. A different runtime or source revision requires a
fresh output directory. Eight workers is the recorded local configuration,
not a throughput claim for other machines.

Each saved game contains its setup, complete operation stream, detached public
observations, full policy decisions and diagnostics. The audit checks every
record, compares control operation streams, and locates the first policy-plan
difference while confirming both arms still had the same public observation.

This campaign is a fixed-loadout policy measurement. It does not establish Lord
balance, native full-game parity, or performance against human players. The
accepted Windows Breath gate does not need repeating for this measurement.
