# Breath of Life: supplied art and next board pass

User request, recorded alongside Kalligan's rules slice. Implemented in the
following board pass; see `U13_KALLIGAN_BOARD_2026-09-08.md` for commands and
validation status. The authoritative Breath lifetime and aura are preserved.

## Assets

User's original checkout contains
`ConceptImages/Sprites/BreathOfLife/Flower1.png` through `Flower4.png`, plus a
healing-effect texture. These were initially local-only; the user subsequently
pushed all five to `main` in `e357b4a`. This board pass imports the exact five
asset blobs to U13, including `HealEffect.png`.

The uploaded Flower example is 1536 x 1024 RGBA: three columns by two rows of
512 x 512 cells. Read left-to-right, then top-to-bottom. It is a reference for
the following sequence. All four supplied flowers and `HealEffect.png` have
the same six-frame atlas layout. The healing effect loops all six cells.

## Visual lifecycle

1. Flowers sprout at varied random positions inside the healing area, choosing
   among the supplied four flower variants.
2. Play frames 1 through 4 once. Hold the mature frame 4 while Breath is active.
3. When the authoritative Breath instance expires, start its visual cleanup
   interval. Assign each flower a staggered death trigger within ten seconds.
4. On its trigger, play frames 5 and 6 once, then remove the flower. This is a
   post-expiration visual tail; it does not extend healing or movement bonuses.

The healing-effect texture tiles horizontally and scrolls across the affected
lane in a loop with a semitransparent pulse while Breath is active. Stop the
active healing layer on expiry while the flowers finish dying.

## Implementation constraints

- Read the persistent aura's stable instance ID and authoritative lifetime.
  Do not reset growth when the board refreshes or on every playback sample.
- Keep cosmetic variation independent of simulation RNG decisions, ideally
  stable per effect/flower so refreshes do not rearrange the area.
- Clip flowers and the healing strip to their intended lane/area. Preserve
  Marcher visibility, health rings, target input and selected-target flashes.
- Use cached sprite-sheet regions and a bounded shared animation update.
  No per-flower physics, threaded scene-tree mutation or texture reloads.
- Restart/skip/restore must clean up obsolete effects. Separate a retiring
  flower group from a newly activated Breath instance if their visuals overlap.
- Verify growth/hold/expiry, the ten-second stagger, clipping and responsiveness
  in a temporary visual preview or a focused board scenario once assets arrive.
