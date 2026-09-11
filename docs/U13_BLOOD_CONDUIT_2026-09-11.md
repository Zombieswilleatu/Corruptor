# U13 Blood Conduit and Fracture terminology

The full-game runner now expects **9/9**. Blood Conduit is enabled by the
`U13_BLOOD_CONDUIT_V1` game profile. Existing exercise profiles retain their
previous behavior. Sigil creation/aging remains the next missing subsystem.

## Blood Conduit

Source: current UI2 CastlePowerText and CastleIntegrityRules.gain_threat, adapted
to U13LordStats rather than copying obsolete Lord defense formulas.

- When a Threat gain would lower the current Lord's DEF, one operational friendly
  Summoning Circle exerts 3 Integrity and prevents 1 of that gain.
- For ordinary Lords, the crossings are 1->2, 2->3 and 3->4. Gaining Threat from
  0->1 or above the final defense band does not expend Integrity.
- Humbaba has no Threat; Kroni's DEF comes from Hunger. Neither triggers Conduit.
- Protected, below-floor, Ruined or Profaned Circles do not qualify. Select the
  lowest eligible physical slot. Duplicate Circles do not stack on one gain;
  another operational copy can handle a later gain.
- Exertion uses the existing Integrity-loss/vulnerability-lock rules. It may
  make a Circle Defunct but does not deliver a Castle-ruination reward or callback.
- Current gain sites are Orias's Snare payment, Accelerate on a credited Hunt
  Guard defeat, and the extra Threat from The Mark on a returned Lord.
- Summon payment shortfall establishes a baseline; it is not a Conduit-triggering
  gain. Blood Offering spends its 3 Integrity first. The Mark's separate gain
  then checks whether any Circle is still operational. Quotes and resolution
  follow the same order, including the existing return cap.

Snare snapshot validation recognizes the reduced actual Threat payment. The
existing declaration, cooldown, once-per-round and credited-fact checks remain.
The effect emits an explicit public BLOOD_CONDUIT event with before/after values.
The policy identity includes Conduit, so older game snapshots need a new match.

## Terminology correction: Fracture

The user clarified that the old printed **Return Threat** rating is now
**Fracture**. `FractureEngine.fracture_value` still reads the old Lord-content key
`return_threat`; this is a legacy internal name, not the current rules term.
Fracture is the banishment effect affecting Subjects or infrastructure. The U13
Lord cards already label that printed rating FRACTURE.

This is distinct from current Threat and from the Threat calculated when a player
underpays a summon. U13Resummoning's dynamic `return_threat` quote field refers to
that payment/Mark result, not the printed Fracture rating. Its current mechanics
are preserved; rules and explanatory text must make the distinction explicit.
Blood Conduit prevents an applicable Threat gain; it does not prevent Fracture
or convert banishment damage into Threat. The later `U13_FRACTURE_2026-09-11.md`
checkpoint implements the printed banishment effect in the full-game conductor.

## Verification

The dedicated suite covers DEF crossings, inactive/protected Circles, duplicate
selection, Humbaba/Kroni exceptions, exertion locks, read-only Snare preview,
post-lock JSON restore and full-round replay, credited Accelerate, and marked
return quotes/resolution at Integrity 7 and 10. The marked-return examples are
explicit transform fixtures to isolate Offering/Conduit ordering.

Orias resummon, pursuit and Snare regressions cover the unchanged exercise
profiles. Local compatibility runtime is Godot 4.5.1; Windows Godot 4.7.2 remains
the user's runtime gate.
