# Sooge animation preview

Select Sooge in the shared sprite preview. Both approved sheets are bundled unchanged.
External `Sooge.png` / `sooge.png` and `SoogeTurretForm.png` / `soogeturretform.png`
in the source sprite folder or its Monsters subfolder take precedence when found.
The existing Penitent runner can open the preview and discover these siblings.

Attack 1 is the mobile tentacle swipe. Attack 2 is the six-frame permanent turret
transformation: the inspector plays it once at 8 FPS and holds its final frame.
The Turret form button returns to the live lane, captures unit positions, plays
that transformation once, and keeps units rooted. Restart restores mobile units;
changing characters also resets the transformation. Inspecting other animations
is available independently and does not undo the live lane's rooted state.

This is presentation only. The supplied second sheet is the transformation, not
a separate laser-firing animation. No combat rules are implemented here. The
existing death inspector still uses the supplied mobile death frames.

Crops use measured row bounds and inter-frame gaps, with one body scale per
sheet. Black backgrounds use the existing Vulture key shader. Interactive crop
and alignment review in the user's Godot 4.7.2 remains necessary.

Validated with isolated Godot 4.6 headless playback: both textures, all frames,
one-shot final-frame hold, frozen lane positions, and switching away/back.
