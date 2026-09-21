# Kroni: meals, erratic routes and proportional artwork

Common doctrine V24 follows the requested meal priorities and fixes the widened-lane sprite distortion. This is a focused behavior update, not measured evidence of stronger play.

## Consume

The bot retains the best enemy Guard in each lane: an intact pair first, then higher card value, with stable identity tie-breaking. Hunt/Siege plans must target Consume in the opposite lane. Final plan assembly retargets an incompatible declaration to that lane, or holds Consume if there is no Guard there. This applies before every preview, including softmax alternatives. Ward/Pass can use either lane. Human targeting legality is unchanged.

The estimate includes next-round feeding, the first Hunger-three milestone and avoiding Cannibal Hunger's own-Guard loss. Ward/Pass's Hunger reduction is applied before evaluating the feeding benefit. Successful feeding remains conditional on Kroni and the target surviving until the scheduled bite.

## Ravenous

The authoritative native and Python launch rules now always select a weighted random angle among routes crossing at least two current enemy positions, when any qualify. The old blind 25% branch is removed. The 48 signed angles retain weights `16 + angle²`; shallow routes remain possible, diagonals remain favored, and the path still bounces. If there is no qualifying route, the original weighted random launch is used. There is no homing or re-aiming after launch. Breach manifestation is unchanged.

The bot evaluates six start positions using twelve representative angles across the whole two-lane field. Its bounded estimate includes potential enemy meals, both lanes' friendly exposure, same-plan recruits/monsters, spent Supplicants, minimum guaranteed power-spawned bodies, and nearby support or gate pressure that could exploit fleeing. Material credit is discounted because moving targets, one bite at a time and flee pauses prevent static intersections from guaranteeing kills. It compares holding with useful launch alternatives within the existing 32-plan/eight-preview caps.

The bot never reads the launch seed, hidden orders or future random route. This is an approximate route-exposure estimate, not a combat rollout. It does not predict each bounce/chomp/flee interaction. The full authoritative route choice still uses all 48 angles. Existing saved actor trajectories remain valid.

## Artwork

Each of the 24 atlas cuts uses one uniform scale for both axes, based on forward board scale and Hunger. Widening lanes cannot stretch the artwork sideways. The same atlas proportions apply to Guard chomps and their mouth anchors. Nearest filtering preserves the pixel art. Collision projection remains separate and still follows board geometry. The source texture is unchanged.

## Verification

- 45 Python methods passed: common planner, coordination, directed Kroni tactics and all nine saved defense expectations (12.76 seconds).
- 953 native Kroni assertions passed.
- 89 native launch/visual geometry checks passed, including all 24 frame proportions, widened fields and Hunger growth.
- 16 native/Python actor creation cases matched exactly: both owners, Hunger zero/three, groups, single targets, allies-only fallback and Breach.
- 54 board interaction/playback checks passed with the explicit headless compatibility option on Godot 4.5.1. The production board still requires Godot 4.7.2; this is not a Windows 4.7.2 rendered acceptance run. Sprite verification here covers atlas geometry and playback, not a rendered screenshot review.
- Two four-round smoke games: 16 decisions / 204 operations, 12.54 seconds, no invalid actions or rejected previews. Each Kroni used Consume three times and Ravenous once. No long balance run.

The native suite initially exposed a pre-existing failure in “Breach can Devour both sides,” also reproduced on unchanged baseline `284bbcb`. Its injected actor had no active Breach, so permanent-arrival protection correctly made both seats immune. The fixture now activates Kroni's Breach and strengthens its assertion to require actual devours from both owners. No immunity rule changed. The board runner now stops promptly on startup failure and supports the same explicit headless compatibility exercise as the Valak runner.

Focused commands from the repo root:

```bash
PYTHONPATH=Scripts/Sim python -m unittest u13_doctrine.test_kroni u13_doctrine.test_coordination u13_doctrine.test_common u13_doctrine.test_defensive_plans
python Scripts/Sim/run_u13_kroni_doctrine_smoke.py
"$GODOT" --headless --path . --script Scripts/Sim/U13KroniTestRunner.gd
"$GODOT" --headless --path . --script Scripts/Sim/U13KroniLaunchTestRunner.gd -- /tmp/kroni-launch.json
python Scripts/Sim/verify_u13_kroni_launch.py /tmp/kroni-launch.json
"$GODOT" --headless --path . --script Scripts/Sim/U13KroniBoardTestRunner.gd
```

For an explicitly requested headless compatibility check on another Godot runtime, append `-- --compatibility-check` to the board runner only. Set `GODOT` to the executable path. No campaign runner is needed for this checkpoint.
