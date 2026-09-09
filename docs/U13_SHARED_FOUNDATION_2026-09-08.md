# U13 Milestone 1 shared foundation — local gate pending

## Runtime and verification status

The user verified commit `adab8f6895269f84e149096775172d750e5cc010`
on Godot **4.7.2 stable**, with `U13 foundation runners passed: 6/6`.
That clears the previous timeline/declaration/effect foundation. U13 now targets
4.7.2; this work does not attempt to preserve Godot 4.2 compatibility.

This batch adds central cooldowns, keyed RNG, entity identity, declaration/firing
legality, an authoritative U13 match owner, and explicit player event projections.
The wrapper now checks the runtime version, compiles shared dependencies directly,
and runs **nine** suites. It still rejects engine errors even when Godot exits zero,
requires every completion footer, stops at the first failure, and times out hangs.

Checks performed in the coding environment:

- All U13 GDScript files parse with gdtoolkit's static parser. This is **not** a
  Godot compiler or runtime result; it previously missed a Godot reserved word.
- Bash syntax validation passes.
- Process-shim checks cover 9/9 orchestration, rejection of the old executable,
  dependency-preflight errors, missing suite footer, and exit-zero engine errors.
  These shims do not execute or validate game rules.
- RNG expected values were independently calculated with Python `hashlib`.

Godot is not installed in this environment. The new three suites and the expanded
nine-suite run still need authoritative local execution. **Gremory remains blocked
until `U13 foundation runners passed: 9/9` on Godot 4.7.2.**

```bash
git fetch origin u13-lord-overhaul &&
git merge --no-edit FETCH_HEAD &&
bash Scripts/Sim/run_u13_foundation_tests.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
```

There is a runnable headless match fixture, not a new playable U13 match scene.
Opening the editor is not an additional gate for this foundation batch. The U12
scene/controller and frozen reference branch remain unchanged.

## Central cooldown semantics

`U13Cooldowns` owns one clock per `(player_id, lord_id, power_id)`.
No Lord script decrements a private counter. Cooldown registration identities have
a durable used ledger; a consumed declaration cannot restart a clock after load.

| Case | Active/activation rounds | Blocked rounds | Ready at Step 2 |
|---|---|---|---|
| Instant, cooldown 0 | R3 | R3 reuse prevented | R4 |
| Instant, cooldown 1 | R3 | R4 | R5 |
| Instant, cooldown 2 | R3 | R4–R5 | R6 |
| Persistent, cooldown 1 | R3–R4, expires R5 | R5 | R6 |
| Persistent, cooldown 0 | R3–R4, expires R5 | None after expiration | R5 |

The match owner registers activation cooldowns when the joint submission locks,
when the activation/cost is committed. Delayed firing does not restart that clock.
Expiration-based powers reserve their slot immediately and bind it to the actual
persistent instance ID. They remain unavailable while prepared/active. Step 2 is:

1. Advance existing persistent effects.
2. Deliver actual expiration events to the cooldown registry.
3. Advance/release cooldowns.
4. Resolve pending effects due at Step 2 (new prepared effects stay at stage zero).

A failed firing that never creates its promised persistent instance cannot wait
forever for an expiration event. `fizzle_waiting` starts its spent cooldown from the
failed firing round; costs remain spent. A round-start fizzle can occur before this
round's Step 2, and that boundary is serializable.

## Stable entity decisions

Audit evidence in the existing runtime:

- `Card.card_id()` describes `suit:value`, but `SeededGameSetup.CARD_COUNTS`
  creates several physical copies of each face. That value is not an instance ID.
- Existing Marcher IDs contain player/round/per-call index. The per-call index can
  repeat when a power creates another batch during the same round.
- Castles are presently stored by owner/type, which cannot distinguish a destroyed
  Castle from a rebuilt incarnation for delayed targeting.
- `GameState.reflex_winner` is the existing Momentum action winner. It must not be
  substituted for U13 Reflex execution order.

`U13EntityIds` is the U13 authoritative entity registry, not an object-address map.
It reuses `U13EffectData.instance_id`'s length-prefixed encoding. Every entity ID is
`kind + immutable creation origin + ordinal`. Current owner/location are attributes.

| Entity | Creation origin and lifetime |
|---|---|
| Lord | Setup player/roster slot; Banishment changes `alive`, retaining the ID. |
| Card/Guard | Deck face plus physical copy ordinal assigned **before shuffling**. Guard is a card role, not a new physical identity. Preserve the ID across zone and allegiance changes. |
| Marcher | Creating effect ID plus spawn ordinal (or a stable base commitment ID). Distinct creation effects cannot share a batch origin. A Marcher backed by a card retains that card's ID in its attributes as well as its own actor ID. |
| Castle | Setup slot for the initial incarnation; rebuilding uses the rebuilding effect/declaration as a new creation origin. The old ID stays retired. |
| Pending/Persistent effect | Existing effect instance IDs remain unchanged; do not register duplicate entity identities for them. |

