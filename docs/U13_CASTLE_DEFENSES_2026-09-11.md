# U13 game Castle defenses: Keep and Bastion

`run_u13_game.sh` now expects **6/6**. This checkpoint enables defensive Castle
powers in the game-conductor profile. Existing exercise-board profiles remain
unchanged. Stockpile selection is the next Castle subsystem, not part of this commit.

## Rules and source reconciliation

References: UI2 `CastlePowerText`, `CastleIntegrityRules.keep_interposes` /
`keep_fortification`, `HuntResolutionEngine`, and `SiegeResolutionEngine`.
The current U13 Lord rules and Castle destruction semantics take precedence over
obsolete U12 Lord callbacks.

- Keep receives remaining Hunt strength after Ward, Valak reinforcement, Lord
  Guards, and Sigil, before the Lord DEF comparison.
- An operational Keep removes up to 3 strength. A damaged Keep below the
  operational floor still absorbs using its Integrity, without the reduction.
- Equality destroys the Keep with zero overflow. Only excess reaches Lord DEF;
  defense is recomputed after ruination (especially important for Humbaba).
- Keep destruction during Hunt grants no base Siege Souls or Castle-destruction
  neutral Tear. It does deliver current U13 destruction callbacks, including
  Sifting and attributed Spoils. Lord banishment, if overflow causes it, retains
  its own existing rewards.
- A Bastion screens a Siege aimed at another Castle after Castle Ward, Guards,
  and Sigil. Overflow continues to the originally selected Castle.
- A Siege directly targeting any Bastion uses no other Bastion and spills nowhere.
- Breaking the wall and rear Castle runs the existing U13 ruination/reward chain
  in that physical order. Base Castle neutral Tears retain the current round cap;
  Lord passives retain their own attribution and caps.
- A Defunct screen absorbs zero Integrity; positive incoming strength ruins it
  under current U13 rules. This intentionally follows the newer U13 transition
  contract rather than the legacy Siege code's positive-before-Integrity check.
- Protected construction, Ruined and Profaned structures never screen.
- Artillery is direct damage and bypasses both defenses.

## Duplicate policy

One physical screen applies per attack: the lowest eligible Castle slot of that
printed type. Copies do not stack reductions or chain screens during one attack.
A surviving copy becomes eligible for the next attack after the first is Ruined.
This follows the existing stable-slot, non-stacking Summoning Circle convention.
The selection rule is explicit so it can be reviewed without hidden array-order
or random targeting behavior.

## Implementation

`U13CastleDefenses` selects screens and computes Keep absorption. `U13Combat`
inserts it at the two structural layers, retaining the current damage/reaction
path. Siege damage and reward handling is factored into `_siege_castle` so the
Bastion and target cannot diverge into separate rule implementations.

The game opening installs `U13_CASTLE_DEFENSES_V1`; game content validates and
projects the profile and includes it in save-policy identity. Earlier game
checkpoints require a new match rather than silently acquiring changed rules.
Unprofiled U13 subsystem tests continue using their existing behavior.

## Verification

Directed cases cover operational and low-Integrity Keeps, exact depletion,
overflow, Defunct/protected/Ruined/Profaned screens, wall/target reward accounting,
duplicate slot selection, direct Bastion targeting, layered Ward/Guard/Sigil
ordering, artillery bypass, current Sifting callbacks, and Humbaba DEF after Keep
loss. A sealed Siege is restored immediately before combat and replays through
the remaining Lord and Marching hooks to an identical snapshot.

Existing Hunt and Deimos suites are also run because the shared combat path was
refactored. Game Development and Random-Legal replay checks cover the new profile
with actual constructed Castles. Local runtime is Godot 4.5.1 compatibility;
Windows 4.7.2 remains the user-facing verification gate.
