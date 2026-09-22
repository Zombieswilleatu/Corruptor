# Veil escalation and round-25 deadline pilot

Opt-in Python experiment based on local commit `32442c5`. Godot and playable
rules are unchanged. This trial targets normal victories in rounds 15–20,
with the hard ending reserved for round 25.

## Rules and implementation

Enable split Ward plus setup `tempo_experiment: "U13_VEIL_ATTACK_ROUND25_V1"`.
It cannot be combined with the always-on decisive-soul flag.

- Veil 13/17/21 grants +1/+2/+3 strength to each committed Hunt/Siege attack.
  Bonuses are flat per attack, capped at +3, never multiplied by cards or units.
  They do not change printed recruitment value, monster stats or field attacks.
- Strength uses the actual Veil total immediately before each attack; earlier
  effects in the round can therefore change the later attack's bonus.
- The capped extra soul for successful Hunt banishment or Siege final-target
  destruction starts at round 20, inclusive. No pillage/partial-damage bonus.
- Veil 26 no longer ends the game in this profile. Normal victory checks still
  use Ritual first, then Dominion. After those, round 25+ ends by `RoundLimit`.
  The existing collapse comparison chooses the player with more souls, seat 0
  on a tie. That tiebreak is inherited for this trial, not newly balanced.
- Existing Veil arrivals, round pressure, repair, guards, recruitment and
  monster rules stay in place. Split Ward still has no recipe summons or Sigils.

The public observation carries the experimental profile. Bot attack estimates,
defensive stress cases, paid-choice victory projections and closing checks use
the corresponding rules. Future hidden orders and random effects remain
unknown. As in the previous trial, the extra soul itself has no special bonus
score; actual resources flow through existing policy logic.

## Run and validation

Three arms: split Ward; split Ward with always-on decisive soul; new Veil/round-25
profile. Same six matchups, seeds, loadouts and seat orders as the previous
pilot: Gremory–Kanifous, Deimos–Kalligan, Humbaba–Kroni, each reversed.
Eighteen games, two workers recycled every four games, optimized CPython 3.12.

97 focused checks passed, including flat attack thresholds, delayed soul
rewards, deadline precedence, and round-aware planner projections. The first
attempt exposed a missing round argument in closing sensitivity checks; it was
fixed with a regression test, and a fresh frozen run replaced that attempt.
Do not mix the failed `veil-tempo-trial-01` records with the completed run.

`attack_escalation_first_round` records the first actual attack using each bonus,
not necessarily the round when the Veil first crossed its threshold. Zero is
the unboosted case. Win conditions, actual round bands, terminal resources and
deadline usage matter more than whether the ending was labeled collapse.

Run the same short comparison:

```bash
bash Scripts/Sim/run_u13_lord_balance.sh --split-ward-experiment --tempo
```

Adding `--full-roster` selects 243 games; it was not run for this short pilot.

## Completed result

| Measure | Split Ward | Always-on soul bonus | New Veil/deadline profile |
|---|---:|---:|---:|
| Dominion | 2 | 2 | 2 |
| Ritual | 1 | 4 | 4 |
| Final Collapse | 3 | 0 | 0 |
| Round-limit endings | 0 | 0 | 0 |
| Any ending in rounds 15–20 | 2/6 | 3/6 | 3/6 |
| Normal victory in rounds 15–20 | 0/6 | 3/6 | 3/6 |
| Earlier than round 15 | 3/6 | 3/6 | 3/6 |
| Later than round 20 | 1/6 | 0/6 | 0/6 |
| Mean rounds | 14.3 | 12.2 | 14.5 |
| Rejected previews | 0 | 0 | 0 |

New profile, by matchup:

| Matchup (seat order) | Round | Winner method |
|---|---:|---|
| Gremory–Kanifous | 12 | Dominion |
| Deimos–Kalligan | 17 | Ritual |
| Humbaba–Kroni | 14 | Dominion |
| Kalligan–Deimos | 17 | Ritual |
| Kroni–Humbaba | 19 | Ritual |
| Kanifous–Gremory | 8 | Ritual |

No game reached round 20, so the delayed soul bonus never paid in this sample.
Its boundary behavior is covered by focused tests, not exercised by these full
games. No game reached round 25 either. The two former Deimos/Kalligan collapses
became round-17 Ritual wins, at Veil 39 and 32; allowing normal play beyond the
old Veil threshold is part of that change. Kroni–Humbaba moved from a round-21
collapse to a round-19 Ritual at Veil 22.

Both previous Dominion outcomes remained Dominion. In Deimos–Kalligan, both
players had five personal tears at Ritual, but neither had the strict lead
needed for Dominion. The other three Ritual endings had neither player at
five tears. Dominion/Ritual balance is therefore still unresolved.

The first boosted attacks occurred on rounds 9, 10, 14, 10 and 15 in the five
games that used boosts. Four reached +3, first used on rounds 12, 12, 14 and 19.
Kanifous–Gremory finished before any boost applied, showing that its early win
does not originate in the new attack escalation or delayed soul reward.

This achieved normal victories inside the target window in half the sample,
not most games. It removed the late tail here without removing the early tail.
The bundled trial does not isolate the separate effects of attack escalation
and removing Veil-based collapse. Six games per arm are not a balance verdict.

All 18 completed records and frozen source hashes were verified. Both control
arms reproduced all twelve prior operation hashes exactly. Raw paired data:
`docs/evidence/U13_VEIL_TEMPO_SCREEN_2026-09-21.json`. Only report labels and the
normal-win-in-window aggregation changed after the successful freeze; simulation
and policy code did not.
