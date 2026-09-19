# U13 Rout / Humbaba doctrine and immediate Breath pulse

**Windows acceptance passed at `f3344f2`.** Godot 4.7.2 completed the focused
Breath gate; CPython 3.14.7 and PyPy 7.3.23 each passed 164 tests and produced
identical five-game reports and inputs: 87 rounds / 2,187 operations, zero
failures or rejected previews. All 456 native Breath transitions matched both
runtimes and an independent local replay. The full doctrine reports and inputs
also match the saved Linux run. See the
[accepted Windows evidence](evidence/U13_ROUT_HUMBABA_WINDOWS_f3344f2.json).

Implementation **`197f0db`** is on `u13-basic-doctrine`, preserving the parallel
Sinodek immunity fix at `c0b2a76`. Local tested commit `bffb5ac` has the identical
implementation tree. The rules change applies in Godot and Python. The doctrine
changes belong to the experimental Python CommonSmartCore, now
`U13_COMMON_SMART_CORE_ALPHA_V11_ROUT_HUMBABA`; the playable native bot remains
on its existing policy.

Breath of Life now heals each eligible allied Marcher in its selected lane for
**1 HP immediately when it fires**, capped at maximum HP. It then retains
**+1 regeneration at the next normal round-start regeneration** and **+25%
movement this round and next**. Waiting Supplicants remain excluded. The pulse
does not restore armor, resurrect units, repeat on restore, or perform an extra
base-regeneration pass. Muster still fires first, and an already armed Breath
still fires if Humbaba is banished before resolution. Duration and cooldown are
unchanged: a round-n cast expires at n+2 and is ready again at n+4. The board
tooltip and aftermath ledger explain and show the pulse; existing healing
feedback consumes its normal Marcher regeneration events.

## What the audit found

The frozen V10 baseline at `156e48e` covered all 32 ordered matchups involving
Deimos or Humbaba, including both mirrors: **613 rounds / 15,356 operations**, no
failed games or rejected previews. It predates both the new pulse and the later
Sinodek fix. These counts describe that baseline, not an A/B strength result.

| Baseline observation | Count |
| --- | ---: |
| Rout selections | 84 |
| Muster selections | 170 |
| Breath selections | 87 |
| Friendly bodies visible in those Breath lanes at planning | 1,707 |
| Of those bodies, waiting Supplicants | 24 |
| Wounded, eligible bodies visible at planning | 122 |

The old Breath score included waiting bodies and the entire missing-HP amount,
without checking the amount or timing of its healing. It could not propose
Breath for an empty lane even when its own plan would Muster or recruit there.
Rout primarily valued enemy head count. Applying the new public-pressure
heuristic to the 84 recorded Rout observations identifies 13 opportunities to
hold and three to prefer the other lane. These are conditional judgments;
retreating a distant column still has a displacement effect.

## What the bot now considers

Rout scores visible enemies that could reach a fight or the friendly end of the
lane during the current Marching phase. Gate threats receive additional weight.
It can keep the power ready when there is no such public pressure. The estimate
uses nominal travel, not hidden orders, future spawns, a pathfinder or combat
rollouts. It does not credit Rout with silencing a rooted Sooge's special attack.
Walls, support pacing, slows and opposing Supplicant spends remain uncertainty.

Breath scores one capped immediate HP per eligible wounded unit, then only the
extra HP that its next regeneration bonus could add after ordinary regeneration.
It excludes waiting/spent Supplicants and distinguishes current movers, next-round
recruits, units already stopped in combat, and Muster's immediately mobile
Penitents. New monsters' uncertain movement is not priced as ordinary recruits.
The bot can pair Breath with Muster or its committed recruitment lane, including
an initially empty lane, and can aim a later Muster into a still-active Breath.
Actual pulse healing is reported separately from predicted movement opportunities.

The support search generates at most 16 alternatives and retains at most four
inside the existing **32 complete plans / eight authority previews**. It preserves
cards, Work, Guards, Rites and other declared powers while comparing support
lanes. Shared weights and default greedy selection are unchanged. This is a
bounded timing/eligibility correction, not a win-rate tuning pass.

## Controlled replays

