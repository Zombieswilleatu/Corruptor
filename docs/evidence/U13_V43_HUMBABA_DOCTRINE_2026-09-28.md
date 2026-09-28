# Humbaba doctrine experiment — 28 September 2026

**Result: improvement on both the reused screen and fresh seeds. Recommend retaining this as the next balance candidate, with no kit buff yet.**

| Set | Games per version | V42 wins | Candidate wins | Gained / lost wins |
|---|---:|---:|---:|---:|
| Reused screen | 32 | 11 (34.4%) | 14 (43.8%) | 7 / 4 |
| Fresh validation | 32 | 14 (43.8%) | 20 (62.5%) | 11 / 5 |
| Combined | 64 | 25 (39.1%) | 34 (53.1%) | 18 / 9 |

The full original survey was 69/160 (43.1%). Compare the two versions within each row above; the reused 32-game subset had a different baseline. The combined result includes the development screen, so the fresh row is the more useful independent check. Small samples and paired seats sharing seeds do not establish a true 50% win rate.

## What changed

- Muster favors reachable fights, projectile-blocking opportunities and friendly ranged support, with a capped penalty for overwhelming enemy attack.
- Breath values available healing more highly, reduces generic movement credit, and adds bounded credit when its speed bonus changes nominal arrival within its active window. It also values healing living, unearned Muster cohorts already near Endurance.
- Humbaba receives a bounded survival bonus against Orias or after observed Hunts, increasing modestly with nearby Endurance opportunities. It compares defense against three strength scenarios from public history; it does not read sealed orders or run future combat.
- Both Python and Godot observation builders expose only his own cohort owner, points and rewarded status to the bot.
- No changes to stats, healing, speed, summon count, Endurance threshold (25), reward ownership, banished-payment rules, victory targets or castle loadout.

## Measured behavior

| Measure | Screen V42 → candidate | Fresh V42 → candidate |
|---|---:|---:|
| Banished planning turns | 131 → 105 | 125 → 94 |
| Endurance Personal Tears | 16 → 19 | 14 → 16 |
| Muster casts | 187 → 188 | 186 → 199 |
| Breath casts | 108 → 104 | 104 → 101 |
| Resummon orders | 55 → 47 | 59 → 39 |
| Total match rounds | 478 → 462 | 465 → 463 |
| Actual immediate Breath HP | 168.53 → 126.75 | 127.36 → 149.04 |

Combined Endurance rewards: 0.47 → 0.55 per game. These remain rare; this is not a two-Tears-per-game engine.

Immediate Breath healing excludes later bonus regeneration and movement value. The screen did not show more actual healing despite its increased score. Different trajectories also change missing HP and cast opportunities, so neither healing nor banished-turn differences isolate the cause of wins. No component ablation was run.

## Matchups

| Opponent | Reused screen (4 each): V42 → candidate | Fresh (4 each): V42 → candidate |
|---|---:|---:|
| Deimos | 2 → 2 | 1 → 3 |
| Gremory | 2 → 2 | 3 → 3 |
| Kalligan | 1 → 2 | 3 → 3 |
| Kanifous | 0 → 1 | 2 → 2 |
| Kroni | 1 → 3 | 0 → 3 |
| Odradek | 1 → 0 | 1 → 2 |
| Orias | 2 → 2 | 3 → 2 |
| Valak | 2 → 2 | 1 → 2 |

Four games per opponent per set are descriptive, not enough to tune individual matchups confidently.

## Validation and provenance

- Frozen baseline: `24b654862d97ac05af937d575fecbd67baf32fa5`, policy `U13_COMMON_SMART_CORE_ALPHA_V42_DEIMOS_FINAL_SPOILS`, from the supplied `u13-unified-v42-overnight.zip`.
- Candidate identifier: `U13_COMMON_SMART_CORE_ALPHA_V43_HUMBABA_SUPPORT_TRIAL`. One candidate was chosen before the screen and stayed unchanged through fresh validation.
- Reused screen: repeats 00 and 01 against each of eight opponents in both seats, original exact setups. Fresh seeds: `u13-humbaba-v43-fresh-2026-09-28:{alphabetically sorted lord pair}:{repeat:02d}`. Same seed shared by the two seat orientations; separate policy processes.
- 96 newly simulated games: 32 reused-seed candidate games and 32 fresh games per version. The 32 screen controls are reused verified records. All 64 pair setups compare equal.
- New candidate rejected previews: 0. Fresh baseline rejected previews: 0. The complete-plan budget stayed at or below 32.
- 24 focused tests passed: observations/privacy, support eligibility, healing caps, arrival scoring, cohort eligibility, deterministic legal openings and unchanged Endurance mechanics. 34 sampled saved non-Humbaba decisions produced unchanged plans.
- The broader existing test selection has eight failures and two errors on the untouched baseline too, including outdated power, victory and recorded-trace fixtures. This work does not claim a clean full suite.
- No native Godot executable was available; native runtime/parity validation remains outstanding. All game-rule Python files remain byte-identical. The one native edit is the observation allowlist.
- The patch was applied to a clean copy of its eight target files; all resulting hashes exactly matched the tested candidate. The experiment was run before publication; native runtime validation is still outstanding.

## Accepted publication

Accepted for u13-resolution-theater on top of 24b6548. Published identifier: `U13_COMMON_SMART_CORE_ALPHA_V43_HUMBABA_SUPPORT`. The test records retain the `_TRIAL` suffix; the label change does not alter scoring.

All previously accepted V42 doctrine remains included: Deimos engine priority and Orias survival, Kalligan anti-Orias, Kanifous matchups, Valak/Kroni Hunt valuation, Orias Hunt/Mark, Gremory support and Odradek Multiply doctrine. The repository baseline matched all 857 frozen simulation/doctrine files relevant to this change; one additional uploaded audio test runner was unrelated and is not included.

Companion evidence: `U13_V43_HUMBABA_SCREEN_2026-09-28.json` and `U13_V43_HUMBABA_FRESH_2026-09-28.json`. The complete experiment package retains the 96 new game records and test logs.

The overnight launcher now accepts V43 and defaults to a separate `u13-unified-v43-overnight` output folder. Three workers, 810 games, six-game worker recycling and the existing paired seed namespace are unchanged. Explicitly resuming an older output continues using that output's frozen source. No new overnight balance run was started during publication.
