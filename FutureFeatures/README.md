> **2026-09-17 doctrine resumed:** The user paused balance at `cfee89a`. The [recipe and Veil doctrine pass](../docs/U13_RECIPE_VEIL_DOCTRINE_2026-09-17.md) adds deliberate recipe commitments/saving, public protection judgment and a Gravity/monster interaction fix. This is a Python experiment; local checks and pending Windows acceptance are recorded separately from historical gates.

# Corruptor — consolidated roadmap

**Updated 2026-09-16 · planning baseline · branch: `u13-basic-doctrine`**

Start here for project priorities. This distills FutureFeatures and the relevant U13 planning/acceptance documents. It replaces their competing “next task” lists for navigation, while preserving original designs, implementation notes and evidence. It does not change game rules or start every item below.

**Immediate engineering path:** preserve accepted nine-Lord parity and the common-doctrine alpha → integrate the monster recipes and new Veil currently being developed in parallel → establish parity for those additions → expand native coverage and improve doctrine → run meaningful balance campaigns. **UI redesign is a parallel presentation track**, now that the first Forecast is playable. The larger native reference campaign and weight tuning wait for the intended monster/Veil rules; shared planner contracts and Lord examples can progress meanwhile.

## Release milestones — Steam Early Access, then 1.0

**Confirmed direction, 2026-09-15:** the beta release goal is **Steam Early Access**. Final art assets and production polish will be developed during Early Access; completion of those assets is not a prerequisite for that first public release.

Planning distinction:
- **Before Early Access:** prioritize a stable, enjoyable and understandable playable offering, reliable saves, usable onboarding and readable provisional assets. The exact initial content roster and run/progression scope still need to be set; this clarification does not automatically require every roadmap feature at launch.
- **During Early Access:** replace provisional art with final assets, refine animation/audio/UI, iterate on balance and progression using player feedback, and complete the agreed content scope.
- **1.0:** the later finished-release milestone, with final production assets and the chosen feature scope complete.

Earlier estimates for a fully polished release should not be treated as Early Access deadlines. Prototype art remains useful, provided it communicates gameplay clearly. The full authored prologue's Early Access timing remains a separate scope decision; players still need enough onboarding to play.

## 1. What already exists

