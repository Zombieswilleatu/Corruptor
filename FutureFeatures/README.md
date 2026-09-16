# Corruptor — consolidated roadmap

**Updated 2026-09-15 · planning baseline · branch: `u13-basic-doctrine`**

Start here for project priorities. This distills FutureFeatures and the relevant U13 planning/acceptance documents. It replaces their competing “next task” lists for navigation, while preserving original designs, implementation notes and evidence. It does not change game rules or start every item below.

**Immediate engineering path:** finish the U13 Python mirror → establish full-match parity and measured throughput → improve common and Lord doctrine → run meaningful balance campaigns. **UI redesign is a parallel presentation track**, now that the first Forecast is playable. Monster integration follows a trusted battle baseline; the campaign builds on that.

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
| Python mirror | Foundation through ordinary resolution retains its dated Windows acceptance. A separate `FullMatch` connects all 20 hooks and repeated rounds for Gremory, Deimos, Humbaba and Kalligan with explicit ordinary decisions. The [focused full-match gate](../docs/U13_PYSIM_FULL_MATCH_2026-09-15.md) passed Windows 4.7.2 at clean `d059b95`: two complete games / 30 rounds / 767 operations, eight settlement components and one 200-tick probe. Independent replay reproduced the full summary. Declared powers, paid Rites/Resummon and the other Lords remain outside this adapter. |
| Python copying optimization | Accepted at `88ef438`: matched partial-cycle means 20.31 → 7.98 ms, 2.54× throughput. These partial results do not establish the new full-match cost. |
| Full-match rollback optimization | [Windows-accepted at clean `c228d85`](../docs/U13_PYSIM_FULL_MATCH_COPYING_2026-09-15.md). Both CPython and PyPy passed all 63 tests and exact full-game replay, including 13 corruption checks. Twenty consecutive games per implementation/runtime measured CPython 12.92 → 2.71 seconds (4.78×) and PyPy 7.83 → 1.45 (5.40×); all 80 final digests matched. PyPy's final ten averaged 1.23 seconds. These repeat two ordinary games; policy cost, memory and worker scaling remain unmeasured. |
| Optimized full-match profile | [Windows capture accepted at clean `76e80fd`](../docs/U13_PYSIM_OPTIMIZED_PROFILE_2026-09-15.md), with unchanged `c228d85` engine source. All 64 repeated final digests matched; three observer tests passed per runtime. PyPy mean 1.439 seconds, final ten 1.263. Movement and registry restoration are bounded candidates; another quick 2–3× is unproven. CPython's 5.566-second mean has unresolved variability; the identical timed worker excludes digesting. |
| Focused Marching optimization | [Implemented; Windows comparison pending](../docs/U13_PYSIM_MARCHING_OPTIMIZATION_2026-09-15.md). Skips nonlethal volley registry rebuilds and prunes nearest-target search while preserving exact two-dimensional/ID ties. Local tests and replay against both accepted Windows streams check the candidate; they do not establish Windows/PyPy speed. User intends this to be the likely last optional optimization before doctrine work. |
| PyPy runtime | [PyPy 7.3.23 passed](../docs/U13_PYSIM_PYPY_2026-09-15.md) the same full-match replay at `d059b95`, including 13 corruption rejections; the user also supplied 56 passing unit tests. Ten timing samples per game average 3.73 / 6.53 seconds versus CPython's earlier 11.34 / 19.07: an observed 2.96× gain with unchanged source/inputs. This remains a two-game reference, with early-sample warmup behavior and no worker-scaling or memory measurement. |
| Python Marching spike | Windows 4.7.2 acceptance passed at clean `e8cc3f9`: 28 phases / 5,600 tick frames, 394 Godot checks, 46 Python tests and 14 corruption probes. Flat columns, explicit keyed contact ordering and prepared Web/aura/Rout/Gravity behavior are covered. The new full-world integration preserves this isolated API's boundary and evidence. |
| Animation previews | Subject/monster gallery integration exists. Preview artwork and animations do not establish gameplay implementation of the ten recipe monsters. |
| Monster design | [Recipes v0.1](Corruptor-Monster-Recipes-v0.1.md) is the accepted starting recipe baseline, with combat values and open balance questions recorded. |

Sources: [accepted checkpoint](../docs/U13_ACCEPTED_CHECKPOINT_2026-09-15.md), [action flow](../docs/U13_ACTION_FLOW_2026-09-14.md), [Forecast](../docs/U13_ACTION_FORECAST_2026-09-14.md), [Development](../docs/U13_PYSIM_DEVELOPMENT_2026-09-15.md), [copying pass](../docs/U13_PYSIM_COPYING_2026-09-15.md), [resolution acceptance](../docs/U13_PYSIM_RESOLUTION_2026-09-15.md), [Marching spike and timings](../docs/U13_PYSIM_MARCHING_2026-09-15.md).

