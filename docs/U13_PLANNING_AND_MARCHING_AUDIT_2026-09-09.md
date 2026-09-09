# U13 planning performance and Marching audit — 2026-09-09

Baseline: `13fba3db344fe9e7ca4b0255ae46334b4ab7def3`.
Runtime: Godot 4.7.2 stable. U12/main stays separate.

## What the locally supplied alpha report establishes

The report is `U13_FOUR_LORD_ALPHA_V1`, fixture
`U13_FOUR_LORD_ALPHA_FIXTURE_V1`: 16 ordered pairs including mirrors, one seed
per pair, six baseline rounds and a restored replay each. All shards replay
verified; 96 baseline rounds, 96 JSON checkpoints, 1,920 hook comparisons.
All eight active powers resolved at least once. This is the bounded M3
correctness/frequency checkpoint, not the completed production game or balance.

| Claim | Finding against report and current implementation |
| --- | --- |
| 175 declarations | The supplied report's per-Lord counts sum to **158**, with 150 resolutions and zero fizzles. |
| Endurance is made impossible by regeneration | Incorrect timing premise. `U13Combat.on_hook` calls regeneration at **Step 3** (`ROUND_START_AUTOMATIC`). Contact damage occurs in Step 12; Endurance checks at Step 13. Waiters do not regenerate at all. Zero qualifying bodies in 48 opportunities is a coverage observation, not proof of impossibility. |
| Replace 1 HP with 0 Armor | Not equivalent. Vulture bypass can leave a Penitent at 1 HP with all three Armor intact. Depleted Armor also persists through healing, so changing this condition can award repeated Tears to healthy survivors. No threshold or power semantics changed here. |
| Density has declined | Correct for these samples, not a controlled before/after comparison. Alpha starts at mean 5.52, median 5, p90 10, range 1–20; 32/96 observations are exactly 2. Earlier Gremory-only fixture mean 9.08 used a different opening and roster. Finite hands, Castle payments, absent normal draws, and spawn-power availability all matter. All implemented combat commitments, including Ward, also spawn Marchers. |
| Five waiters is well-evidenced as unreachable | Unsupported. This alpha peaks at four, but the earlier construction batch explicitly reached five in both seat-1 lanes (Castle: 2 rounds/204 ticks; Lord: 1 round/5 ticks). Tick and round samples of persistent units are correlated. No waiter-threshold tuning from this report. |
| Eight Infernos unaccounted for | The eight pending-at-limit effects correspond exactly by matchup and count to final-round Inferno declarations with no final-round resolution. Each Kalligan seat declares one on round 6; delayed firing is round 7, outside the six-round sample. This is cutoff censoring, not an observed dropped effect. |
| Castle destruction drives Tears | True in this fixture: 30/49 Neutral Tears (61.2%). There were 31 destructions; the shared Castle-destruction faucet is capped at one per round. Two operational Engines per seat and vulnerable opening Castles bias this exercise toward artillery. Full Veil and other economy sources are absent. Track destruction **rounds** as well as destruction count. |
| Rout averages 2.1 bodies | Correct: 34 affected / 16 activations = 2.125; one empty activation. Frequency only. |
| Lord Guard Scorch affected zero, therefore Guards exceeded Intensity | Not established by that counter. This fixture initially installs only Castle Guards, and Guard deployment is absent. Empty Lord Guard zones explain those zero-hit pulses. |

The Stones Forget also did not trigger in the alpha batch. Its earlier focused
fixtures remain the source of coverage. The random report is not a replacement
for them. The new Marching audit fixture proves the actual Endurance path through
Step 3, a real duel, and Step 13; it does not merely inject a final HP result.

## Planning performance change

User baseline timings include 384 individual player plans across baseline and
replay. Round-1 planning median 5,627 ms; maximum 11,805 ms. Later planning
median 744 ms, p95 1,600 ms. Whole Marching computation median 300 ms and maximum
903 ms. Those are complete headless phase costs, **not frame times**. JSON restore
costs are separate and can also be substantial; no inference of hardware failure
or a memory leak follows from variation between trials.

