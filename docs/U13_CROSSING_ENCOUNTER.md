# The Crossing — finite expedition internal prototype

Status: accepted Crossing playtest baseline, including shared game visuals and player-only repricing. Campaign aftermath remains a preview.
Base branch: `u13-resolution-theater`, commit `f4b4c187a0e9099680f304022ba74e33bba2cffd`.
This replaces the card/command economy of the previous Crossing ZIP.

## Open and play

Dev setup menu: **THE CROSSING · ASCENT ENCOUNTER PLAYTEST**.
Standalone: `bash Scripts/Sim/run_u13_encounter.sh "$godot_exe"`.
Focused tests: add `--test`.

Choose Gate/Lamp, opposition, a seed, power regeneration and a retinue type; apply.
Select a recruit or monster, then click the blue deployment area. Placement sets
spacing and arrival order. Undo restores the complete last placement before combat.
Flip the hourglass to run one 15-second simulation round. Units and fortifications
persist. Playback defaults to 3×; 1× inspection, 6× and 9× are available. Pause and
speed never change simulation outcomes. At 3× an ordinary replay takes five seconds,
plus simulation preparation and a 0.62-second hourglass introduction; planning time remains the player's choice.

## Player expedition

- Three Penitents, three Vultures, three Wrights and three Butchers, finite.
- One local retinue-type selection adds two of its type: 14 recruits total.
  Rank never changes this contribution. No-retinue testing uses 12 recruits.
- Ordinary troops cost no summoning power. There is no hand, draw bag, purchase
  currency or ordinary refill.
- Four deployments per round, shared by ordinary recruits and monsters. One Varn
  swarm is one deployment, even though it creates 3–5 bodies.
- Five starting summoning power, then +2 per new round by default. Power has no
  carry cap. +1/+3 are explicit playtest settings.
- Seven occupied monster capacity. Power is a purchase cost, capacity a continuing
  occupation cost. Death/banishment refunds no power.
- All ten monsters are unlocked for this test. The model accepts an unlock list.

| Monster | Power | Occupancy |
| --- | ---: | ---: |
| Lemek | 6 | 3 |
| Varn | 4 | 1 per swarm |
| Fyra | 5 | 3 |
| Kopita | 5 | 2 |
| Tumler | 5 | 3 |
| Kurchin | 6 | 3 |
| Muno | 7 | 3 |
| Dotra | 6 | 3 |
| Sooge | 7 | 6 |
| Sinodek | 7 | 6 |

These are player summoning prices. Varn, Fyra, Kopita and Tumler are affordable
from the opening five power. Lemek costs six, Muno seven; both retain three
capacity and unchanged combat stats. Their previous enemy expedition weights
remain five and six. `OPPOSITION_COST` keeps the accepted enemy schedules and
budgets independent of player price tuning. Other eight prices are unchanged.
Sooge plus Varn fits. Two Kopitas or multiple Varn swarms can coexist if purchased within
capacity. The engine's existing Sooge/Sinodek singleton restrictions are preserved;
their weight already prevents buying two copies in this seven-capacity mode.

## Ownership and occupancy contract

Paid summon groups retain their original purchase identity and weight.

| Event | Capacity consequence | Lamp consequence |
| --- | --- | --- |
| Temporary charm of our monster | Still occupies our capacity | Monsters never carry |
| We charm an enemy monster | No purchased group added; no new occupation charge | It may contest while allied |
| Sooge transforms into turret | Original six capacity remains occupied | Still cannot carry |
| Part of a Varn swarm dies/is permanently banished | Entire one-capacity group remains occupied | Monsters never carry |
| Last body of a paid group permanently leaves | Group frees capacity; no power refund | Carrier removal drops Lamp |
| Ordinary carrier charmed | No monster capacity involved | Drops Lamp; does not transfer possession |
| Our ordinary troop temporarily charmed | Remains a possible future carrier | No early impossibility loss on that basis |

Sinodek's portal is permanent removal in this arena. Humbaba/Lord rules and
resurrection are not enabled here. If a future integration adds **temporary**
banishment or returnable reserves, those groups must retain capacity until their
return claim expires; IDs must follow the group across staging/return. Such troops
also count as recoverable Lamp carriers. That integration requires corresponding
ledger tests before enabling it; this build does not silently treat a future return
as permanent death. Hidden on-field bodies already retain their capacity.

