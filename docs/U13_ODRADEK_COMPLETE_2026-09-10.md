# Odradek: remaining powers, Psychic Interlock and Paradox Geometry

The U13 main runner now supports all four Reconfiguration choices, Psychic Interlock and the Odradek Breach. The existing Gem Dagger enlargement remains in place. U12 is unchanged.

## Playing Odradek

Reconfiguration starts at zero, gains one each round while active, caps at four, and resets on banishment. During Powers, build any affordable ordered cart, including repeated powers. Remove or reorder entries before confirming. Payment occurs at submission lock; preparing an order reserves the displayed budget without mutating the match.

| Power | Cost | Selection | Resolution |
| --- | ---: | --- | --- |
| Redirect | 1 | Click to place a circle, then drag to adjust | Step 10B: both sides change lane at the same position |
| False Orders | 2 | Click a Guard, then its owner's other Guard zone | Next round before deployment: move that Guard |
| Allegiance Shift | 3 | Place the smaller circle; confirm **Turn Their Loyalty** | Step 10C: enemy Marchers inside become yours |
| Inversion | 4 | Click an enemy Guard zone | Next round before deployment: transfer its legal Guards to your corresponding zone; any success grants one Neutral Tear |

The area preview shows both lanes. Shift previews account for all queued Redirects and preceding Shifts. Membership is sampled again at resolution. Redirect radius remains 300 fixed-point units; Shift and Paradox use 180. These are initial tuning values, not final balance. Each circle belongs to one lane under the existing spatial contract.

Same-hook declarations use submission queue order. All Redirects fire before all Shifts regardless of cart order. Declared Step 10C effects resolve before the automatic Paradox event, following the Match's existing pending-effects-before-hook-callback convention.

## Guard transfers

Transfers preserve identity, value, suit and other card state. False Orders also preserves current ownership. A declaration captures the Guard's owner; if the Guard disappears or changes owner, the prepared order fizzles without retargeting or refunding its cost.

Destinations use the existing three-slot capacity. A transferred Guard keeps its slot if free, otherwise takes the lowest free slot. Inversion processes stable Guard IDs, transfers as many as fit, and leaves the rest behind. It grants exactly one Tear if at least one Guard moves. A full or empty target at firing grants none. Transfers do not count as Guard defeats, draws, spawns or swaps.

## Passive and Breach

Psychic Interlock reacts after the first enemy Marcher kills an active Odradek player's Marcher that round. Reflection uses the killing attack's resolved damage after the victim's Armor, before overkill clamping; the attacker then applies its own Armor normally. The original kill remains resolved. Reflection may kill the attacker and cannot recursively trigger another Interlock. Simultaneous mutual kills consume the trigger without reviving the attacker. The used-round ledger survives save/load.

Paradox Geometry runs once per round at Step 10C when Odradek occupies the Breach. Keyed RNG selects uniformly among currently valid Lord Guard, Castle Guard and Marcher events, then uniformly within the selected target pool. Guard events transfer one Guard to the opposing corresponding zone if capacity permits. Marcher events capture one small-circle membership snapshot and flip every member, from either side, through the shared allegiance transition. An empty valid pool produces an explicit no-op. Paradox grants no Inversion Tear.

History includes Guard moves, allegiance counts, reflection damage and the selected Paradox event. The bot can intentionally bank Reconfiguration, choose all four powers, and append affordable effects to a validated cart. It remains a basic seeded legal-move bot, not a tactical Odradek doctrine.

## Compatibility and verification

The Odradek rules profile is now `U13_ODRADEK_COMPLETE_V2`. Start a new match after pulling; snapshots from the earlier Redirect-only profile are intentionally rejected.

Three new suites cover power interactions, actual board controls and bot planning. The `--odradek` launcher now runs eight suites; the full launcher contains 88. The spatial reference implementation also emits the new killing-damage fact, keeping exact event/world comparisons meaningful.

Godot 4.7.2 verification: all 19 targeted suites passed—the eight focused Odradek/shared suites plus Marching Integration, Spatial Marching, Spatial Reference 6/24/48, Guard Deployment, Guard Random, Orias Board, Loadout Board, Quickstart and Gem Dagger. The focused launcher stopped at a formatter-induced parse error in a new test; the corrected test and remaining focused suites were then run successfully. An older reference-event mismatch was corrected by adding the killing-damage metadata to the independent reference, after which all three exact spatial comparisons passed. The full 88-suite aggregate was not rerun for this change. Visual feel and balance still need the user's playtest. The separate global Fracture gameplay migration remains outside this change.