`create`, `update`, `retire`, `get_entity`, `snapshot`, and atomic `restore` are the
shared path. Retired IDs are never recycled; owner/location changes retain IDs.
The match owner also rejects transforms that erase identity history or resurrect
an already retired ID. Origin strings are semantic, not current array positions.

This batch does not retrofit IDs into mutable U12 Card/PlayerState objects. A future
playable U13 setup must construct this registry at creation time; it must not attempt
to recover unique card identities later by matching `suit:value`.

## Keyed deterministic RNG

`U13KeyedRng.draw(seed_string, effect_id, purpose, roll_index, bound)` returns a
uniform integer in `[0, bound)`, or an explicit invalid result. There is no global
cursor, mutable engine RNG state, or dependency on unrelated calls.

Algorithm identity: `U13_SHA256_REJECTION_V1`.

- Fields: version, seed, effect ID, purpose, decimal roll index, decimal retry index.
- Each field is prefixed with its UTF-8 **byte** length and `:`; concatenate fields.
- SHA-256 digest; first four bytes are an unsigned big-endian 32-bit integer.
- Reject values at/above `2^32 - (2^32 % bound)`; retry with the next retry index.
- Return accepted value modulo bound. Bounds are 1 through `2^32` inclusive.
- A pathological 1,024 consecutive rejections returns an error, never a biased roll.

The engine hash API is documented at
<https://docs.godotengine.org/en/stable/classes/class_string.html#class-string-method-sha256-buffer>.
Golden vectors include Unicode, the full unsigned range, and a key requiring a
rejection retry. Match snapshots pin both seed and algorithm version. Candidate
selection must use a canonical stable-ID order before mapping a roll to an entity.

## Match ownership and common legality

`U13Match` owns the round cursor, pending/persistent effects, cooldowns, entity
registry, world data, both submissions, explicit player execution order, RNG seed,
and event log. Its methods are:

- `start(seed, world, player_order)` and consecutive `begin_next_round(player_order)`.
- `preview_submission(player, full_queue)` and `submit(player, full_queue)`.
- `run_next_hook()`, `next_hook()`, and `player_view(player)`.
- Authoritative `snapshot()` and atomic `restore()`.

An initial world is data only: two players with Lord instance references and
resource dictionaries; an entity-registry snapshot; and a content-owned `data`
dictionary. U13 does not import the U12 GameState as its live mutable owner.

The content configuration contains a nonempty implementation `policy_id`, power
rules, validators, resolvers, a world projector, and an ordinary-hook handler.
Callbacks must be pure functions of their provided copied data. No external writes,
Node mutation, interactive prompts, mutable RNG cursor, or hidden callback state.
Changing callback logic requires a new policy ID. Rules content is independently
hashed in the snapshot. Engine/RNG/schema/policy/rules mismatches reject the load.
This fixes identity for this U13 owner; it does not rewrite U12 snapshot policy debt.

Current declarative rule fields are Lord ID, fixed hook/delay, visibility, resource
cost map, target kind/ownership relation, cooldown length/start mode, and optional
persistent stages. Additional legality lives in the same registered validator for
all callers, with an explicit `declaration` or `firing` phase. Geometry and individual
power rules are content extensions, not hard-coded into this foundation.

A validator receives `(declaration_copy, world_copy, phase)` and returns
`{legal: bool, reason: String}`. Wrong return shape is an engine/contract failure,
not a gameplay fizzle. The common declaration pass checks source availability,
canonical identity and timing, configured cost/visibility, target, cooldown and
resources. The firing pass checks the current target and power-specific rule but
does not re-charge cost or invalidate an armed power merely because its source was
Banished. Failure consumes the effect, retains cost/cooldown, produces a fizzle,
and never invokes the success resolver or prompts for retargeting.

The full queue is previewed atomically, including combined cost and cooldown
reservations. Each player submits once, including an empty queue. The joint lock
requires both submissions and commits costs/arming in explicit player order.
Both declaration passes use the presented round world, with only that player's
staged resource budget changing across its own queue. Spending by the first player
at joint lock cannot invalidate the second player's already accepted choice.
Declaration IDs derive from player, round and queue index; the client cannot choose
an ID that collides with an opponent. UI and bots call `preview_submission`; submit
uses that exact path. No production U13 UI or bot adapter is included yet.

