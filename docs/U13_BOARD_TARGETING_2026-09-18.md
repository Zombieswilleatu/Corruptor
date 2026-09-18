# Direct board targeting

All player-selected spatial targets use the actual game board. Power choice,
payment, and Essence spending remain in their existing controls.

| Lord | Target selection |
| --- | --- |
| Gremory | Predator: marching lane. Ruin: two hand cards, then an eligible enemy Castle. |
| Deimos | Rout: marching lane. War Machine: own Siege Engine card; the sole eligible engine remains automatic. |
| Humbaba | Muster and Breath: marching lane. |
| Kalligan | Inferno: marching lane or enemy Guard zone. Pyroclasm retains its automatic targeting. |
| Orias | Web: click and drag on the actual marching lanes, then Set the Snare. |
| Odradek | Redirect and Allegiance Shift: actual lane area. False Orders: Guard card. Inversion: actual Guard zone and confirmation. |
| Kroni | Consume: enemy Guard card. Ravenous: starting position on the actual lane. |
| Valak | Projection: enemy Guard zone after choosing Essence spend. Gravity Orb: actual lane area. |
| Kanifous | Power and Resurrection: marching lane. Longevity: eligible own Castle. Death: actual lane area. Applies equally to Breach Wishes, including access while banished. |

Orias's Web no longer draws a separate opaque battlefield. All area selectors
share the canvas-aware conversion from the live battlefield rectangles to
their overlay coordinates. The full game's phase modal stays hidden during
targeting, including after refresh. Target instructions and cancellation remain
available; cancellation neither queues a new order nor spends its resources.
Odradek's duplicate Guard-zone choice buttons and Valak/Kanifous's spatial
target dropdowns have been removed.

## Validation

The focused `Scripts/Sim/U13BoardTargetingTestRunner.gd` exercises the full
Action Flow board: live lane geometry for every area selector, Web placement
and cancellation, actual Guard-slot and Castle-card clicks, rejected targets,
normal/Breach Wish declarations, Inversion validation/cancellation, and Ruin's
hand payment. Playable-board, Valak, Kanifous, and Breach Wish UI suites also
passed: 169 checks in total.

These are Linux Godot 4.5.1 diagnostic runs. The production Godot 4.7.2 gate is
unchanged, and Windows visual confirmation remains. An additional Action Flow
runner exited without its final completion marker after 27 passing checks;
it is recorded separately and not counted as a completed suite. See
`docs/evidence/U13_BOARD_TARGETING_2026-09-18.json`.
