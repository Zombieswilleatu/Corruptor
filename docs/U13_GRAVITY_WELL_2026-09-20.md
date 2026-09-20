# Gravity Orb: concentration and slow damage

User direction: make Gravity Orb a pull/concentration tool rather than another
Death Wish. Instant death belongs only to the very center; the wider area
should apply slow damage. Also preserve open-ended Projection guard targeting.

## Rules

- Attraction radius stays 248 fixed-point units. Lethal core shrinks from 65
  to 20 (about 9.5 percent of its previous area).
- Pull is now an additive two-unit force, rather than replacing normal movement
  with seven-unit forced movement. Moving units can resist/escape; engaged or
  stationary units drift toward the center. Existing movement-readiness and
  Valak Breach slowdown apply to the pull.
- Outside the core, one base damage every 67 ticks: approximately five simulation
  seconds using the existing 200-tick/15-second round convention. First damage
  is delayed. Age is measured from activation and carries across round boundaries.
  Normal board playback can compress simulation time.
- Armor absorbs the pulse first; existing exposure modifies incoming damage.
  Both armies are affected, only in the targeted lane. Nearest-orb selection
  prevents simultaneous overlapping pulses from stacking on one unit.
- Swept center contact still executes units without tunneling. Core execution
  takes priority over that tick's damage. Only core consumption counts toward
  the existing four-consumption Neutral Tear reward, once per orb.
- Pulse deaths emit ordinary casualty records, pass through reactions and feed
  the Resurrection loss ledger. They are area damage, not ordinary attacks.
- Orb duration (two rounds) and cooldown (two rounds after expiration) are unchanged.

Godot and PySim share the same rules. The standalone Valak preview uses the same
pull/core/pulse implementation and now uses the 15-second simulation clock.
Board placement shows both radii, the live vortex has a small core marker, and
help text explains slow damage. Doctrine diagnostics separate friendly/enemy
pulse HP damage, Armor damage and pulse deaths from core consumption.

## Projection

The prior implementation actually admitted only enemy zones. Both rule validators,
the Python resolver and the board picker now accept either player's Lord/Castle
Guard zone. The queue names your/enemy zone. Highest eligible value, declared
spend, reservation, no refund on a whiff, and no Essence generation from Projection
kills remain unchanged. The bot continues to propose enemy zones; this change
restores player freedom without inventing a self-sacrifice policy.

The remembered original reason could not be recovered. A concrete current
interaction is Gremory's Breach Gem Dagger: an eligible Guard death triggers its
card draw. Clearing a slot for a different defensive pair is another possible
use; neither is claimed as the user's original rationale.

## Focused verification

- 39 Python tests: Gravity well boundaries, delayed and cross-round pulses,
  Armor, both owners, lane/radius limits, additive movement/escape, overlap,
  pulse casualty ledger, friendly/enemy Projection and existing powers/movement.
- 20 existing doctrine diagnostics tests pass.
- Godot Valak runner: 218 assertions pass, including friendly Projection resolving
  without an Essence refund and full Wish-independent Valak phase/lifetime checks.
- Focused Godot well exporter: 41 assertions; independent native replay.
  Python matches all packets across three cases / four phases / 800 ticks.
  Includes core consumption/sweeps, Web/Breach interactions and delayed outer
  damage/Armor/death across the round boundary.
- Board runner: 15 checks, zero failures, including clicking your own guard zone,
  queued target/spend, actual worker resolution and animation state isolation.
- Native runtime here is Godot 4.5.1 Linux. The board runner uses its existing
  explicit --compatibility-check test option; the production runtime gate is
  unchanged. This is not Windows 4.7.2 acceptance or a balance-strength claim.
- No long campaign was run.

Reproduce focused parity:

```bash
godot --headless --path . --script Scripts/Sim/U13GravityWellTestRunner.gd -- gravity-well-native.json
python Scripts/Sim/verify_u13_gravity_well.py gravity-well-native.json
PYTHONPATH=Scripts/Sim python -m unittest u13_pysim.test_gravity_well u13_pysim.test_marching u13_pysim.test_powers
```

Base revision: b2efccb6fcd5f6b8625069c968d182b0196dafbb.
