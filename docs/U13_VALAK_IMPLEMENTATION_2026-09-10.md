# Valak — U13 gameplay integration

Valak is selectable in the main U13 board alongside the seven existing Lords.
U12 and the project's default scene are unchanged.

## Rules

- **Life Essence:** each enemy Guard defeated by Valak's Hunt or Siege grants
  two Essence, capped at five. After normal Ward screening, unreserved Essence
  absorbs incoming Hunt strength before the Lord Guard/Sigil/Defense sequence.
  Other Guard destruction and Projection kills grant no Essence.
- **Projection:** select the enemy Lord or Castle **guard zone** and spend 1–5
  already-owned Essence during submission. The selected amount is reserved at
  lock, still counts toward the five-charge capacity, and cannot also screen a
  Hunt. New combat gains cannot enlarge the shot. At Step 10F, spend the reserve
  and defeat the highest printed-value Guard at or below that amount. Equal
  values are resolved by slot, then stable ID. An empty zone or failed threshold
  still spends it. There is no retargeting or Essence refund. An armed shot
  survives source Banishment. One Projection may be declared each round.
- **Gravity Orb:** declare a canonical position in one marching lane. Fires at
  Step 10E, remains active for two rounds, then has a two-round cooldown after
  expiration. The persistent registry owns that lifetime. Both sides are pulled
  toward it; touching Marchers are destroyed regardless of HP or Armor. The
  first fourth kill grants one Neutral Tear, once per Orb across both rounds.
  Destroyed Marchers do not receive combat kill credit. Orb effects never move
  a Marcher between lanes. Swept collision prevents tunneling through its core.
- **Breach — Gravitational Collapse:** all Marcher travel is halved. This
  composes with Web, Breath and Rout modifiers and also halves Kroni-induced
  fleeing and Orb pull. Kroni himself remains a separate special actor.
- Printed ratings use the existing Valak content: Summon 6, Defense 5, Fracture 1.
  Standard Threat reduction and U13 resummoning remain in effect.

The initial fixed-point Orb tuning is attraction radius 330, destruction radius
65 and pull 7 per tick in a 2400 × 600 lane. These are balance parameters in
`U13GravityOrbs.gd`, not screen pixels. Pull includes engaged and waiting actors;
new commitments keep their normal movement-ready round. Contact with the core
destroys even a stationary actor. Overlapping attraction fields use nearest
distance, then stable Orb ID. Destruction ties follow activation order.

## Board

Projection explicitly labels enemy Lord/Castle guard zones. Gravity Orb uses a
separate placement overlay on the live marching field. Both can be queued in
one submission, removed independently, and use normal sealed-plan validation.

The green stored-energy orb sits on Valak's card at the right of the figure and
below its stat row. Its five layers scale with the card. Absorption travels from
the defeated Guard zone, defensive expenditure travels to the friendly Lord
Guard zone, and Projection travels to the selected enemy Guard zone. Gravity
Orb launches from the staff, forms its singularity, and rotates while active.
All animations consume simulation events and never mutate the match.

The existing debug panel includes **Fill Valak Essence** for immediate tests.

## Validation and runner

```bash
bash Scripts/Sim/run_u13_valak.sh "/c/path/to/Godot.exe"
```

This runs `--valak` in the foundation wrapper, then opens the main board. Select
Valak in the Lord picker. The wrapper retains the exact Godot 4.7.2 stable gate.

Local checks used the available Godot 4.5.1: Valak rules **213/213**, board
integration, preview **23/23**, Kroni, Odradek, Marching integration and lane
auras all passed. The board test uses an explicit headless-only
`--compatibility-check` flag to exercise UI code on that older runtime; the
production runtime check is unchanged. Godot 4.7.2 execution and visual review
on the user's machine remain the final runtime check.

Coverage includes both guard zones, equality kills, paid misses, empty targets,
Banishment after arming, no self-refund, actual Hunt/Siege gain, Ward precedence,
reserved capacity, source/target rejection, friendly/enemy Orb deaths, later
entrants, one reward across rounds, two-round lifetime/cooldown, composed Breach
slowdown, checkpoint integrity and identical populated-Orb replay results.
