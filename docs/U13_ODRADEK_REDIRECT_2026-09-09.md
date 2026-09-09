# Odradek: Reconfiguration and Redirect

Odradek is now selectable in the U13 main runner and Quickstart. This is his first playable slice. False Orders, Allegiance Shift, Inversion, Psychic Interlock and Paradox Geometry are still pending. U12 is unchanged.

Reconfiguration starts at 0, gains 1 at Step 3 while Odradek is alive, caps at 4, and resets immediately when he is Banished. The first planning phase therefore shows 1. Both players' Lord cards expose the current bank. Printed stats use the existing Lord data: Summon 8, base Defense 5, Fracture 2; normal Threat reduction applies to Defense. Fracture's U13 gameplay migration remains pending.

Redirect costs 1, paid at submission lock. A rule-owned repeatable flag lets the existing declaration queue reserve repeated effects without adding a cooldown. Identity, queue order, affordability and target validation remain authoritative. Previewing or editing the queue never spends live resources. Paid effects survive Banishment.

At Step 10B, each Redirect captures current Marcher membership in its circle, across both owners, and moves those bodies to the opposite lane with the same progress and lateral coordinate. It preserves identity, ownership, facing, HP, Armor, movement readiness, waiting eligibility and persistent effects. Any old cached encounter involving a moved body is ended and its participants' contact tickets are cleared so combat can restart in the proper lane. Each later queued effect recaptures the changed board.

The initial tuning radius is `U13Odradek.REDIRECT_RADIUS_FP = 300`, a diameter equal to one lane's width. This is an explicit exercise default, not a finalized balance specification. Spatial selection remains lane-bound under the existing canonical region contract.

The placement view shows both lanes, current Marchers, affected destination outlines, and earlier queued Redirects. Click to place; grab and drag to adjust; **REWRITE THE PATH** adds the effect. Queue controls reorder or remove declarations and rebuild their indices/IDs. A public note makes clear that actual membership is checked after combat. The Tier-1 bot samples Marcher positions and lane centers through shared legality; strategic multi-effect combinations remain future doctrine work.

Gem Dagger's sprite scale increased from 0.22 to 0.66 in the shared renderer. Its impact-point offset uses that same scale, preserving the target alignment in both the main match and standalone preview.

Validation on Godot 4.7.2 includes Odradek rules/replay, main board placement and round worker, Orias board regression, shared Match and planning legality, Quickstart, and Gem Dagger. The focused Odradek suite also checks injured/armored bodies, circle edges, repeated movement, unfinished duels, gate waiters, the resource cap, overspending rejection, paid-queue JSON restore, and Banishment. The aggregate launcher now contains 85 suites; the full aggregate was not rerun.

Focused launcher: `bash Scripts/Sim/run_u13_foundation_tests.sh "$godot_u13_exe" --odradek` (five suites).
