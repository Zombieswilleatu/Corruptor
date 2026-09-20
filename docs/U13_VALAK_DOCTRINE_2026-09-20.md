# Valak doctrine V23 and paid friendly sacrifice

Parent: `284bbcb4e05ab5958952d82f729abac218eee3c1`.
Policy: `U13_COMMON_SMART_CORE_ALPHA_V23_VALAK_WELL`.

The user requested tactical use of the redesigned Gravity Orb, selective
Projection spending, and the ability to charge Projection by sacrificing an own
Guard. The preceding Gravity well rules remain unchanged.

## Friendly Projection rule

A successful Projection against one's own Guard now grants **two Essence** after
its declared spend, while Valak is alive, capped at five. Spend one to kill a
value-one Guard and gain one net Essence. A value-two sacrifice breaks even;
more expensive sacrifices lose Essence. A full pool cannot grow. The normal
once-per-round Projection admission still applies, and initial Essence is needed.

Enemy Projection kills and whiffs grant none. Reservations are consumed before
the gain. Armed Projection still fires after banishment, but a banished Valak does
not gain Essence. Regular Hunt/Siege guard kills retain their existing +2 gain.
Both Python and Godot implement this rule; the board explains it. This supersedes
the no-Essence-on-friendly-Projection statement in the preceding Gravity note.

## Doctrine

- Orb placements consider the current enemy cluster, a trailing/off-axis pull,
  and a position along the wave's future route in each lane.
- Twenty coarse, public movement samples per body cover two Marching phases.
  Movement and pull are additive; birth-round holds and Valak Breach slowing are
  respected. Core crossings, slow outer damage, useful ranged/melee concentration,
  delay, acceleration toward our gate, and friendly exposure have separate scores.
- Planned recruits are included at a coarse spawn position; spent Supplicants
  are excluded. Prospective core contact is discounted, later exposure is
  discounted, and overlapping existing wells do not earn full extra damage credit.
- Projection reserves are valued for their Lord screening. Its target is
  rechecked after the conditional own attack. It receives no credit for helping
  this round's attack: it fires afterward. Additional next-round Hunt/Siege
  credit uses cards still held, with a capped uncertainty discount.
- Friendly sacrifice is considered only with positive net Essence and a visible
  enemy Guard newly affordable at the resulting charge level. Pair loss,
  exposed lanes, new own deployments, exact eligible-Guard tie order and cap
  waste are considered. No speculative Gem Dagger farming bonus is added.
- Retained options are reconsidered with complete own plans. Original limits
  remain 16 generated/4 retained per category, 32 complete plans and 8 previews.
  Valak alternatives use the same limits, not extra previews or game rollouts.
- Diagnostics distinguish friendly sacrifices, enemy Guard removal and actual
  sacrifice Essence gained.

These are nominal public-board estimates, not simulated combat predictions.
Enemy orders, future draws, pathing/target changes and survival are unknown. Orb
pulse amounts are estimated as base damage; temporary damage modifiers and exact
pulse timing are left to authoritative resolution. The next-round Projection
estimate does not promise the opponent leaves the opened Guard slot empty.

## Verification

- 82 focused Python methods passed across Valak decisions, common planning,
  coordination, diagnostics, Gravity rules and power admission/resolution.
  A subsequent additional complete-plan sacrifice test passes (83 total methods
  across the same modules); the changed Valak/coordination/diagnostic subset was
  rerun after the final edits.
- Godot 4.5.1 Linux: **242/242 native Valak checks**, including capped sacrifice,
  whiff, banishment, independent resolver replay and duplicate-spend rejection.
  This is local compatibility evidence, not Windows Godot 4.7.2 acceptance.
- Two four-round smoke games, Valak/Kroni and Orias/Valak: **16 decisions, 205
  operations, zero rejected previews or illegal operations**, no budget overruns.
  About **11.4 seconds** locally. Each Valak used Orb; one used Projection.
- An expanded defense check encountered two existing stored-view hash failures
  (`kroni_odradek_00`, `kroni_valak_00`). Running the same method in a detached,
  unchanged parent checkout reproduced the identical failures. The historical
  fixtures were not rewritten to claim a green baseline.
- No long campaign or win-rate comparison. No claim of increased wins.

Reproduce the short smoke run from the repository root:

```bash
python Scripts/Sim/run_u13_valak_doctrine_smoke.py
```

Focused decision tests:

```bash
PYTHONPATH=Scripts/Sim python -m unittest u13_doctrine.test_valak u13_doctrine.test_coordination u13_doctrine.test_common u13_doctrine.test_diagnostics u13_pysim.test_gravity_well u13_pysim.test_powers
```
