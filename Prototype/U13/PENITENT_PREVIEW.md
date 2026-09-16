# Penitent preview

## Still image trial (September 16, 2026)

The Penitent now defaults to **Still + Godot motion** in the existing sprite
preview, including the shared Subjects & Monsters gallery. **Sprite sheet**
restores the prior V3 sheet and its frame inspector. Other characters retain
their existing previews.

`Assets/PenitentStill.png` derives from the supplied bowed, wounded Penitent
reference (`fd4f667e-22c1-42d0-baa5-9b6a1c7cdb67.png`). Python removed its white
background and enclosed white gaps, cropped the transparent bounds, and resized
with nearest-neighbor sampling to 384 pixels tall. No generative redraw.
The ground anchor is 43% across the image, at its bottom edge.

`U13StillSpriteMotion.gd` provides purely cosmetic GDScript drawing transforms:

- Lane cycle: march toward contact, one staggered attack, then idle and reset.
- Idle: nearly imperceptible breathing, feet fixed.
- March: small weight shift, no elastic squash.
- Attack: anticipation, quick lunge, tiny impact tick, recovery.
- Hit: short brightening and recoil.
- Death: restrained lean, sink and fade. This is not a drawn collapse pose.

Use Still motion to inspect each effect. Attack/Hit repeat every 1.8 seconds;
Death repeats every 2.4 seconds. Replay motion restarts that demonstration.
Pause freezes all timing. Try lane death keeps the existing captured positions.
The sprite-size slider and 1/24/48-unit choices also apply. Inspect at 75px for
board readability and enlarge for checking edges. The front-three-quarter
pose is mirrored for facing; it does not acquire a true side-view walk cycle.
Full sprite animation remains the eventual goal; this is a beta experiment.

The standalone runner now works with only the Godot executable argument;
it falls back to the bundled V3 comparison sheet if no external sheet exists.
An optional second argument still loads an external comparison sheet.

Validation: isolated Godot 4.5.1 import and headless exercise of all still modes,
pause, Penitent -> Sooge -> Penitent cycling, and V3 inspection rows passed.
The PNG was composited over a dark background for alpha-edge inspection.
Interactive visual approval on the user's Godot 4.7.2 remains pending.
Existing sheet loading uses Image.load_from_file and retains its export warning;
the new still prefers an imported Texture2D resource, with direct PNG loading
as a fallback for a fresh checkout launched without an editor import. Its
selector remains visible with a load-error message if the asset is unavailable.
The no-import startup regression was reproduced and the fallback checked with
the PNG import sidecar absent.

No combat, authoritative movement, balance, PySim, or playable unit art changed.

## Earlier assets

The prior V3 sheet and measured crops remain in U13PenitentLanePreview.gd:
left/right walk, celebrate (third source row), shield attack (fourth), and death.
The older PenitentWalkV2.png six-frame replacement and its key shader also remain
in the repository for historical reference; they are not the current default.
