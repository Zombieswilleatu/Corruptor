# Orias Web first slice, Gem Dagger presentation, and Quickstart

Date: 2026-09-09. Runtime: Godot 4.7.2 stable.

## Scope and gates

This is the first Orias rules slice, not a completed playable Orias. The main
picker and Quickstart still use Deimos, Gremory, Humbaba and Kalligan. Web has an
experimental match-owner fixture, shared declaration/firing legality, a keyed
random-legal declaration provider, and focused rules/replay runners.

Snare's actual Guard-placement restriction, Relentless Pursuit, Accelerate,
Mark/resummoning, and Breach Frenzy remain outstanding. The normal board does
not yet offer Web targeting. Snare artwork in Animation Previews is explicitly
a visual example, not a claim that its Development restriction is implemented.
No four-Lord alpha frequency report or completion claim is extended to Orias.

## Web rules and movement

- Declare a canonical lane and fixed-point position. Fire at Step 10E,
  `POST_RESOLUTION_HAZARDS`, before Marching.
- On activation only, enemy Marchers whose centers are inside or on the circle
  take one damage. The standard Armor-before-HP path and battle event ledger
  own damage, deaths and reactions. Entering the area later does not deal
  another activation pulse.
- During the fresh and following fading round, enemy movement inside the area
  is halved. Current allegiance and real positions are checked at each movement
  tick. Allies are immune, and leaving removes the modifier.
- Expire at Step 2 after the two active rounds. Expiration starts the one-round
  cooldown: a round-1 Web is active in rounds 1–2, blocks round 3, and is ready
  again in round 4. The central registry limits each owner to one active Web.
- Slow composes with Breath and Rout recovery before deterministic integer
  rounding. Overlapping enemy Web areas are a single 50% modifier, not repeated
  multiplicative halving. With two players and one Web per owner there can be
  only one hostile Web for a given Marcher.

The initial radius is 270 fixed-point units: at lane center its diameter covers
540 of the 600-unit width (90%), and 540 of the 2400-unit forward length. This is
an explicit provisional tuning value. The follow-up message about a third of a
lane ended at “catches”; no missing design conclusion was inferred. A changed
rules radius must also update the versioned Orias policy and its tests. The
preview slider does not modify this rule or a saved match.

`U13SpatialFields` compiles active geometry once per Marching phase. The hot loop
performs a squared-distance membership check only when fields exist. It adds
no per-actor Nodes, physics bodies, random draws, or registry snapshots. Existing
four-Lord motion profiles take the previous speed path unchanged.

Restore binds Web payload/radius, stages, original target, activation time and
expiration cooldown to the trusted content policy. Fractional/out-of-bounds
positions and caller-supplied radius parameters are rejected. The old Kalligan
owner rejects the experimental Orias profile.

## Web and Snare artwork

Original uploaded PNGs are preserved at:

- `ConceptImages/Sprites/Orias/Web.png`
- `ConceptImages/Sprites/Orias/Spider.png`

The Web image stays still. The six-frame Spider follows a closed path on its
strands continuously. Drawing clips destination and source together at the
lane edge. Geometry is projected from canonical coordinates, including when
an area extends past an edge. The same Web artwork covers the Lord Guard zone
and the single shared Castle Guard zone in the Snare preview.

Main picker → **ANIMATION PREVIEWS** → **Orias · Web & Snare**. This preview is
also preserved as a standalone runner:

```bash
bash Scripts/Sim/run_u13_web_preview.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
```

Click the lane to reposition Web; use the radius slider to compare coverage.
The Fading and Snare-marker controls are presentation-only. Back returns to the
picker without discarding its choices. Assets load lazily when opened.

## Gem Dagger

The original five-frame PNG is at
`ConceptImages/Sprites/GemDagger/GemDagger.png`. Frames 1–3 loop during a straight
vertical drop; the sheet is rotated so its right-facing blade points down.
Frames 4–5 play at impact as the blade/coin burst. Initial timing is 0.70 seconds
of flight and 0.32 seconds of burst.

The worker supplies only the player's redacted `GUARD_DEFEATED` and
`GEM_DAGGER` events. Both players' reward events are grouped into one drop on the
triggering Guard. During the fall the presentation restores that Guard and
withholds the newly drawn own-hand card and opponent hand-count increase. At
impact it reveals the completed Guard defeat and draws together. Opponent card
identities are never reconstructed or passed to the effect.

The simulation has already resolved the rule; sprite timing does not own the
battle ledger, draw, replay, or RNG. Existing once-per-round Gem Dagger rules
and hand limits are unchanged. Skip reveals the final view, and Restart/New
loadout clear pending presentation. Planning and round advancement are held
while the drop is playing. Artillery playback still finishes before the drop
and before the Marching playback clock starts.

## Quickstart

The Lord/Castle picker has **QUICKSTART · RANDOM** beside Start Board. One click:

1. Selects a random currently playable Lord independently for each side (mirrors
   are allowed).
2. Places Keep in slot 1 on both sides.
3. Fills the other four slots randomly, respecting the existing maximum of two
   copies per type. A second Keep is allowed.
4. Starts the existing quick exercise opening through the same configure/start
   path as manual selection.

Setup randomness uses a fresh local setup seed and dedicated per-player and
per-slot keys. It does not consume or shift the match RNG. Manual setup remains
available and retains the existing optional Keep recommendation/tutorial.
Keep is mandatory specifically for Quickstart.

## Verification

New focused groups, under the unchanged 30-second per-runner watchdog:

| Flag | Expected successful footer count | Coverage |
| --- | ---: | --- |
| `--orias-web` | 7/7 | Activation/legality, real-position motion, four separate lifecycle/replay rounds, artwork/projection |
| `--quickstart` | 1/1 | Repeatable seeded choices, both Keep-first loadouts, type cap and roster variety |
| `--gem-dagger` | 2/2 | Existing Gremory rules plus event-driven visual impact/hand-count timing |

The full foundation list is now **72 runners**. Every previous focused group
is retained. Web lifecycle verification is split into four processes to avoid
accumulating a multi-round replay under one watchdog.

Agent-side checks: GDScript grammar, indented blocks, direct preload references
and call arities, shell syntax, original PNG hashes, and wrapper stubs for all
new groups plus exit-zero script errors, missing footers and watchdog expiry.
Independent arithmetic checks cover Web entry travel, combined speed rounding,
and Quickstart's keyed selection constraints.

There is no Godot executable in the agent workspace. These checks do not claim
Godot compilation, runtime success, performance measurements, or a visual
approval. Local Godot 4.7.2 results remain authoritative.
