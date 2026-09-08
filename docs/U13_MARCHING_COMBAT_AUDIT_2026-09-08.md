# U13 Marching and Gremory combat integration

## Gate and exact scope

The user verified **10/10 on Godot 4.7.2** for U13 commit
`827e7cc0c2baba64a3fdcf3446cbc4273dc86ef2`. That checkpoint proved the Gremory
content/transition slice. This batch adds actual contact, damage and committed-card
combat, with an eleventh runner. **The user verified 11/11 on Godot 4.7.2** at
`b1b3e60f2e0874555b802f2c9e57db9c8d41953a`, reporting both
`U13 Marching integration failures: 0` and `U13 foundation runners passed: 11/11`.

No U12 implementation or playable controller is changed. This remains a headless
U13 match path, not a playable scene or full migration of every ordinary action.
The built-in combat profile is deliberately named `U13_GREMORY_BASIC_COMBAT_V1`:
Gremory mirrors, Siege/Ward, ordinary Guards, flat Sigils and explicitly marked
`plain_integrity` Castle instances. Unsupported actions/profiles are rejected.
It cannot yet load arbitrary U12 matches. Hunt/Keep interposition, Bastion screening,
other named Castle powers, construction/repair, Fracture, Profane, full Development,
victory orchestration, UI and bot policy remain separate work.

The old injected-transition fixture remains useful for isolated Gremory rules. The
new runner calls `Gremory.new().create_combat_match()` and submits cards/powers;
it never supplies damage, kill, Guard-defeat or Castle-destruction commands.
The combat module derives those outcomes and delivers the same authoritative facts
and immediate Gremory reactions. Do not advance to another Lord or spatial powers
without their own acceptance gates. This Marching/Gremory integration gate is now green.

## Audit: extend the math, adapt ownership and timing

Inspected sources at the verified checkpoint: `MarchingEngine.gd`, `PlayerState.gd`,
`ResolutionEngine.gd`, `HuntResolutionEngine.gd`, `SiegeResolutionEngine.gd`,
`RuleConfig.gd`, `Prototype/PlayableRoundController.gd`,
`Prototype/UI2/MarchingLaneView.gd`, `BotMarchingDoctrine.gd`, and the shipping
`SmartCoreV47Doctrine.gd` / `SmartCoreV47BaseDoctrine.gd` path.

| Audit question | Finding and U13 decision |
|---|---|
| Authoritative position | Modern U12 uses owner-relative integer `distance_fp`, scale 200, lane length 2400. U13 uses the equivalent global `x_fp`: owner 0 distance = x; owner 1 distance = 2400 − x. No pixels are serialized. |
| What advances movement? | `MarchingEngine.resolve_half` advances standard tokens. The old controller invokes one half near round start and the other after Reveal, before normal Resolution. U13 invokes its adapter only at Step 12. |
| Fixed step or frame time? | Each old half is 100 ticks. The U13 phase is 200 ticks, preserving total movement per round and the exact integer increments: Butcher/Wright 4, Penitent 3, Vulture 6. |
| Visual separation | UI2's `_process(delta)` advances a playback clock and local chit/keyframe state. Its packing and collision animation are visual; the simulator already owns outcomes. The U13 owner has no renderer callbacks. |
| Collision resolution | Front token per owner/lane; contact when the owner distances sum to at least 2400. Snap both fronts to the floored midpoint. Resolve simultaneous exchanges to a death, then the next front pair in the same tick. Preserve depleting Armor, bypass, and both deaths in a lethal exchange. |
| Combat targets | U12 uses mutable marcher dictionaries in owner arrays. U13 uses registered physical entity IDs, owner, lane and canonical position. Kill facts retain both combatant snapshots before retirement. Guard targets remain physical card IDs with explicit lane and slot. |
| Waiters | Arrival retains the unit and marks it waiting; it creates no Tear. Waiters do not move or regenerate, remain eligible for contact, and fight fresh held defenders. A valid matching Siege adds +1 per waiter and consumes them even if blocked. A vanished target leaves its waiters. U12 Hunt support is audited but the U13 Hunt action is not implemented in this profile. |
| Legacy config | `march_max_in_flight` belongs to launch/reactive paths; `march_steps`, `march_threshold`, `march_damage`, `march_suit_bonus`, and `march_exception_pair` belong to legacy advance/scoring/marshal logic. Modern `resolve_half` does not use them as caps or damage rules. `BotMarchingDoctrine` still reads legacy knobs; it is not connected to this U13 owner. |
| Repeated headless determinism | New Godot runner compares repeated results with reversed registry insertion order, JSON restores at every owner hook, a one-sided sealed submission, and a full real Marching replay. The user verified the complete 11/11 runner set on Godot 4.7.2 at `b1b3e60`, including these runtime assertions. |
| Reusable behavior | Profiles, integer movement, birth hold for commitments, regeneration rules, geometric fronts, midpoint snapping, simultaneous exchanges, armor depletion, waiter interception and support. These are extracted from the audited modern engine, not redesigned from the legacy launch engine. |
| Required refactor | The existing engine couples typed U12 state/config/finale, owner arrays, mutable global RNG and `source == commitment` filtering. Calling it directly would exclude Lord spawns and retain old phase/victory coupling. `U13Marching` adapts those boundaries to registered entities, keyed RNG and a single owner transaction. No full physics or spatial targeting rewrite is justified. |

