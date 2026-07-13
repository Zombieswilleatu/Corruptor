# Golden-Master Harness — Cross-Implementation Test Contract

The Python sim is the **oracle**. The GDScript engine must reproduce its state
exactly. This harness makes that mechanical: the oracle emits versioned JSON
traces; the Godot loader replays each scenario and asserts state-equality.

Because Corruptor is *a GUI over a state machine*, a single wrong number in
resolution is invisible until the game feels "off." This harness is how you
catch it the moment a rule is ported wrong, instead of debugging a heap later.

## Files

| File | Side | Role |
|---|---|---|
| `golden_serializer.py` | Python | Canonical state → deterministic dict (sorted sets, tokenized cards, sha256) |
| `golden_master.py` | Python | Scenario definitions + driver; writes `golden/*.json` |
| `golden/*.json` | shared | The traces — one per scenario, each with a `trace_hash` |
| `golden/_manifest.json` | shared | schema + AI version + all hashes (CI compares against this) |
| `GoldenMaster.gd` | Godot | Loads a trace, replays it, asserts state-equality |

## Workflow

**Regenerate goldens (after an intentional oracle change):**
```
python3 golden_master.py
```
**CI guard — fail if the oracle drifted unintentionally:**
```
python3 golden_master.py --check      # exit 1 on any hash drift
```
**Godot side — validate the engine (once the real resolver exists):**
```gdscript
var rules := RuleConfig.de_v2()
var results := GoldenMaster.run_all(
    func(name, trace): return MyEngine.replay_scenario(name, trace),
    rules, "heuristic-2025.06-doctrine")
for r in results:
    print(r)   # PASS/FAIL with first divergence located
```

## Two scenario families

- **UNIT** (`unit_*`): a hand-built board run through exactly one mechanic —
  the rulebook's combat examples, sigil layers, Siege-Engine bypass order,
  Humbaba's defense curve, the Seal. Fast, surgical. **The GDScript engine
  should pass every unit trace before a single game scenario.** They isolate the
  combat resolver and kit math from all the integration noise.
- **GAME** (`game_*`): a full fixed-seed game under DE v2, snapshotting the deal
  and the terminal state. These catch emergent/integration divergence —
  deck-order, setup, win-resolution — that no unit test sees. Currently coarse
  (deal + end); when the GDScript port exposes per-round step hooks, add
  mid-round checkpoints by snapshotting inside the round loop.

## The serialization contract (read before trusting a hash)

Cross-language canonical JSON is **fragile**. Two known divergence points between
Python `json.dumps` and Godot `JSON.stringify`:

1. **int vs float** — Godot round-trips all JSON numbers as float; it may emit
   `5.0` where Python writes `5`.
2. **nested key-sort depth** — verify your Godot version deep-sorts keys.

Therefore the harness treats the **structural diff as authoritative**, not the
hash. In `GoldenMaster.validate()`:
- hash match → trusted equal (fast path);
- hash mismatch → run the structural diff anyway. If the diff finds nothing, the
  mismatch was serialization noise and the trace **passes** (flagged). Only a
  real structural divergence fails.
- numeric comparison is type-tolerant (`5 == 5.0`), so float round-tripping never
  masquerades as state drift.

If you want the hash fast-path to fire more often, tighten `canonical_json` on
the GDScript side to match Python byte-for-byte (coerce whole floats to ints
before stringify). Not required for correctness — the structural diff covers it.

## The identity gate (Law 5)

Every trace records the `RuleConfig` constants + `VARIANT` + `ai_version` that
produced it. `GoldenMaster.identity_matches()` **refuses** to validate a trace
whose config/AI version doesn't match the engine's — because balance/behavior
data is invalid across rule and policy versions. When you change the ruleset or
the bot doctrine: bump `AI_VERSION` in `golden_master.py`, regenerate, commit the
new goldens as a deliberate act. A silent regen that changes hashes is the thing
CI is there to stop.

## What's proven working

- Determinism: back-to-back regeneration is bit-identical (10/10 hashes stable).
- Drift detection: a one-point rule change (`WIN_SOULS` 7→6) fires drift on
  exactly the traces whose outcomes depended on it — verified.
- Locating power: on mismatch, the diff reports `checkpoint.field want=X got=Y`,
  so a failure names the exact subsystem, not "something's different."

## Extending

- **New unit scenario:** add a `unit_*()` builder to `UNIT_SCENARIOS` in
  `golden_master.py` that builds a state, runs one op, snapshots the result.
- **New game scenario:** add a `game_scenario(name, seed, pool0, pool1)` to
  `GAME_SCENARIOS`. Pick seeds that exercise a specific interaction (the current
  set covers a Ritual race, the Humbaba–Odradek predator pair, Kroni decay, and
  a mixed pool).
- **Finer game checkpoints:** when the GDScript engine has step hooks, mirror
  them in the Python driver — call `snapshot_game(g, "round:%d:post_resolution")`
  inside the loop and the loader will diff each round independently, so a
  divergence points at the exact round *and* phase it first appeared.

## Suggested first milestone

Before porting the whole engine, port just enough to pass the six **unit**
traces — that's the combat resolver + Humbaba's defense/seal math. Green unit
traces mean the hardest, most error-prone arithmetic in the game is provably
correct. Then the game traces become the integration checklist as the round loop
comes online.
