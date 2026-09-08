# U13 Construction, activation and War Foundry

## Scope and local gate

This adds the shared Castle Development path to the Deimos/Gremory headless
profile. It follows the accepted mixed-roster batch and the user's clarification
that **every Construction action receives its passive bonus, regardless of its
permitted spending choice**. It also incorporates the subsequent request to
preserve construction protection and make activation at seven a player choice.

The accepted Gremory board, its worker/playback path, U12 scenes, project settings
and main scene are unchanged. This is the rules/batch gate before adding more
Deimos behavior or board controls. Rout, other Development actions, other named
Castle effects, normal draws, Hunt, Profane, Veil and victory remain outstanding.

Godot **4.7.2 stable** is authoritative. This environment has no Godot binary.
Grammar parsing, source review and simulated Bash launcher checks passed here;
compiler and runtime verification of this change is still pending locally.
The full wrapper now expects **19/19**, retaining its 30-second suite watchdog.

## Castle lifecycle

Activation is a **one-way action**, not a reversible protection toggle.

| State | Targetable/damageable | Castle effects | Allowed Castle actions |
|---|---|---|---|
| Unbuilt identity | No | None | Construct |
| Protected build, below 7 | No | None | Construct |
| Protected build, 7 or higher | No | None | Construct, or Activate |
| Full protected build | No | None | Activate |
| Activated | Yes, while standing/defunct | Operational effects require at least 7 Integrity | Repair when damaged |
| Ruined | No | None | War Foundry may admit own Siege Engine to Construct |
| Profaned | No in this slice | None | No reconstruction |

The implementation choices stated during the work are explicit:

- A player chooses **one** Construct, Repair or Activate action per round.
- Construct supplies **3 passive Integrity**, including with zero card spending.
- Optional acceleration gives `floor(sum of printed card values / 3)` additional
  Integrity. Cards are discarded, never combat commitments. Repair tokens cannot
  accelerate Construction; the old source has Repair tokens, not a separate
  Construction-token currency.
- A selected project retains its identity and progress. A round with no Castle
  action makes no progress. Repair or Activate does not also grant the build tick.
- Full build is normally **21 Integrity**, clamped to the current effective
  ceiling. Reaching full stops Construction, clears the selected build target,
  and **still awaits player activation**. It never auto-selects another Castle.
- Activate may be chosen at 7 or more. It costs no cards or tokens, uses the
  round's Castle action, and grants no extra Integrity. It ends passive building
  on that Castle permanently; subsequent growth uses Repair. There is no
  Deactivate action and no way to re-enter protected construction after damage.
- Only actual Ruination and War Foundry eligibility permit an activated Engine
  to begin a new protected reconstruction cycle.
- Existing active Castles below seven remain exposed but lose operational
  effects. The carried-forward Repair lock blocks Repair in the round following
  damage that crosses from at least seven to below seven. Repair is available
  after that lock expires. This applies to Siege, artillery and Inevitable Ruin.

Repair retains the audited old payment vocabulary: each Wright contributes its
printed value; another suit contributes `max(1, value - 1)`; an optional Repair
token contributes three and is consumed. Repair requires some payment and caps at
the effective maximum. These tokens cannot heal a still-protected build.

Deimos's Breach ceiling can finish a protected build by lowering its maximum; it
still does not activate it. Raising the ceiling grants no healing. A protected
ready Castle with new headroom may choose further Construction or activate.

The fixture contains two stable Castle identities per side, not the complete
five-type Castle roster. It does not reinterpret the old three-Castle opening as
the final roster limit or simulate the remaining named Castle effects.

## Authoritative timing and payment

A sealed order may contain an optional `castle_action` alongside existing
Siege/Ward fields:

```json
{
  "castle_action": {
    "action": "Construct",
    "target_id": "stable Castle entity ID",
    "card_ids": [],
    "use_repair_token": false
  }
}
```

`action` is Construct, Repair or Activate. Exactly one choice is accepted. A
player may also make the existing combat commitment with separate physical cards.
Whole-plan preview, bot filtering and submission share the same owner validation.
Lord-power costs, Castle costs and combat commitments cannot share a card.