The old contact/exchange guards are retained as **explicit atomic failures** (256
contacts per lane/tick, 64 exchanges per duel). Hitting a guard never silently
commits a partially resolved phase. In ordinary standard-profile duels these limits
are far above the required work. Midpoint snapping can slightly reposition a waiter
during contact, as in U12; its waiting/support state remains authoritative.

Smart Core evidence is narrower than full doctrine certification: its bulk
`commitment_choices` wrapper appends waiter-count/cash-lane annotations, but its
separate `commitment_choice` entry point does not pass through that wrapper. This
audit does not establish that all candidate scoring consumes those annotations.
No Smart Core adapter is added or claimed for U13.

## Explicit timing and identity decisions

- Step 3 regenerates living, non-waiting Marcher HP once. Armor does not regenerate.
- Step 8 Reveal creates commitment Marchers from immutable committed card values:
  per suit, `floor(total printed value / 3)`, in the committed action's lane.
- Commitment births can block/fight immediately, but `movement_ready_round` is
  birth round + 1, preserving the U12 commitment hold.
- Predator births at Step 10A have `movement_ready_round == birth_round`: the
  finalized Lord spawn participates in the upcoming Step 12. This is a deliberate
  Lord-spawn timing policy, not accidental inheritance of the commitment hold.
- Step 12 runs all 200 ticks after normal combat and Step 10A–10G / Step 11.
  Gate-to-gate unobstructed travel remains 3 moving rounds for Butcher/Wright,
  2 for Vulture and 4 for Penitent.
- Same-position front ties preserve the baseline random choice. Candidates are
  sorted by stable entity ID, then selected with the shared keyed RNG using round,
  tick, lane, duel ordinal and player. Other random draws cannot shift that stream.
- Predator IDs retain their effect ID + spawn ordinal. Commitment IDs use a
  length-prefixed origin containing round, owner and suit, then spawn ordinal.
  Equal faces, repeated rounds and different players cannot collide.
- Guard slots are explicit per owner/lane. Defeat ordering is value descending,
  then slot ascending, preserving the baseline zone-order tie rule without relying
  on registry insertion order. Defeat changes card role/zone, not physical identity.
- Simultaneous Marcher deaths are installed together. Both kill facts retain
  attribution and reactions follow explicit player priority, so both Gremories can
  earn Bones on mutual Vulture destruction. Reward caps remain once per owner/round.
- A whole hook is atomic; saves are at hook boundaries, not halfway through a tick.
  Start/end units plus tick-stamped clashes/exchanges/waiting events form the public
  replay tape. A future renderer can interpolate it without deciding outcomes.

## Sealed ordinary combat orders

The shared match API now accepts an optional third argument:

```gdscript
owner.preview_submission(player_id, powers, combat_order)
owner.submit(player_id, powers, combat_order)
```

Examples for this profile:

```gdscript
{} # Pass ordinary combat; Lord declarations can still be submitted.
{"action": "Siege", "lane": "Castle", "target_id": castle_entity_id,
 "card_ids": [physical_card_id_a, physical_card_id_b]}
{"action": "Ward", "lane": "Castle", "card_ids": [physical_card_id]}
```

