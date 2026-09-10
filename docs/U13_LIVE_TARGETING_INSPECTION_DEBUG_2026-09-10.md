# U13 live targeting, Lord inspection and debug controls

Redirect and Allegiance Shift now target the actual battlefield rail. Click to place, drag to adjust, then confirm. The overlay retains the battlefield art and chits; rings identify affected Marchers and Redirect arrows identify destinations. Descriptions beneath each power explain its effect. The targeting rectangle uses the same coordinate mapping as the drawn chits, including the lane's lateral axis. Earlier queued Redirects and Shifts are included in the working preview; final membership is still sampled at the authoritative firing hook.

## Negative vortex

`U13Paradox.gdshader` reads the rendered battlefield, twists its sampling coordinates and blends in a negative with a feathered edge. The screen-space center and two projected radii come from the canonical target and effect radius. Sampling and output are clipped to the affected lane or Guard zone. No sprites or simulation RNG are used.

Aiming uses a subtle crawling distortion. Resolution plays public before/after records in hook and declaration order: the vortex rises, chits change lane or allegiance at the midpoint, and the distortion collapses. Marching playback waits for these pulses; Skip clears them. Paradox has greater swirl and edge variation while preserving the real affected radius. Guard transfers also pulse their source/destination areas.

## Lord cards

Hold a Lord card for 0.35 seconds to open its large front. Release leaves it open. Click the large card to flip between front and rules back. Hold either the original small card or the large card to dismiss; Escape also closes it. Ordinary short clicks on small cards retain their targeting behavior, and inspection never clicks through to a declaration.

All six playable Lords have text backs containing passives and Breach rules. Active passives are bright and the inactive Breach is gray. In the Breach, passives are gray and the Breach rule is highlighted. Banished Lords outside the current Breach have no highlighted rules. The header's Breach card supports the same inspection interaction. Active-power instructions remain in the power controls. Existing live stat overlays remain on enlarged Lord fronts. Legacy U12 and its card-preview implementation are unchanged.

## Debug panel

Open **DEBUG** in the main runner header while planning. Choose **You/Opponent** and **Lord/Castle** lane or Guard zone.

| Control | Result |
| --- | --- |
| Add random Guard | Adds a seeded random suit/value Guard to a free slot |
| Draw 2 hand cards | Draws from the real deck, respecting hand capacity |
| Add random Marcher | Adds a seeded random suit Marcher ready for this round |
| Kill Lord · Move to Breach | Banishes the selected Lord and runs Breach-entry reactions, without fabricated Hunt rewards |
| Defeat first Guard | Defeats the first stable-ID Guard in the selected zone, including normal defeat triggers |
| Fill Odradek Reconfiguration | Sets an active Odradek's bank to its normal cap of four |

Successful debug changes clear staged orders and record a public debug history entry. Full zones, empty zones, full hands, inactive Odradek and changes during resolution are rejected without changing the match. Debug edits are checked on a disposable owner and installed only after complete snapshot validation. Humbaba's debug-time Breach entries have an explicit ledger marker so their actual entry damage can occur during planning without falsifying the combat clock. Normal game entries retain their combat-phase constraint.

The ordinary opening and automatic Reconfiguration gain are unchanged. No special practice opening was added.

## Verification

Three new suites cover real mouse input for inspection, debug actions and live coordinate mapping, and shader parameters/resolution timing. The full launcher now contains 91 suites; `--odradek` includes the three additions. All 14 targeted suites passed on Godot 4.7.2 with 30-second timeouts and engine-error rejection: Lord Inspection, Debug Board, Odradek Visual, Odradek Board, Odradek Complete Board, Orias Board, Loadout Board, Direct Board, Humbaba Integration, Humbaba, Kalligan Board Session, Odradek Powers, Quickstart and Gem Dagger. The loadout regression found a missing effects-node guard in the older U13 layout; that was fixed and the suite rerun successfully. The full 91-suite aggregate was not rerun. Headless tests check the shader's canonical parameters and presentation sequencing; final color/intensity tuning still requires an in-game visual check.
