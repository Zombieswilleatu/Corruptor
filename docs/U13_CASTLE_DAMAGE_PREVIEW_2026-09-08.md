# Castle damage visual diagnostic

The first preview confirmed that Castle fracturing rendered, but the user did
not like the effect. This revision uses 12 larger shards, more visible gaps,
dark cavities, cast shadows and lit fracture edges. Gravity, polygon contacts
and an invisible four-wall container determine the resting shapes. The same
`U13LayoutCard` / `U13CastleArtwork` renderer is used in the preview and board,
with a 1.1-second damage/repair transition. Game state is unchanged.

Run without any foundation tests:

```bash
git pull --ff-only origin u13-lord-overhaul &&
bash Scripts/Sim/run_u13_castle_preview.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
```

The enlarged card and an actual board-sized 124 × 180 card cycle every two
seconds from 21 to 1 Integrity and back through repairs. Fixed references show
21/21, 11/21 and 4/21 simultaneously. Choose any of the five Castle artworks;
pause, step or scrub Integrity manually. Space toggles cycling; Escape, Exit or
the window close button exits normally. Hold-to-inspect is disabled here because
that board feature shows the original, undamaged source art.

All preview cards are commissioned (`construction_state = active`); protected
construction would deliberately display progress instead of damage. The current
renderer stays intact above two-thirds Integrity and fragments below that,
with the heavily damaged label at one-third or below. At 14/21 the first cracks
are already visible; as Integrity falls the shards shrink slightly to widen
the cracks, tilt, and settle against the pieces below. Compare 4/21 or 1/21
against 21/21 when judging visibility. The numerical caption remains intact.

## Performance and reproducibility

This is baked physics, not live Godot rigid bodies. The standard-library tool
`Scripts/Tools/bake_u13_castle_fracture.py` solves gravity, weakening masonry
support, inelastic convex-polygon contacts and card bounds ahead of time.
It emits four shared damage poses plus the intact UV geometry into
`U13CastleFracture.gd`. No collision solver runs when opening the board or
taking damage. The renderer blends the saved positions and reverses the
transition for repairs, so these are not frame-by-frame live falling bodies.

Only changing Integrity redraws for animation; there is no per-frame process
or PhysicsServer allocation. Existing resize/draw invalidation still works.
All Castle types reuse the same geometry and their existing textures. There
are no generated image assets. The source artwork used by hold-to-inspect is
still unchanged, as is the protected-construction shader.

Regenerate with `python Scripts/Tools/bake_u13_castle_fracture.py` or verify with
`python Scripts/Tools/bake_u13_castle_fracture.py --check`. The tool checks finite
coordinates, containment, polygon contacts, downward settling, and interpolated
geometry for bounds, orientation and subpixel contact tolerance. Generation is
repeatable and the check rejects stale committed data. This is development
tooling; the game and visual launcher do not require Python.

If fixed references differ clearly but the board did not, check the Castle's
construction state and Integrity and whether source-art inspection was open.
If differences are visible enlarged but weak at board size, the artwork needs
a stronger visual treatment. If all three references look identical, report
the screenshot and console output so the actual rendering path can be fixed.

This is an optional, removable visual harness, not a new foundation gate. It
starts no simulation, background planning or marching playback. Workspace
validation covers GDScript grammar, dependency paths, baked geometry and launcher
arguments; Godot compilation, rendered appearance and GPU cost require the local
visual run. No new full-suite gate is required for trying this visual revision.