There is one ordinary order per player. Both orders and power queues lock together.
Payment is staged before card commitment, so Ruin's two discarded cards cannot also
pay for the ordinary attack. Preview uses the same code as acceptance and mutates
only a candidate. A submitted order creates no public world/event change until the
joint lock. Committed identities and even their count remain hidden from the
opponent until Reveal; each owner can inspect its own commitment.

Cards gain a `committed: [[], []]` zone, retaining physical identity and owner. They
are unavailable for draw/recycle or another payment and enter discard during
Aftermath in player-priority and submitted-card order. Older fixture worlds without
the optional zone remain valid. Authoritative snapshots store both orders; restore
checks order shape, physical identities, hand/commitment correspondence and phase
ledgers. A pre-Reveal save cannot substitute another real but uncommitted card to
increase an attack. Live combat policy identity pins both combat and Marching
versions; the injected fixture and built-in profile cannot restore each other's saves.

### Audited basic Siege calculation

The measured baseline attack suit economy is retained: Butchers at print,
off-suits −1 with floor 1, plus one for at least two Butcher cards. Ward uses the
same rule with Penitent exemption/bonus; an opposite-lane Ward contributes half,
rounded down. Waiters add one each to the attack. Resolve Ward, then Guards in
value/slot order, then flat Sigil (Fresh 2 / Flipped 1), then plain Integrity.
Equality stops at Ward/Guard/Sigil; positive Castle Integrity is destroyed at
equality. A zero-Integrity Defunct Castle does not generate a destruction event.

Guard defeat immediately discards that physical card, then runs Gem Dagger.
Castle destruction retires the instance, then Sifting sees the actual current
discard top. Prepared Ruin aimed at that retired instance fizzles next round.
The profile preserves ordinary unconsumed enemy-Siege rewards: 1 Soul (2 when Guards
were defeated) plus measured-profile +1; first Castle Tear globally each round is
neutral. A broken Fresh Sigil rewards the defender one Soul if the Castle survives.
Consume-the-Siege and alternate reward profiles are not accepted inputs. These
rewards do not imply that victory/endgame orchestration has been migrated.

## Verification and next step

Added `U13MarchingIntegrationTestRunner.gd` and direct preflight checks for the two
new dependencies. The runner covers movement vectors, birth hold, waiting, regen,
bypass/depleting armor, simultaneous kills, tied fronts, real Predator deaths,
real Siege/Guard/Castle facts, Gem/Sifting/Bones, Ward/Guard/Sigil/Integrity equality,
waiter consumption, private commitments, distinct power/commitment payments,
real-target Ruin fizzle, repeated rounds, malformed restores and JSON replay.

Coding-environment checks: all U13 scripts parsed with gdtoolkit; formatting/lint
review; Bash syntax; wrapper subprocess shims for success, old runtime, failed
preflight, missing footer and engine error. Shims exercise orchestration only.
Godot is unavailable in the coding environment. Runtime verification comes from
the user's local Godot 4.7.2 run at `b1b3e60`, which passed **11/11**.

```bash
git pull --ff-only origin u13-lord-overhaul &&
bash Scripts/Sim/run_u13_foundation_tests.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
```

Verified final line: `U13 foundation runners passed: 11/11`.
The next product-facing step is a U13 smoke scene/controller over this owner, with
its supported profile made clear; the broader ordinary-rule migration remains
necessary for full matches. This gate does not certify a full playable U13 ruleset.


## Local gate follow-up: fractional-position fixture

The user's Godot 4.7.2 run of `6b51866` reached
`FAIL fractional_marching_position_rejected`; the preceding replay and order
validation checks passed. The test attempted to corrupt `x_fp` through its normal
`_edit` helper. That helper called `U13EntityIds.update`, which correctly rejected
the fraction through `U13EffectData.is_data`, but ignored the returned rejection.
The subsequent match-start assertion therefore received the original valid world.

The corrected test separately verifies atomic registry rejection, a valid integer
startup control, an actual fraction in raw external data, direct Marching validation,
and atomic rejection at match start/restore. The normal setup helper now reports
rejected edits. Production validation and combat rules are unchanged. Static parsing
passes. The user subsequently verified the corrected **11/11 local Godot gate**
at `b1b3e60`, including the real-target Ruin test that follows this check.
