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

## Wish Death impact

The supplied Kanifous skull now plays for 0.8 seconds: the target circle pulses
dark, the skull appears at 125% scale and settles, purple smoke glows, then the
eyes and mouth flash once. At 0.46 seconds the circle collapses inward and the
victims begin the shared chit flash and ghost animation. The skull fades quickly.

Wish resolution records immutable victim pictures. The board holds those chits
only for presentation until impact, with the Marching playback clock paused.
The effect never applies damage or changes saved state. Multiple wishes queue;
a long frame drains impacts once each. Skip and reset cancel pending skulls.
Gem Dagger remains Gremory's separate effect.

The focused Kanifous wrapper now includes both Marcher feedback suites (seven
suites total). Local validation uses Godot 4.5.1 with the existing explicit
headless compatibility flag; the normal wrapper still requires 4.7.2. The board
test exercises the real process method for the pause/impact boundary, slow-frame
queue draining, skip cleanup and unchanged authoritative state. The feedback
board runner now verifies a match actually started before comparing checkpoints.
