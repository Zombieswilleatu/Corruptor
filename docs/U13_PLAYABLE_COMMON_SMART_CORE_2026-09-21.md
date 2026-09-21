# Shared V26 planner in the playable game

The playable opponent now runs `U13_COMMON_SMART_CORE_ALPHA_V26_ODRADEK_FIELD`, the same `CommonSmartCore` implementation used by the Python comparison runner. This includes complete-plan coordination, closing priorities, defense, economy choices, resource saving and all nine Lord modules. Both new games and compatible resumed saves use the updated opponent at their next decision.

This is a desktop development integration using a local Python worker. It is not a GDScript rewrite of the planner. The current checkout needs Python 3.10 or newer alongside Godot; standalone distribution will need a bundled runtime/worker or a subsequent native port. Game rules, costs, strength settings and the planner's weights are unchanged.

## Authority and information

`U13PlayableSession.gd` now calls `U13CommonSmartCore.gd` for the opponent's complete plan and Stockpile/Slaver choices. The existing native Basic Doctrine remains available to legacy tests and comparison drivers.

`U13CommonObservation.gd` constructs an explicit public/own-hand observation matching Python's observation contract. During simultaneous planning it uses the same pre-submission world as the human view. The worker receives no match snapshot, seed, deck/discard ordering, undeployed enemy hand, sealed opposing commitment or future random sequence. Public effects are reduced to the same fields as in the Python runner.

The worker executes the existing planner once. When it needs a preview, it sends the complete candidate back to Godot; Godot checks that candidate through one isolated native planning session and replies with legality. A final plan must be identical to a plan actually admitted in that session. Normal submission still validates it again. Neither the Python simulator nor a guessed reconstruction of hidden state adjudicates the live match.

Transport uses the existing exact typed codec, preserving integer/float distinctions and floating-point bits. The interface uses [Godot's process pipes](https://docs.godotengine.org/en/stable/classes/class_os.html#class-os-method-execute-with-pipe). There is no network service or remote inference.

The existing limits remain 16 generated/four retained candidates per category, 32 complete plans and eight previews. The process boundary adds no repeated planner runs or extra tactical search. A separate 20-second watchdog aborts a stalled worker; elapsed time never chooses a partial plan. Missing runtimes, closed pipes, malformed replies and exhausted previews produce visible errors, with no fallback to Basic Doctrine or an unscored Pass.

## Playable integration

The existing board worker performs opponent planning before committing either seat. The human cart is not included in the bot observation. Economy choices and advancing to the next planning pause are staged on an independent session and adopted only after all required bot choices succeed. A failed bot choice preserves the previous human choice/checkpoint for retry. The session's visual-event buffers are preserved across forks.

The save schema and authoritative rules identity are unchanged. The adapter is stateless between decisions; no Python process, cached tactical plan or private observation is serialized into saves.

The launcher now discovers Godot 4.7.2 stable on PATH or in common Downloads locations, verifies Python, imports the current planner and prints its policy identity before starting the game. Explicit executable arguments and `CORRUPTOR_BOT_PYTHON` remain available. The 4.7.2 production runtime gate is preserved.

## Verification

- **31 exact observation/decision contracts / 341 native assertions pass.** These cover each Lord in both seats, both seats' Stockpile and Slaver choices, a resilient winning Invocation, and eight natural round-four decisions involving Kalligan, Orias, Odradek, Kroni, Valak and Kanifous. Complete decisions, diagnostics and scores match Python exactly.
- Those contracts also check unchanged authoritative state during planning, unchanged observation after the opposing seat submits, hidden seed/card/order exclusion, missing-runtime behavior, preview rejection, successful retry of a failed economy transition, and termination of a deliberately stalled child process.
- **17 playable-session assertions pass** with the updated opponent: economy pauses, stale-choice rejection, save/resume, human-cart preservation, animated worker resolution against the independent native conductor, visual retirement and round-end restore.
- **Two two-round playable smoke games / 36 assertions pass in 30.43 seconds.** The board worker played Kroni versus Odradek and Kanifous versus Valak, checking adoption, round advancement and exact save restoration. Valak cast Gravity Orb in round two. Odradek held its powers during these first two rounds; there is no forced cast quota.
- **36 focused Python tests pass** for common planning, closing and the nine saved defense expectations.
- Launcher checks verify executable paths containing spaces, real planner import/preflight, runtime propagation, missing Python rejection and preservation of the Godot version gate.

The original single-decision probe took 162 ms. The final contract checks took roughly 0.2–0.6 seconds each including their extra validation/assertion work; those are local timings, not a Windows performance guarantee.

Native verification used local Godot 4.5.1 headless. Windows 4.7.2 rendered play and process-launch behavior remain to be confirmed on the user's machine. There was no long campaign and no win-rate claim. The previous audit's nine-Lord rule-resolution results remain separately scoped; this checkpoint additionally establishes sampled planner-decision equivalence.

## Play

From the Corruptor checkout:

```bash
bash Scripts/Sim/run_u13_playable.sh
```

If automatic executable discovery cannot find the installed programs:

```bash
bash Scripts/Sim/run_u13_playable.sh "/path/to/Godot_4.7.2.exe" "/path/to/python.exe"
```

The startup output should name `U13_COMMON_SMART_CORE_ALPHA_V26_ODRADEK_FIELD`. The script keeps the existing run-log and save locations and launches the U13 playable scene explicitly.

## Reproduce focused checks

```bash
python Scripts/Sim/export_u13_common_bot_cases.py /tmp/u13-common-bot.jsonl
"$GODOT_BIN" --headless --path . --script Scripts/Sim/U13CommonSmartCoreTestRunner.gd -- /tmp/u13-common-bot.jsonl
"$GODOT_BIN" --headless --path . --script Scripts/Sim/U13PlayableSessionTestRunner.gd -- --fixtures-only
"$GODOT_BIN" --headless --path . --script Scripts/Sim/U13CommonPlayableSmokeTestRunner.gd
PYTHONPATH=Scripts/Sim python -m unittest u13_doctrine.test_common u13_doctrine.test_closing u13_doctrine.test_defensive_plans
```

The default contract exporter creates 23 cases without running combat. Add `--prior-smoke /path/to/completed-integration-trace.jsonl` to reuse an existing complete nine-Lord trace and include the eight natural midgame cases. No new balance campaign is needed.
