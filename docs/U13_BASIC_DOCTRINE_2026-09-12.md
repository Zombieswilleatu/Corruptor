# U13 basic doctrine and short simulation loop

Status: first heuristic policy; local diagnostic validation, Windows acceptance pending.
Branch: `u13-basic-doctrine`, based on `76e723d`. The existing running Windows
Random-Legal campaign remains on its original checkout/revision.

## Design references and scope

The originating **CORRUPTOR_U13_ASTRA_HANDOFF_2026-09-08.md**, Section 6,
Implementation Plan v3, explicitly defines Tier 1A Minimal Heuristic Targeting:
occupied lanes, occupied guard zones, damaged castles and finite meaningful
spatial points. Its testing pyramid retains Random-Legal and exact deterministic
save/replay checks. The final Lord specification and current verified U13 rules
take precedence over U12 references. The handoff was recovered from the user's
design files, not inferred from the later roadmap.

This is an early common planner plus Tier 1A Lord targeting, not the finished
Smart Core, probabilistic Action Forecast, or evidence of production balance.
Veil threshold effects/drift remain off; normal Tears, rites and victory remain on.

Legacy references reviewed for individual ideas:

- `BotDoctrine.gd`: minimum sufficient attack commitment and avoiding overpayment.
- `BotDevelopmentDoctrine.gd`: useful repairs and economical payment.
- `BotDeployDoctrine.gd`: reserving cards before deployment, already reflected in
  U13GameDevelopment's shared reservation helper.
- `BotDominionRiteDoctrine.gd`: evaluate rites against victory progress.

No legacy doctrine or legacy game engine is imported by this policy.

## Behavior

`U13BasicDoctrine.gd` reads only player projections. It reserves rites and Lord
return costs, chooses a useful power, develops a castle, scores combat and fills
useful guard positions. Every accepted choice passes the shared authoritative
legality path; the final full submission preview remains mandatory. An invalid
final plan is reported as a failure, never replaced with a pass.

`U13DoctrineView.gd` caches public entities and own cards. Payment generation is
bounded to eight sampled cards for singles/pairs and up to six-card strong
prefixes. Scoring is heuristic: it knows printed suit penalties, paired-suit bonus,
public guards, sigils, Keep/Bastion screens and waiters. It cannot see opponent
hands, sealed actions, future RNG or Ravenous trajectories. It does not promise
an attack succeeds against unknown simultaneous defense.

`U13PowerDoctrine.gd` separates scoring functions for all nine Lords. It favors
occupied areas, useful army support and damaged castles. Spatial targeting uses
at most eight enemy centers, with friendly-fire penalties for relevant powers.
Odradek can bank resources; Valak spends existing Essence; Kanifous uses a rough
price-risk penalty. V1 selects at most one power per round: multi-power combos,
fine spatial prediction, full Wish risk modeling and optimized Lord doctrine
remain later work. A version change identifies future policy/distribution changes.

Each stage submits at most 32 ranked payloads to bulk legality. The policy chooses
among that shortlist, so it may pass when better legal choices exist outside it.
This bounded search is deliberately different from Random-Legal's distribution.
Stockpile keeps and Slaver swaps prefer higher useful printed card value.

## Hunt correction (explicit user rule)

Hunt is an army action. The player's Lord may already be banished when Hunt is
declared, and the two opposing committed Hunts can both banish their targets.
The Lord ID on an attack supplies player attribution, not an alive-source gate.
The hunted target must still be present and enemy-owned.

The doctrine's first meaningful full match exposed the old banishment-attribution
gate at round 11. The fix removes that gate and the Hunt admission restriction.
Hunt may accompany resummoning with disjoint card payments. Powers retain their
own declaration/source requirements. Random-Legal V5 includes Hunt alongside
resummoning; the previous V4 distribution and current running campaign are not
retroactively relabeled. The dedicated committed-Hunt regression covers both
opposing Hunts, already-absent declaration, return plus Hunt, double-spending,
invalid friendly attribution, and exact save/replay.

## Simulation tiers

`run_u13_doctrine.sh` defaults to nine matches (all nine Lords in both seats),
two workers and a 40-round cap. Games 1 and 6 use independent planning, exact
save/restore and replay; the other games use one authoritative conductor with
normal submission legality and genuine terminal outcome validation. Set
`U13_DOCTRINE_VERIFY_EVERY=1` for independent replay on every game.

Every report identifies engine runtime, git revision, bot version, seed/loadout,
round cap and verification scope. Rounds record plans, candidate counters and
timings. Fast mode saves checkpoints at round 1 and every fifth round; an ordinary
failure also contains its current exact save. Watchdog/interruption preserves
the last checkpoint and partial log. There is no automatic result reuse: default
output directories are unique. Existing reports in an explicit directory may be
replaced by a new campaign, so use a new directory for comparisons.

Round caps are **censored**, never wins. Exit 0 means every requested match won;
exit 2 means one or more were capped; exit 1 means a failed check/watchdog. Errors
and missing completion markers stop all workers. `results.tsv` is a concise
campaign index; JSON contains the full result details.

