# Humbaba playable board and Castle artwork

The user accepted the Humbaba rules gate at `52ad37c` on Godot 4.7.2: 10/10.
This slice connects those rules to the existing U13 board and handles the deferred
construction/damage presentation. Kalligan remains the next Lord after this gate.

## Playable controls

Humbaba is available on either side of the existing Lord/Castle picker, including
a Humbaba mirror. The usual five slots, maximum two copies of a type, shared
Castle Guard zone and beginner Keep suggestion remain. Quick start still provides
slot 1 active at 12, slot 2 protected at 7, and three unbuilt choices. This does
not establish a production starting economy.

Loadout sessions select the verified Humbaba owner whenever either side uses
Humbaba. Its loadout builder reuses the shared Castle setup, then installs the
Humbaba profile and absent Threat stat. Gremory/Deimos-only loadouts retain their
existing owner. Worker forks and JSON checkpoints preserve the chosen roster,
Castle identities, Hunt policy, active auras and cooldowns. Opponent planning uses
the matching centralized candidate provider; no UI rules copy is introduced.

The existing Lord-powers prompt now provides:

- **Muster the Faithful:** click the power, then the Lord or Castle lane. Three
  Penitents spawn and march this round. Free; one blocked cooldown round.
- **Breath of Life:** click the power, then a lane. Friendly bodies receive +25%
  movement this round and next, plus +1 regeneration at the next round's Step 3.
  Free; two active rounds followed by two blocked cooldown rounds.

Targets pulse on selection and the selected lane pulses again after choosing it.
The modal stays open, dropdowns stay hidden in direct mode, queued powers cannot
be duplicated, and committed combat cards remain locked during power selection.
Both powers can be staged together without advancing the authoritative state.

Breath's lane indicator uses the published persistent record and displays its
owner and remaining active rounds, including during recorded Marching playback.
The modal distinguishes active Breath from cooldown and shows ready-round counts.
The Lord card shows Humbaba's live Defense and “NO THREAT”; its tooltip describes
Woven Into the Stones, Endurance and The Stones Forget. Original Humbaba art and
Penitent chits/health rings are reused.

## Castle art audit and implementation

U12 `CastleSpine.gd` already applies
`Prototype/UI2/Shaders/CastleConstructionProgress.gdshader`: the image fills upward
with an uneven masonry boundary while the unfinished region remains a faint
architectural outline. U13 reuses that shader unchanged, feeding current
Integrity divided by current maximum for protected construction.

Commission switches the image to damage presentation at its actual Integrity.
The original texture is drawn as 18 cached triangular fragments; they progressively
move inward/downward and rotate slightly as Integrity falls. The bands are intact
above two-thirds, fractured above one-third through two-thirds, and heavily damaged
at one-third or below. Exact category boundaries use integer comparisons; visual
collapse interpolates between states. Repairs restore the image correspondingly.
The maximum is read from the same entity as the numerical Integrity caption.

Only changed ratios animate, for 0.65 seconds. No physics, random choices,
generated textures or simulation mutations are involved. The renderer ignores
input; existing target buttons, Commission, hold-to-inspect source artwork,
readable captions and Guard/card outlines remain. A new match resets visual
history. The implementation uses Godot's standard [CanvasItem drawing and
self-modulation behavior](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html).

## Verification

Two new processes keep work out of the already bounded legacy board runners:

1. `U13HumbabaBoardSession`: selectable human/opponent/mirror loadouts, absent
   Threat on each Humbaba, worker forks, JSON restoration, independent mirror
   auras, opponent legal planning and atomic rejection of invalid setup.
2. `U13HumbabaBoard`: actual scene/picker, direct power/lane interaction, committed
   card locking, duplicate prevention, sparse worker playback, aura/clock display
   next round, and construction/Commission/damage presentation bindings.

The default per-process timeout remains 30 seconds. `--board` expects **8/8**;
full foundation expects **32/32**; the accepted `--humbaba` rules gate stays **10/10**.
Workspace validation is grammar/static review and stub-engine wrapper checks,
not Godot compilation, gameplay execution or a rendered screenshot review.

```bash
git pull --ff-only origin u13-lord-overhaul &&
bash Scripts/Sim/run_u13_foundation_tests.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe" \
  --board
```

Then launch without rerunning the tests:

```bash
bash Scripts/Sim/run_u13_board.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
```

Choose Humbaba and Quick start. Skip combat once to try both powers in the same
lane; confirm three Penitents and a Breath indicator, then inspect next round's
cooldowns. Slot 2 starts protected at 7/21: it should show construction progress;
Commission should switch it to heavy damage while preserving its caption and
click target. Construct or Repair a copy to inspect the upward reveal/recovery.
The final appearance and responsiveness still require this local visual pass.
