# Orias Snare, Entanglement, and hand-to-Guard deployment

Runtime: Godot 4.7.2 stable. Date: 2026-09-09.

## Gate and scope

The user verified all 72 foundation runners at `00860af` locally before this
extension. This slice adds six runners, bringing the full suite to 78.
The new slice still requires local Godot verification. Static grammar and
launcher checks are not engine execution.

Orias remains an experimental headless profile, outside the playable picker
and Quickstart. This adds Snare and its real Development dependency, plus the
Breach placement limit. Relentless Pursuit, Accelerate, The Mark/resummoning,
Orias board controls, and full Development/Garrison integration remain open.
It does not extend the accepted four-Lord alpha matrix to Orias.

**Name amendment:** Orias's Breach effect is **Entanglement**, replacing the
former name Frenzy. The rule is unchanged. Snare is a separate prepared active.
The U12 production rules and UI remain untouched.

## Rules and timing

- Snare targets the opposing player during normal submission. Its cost is to
  gain one Threat, paid once at joint submission lock. Preview and individual
  sealed submission do not mutate the live Threat value. Invalid complete plans
  roll back the power, payment, cooldown registration, and all card reservations.
- Snare fires at `ROUND_START_SCHEDULED` next round, before the affected public
  state and submission. That player may place at most **one Guard total** across
  the Lord zone and the shared Castle zone during that Development.
- An armed Snare survives its caster's Banishment. It neither rechecks the
  caster's life nor pays Threat again when firing. The cap lasts one Development.
  There is no added cooldown round; the ordinary once-per-power submission
  rule applies. Consecutive declarations can affect consecutive rounds.
- Entanglement applies while Orias is in the Breach: each player with Threat
  at least two may place at most **two Guards total** during Development.
  Humbaba's absent Threat remains absent, not coerced into a qualifying stat.
- Limits are captured at `PRESENT_PUBLIC_STATE`. Later Threat payments or Breach
  changes cannot retroactively alter a plan accepted against that public state.
  If both restrictions apply, the stricter cap of one wins.
- Snare's Threat payment is content-owned and logged in `SNARE_ARMED`; shared
  resource costs remain nonnegative spending. The trusted rule describes
  `threat_gain: 1`, while the serialized source retains `cost: {}`.

## Shared Guard placement contract

The experimental order adapter accepts a `guard_moves` array alongside the
existing combat and Castle-action fields:

```json
{
  "guard_moves": [
    {"card_id": "stable-card-id", "lane": "Lord", "slot": 0}
  ]
}
```

Each side has three Lord Guard slots and three slots in **one shared Castle
Guard zone**, independent of Castle count or type. Slot indices are 0–2.
This slice moves cards from Hand into empty slots; it does not implement
Garrison transfers, replacement, or Guard rearrangement.

Cards stay in Hand while sealed, with an owner-visible reservation after joint
lock. Development removes each selected ID from Hand and changes that same
physical card into a Guard at its chosen lane/slot. Deployment completes after
Castle progress/Repair and before artillery and combat reveal.

A card cannot also fund a Lord power, Castle action, or combat commitment.
Repeated cards, duplicate slots, occupied slots, fractional slots, foreign IDs,
and forged reservations are rejected. Repair can coexist with deployment using
distinct cards: U12's production configuration explicitly sets
`repair_blocks_hand_deploy = false`; its older default is not reinstated.

`GUARDS_SEALED` is owner-only. `GUARD_DEPLOYED` is public at Development.
The public projection exposes both placement limits and Snare activation rounds,
the Entanglement display name, and only the viewer's Guard reservations.

Snapshots validate phase ledgers, sealed moves, original Hand membership,
shared-card costs, public caps, Snare payment timing, and actual Guard placement
immediately after Development. Guards may subsequently be defeated normally.
The experimental Orias policy changes from `U13_ORIAS_WEB_V1` to
`U13_ORIAS_SNARE_WEB_V2`; older experimental Orias saves must be restarted.
The four-Lord policies are unchanged.

## Random-legal path

Orias's candidate provider offers Web and Snare through shared legality. The
experimental scenario also adds bounded Guard candidates for either player.
For each existing combat order, it samples one possible Guard plan plus a
Guard-only alternative. Amount, cards, and empty cells use separate keyed RNG
purposes. Keys use round, player, and canonical order content; reordering the
candidate list does not shift the sampled plan for an existing order.

These are uniformly sampled components of a bounded vocabulary, not exhaustive
uniform sampling of every possible complete Development plan. Existing combat
orders remain available. Shared legality filters complete plans after power and
Castle payments; the bot does not implement a competing rules validator.
No balance or frequency conclusion is inferred from these tests.

## Focused verification

```bash
bash Scripts/Sim/run_u13_foundation_tests.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe" \
  --snare
```

Expected: `U13 Snare runners passed: 6/6`.

- Guard deployment: physical movement, private reservations, shared-zone slots,
  costs, malformed inputs, Repair coexistence, and atomic snapshot rejection.
- Snare: delayed activation, exact Threat payment, public Entanglement limits,
  Humbaba's absent Threat, nonretroactive caps, and prepared firing after Banishment.
- Three separate replay runners: rounds one, two, and three; hook-by-hook replay,
  JSON checkpoints, one-Guard legality in the affected round, expiration afterward.
- Guard random: sampled candidates, keyed stability, central legality equivalence,
  valid submissions, physical deployment, and deterministic replay.

The per-runner watchdog remains 30 seconds. `--orias-web` remains seven runners;
remove the selector for all 78. Standalone animation previews remain available.
