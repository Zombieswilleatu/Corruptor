> **2026-09-16:** The focused nine-Lord Windows gate passed at `5fb53e7`. The [fresh common-planner alpha](U13_COMMON_DOCTRINE_ALPHA_2026-09-16.md) is now implemented with nine separate Lord modules, bounded proposals and measured decisions. Its own Windows dual-runtime check is next; broad tuning remains gated.

# U13 doctrine start: contracts and diagnostics before tuning

## User direction and first milestone

Build a fresh common U13 planner that plays all nine Lords competently. Review
U12 for useful ideas, but do not inherit its policy architecture or weights.
Every Lord gets a separate decision module with clearly named power, passive,
timing, resource and explanation sections. Baseline power competence belongs in
the first shared-doctrine milestone; individual Lord specialization follows.

The U12 review followed `BotDoctrine.commitment_choice` into
`SmartCoreV47Doctrine` and its shipping policy. Useful ideas include minimum
sufficient attack commitments, resource-horizon/regroup checks before renewed
pressure, and threat-aware defense under existing structural cover. Turn those
into fresh U13 decision examples. Do not transfer its score weights, inherited
wrapper stack, hidden-Guard estimates or obsolete repair/attack-pair rules.

This first implementation checkpoint is **diagnostic infrastructure**, not a
new shipping bot. `Scripts/Sim/u13_doctrine/` is separate from both the Python
rules engine and frozen Godot BasicDoctrine. The playable bot, U12, accepted UI,
assets, rules and existing reference policy are unchanged.

The [final Marching comparison](U13_PYSIM_MARCHING_OPTIMIZATION_2026-09-15.md)
passed Windows correctness on CPython and PyPy at `ad30730`. CPython improved
1.333x; PyPy showed no consistent gain (0.970x aggregate). Close optional speed
work and move into the agreed doctrine sequence; do not claim a new PyPy gain.

## Dependency order

1. Establish behavior contracts, deterministic candidate limits, observations
   and counters. This checkpoint supplies the recorder, budget, capability
   inventory, reference observer and first Veil settlement regression cases.
2. Complete exact Python full-match support for declared powers and their
   lifecycle, paid Rites, Resummon, and the remaining five Lord integrations.
   Extend existing code; do not rebuild the simulator. Track useful activation,
   sensible restraint and failure/timing cases for each power before campaigns.
3. Build the bounded common planner and nine separate Lord decision modules.
   Designs and directed examples can develop during parity work. Shared-weight
   tuning and full-roster strength claims require the missing rules coverage.
4. Use matched seeds and crossed seats against frozen BasicDoctrine, then the
   full matchup matrix, ablations and held-out seeds. Tune shared judgment before
   individual styles. No balance changes follow from an inert policy branch.

The four ordinary-play Lords are development coverage, not a training roster for
the final shared evaluator. `coverage.py` lists all nine Lords and all 23
declared powers. At the accepted `a7544d6` checkpoint all declared powers, paid
Rites and Resummon were unsupported by the full-match adapter. The subsequent
[paid Development slice](U13_PYSIM_PAID_DEVELOPMENT_2026-09-16.md) passed Windows
4.7.2 with CPython and PyPy at clean `24792a6`: four exact games, 57 rounds,
1,462 game operations and 258 paid component operations. The next
[nine-Lord checkpoint](U13_PYSIM_NINE_LORDS_2026-09-16.md) adds `PowerMatch`, all
23 powers and the remaining Lord lifecycles. Its focused Windows 4.7.2 / CPython / PyPy gate passed at clean `5fb53e7`:
five complete games / 81 rounds, 34 directed power components, all 23 powers
and 16 corruption rejections, with identical runtime reports. The historical four-Lord
`FullMatch` and reference observer retain their boundaries. The capability
report distinguishes that observer from the new adapter.