## 2. Next — finish the fast, trustworthy experiment engine

Extend the existing mirror in dependency order:

1. Finish the [focused Marching pass's Windows comparison](../docs/U13_PYSIM_MARCHING_OPTIMIZATION_2026-09-15.md) against `c228d85`, retaining exact replay, initial samples, later-game means and both control/candidate orderings under each runtime. CPython varied across unchanged-source captures, so use these matched controls. **User direction: likely the last optional optimization before doctrine work; do not automatically open another performance cycle.** Keep remaining rules-parity and scoped-throughput gates visible when planning doctrine; the two ordinary games do not establish full-roster readiness. Collect a matched Godot/Python pure-match comparison before claiming a cross-engine speed ratio.
2. Extend persistent effects, declared powers, Rites/Resummon and the remaining Lords, including timing, cooldowns, allegiance and spatial actors. Grow to approximately 50–100 exact full reference games after their mechanics are supported; the first two are not complete roster parity.
3. Measure target-hardware policy cost and worker scaling separately from simulation and export. Set the practical sweep budget from those results before building large doctrine sweeps.

**Done when:** identical explicit inputs produce matching Godot/Python states, ordered events and outcomes across the declared corpus, and complete-match throughput has a measured scope. Do not fill missing mechanics with fixture state or extrapolate 50,000-game speed from partial timings.

The accepted Marching spike uses parallel lists and separately measures validated import/publication against row dictionaries; it does not claim a row-versus-column tick-loop speedup. Windows single-worker means per 200-tick phase were 57.73 ms ordinary, 130.52 ms dense and 6.37 ms Gravity (13 of 14 units consumed). Dense median/p95 were 96.78 / 210.33 ms; the report records substantial variability. Movement/nearby searches dominate that isolated profile. Explicit contact order, earliest arrival and keyed ties match, including reversed registry order. These phase timings establish no 50 ms whole-match budget. The [first complete-game timing](../docs/U13_PYSIM_FULL_MATCH_2026-09-15.md) has its own scope; earlier Linux and Development-only timings remain separate.

Keep experimental policies outside the rules engine. Their public observations, legal-choice inputs, versioned weights and deterministic policy RNG belong to the harness. Only the selected shipping doctrine needs a corresponding Godot decision implementation.

Sources: [parity inventory](../docs/U13_PYSIM_PARITY_2026-09-15.md), [policy and performance gates](../docs/U13_PYSIM_POLICY_AND_PERFORMANCE_2026-09-15.md).

## 3. Next — competent opponents and useful balance evidence

- Improve common decisions around defense, Work, attack commitment, Supplicant use, resummoning and Tear/Veil consequences.
- Keep Lord-specific decision modules separate from authority and from one another. Compare common doctrine with and without each Lord module to distinguish weak play from a weak kit.
- Carry forward the [Veil-clock safety regression](BOT_VEIL_CLOCK_SANITY.md): do not voluntarily hand the opponent an immediate known win when the action does not change the winner in your favor. Evaluate current public-state consequences; reconcile the old spec's broader “materially advances” wording before turning it into a blanket ban on risky play.
- Add exposure, eligibility, selection and actual-effect counters before weight sweeps. A power that never fires is not balanced merely because its Lord's win rate looks reasonable.
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

## 5. Then — monsters through commitment

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
| Veil threshold effects | A dedicated future design question | Current threshold penalties are disabled. Existing round-pressure Tears remain active; “drift off” in older notes is stale. |
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
| [Final Blows and the Final Rite](Corruptor-Finals-Theoretical-v0.1.md) | Theoretical Ritual/Dominion finale proposal: finishing Hunt, telegraphed rite and four-suit defensive payment. Not implemented; timing and balance questions remain open. |
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

The next concrete engineering checkpoint is the implemented Marching pass's Windows comparison, then a shift of focus to doctrine while retaining the rules-parity and throughput gates in section 2. The first complete-game reference, dual-runtime copying comparison and unchanged-engine profile are accepted at `d059b95`, `c228d85` and `76e80fd` respectively; the new candidate is not yet Windows-accepted. The next major design/content milestone is the monster system; the next presentation milestone is the UI overhaul. Campaign, prologue completion and optional online scope build on those foundations.
