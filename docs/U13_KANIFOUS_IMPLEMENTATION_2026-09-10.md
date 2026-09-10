# Kanifous — U13 implementation

Implements the accepted Wishmaster Lamp amendment, the five active Wishes,
delayed Prices and a first Void presentation. Kanifous is the ninth selectable
Lord. U12 is unchanged.

## Lamp and smoke

Each living Kanifous creates one public smoke marker at Round Start Automatic,
before submission. Its lane and center use keyed RNG; in round N+1 at Marching
Start a Lamp materializes within 180 fixed-point units of that center. The
marker communicates the region, not the exact future point. Current sampling
keeps the region within one lane. Existing markers survive later banishment;
a banished Kanifous creates no new markers.

Contact uses swept segments and a 65-unit radius. Earliest contact within a tick
wins, then claimant stable ID, then Lamp ID for exact ties. Effects resolve after
Kroni/movement/Gravity hazards and before ordinary combat. A surviving first
claimant from either army resolves a keyed 10% rejection or its suit Wish.
Unclaimed Lamps expire at End of Marching. Markers and Lamps have stable IDs and
are saved with the authoritative world.

- Butcher: next actual attack uses twice its normal attack amount, then clears.
- Penitent: +2 current Armor, consumed through ordinary combat.
- Vulture: next two distinct enemy contacts are ignored by both sides. The
  bypassed identity list travels with the claimant, including allegiance changes.
- Wright: fresh base Wright with current allegiance, no inherited damage/buffs;
  shared local-spawn placement looks for an adjacent valid point, using the
  origin if the neighborhood is fully packed. It does not claim the same Lamp.

## Active Wishes and Prices

One Wish per player per round is enforced at submission and snapshot validation.
Power spawns three equally weighted random suits in the chosen lane at Step 10A.
Longevity restores an owned standing/Defunct Castle, including construction,
to full and active at Step 10F. Ruined/Profaned targets fail. Resurrection restores
this round's defeated Guards from the selected owned zone if their cards remain
in discard and their slots are free. No earlier-round losses return. Death
removes both armies in a 270-unit circle. Wealth draws up to two cards through
normal deck/hand-limit rules. No effective result means no Price.

Successful Wishes create independent public due notices 1–3 rounds later. Their
outcomes are not selected or revealed until due. At Round Start Automatic each
Price samples its currently valid outcomes with weights:
Cards 30, Blood 30, Guards 15, Stone 15, Soul 5, Ruin 4, Wishmaster 1.
All weights and spatial sizes are named tuning constants.

Prices discard up to two random cards, destroy up to two random owned Marchers,
defeat one Guard, remove five Castle Integrity, cost one Soul, make a Castle
Defunct, or banish Kanifous into the Breach. Stone/Soul/Ruin/Wishmaster each add
one Neutral Tear. If no outcome can affect anything, the Price expires harmlessly.
No Price or Lamp creates a decision prompt.

## Graphics hooks and Void

`U13WishmasterVisual` exposes optional smoke/lamp textures and a presentation-event
signal. It draws an animated procedural smoke marker with its spawn-radius ring
and due round, plus a temporary gold Lamp glyph. These are placeholders until
sprites are available. Lamp removal follows the same Marching playback clock.
Authoritative events identify smoke creation, materialization, claimant, rejection,
suit reward, Wright creation and Vulture bypass. Active Wishes and Prices also
publish result events for later bespoke animations.

The Void uses a replaceable screen distortion shader. Castle card captions and
tooltips use condition bands, Guard values are veiled with inspection suppressed,
and Marcher health rings use thirds. This is presentation-only: full world state,
replay, targeting and simulation remain exact. Broader masking (for example,
history or action-dialogue numbers) and visual intensity remain presentation tuning.

## Validation and runner

Focused checks cover all suit rewards on either team, rejection, swept contact,
active Wishes, all seven Price outcomes/Tears, catastrophic banishment, whole-plan
Wish limit, smoke timing/region/replay, expiry, Ghost contact exclusion, fresh
Mirror identity through real Marching/tape playback, and per-hook checkpoint
restores over four rounds. The board runner covers selection, targeting, removal,
worker resolution, public Price notices and Void state isolation.

Local execution uses Godot 4.5.1; board checks use the explicit headless-only
compatibility flag. Production remains pinned to 4.7.2. Visual review on the
user's machine and final supplied sprite integration remain pending.

`bash Scripts/Sim/run_u13_kanifous.sh /path/to/Godot.exe` runs the Kanifous rules,
board, Valak, Kroni and Marching regression groups, then opens the board. It
uses a 90-second per-runner default, overridable by U13_TEST_TIMEOUT_SECONDS.
