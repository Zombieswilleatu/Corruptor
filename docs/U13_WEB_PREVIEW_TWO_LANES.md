# Web preview follow-up

The preview now labels and displays Lord and Castle lanes side by side at the
same canonical scale (600 wide by 2400 long each). Clicking either lane chooses
the Web center. Large radii can visibly overlap both lanes for size comparison;
this does not change the gameplay rule restricting Web to its selected lane.

The blue dots are stationary reference Marchers. A visible legend identifies
them. Snare artwork is square and centered on each middle Guard card, independent
of unused panel width. Both Guard rows retain three card references.

The six-frame spider rotates to follow its projected travel direction. Rotated
sprite geometry is clipped with corresponding texture coordinates. Existing
artwork, gameplay radius, damage, slow, lifetime and replay rules are unchanged.

Verification: source delimiter checks and layout/scale calculations at 1024x768,
1280x800 and 1920x1080. Godot execution and visual approval remain local checks.
Open the existing Orias Web & Snare animation preview; try both lanes, a radius
above 600, Snare toggling, and a full spider loop. The existing standalone command
is `bash Scripts/Sim/run_u13_web_preview.sh "$GODOT_U13"`.