## Enemy expedition and forecast

The complete seeded wave list is built before deployment. This round and the next
round are displayed, with exact monster/suit counts, exact Varn body counts, a total
remaining body reserve and any older queued orders. The forecast names the enemy
plan and its upper/central/lower approach. Hover for abilities and existing suit
matchups (Penitent blocking and Vulture damage against Butchers).

There are three deterministic plan families:

| Plan | Ordinary emphasis | Monster core |
| --- | --- | --- |
| Shield column | Two Penitents per four ordinary orders | Lemek + Kopita |
| Volley company | Two Vultures per four ordinary orders | Kurchin + Fyra |
| Raiding party | Two Butchers per four ordinary orders | Tumler + Varn |

The remaining two ordinary orders use the other two combat suits. Round four's
first ordinary purchase is a Wright. No later engineers are purchased. A lone
Wright can build and guard a wall using the existing field-construction rules.
These are legible tendencies, not guaranteed rock-paper-scissors solutions: for
example Tumler specifically hunts ranged/support targets in a Butcher-heavy plan.

Standard and Heavy send both core monsters with the opening; Light sends the
first in round one and attempts the second in round three. Support arrives in a
rear rank, with front-line units ahead and a common approach. A fixed seeded plan
stream selects the family and approach, independent of player purchases. Positions
are planned with each order. Occupied entry space can shift bodies within the
formation or defer a whole group; it cannot discard an order or reroll its bodies.

| Opposition | Budget ceiling | Releases in rounds 1–4 | Later releases |
| --- | ---: | --- | --- |
| Light | 36 | 8, 6, 4, 4 | 2 on even rounds, until exhausted |
| Standard | 46 | Gate: 14, 8, 6, 6; Lamp: 12, 8, 6, 8 | 2 on even rounds, until exhausted |
| Heavy | 58 | Gate: 16, 12, 8, 6; Lamp: 14, 12, 8, 8 | 2 on even rounds, until exhausted |

Ordinary enemy bodies cost two budget; monsters spend their listed power costs.
Unspent fractions remain banked, so exact order counts depend on the chosen core.
Light saves up to two points in round two for its second monster. Finite budgets
can leave an unspendable point; no purchases are made beyond the published deadline.
Both monster types are single purchases for the enemy. Surviving monsters and
Wrights continue functioning after the reserve is empty.

Lamp moves one ordinary purchase from the opening into round four because
extraction punishes a lost opening sooner than Gate. Total finite budgets stay equal.

This shifts existing budget into an actual opposing army before a rush finishes;
it does not increase the budget ceiling, gate HP, unit stats or the shown deadline.
Scheduled tails normally reach rounds 18/16/20 in Gate, depending on budget parity;
Lamp only schedules through round 16. Test milestone logs, not the budget ceiling,
are authoritative about actual last arrivals and whether survivors remain.

The engine's 64-body limit and a crowded formation can defer an order. It stays
visible in a queue, keeps its identity and exact count, and tries again next round.
If formation placement fails, the spawn and its accounting roll back as one group.
An empty enemy reserve means no further arrivals, not victory. Restarting the same
setup repeats the same schedule. Counterfactual tests replace a wave before the
examined decision, never after a live forecast has been shown.

## Objectives and failure

Gate: both gates have 24 HP. A troop at the far end attacks the gate approximately
every two seconds. Defenders still fight. Both gates falling on the same tick is a
draw. Existing combat, Wright fortifications, navigation and gate rules are retained.
Deadline stays at 24 rounds. There is no speculative early Gate impossibility loss.

Lamp: ordinary troops secure within 150 units for three uncontested seconds;
opposing units within 320 contest. Monsters escort/contest but cannot carry. The
nearest eligible ordinary troop carries home at roughly 70% speed. Death,
permanent banishment or charm drops the Lamp at its last recorded location. Camp
extraction resolves immediately; the deadline remains 16 rounds.

Lamp can end early only when no carrier can be recovered: no ordinary reserve,
no own/allied ordinary body, no charmed own body that will return, and no possible
Fyra acquisition from present/future enemy ordinary troops. Future affordable Fyra
is deliberately treated conservatively, even if capacity is presently occupied.
This may defer some truly lost states until the deadline; it must not invent a loss.
The decision runs in the objective tick callback and goes through the normal replay
before the UI commits the aftermath, including failure at tick zero.

