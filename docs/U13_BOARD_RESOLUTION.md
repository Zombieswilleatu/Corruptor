# Main-board resolution, first pass

Sieges and Hunts now play on the main board before marching playback. Committed
cards travel as a single group, followed by applicable Ward, Guards, broken Sigil,
Bastion/Keep interception, and the recorded outcome. Castle Integrity counts down
through intermediate values, and the castle artwork receives those same values.
Surviving Guards return to their slots; defeated Guards disappear. This pass does
not add a popup or marching highlights.

Timing: advance 0.95s, Ward 0.65s, Guards 0.8s, broken Sigil 0.35s,
each interceptor 1.1s, final impact 1.0s. A simple attack takes 1.95s;
a fully defended attack takes up to 4.85s. Both players use the same presentation.

## Authority and integration

U13BoardSession captures the public player view immediately before combat and
public events through the combat hook. U13ResolutionTape consumes revealed cards
and actual result/interception events. No attack calculations, RNG draws, match
commands, or hidden-hand lookups run in presentation. Snapshots are transient and
not part of saves. Existing saves and battle rules are unchanged.

Artillery plays first. Combat holds the board's pre-combat state until its impacts;
the completed public view is then installed before Gem Dagger and subsequent Lord
visual effects and marching. Gem Dagger rewards retain their existing delay but no
longer restore Guards whose defeat the theater has already shown. Other reaction
consequences are reconciled in the completed view; they do not each get a separate
animation in this first pass. The Void keeps numeric labels and subject values
concealed.

Skip restores hidden source cards, disposes of copies, installs the completed
view, and continues through normal Aftermath. Restart and load clear the tape.
The existing PAUSE availability is unchanged.

## Verification

Run with the same Godot executable used by the game, from the repository root:

```bash
"$u13_godot" --headless --path . --script Scripts/Sim/U13ResolutionTheaterTestRunner.gd
"$u13_godot" --headless --path . --script Scripts/Sim/U13PlayableBoardTestRunner.gd
"$u13_godot" --headless --path . --script Scripts/Sim/U13GemDaggerTestRunner.gd
```

Focused coverage: event order, grouped attackers, intermediate 17→3 Integrity,
Guard death, ruined interception, zero-damage Keep absorption, cleanup during each
beat, unchanged public inputs and authoritative state, and real session capture.
Playable-board coverage includes a real Hunt, holding marching at time zero,
completion/handoff, Skip/Aftermath and the final victory ledger. The victory test
fixture now uses the current Dominion threshold instead of assuming five Tears.

Local checks use the available diagnostic Godot 4.5.1 runtime. The production
launcher and game continue to require Godot 4.7.2 stable.
