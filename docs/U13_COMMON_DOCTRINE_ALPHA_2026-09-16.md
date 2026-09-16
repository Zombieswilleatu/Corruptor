# U13 CommonSmartCore alpha

The existing nine-Lord rules passed the focused Windows Godot 4.7.2 / CPython /
PyPy gate at `5fb53e7`. See [accepted rules evidence](evidence/U13_PYSIM_NINE_LORDS_5fb53e7.json).
This checkpoint begins the fresh Python doctrine. It does not replace the
playable Godot BasicDoctrine or establish a strength/balance result.

## Implementation

`Scripts/Sim/u13_doctrine/common.py` builds proposals for Work/activation, Guards,
combat, paid Rites, Resummon, Stockpile and Slaver. `lords/` has separate files
for Gremory, Deimos, Humbaba, Kalligan, Orias, Odradek, Kroni, Valak and Kanifous.
Each file documents its power timing, resource tradeoffs and passive context.
All 23 powers have legal proposals in separately labeled favorable fixtures.
That is basic capability coverage, not proof that every power is selected well
in natural games.

The U12 SmartCore review contributed minimum useful commitments, conservation,
and resource-horizon examples. No U12 inheritance, old weights, hidden-Guard
estimates, repair tokens or attack-pair rules enter this policy. The initial
integer weights are explicit, untuned values. `--weights path.json` injects a
replacement configuration, and the Python API supports Lord-module ablation.
Experimental policies remain independent of the rules engine.

The limits remain 16 generation reservations and four retained proposals per
category, 32 complete plans and eight authoritative previews per decision.
The generator is resumed only after a reservation; an exhausted generator may
leave an unused reserved slot. Diagnostic generated counts count actual
proposals, while budget reports count reservations. Retention preserves the
best distinct terms before extra targets. Fixed priority bundles are assembled;
no Cartesian product is enumerated. Conservation is a genuine scored candidate.
A rejected final submission is an error; no silent replacement Pass is inserted.

The private adapter exposes own hand, public board, public resources, public
Guard values/bonds and permitted effect summaries. It omits simulation seed,
opponent hand, deck order, sealed submissions and future random outcomes.
Each seat gets a reusable private legality session. Policies receive only a
legality callable, never its match/world. Combined power/paid/Guard/combat
admission uses the existing PowerMatch authority and owns temporary payments.

Current-board combat scoring includes strict Guard thresholds, intact Penitent
screens, Sigils, Valak's public Essence, Keep/Bastion interception, Orias Pursuit,
Supplicants and recruitment ratios. Reserved Rite Supplicants are removed from
attack support. These are static estimates, not the complete Action Forecast or
future simultaneous resolution. Spatial reactions and the opponent's new orders
remain uncertain. The Veil score uses actual Ritual / Final Collapse / Dominion
precedence and known round pressure for a paid-choice scenario; it applies no
hard veto without a proof. It never blanket-bans Hunt for adding Tears.

Examples of first-pass Lord judgment: avoid empty area casts; spend the minimum
sufficient Projection Essence; account for friendly exposure to Death/Gravity/
Scorch/Ravenous; charge outstanding Kanifous Prices; retain Reconfiguration for
a visible larger material swing instead of always consuming one-point income;
use delayed Guard attacks with explicit source/target survival uncertainty.

## Diagnostics and limits

The recorder receives assessments only after authority accepts the plan. It
tracks measured opportunity, unknown legality/affordability where not checked,
generated/retained counts, scoring/resource/budget reasons and selected terms.
Sampled decisions include retained candidate scores and reasons. A generation
budget cutoff stays unmeasured rather than becoming zero opportunity.

Declared power IDs retain their original selection through delayed firing and
fizzle. Named actual effects include spawning, artillery damage, Guard changes,
Consume, Gravity/Ravenous friendly/enemy consumption, Web hits, Scorch exposure,
Wish results and later Prices. Resolution alone is not measured benefit. Some
spatial/passive benefits, including Breath healing attribution, remain
unmeasured; those are not asserted to be zero. Persistent effect metrics belong
to their originating declaration and do not infer causal credit for relocation.
Pending powers at game end remain unobserved, not invented cancellations.

The first behavior probe reuses five accepted *setups* with newly selected
alpha decisions. It runs ordinary complete games without fixture edits. The
separate unit fixtures exercise all 23 proposal builders, information boundaries,
rollback, deterministic work limits, delayed attribution and specific decision
contracts. The new game decisions have not been exported/replayed by Godot yet.
The probe writes its explicit inputs for that later expanded native corpus.

Local CPython passed **36 tests** and **five complete alpha games / 72
rounds / 1792 operations**, with zero rejected submissions or previews.
A different `PYTHONHASHSEED=173` reproduced every decision, final state and
complete diagnostic report. See [local evidence](evidence/U13_COMMON_DOCTRINE_ALPHA_LOCAL_2026-09-16.json).
Windows CPython/PyPy acceptance for the **new planner** is pending. Run:

```bash
bash Scripts/Sim/run_u13_common_doctrine.sh \
  "C:/Users/jerem/Downloads/pypy3.11-v7.3.23-win64/pypy3.11-v7.3.23-win64/pypy3.exe"
```

This runner performs the behavior tests and five Python games per interpreter,
then requires identical decisions, complete final digests and diagnostic
reports. It packages the reports/explicit inputs in Downloads. It does not run
Godot export. Time samples separate decision work from simulation, exclude
observer/report/digest costs, and are diagnostics rather than throughput claims.
Each interpreter has a ten-minute watchdog with progress output.

The accepted rules revision predates two new sprite test runners on the shared
branch. The broad engine-source fingerprint includes those added test files and
therefore differs; the accepted evidence retains its exact `5fb53e7` identity.
No existing native authority or Python rules file was changed for this alpha.
The parallel sprite work, U12, playable UI and balance are preserved.

## Next checkpoint

Accept the dual-runtime planner report, inspect unused powers and actual reasons,
and expand directed useful/hold/timing examples where this first alpha is weak.
Then grow the exact native reference corpus around the planner's exercised
choices toward the roadmap's 50–100-game gate. Compare matched seeds and crossed
seats against frozen BasicDoctrine before shared-weight tuning and later Lord
specialization. Five alpha games do not support matchup win-rate conclusions.
Keep monsters, permanent Veil changes and another optional optimization campaign
outside this checkpoint.