After the focused Windows gate, proceed to the bounded common planner and
nine separate Lord modules. This is not another optional optimization cycle.
`require_full_roster_tuning()` still blocks broad tuning: the first five games
are an integration corpus, not the roadmap's expanded exact campaign or a
measurement of policy competence. Keep the instrumentation and behavior
contracts ahead of weight sweeps.

## Candidate and validation work

Initial, versioned defaults for the future planner:

| Work per decision | Limit |
| --- | ---: |
| Generated target/payment proposals per category | 16 |
| Retained proposals per category | 4 |
| Complete plans scored | 32 |
| Authoritative submission previews | 8 |

These are starting limits, not measured optimal values. Reserve a budget slot
**before** constructing or evaluating the next proposal; stop the generator on
refusal. Target and payment variants count against the same category limit.
Do not enumerate a Cartesian product and truncate it afterward. Preserve room
for obvious wins, emergency defense and deliberate conservation inside the
limits, with small synergistic bundles such as power plus Hunt.

`Budget` is a reusable deterministic counter, not a candidate generator or a
planner. It supplies no automatic legality guarantees. The future planner must
use it, share precomputed public facts/resource ledgers and the reusable
validation session, and validate the selected complete plan through authority.
Do not copy/run the entire game once per cheap score. Invalid final plans fail
visibly; never conceal a policy bug with a silent replacement Pass.

Elapsed time is a performance measurement, never the stopping rule. Identical
permitted observations, configuration and policy RNG must yield identical
decisions on CPython, PyPy and, for the shipping policy, Godot. The diagnostic
reference policy is unchanged and does not use these new caps.

## Recorder semantics

`Recorder.assess` accepts one assessment per round/seat/category/term, with a
reason code. Aggregate denominators distinguish known true, known false and
unmeasured for opportunity, legality, affordability and selection. Generated
and retained counts include a measured-decision denominator. A zero count with
zero measured decisions must not be interpreted as observed absence.

Unsupported mechanics have `null` measurements, including effect/outcome
measurements. They never masquerade as abilities eligible or selected zero
times. Budget removal and scoring preference must use different reason codes.
Eligibility and low usage alone do not establish a doctrine defect: alternatives
and the recorded explanations matter too.

Selected terms receive stable match/round/seat/category/term IDs. Resolution,
fizzle and cancellation attach to those original IDs, even in later rounds.
Actual effect metrics are separate from resolution status. A successfully
resolved effect can do zero; a resolved effect with no measured metric remains
unmeasured. Counterfactual benefit is not inferred from an event firing.
Exact duplicate event delivery is idempotent; conflicting deliveries, missing
selection IDs and contradictory terminal outcomes fail explicitly.

Reports keep seat, Lord, opposing Lord and policy identity separate. Each game
owns its recorder; release it after writing/merging its report rather than
retaining all decisions from a 50,000-game campaign. Explanation examples have
a fixed sample cap. Reports own their data. No authoritative state, hand,
trajectory, sealed enemy order or parity oracle is passed through the recorder
to a policy. Authority event access belongs exclusively to the observer after
the engine accepts a choice/resolves a hook.

## What the current probe actually measures

The adapter runs the existing `U13_REFERENCE_PAIR_WORK_V1` input producer on the
two accepted ordinary games. This is **not Godot BasicDoctrine or the new
planner**. The existing producer only exposes final choices, so its opportunity
assessment, candidate generation/retention and reasons for preferring one
alternative remain unknown. Stockpile/Slaver currently have event totals only.
Future policy adapters must fill the full recorder contract directly; do not
reverse-engineer imagined reasoning from a chosen action.

The reference observer itself has no paid-choice adapter yet. Its Rites and
Resummon rows therefore remain unmeasured/unsupported by that observer even
after the rules engine implements them. Capability inventory and reason codes
distinguish that observer boundary from rules support. The accepted report at
`a7544d6` remains historical evidence; subsequent coverage metadata is versioned
by its new harness fingerprint.

