# Dense-field visual check

Launch the regular U13 board with a repeatable 48-Marcher fixture:

```bash
bash Scripts/Sim/run_u13_board.sh "$u13_godot" --dense
```

Requires Godot 4.7.2 stable. This launcher does not run the foundation suite.
Without `--dense`, the board retains its normal opening and action modals.

## Two-minute check

1. Click **Run dense round**. Note any noticeable pause before movement begins.
2. Watch the Castle lane: the four chit types should move through real positions,
   steer into contact, join queued fights, and lose health on their rings.
   Queued Marchers waiting their turn are expected; fighting is sequential per lane.
3. Click **Next dense round** once the animation ends. Check that the next round
   works and the board remains responsive. **Restart** restores the same 48-unit
   opening; it does not add another wave. **Exit** closes the board normally.

Report any hitch during playback, frozen controls, overlapping unreadable chits,
missing health updates, or console script errors. This is a rendering and interaction
check; it does not produce balance data or replace deterministic runner coverage.

## Fixture and scope

- 24 per owner, six of each suit per owner, all in the Castle lane.
- Real keyed spawn placement runs before both groups are translated 900 fixed-point
  units toward the center. These are authoritative initial coordinates, not visual offsets.
- All units are movement-ready in round 1. HP, speed, armor, steering, contact queues,
  and damage use existing Marching rules without overrides.
- Both players pass combat and powers through normal owner submission. The fixture
  opponent does not add summons, so the initial tape contains exactly 48 Marchers.
- Match resolution remains synchronous. Playback uses the existing six-second preview
  duration; this change does not implement the proposed 15-second production schedule
  or spread simulation work across frames.

The existing U13Board runner also exercises dense launch controls, population,
damage playback, completion, and deterministic restart. Source grammar and shell
argument routing were checked here; Godot runtime and visual verification remain local.
