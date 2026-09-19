> **2026-09-19 Deimos V13 local checkpoint:** [Available-plan Rout preference](U13_ROUT_ANSWER_2026-09-19.md) finished **19–15 against V12** in 34 matched games / 644 rounds / 16,220 operations, with no failures or rejected previews. Deimos gains four non-mirror setups and loses one; V12 wins both mirror policy assignments. Twelve controlled continuations include six exact controls and show both useful delay and a preserved tactical miss where saving 36 HP still loses. Local CPython passes **175 tests and five games / 93 rounds / 2,338 operations**. One lane-choice replay is explicitly reviewed with its historical expectation retained. Shared rules, weights, greedy selection and 32-plan/eight-preview limits remain unchanged. Windows CPython/PyPy acceptance is next; this pilot does not establish general strength or Lord balance.

> **2026-09-19 navigation/doctrine integration:** [Reviewed current replays](U13_DOCTRINE_NAVIGATION_REPLAY_2026-09-19.md) preserve V12 on the parallel `176e175` navigation update. All 13 saved cases remain legal; nine observations and one Humbaba recruitment lane change, with tactical assertions preserved. Local CPython passes **168 tests and five games / 94 rounds / 2,367 operations**. The Rout timing results remain pinned to the earlier `2099326` checkpoint. Sandbox staging, shared navigation implementation and production doctrine are unchanged by this integration. Windows/PyPy acceptance of the combined revision remains pending.

> **2026-09-19 Rout timing and marcher replay integration:** [Controlled Rout replays](U13_ROUT_TIMING_2026-09-19.md) retain V12. In six early holds, forcing Rout lost two existing wins and gained none; six outnumbered-lane tests show delayed attacks and 10–74 more surviving allied HP that round, with unchanged winners. All 36 final continuations and 18 exact controls passed. Reviewed replay fixtures now pass 168 local CPython tests and five games / **93 rounds / 2,329 operations** on the marcher rules through `b61393f`. Production doctrine and game rules are unchanged; Windows acceptance at `77ff661` remains scoped to the older revision. Next: evaluate emergency reservation based on the answer available to the current hand.

