# Kalligan board and Breath of Life art

The user reported the Kalligan rules gate green on Godot 4.7.2 after commit
`12b9652`. This pass connects that accepted content to the existing U13 board.

## Board behavior

- Kalligan is selectable on either side, including mirrors and Kalligan/Humbaba.
  Existing Castle loadouts, shared Guards, Hunt, worker forks and checkpoint
  restoration use the correct composed content owner.
- In the separate powers prompt, choose **Inferno**, then click an enemy Lord
  Guard slot/area, an enemy shared Castle Guard slot/area, or either Marching
  lane. Valid areas pulse; the chosen target flashes again. Enemy Castle cards
  themselves are not Inferno targets: this targets their shared Guard zone.
- The prompt stays open. Main board targeting uses clicks, with no target
  dropdown. Combat/development commitments remain locked during powers.
- Inferno's readiness uses an authoritative whole-plan preview. An existing
  expiration clock does not incorrectly disable relocation. The last active
  round correctly disables preparing a move into expiration.
- **Pyroclasm** queues one extra pulse at the current Scorch. There is no second
  target to choose. Its selected-target flash uses the current location even
  when a future Inferno relocation is queued elsewhere.
- Repeated button clicks cannot double-queue either power. Neither selecting a
  power nor changing prompts advances state or consumes a cooldown.
- The prompt reports intensity, remaining active rounds, location, queued
  next-round target and cooldown. Lane tint and Guard headings show active fire;
  prepared fire is visibly marked for its firing round. All values come from
  the public persistent/pending registries, not a separate gameplay timer.

The existing U12-style layout, card outlines, committed stacks, Castle fracture,
construction meter, artillery and responsive worker/playback remain in place.
Scorch is currently a readable tint/badge presentation; bespoke fire sprites
are not part of this pass.

## Breath of Life sprites

The five original assets were supplied on `main` in `e357b4a` and copied into
this branch by their exact Git blob identities. No unrelated main-branch code
is merged. All five are 1536 x 1024 RGBA, a 3-by-2 atlas of 512-pixel cells.

`U13BreathVisuals` is shared by the board and the standalone preview:

- Four flower variants, fourteen scattered flowers per active instance.
- Growth frames 1–4 play once, then frame 4 holds while Breath is active.
- On authoritative expiry the healing sweep stops immediately. Each flower's
  death trigger is staggered through the following ten seconds; it plays frames
  5 and 6, with a short terminal fade, and disappears by the window's end.
- HealEffect loops all six frames, tiles across the lane width and pulses at
  low opacity while sweeping along the lane. On the vertical U13 board it moves
  upward for the human aura and downward for the enemy aura.
- Both layers are clipped to their lane and drawn beneath Marcher chits, health
  rings and targeting highlights. Cosmetic positions derive from effect/flower
  identity; no simulation RNG stream or physics bodies are involved.
- Textures are cached, warmed one per frame during initial setup and shared by
  all flowers. Original RGBA pixel storage is about 30 MiB for the five atlases;
  actual engine/GPU residency still needs local observation. There are no image
  reloads per flower, frame or round.
- Refreshes preserve the group and growth age. Restart clears it. Retiring and
  newly active instances remain separate. Rapid round skipping retains at most
  six visual groups, dropping the oldest retired tail if necessary.

The effect's real-time visual tail does not extend regeneration or movement.

## Focused local gate

```bash
git pull --ff-only origin u13-lord-overhaul &&
bash Scripts/Sim/run_u13_foundation_tests.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe" \
  --kalligan-board
```

Expected: `U13 Kalligan-board runners passed: 3/3`.

The session runner covers mixed/mirror loadouts, JSON, worker policy, shared
readiness and independent public Scorch records. The scene runner exercises
actual signal wiring, both target kinds, commitment locking, repeat clicks,
worker publication, next-round activation and Pyroclasm versus a future move.
It uses an empty Marching field to keep presentation testing bounded. The
visual-state runner checks growth/hold/death timing, cleanup, identity isolation
and all five atlas resources without waiting ten real seconds.

Every runner retains the 30-second cap, required footer, error-log rejection and
stop-on-first-failure. Full foundation: 39 runners. `--board`: 11 runners.
`--kalligan` remains the previously accepted 10-run rules gate.

Authoring checks cover GDScript grammar, preload arity, shell syntax and stub
wrapper selection/failure handling. The asset byte hashes and image dimensions
were checked against main. No Godot executable is available in the authoring
workspace, so actual compilation, rendering and runtime timing remain local
verification requirements.

## Visual preview without a match

```bash
bash Scripts/Sim/run_u13_breath_preview.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
```

Auto cycles eight seconds active, then a ten-second staggered death window.
Disable Auto to leave the flowers mature; **Expire now** starts their death
sequence. **Restart / sprout** retains the same layout; **New flower
arrangement** changes it. This uses the actual board renderer at larger scale.

For the game board, use the existing `run_u13_board.sh` command. Choose Kalligan
to test Inferno/Pyroclasm, or Humbaba to see Breath during play. Visual review
should confirm the flowers remain legible but do not obscure combat, that the
sweep is appropriately translucent, and that frame timing stays responsive.
