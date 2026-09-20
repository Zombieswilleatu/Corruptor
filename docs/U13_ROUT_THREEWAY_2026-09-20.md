# Rout old/new/none experiment

The previous experiment compared two doctrines with the same Rout mechanics.
This experiment adds an explicit no-Rout control. The user has not yet played a
full game after the lane overhaul; the historical two-engine strategy is a
hypothesis to test, not evidence that the current Deimos is weak or strong.

## Preregistered design

- Engine and frozen opponent: `b385b10fe84c80ad72d70cf071d510bd1b98d457`.
- Old: frozen V12, including its existing reachable-pressure Rout scorer.
- New: opt-in `rout_mode='new'`, with the same proposals and an assembled-plan
  delay score. No engine, power, castle, monster, or shared weight changes.
- None: V12 with Rout proposals suppressed before retention/assembly. It may
  replan normally and use War Machine. This is an ability ablation, not removal
  of Rout after submitting an otherwise frozen plan.
- Every opponent uses frozen V12. In mirrors only the focal Deimos changes.
- 162 games: 9 opponents × 2 focal seats × 3 shared castle loadouts × 3 modes.
  Each triple has identical setup/seed. Opposite seats share a seed; different
  loadouts have different seeds. The 144 nonmirror games (48 per mode) are the
  primary cohort; 18 mirror games are reported separately.
- Namespace: `u13-rout-threeway-20260920-v1`. One fixed cohort; no outcome-driven
  coefficient changes, seed additions, exclusions, or early stopping.
- Standard deterministic budgets remain 16 generated and 4 retained proposals
  per category, 32 full plans, and 8 legal previews. New Rout reserves omission
  alternatives inside that existing budget. Greedy selection remains default.

The first three castles start active. Both players receive the same selected
loadout regardless of Lord. These are experiment strata, not castle doctrine.

| Setup | Active castles | Initially unbuilt castles |
| --- | --- | --- |
| Zero engines | Keep, Stockpile, Bastion | Summoning Circle, Bastion |
| One engine | Keep, Stockpile, Siege Engine | Summoning Circle, Bastion |
| Two engines | Keep, Siege Engine, Siege Engine | Summoning Circle, Stockpile |

## Candidate score

Use the existing pressure score (8 per reachable fight/gate threat, plus 6 per
gate threat), subtract a fixed 24-point reservation cost, then add conditional
goals: 6 per same-lane ordinary recruit up to 3 when enemies can already reach
our gate; 12 when that gate pressure threatens a targetable castle at 8 or fewer
Integrity (Keep only in Lord lane); 18 when a next-round artillery volley can
finish a surviving locked/singleton castle target. The last goal requires at
least 2 reachable threats or a gate threat. Goals do not stack per castle.

The artillery scenario first applies known own Work, current War Machine,
ordinary artillery, and own attack. Current-round kills earn no future-volley
credit. The future volley allows ordinary fire plus at most one War Machine;
enemy repairs, powers, new random target acquisitions, spatial combat and
engine/Lord survival are unknown. No seed, enemy hand or sealed order is read.
Gate credit concerns future pressure/support, not an attack already resolved
before Rout. Newly recruited enemies and monster-special suppression are not
invented. Terminal paid-choice scenarios receive no future-goal credit.

## Decision rule and limitations

Promotion requires at least 6 additional wins out of the 48 matched nonmirror
cases, at least twice as many gains as losses, a positive net in each loadout,
and all relevant validation gates passing. Otherwise retain production V12 and
preserve the experiment for inspection. This is an exploratory adoption screen,
not a statistical claim about all opponents or Deimos balance. Paired exact sign
probabilities are descriptive: opposite seats and repeated opponents correlate.
The shared setups and fixed opponents also limit any castle-build conclusion.

Reproduce from the experiment source checkpoint with:

```bash
pypy3 Scripts/Sim/compare_u13_rout_threeway.py --output /path/to/new-output --workers 6
```

The output pins source hashes, frozen policy files, every setup, decisions,
operation streams, final hashes, failures, Rout use and affected Marchers.
Run in an isolated checkout; changing engine or harness files during the cohort
invalidates it. Preserve rejected games; do not silently drop them.