> **2026-09-19 Humbaba V12 accepted on Windows:** [Reachable Breath support](U13_HUMBABA_PRESSURE_2026-09-19.md#windows-acceptance-at-77ff661) passed at clean `77ff661`: 168 tests per runtime, identical five-game reports and inputs, **84 rounds / 2,118 operations**, zero failures or rejected previews. All semantic results and recorded inputs also match the original local V12 run. CPython took 961 seconds and PyPy 583; the corrected runner completed successfully. This closes the V12 behavior gate at that revision. Later marcher changes at `b61393f` remain outside this acceptance.

> **2026-09-19 doctrine runner correction:** The first V12 Windows attempt at clean `4dd3c02` passed 168 tests and one game, then stopped at the old ten-minute deadline. [The wrapper now allows thirty minutes per Python check and packages explicit failure reasons](U13_HUMBABA_PRESSURE_2026-09-19.md#incomplete-windows-attempt-and-runner-timeout-correction). Seven local process tests passed. The corrected runner subsequently completed the accepted Windows run at `77ff661`, recorded above.

> **2026-09-19 Humbaba V12 local checkpoint:** [Reachable Breath support and controlled replays](U13_HUMBABA_PRESSURE_2026-09-19.md) finished **V12 37–31 V11** in 68 fresh matched games, all complete: 1,282 rounds / 32,360 operations, zero failures or rejected previews. Breath held on 41/218 ready decisions; opening Muster split 18 Castle / 18 Lord. The 28 opening continuations and five exact controls show no universal first-turn lane/hold fix. Local CPython passed 168 tests and five games / 84 rounds / 2,118 operations. Implementation `5dccbcb` preserves game rules, Deimos, weights and search limits. This is focused evidence with limited seed coverage. Windows CPython/PyPy acceptance subsequently passed at `77ff661`; the accepted native Breath gate remains valid.

> **2026-09-19 V10 / V11 comparison complete:** [Same-engine matched comparison](U13_ROUT_HUMBABA_COMPARISON_2026-09-19.md) finished **V11 90–102 V10** over 192 primary games, plus eight identical control games. All 200 completed: 3,846 rounds / 96,734 operations, no failures, caps or rejected previews. All three repeats favored V10; this does not establish a strength upgrade. Breath restored more HP, but V11 fired on 277/278 ready decisions and opened with Castle-lane Muster in 53/54 games. Next: isolate Breath timing and Muster lane choice in saved losing openings, then separate Rout from Work in the Deimos mirror. The accepted game rules and Windows gate are preserved.

> **2026-09-19 Rout / Humbaba accepted on Windows:** [Common doctrine V11 and the immediate Breath pulse](U13_ROUT_HUMBABA_2026-09-19.md) passed at `f3344f2`: 164 tests each under CPython 3.14.7 / PyPy 7.3.23, identical five-game reports and inputs, 87 rounds / 2,187 operations, zero failures/rejected previews. Godot 4.7.2 passed 3,322 focused checks and 456 exact Breath transitions against both runtimes; an independent local replay also matched. The saved Linux doctrine run matches every semantic result and input. The Sinodek fix and existing 32-plan / eight-preview limits are preserved. Next: compare V10 and V11 on the same updated rules with matched seeds/seats before tuning or balance claims. The accepted gate does not need repeating.

> **2026-09-19 Deimos V10 accepted on Windows:** [Artillery coordination and replay integration](U13_DEIMOS_ARTILLERY_2026-09-18.md) passed at clean `89a8c8c`: 148 tests each under CPython 3.14.7 / PyPy 7.3.23, identical five-game reports and inputs, 88 rounds / 2,222 operations, zero failures/rejected previews, and an exact semantic match to the saved local run. This includes the Wright/Tumler Python update; its native gate remains separate. Original tactical assertions and 32-plan / eight-preview limits are preserved. The subsequent lane-balance update `c8efe00` has separate evidence and is outside this acceptance. Next: measure useful Rout displacement and Humbaba Breath/Muster benefit before changing activation preferences.

> **2026-09-19 doctrine replay integration:** The Windows run at clean `8591fae` failed five saved-observation checks after the parallel Wright/Tumler changes. [Reviewed replay expectations](U13_DOCTRINE_REPLAY_INTEGRATION_2026-09-19.md), published as `7738dc7`, preserve original inputs, chosen plans and tactical outcome assertions. Local CPython passed 148 tests and five games / 88 rounds / 2,222 operations, zero failures/rejected previews. Next: rerun Windows CPython/PyPy acceptance, then useful Rout and Humbaba support effects.

> **2026-09-18 Deimos artillery doctrine, local verification:** [Common doctrine V10](U13_DEIMOS_ARTILLERY_2026-09-18.md) accounts for known own artillery before Hunt/Siege, gives bounded alternative Castle targets, and prices War Machine by capped incremental damage where both shot sequences are known. Two original-input Sieges now deal damage instead of fizzling against the same recorded opponent. Local CPython passed 148 tests and five games / 92 rounds / 2,321 operations, zero failures/rejected previews. Overall 32-plan / eight-preview limits and game rules are unchanged. Implementation `7685deb` has the tested tree. Next: Windows CPython/PyPy acceptance, then useful Rout and Humbaba support effects.

> **2026-09-18 Castle Scorch accepted on Windows:** [Kalligan Castle fire](U13_KALLIGAN_CASTLE_FIRE_2026-09-18.md) passed at clean `0d0983c`: Godot 4.7.2 passed 431 focused assertions and 7,322 exact checks; independent CPython/PyPy matched seven cases / 1,001 operations / 1,009 records, and a separate local replay reproduced the result. Both Windows Python runtimes passed 139 tests and identical five-game reports and inputs, 88 rounds / 2,221 operations, zero failures/rejected previews; these also match the saved local run. Single-Castle/lane targeting, unchanged switching and every-other-round Pyro are accepted. Next: inspect remaining Lord-specific tactical gaps.

> **2026-09-18 Kalligan Castle fire implemented:** [Current checkpoint](U13_KALLIGAN_CASTLE_FIRE_2026-09-18.md) replaces Guard-zone Scorch with one enemy Castle or either Marching lane, preserves switching and the 1–2–1 lifetime, and limits Pyroclasm to every other round. Native/Python rules, board controls/visuals and common-doctrine V9 are updated. The parallel sandbox/monster fixes through `be392ce` are preserved. Local diagnostic checks and evidence are recorded in the checkpoint; Windows 4.7.2 + CPython/PyPy acceptance is next. Older Guard-fire results do not establish Castle-fire balance.

> **2026-09-18 Guard placement and Work accepted on Windows:** [Common doctrine V8](U13_EARLY_DEFENSE_2026-09-18.md) passed at clean `36722ad`: 129 tests each under CPython 3.14.7 / PyPy 7.3.23, identical five-game reports and input files, 93 rounds / 2,333 operations, zero failures/rejected previews, and an exact match to the saved local run. This includes the Dotra update and preserves the later lane sandbox. The earlier opening audit and 162-game 81–81 comparison retain their recorded engine scope. Greedy remains default; no new native-parity, strength or balance claim. Next: inspect remaining Lord-specific tactical gaps.

> **2026-09-18 Guard placement and Work, local verification:** [Common doctrine V8](U13_EARLY_DEFENSE_2026-09-18.md) scores bounded public defensive scenarios and actual capped Work within the existing candidate/preview limits. In 81 matched three-round openings, castle destruction events fell from 78 to 31; two natural replay cases preserve an already-active Keep. A separate 162-game matched comparison finished 81–81 with zero failures/rejected previews. The integrated Dotra update passed 129 tests and five complete games / 93 rounds / 2,333 operations; the later lane sandbox is preserved with identical Python engine/doctrine/runner sources. Greedy remains default; no strength, balance or new native-parity claim. Next: Windows CPython/PyPy acceptance, then remaining Lord-specific tactical gaps.

> **2026-09-18 Odradek horizon accepted on Windows:** [Common doctrine V7](U13_ODRADEK_HORIZON_2026-09-18.md) passed at clean `f6f63be`: 120 tests each under CPython 3.14.7 / PyPy 7.3.23, identical five-game reports and inputs, 88 rounds / 2,220 operations, zero failures/rejected previews, and an exact match to the saved local run. This includes `66ea09e`'s movement fix. V7 compares Reconfiguration saving with immediate casts, accounts for own Guard/attack conflicts, and removes Redirect credit for merely moving an intact crowd. Its earlier 34-game development pilot finished 17-17, with False Orders fizzles 8 to 2 and zero Inversions on either policy; that pilot predates the movement fix. A directed test verifies saving at three then actually transferring Guards. The Python Gremory tower-kill reaction repair is included. No new native parity or strength/balance conclusion; greedy remains default. Next: review recorded behavior before choosing further doctrine changes, without forcing Inversion frequency.

> **2026-09-18 power coordination, local verification:** [Common doctrine V6](U13_POWER_COORDINATION_2026-09-18.md) scores Projection/Consume target survival and Ravenous friendly recruitment within complete plans, with up to four omission alternatives inside the existing 32-plan cap. Local CPython passed 103 tests and five games / 86 rounds / 2,168 operations. A 36-game matched V5 pilot completed without failures/rejections: 18–18; Projection whiffs 7→0 and Consume fizzles 25→1. Directed replays also preserve the missed-opportunity counterexamples. No strength/balance claim or new native parity; Windows CPython/PyPy remains pending. Next: Odradek resource saving.

> **2026-09-18 closing doctrine accepted on Windows:** [V5 closing preference](U13_CLOSING_DOCTRINE_2026-09-18.md) passed at clean `725be5e`: 92 tests each under CPython 3.14.7 / PyPy 7.3.23, identical five-game reports and inputs, 85 rounds / 2,142 operations, and an independent local match. This includes the Penitent update; the 162-game policy comparison still predates it. Default selection remains greedy. Next: power/plan coordination, then Odradek resource saving.

> **2026-09-18 closing pass, local verification:** [Common doctrine V5](U13_CLOSING_DOCTRINE_2026-09-18.md) prioritizes public closing plans that survive bounded resource shocks; fragile opportunities keep their V4 credit and no hard veto is introduced. On the parallel range/monster rules at `b56c83a`, 162 matched policy-seat games completed without failures/rejections: V5 82–80, one V5 sweep / 80 splits / zero V4 sweeps. All 37 selected resilient projections won that round; this is not an established strength/balance result. After integrating the later Penitent block at `55d34fd`, the unchanged doctrine passed 92 tests and five games / 85 rounds / 2,142 operations; the 162-game comparison predates that block. Windows CPython/PyPy acceptance remains pending. Softmax stays off; power/plan coordination and Odradek resource saving remain next.

> **2026-09-18 optional selector accepted:** [Plan selection](U13_PLAN_SELECTION_2026-09-18.md) adds opt-in softmax within the existing legal-preview budget, with separate policy seeds and rank/gap diagnostics. Greedy remains default: all 2,916 saved V4 decisions and the five complete default games are unchanged. Windows CPython/PyPy passed at clean `ba35bd6`: 83 tests each including fixed softmax vectors, identical default-game reports and inputs, 94 rounds / 2,361 operations. Five positive-temperature games passed locally; full-game positive-temperature Windows behavior remains unmeasured. No difficulty tuning or settlement-scoring changes are included. Next: inspect the remaining win-closing misses and false-positive projections.

> **2026-09-18 Rite plans accepted:** [Common doctrine V4](U13_RITE_PLANS_2026-09-18.md) admits nonpositive material-value Rites to complete-plan scoring within the existing caps. In 162 paired policy-seat games on the accepted opening, Invocation resolved 19 times versus zero for frozen V3; V4 won 84–78, with zero failures/rejected previews. Windows CPython/PyPy passed at clean `5e93ce0`: 74 tests each, identical five-game reports and inputs, 94 rounds / 2,361 operations. This fixes reachability, with 21 public-scenario scoring misses still to inspect; it is not a strength/balance conclusion or a new native parity gate. Power coordination and Odradek saving remain subsequent targets.

> **2026-09-18 opening accepted on Windows:** The [normal-draw/free-Lord opening](U13_FREE_OPENING_2026-09-17.md) passed at clean `7147683`: Godot 4.7.2 stable, 318 native checks, 115 tests each under CPython 3.14.7 and PyPy 7.3.23, identical reports for nine openings / 72 snapshots / 63 operations and six corruption rejections. Independent replay reproduced the uploaded report. This accepts the focused opening scope; no repeat run is needed. Next doctrine sequence: bounded Invocation plans, power/plan conflicts, then Odradek's resource horizon. Reassess opening defense under the adopted rules before tuning it.

> **2026-09-17 opening experiment:** [162 matched opening comparisons / 324 games](U13_OPENING_COMPARISON_2026-09-17.md) reduced round-one castle-loss incidence from 56.2% to 17.3% with ordinary first draws and free starting Lords; mean match length changed 17.76 → 18.02 rounds. All controls exactly reproduced the saved survey. This supports a playable trial; production rules remain unchanged. Reassess opening defense after choosing the opening economy. Invocation and power/plan conflicts remain the next doctrine targets.

> **2026-09-17 behavior survey:** [810 Python doctrine games](U13_DOCTRINE_SURVEY_2026-09-17.md) covered all 81 ordered Lord matchups ten times, with zero failures or rejected previews. Next targets are unreachable Invocation plans, conflicts between powers and the rest of a plan, and opening castle defense. The survey includes exact castle-timing replays and does not broaden native parity or establish balance.

> **2026-09-17 doctrine resumed:** The user paused balance at `cfee89a`. The [recipe and Veil doctrine pass](U13_RECIPE_VEIL_DOCTRINE_2026-09-17.md) adds deliberate recipe commitments/saving, public protection judgment and a Gravity/monster interaction fix. This is a Python experiment; local checks and pending Windows acceptance are recorded separately from historical gates.

> **2026-09-16 accepted:** The focused nine-Lord Windows rules gate passed at `5fb53e7`. The [fresh common-planner alpha](U13_COMMON_DOCTRINE_ALPHA_2026-09-16.md) passed Windows CPython/PyPy at clean `d9457a9`: 36 tests per runtime and identical decisions, final states and diagnostics for five games / 72 rounds / 1,792 operations. Monster recipes and the new Veil are now being implemented concurrently; integrate and establish parity for them before the larger native campaign and tuning. Earlier dated records below retain their exact tested scope.

> **Current roadmap (2026-09-15):** See the [consolidated roadmap](../FutureFeatures/README.md) for current status, priorities and the disposition of older proposals. The document below is preserved as detailed source/history; its dated acceptance records retain their original scope.

# CORRUPTOR U13 — POST-LORD-OVERHAUL PROGRESSION PLAN

**2026-09-16 remaining rules implementation:** The
[nine-Lord checkpoint](U13_PYSIM_NINE_LORDS_2026-09-16.md) adds a `PowerMatch`
adapter for all nine existing Lords, all 23 declared powers and their scheduled,
persistent, cooldown and spatial lifecycles. The focused Windows 4.7.2 / CPython / PyPy gate passed at clean `5fb53e7`:
five complete games / 81 rounds, 34 power components, all 23 powers and 16
corruption rejections. Build the bounded common
planner and nine separate Lord modules. Keep the larger exact reference corpus
as a gate before serious balance claims. The permanent-Veil proposal and monster
system are outside this existing-rules checkpoint; no Godot production rules,
balance, playable UI, U12 or assets change.

**2026-09-16 paid Development checkpoint:** The diagnostic observer passed its
Windows CPython/PyPy gate at clean `a7544d6`: all 20 tests and both unchanged
reference games matched. The next [parity slice](U13_PYSIM_PAID_DEVELOPMENT_2026-09-16.md)
adds paid Rites and Resummon to Python FullMatch. Its Windows 4.7.2 gate passed
at clean `24792a6`: 17,904 native checks, 77 tests per Python runtime, four exact
games / 57 rounds / 1,462 game operations, 258 paid component operations and
20 corruption rejections. CPython/PyPy reports match; zero failures. Declared
powers and five Lord integrations were the next dependency; their implementation
is now scoped in the nine-Lord checkpoint above.

**2026-09-16 doctrine start:** The user authorized beginning the agreed rebuild
with consultation for substantive forks. The [first checkpoint](U13_DOCTRINE_START_2026-09-16.md)
supplies separate harness diagnostics, deterministic work budgets, explicit
missing-mechanics coverage and reconciled Veil behavior contracts. It retains
the existing rules and bots. The sequence is diagnostics/contracts → missing
full-roster rules parity → bounded common planner with nine separate Lord files
→ shared tuning → specialization. Four-Lord ordinary play is development
coverage, not the final tuning roster. The uploaded dual-runtime diagnostics
subsequently passed at `a7544d6`; that result does not broaden rules parity.

**2026-09-16 final optional optimization checked:** Windows CPython and PyPy
passed both exact replay gates and all 67 engine + 3 comparison tests at clean
`ad30730`; all 160 timed final digests matched. CPython improved 1.333x, while
PyPy's aggregate 0.970x and disagreeing paired comparisons establish no reliable
gain. Retain the verified implementation and proceed to doctrine. See
[measured results](U13_PYSIM_MARCHING_OPTIMIZATION_2026-09-15.md).

**2026-09-15 full-match rollback optimization accepted on Windows at clean `c228d85`:**
The [copying pass](U13_PYSIM_FULL_MATCH_COPYING_2026-09-15.md) shares unchanged
history/presentation only within audited owned transactions, retaining detached
snapshots and full rollback for live-state access/custom hooks. CPython 3.14.7
and PyPy 7.3.23 each passed all 63 tests and the exact two-game replay, including
all 13 corruption rejections, against the pinned Windows Godot 4.7.2 stream.
Twenty consecutive games per implementation/runtime measured CPython
12.92 → 2.71 seconds (4.78×) and PyPy 7.83 → 1.45 seconds (5.40×), using
`d059b95` as each runtime's control. All 80 final digests matched; PyPy's final
ten games averaged 1.23 seconds. These are repetitions of two ordinary games;
policy cost, full-roster throughput and worker scaling remain unmeasured. Profile
the optimized implementation to choose the next change; the old copying profile
does not describe the new distribution of cost.

**2026-09-15 first complete-game adapter accepted at clean `d059b95`:**
`FullMatch` connects all 20 hooks, repeated rounds, Marching reactions, cleanup,
Vacant Throne and victory for four Lords with explicit ordinary decisions. The
Windows Godot 4.7.2 passed 8,586 checks; Python matched two complete games,
30 rounds and 767 operations without fixture mutations, plus eight separate
settlement components and one 200-tick probe. All 56 Python tests and 13 corruption
rejections passed; independent replay reproduced the complete uploaded summary.
Windows CPython match means are 11.34 / 19.07 seconds. The subsequent
[PyPy 7.3.23 run](U13_PYSIM_PYPY_2026-09-15.md) passed the same exact replay at
unchanged source/input fingerprints and measured 3.73 / 6.53 seconds (2.96×
observed gain). That pre-optimization profile motivated the copying pass now
accepted above. It retains a swappable
reference policy outside authority. Declared powers, paid Rites/Resummon and the
other Lords remain unsupported. See [scope and accepted evidence](U13_PYSIM_FULL_MATCH_2026-09-15.md).
This supersedes the old full-round implementation boundary for this new adapter;
earlier dated acceptance entries remain historical evidence at their exact scope.

**2026-09-15 isolated Marching accepted at clean `e8cc3f9`:**
Windows Godot 4.7.2 passed 394 checks; independent Python matched 28 phases and
5,600 complete tick records, with 46 unit tests and 14 corruption rejections.
Independent replay reproduced the complete uploaded summary. Flat columns
preserve explicit contact ordering, including registry permutations. Windows
batch means were 57.73 ms ordinary, 130.52 ms dense and 6.37 ms Gravity with
13 of 14 units consumed. These are isolated 200-tick phases; the nine-hook
match adapter and full-game parity boundary are unchanged.
See [scope, accepted evidence and timings](U13_PYSIM_MARCHING_2026-09-15.md).
Continue the remaining round lifecycle and preserve the first
legitimate complete-game reference promptly. No full-match budget is established.

**2026-09-15 ordinary resolution accepted at clean `e51588d`:**
The Windows Godot 4.7.2 gate passed: 1,632 Godot checks, 252 exact snapshots,
241 isolated component operations, 36 Python tests and 16 corruption probes;
zero failures or script errors. Independent Python replay reproduced the complete
uploaded summary. The new adapter extends through artillery, commitment
reveal/recruitment and combat (the first nine fresh-game hooks), including required immediate Lord
reactions and exact event visibility. It stops before Post-Resolution/Marching.
See [scope, directed corpus and accepted evidence](U13_PYSIM_RESOLUTION_2026-09-15.md).
No new full-match speed or balance claim follows from this slice. The subsequent
spatial spike has Windows acceptance as scoped above;
preserve the first complete-game reference as soon as a supported path exists.

**2026-09-15 Python copying optimization accepted at clean `88ef438`:**
The Windows Godot 4.7.2 gate passed: 926 Godot checks, 321 exact snapshots,
27 Python tests and 25 rejected evidence corruptions, with zero failures or script
errors. Independent replay reproduced both uploaded verifier summaries. The
matched Windows partial comparison measured 20.31 ms before and 7.98 ms after:
2.54× throughput / 60.71% less wall time, with identical exact results. The pass
removes duplicate copies while preserving complete snapshots, event views and
rollback. See [implementation and accepted evidence](U13_PYSIM_COPYING_2026-09-15.md).
This remains opening-through-Development timing; full-match speed is unknown.

**2026-09-15 Development accepted at clean `108fc15`:** The Windows Godot 4.7.2
gate passed: 497 Godot checks, 90 exact Python snapshots, 217 isolated lifecycle
operations, 20 Python unit tests and 14 rejected evidence corruptions; no failures
or script errors. The independent Python mirror extends through the sixth hook,
Guard deployment and Work/pairs. See
[implementation and accepted evidence](U13_PYSIM_DEVELOPMENT_2026-09-15.md).
That Development adapter stops before artillery; the new resolution adapter
extends it as scoped above. Full-round integration remains unimplemented;
the subsequent isolated Marching kernel is scoped separately above.

**2026-09-15 policy and performance steering:** Keep doctrine swappable in the
harness. Experimental Python policies/configurations do not need Godot ports;
require decision parity for the selected shipping doctrine and exact rules parity
for identical explicit inputs. The accepted Windows partial timing probe measures
31.35 ms mean, 26.65 ms median and 52.74 ms p95 for opening through first Development
over 270 cycles on one worker, excluding export/comparison and doctrine. It
establishes no full-match speed. Local profiling identified state copying as the
first optimization candidate; the copying pass is now accepted above. Continue
ordinary resolution, then bring a spatial performance spike forward before
finishing Marching; measure the first supported complete-match path promptly.
See [concrete contracts and gates](U13_PYSIM_POLICY_AND_PERFORMANCE_2026-09-15.md).

**2026-09-15 PySim planning slice accepted at `f318d6d`:** Python now matches the first
five game hooks through submission lock, opening draws/Stockpile/Slaver and
power-free sealed orders with Guard/Work reservations. The clean Windows 4.7.2
gate passed: 429 Godot checks, 231 exact Python snapshots across nine Lord
cases, 222 game operations (including 140 atomic rejections), 21 economy
component transitions and 52 standalone cursor operations. Thirteen Python unit
tests and eleven corruption probes also passed; zero failures or script errors.
See [scope and accepted evidence](U13_PYSIM_PLANNING_2026-09-15.md).
Development is now accepted as described above.
Full Python round resolution remains unimplemented; standalone cursor coverage
does not certify the later hooks' game mechanics.

**2026-09-15 PySim foundation accepted:** The focused Windows Godot 4.7.2 gate
passed at clean revision `4e485b1`: 51 Godot checks, 14 exact Python opening
snapshots, 49 Godot-replayed operations across two rounds, six Python unit tests
and ten rejected evidence corruptions; zero failures or script errors. See
[implementation and accepted evidence](U13_PYSIM_FOUNDATION_2026-09-15.md).
Python round resolution is not implemented yet. The user confirmed the
integrated 63d1372 playable build runs before this work began.

**2026-09-15 current checkpoint — accepted and integrated:** The 357d793
Windows Godot 4.7.2 campaign completed 100/100 replay-verified Random-Legal games,
all 81 ordered Lord matchups, zero caps/failures/errors (52 Dominion / 48 Final
Collapse; mean 20.07 rounds). The user separately accepted Action Forecast at
dd9638c. Forecast/public Guards are integrated with the parallel 5c1fa48 sprite
gallery change into `u13-basic-doctrine`. See
[exact revisions and evidence](U13_ACCEPTED_CHECKPOINT_2026-09-15.md).
The campaign predates forecast/public-Guard changes and is not balance evidence.

**PySim progression:** Round sequencing, submissions and opening-round economy
now have the focused implementation above. The
trace contract, exact deterministic primitives and opening-state parity are
accepted through Development, with the copying optimization also Windows-accepted.
Ordinary resolution also has focused Windows acceptance as documented above.
The isolated spatial gate also has Windows acceptance; integrate the remaining
round lifecycle toward the first legitimate complete-game reference;
see [inventory and subsequent parity order](U13_PYSIM_PARITY_2026-09-15.md).
Then Common Smart Core + separate Lord doctrines, serious balance, and roguelite
work. Preserve the accepted UI. No new broad campaign is needed for this
documentation/integration checkpoint. The dated entries below are historical;
their pending-campaign and hidden-Guard wording is superseded where noted above.

**2026-09-14 parallel forecast checkpoint:** User accepted the playable build,
started the 357d793 full-game campaign, and authorized Action Forecast in
parallel plus public deployed Guard faces/values for both human and bot. Work
is isolated on `u13-action-forecast`; see `U13_ACTION_FORECAST_2026-09-14.md`.
The first forecast is a visible-board baseline, not a hidden-hand probability
model. Preserve the running campaign's revision and do not mix bot versions.


**2026-09-14 user-authorized mechanics checkpoint:** Guard deployment work,
defensive suit bonds, a single Work Target and Ward 2:1 recruitment supersede
the earlier paid-development rules. See `U13_GUARD_WORK_2026-09-14.md`.
The accepted 100-game gate below remains historical evidence for its original
rules; validate this new policy before drawing new balance conclusions.


**2026-09-14 accepted full-game gate:** Windows Godot 4.7.2, clean
`d605e3a7976735d0c933818cbfa965f5d41d78d7`: 100/100 complete games, all independently
replay-verified, zero caps/timeouts/errors/missing games, all 81 ordered Lord
pairings. 63 Dominion / 37 Final Collapse; rounds 10–26 (mean 19.46).
This supersedes the pending/timeout status below. No additional large batch is
required for the presentation pass; balance remains paused.

**2026-09-14 user priority: Aftermath ledger first.** Before Action Window /
Resolution Theater, replace the empty Aftermath copy with a scrollable public
round ledger, grouped by credited player with shared/unattributed effects
separate. Show Souls/Personal Tears/Neutral Tears totals and net changes,
combat/destruction results and meaningful position changes. Preserve the final
round ledger before opening the victory screen. Loaded mid-round saves without
an opening balance show current totals, not fabricated net changes. This is
presentation only; no balance or authoritative mechanics changes.


**2026-09-14 Random-Legal timeout:** The a0b774c Windows flow gate passed both
suites (858 checks). The subsequent 20-game Random-Legal diagnostic completed
three replay-verified games before game 0 hit its 1,200-second watchdog in round
14. User authorized profiling and fixing the planning bottleneck. The bounded
lazy power-domain change preserves seeded choices; see
`U13_RANDOM_POWER_PERFORMANCE_2026-09-14.md`. A 12-round smoke test does not replace
full-game completion. Balance tuning and the larger gate remain paused pending
the focused Windows comparison.

**2026-09-14 targeted performance steering:** User authorized shared-engine
optimization before another Random-Legal batch. Balance tuning remains paused.
Windows e4d9501 doctrine fixtures passed 7/7 (759 checks); the subsequent doctrine
campaign was interrupted after 54 completed games and does not close Random-Legal
acceptance. See `U13_SHARED_FLOW_PERFORMANCE_2026-09-14.md` for the bounded changes,
exact differential tests, and phase-level timing limits.

**Status:** Working roadmap / engineering addendum
**Date:** 2026-09-10

**Latest round-length rule:** Starting at the end of round 13, add one neutral
Tear per round through round 20, then two per round from round 21 onward. Apply
once at Aftermath before victory evaluation. Final Collapse at 26 total Tears
bounds even a zero-Tear opening to round 29. Threshold penalties remain disabled;
this supersedes the older drift-off notes below. New victory policy requires
fresh matches; do not combine the earlier 42 results with this rule profile.
See `U13_ROUND_PRESSURE.md`.

**Latest V5 campaign:** Windows fixture gate accepted 462 checks on `9e55f654`.
The local nine-match campaign completed 9 wins, zero caps/failures in 163 rounds.
User authorized an unattended 100-game campaign: use `run_u13_doctrine_100.sh`
(four workers, 40-round cap, replay every fifth game, distinct seeds beyond 81).
See `U13_DOCTRINE_V5_CAMPAIGN_2026-09-13.md`. Next directed review: repeated
low-impact Kanifous Hunts in seed 79; avoid changing the accepted gameplay
baseline while collecting this larger batch.

**2026-09-13 resumed simulation work:** The Windows submission performance gate
passed on `5b7dffbb`: 317 checks, 176 exact hooks, no failures. A fresh local V3
campaign completed nine wins in 146 rounds, no caps/failures, with 20/23 active
powers used. Directed fixtures cover the three absent powers. V4 addresses the
observed construction switching by keeping an active project focused while
retaining Repair and commissioning choices. See
`U13_DOCTRINE_COVERAGE_2026-09-13.md` for scope and the new fixture-only command.
The short Windows doctrine fixture gate passed on `35edeaf`: five suites,
456 checks, no failures or script errors on Godot 4.7.2. The V4 seed 19
diagnostic exposed repeated Ward versus ineffective Siege and was deliberately
stopped during round 28; keep that longer-game regression as the next directed
case, using only public observations. Keep the larger throughput work
for PySim and the Action Window / Resolution Theater as a later milestone.

**V5 directed Ward correction:** The saved round-25 stall had 83 travelling
enemy Castle-lane marchers and zero waiters. Ward scored all 83 as immediate
support; its formula also counted actual waiters twice. Score only enemy
waiters for this round's visible support threat, matching combat consumption.
Moving units still matter to spatial powers and Marching. This does not predict
the opponent's hidden hand or simultaneous order. See the coverage report for
the saved-position and fresh-match verification.

**Deferred visual feedback:** The Ward graphic is stretched too far and looks
poor. User requested moving on with doctrine; adjust its aspect/extent in the
next visual pass. No Ward artwork or rendering change is included here.

The uploaded earlier random-legal summary completed 100 games: 92 wins, 8 censored
at the round cap, zero failed/missing. Its own `gate_passed` is false because of
the capped games; it is neither current V3 balance evidence nor a clean full-win
gate. The playable build has since been exercised in two uploaded Windows games.

**2026-09-13 playable steering:** User clarified that the requested next runner
is a visible human-versus-doctrine game. `run_u13_playable.sh` now connects the
existing board to the production conductor, human draw/Slaver choices, complete
sealed plans, Tear rites, save/load and terminal victory. Doctrine V3 also fixes
Odradek saving and Kanifous wish valuation. Local engine and widget checks pass;
See `U13_PLAYABLE_RUNNER.md` for the subsequent Windows feedback and fixes. Keep the
Action Window / Resolution Theater and Action Forecast work as later milestones.

**2026-09-12 doctrine steering:** User authorized an early, bounded common planner
and Tier 1A targeting now, using the originating Astra handoff/Implementation Plan
v3 and individual ideas from legacy doctrine. Do not port the old Smart Core.
The `u13-basic-doctrine` branch adds a short simulation loop with explicit fast
versus independent replay scope; do not wait for the running 100-game campaign
before developing this pass. See `U13_BASIC_DOCTRINE_2026-09-12.md`.

**2026-09-12 steering:** Veil threshold effects and automatic drift are disabled
pending a dedicated design pass. Keep Tear accumulation and Lord Breach powers.
Victory resolution is now implemented after Aftermath; see
`U13_VICTORY_2026-09-12.md`. Next: autonomous matches through real termination
and the remaining candidate coverage audit. The separate 100-game runner is
now available in `U13_FULL_MATCH_BATCH_2026-09-12.md`; Windows batch acceptance
is pending.
This decision supersedes references below to implementing Veil effects before
the full-game and playable-UI milestones.

## Next engineering priority: simulation performance

User steering: the slow batch was canceled for a targeted performance pass.
Multi-hour batches are not acceptable as the routine test loop. Do not require
another 100-game run for every change. Keep extensive throughput work for the
later PySim parity rebuild.

Before the next large campaign:

- Profile legal-plan generation, ordinary resolution/Marching, snapshot encoding
  and restoration, and complete-state/history comparisons separately.
- Measure growing event-history cost and compare one versus four workers using
  the same seeds and runtime. Separate per-game CPU cost from wall-clock contention.
- The uploaded round-7 checkpoint confirmed expensive power previews and history
  copying. The targeted fix removes redundant temporary order transactions and
  entity copies; batch mode omits position samples. Full-trace gameplay state and
  plans match the prior implementation; compact/full gameplay also matches.
  See `U13_SIM_PERFORMANCE_2026-09-12.md` for evidence and scope.
- Establish a fast targeted regression loop and a separate lightweight simulation
  throughput benchmark. Keep the full 100-game replay batch as an occasional
  integration gate, with explicit scope for each tier.
- Record before/after timings, hardware/runtime, game rounds and validation scope;
  select practical time budgets from measurements rather than inventing a target.

This bookmark does not authorize replacing correctness checks with approximate
comparisons or declaring capped games victories. Veil effects and drift stay off.

## 1. Immediate Objective

Once all nine Lords are mechanically complete, the next goal is:

> **Make U13 capable of autonomously playing an entire legitimate match from setup to victory.**

The work should proceed in this order:

1. Full U13 game runner
2. Full-game Random-Legal bot
3. Full playable U13 runner/UI
4. Action Window + Resolution Theater presentation pass
5. U13 Action Forecast
6. PySim parity rebuild
7. Smart Core doctrine rebuild
8. Serious balance campaign
9. Roguelite/meta-progression layer

---

## 2. Full U13 Game Runner

Wire the existing U13 systems into one complete authoritative match.

Required systems include:
- opening setup / deal
- normal round draws
- Development
- Construction / Commission / Repair / Reconstruction
- duplicate Castle support
- shared Castle Guard zone
- Siege / Ward / Hunt
- Pillage where applicable
- Lord Banishment and resummoning
- Vacant Throne behavior
- waiter support
- waiter-to-personal-Tear spending
- Souls, personal Tears, Neutral Tears
- Veil accounting; threshold effects and automatic drift disabled pending redesign
- Dominion / victory
- Castle picker/loadout state
- complete save/load and replay

**Acceptance:** setup → rounds → submissions → combat → Marching → Veil/victory, with no fixture intervention.

---

## 3. Full-Game Random-Legal Bot

Before teaching the bot to play well, make it capable of always producing a **complete legal submission**.

It must handle:
- combat action and commitments
- Castle action
- Construction / Commission / Repair / Reconstruction
- Lord powers and targets
- spatial targets
- resource payments
- waiter spending
- resummoning
- every other required round choice

Random-Legal exists for reachability and stability, not balance.

**First serious gate:** 100–1,000 complete games with:
- no crashes
- no deadlocks
- no illegal prompts after submission lock
- no orphaned pending effects
- deterministic replay
- legitimate game termination

---

## 4. Full Playable U13 Runner / UI

Once the authoritative game runner is stable, connect it to the actual board.

The UI must use the same authoritative legality and submission path as bots and tests.

Goals:
- human vs bot full matches
- all nine Lords
- Castle picker
- duplicate Castle rules
- Construction / Commission states
- Lord targeting
- Marching visuals
- persistent effects
- Veil and victory flow
- complete save/replay

At this point U13 becomes **the game**, not a collection of subsystem runners.

---

---

## 4A. Presentation Pass — Action Window / Resolution Theater

The next phase should also deliberately restore the presentation layer that made the playable build feel like a game rather than only an authoritative simulation.

These systems are **not blockers for mechanical correctness**, but they should be included in the immediate post-overhaul phase rather than deferred indefinitely.

### Existing reference systems

Relevant existing presentation code includes:

```text
Prototype/UI2/ActionZone.gd
Prototype/UI2/ResolutionTheater.gd
Prototype/U13/U13ActionZone.gd
```

These should be treated as presentation references and reusable components where appropriate, not as alternate authorities for gameplay rules.

### Action Window

Restore the Action Window as the primary presentation surface for:
- selected action
- target
- committed cards
- projected/forecast pressure
- Lord-power additions that materially modify the action
- submission state / confirmation
- concise explanation of what the player is attempting

The Action Window should consume authoritative U13 state and legality. It must not invent or own game rules.

It should integrate cleanly with the planned `U13ActionForecast.gd` so that Hunt/Siege/Pillage odds can be shown in the same place the player is making the decision.

### Resolution Theater

Restore the Resolution Theater for important resolved confrontations.

Its job is presentation, not simulation.

It should visualize major events such as:
- Hunt resolution
- Siege resolution
- Guard clashes
- Lord confrontations
- significant Castle attacks
- other high-value battle moments where a focused presentation improves readability

The underlying result must already be decided by the authoritative U13 engine. The theater receives a resolved event/result package and plays the corresponding visual sequence.

### Architectural rule

> **Authority resolves first. Presentation observes and dramatizes second.**

Neither the Action Window nor Resolution Theater should be able to change the authoritative result.

This separation is especially important in U13 because:
- all submissions are locked before resolution,
- replay must remain deterministic,
- Marching and Lord effects may resolve through multiple authoritative hooks,
- presentation timing should never affect gameplay timing.

### Scope for the next phase

The initial goal is not final polish.

A successful first pass only needs:
- Action Window wired to real U13 submission state,
- Resolution Theater receiving and displaying real U13 resolution packages,
- clear handoff between authoritative resolution and presentation,
- no duplicated combat logic,
- no blocking prompts after submission lock,
- replay-safe presentation triggers.

Once those are functioning, animation quality and dramatic polish can continue incrementally.


## 5. PySim Rebuild

Update PySim only after the U13 battle rules stop moving rapidly.

> **Godot U13 = authoritative implementation.**
> **PySim = fast behavioral mirror for large-scale testing.**

PySim should mirror only outcome-relevant mechanics, not UI/presentation.

Policies remain external to the rules engine. Experimental policies are loaded
by the Python harness; only the selected shipping doctrine needs a matching
Godot decision implementation. Measure rules, policy and export costs separately
during the parity build, including an early Marching performance spike. Follow
the [policy and performance gates](U13_PYSIM_POLICY_AND_PERFORMANCE_2026-09-15.md)
before assuming tens-of-thousands-of-games throughput.

### Parity before balance

For identical seeds, setups, and submissions, Godot and PySim should agree on:
- Marcher creation and IDs
- movement/contact
- combat and kills
- Guards
- Castle state
- Lord state
- Souls
- personal/Neutral Tears
- Veil
- power outcomes
- winner

Maintain approximately **50–100 deterministic reference games** that both engines reproduce exactly before trusting PySim for balance work.

---

---

## 5A. Player-Facing Action Forecast / Success-Chance System

U12 already had a useful player-facing forecast layer in:

```text
Scripts/Sim/ActionForecast.gd
```

That system exposed modeled **Hunt** and **Siege** outcomes before commitment through functions such as:

```text
forecast_hunt(...)
forecast_siege(...)
forecast_all(...)
```

It was more than a simple attack-versus-defense percentage. The U12 forecast model accounted for hidden Guard uncertainty, opponent hand size / Ward possibility, commitment depth, and other public information to present the player with an estimated chance/pressure picture before choosing an action.

### U13 direction

Do **not** directly port the old implementation unchanged.

Instead, build a clean U13 equivalent after the full authoritative match loop is wired:

```text
U13ActionForecast.gd
```

The U13 forecast should:

- read from the same authoritative public-state representation used by the playable UI and bot doctrine,
- respect the one-complete-submission-per-round structure,
- never reveal hidden information,
- model current U13 Hunt/Siege/Pillage legality,
- account for U13 Guards, Ward, waiter support, Lord modifiers, Castle state, and other relevant known effects,
- present success likelihood / pressure estimates before submission lock,
- remain non-authoritative: it advises the player but never resolves gameplay,
- be deterministic for the same visible state and forecast assumptions,
- expose its calculations in a form that can also be reused by Smart Core.

### Architecture relationship

The forecast layer should become a **shared analysis service**, not UI-only code.

That means:

> **Playable UI uses it to show the player estimated success chances.**
> **Common Smart Core uses the same underlying forecast information for decision scoring.**

This prevents the human UI and bot from maintaining separate interpretations of combat odds.

The old U12 `ActionForecast.gd` should be treated as a valuable reference for proven modeling ideas, just like the old Smart Core: **reuse the useful logic and assumptions that remain valid, but rebuild against U13's authoritative rules and public-state boundaries.**

### Recommended timing

Implement this after the full U13 game conductor and Random-Legal path are stable, and before serious Smart Core tuning.

Suggested sequence:

> full game conductor → Random-Legal full matches → playable U13 → **U13 Action Forecast** → PySim parity → Smart Core doctrine


## 6. Smart Core: Rebuild Architecture, Reuse Proven Ideas

Do **not** port the old Smart Core architecture wholesale.

Too much changed in U13:
- one complete locked submission
- new Lord timing
- spatial Marching
- duplicate/commissioned Castles
- new waiter economy
- new Veil/Tear routes
- persistent effects

However, the old Smart Core remains valuable as a source of proven heuristics:
- card valuation
- combat commitment valuation
- Siege vs Ward reasoning
- Hunt valuation
- target scoring
- forecast shortcuts
- deterministic tie-breaking
- risk evaluation

**Reuse ideas, not the old monolith.**

---

## 7. Recommended Bot Architecture

### Tier 0 — Safe Legal Fallback
Always produces a legal submission.

### Tier 1 — Random Legal
Deterministic random choice among legal complete submissions.

### Tier 2 — Common Smart Core
General Corruptor intelligence independent of Lord identity.

Recommended files:

```text
U13BotPolicy.gd
U13CommonDoctrine.gd
U13CombatDoctrine.gd
U13CastleDoctrine.gd
U13VeilDoctrine.gd
```

Responsibilities:
- `U13BotPolicy`: orchestrates one complete submission
- `U13CommonDoctrine`: scoring utilities, card value, risk, tie-breaking
- `U13CombatDoctrine`: Siege/Ward/Hunt/commitments
- `U13CastleDoctrine`: build/repair/commission/reconstruct/composition
- `U13VeilDoctrine`: waiter spending, Tears, Dominion, Veil pressure

---

## 8. Separate Lord Doctrine Files

Each Lord gets its **own doctrine module**.

Recommended structure:

```text
U13LordDoctrineRegistry.gd
U13GremoryDoctrine.gd
U13DeimosDoctrine.gd
U13HumbabaDoctrine.gd
U13KalliganDoctrine.gd
U13OriasDoctrine.gd
U13OdradekDoctrine.gd
U13ValakDoctrine.gd
U13KroniDoctrine.gd
U13KanifousDoctrine.gd
```

Lord doctrine should evaluate decisions only. It must not execute mechanics or mutate authoritative state.

Typical responsibilities:
- `score_power(...)`
- `choose_targets(...)`
- `score_spatial_region(...)`
- `score_combination(...)`
- `adjust_submission_score(...)`

All legality continues to come from the same authoritative system used by humans and Random-Legal.

### Why this matters

Per-Lord modules prevent a giant `if lord == ...` doctrine file and make it possible to compare:
- Common Smart Core + random Lord behavior
- Common Smart Core + Lord Doctrine v1
- Common Smart Core + Lord Doctrine v2

This helps distinguish **a weak Lord** from **a bot that does not understand the Lord**.

---

## 9. Serious Balance Campaign

Balance work begins only after:
- full U13 game loop is stable
- Random-Legal survives large batches
- PySim parity is established
- Smart Core can play every Lord competently

Recommended analyses:
- all 81 ordered Lord matchups
- crossed seats
- thousands/tens of thousands of seeds
- Castle composition tests
- duplicate-Castle strategies
- Commission timing
- waiter threshold sweeps
- Veil timing
- cooldown/radius/damage parameter sweeps
- Kanifous Price weights
- Orias Web tuning
- Valak Gravity Orb tuning
- Kroni Hunger sustainability
- Kalligan Scorch tuning
- Deimos artillery pressure
- Humbaba survivability
- Odradek doctrine skill ceiling
- power-ablation tests

**Random-Legal proves reachability. Smart doctrine + PySim provides balance evidence.**

---

## 10. Recommended Order After Lord #9

1. Full U13 conductor
2. Full Random-Legal policy
3. 100–1,000 complete Godot games
4. Full playable human-vs-bot U13
5. Wire Action Window + Resolution Theater to authoritative U13 events/state
6. Build U13 Action Forecast
7. Freeze a mechanical checkpoint
8. Update PySim
9. Prove Godot ↔ PySim parity
10. Build Common Smart Core
11. Add one Lord doctrine at a time
12. Run the serious balance campaign
13. Build roguelite/meta progression

---

## 11. Roguelite Layer Comes After the Trusted Battle Core

The roguelite wrapper should build on the completed battle game.

Current direction:
- about five Lords per run
- start weaker than the fully unlocked base game
- progression restores options rather than stacking permanent stat bonuses
- Lord powers can be unlocked
- Castle blueprints can be unlocked
- special Marcher recipes can be unlocked
- approximately 10 special Marcher recipes, with 1 starter and ~9 later unlocks
- fully progressed account eventually reaches the complete battle ruleset

---

## 12. Next Major Milestone

# FULL U13 AUTONOMOUS MATCH

A Random-Legal match must be able to:

1. initialize a legal setup
2. choose complete submissions
3. resolve every round
4. use all base systems
5. interact with all Lord systems
6. save/load deterministically
7. reach a legitimate victory condition
8. finish without manual intervention

When this is green across a large batch, U13 has crossed from:

> **Lord-overhaul architecture**

to:

> **complete game architecture**
