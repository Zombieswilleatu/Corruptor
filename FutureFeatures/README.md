# Corruptor — consolidated roadmap

**Updated 2026-09-15 · planning baseline · branch: `u13-basic-doctrine`**

Start here for project priorities. This distills FutureFeatures and the relevant U13 planning/acceptance documents. It replaces their competing “next task” lists for navigation, while preserving original designs, implementation notes and evidence. It does not change game rules or start every item below.

**Immediate engineering path:** finish the U13 Python mirror → establish full-match parity and measured throughput → improve common and Lord doctrine → run meaningful balance campaigns. **UI redesign is a parallel presentation track**, now that the first Forecast is playable. Monster integration follows a trusted battle baseline; the campaign builds on that.

## 1. What already exists

| Area | Current evidence and limits |
|---|---|
| U13 battle core and nine-Lord full-game path | Accepted Windows 4.7.2 campaign at `357d793`: 100/100 complete, replay-verified Random-Legal matches, all 81 ordered Lord pairings, no caps or failures. Mean 20.07 rounds. This proves the tested game path, not Lord balance. |
| Playable human-versus-bot U13 | Accepted playable integration; shared action modal, Work/Guard planning, Aftermath ledger, save/load and victory flow exist. Preserve them while redesigning presentation. |
| Public Guards and first Action Forecast | User accepted the Forecast at `dd9638c`; integrated with the sprite gallery. Deployed Guards and bonds are public; hands and sealed orders remain private. Forecast is a labeled current-board baseline, not a promised probability of success. |
| Basic doctrine | A working common planner and Lord targeting already exist. The next doctrine milestone improves/restructures that baseline; it is not “build the first bot.” |
| Python mirror | Foundation, planning and Development have Windows acceptance. Independent fresh-game progression reaches the sixth hook, before post-repair artillery. Isolated pair/Work lifecycle tests have broader component coverage; they do not certify complete rounds. |
| Python copying optimization | Accepted at `88ef438`: matched partial-cycle means 20.31 → 7.98 ms, 2.54× throughput. Full-round and full-match speed remain unknown. |
| Animation previews | Subject/monster gallery integration exists. Preview artwork and animations do not establish gameplay implementation of the ten recipe monsters. |
| Monster design | [Recipes v0.1](Corruptor-Monster-Recipes-v0.1.md) is the accepted starting recipe baseline, with combat values and open balance questions recorded. |

Sources: [accepted checkpoint](../docs/U13_ACCEPTED_CHECKPOINT_2026-09-15.md), [action flow](../docs/U13_ACTION_FLOW_2026-09-14.md), [Forecast](../docs/U13_ACTION_FORECAST_2026-09-14.md), [Development](../docs/U13_PYSIM_DEVELOPMENT_2026-09-15.md), [copying pass](../docs/U13_PYSIM_COPYING_2026-09-15.md).

## 2. Next — finish the fast, trustworthy experiment engine

Extend the existing mirror in dependency order:

1. Ordinary resolution: artillery, commitment/combat interfaces, defenses and victory.
2. Bring forward a bounded Marching performance spike on ordinary, dense/contact-heavy and spatial-actor fixtures. Establish exact field agreement and measure tick/round costs before completing the spatial port.
3. Complete fixed-step Marching, persistent effects and Lord mechanics, including timing, cooldowns, allegiance, pair breakage, Supplicants, reconstruction and deterministic retargeting.
4. Reach a legitimate independent setup-to-victory path, then approximately 50–100 exact full reference games spanning the supported mechanics.
5. Measure complete matches on target hardware, separating rule execution, policy evaluation, event/export costs and worker scaling. Set the practical sweep budget from those results.

**Done when:** identical explicit inputs produce matching Godot/Python states, ordered events and outcomes across the declared corpus, and complete-match throughput has a measured scope. Do not fill missing mechanics with fixture state or extrapolate 50,000-game speed from partial timings.

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
| Final production and release | Art/audio integration, accessible UI, settings, saves, onboarding, demo and outside playtests | Define the actual launch scope before scheduling beta or promising dates/budgets. Historical estimates are not current commitments. |
| Ranked, additional Lords, 2v2, mobile | Preserve as expansion possibilities | No implementation priority or launch requirement assigned here. |

Tell source: [The Read v0.1](corruptor_tell_system_design_v0.1.md). Multiplayer and older expansion concepts: [product roadmap v3](../corruptor_godot_roadmap_v3.md).

## 9. Source disposition and precedence

No source files were deleted or moved. “Historical” below describes their role, not their usefulness.

| Source | How to use it now |
|---|---|
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

The next concrete engineering milestone is ordinary Python resolution plus the early Marching performance gate. The next major design/content milestone is the monster system; the next presentation milestone is the UI overhaul. Campaign, prologue completion and optional online scope build on those foundations.