Withdrawal is available during planning and asks for confirmation. It counts as
mission failure; it saves time, grants no reward and preserves no favorable margin.
If graded aftermath is later added, withdrawal's grade ceiling is **worst**.
The announced clock never shortens during a match.

## Retinue aftermath boundary

Success: reward eligible, selected retinue eligible for promotion.
Failure/draw/withdrawal: no reward, selected retinue eligible for marring.
The run continues. Consequences follow the mission result, never a particular
ordinary body's survival or which source it came from. Unfielded bodies do not
protect the selected retinue from failure consequences.

This isolated build selects a retinue **type as a proxy**, not an actual saved
campaign member. It writes no promotions, scars, unlocks, rewards or saves. Exact
chance/grade rules remain unspecified. No-retinue tests have no promotion/marring
eligibility. A named leader body and deployment/survival requirements remain optional
future work rather than being introduced without evidence.

## Internal validation and measurement

`U13EncounterTestRunner.gd` covers reserves/undo, finite budgets, locked forecasts,
spawn identity, capacity/ownership/removal, objectives, early failure, withdrawal,
UI input and worker/replay endpoints at all four speeds.

`U13EncounterTrials.gd` runs full encounters under four explicit scripts: early
commitment, a slower escort, saving for Sooge, and monsters-only Varn. These are
limited policies, not estimates of human win rate. `CROSSING_RESULTS` selects a JSON
output path; `CROSSING_HEAVY=1` runs Heavy instead of Light/Standard. Additional
filters: comma-separated `CROSSING_MODES`, `CROSSING_DIFFICULTIES`,
`CROSSING_POLICIES`, integer `CROSSING_FIRST_SEED` and `CROSSING_SEED_COUNT`.
The `open_varn`, `open_fyra`, `open_kopita`, `open_tumler` policies use the same
four-slot ordinary deployment logic as rush, changing monster purchase priority.
`counter` follows a simple suit-count heuristic; `focus_pen`, `focus_vulture`,
`focus_butcher` prioritize a fixed suit. These are probes, not production AI.

`U13EncounterForecastTrials.gd` evaluates ten candidate ordinary deployments under
paired seeds, replacing two Vultures with two Butchers in the next forecast wave.
The paired enemy cost, seed and entry coordinates remain fixed. It records choices, holdback, material and
score, including the old choice played against the new wave. The same evaluation
weights apply to both variants. Default probes the opening; set
`CROSSING_FORECAST_STAGE=3` to probe after a fixed two-round opening.
`CROSSING_FORECAST_OFFSET=0` swaps the wave about to enter; the default 1 swaps
the second visible wave. `CROSSING_MODEL` can select a preserved baseline script
for matched comparisons. `CROSSING_FORECAST_RESULTS` selects its JSON output path.
Record whether the old choice actually scores worse after the swap; different
choices tied for best score are not evidence that adapting was beneficial. Its two-round material
score is a diagnostic, not a validated model of mission success or human judgment.
An additional opening-only probe uses `CROSSING_FORECAST_MONSTERS=1`: two troop
compositions for each of the five affordable opening monsters, plus the old
Wright/Wright/Butcher reference. `CROSSING_FORECAST_SEEDS` controls its seed count.
This broader choice set is reported separately from the original ordinary-only
probe, so increased sensitivity cannot be passed off as an apples-to-apples gain.

Per-match log: last reinforcement entry, reserve exhaustion, enemy combat force
cleared after final arrivals, first enemy gate damage, mission end. Missing
milestones remain -1 or absent: never infer them from an empty reserve. Per-round
snapshots record remaining recruits, power before/after purchases, capacity,
deployments and monsters blocked by power alone/capacity alone/both. Log both
before choices and after them, so spending everything does not masquerade as an
inherent resource shortage. End-of-round milestone granularity is explicit.

If late exhaustion produces a long empty cleanup, redistribute existing enemy
budget later before changing the next encounter's deadline. If a meter never
changes a practical choice, simplify it. If forecasts never change good deployments
or holdback, revise encounter composition/counters before campaign integration.
Do not tune a scripted evaluator merely to force a positive forecast result.