Both plans lock against the presented round state. Payment is reserved at joint
Submission Lock; nothing is paid by preview or by the first sealed submission.
Progress/activation happens at Development, before Step-7 artillery. Target and
reconstruction admission are checked again at resolution. A later-invalid target
produces `CASTLE_ACTION_FIZZLED` without refund, rather than a partial transaction
or an extra player prompt.

An Engine activated during Development can fire normally at Step 7 and can be
hit by opposing artillery immediately. War Machine still requires an operational
Engine **at declaration**: an unactivated or under-seven Engine cannot predeclare
it in anticipation of activation or Repair. Siege and Inevitable Ruin likewise
cannot predeclare an attack on a protected enemy Castle. Their existing firing
legality rechecks and artillery acquisition all respect the same protected state.

`U13Structures.targetable` and `operational` are the shared queries for future
Castle integrations. Protected builds are excluded from both. The Battle transition
boundary also rejects destruction/Ruination and legacy full-Repair commands on
protected structures. No player payload can toggle an attribute directly.

## Stable identity, policy and restoration

The opt-in profile is `U13_CASTLE_DEVELOPMENT_V1`, appended to the match policy.
Existing Gremory and prebuilt Deimos test profiles retain their previous behavior.

Castles add `construction_state`: unbuilt, building, ready or active. Status still
records standing, defunct, ruined or profaned; positive Integrity alone no longer
means an opted-in Castle is activated. Optional `repair_lock_until_round` records
the Repair lock. Protected builds cannot hold an artillery target or damage lock.

World data carries a Development round ledger, two selected build target IDs, and
two Castle reservation records. A record binds the exact choice to its round,
paid value and reconstruction admission. Aftermath clears reservations. Snapshot
validation checks their shape, phase, original presented Hand/payment, token spend,
physical identity, cross-action card conflicts and the Development ledger.
Malformed restoration rejects atomically; JSON integer normalization uses the
existing shared data boundary.

War Foundry requires a living Deimos's **own ruined Siege Engine**. Normal
Construction rates, card costs, action limits, protection and activation apply.
Reconstruction updates the same entity ID, clears the old targeting lock, retains
its acquisition history, and does not award another destruction event. Profaned
Engines, enemy structures and ruined plain Castles are excluded.

## Random-legal measurement

`--roster=construction` uses a labeled mixed fixture: damaged active plain
Castles, a ruined Deimos Engine, an unbuilt Gremory Engine, four initial Hand cards
and two Repair tokens per side. Normal round draws remain absent.

The chooser asks central legality for Construct/Repair/Activate choices after
selecting its power, then filters combat against the remaining cards. It samples
legal action names uniformly and then legal canonical target/payment choices.
The finite test vocabulary includes free Construction, every single card/pair,
Repair with/without one token, and free activation. Human/owner submissions may
spend larger valid sets; this bounded vocabulary is recorded as a batch limitation.

Dedicated keyed purposes are `BOT_CASTLE_ACTION` and `BOT_CASTLE_PAYMENT`, under
`U13_RANDOM_CASTLE_V1`. Existing power decisions and real-doctrine precedence are
unchanged. No sequential stream is introduced. Providers read the player's view.

Reports add per-player Castle action/fizzle counts, reconstruction starts, full
Construction completions, and the **distribution of Integrity at activation**.
That distribution will let us observe early exposure once the full economy exists;
it is not a balance verdict. Existing Marcher/waiter distributions, Tears, artillery
and independent replay checks remain. No win rates are generated.

## Regression coverage and command

`U13ConstructionTestRunner` covers free/paid passive progress, aggregate 3:1
rounding, payment reservation and conflicts, protected builds, optional activation
at seven, full builds awaiting activation, immediate artillery exposure, no return
to passive Construction, Repair payment/lock, War Foundry identity/exclusions,
ceiling changes, no automatic next target, per-hook JSON restoration/replay,
invalid restoration rollback and deterministic random plans/batches.

```bash
u13_godot="/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
git pull --ff-only origin u13-lord-overhaul &&
bash Scripts/Sim/run_u13_foundation_tests.sh "$u13_godot" &&
bash Scripts/Sim/run_u13_random_batch.sh "$u13_godot" --roster=construction
```

