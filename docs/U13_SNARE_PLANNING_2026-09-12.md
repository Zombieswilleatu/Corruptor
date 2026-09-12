# Snare, Blood Conduit and Castle Repair admission

The Windows batch at `7522bee` stopped in game 37, Deimos/Orias, round 16.
Both independent plans returned `castle_repair_locked_this_round` for Orias.
The same seed (`u13-full-match-v1:37`) reproduced the exact failure locally.

Orias had Threat 1 and a Summoning Circle at Integrity 7. Paying Snare grants
Threat; Blood Conduit prevented that gain and exerted the Circle to Integrity 4.
Crossing the operational floor locked Repair through the following round. The
bulk candidate filter checked the castle before this payment, while complete
submission checked it afterward. Final validation correctly rejected the plan.
The batch's combined `plan_legality_or_replay` label did not mean replay differed.

The owner now passes the already-validated declarations and round into its bulk
predicate. The rites adapter preserves that context. Guard/Construction filtering
stages Snare's payment once on the isolated world before checking Castle actions,
using the same `U13SnareCost.pay()` implementation as authoritative submission.
Live state, events, resources and queues remain untouched by enumeration. Final
submission still validates the entire plan; invalid plans are never replaced by
Pass. The compact event mode and other performance fixes remain enabled.

The opposite boundary also matters: a full Circle can become repairable after
exertion if it stays operational. Sealed-order validation now reconstructs the
same Castle admission world for save/restore, so a legal Repair in that case does
not fail at joint lock. Snapshot checks still require the actual Circle payment,
and the real cost is paid once.

## Focused verification

`U13SnarePlanningTestRunner.gd` uses pre-match fixtures at Integrity 6, 7, 8, 9,
10 and 21, including duplicate Circles. It compares bulk choices with complete
submission previews, with and without Snare, for card/token repairs, other
castles, mixed combat/Guard orders and conflicting card payments. It checks
atomic rejection, unchanged enumeration state, real payment/repair locks, and
exact save/replay of legal submissions. Before the fix, four boundary cases
failed; extending the test exposed the full-Circle sealed-order issue as well.

Twelve diagnostic suites passed on Linux Godot 4.5.1: Match, PlanningLegality,
Construction, BloodConduit, Snare, SnarePlanning, GameDevelopment, GamePlanCoverage,
GameRandom, PlanningPerformance, GameConductor and FullMatchBatch. The original
round-16 checkpoint now generates legal plans and completes exact save/replay;
its complete power domains also match the full-transaction reference.
Rerunning game 37 from the original seed completed a legitimate Dominion win for
player 0 at round 25, with independent planning and exact replay verified each
round. This is one targeted completed game, not a 100-game acceptance claim.
Windows Godot 4.7.2 is still the authoritative acceptance runtime.

```bash
bash Scripts/Sim/run_u13_snare_planning.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe" \
  "$HOME/Downloads/u13-full-matches-7522bee4-cb1cc5bc-r80/game-037-checkpoint.json"
```

The wrapper runs the focused regression, then one saved round with timings,
reference power-domain checks and exact replay. It requires Godot 4.7.2 stable,
preserves logs in Downloads, and rejects missing footers, test errors and timeouts.
Omit the checkpoint argument to run only the directed regression.

The full batch also runs the new regression before starting workers. Restarting
after this code change uses a new revision/report directory; previous wins remain
evidence for the old revision and are not relabeled as results of the fixed code.
The 100-game acceptance gate remains pending.