The previous random chooser enumerated every Castle/payment and combat candidate
through complete temporary match transactions. Even after the conservative
screen and shared baseline clone, survivors repeated declaration checks,
resource reservations, card registry work, transforms, event construction and
whole-world validation. Power candidates additionally repeated baseline
consistency checks.

Changes:

- `U13Match` stages the exact `_accept_declarations` transaction once for an order
  batch, on an isolated fork. Each order is checked against the resulting Hand
  and resource budget.
- Construction-capable content explicitly configures an exact batch validator.
  `U13Construction` shares its target, payment and token predicates with commit;
  `U13Combat.validate_commit` is used by both commit and enumeration. The registry
  and owning card zones are validated once outside the candidate loop.
- Power candidates still use complete independent `_accept` transactions, with
  one baseline consistency check rather than one per candidate.
- The final chosen plan, `submit`, joint lock, save restore and world-transform
  boundaries retain full transaction validation. No blanket trusted-world mode
  or long-lived legality cache is introduced.
- Unconfigured adapters retain the prior complete-preview path. Malformed exact
  validator output falls back to it. Exact validators are simulation content,
  never bot/UI-supplied callbacks.
- Canonical sorting, candidate vocabulary, purpose keys, uniform selection and
  bot policy version remain unchanged. No probability/target domain is pruned by
  a bot heuristic.

`U13PlanningProbe` is test-only. Reference mode preserves the previous enumeration
algorithm: each power uses full preview; orders use the old conservative screen,
shared validated baseline and a full `_accept` per survivor. It uses the current
shared commit predicates, so the code diff and negative fixtures additionally
check that those predicates preserve the previous rules.

`U13PlanningProfileRunner` alternates optimized/reference/reference/optimized
(ABBA) on identical JSON-restored owners, for rounds 1 and 2 of each Lord's alpha
fixture. Each run compares the complete legal arrays at all three selection
stages, the final keyed plan, and owner state before/after. Reports give input and
legal counts plus timings by stage and total. Restore and file IO are excluded
from timing. Round 2 exercises the state reached by the selected round-1 plan;
the other player passes, so this is a planning microbenchmark, not a new match
frequency sample.

No runtime speedup is claimed until these measurements run on the user's pinned
Godot build. Do not increase the foundation watchdog to hide a regression.

## Milestone 4 — Marching source audit

| Required question | Current answer / evidence |
| --- | --- |
| Authoritative representation | Entity-ID keyed `x_fp`, `y_fp`, lane, owner/direction, health, armor, birth/ready rounds, contact ticket, waiting state. Lane length 2,400 and width 600 canonical units. Fractional spatial inputs rejected. Screen pixels are not saved. |
| What advances movement | `U13Match` dispatches `U13Combat.on_hook` to `U13Marching.resolve` at Step 12. Commitments spawn at reveal, then hold movement until the following round. Lord spawn powers explicitly choose their ready round. |
| Fixed step | Exactly 200 ticks per phase. Step is printed suit speed plus compiled aura/Rout modifiers. Serialized coordinates are integers. Steering uses bounded squared distance/integer square root and explicit rounding for scaled displacement. No frame delta or physics callback enters authority. |
| Visual separation | Worker computes the phase; `U13SmokePlayback` reconstructs/interpolates the public tick tape and the board advances a presentation clock. Skip/sampling do not resolve damage. Gameplay effects must not be tied to animated sprite overlap. |
| Collision | Exact two-dimensional distance <= 180 for enemy contact; spatial buckets only reduce candidates. Ally center clearance is 84; blocked units attempt deterministic lateral detours. Read targets from one tick snapshot; resolve personal-space conflicts in stable ID order. |
| Fight and joins | One active duel per lane. Contacting joiners retain contact tickets and wait; earliest contact wins, keyed selection resolves ties. Exchanges occur every eight ticks and apply reciprocal damage before deaths, allowing mutual defeat. A following pair enters after the previous duel ends. No nearest-ID stand-in for physical intersection. |
| Combat targets | Physical entity IDs. Active duel source identities/exchange history/next tick persist. Retired, moved or owner-changed participants interrupt the duel rather than transferring it to another instance. |
| Waiters/support | Contact takes precedence over arrival. An arriving body becomes a waiter, not an arrival Tear. Waiters can fight incoming enemies, do not regenerate, and remain physical targets. Valid Hunt/Siege consumes the attacker's matching-lane waiters for +1 each at Step 9, even when Ward blocks the attack. An unavailable sealed target fizzles and preserves those waiters. |
| Regeneration / Endurance | Step 3 heals non-waiters; Armor is not healed. Step 13 checks surviving owned Penitents at exactly 1 HP if Humbaba is alive. A 1-HP waiter can remain eligible in later rounds until removed/consumed; that is the current rule, not a reason to silently replace the threshold. |
| Legacy configuration | Static dependency walk from `U13AlphaScenario` covers 39 scripts: no import of `MarchingEngine`, `RuleConfig`, or U12 game setup; no reads of `march_steps`, `march_damage`, `march_suit_bonus`, `march_threshold`, `march_max_in_flight`, `march_exception_pair`. These remain on old engine paths. The added sentinel test verifies they do not affect U13 movement, fights or events. |
| Determinism | Existing spatial tests cover registry reversal, keyed spawn, exact old/new engine equivalence at 6/24/48 bodies, round-spanning duels and JSON replay. Integration covers suit movement, commitments, waiter interception/consumption and replay hooks. Alpha adds whole-owner four-Lord restored replay. New audit fixture repeats the real Endurance path after JSON restoration immediately before Marching. |
| Extension vs rewrite | Extend the existing authoritative engine. It already has the correct owner, stable identity, phase, position, contact, modifier and reaction boundaries. Orias still needs common region/overlap/position-query APIs; future spatial effects must use those, not viewport dimensions or Godot physics. |

