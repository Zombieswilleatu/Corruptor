# Castle damage visual diagnostic

The construction effect was visible in the user's board check, but Castle
fracturing was not apparent. This standalone scene makes that appearance directly
reviewable before changing the effect. It uses the existing `U13LayoutCard` and
`U13CastleArtwork`, including the board's parent/child modulation and 0.65-second
transition. The production renderer and game state are unchanged.

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
with the heavily damaged label at one-third or below. At 14/21 the collapse
distance is still zero and only small seams are present. Compare 4/21 or 1/21
against 21/21 when judging visibility.

If fixed references differ clearly but the board did not, check the Castle's
construction state and Integrity and whether source-art inspection was open.
If differences are visible enlarged but weak at board size, the artwork needs
a stronger visual treatment. If all three references look identical, report
the screenshot and console output so the actual rendering path can be fixed.

This is an optional, removable visual harness, not a new foundation gate. It
starts no simulation, background planning or marching playback. Workspace
validation covers GDScript grammar, dependency paths and launcher arguments;
Godot compilation and rendered appearance require the local visual run.