These comparisons use the same current engine, seed, opposing order and own
ordinary order. Only the named power changes. Full inputs, observations and
hashes accompany the [checkpoint evidence](evidence/U13_ROUT_HUMBABA_2026-09-19.json).

| Recorded situation | Change | Observed result through Marching |
| --- | --- | --- |
| Deimos mirror, round 2, seat 0 | Omit the early Castle-lane Rout | Same 16 allied Marchers and 90 total HP; Rout remains unspent |
| Deimos mirror, round 10, seat 0 | Rout Castle instead of Lord lane | 40 allies / 241 HP versus 39 / 213 HP |
| Humbaba–Gremory opening, seat 0 | Add Breath beside the same Muster | Each of the three Penitents advances another 150 field units |
| Gremory–Humbaba opening, seat 1 | Add Breath beside the same Muster | Each of the three Penitents advances another 150 field units |

Six natural regression positions also check holding, retargeting, paired powers,
recruit support and an actual two-HP immediate pulse. Opposing orders enter
retrospective execution only after the policy chooses. A round-six case favors
supporting the Lord recruitment lane over healing two Castle-lane units: the bot
still makes a conditional tradeoff, rather than always preferring wounds. These
examples establish specific behavior and effects, not overall superiority.

The existing six artillery/defense/Pyro replays retain every original operation,
opposing plan and tactical assertion. Five planning observations are unchanged.
The Deimos–Humbaba round-16 position changes after earlier pulses: three previous
body identities are absent, 13 additional identities are present, 36 shared entities differ,
and the Neutral Tear count is one lower. Healing can change later combat and
Humbaba's exactly-one-HP Endurance condition. Its updated observation fingerprint
is backed by the [complete before/after review](evidence/U13_BREATH_REPLAY_REVIEW_2026-09-19.json.gz),
not a substituted input fixture. The original artillery retarget still fixes the
recorded fizzled Siege.

## Local verification and accepted Windows gate

- **164 CPython tests**, including pulse lifecycle, public-information boundaries,
  both seats, deterministic ordering, reduced work limits, metrics and natural
  tactical replays.
- **Five complete doctrine games / 87 rounds / 2,187 operations**, zero failures
  or rejected previews. The Humbaba game records five activation pulses and two
  HP actually restored; the remaining support benefit is not counted as healing.
- **3,322 native focused checks** and exact agreement with independently executed
  Python for four cases / **456 operations / 461 records**, including every event
  and state field. Both seats, capped healing, waiting/other-lane/enemy exclusions,
  lane reentry, source banishment, duplicate-hook rejection and cooldown reopening
  are covered.
- The existing native Breath and Humbaba integration runners also pass, with
  **63 and 191 checks** respectively.

The initial local diagnostics used **Linux Godot 4.5.1**, with CPython 3.12.14.
The subsequent Windows run at `f3344f2` passed under Godot
**4.7.2.stable.official.ed1daf0bf**, CPython 3.14.7 and PyPy 7.3.23. Its tracked
worktree diff was empty and all source fingerprints match the tested code.
The Windows native gate includes the 63-check Breath runner and 3,322 focused
checks; the separate 191-check Humbaba integration runner above remains local
evidence. This accepts focused Breath parity and dual-runtime doctrine behavior;
native full-game doctrine parity and overall balance remain unestablished.

The accepted run used this Git Bash command; it does not need repeating:

```bash
git pull --ff-only origin u13-basic-doctrine &&
bash Scripts/Sim/run_u13_common_doctrine.sh \
  "C:/Users/jerem/Downloads/pypy3.11-v7.3.23-win64/pypy3.11-v7.3.23-win64/pypy3.exe" \
  --humbaba-godot \
  "C:/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
```

The wrapper runs the focused native Breath cases, compares their exact records
under both Python runtimes, runs the complete doctrine gate under both, and
packages the reports in Downloads. The subsequent [same-rules comparison](U13_ROUT_HUMBABA_COMPARISON_2026-09-19.md) is complete: **V11 90–102 V10** across 192 primary games, plus eight identical controls. All 200 games completed without failures or rejected previews. V11 is not a demonstrated strength upgrade. Next: isolate Humbaba’s opening lane choice and Breath timing in the saved losing positions, and separate Rout from Work in the Deimos mirror. The earlier pre-pulse audit remains behavior evidence rather than a policy comparison.