| Area | Current evidence and limits |
|---|---|
| U13 battle core and nine-Lord full-game path | Accepted Windows 4.7.2 campaign at `357d793`: 100/100 complete, replay-verified Random-Legal matches, all 81 ordered Lord pairings, no caps or failures. Mean 20.07 rounds. This proves the tested game path, not Lord balance. |
| Playable human-versus-bot U13 | Accepted playable integration; shared action modal, Work/Guard planning, Aftermath ledger, save/load and victory flow exist. Preserve them while redesigning presentation. |
| Public Guards and first Action Forecast | User accepted the Forecast at `dd9638c`; integrated with the sprite gallery. Deployed Guards and bonds are public; hands and sealed orders remain private. Forecast is a labeled current-board baseline, not a promised probability of success. |
| Basic doctrine | A working common planner and Lord targeting already exist. The next doctrine milestone improves/restructures that baseline; it is not “build the first bot.” |
| Python mirror | Foundation through ordinary resolution retains its dated Windows acceptance. The four-Lord [ordinary full-match gate](../docs/U13_PYSIM_FULL_MATCH_2026-09-15.md) passed at `d059b95`; [paid Development](../docs/U13_PYSIM_PAID_DEVELOPMENT_2026-09-16.md) passed at `24792a6`: four exact games / 57 rounds, 77 tests per Python runtime and 20 corruption rejections. The new [nine-Lord adapter](../docs/U13_PYSIM_NINE_LORDS_2026-09-16.md) implements all 23 powers and remaining Lord lifecycles. Its focused Windows 4.7.2 / CPython / PyPy gate passed at clean `5fb53e7`: five exact games / 81 rounds, 34 components, all 23 powers, 2,400 directed tick frames and 16 corruption rejections. |
| Doctrine diagnostics | [Accepted on Windows CPython and PyPy at clean `a7544d6`](../docs/U13_DOCTRINE_START_2026-09-16.md): 20 tests per runtime, identical diagnostic records and all 767 original decisions/final states. This validates the observer and contracts, not a new planner. |
| Fresh common doctrine alpha | [Accepted on Windows CPython and PyPy at clean `d9457a9`](../docs/U13_COMMON_DOCTRINE_ALPHA_2026-09-16.md): 36 tests per runtime, five games / 72 rounds / 1,792 operations, identical choices/final states/diagnostics, zero rejected plans and all candidate caps respected. Nine separate Lord modules; 19 of 23 powers selected naturally. These new choices have not been replayed through Godot and establish no strength result. |
| Python copying optimization | Accepted at `88ef438`: matched partial-cycle means 20.31 → 7.98 ms, 2.54× throughput. These partial results do not establish the new full-match cost. |
| Full-match rollback optimization | [Windows-accepted at clean `c228d85`](../docs/U13_PYSIM_FULL_MATCH_COPYING_2026-09-15.md). Both CPython and PyPy passed all 63 tests and exact full-game replay, including 13 corruption checks. Twenty consecutive games per implementation/runtime measured CPython 12.92 → 2.71 seconds (4.78×) and PyPy 7.83 → 1.45 (5.40×); all 80 final digests matched. PyPy's final ten averaged 1.23 seconds. These repeat two ordinary games; policy cost, memory and worker scaling remain unmeasured. |
| Optimized full-match profile | [Windows capture accepted at clean `76e80fd`](../docs/U13_PYSIM_OPTIMIZED_PROFILE_2026-09-15.md), with unchanged `c228d85` engine source. All 64 repeated final digests matched; three observer tests passed per runtime. PyPy mean 1.439 seconds, final ten 1.263. Movement and registry restoration are bounded candidates; another quick 2–3× is unproven. CPython's 5.566-second mean has unresolved variability; the identical timed worker excludes digesting. |
| Focused Marching optimization | [Windows correctness accepted at clean `ad30730`](../docs/U13_PYSIM_MARCHING_OPTIMIZATION_2026-09-15.md): both runtimes passed 67 engine + 3 comparison tests and both exact replay gates; all 160 timed final digests matched. CPython 3.358 → 2.518 s (1.333x). PyPy 1.453 → 1.499 s (0.970x), with disagreeing paired results; no demonstrated PyPy gain. Retain the verified change and close optional optimization. |
| PyPy runtime | [PyPy 7.3.23 passed](../docs/U13_PYSIM_PYPY_2026-09-15.md) the same full-match replay at `d059b95`, including 13 corruption rejections; the user also supplied 56 passing unit tests. Ten timing samples per game average 3.73 / 6.53 seconds versus CPython's earlier 11.34 / 19.07: an observed 2.96× gain with unchanged source/inputs. This remains a two-game reference, with early-sample warmup behavior and no worker-scaling or memory measurement. |
| Python Marching spike | Windows 4.7.2 acceptance passed at clean `e8cc3f9`: 28 phases / 5,600 tick frames, 394 Godot checks, 46 Python tests and 14 corruption probes. Flat columns, explicit keyed contact ordering and prepared Web/aura/Rout/Gravity behavior are covered. The new full-world integration preserves this isolated API's boundary and evidence. |
| Animation previews | Subject/monster gallery integration exists. Preview artwork and animations do not establish gameplay implementation of the ten recipe monsters. |
| Monster design | [Recipes v0.1](Corruptor-Monster-Recipes-v0.1.md) is the accepted starting recipe baseline, with combat values and open balance questions recorded. The user is implementing recipes concurrently; the accepted Python checkpoints do not yet cover them. |

Sources: [accepted checkpoint](../docs/U13_ACCEPTED_CHECKPOINT_2026-09-15.md), [action flow](../docs/U13_ACTION_FLOW_2026-09-14.md), [Forecast](../docs/U13_ACTION_FORECAST_2026-09-14.md), [Development](../docs/U13_PYSIM_DEVELOPMENT_2026-09-15.md), [copying pass](../docs/U13_PYSIM_COPYING_2026-09-15.md), [resolution acceptance](../docs/U13_PYSIM_RESOLUTION_2026-09-15.md), [Marching spike and timings](../docs/U13_PYSIM_MARCHING_2026-09-15.md).

## 2. Next — finish the fast, trustworthy experiment engine

Extend the existing mirror in dependency order:

