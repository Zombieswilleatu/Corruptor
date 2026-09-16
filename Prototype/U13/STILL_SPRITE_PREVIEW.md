# Still-frame motion across the sprite gallery

All 14 preview characters default to **Still + Godot motion**. The shared
character picker, domain background, plain background, guides, size and count
controls apply to both still and sheet modes. This changes presentation previews
only; full animated sprites remain the eventual goal.

## Sources and anchors

No new generated art. U13StillFrame extracts the first measured right/left walk
pose from each character's existing loaded sheet, preserving its crop, ground
anchor, body-height divisor, actual-resolution scaling, and polygon exclusions.
Near-black matte removal uses the same thresholds as U13VultureKey. This cleanup
runs once when selecting a character, not every draw. External sheet overrides
continue to work for these characters.

Penitent keeps the separately approved still. Butcher uses the first frame of
the bundled approved ButcherWalkV2, including its existing green key. These
single-facing sources mirror for left facing. Others use both authored facing
poses. If Butcher's external original sheet is absent, the still remains usable
and its unavailable sheet-comparison option is labeled and disabled.

## Motion choices

| Preview character | Treatment |
| --- | --- |
| Butcher | Heavy weight shift and short committed lunge |
| Penitent | Existing grounded breathing, restrained step and shield lunge |
| Vulture | Restrained shuffling and small casting/attack gesture |
| Wright | Grounded steps and tool-strike lean |
| Batboy | Small hovering motion and attack lunge; no wing deformation |
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

Turret form captures positions and swaps to the final pose in the existing
SoogeTurretForm sheet. It stays rooted across lane-cycle wraps, mode changes,
and still/sheet comparisons until Restart or a character change. Still-mode
March becomes idle when rooted. Attack is a stationary pulse rather than a
lunge. This version uses a form swap, not an interpolated transformation.

## Validation

Isolated Godot 4.5.1 headless checks exercise all 14 characters without external
art, all six modes, both source facings, sheet comparison where available, and
Sooge's persistent rooted form. Extracted poses were reviewed on a dark contact
sheet. Interactive motion review on the user's Godot 4.7.2 remains necessary;
headless checks cannot establish visual quality.
