# U13 effect foundation — 2026-09-08

Base: `2cca7dbae61f860bfeb51a118deac43c3b2ab47a` on `u13-lord-overhaul`.
The U12 runtime and playable baseline are unchanged.

## Scope and verification

Adds shared data handling, Pending Effects, Persistent Effects, focused tests,
and a timeline/save-resume fixture. These are conductor primitives, not wired
into a playable U13 match or the legacy GameState/save pipeline yet. No Lord kit
is implemented by this batch. Fixture stage values only exercise the API.

The new and modified GDScript files were parsed with gdtoolkit 4.5.0, and the
shell runner was checked with Bash. This is not Godot compilation or runtime
verification. Godot was unavailable in the Work environment, and its binary
download could not proceed. The prior three runners were green at the handoff;
all six runners below must pass locally in Godot 4.2 before this batch is called
green or higher-level power implementation begins.

From the U13 worktree in Git Bash:

```bash
git pull --ff-only origin u13-lord-overhaul
bash Scripts/Sim/run_u13_foundation_tests.sh \
  "/c/Users/jerem/Downloads/Godot_v4.2-stable_mono_win64/Godot_v4.2-stable_mono_win64/Godot_v4.2-stable_mono_win64_console.exe"
```

Expected final line: `U13 foundation runners passed: 6/6`.
The wrapper fails on a nonzero exit, missing completion footer, `FAIL`, or
Godot error output. It first checks the shared helper directly with Godot's
`--check-only`, stops at the first failed suite, and limits each Godot invocation
to 30 seconds (override with `U13_TEST_TIMEOUT_SECONDS`). Its temporary logs are outside the project and are removed
after their contents have been printed.

### First local run and corrective patch

The user's Godot 4.2 run at `8b05f9a` passed the timeline, runtime and declaration
suites. The effect suites could not load `U13EffectData.gd`; integration then
hung and required Ctrl+C. The root cause was the helper's `namespace` parameter:
Godot 4.2 reserves that token, while gdtoolkit accepted it as an identifier.
The parameter is now `effect_scope`; generated IDs and snapshot data are unchanged.
The runner changes above expose the direct error and bound failed-load hangs.
The corrected six-suite run still requires local Godot verification.

The next local 4.7.2 run passed Pending Effects and reached one Persistent
Effects failure: strict replay-state equality. The shared copy boundary had
normalized controls and fixed-point values, but left payload counters such as
`kills` as JSON floats. Whole numbers now canonicalize consistently during both
creation and restoration, including stage data and nested arrays; fractional
values remain floats. The integration fixture also normalizes its outer match
envelope before restoring runtime history and event metadata. Strict snapshot
equality remains in place, with typed state dumps if it still fails.

The corresponding 4.2 run exposed an implicit method lookup inside the pending
fixture's lambda. That fixture now captures an explicitly bound Callable and
checks resolver completion before inspecting observations. Cooldowns remain
blocked until the complete local wrapper reports 6/6.

Reference: [Godot 4.2 tokenizer keywords](https://github.com/godotengine/godot/blob/4.2-stable/modules/gdscript/gdscript_tokenizer.cpp).

## Pending Effects contract

- One `U13PendingEffects` instance belongs to each authoritative U13 match.
- `schedule()` preserves the original declaration and copies its payload. An
  optional fire-round/hook override supports future consequences such as Prices.
- IDs derive from namespace, stable declaration ID, and a semantic child key.
  Length prefixes prevent delimiter collisions. Different children of a single
  declaration require distinct child keys. No random or global counter is used.
- `due_effects(round, hook, player_order)` selects the exact hook. An overdue
  effect is an error rather than an unnoticed missed activation.
- The conductor supplies `[0, 1]` or `[1, 0]` from U13's authoritative ordering.
  Hook/effect class is selected first, then cross-player order. Within a player,
  separate submissions use oldest declared round first, then submitted queue
  index, then stable effect ID. The cross-submission tie-break is an explicit
  provisional manager convention, not new Lord text.
- `resolve_hook()` calls one automatic resolver per due effect. It must return
  `{"action":"resolved", ...}` or
  `{"action":"fizzle", "reason":"target_no_longer_standing", ...}`.
  Both consume the effect and emit the existing `Events.make()` shape.
- Target legality, paid costs, state changes, and success-dependent rewards are
  the authoritative power resolver's responsibility. The queue never refunds,
  retargets, requests input, or cancels because the source is Banished.
- A malformed resolver result is an engine error, not a gameplay fizzle. Already
  completed effects stay consumed and their events are returned with the error;
  the failing effect remains pending. The resolver must not mutate on an engine
  error. This manager cannot roll back arbitrary external mutations.
- Resolvers may schedule a new effect for a later hook/round. Inserting at the
  current/past hook and recursive resolution are rejected.
- The U13 runtime now preserves its cursor when a handler returns
  `action: invalid`. This does not roll back handler mutations. A conductor with
  several subhandlers must track successful subhandlers when retrying (for
  example, do not advance persistent state a second time after it succeeded).

## Persistent Effects contract

- One `U13PersistentEffects` instance belongs to each U13 match.
- `activate()` creates stage zero at the declaration's firing round (or its
  declared round when `fire_round == -1`). Its optional `activation_round`
  accepts a Pending Effect's actual firing round when that differs from the
  original submission schedule, preserving the original declaration intact.