The existing 100-game Random-Legal runner remains the occasional extensive
integration/stress gate. It is not required after every small change. Broad
throughput work remains a PySim parity priority.

## Local validation

Linux Godot 4.5.1 diagnostic runs:

- All nine Lord pairs through an ordinary opening, authoritative planning and
  exact round replay; bounded candidate calls, determinism, no server-snapshot
  reads by the new policy, and disjoint physical-card reservations.
- Directed scoring checks for a castleless/protected Castle zone, imminent
  Ritual/Dominion opportunities, a banished Lord, canonical payloads and empty
  spatial fields. These are isolated fixtures, not autonomous match results.
- Seed `u13-full-match-v1:0` finished naturally at round 11, Final Collapse,
  winner 1. Independent replay and single-conductor runs had identical every-round
  plans and identical final lossless-save hash. Elapsed: 129.24s replay / 56.317s
  single. These ran with other local work and are diagnostic throughput evidence,
  not a controlled hardware benchmark or a Windows ETA.
- Six focused suites passed: BasicDoctrine, SnarePlanning, Fracture,
  GameDevelopment, GamePlanCoverage and PlanningPerformance, plus the separate
  CommittedHunt suite. The old development test's banished/no-combat expectation
  was updated to permit Hunt under the user's explicit rule.

## Performance instrumentation

`U13PlanningCounters.gd` wraps either policy without changing decisions. It counts
the candidates entering each bulk validation call, accepted count and elapsed
time, plus complete submission previews and projection/snapshot overhead.
`U13DoctrineProfileRunner.gd` compares both policies on one exact checkpoint and
also measures a world deep copy and a validated match clone. The remainder includes
scoring/enumeration and wrapper work; it is not falsely labeled pure allocation time.

The existing Gravity Orb enumerator has 18 positions, and Web samples one position
per lane. Thousands of spatial positions were not the source of candidate volume.
The full inherited Random-Legal vocabulary also generates combat/payment choices,
construction choices and repeated projections. Bulk order admission already stages
a baseline once per call rather than resolving a whole Marching phase per candidate.
A complete submission preview clones and checks/reserves a plan; it does not advance
combat or Marching. Individual bulk-candidate costs cannot be derived accurately
by dividing the whole planning total by candidate count.

The supplied Windows game-18 log contains eight completed rounds and the start of
round 9, not a terminal result. Its eight round totals sum to **303.16 seconds**:
planning **168.78s (55.7%)**, resolution/compare **81.25s (26.8%)**, remaining phases
**53.13s (17.5%)**. Its planning column covers four plans (two players on two
conductors), not one plan or a demonstrated fixed 11.5-second planning floor.
Four-worker contention and different Godot versions prevent direct comparison
between those Windows totals and local single-process diagnostics.

On the preserved round-16 Deimos/Orias checkpoint, a paired local profile measured
2,753 candidate validations / 1,050.9ms total for Random-Legal V5 versus 137 /
654.4ms for Basic V1 (both seats, once each). One world deep copy was 0.277ms;
one validated match clone was 21.385ms. Complete submission previews were about
60–86ms. Random-Legal's repeated projection/snapshot calls used 124.6ms, compared
with 12.2ms for the new planner. This supports reducing repeated setup and broad
payment/order vocabulary; it does not support thousands of spatial positions or
full Marching execution per candidate. Consider further validated-clone/preview
cost reduction after this short loop has Windows evidence.

On the uploaded round-7 Gremory mirror checkpoint, Random-Legal validated 227
power/payment candidates per seat. Those power calls consumed 6,555.1ms of the
7,591.9ms combined planning time. Basic validated three power candidates per
seat and planned both seats in 877.9ms. Total candidate counts across all planning
calls were 3,082 versus 130. This specifically identifies an expensive Gremory
payment/target vocabulary, not spatial enumeration, in that checkpoint. Results
vary materially by Lord and state; do not extrapolate the largest ratio to every
game or claim logging had zero historical cost from this comparison.

Run a same-checkpoint comparison in the new checkout:

```bash
"/path/to/Godot_4.7.2_executable" --headless --path . \
  --script Scripts/Sim/U13DoctrineProfileRunner.gd -- \
  --checkpoint="/path/to/game-NNN-checkpoint.json" \
  --output="/path/to/doctrine-profile.json"
```

Without `--checkpoint`, this profiles an ordinary Valak/Humbaba opening. Preserve
the JSON and log: they separate projected-view setup, baseline clone, bulk power
and order checks, complete preview and total planning.

## Run the short Windows campaign

Use a separate worktree while another campaign is running:

```bash
cd ~/OneDrive/Documents/Corruptor-U13 &&
git fetch origin u13-basic-doctrine &&
git worktree add ../Corruptor-U13-Doctrine FETCH_HEAD &&
cd ../Corruptor-U13-Doctrine &&
bash Scripts/Sim/run_u13_doctrine.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
```

The wrapper enforces pinned Godot 4.7.2 stable. Local Linux Godot 4.5.1 results are
diagnostic evidence only; they are not Windows acceptance or a 100-game green gate.