## Scope and remaining work

The scene owns its arena and worker and is separate from the old main game/menu.
The dev menu entry and shared optional encounter hooks are carried forward from
the prior Crossing package. Closing returns to the dev menu and restores scaling.
No music, Wilhelm audio, main-game rules or campaign saves are changed by this
redesign. No baseline golden files are rewritten.

Next design gate is human decision quality, especially monster-opening choices,
Heavy Lamp difficulty and whether both forecast waves are useful in practice. Human readability and fun still need playtesting.
Optional future work: authored enemy plans with visible weaknesses, capped run
monster selection, genuine retinue selection/aftermath persistence, graded outcomes,
and further objectives. Withdrawal stays worst-grade if grading lands.

## Crossing-only monster reliability pass (2026-09-29)

Opt-in profile `crossing-monsters-v1` applies only to worlds created by the Crossing model. The shared monster roster and tuning remain unchanged. Both sides use the same profile; the current enemy templates do not purchase Dotra, Sooge or Sinodek.

- **Dotra:** conceals after 27 active ticks (about 2 seconds), instead of 200 (15 seconds). Still once per summon. Ambush, exposure, shroud, damage and movement remain unchanged.
- **Sooge:** keeps advancing until an enemy unit or field fortification is within 1200, then roots reliably, including mid-round. No chance roll in this mode. Beam reach rises from 1800 to 2400 and charge falls from 32 to 16 ticks (2.4 to 1.2 seconds). Still one shot per 200 ticks, 3 enemy damage / 1 friendly damage, and a permanent turret. Requires other units to finish a Gate objective; the beam hits troops and field fortifications, not the objective HP directly.
- **Sinodek:** target range 600 to 900. First in-range portal is guaranteed per summon; later active rounds use 50% instead of 25%. Empty range spends no attempt; at most one attempt per round. The first-use flag persists across rounds and charm. Friendly banishment and caster immunity remain unchanged.
- **Varn visuals:** living sprite height 72 to 36, death ghost 62 to 31, footprint and missing-art fallback halved. Applies to both sides in this encounter view only. Combat body count, stats, collision, placement spacing and capacity unchanged.

Prices, weighted capacity, ordinary troops, retinue bonuses, enemy budgets and deadlines are unchanged. Mode tooltips and forecast tooltips show the altered abilities. No campaign save writes. These are reliability buffs, not a claim of a fully balanced roster; paired scripted trials are included with the installer.

## Pressure and recovery pass (2026-09-29)

This supersedes the previous difficulty budgets and late-patrol schedule.

- Light uses the exact former Heavy expedition: 58-point ceiling, original opening and finite ordinary tail. The new construction speed applies at every difficulty.
- Standard has a 78-point ceiling; Heavy 84. Their opening funding remains the former Heavy's. Round 2 includes Muno, paid from that wave's budget, replacing some ordinary troops.
- Both higher tiers have reinforced pushes on rounds 6, 9 and 12. Standard releases 14/12/10 points; Heavy 16/14/12. Each push buys a named monster plus ordinary troops. Shield-column reserves: Sooge, Kopita, Lemek; Volley-company reserves: Muno, Kurchin, Fyra; Raider reserves: Dotra, Tumler, Varn.
- Rounds between pushes bring no new orders. Surviving enemies continue fighting. The full schedule remains fixed before play and the two-wave forecast remains truthful. No reinforcement is created in response to player success or weakness. One odd, unspendable point can remain in the finite bank.
- Gate's 24-round and Lamp's 16-round deadlines are unchanged. No automatic comeback, enemy exhaustion victory or hidden assistance.

### Wright construction

Wrights take 96 active work ticks (~7.2 simulation seconds) to complete a structure, up from 32 (~2.4 seconds). Travel to the site is additional. Work only advances while the builder is at the site and not threatened in melee. Both sides use this rule in the Crossing. Multiple Wrights can build in parallel; there is **no per-round building cap**. The earlier cap experiment was discarded.

Repair cadence, structure health/armor, guard attacks, deployment limits and recruit counts are unchanged. In-progress work and fractional work ticks survive round boundaries and exact save transport. The regular game keeps its original 32-tick construction. Purchase and field tooltips describe the slower construction.