- `stages` contains one data dictionary per active round. For example,
  `[{"intensity":1}, {"intensity":2}, {"intensity":1}]` is a three-round clock.
- `advance(round, PERSISTENT_ADVANCEMENT)` advances once at Step 2. It rejects
  duplicate or skipped round advancement. Creation before the current Step 2
  retains stage zero during that round; creation after it ages next round.
- At the next Step 2 after the last active stage, the record is removed and a
  `PERSISTENT_EFFECT_EXPIRED` event is emitted. Damage, healing, movement,
  affected-unit membership and success rewards are not performed by the clock.
- An owner may have one active instance per semantic effect key. Opponents have
  independent slots. Repeated activations use fresh declaration IDs.
- `relocate()` changes only the live target; source declaration, ID, activation
  round and age survive. `set_payload()` updates mutable counters/state.
- Expiration events provide the attachment point for central cooldowns. The
  cooldown system itself is not implemented. In particular, do not count an
  expiration boundary as a completed cooldown round without defining it against
  the agreed activation -> unavailable next round -> ready following rule.

## Serialization and visibility

Snapshots retain full authoritative state and spent-ID ledgers. Restore validates
the entire replacement before modifying the collection. Control integers and
`*_fp` coordinates normalize from integral JSON numbers. Fractions in integer
fields, numeric strings, nonfinite numbers, non-string dictionary keys, and
Object/Callable payloads are rejected. All safely representable whole numeric
values use integer form, including arbitrary payload counters, stages, arrays,
and public data. This applies to live input and JSON restoration alike. Genuine
fractions remain floats; consumers needing a float API argument explicitly cast
at that API boundary. A future U13 match loader must validate and canonicalize
its complete decoded envelope before dispatching individual restore methods,
as the integration fixture does for runtime history and events.

`public_state()` returns copies. Hidden effects expose only their public identity,
source power, and explicitly supplied `public_data`; pending effects also show
the due round/hook. Hidden payloads are hidden from their owner too. Stable IDs
and public_data must never encode concealed outcomes. Full snapshots and resolver
events are authoritative/debug data and must not be passed directly to a player
UI. A production event-view adapter is still needed.

The eventual U13 match snapshot must include the round runtime, both collections,
GameState, RNG and future cooldown state together. The integration fixture proves
the authored save/resume path only; it is not a full game save implementation.

## Identity and infrastructure audit notes

- Existing card/Guard IDs are `suit:value`; `duplicate_card()` preserves those
  values. Confirm deck-wide uniqueness before delayed Guard targeting or future
  effects that create card copies. This batch does not certify that wider audit.
- Existing Castles are keyed by type inside each player. The player/type pair
  distinguishes current structures; reconstruction may require an incarnation ID
  so an old doom does not attach to a replacement. Resolve before Inevitable Ruin.
- Lords currently use player plus Lord name; define return/incarnation semantics
  where a delayed power needs to distinguish one deployment from another.
- Modern commitment Marchers already have `p<player>_r<round>_m<index>` IDs and
  fixed-point state. The generator restarts its local index per spawning call;
  do not reuse that allocator blindly for additional Lord spawns in the same round.
- `Events.gd` provides `{type, text, data}` and is reused unchanged.
- Existing Golden/Playable serializers are tailored to U12. They are inspected
  references, not automatically extended to carry these new collections.
- `GameState.reflex_winner` now means the Momentum extra-action winner. It must
  not silently supply the new queue's Reflex order.

## Next gate

Run all six foundation runners in Godot 4.2. Then complete central cooldowns,
keyed RNG, shared declaration/firing legality, the U13 match owner/event-view path,
and the stable entity identity decisions needed by Gremory. Gremory remains the
first full acceptance slice. Passive Construction's open action/progress question
is unchanged and need not block this foundational work.