### Explicit implementation limits before future spatial work

- The 64-attempt spawn sampler chooses best available clearance if it cannot find
  free space. It is not an infinite-density guarantee. Later spawn/crowding work
  must preserve deterministic ownership/positions rather than silently dropping
  entities or reviving the U12 in-flight cap.
- Collision checks are discrete. Current printed speeds (3–6, 25% aura and Rout
  modifiers) are small relative to contact distance. Future high-speed movement
  or teleportation must define sweep/landing semantics; do not assume arbitrary
  speeds up to the broad save-data bound cannot tunnel.
- Duels have a 64-exchange failure guard. Current printed health/armor is well
  inside it. New huge-health/armor actors require revisiting that bound.
- Nearest-opponent steering can still be quadratic for mobile populations despite
  contact buckets. The 96-round alpha is not a worst-case dense-field benchmark;
  existing dense performance checks remain relevant for new spatial actors.
- Public geometry/query APIs are the next foundation task. Existing private
  contact helpers are not yet the complete spatial API for Orias/Odradek.

No Marching movement, collision, balance or visual behavior is changed by this
commit. The audit does not justify a rewrite. M4's local gate remains open until
the focused runners pass; Orias has not begun.

## Local verification

Run performance correctness first, then the separate microbenchmark:

```bash
bash Scripts/Sim/run_u13_foundation_tests.sh "$GODOT_U13" --planning &&
bash Scripts/Sim/run_u13_planning_profile.sh "$GODOT_U13"
```

Expected: planning **7/7**, profiles **4/4**. The profiler saves four JSON files
and logs in the unique Downloads directory printed by the script:
`u13-planning-XXXXXX`. Share the four JSON files. It intentionally runs the slower
reference path too. Each profile shard retains the existing 300-second batch
limit. Ordinary foundation runners retain 30 seconds each.

After checking that performance result, the Marching gate is ready:

```bash
bash Scripts/Sim/run_u13_foundation_tests.sh "$GODOT_U13" --marching
```

Expected: Marching-audit **11/11**. This collects existing meaningful spatial,
replay, combat, aura, hazard and feedback tests with the two new audit cases.
The full foundation list is now 50 runners; other focused groups are unchanged.

Workspace verification is grammar/block structure, preload call arity,
dependency closure, diff review and stub-based launcher checks. This workspace
has no Godot 4.7.2 runtime; these are not engine compilation or gameplay passes.