### Intended experience and testing limits

The aim is pressure, a readable chance to stabilize, then a counterattack. It is not to force every player to narrowly lose, or to secretly scale an enemy against a successful army. A good opening may avoid a crisis. Three Wrights remains a legitimate defensive investment; the goal is to delay its payoff, not ban it.

The bundled pressure trial runner compares three-Wright, mixed and assault openings with the same later deployment policy, plus a saving-for-Sinodek opening for Lamp. It records army counts, gate health and recovery from a coarse crisis marker (at most two friendly units against at least four enemies, or own gate at 12 HP or less). This marker is a diagnostic, not proof that a player felt close to defeat. Results are documented in the patch REPORT.md; scripted win rates are not human difficulty estimates.


## Scheduled player reinforcements — September 29

One fixed reserve arrives at the start of Gate round 15 or Lamp round 10: two of each ordinary troop (eight total), independent of retinue, losses, difficulty and saved reserves. The schedule is visible from round 1. They enter reserve, not the field; the four-deployment cap still applies. No power bonus, repeat grant, deadline extension or enemy changes. Surviving armies keep the same reinforcement entitlement. Arrival happens only after a nonterminal resolved round, before planning and placement undo snapshots.

Lamp carrier-impossibility checks include the pending reserve; enemy delivery and the deadline still end the mission normally. After the shipment, the original conservative carrier check resumes. Withdrawal remains available. Arrival round/body counts and pending reserve are recorded in local metrics.


## Lamp opening balance — September 29

Lamp now has an independent enemy schedule; Gate retains its pressure-pass rules exactly. Light/Standard/Heavy Lamp budgets are 42/56/64, with round 1–4 releases of 8/6/6/4, 10/8/6/4, and 12/10/6/4 respectively. Fixed round 6/9/12 reinforcements release 6/6/6, 10/10/8, or 12/10/10. Costs still debit a finite bank; unspendable odd points may carry between releases. Light opens with one affordable monster instead of the old two-monster escort. Standard/Heavy retain their paid round-2 Muno and monster-plus-troop reserve pushes. All plans are locked before deployment, with the usual two-wave forecast and explicit gaps.

This reduces early Lamp pressure rather than giving either side different pickup or movement rules. The symmetric three-second secure time, carrier speed, contest range, delivery conditions, and 16-round deadline remain unchanged. Player reinforcements still arrive at round 10; Gate at 15.


## Calibrated opposition — September 29, latest pass

The current `OPPOSITION` table in U13EncounterModel supersedes the earlier numeric wave schedules above. Target player win rates are approximately Light 80%, Standard 60%, Heavy 30%, assessed separately in Gate and Lamp with a frozen forecast-aware test policy. These are simulation targets, not promised human success rates. Full fresh-seed results and unsuccessful candidates accompany the installer in REPORT.md and validation/.

Gate enemy budgets are 59/70/80; Lamp 48/58/65. Gate Light has finite two-point patrols every even round after round 4. Other tiers commit fixed pushes on rounds 6, 9 and 12. Standard Gate and Light Lamp delay their Muno skirmisher until round 3; higher tiers retain round 2. The complete order list remains fixed before planning. Unit stats and main-game combat are unchanged. Deadlines, scheduled player reserves, construction time, and deployment/capacity limits retain their previous values.

The new standalone tactical policy and balance runner are simulation tools only. They do not secretly control or adapt the enemy during human play. The policy directly tests reading the forecast, holding reserves and purchasing counters; its limited heuristics are not a claim of optimal play.


## Accepted visual and price release (2026-09-29)

The field uses Domain1's actual Lord-lane crop rotated clockwise. Troops and
towers stay upright; Wright walls turn across the road. Shared renderers supply
monster attacks, status markers and dagger artwork. Sinodek portals use Odradek's
screen distortion with horizontal world-to-screen projection and lane clipping.
The real hourglass flips and lands before the replay advances, then drains at the
selected speed. Pause and restart retain their existing phase semantics. Empty
Crossing fields still process objective time instead of skipping the round.

The player-only price increase preserves all seeded enemy orders, budgets,
arrival rounds and positions. No new human win-rate estimate is claimed. Earlier
balance estimates and historical implementation notes above describe their
respective versions, not a recalibration after this price adjustment.