1. The [focused Marching Windows comparison](../docs/U13_PYSIM_MARCHING_OPTIMIZATION_2026-09-15.md) is complete against `c228d85`. Preserve its mixed performance finding: CPython improved, PyPy did not show a consistent gain. **User direction: close optional optimization and begin doctrine; do not automatically open another performance cycle.** The first [doctrine diagnostic checkpoint](../docs/U13_DOCTRINE_START_2026-09-16.md) passed its Windows dual-runtime check. Keep remaining rules-parity and scoped-throughput gates visible; the ordinary games do not establish full-roster readiness. Collect a matched Godot/Python pure-match comparison before claiming a cross-engine speed ratio.
2. Paid Rites/Resummon passed at `24792a6`. The [nine-Lord implementation](../docs/U13_PYSIM_NINE_LORDS_2026-09-16.md) adds declared/persistent effects, timing, cooldowns, allegiance and spatial actors. Its focused Windows acceptance passed at `5fb53e7`; the bounded common planner and separate Lord modules passed their Python dual-runtime behavior gate at `d9457a9`.
3. The user is implementing monster recipes and the new Veil concurrently. Once those authoritative changes land, mirror them in PySim and adapt recipe card reservations, summoning choices and victory judgment in doctrine. Establish focused parity before growing the exact native reference corpus to approximately 50–100 games. Defer that expensive campaign until it covers the intended rules; neither five-game checkpoint replaces it.
4. Measure target-hardware policy cost and worker scaling separately from simulation and export. Set the practical sweep budget from those results before building large doctrine sweeps.

**Done when:** identical explicit inputs produce matching Godot/Python states, ordered events and outcomes across the declared corpus, and complete-match throughput has a measured scope. Do not fill missing mechanics with fixture state or extrapolate 50,000-game speed from partial timings.

The accepted Marching spike uses parallel lists and separately measures validated import/publication against row dictionaries; it does not claim a row-versus-column tick-loop speedup. Windows single-worker means per 200-tick phase were 57.73 ms ordinary, 130.52 ms dense and 6.37 ms Gravity (13 of 14 units consumed). Dense median/p95 were 96.78 / 210.33 ms; the report records substantial variability. Movement/nearby searches dominate that isolated profile. Explicit contact order, earliest arrival and keyed ties match, including reversed registry order. These phase timings establish no 50 ms whole-match budget. The [first complete-game timing](../docs/U13_PYSIM_FULL_MATCH_2026-09-15.md) has its own scope; earlier Linux and Development-only timings remain separate.

Keep experimental policies outside the rules engine. Their public observations, legal-choice inputs, versioned weights and deterministic policy RNG belong to the harness. Only the selected shipping doctrine needs a corresponding Godot decision implementation.

Sources: [parity inventory](../docs/U13_PYSIM_PARITY_2026-09-15.md), [policy and performance gates](../docs/U13_PYSIM_POLICY_AND_PERFORMANCE_2026-09-15.md).

## 3. Next — competent opponents and useful balance evidence

The [fresh CommonSmartCore alpha](../docs/U13_COMMON_DOCTRINE_ALPHA_2026-09-16.md) implements the bounded Python planner and nine separate Lord modules. Its focused Windows behavior/dual-runtime gate passed at `d9457a9`. Continue directed useful/hold/timing examples while monster/Veil implementation proceeds; integrate and verify those mechanics before expanded native decision parity, shared-weight tuning and strength testing.

- **2026-09-16 start:** [Diagnostic checkpoint and revised sequence](../docs/U13_DOCTRINE_START_2026-09-16.md). Build fresh common doctrine with basic competence for all nine Lords and separate Lord files. U12 supplies selected ideas and regression cases, not the new architecture. Counters precede the planner; full-roster rules parity precedes shared-weight tuning. The Windows/PyPy diagnostics passed at `a7544d6`; paid Rites/Resummon passed at `24792a6`. The remaining nine-Lord rules passed their focused Windows gate at `5fb53e7`. The existing reference observer still measures ordinary choices only.
- Improve common decisions around defense, Work, attack commitment, Supplicant use, resummoning and Tear/Veil consequences.
- Keep Lord-specific decision modules separate from authority and from one another. Compare common doctrine with and without each Lord module to distinguish weak play from a weak kit.
- Apply the reconciled [Veil-clock contract](BOT_VEIL_CLOCK_SANITY.md) at actual end-of-round settlement: exclude a provable, avoidable enemy win; retain uncertain pressure and legal last-chance plans. The old “materially advances” blanket restriction is retired.
- The new recorder distinguishes unsupported, unmeasured and measured-zero opportunity/eligibility/selection/effects. Add complete candidate-generation, budget-removal and preference explanations in the new planner before weight sweeps. The current observer measures final choices from the existing Python reference policy; it does not invent that policy's internal reasoning.
- Use matched seeds, crossed seats, all 81 ordered matchups, power ablations and held-out checks. Report matchup distributions, not just roster averages.
- Separate rules experiments from policy experiments. Use an appropriate neutral/forced-policy control for structural questions, then the real roster for interactions; July's Vanilla numbers are historical, not U13 targets.

