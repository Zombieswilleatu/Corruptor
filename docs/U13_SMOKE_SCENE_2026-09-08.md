# U13 Gremory smoke scene

## Checkpoint and scope

The user verified `U13 foundation runners passed: 11/11` on Godot 4.7.2 at
`b1b3e60f2e0874555b802f2c9e57db9c8d41953a`; documentation checkpoint `2a25e97`
records that result. This batch adds an explicitly launched smoke scene over that
owner. Its new **12/12 runtime and visual gate is pending**.

The scene is a small inspection tool: Gremory mirrors with the existing basic
Siege/Ward, Guard, flat-Sigil, plain-Integrity and Marching profile. It does not add
a full ordinary-action selector, complete Development, named Castle powers,
construction, resummoning, victory, or a general opponent doctrine. U12's scenes,
controller, project main-scene setting and rules are untouched.

The user's [Random-Legal Doctrine Tier addendum](U13_RANDOM_LEGAL_ADDENDUM_2026-09-08.md)
is accepted and stored alongside this work. It becomes a per-power requirement,
including Gremory; its chooser and frequency instrumentation are the next task
after this scene's local gate. Preset smoke scenarios are not random-legal batches
or evidence for balance/frequency tuning.

## Open it

From the U13 checkout in Git Bash:

```bash
git pull --ff-only origin u13-lord-overhaul &&
bash Scripts/Sim/run_u13_smoke.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
```

Or open `Prototype/U13/U13Smoke.tscn` in Godot 4.7.2 and press **F6** (Run Current
Scene). F5 still launches the existing project main scene. The standalone launcher
uses the compatibility renderer and a 1440 × 960 window; it does not edit
`project.godot`. The scene itself checks the U13 runtime version.

## Quick tour

1. Start with **Predator clash**, optionally choose Lord or Castle lane, then press
   **Run to Marching**. Both players declare three Vultures. They move, meet, exchange
   attacks and die. Each Gremory receives Bones once.
2. Use **Pause**, the time slider, **0.5x / 1x / 2x**, or **Replay battle** to inspect
   captured HP/Armor changes. **Show result** skips the animation. These controls
   do not execute combat again or award extra cards/Tears.
3. Press **Next phase** twice to finish End-of-Marching Checks and Aftermath, then
   **Next round**. Odd rounds declare Predators; even rounds respect cooldown.
4. Switch to **Siege & spoils**. Your two Butcher 3s produce an actual Siege against
   two Guards and a damaged Castle. Gem Dagger, Sifting, ordinary Siege rewards
   and later Bones appear in the event panel. Commitment Marchers retain their
   birth hold while Lord spawns move this round.
5. Switch to **Prepared Ruin**. Round 1 discards the first two cards to mark the
   enemy Castle and summons Predators. Finish the round and choose **Next round**:
   the marked Castle becomes Defunct before planning. It is not a destruction and
   must not award a Castle Tear or Sifting reward. In round 2 the unopposed Vultures
   reach the gate and become waiters.

**Lock plans / Next phase** advances one owner hook. **Run to Marching** locks the
preset plans and stops after the Marching hook so its animation can play before
Aftermath. The next-round button stays disabled until the round actually ends.
Switching scenarios or restarting cancels playback and resets the scenario.

**Save checkpoint / Restore** stores one in-memory checkpoint, including the owner
snapshot and scenario settings. Restarting/changing scenario clears it. Closing
the scene discards it; this is not the game's persistent save UI.

## Data and rendering boundaries

`U13SmokeSession.gd` owns a normal `Gremory.create_combat_match()`. It constructs a
fixed setup and scenario recipes, then uses the existing preview, submit, hook and
snapshot APIs. It does not inject kill/damage/defeat commands, mutate accepted match
state, bypass costs or call gameplay from frame callbacks. Its explicitly scripted
opponent is a scenario recipe, not a substitute for random-legal or real doctrine.

The scene renders `player_view(0)`. Opponent hand identities, deck order and match
seed are not rendered. Gremory's projector adds a two-entry public Souls array so
the viewer can show ordinary Siege rewards without reading an authoritative save
or reconstructing reward rules. Unknown resource fields remain outside that
projection. The in-memory checkpoint is kept in the session/controller and never
shown in the player view or event panel.

`U13SmokePlayback.gd` builds visual frames from public `MARCHING_STARTED`,
`MARCHER_CLASH`, `MARCHER_WAITING` and `MARCHING_FINISHED` events. It interpolates
movement, pauses for the recorded exchanges, and finishes at the exact recorded
end units. Fractional render positions use `visual_x`, never the simulation's
`x_fp`. The renderer is not a second combat engine. HP, Armor, deaths and rewards
come from the owner. Scrubbing and playback frame rate cannot alter match state.

The board displays suit initials, player-colored outlines, HP bars, and clash
highlights. The scrollable Marcher list gives HP, Armor, lane and position. `H`
above a token means its commitment birth hold; `W` above it means waiter. Visual
stack offsets only separate overlapping tokens; they do not change collision
positions. Current match state and the last battle replay remain separate: replay
captions identify the round being shown.

## Verification

Added `U13SmokeTestRunner.gd`, bringing the wrapper to **12 suites**, plus direct
preflight for the session and UI scripts. Tests cover:

- All three recipes through actual combat and subsequent rounds;
- Predator lane choice, cooldown-respecting plans, Gem/Sifting/Bones and public Souls;
- Prepared Ruin firing before the next planning window;
- Exact checkpoint replay and atomic rejection of a bad version;
- Tape endpoints and mid-travel interpolation;
- Sampling at 30/60/144 FPS without changing match state or source events;
- Loading the actual `.tscn`, running its controls, pausing/scrubbing/replaying,
  checkpoint restore and scenario restart during animation.

Static GDScript parse/lint and shell syntax/orchestration checks are performed in
the coding environment. **Godot is unavailable here**, so this does not claim
runtime or rendered visual verification. The user's local checks are the gate:

```bash
bash Scripts/Sim/run_u13_foundation_tests.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
```

Expected final line: `U13 foundation runners passed: 12/12`.
Then open the scene and confirm the controls fit, both players' tokens are visible,
replay pauses/scrubs correctly, and rewards appear once. Report any runtime error
or clipped/overlapping controls before progressing to random-legal batches.
