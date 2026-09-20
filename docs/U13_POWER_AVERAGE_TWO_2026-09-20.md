# Power balance: two marchers on average

Power now spawns one/two/three marchers with 25/50/25 percent probability,
replacing 70/25/5 percent. The expectation rises from 1.35 to 2.0 bodies.
This is an actual rule change in both Godot and PySim, including Breach Power.
Keyed RNG channels, uniform suit selection, timing and delayed Prices are unchanged.

The Godot bot now uses a two-body expectation. The calibrated Python Power
valuation uses two average ordinary recruits (39 material points at current
profiles); the diagnostic control profiles retain their original heuristics.
Python Breach proposals retain their existing heuristic rather than receiving
an unrelated policy rewrite.

## Validation

- 23 focused Python Wish/calibration/comparison tests pass, including every
  possible count roll for native and Breach Power (25 ones, 50 twos, 25 threes).
- Godot U13KanifousTestRunner: 459 checks pass, zero failures, including keyed
  count distribution/replay, Wish mechanics, Marching and delayed Prices.
- Godot used here: 4.5.1 Linux. No full-game campaign was run.
- Separate U13WishDoctrineTestRunner stops at line 31 with an out-of-bounds
  access in its Longevity debt fixture. Reproduced unchanged on parent 35d78dc;
  this is not introduced by the Power change.

## Comparing results

The earlier 35d78dc-pinned V21 command still tests the old 1.35-body rules.
Use that revision to finish the original doctrine comparison. Reports from
these new rules must be treated as a separate balance experiment. The runner's
engine hash check correctly rejects importing old-rule control records when
run from this new revision; run fresh controls for a new-rule campaign.
Historical V20/V21 evidence documents describe their original rules and are
not rewritten as evidence for this buff. No win-rate improvement is claimed.