**Done when:** important mechanics are meaningfully exercised, the selected doctrine obeys information boundaries, and measured weaknesses survive competent play before kit changes are proposed.

Keep balance work iterative. The 100-game Godot campaign is an integration gate, not a mandatory rerun for every document, visual adjustment or isolated fix.

## 4. Parallel track — make the playable game readable and satisfying

The [UI overhaul brief](UI_OVERHAUL.md) explicitly follows a trustworthy playable Forecast. That first pass is now accepted, so this track can proceed without waiting for every Python mechanic.

- Redesign the hierarchy around the current decision: resources, public board state, chosen action/target, committed cards, reservations, Forecast assumptions and confirmation.
- Reduce modal friction and text density while preserving staged orders and authoritative legality.
- Unify card, Castle, Lord, Guard, Sigil, Soul/Tear/Veil and turn-state presentation.
- Audit the existing U13 action flow before replacing components. Restore or complete the Resolution Theater using already-resolved event packages; its full U13 completion is not established by the reviewed checkpoint.
- Include the deferred Ward graphic aspect/extent correction and verify Castle construction/damage presentation. The Castle fragment/shader work is documented as implemented with visual acceptance pending, not a feature to recreate from zero.
- Continue sprite cropping, anchors, state transitions, sizing and in-engine checks through the existing gallery. Prepare consistent briefs for eventual artist replacement.

**Done when:** an unfamiliar player can understand what they can do, why an action is legal, what the Forecast assumes and what actually happened. Presentation must never change simulation outcomes or require post-lock choices.

Sources: [UI brief](UI_OVERHAUL.md), [presentation plan](../docs/U13_POST_OVERHAUL_ROADMAP.md), [Castle visual follow-up](../docs/U13_CASTLE_DAMAGE_PRESENTATION_BACKLOG_2026-09-08.md). Forecast refinements must explicitly model additional dependencies before presenting calibrated odds.

## 5. Parallel rules work — monsters through commitment and the new Veil

**User direction, 2026-09-16:** monster recipes and the new Veil system are being
implemented concurrently. This moves their integration ahead of the expanded
native reference campaign and balance tuning. Their actual authoritative
implementation governs the Python port; the sequence below remains design
context, not permission to invent unresolved mechanics. Existing accepted
rules and doctrine evidence predates both additions.

Use [Monster Recipes v0.1](Corruptor-Monster-Recipes-v0.1.md) as the single recipe table. Keep the overlap with defensive pairs: reinforcement, saving and summoning should compete for useful cards.

Suggested integration sequence:

1. Recipe eligibility and choice at commitment, with one selected summon alongside normal marchers. Extra committed cards are allowed; only unlocked, eligible recipes qualify.
2. Lemek as the starter and Varn as the other easy recipe. A Varn swarm is one summon.
3. Moderate and hard creatures in small mechanic-focused slices.
4. Sooge's permanent turret transition and Sinodek's banishment behavior; enforce one living copy of each type per player. Death/banishment frees that type's slot, with no additional cooldown.
5. Mirror each accepted rules addition in PySim and extend doctrine, Forecast and presentation as applicable.

Before implementation, settle the missing ability probabilities/ranges, Sinodek stats, swarm-size distribution and precise spatial interactions. Measure card saving against actual defensive placement opportunities and recurring Vulture income.

**Balance questions:** can beginners use easy recipes regularly? Do moderate monsters justify interrupting a very-hard recipe? Does saving create a worthwhile short-term sacrifice? Are particular subjects effectively cheaper because their defensive options are less valuable?

The 20-round simulations, one-extra-saved-card policy, three-round very-hard lifespan and random 50% defensive-pair expenditure are experiment assumptions, not new game rules. Guard formations that remain intact can naturally leave pairs available for monsters.

## 6. Then — a complete run and progression

Current direction: roughly five Lord battles per run, aiming around 15 minutes per battle / 75 minutes per run, subject to playtesting. Twenty rounds is a simulation baseline, not a forced battle length.

Build one complete, saveable, winnable and losable run before broad meta-content:

- Select a Lord and face a sequence of opponents.
- Start with a restricted set of options; unlock Lord powers, Castle blueprints and monster recipes.
- Make progression primarily restore and diversify options rather than apply permanent raw-stat inflation.
- Establish rewards, between-battle choices, failure/restart flow and persistent unlocks.
- Test whether players want to begin another run and can explain the choices shaping their build.

**Still requires design decisions:** exact reward cadence, within-run versus account unlocks, opponent order/final boss, what carries between battles, and how difficulty increases. The old global run Veil, persistent Castle damage, stacking Breaches, rank ladder and five-currency/unlock ideas remain candidate designs; they are not silently adopted by this roadmap.

Sources: [U13 progression direction](../docs/U13_POST_OVERHAUL_ROADMAP.md), [older product roadmap](../corruptor_godot_roadmap_v3.md).

## 7. Tutorial and authored opening — The Fifth Day

[The definitive prologue](Tutorialopen.docx), SPEC-PROLOGUE-001, supplies the detailed narrative. It supersedes the older “First Rite” shorthand and forced-loss framing.

- Aldric's wife truly returns; her eventual fate stays unresolved. Kanifous never speaks to or acknowledges Aldric as a rival.
- Teach the core grammar through real Subjects, a legally modeled Cottage/Castle, Guards, Ward, commitment, Reveal, Hunt, Banishment and resummoning.
- Aldric can genuinely banish Kanifous. Kanifous pays his live Summon requirement and returns through ordinary rules.
- The scenario ends because Aldric's story is complete, not because the engine fabricates defeat, removes his legal moves or displays a Retry screen.
- Use dark engraved/woodcut motion-comic presentation and restrained animation. Subjects remain recognizably human.
- Target 8–12 minutes for the interactive portion. Advanced Dominion, monster strategy and run mastery can be taught later.

Prototype legal scenario states once the relevant battle/UI contracts are stable; complete the handoff to Lord selection with the run flow. Use current Forecast capabilities honestly—do not convert the current baseline into an unsupported “guaranteed” result for dramatic effect.

**Done when:** a saved decisive scenario reproduces the same legal Hunt → Banishment → paid Summon sequence outside tutorial presentation, and new players understand the basic loop without being taught false rules.

## 8. Parked or longer horizon

| Feature | What to retain | Gate / unresolved scope |
|---|---|---|
| Alternate round events | Potential variety alongside the Slaver | Deferred by the current design discussion. Slaver remains available every round. |
| Veil threshold effects | [Permanent Breach proposal](Corruptor-Veil-Permanent-Breaches-Proposal-v0.2.md): hidden absent-Lord arrivals, Personal Tear protection and ongoing Humbaba erosion | Current threshold penalties are disabled. Existing round-pressure Tears remain active; “drift off” in older notes is stale. |
| The Read / tell system | Pattern-first, per-opponent learning, sample-size gating; tempo only with calibrated baselines | Proven-fun loop, competent distinct bosses and repeated-opponent data. Preserve useful policy diagnostics/profile seams; do not build glyphs now. |
| Async multiplayer | Simultaneous orders, multiple active matches, replayable state; realtime as a possible companion | Retain as a product ambition. Launch inclusion, networking authority, hidden-information protection, reconnect/abandonment and version compatibility need a dedicated plan. The old commit-reveal sketch is not a complete networking design. |
| Broader progression/lore | Mastered Breaches, rank ladder, world progression and campaign terminus | Revisit after the first run demonstrates its value; avoid committing to every old progression idea at once. |
| Early Access → 1.0 production | Final art replacement, animation/audio/UI refinement, content and balance iteration | Steam Early Access is the beta release target. Final production assets follow during Early Access; readable presentation, stability and usable onboarding remain first-release priorities. |
| Ranked, additional Lords, 2v2, mobile | Preserve as expansion possibilities | No implementation priority or launch requirement assigned here. |

Tell source: [The Read v0.1](corruptor_tell_system_design_v0.1.md). Multiplayer and older expansion concepts: [product roadmap v3](../corruptor_godot_roadmap_v3.md).

## 9. Source disposition and precedence

No source files were deleted or moved. “Historical” below describes their role, not their usefulness.