Resolvers receive `(effect_record_copy, {world, seed, round, rng_version})` and
return `{action: "resolved", world: updated_world, events: event_array}`. Registered
persistent stages are activated after successful resolution, in a separate slot
for each named power. Ordinary-hook handlers
receive `(hook, round, world_copy)` and return the same transform envelope, except
that their event array contains explicit `{event, views: [p0_view, p1_view]}` rows.
They are the future combat/development adapter boundary, not a new implementation
of all base-game mechanics in this batch.

Each hook runs on a candidate owner. A bad later resolver discards earlier world
changes, queue consumption, clock changes, events and cursor advancement from that
hook. A retry therefore cannot duplicate rewards/events. This transaction does not
undo prohibited external side effects in a content callback.

## Authoritative events versus player views

`U13EventLog` stores authoritative `{type, text, data}` events with separately
provided views for player 0 and player 1. `null` hides an event entirely. A minimal
projection can be identical for both players, including when the owner must not
know a future Price outcome. A player's getter returns deep copies.

The match owner uses existing effect-manager public projections. Pending effects
expose due round/hook even when their payload is hidden. Hidden declaration-derived
events are omitted from **both** player logs. The authoritative snapshot retains
them. Future content must explicitly implement a permitted reveal; it must not
forward an authoritative event to the owner automatically. Ordinary-hook events
must provide explicit views, and world state passes through an allowlist projector.
The player path never returns the authoritative snapshot or RNG seed.

## New acceptance suites

- `U13CooldownsTestRunner`: zero/one/two-round timing, persistence expiration event
  binding, replay boundaries, fizzle timing, independent slots, invalid restores.
- `U13DeterminismTestRunner`: independent RNG vectors, unrelated-roll independence,
  duplicate card faces, allegiance/relocation, rebuilt Castle identity, durable
  retirement, explicit hidden views and authoritative event replay.
- `U13MatchTestRunner`: joint lock, shared preview/submit, combined spending, canonical
  IDs/timing, no post-lock choice, fizzle without reward/refund, Banishment survival,
  Step 2 prepared creation/expiration/cooldown, hidden RNG, exact JSON replay,
  whole-hook rollback/retry, player/queue ordering, and snapshot version/consistency.

No Gremory content, U12 runtime/controller edits, or playable U13 scene are part of
this commit. The next action is the local 4.7.2 nine-suite gate.


## Local verification follow-up: match fixture startup

The user's Godot 4.7.2 run of `ca160e9` compiled every shared dependency and passed
all first eight suites. `U13Match` failed its initial `match_starts` check; later
missing-world errors were consequences of continuing after failed initialization.
The nine-suite gate therefore remains **not cleared**.

The fixture added its last rule using `rules.SecondZone = ...`. Godot's named
Dictionary setter takes a `StringName`, whereas U13's strict data boundary requires
String keys. All other rule keys already existed as String keys in a literal.
Use `rules["SecondZone"] = ...` when inserting that new key. Do not loosen
`U13EffectData.is_data` or silently convert arbitrary non-data objects.

Engine source reference: `Variant::set_named` forwards its StringName member to
`Dictionary::set` in
https://github.com/godotengine/godot/blob/4.4-stable/core/variant/variant_setget.cpp.

The match runner now checks serializable fixture rules and a complete startup
before running dependent scenarios, and verifies explicit rejection of a
StringName rule key. Startup errors print the returned reason; failed fixture
creation does not lead to reading an empty world. Match start distinguishes invalid
rules data, configuration, seed, player order, and an already-started owner.

The change passes static parsing here. Godot is still unavailable in this coding
environment; the authoritative 4.7.2 wrapper rerun is required. Gremory stays blocked.


## Accepted plan amendment: random-legal declarations

The user's [Random-Legal Doctrine Tier addendum](U13_RANDOM_LEGAL_ADDENDUM_2026-09-08.md)
adds a legal random-declaration path to each power's definition of done.
Gremory's verified correctness checkpoint does not complete that new requirement.
The chooser and frequency/reachability instrumentation remain pending, scheduled
after the smoke-scene gate and before adding another Lord. Milestone 3 proves
correctness, not balance; Level 5.5 batches report distributions and trigger counts,
never random-bot win rates. Real doctrine retains priority and Milestone 9 stays put.


## Accepted Kanifous power-list amendment — 2026-09-09

The [Kanifous power list](U13_KANIFOUS_POWERS.md) now names its passive
battlefield objective **The Wishmaster**. The accepted
[Smoke/Lamp addendum](U13_KANIFOUS_THE_WISHMASTER_2026-09-09.md) replaces the
immediate Chest and draw-one reward with a one-round public telegraph,
next-round contested Lamp, 10% rejection and suit-specific claimant effects.
Kanifous remains design-only; this amendment does not clear or bypass the
Marching/spatial gates. The active Wish/Price system is retained.