Expected local gate: `U13 foundation runners passed: 19/19`, then
`U13 random-legal batch completed: OK`. Share Downloads
`u13_random_construction.json` and `u13_random_construction.log`.
Do not mark this runtime-verified or start Rout until that gate is green.


## Construction runner timeout correction

The user's Godot 4.7.2 failure log `u13-foundation-failure-sK1aHe.log` records
all Construction rules, activation/protection, payment checks, every per-hook
JSON restore/replay check and both deterministic player plans passing. The first
two-round Construction batch also completed. The combined process reached its
30-second watchdog during the independent replay of that batch. This establishes
the stopping point; the old log has no stage timings to assign exact costs.

Separate the rule/owner replay checks (`U13Construction`) and random-plan/batch
replay checks (`U13ConstructionRandom`) into two processes. Both retain the same
30-second watchdog. No assertion, seed, round, independent replay or production
rule is removed or changed. The new runner inherits the existing fixture and
assertion code and overrides only deferred test dispatch. Stage timings and batch
round progress identify any remaining slow section on the local machine.

The full foundation wrapper has 19 suites. To rerun just this corrected gate:

```bash
bash Scripts/Sim/run_u13_foundation_tests.sh "$u13_godot" --construction
```

Expect `U13 construction runners passed: 2/2`; this focused result does not claim
a full 19/19 run. Then run the previously requested `--roster=construction` batch.
The split's wall-time margin still requires local measurement. Grammar and
simulated launcher checks do not establish Godot runtime performance.


## Random planning cost correction

The subsequent local log `u13-foundation-failure-2g4eHc.log` shows the separate
random runner still timing out during its replay. The first two-round batch took
12,681 ms; round two began at 9,736 ms. Splitting runners alone was insufficient.
Those timings include all work in each round, not an isolated planner benchmark.

Source review found a repeated cost: every raw Castle/combat candidate entered
whole-match cloning and validation, including protected/ineligible targets and
physical-card conflicts that the shared rules could reject earlier.

An optional owner-side order screen now evaluates a batch against one detached
world. Construction reuses its authoritative target predicate and the shared
CardZones Hand-selection predicate; it screens Castle eligibility, token budget
and card conflicts across the selected power, Castle spending and combat. It
returns candidate indices, preserving payloads and input ordering. Every survivor
still runs the same complete `_accept` checks used by `preview_submission`, and
the selected plan still requires normal submission. The screen cannot authorize an action. Missing/malformed
screening falls back to full validation. The ordinary Gremory and prebuilt Deimos
profiles have no screen and keep their existing path.

The optimization creates no persistent candidate cache, random draws or new game
state. Restore and transactional forks retain the configured content callback.
Full world checks at normal payment/submit/restore boundaries remain. The legal
domain, canonical ordering, keyed purposes, seeds, two-round trials and independent
replay assertions are unchanged.

Small differential fixtures compare screened-plus-full validation with the
original full-preview path for reconstruction, Repair, activation, token shortages
and power/combat card conflicts. They also check purity and malformed-screen
fallback. The random runner prints candidate/survivor counts and optional batch
timings for planning, lock and Marching, so another local failure identifies the
remaining cost. These diagnostics do not enter replay state or report digests.

Grammar and source checks are available here; no Godot executable is installed.
The actual speedup and 30-second margin require the focused local 2/2 run.

Candidate-batch validation also checks the unchanged owned baseline once, then
forks isolated transactions for each surviving plan. This removes repeated
cross-component snapshot consistency checks on the exact same baseline. Public
single-plan previews retain their original checks; loading a save retains full
restore validation. Differential fixtures compare this batched path directly
with repeated public `preview_submission` calls.

## Castle composition and Rout follow-up

The user has now locally verified the focused 2/2 at the 30-second default and
reported the four-seed Construction batch completed with matching replays.
See `U13_CASTLE_LOADOUT_ROUT_2026-09-08.md` for the accepted prior measurements,
new five-slot/two-copy setup rule, Commission terminology, **shared** Castle
Guard zone, and the next local verification gate.
