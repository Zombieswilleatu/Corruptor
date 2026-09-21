# Odradek field doctrine V26

Allegiance Shift and Redirect now use public unit value and coarse battlefield position instead of flat unit counts. This changes only Python bot doctrine. Native/Python power rules, costs, radii, cooldowns, Guard targeting and delayed Guard transfers are unchanged.

## Target selection

Allegiance Shift values current HP, Armor, attack readiness and a small health-scaled ability allowance. A body contributes both enemy material denied and friendly material gained, plus a bounded positional adjustment. Healthy specialists can outweigh larger wounded groups; monsters are not automatically preferred regardless of condition.

Targets use at most eight sampled centers per lane and field power: six evenly sampled positions along the forward axis, the highest-value body, and the mean position. Duplicate centers are removed. The two best distinct affected sets per lane can become proposals. This is intentionally bounded and can miss a better unsampled center.

Redirect estimates pressure in six fixed forward bands per lane. Nearby friendly strength can contest an enemy group; distant troops cannot cancel imminent gate pressure. It compares both armies before and after moving every body inside the actual 300-radius footprint. This permits useful friendly movement and penalizes moving a defender away. Moving an intact crowd between equally unsupported lanes earns no benefit.

This is a coarse pressure estimate, not exact pathfinding, a wall/line-of-sight check or a prediction of individual engagements. Existing/future hazards, future combat, opposing declarations and random effects are not rolled out. The strength weights and positional credit remain heuristics, not measured winning probabilities.

## Whole-plan coordination and saving

The field forecast now includes ordinary recruits, selected monsters and minimum guaranteed power-spawned bodies. It excludes Supplicants spent by the same commitment. Spawn locations are coarse estimates, not keyed placement predictions.

All Redirects are applied before Allegiance Shifts, matching the authoritative hook order even if declarations list Shift first. Shift receives credit only for eligible bodies at its actual target after those moves. Already captured bodies cannot earn capture credit twice. This prices a retargeted combination when it is proposed; it does not add an exhaustive search of arbitrary Redirect/Shift combinations.

Limited-monster ownership uses the authoritative uniqueness helper. Existing, charmed and same-plan recruited Sooge/Sinodek can block another capture, and blocked bodies earn no theft value. Forecast captures update owner/direction and clear waiting/contact state, matching the actual transfer.

The existing saving horizon uses the same improved Shift values as immediate casts. It still considers one best current public goal within at most two additional income ticks, with its existing uncertainty discount. Inversion and False Orders valuation/lifecycle are preserved. Zero/negative standalone Redirect candidates may receive complete-plan evaluation because planned recruits can make the destination useful. All existing 16-generation/four-retention category limits, 32 complete plans and eight previews remain intact.

## Verification

61 focused Python test methods passed in 6.93 seconds: Odradek field tactics, existing Reconfiguration/saving tests, common planner, coordination and all nine saved defense cases.

Directed checks cover:

- A healthy specialist versus a larger wounded group.
- Limited-monster and charm-owner exclusions, including planned recruitment.
- Nearby versus distant support, harmful defender displacement and spent Supplicants.
- Actual authoritative Redirect-then-Shift resolution with reversed declaration order: both armies relocate, only eligible enemies transfer.
- Capture state cleanup, no duplicate capture credit, mirrored seats and registry-order independence.
- Target and planner work limits on a 40-body board.
- Existing save-at-three/cast-Inversion-at-four behavior and actual delayed Guard transfers.

The shared saving test previously assigned positive standalone credit to moving an entire unsupported crowd. It now explicitly expects zero positional benefit, while retaining its assertions that Odradek saves for and eventually casts Allegiance Shift. The coordination regression checks complete removal of Shift credit when Redirect moves its targets away, replacing the old hard-coded 25-per-body score expectation. No saved-state fingerprints required refresh.

Two four-round smoke games completed in 13.77 seconds: 16 decisions / 205 operations, no invalid actions or rejected previews. Odradek faced Kroni from seat zero and Valak from seat one; each Odradek used Allegiance Shift once. This establishes short-run legality and behavior only. No long campaign, strength comparison or new native decision-parity claim.

Run from the repository root:

```bash
PYTHONPATH=Scripts/Sim python -m unittest u13_doctrine.test_odradek_tactics u13_doctrine.test_odradek u13_doctrine.test_common u13_doctrine.test_coordination u13_doctrine.test_defensive_plans
python Scripts/Sim/run_u13_odradek_doctrine_smoke.py
```
