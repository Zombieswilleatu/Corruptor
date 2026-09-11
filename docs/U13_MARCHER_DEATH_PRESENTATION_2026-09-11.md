# Shared Marcher death presentation — 2026-09-11

The supplied six-frame ghost atlas is used for Marcher removals across the U13
board, including combat, hazards, Wish Death, Price payments, lamp rejection,
Gravity and Kroni consumption. Detection uses stable identities and zero-HP or
removal transitions rather than a power-specific animation hook. Guard/card death
art and standalone Lord animation previews are separate from this board change.

A dying chit flashes for 0.15 seconds and then disappears. Its ghost plays once
for 0.48 seconds independently of that flashing, then disappears. The flash uses
the original chit texture's alpha rather than a solid white rectangle. Live
rendering excludes already-dying chits, so zero-HP frames cannot leave a second
copy behind. Ghost frames keep a shared canvas/bottom anchor from the source
sheet. Original PNG pixels are unchanged and loaded through U13BoardTextures,
without requiring editor import caches.

Normal Marching drains recorded death transitions through a cursor, preserving
casualties even when display frames skip simulation ticks. Board world/initial
playback updates cover removals outside Marching. Repeated updates are deduplicated
by stable ID; reset clears the effect and its identity history. Initial population
is not treated as death. Presentation never writes to the match state.

One shared atlas and a short-lived list are used, without per-death nodes/timers.
The atlas is warmed at board startup. The effects are drawn at the chit position
and clipped to the battlefield rail. This concerns chits visible in the board or
recorded in its Marching tape; it does not reconstruct units absent from both.

Validation: Marcher feedback suite and Kanifous board suite passed headlessly on
Godot 4.5.1, with explicit board compatibility-check. Tests cover removal/zero-HP
deduplication, ghost lifetime after the flash, cleanup, initial population,
source-atlas loading, caller isolation, and skipped-frame death-tape draining.
Windows 4.7.2 visual review is next.