After each accepted submission, record selected combat, Guard and Work choices.
Read new semantic event rows once, extracting named numeric effects: Guard
deployment, Work contribution/application, activation, Sigils, combat outcomes
and fizzles. Persistent Work refers back to the latest explicit Work order for
that target. Combat metrics are the facts in its resolution event, not inferred
credit for every later kill/interception. Automatic Endurance checks preserve
separate threshold/source-presence counts; they are not declared-power choices.

Every generated operation must match the existing corpus before execution.
Each complete game must retain its accepted final state digest, outcome and
complete semantic event-type counts. The report includes seed/setup, policy ID,
configuration and code hashes, engine source hash, a separate harness hash, and
the historical evidence identity. No rules-source fingerprint is rewritten to
hide policy code. The new package is explicitly outside the existing engine
fingerprint and has its own recursive source hash.

The CLI checks both reference games against the accepted Windows Godot 4.7.2
evidence at `d059b95`. This is an observer/decision regression, not a new native
export, full snapshot parity gate, speed benchmark or full-roster acceptance.
The Windows wrapper runs the same check on CPython and PyPy and compares the
complete deterministic diagnostic reports. Runtime details and timing samples
are excluded from that equality check; source/input/evidence identities are not.

## Veil contract

The revised [Veil-clock requirement](../FutureFeatures/BOT_VEIL_CLOCK_SANITY.md)
supersedes the old blanket restriction on materially advancing a losing clock.
Check a complete plan at the actual end-of-round victory point, including
scheduled effects and Ritual / Final Collapse / Dominion precedence.

A hard exclusion requires a provable, avoidable opponent win. Hidden orders,
unknown future Resummon choices or unresolved random effects cannot establish
that certainty. They remain strategic risks. If passing already loses, retain
legal attempts that could change the result. Hunt and other pressure actions
remain available despite shared-Veil advancement.

Directed complete-information settlement fixtures cover losing versus winning
Tears, an intermediate enemy Dominion superseded by own Ritual, safe shared
clock advancement, passing into scheduled round pressure, Final Collapse soul
comparison and the living-Lord Ritual gate. These are contracts for future
planner tests, not a prediction algorithm or a newly installed playable veto.

## Accepted Windows diagnostics checkpoint

The uploaded `u13-doctrine-diagnostics-QpZyq9-2026-09-15_22-44-34-z5NK3K.zip`
passed at clean `a7544d620376a0a4339825dd5ab85fcdf194dcec`. CPython 3.14.7 and
PyPy 7.3.23 / Python 3.11.15 each passed all 20 tests. The complete deterministic
reports matched across runtimes and the earlier local report: 30 rounds, 767
unchanged operations and both accepted final state digests. Archive CRC, zero
exit status, empty worktree diff and engine/harness/input identities were checked.
See [accepted evidence](evidence/U13_DOCTRINE_DIAGNOSTICS_a7544d6.json).
This accepts the diagnostic observer; it is not a new Godot export, performance
result, new planner acceptance or full-roster parity.

## Earlier local verification and reproducible command

Local CPython diagnostics passed 20 tests and regenerated the two complete games:
30 rounds, 767 identical operations, identical event totals and both accepted
final state digests. The engine fingerprint remains
`50d400eb3b9f11ceda9dd4648ef4117caadce8ba33f019b3fd2192e0dca58206`.
These local Linux results alone did not establish Windows/PyPy acceptance;
the subsequent Windows upload above supplies the dual-runtime check.
See the compact [local evidence](evidence/U13_DOCTRINE_DIAGNOSTICS_LOCAL_2026-09-16.json).

After updating to this checkpoint, run:

```bash
bash Scripts/Sim/run_u13_doctrine_diagnostics.sh \
  "C:/Users/jerem/Downloads/pypy3.11-v7.3.23-win64/pypy3.11-v7.3.23-win64/pypy3.exe"
```

The command reuses the two reference games, performs no weight search, and writes
one upload ZIP in Downloads. It requires CPython and PyPy 3.10+, stdlib only.
The Lord overhaul remains the mechanics authority; its originating user design
handoff is not tracked here. No rule changes were inferred from U12 or this plan.