| Source | How to use it now |
|---|---|
| [The Eroding World — Permanent Breaches](Corruptor-Veil-Permanent-Breaches-Proposal-v0.2.md) | Design source: permanent absent-Lord Breaches replace the older physical-rift direction; four individual arrivals, an unprotectable cascade requiring Veil 21+ and round 21+ (preferred; ungated alternative retained), and protection thresholds remain provisional here. The user is implementing the new Veil concurrently; inspect the final authority before porting. Existing Python parity does not cover it. |
| [Final Blows and the Final Rite](Corruptor-Finals-Theoretical-v0.1.md) | Withdrawn in full by Permanent Breaches v0.2. Historical only: finishing Hunt, final rite and four-suit defensive payment are no longer pending proposals. |
| [Monster Recipes v0.1](Corruptor-Monster-Recipes-v0.1.md) | Current starting recipe baseline; revise deliberately as balance evidence arrives. |
| [UI_OVERHAUL](UI_OVERHAUL.md) | Retained presentation brief; first Forecast prerequisite now met at its documented scope. |
| [Tutorialopen.docx](Tutorialopen.docx) | Detailed prologue/narrative reference; reconcile scenario setup with current mechanics at implementation. |
| [BOT_VEIL_CLOCK_SANITY](BOT_VEIL_CLOCK_SANITY.md) | Carry forward its immediate-loss regression intent; adapt to current U13 victory timing and public information. |
| [Veil/Siege/Construction addendum](CORRUPTOR_DESIGN_ADDENDUM_VEIL_SIEGE_CONSTRUCTION.md) | Historical mechanics proposals and rationale. Current Work/pairs, victory, Pillage and Lord implementations govern. Do not resurrect paid repair, old thresholds or old kit constants from it. |
| [Marching Orders v0.2](corruptor_marching_orders_design_v0.2.md) | Historical lane experiment. One-in-flight, Guard-launch and arrival-Tear rules do not replace U13 spatial Marching/Supplicants. |
| [Post-green v1](corruptor_post_green_roadmap.md), [v2](corruptor_post_green_roadmapv2.md), [v3](corruptor_post_green_roadmapv3.md) | Historical parity/balance campaigns. Preserve methodology and rejected-experiment context; no old win rates, proposed kits or “next” steps become current U13 instructions. Filename v3 still carries a v2 heading. |
| [Development devlog](corruptor_devlog_v1.md) | Methodology/history. Its Python-as-oracle direction is historical; Godot U13 is now authority and the new Python engine mirrors it. |
| [Playable prototype v7 ZIP](Corruptor_Playable_Prototype_v7_hidden_guards.zip) | Legacy prototype archive, not a feature backlog or current hidden-Guard policy. Inspected member inventory; no code imported. |
| [Root Godot roadmap v3](../corruptor_godot_roadmap_v3.md) | Product ambitions and candidate run/multiplayer ideas. Old timeline, costs and release checklist need fresh scoping. |
| [U13 post-overhaul plan](../docs/U13_POST_OVERHAUL_ROADMAP.md) | Detailed engineering history and architecture. Dated acceptance updates supersede its older pending-task sections; use this consolidated roadmap for ordering. |
| [Accepted checkpoint](../docs/U13_ACCEPTED_CHECKPOINT_2026-09-15.md) and dated PySim acceptance reports | Evidence for exactly the revisions, platforms and scopes they name. Newer accepted slices may advance this roadmap's snapshot. |

**Precedence:** explicit current design decisions → applicable accepted U13 rules/fixtures and dated evidence → current feature specifications → historical plans/experiments. A roadmap does not override implementation semantics or upgrade an untested proposal into an accepted rule.

Review basis: branch tree `9cdfc095fce68dd5fdd46462ccf235cf7bc9f68b`, followed by the recipe addition at `7c73f3e`. This is a planning snapshot, not a claim to validate every repository subsystem. New work in parallel should update its relevant acceptance report and then this summary.

## 10. Keeping this useful

Update the status table when a milestone is accepted; link its dated evidence instead of appending another competing roadmap. Keep proposals separate from accepted rules, and record why an item moved. Preserve U12 and legacy goldens as historical baselines.

The Marching comparison is complete at `ad30730` with correctness accepted and mixed timing results. Doctrine diagnostics passed at `a7544d6`, paid Rites/Resummon at `24792a6`, nine-Lord focused rules parity at `5fb53e7`, and the common planner's Windows dual-runtime behavior gate at `d9457a9`. Keep those exact scopes distinct. The first complete-game reference, dual-runtime copying comparison and unchanged-engine profile remain accepted at `d059b95`, `c228d85` and `76e80fd` respectively. The user is now implementing monster recipes and the new Veil in parallel: integrate them and establish focused parity before the larger native reference campaign or weight tuning. The UI overhaul remains a parallel presentation milestone. Campaign, prologue completion and optional online scope build on those foundations.
