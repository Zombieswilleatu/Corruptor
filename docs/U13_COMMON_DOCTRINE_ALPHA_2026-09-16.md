# U13 CommonSmartCore alpha

> **2026-09-17 continuation:** Veil and monster rules now exist in both engines.
> The [focused review](U13_NEW_RULES_QUICK_CHECK_2026-09-17.md) fixes Breach Wish
> diagnostics and Python Sooge resurrection parity on top of the current castle
> tuning. Its local diagnostic evidence is separate from the Windows acceptance
> below; strategic recipe planning remains ahead.

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
The **new planner passed Windows CPython/PyPy acceptance at clean
`d9457a90f1c0c3944b1c64e571c1a4704b9d970c`**. Uploaded evidence:
`u13-common-doctrine-whEku6-2026-09-16_12-30-10-wGGDGo.zip`, SHA-256
`04975ad63fd58fe30bcc30a0ca92275fc609dad1284b777766da484b3b6f4bbe`.
Archive CRC, empty worktree diff, successful status, both complete logs,
report fingerprints and both explicit input files were checked. Engine,
doctrine and runner fingerprints match the exact tested revision.

CPython 3.14.7 and PyPy 7.3.23 / Python 3.11.15 each passed all **36 tests** and
the same **five games / 72 rounds / 1,792 operations**. Every decision, final
state and complete diagnostic report matched across runtimes and the earlier
local hash-seed check. There were zero rejected submissions or previews. The
largest decision assembled 21 of the allowed 32 plans and used one of eight
available authoritative previews; all category caps held. See the compact
[Windows evidence](evidence/U13_COMMON_DOCTRINE_ALPHA_d9457a9.json).

The games selected **19 of 23 powers, 93 times in total**. The four unused
powers have specific recorded reasons:

| Power | Observed reason for follow-up |
| --- | --- |
| Inversion | Twelve resource-shortfall decisions, six without a current opportunity, two with the source banished. |
| Redirect | Conservation, absent opportunities and one banished-source decision; three opportunities lost to scoring/shared resources. |
| WishResurrection | One current opportunity lost to scoring/shared resources; other decisions included uncertain future-loss insurance and absent opportunities. |
| WishWealth | Thirteen decisions without a current opportunity; one opportunity lost to scoring/shared resources. |

These are five-game observations, not proof of bad powers or bad choices.
Unchecked affordability/legality remains unknown. Directed useful/hold/timing
examples are the next way to distinguish appropriate restraint from a policy
gap, before changing weights.

For reproducibility, the completed check used:

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

**Updated user direction, 2026-09-16:** monster recipes and the new Veil system
are being implemented concurrently. They are outside this accepted checkpoint,
but now precede the larger native reference campaign and balance tuning.

Preserve the accepted existing-rules baseline. Once the authoritative additions
land, inspect their actual implementation, mirror them in PySim, and adapt
recipe card reservations, summoning choices and victory evaluation in the
planner. Establish focused parity for those additions before expanding the
native corpus toward the roadmap's 50–100-game gate. Do not spend that campaign
on the superseded rules while the replacement mechanics are in progress.

Shared planner contracts, separate Lord modules and directed behavior examples
can progress meanwhile. Keep their tested rules revisions explicit; do not
infer new mechanics from proposals. After integration and parity, compare
matched seeds and crossed seats against a compatible frozen baseline before
shared-weight tuning and later Lord specialization. Five alpha games do not
support matchup win-rate conclusions. Optional optimization remains closed.
