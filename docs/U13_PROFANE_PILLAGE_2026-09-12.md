# U13 active-Castle Profane and castleless Pillage

This full-game checkpoint adds `U13_PROFANE_PILLAGE_V1`. It extends the existing
combat authority and shared planning legality, preserving the U12 baseline and
older isolated U13 fixtures. Full-game saves carry the new policy version.

## Recovered rules

- Active-Castle Profane targets one physical **own, active, full-Integrity**
  Castle. It is the round's main action, not the separate Development rite
  Profane the Ruins. There is no additional card or Soul cost; optionally
  committed cards still produce normal Castle-lane Marchers and leave through
  normal commitment cleanup.
- Profane removes that Castle and its printed effects immediately at its combat
  turn. It grants **one personal Tear after both ordinary combat actions**, before
  Post-Resolution 10A. It creates no neutral Tear, Soul, Castle-ruination event,
  Stones trigger, or Picking the Bones ruin. Fresh Sigils do not veto Profane.
- Target eligibility is checked at planning and again at resolution. Earlier
  artillery, Siege, or another effect can invalidate the sealed target. U13 then
  records a spent/fizzled order with no reward; it does not substitute another
  physical Castle after the joint lock. This preserves U13's existing explicit
  target contract rather than importing U12's optional bot-only fallback picker.
- If no active enemy Castle remains, Siege becomes **Pillage**. It remains `Siege`
  for commitment, Marcher production, waiter support, guard-death attribution and
  Lord reactions, including current Deimos Fear.
- Pillage follows the existing Ward and Castle Guard layers. Guard equality
  stops the attack; positive strength remaining after those layers grants
  **exactly one Soul**. There is no Integrity damage, destruction payout,
  excess bonus, personal Tear or neutral Tear. One main action and the combat
  round ledger prevent repeated awards.
- Ruined and Profaned Castles both permit Pillage. Protected unbuilt/building/
  ready choices are not active defenders. A zero-Integrity **active Defunct**
  Castle is still a physical Siege objective and therefore blocks Pillage.
- A Castleless zone has no persistent Castle Sigil. Losing the last active Castle
  clears it; a Castleless Ward still supplies its frontline defense but does not
  leave a Sigil. Lord Sigils and Castle Guards remain intact.

Sources: `ProfaneResolutionEngine`, `ResolutionCleanupEngine`, the current
`RuleConfig` full-Integrity/Fix-B settings, `MarchingEngine._commitment_lane`,
`SiegeResolutionEngine._resolve_castleless_pillage`, and the Pillage section of
`FutureFeatures/CORRUPTOR_DESIGN_ADDENDUM_VEIL_SIEGE_CONSTRUCTION.md`. Existing U13
Lord powers, shared Guard combat and explicit timing remain authoritative.

## Integration and boundary cases

`U13Plunder` owns target eligibility, the bounded per-round result ledger, Profane
resolution and delayed Tear settlement. `U13Combat` reuses its Siege pipeline
through Guard resolution and branches only for the Castleless payout.

For a Castleless opponent at planning, Siege uses `castle_zone:<opponent seat>`
as its target. These are zone identifiers, not fabricated entity IDs. If an
active Castle appears before resolution, that sealed zone attack fizzles rather
than selecting a new Castle. Conversely, a Siege locked onto a physical Castle
becomes Pillage if no active Castle remains when the attack resolves. If its
selected Castle disappears but others remain, the existing spent-target rule
continues to apply.

The full-game projection exposes the Plunder ledger. Shared bulk legality and
preview/commit accept exactly the same orders. The finite candidate vocabulary
includes Profane and Castleless Siege; full-game Random-Legal is version V4.
Save validation checks the resolution clock, target identity, presentation-time
eligibility, result-to-order binding, and fixed reward amounts.

This is a full-game conductor checkpoint. Manual Profane/Pillage controls and
full-game theater integration belong to the remaining player UI pass; the older
Lord exercise board is not silently switched to the full-game economy.

## Verification

`U13PlunderTestRunner` covers full/damaged/Defunct/Ruined/Profaned/protected and
wrong-owner targets, fresh-Sigil behavior, both combat priority orders, real
artillery invalidation, Profane Marcher production, delayed reward timing,
normal Guard equality, Ward prevention, exact waiter consumption, current Deimos
Fear, Castleless Sigils, and newly active Castles invalidating a zone attack.

Two directed full-game rounds replay from JSON before every hook: Profane plus
incoming Siege, and explicit Castleless Siege. Both continue through next-round
planning/save. Forged reward ledgers and repeated combat resolution reject.

The Windows game gate now expects **17/17**, including the existing Sigil board
check on Godot 4.7.2. Local checks use Godot 4.5.1; the pinned board runtime gate
remains a Windows verification. Veil effects, final victory resolution, and full
player-facing game integration remain separate milestones.
