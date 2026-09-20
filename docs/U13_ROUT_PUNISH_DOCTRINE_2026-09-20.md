# Rout doctrine: punish retreat, preserve emergency delay

The user authorized tuning the doctrine around Rout's new +1 regular-attack
damage window. Retreat speed remains 100%. This changes the Python
`CommonSmartCore` used by the current doctrine harness to
`U13_COMMON_SMART_CORE_ALPHA_V15_ROUT_PUNISH`; game rules are unchanged.

## Decisions

- Price ordinary attack opportunities during the retreat round. Existing
  contact, ranged coverage, attack cooldowns, relative speed, and lane objects
  matter. An equal-speed pursuit earns no imaginary repeated swings.
- All recruits can attack immediately. Movement readiness is a separate
  restriction. Same-plan recruits earn credit for attacks from their spawn
  area, with nine public placement samples discounting uncertain coverage.
  Melee recruits are included; they are not excluded by their birth hold.
- Remove Supplicants spent by this plan before counting friendly attackers.
  Include ordinary monster attacks and Towers, discount blocks/evasion, and
  share a finite target HP/Armor budget across attackers.
- Preserve delay when enemies threaten a gate or substantially outmatch the
  approaching friendly force. A balanced, distant approach is not enough by
  itself. No extra points depend on picking specific Castles or loadouts.
- Consider Rout in either lane alongside the plan's existing recruitment,
  Guards, Work, Rites and other powers. Negative own-plan adjustments can
  retain an otherwise identical plan without Rout.

The estimate uses full-speed straight retreat and stationary attack windows.
An eligible pursuer can receive one additional intercept, rather than a full
round of assumed attacks while chasing. Paths, congestion, support pacing,
enemy orders, future targets, reactions and keyed spawn positions are not
predicted. This is a bounded scoring heuristic, not a Marching rollout or a
promise of damage.

Initial scoring is six points per estimated landed bonus hit, capped at eight
hits, minus a six-point offensive reservation cost. Emergency delay is scored
separately: fourteen per gate threat or eight per threatening unit when
outmatched, each capped at three units. These are provisional doctrine weights;
no win-rate improvement is claimed.

## Verification

CPython 3.12.14 and PyPy 7.3.20 / Python 3.11.13 each pass the same **38 focused
test methods**: 16 new Rout checks and 22 existing coordination, artillery,
lane-support and planner-boundary checks. This includes:

- A legal decision choosing actual firing coverage over a distant chase.
- Immediate melee and ranged recruit attacks at tick zero in two isolated
  Marching phases, while movement readiness is still next round.
- Gate/overrun delay, birth movement restrictions, consumed units, finite
  target credit, Towers, Walls, cooldowns, evasion and both player seats.
- Determinism, input immutability, hidden-information independence, all nine
  Lords' opening legality, and smaller custom budgets.

The existing **32 complete plans / eight previews** limits remain. Rout gets
at most sixteen generated / four retained alternatives inside that budget.
Public lane objects are included in observations when present. No hidden
orders, opponent cards or simulation seed are exposed.

The full comparison remains stopped. No balance games, broad replay-fixture
refresh, or native/Windows acceptance run was performed for this policy change.
The shorter new regression set can be run from the repository root:

```sh
PYTHONPATH=Scripts/Sim python -m unittest u13_doctrine.test_rout_tactics -v
```

The existing common-doctrine runner also includes the new regression module.
The exact 38-method selection and local log hashes are recorded in
`docs/evidence/U13_ROUT_PUNISH_DOCTRINE_2026-09-20.json`.
