# Supplicant cash-in selection — September 17, 2026

Five owned Supplicants in the same lane already grant **one Personal Tear**. The rite reserves their identities at submission and retires them in Development, before Hunt/Siege and Marching. A committed exchange therefore cannot lose its payment to the later combat step. Remaining Supplicants in the matching lane are automatically spent for +1 attack each by Hunt or Siege.

The picker previously required a separate **Stage Five** click after checking the five bodies. Clicking **Resolve Round** directly ignored checked but unstaged selections. The UI now stages the open picker's checked selection before submitting the round. Partial, excessive or mixed-lane groups are rejected by the existing authoritative validator. The player stays in planning with an explanation; no combat is submitted. **No Rites · Resolve** still explicitly discards pending and staged rites.

The separate Stage buttons remain for combining exchanges and other rites. Both rites menus state the personal reward and show readable staged exchanges. The picker explains automatic combat consumption, and names monsters rather than displaying only “Monster”.

## Reported match

The supplied round-18 save records seven player-owned Castle Supplicants at the end of round 12. Round 13 contains a Siege order with no `waiter_spends`. `SIEGE_STARTED` consumes all seven for +7 strength, giving 11 total; `SIEGE_RESOLVED` records an 11-point Ward screen, zero castle damage and zero guards defeated. There is no accepted Supplicant cash-in anywhere in this match. The save does not record unstaged UI selections, so the exact missing click cannot be reconstructed.

The game ended at Final Collapse in round 18, Veil 27, with Kalligan winning 2–0 Souls and trailing 1–2 Personal Tears. Of 24 neutral tears, 14 came from Gremory's Picking the Bones, six from round pressure, two from castle destruction, one from banishment and one from resummoning. Ten of the player's thirteen Sieges dealt no damage to the selected castle, but three of those damaged the protecting Bastion instead (6, 3 and 9 damage). Seven Sieges dealt no damage to any castle. These are balance-review observations, not a broad balance change in this patch.

## Verification

`U13SupplicantCashInBoardTestRunner.gd` exercises the actual modal and round worker: four checked bodies block resolution; five produce one Personal Tear before Siege; only the remaining two fund attack; explicit No Rites spends all seven normally. Existing Dominion rite tests verify that the reward is personal, does not also create a neutral tear, and cannot pay twice.

Local checks use the Godot 4.5.1 Linux diagnostic runtime. The supported Windows Godot 4.7.2 runtime and its guard are unchanged.
