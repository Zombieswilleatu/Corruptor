# Still-frame motion across the sprite gallery

All 14 preview characters default to **Still + Godot motion**. The shared
character picker, domain background, plain background, guides, size and count
controls apply to both still and sheet modes. The live marching lanes now share
these poses and motion through `U13MarcherSpriteCatalog` and
`U13MarcherSpriteVisuals`; see [MARCHER_SPRITES.md](MARCHER_SPRITES.md) for the
rendering hooks. Full animated sprites remain the eventual goal.

## Sources and anchors

No new generated art. U13StillFrame extracts the first measured right/left walk
pose from each character's existing loaded sheet, preserving its crop, ground
anchor, body-height divisor, actual-resolution scaling, and polygon exclusions.
Near-black matte removal uses the same thresholds as U13VultureKey. This cleanup
runs once when selecting a character, not every draw. External sheet overrides
continue to work for these characters.

Penitent keeps the separately approved still. Sinodek uses the approved pixel
still with real transparency, bundled unchanged as `Assets/SinodekStill.png`
(1586 × 992). Its body ground anchor is (1088, 884), with a 777 px body-height
divisor; transparent padding and its trailing cloak do not shift the anchor.
These values are normalized to the texture resolution. Its original sprite
sheet remains available for comparison.

Butcher uses the first frame of the bundled approved ButcherWalkV2, including
its existing green key. These single-facing sources mirror for left facing.
Others use both authored facing poses. If Butcher's external original sheet is
absent, the still remains usable and its unavailable sheet-comparison option
is labeled and disabled.

## Motion choices

| Preview character | Treatment |
| --- | --- |
| Butcher | Heavy weight shift and short committed lunge |
| Penitent | Existing grounded breathing, restrained step and shield lunge |
| Vulture | Restrained shuffling and small casting/attack gesture |
| Wright | Grounded steps and tool-strike lean |
| Batboy | Fast grounded skitter and attack lunge; no floating |
| BottleTree | Heavy, almost stationary weight shift |
| Dogger | Quicker scuttling rhythm and stronger lunge |
| Kopita | Restrained shuffling and casting gesture |
| Lemek | Heavy dragging weight shift and short strike |
| Pixie | Small hovering motion and restrained casting gesture |
| Ratton | Fast, low scuttling rhythm and lunge |
| Sinodek | Slow gliding drift, small cast gesture, upright dissolution |
| Wraith | Slow spectral drift, small cast gesture, upright dissolution |
| Sooge | Small flesh pulse; fixed turret position after transformation |

Idle, March, Attack, Hit and Death are selectable demonstrations. Lane cycle
moves to contact, attacks once and resets. Pause freezes timing. These are
whole-image transforms and feedback, not separate articulated limbs or full
walk cycles. Impact marks are generic presentation cues, not ability simulations.

## Sooge

**Transform to turret** captures positions and plays all six measured frames
from the existing SoogeTurretForm sheet once at 8 FPS, including in Still +
Godot motion mode. Frames are extracted and keyed once on character selection,
using their existing ground anchors and shared body scale. The authored
transformation plays without an extra procedural lunge or pulse on top.

The final frame then becomes the permanent turret still. Sooge stays rooted
across lane-cycle wraps, motion changes, and still/sheet comparisons until
Restart or a character change. Pause holds the transformation. Still-mode
March becomes idle when rooted; Attack produces a stationary pulse.

## Validation

Isolated Godot 4.5.1 headless checks exercise all 14 characters without external
art, all six modes, both source facings, sheet comparison where available, and
Sooge's complete transformation, pause, persistent rooted form and reset. They
also check Batboy's grounded motion and Sinodek's full-size transparent source
and anchor. Extracted poses were reviewed on a dark contact sheet. Interactive
motion review on the user's Godot 4.7.2 remains necessary; headless checks cannot
establish visual quality.
